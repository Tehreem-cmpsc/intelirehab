import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' show BluetoothConnectionState;

import '../onboarding/onboarding_data.dart';
import '../onboarding/onboarding_repository.dart';
import 'ble/arm_band_ble_service.dart';
import 'ble/arm_band_protocol.dart';
import 'ble/reconnect_backoff.dart';

enum WearableConnState { connected, calibrating, disconnected, searching }

/// Communication Layer (SDD §3.1.2) — the app-side half of BLE pairing and
/// connection state, matched against firmware/lib/ArmEMG_IMU/BLEStreamer.cpp's real
/// GATT profile via [ArmBandBleService]. "Connected" means an actual BLE
/// link is up, not just a database row — on app launch, a previously
/// paired band is automatically searched for and reconnected to, and an
/// unexpected drop (out of range, band powered off) is reflected here the
/// moment it happens, not just on the next manual check.
class WearableConnectionController extends ChangeNotifier {
  final String patientId;
  final OnboardingRepository _repo;
  final ArmBandBleService _ble;

  WearableConnState state;

  /// Always null for now: the band's firmware doesn't report a battery level
  /// yet, and a made-up number (this used to be hashed from the serial) is
  /// worse than none - a band at 5% would read "78%". Wire real telemetry
  /// in here once the firmware sends it.
  int? batteryPercent;
  String? lastError;

  /// What the current connect attempt is doing right now, for the UI.
  String? stage;

  /// The remembered band's id (wearable_devices.serial_no) — null once
  /// [forget] has been called, or if nothing's ever been paired.
  String? _deviceId;

  /// Guards against a stale scan/connect attempt finishing after
  /// [cancelSearch] or [dispose] — those don't actually cancel the
  /// in-flight BLE calls (the plugin has no cancellation token for
  /// `connect()`), just make this class ignore the result.
  int _attempt = 0;

  WearableConnectionController({
    required this.patientId,
    required bool initiallyPaired,
    String? deviceSerial,
    OnboardingRepository? repository,
    ArmBandBleService? bleService,
  })  : _repo = repository ?? OnboardingRepository(),
        _ble = bleService ?? ArmBandBleService(),
        // A saved serial that isn't a real BLE id (left over from the
        // simulated pairing) can never connect; forget it so the patient
        // scans and pairs the real band instead.
        _deviceId = deviceSerial != null && ArmBandBleService.isValidDeviceId(deviceSerial) ? deviceSerial : null,
        state = WearableConnState.disconnected,
        batteryPercent = null {
    _ble.connectionState.listen(_onBleConnectionChanged);
    _ble.onProgress = (s) {
      if (isDisposed) return;
      stage = s;
      notifyListeners();
    };
    // Being "paired" only means a database row exists — the BLE link
    // itself never survives an app restart, so it has to be re-established
    // for real, not assumed.
    if (initiallyPaired && _deviceId != null) _autoReconnect(_deviceId!);
  }

  bool get isConnected => state == WearableConnState.connected;

  /// The live sensor stream, once connected — exposed for whatever reads
  /// it next (e.g. a future Active Session redesign that consumes real
  /// data instead of SessionSimulator's synthetic one); nothing in this
  /// pass subscribes to it itself.
  Stream<ArmBandSample> get liveSamples => _ble.samples;

  /// Sends a calibration command (zero pose, gyro, MVC) to the connected band.
  Future<void> sendBandCommand(ArmBandCommand command) {
    if (!isConnected) throw StateError('No band connected.');
    return _ble.sendCommand(command);
  }

  void _onBleConnectionChanged(BluetoothConnectionState bleState) {
    if (bleState == BluetoothConnectionState.disconnected && state == WearableConnState.connected) {
      // The band dropped on its own — out of range or powered off, not
      // something this app asked for.
      state = WearableConnState.disconnected;
      batteryPercent = null;
      notifyListeners();
      _scheduleRetry();
    }
  }

  // ---- automatic reconnect after an unexpected drop ---------------------

  final _backoff = ReconnectBackoff();
  Timer? _retryTimer;

  void _scheduleRetry() {
    if (isDisposed || _deviceId == null) return;
    final delay = _backoff.next();
    if (delay == null) return; // gave up - the patient can retry by hand
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _retry);
  }

  void _stopRetrying() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _backoff.stop();
  }

  Future<void> _retry() async {
    final id = _deviceId;
    if (isDisposed || id == null || state != WearableConnState.disconnected) return;
    final attempt = ++_attempt;
    state = WearableConnState.searching;
    notifyListeners();
    try {
      await _ble.connect(id);
      if (attempt != _attempt) return;
      state = WearableConnState.connected;
      _backoff.reset();
    } on ArmBandSuperseded {
      return;
    } catch (e) {
      if (attempt != _attempt) return;
      state = WearableConnState.disconnected;
      _afterFailedAutoAttempt(e);
    }
    notifyListeners();
  }

  /// Retrying can't fix a denied permission or Bluetooth being off: say so
  /// and stop, instead of looping the radio. Anything else keeps backing off.
  void _afterFailedAutoAttempt(Object e) {
    if (e is ArmBandPermissionDenied || e is ArmBandBluetoothOff) {
      lastError = (e as ArmBandException).message;
      _stopRetrying();
    } else {
      _scheduleRetry();
    }
  }

  Future<void> _autoReconnect(String deviceId) async {
    final attempt = ++_attempt;
    state = WearableConnState.searching;
    notifyListeners();
    try {
      await _ble.connect(deviceId);
      if (attempt != _attempt) return; // superseded by forget()/a newer attempt
      state = WearableConnState.connected;
      _backoff.reset();
    } on ArmBandSuperseded {
      return;
    } catch (e) {
      // Quiet on launch — the band just wasn't in range yet. Home's
      // ambient "Wearable not connected" card (Rule 17) is what tells the
      // patient, not an error dialog they didn't ask for.
      if (attempt != _attempt) return;
      state = WearableConnState.disconnected;
      _afterFailedAutoAttempt(e);
    }
    notifyListeners();
  }

  /// Reconnects to the remembered band, or — if none is remembered yet —
  /// scans and pairs with the strongest one found (this app only ever
  /// manages one band at a time).
  ///
  /// "Connected" follows the real Bluetooth link alone. Recording a newly
  /// paired band in the database is a separate, best-effort step: it used to
  /// run inside this flow, so being offline made pairing fail even though the
  /// band was connected, and left a live link the app had given up on.
  Future<void> reconnect() async {
    _retryTimer?.cancel(); // the patient is driving now
    final attempt = ++_attempt;
    lastError = null;
    stage = null;
    state = WearableConnState.searching;
    notifyListeners();

    try {
      var targetId = _deviceId;
      final isNewBand = targetId == null;
      if (targetId == null) {
        final found = await _ble.findStrongest();
        if (attempt != _attempt) return;
        targetId = found.id;
      }

      state = WearableConnState.calibrating; // the connect+service-discovery handshake
      notifyListeners();

      await _ble.connect(targetId);
      if (attempt != _attempt) return;

      _deviceId = targetId;
      batteryPercent = null;
      state = WearableConnState.connected;
      _backoff.reset();
      if (isNewBand) _unsavedBandId = targetId;
    } on ArmBandSuperseded {
      return;
    } on ArmBandException catch (e) {
      if (attempt != _attempt) return;
      lastError = e.message;
      state = WearableConnState.disconnected;
      batteryPercent = null;
    } catch (e, st) {
      if (attempt != _attempt) return;
      // Anything that isn't one of the band's own errors (a plugin/platform
      // failure, a connect timeout, a stale saved band id...). Keep the
      // patient-facing line short, but never throw the cause away: log it,
      // and in debug builds show it so "couldn't connect" is diagnosable.
      debugPrint('Band connect failed: $e\n$st');
      const base = "Couldn't connect to your band. Check it's charged and nearby.";
      final firstLine = '$e'.split('\n').first;
      lastError = kDebugMode ? '$base\n\n[debug] ${e.runtimeType}: $firstLine' : base;
      state = WearableConnState.disconnected;
      batteryPercent = null;
    }
    notifyListeners();
    unawaited(_trySaveNewBand());
  }

  /// A band paired while the phone was offline (or the save failed) is
  /// remembered here and saved as soon as the network allows.
  String? _unsavedBandId;

  Future<void> _trySaveNewBand() async {
    final id = _unsavedBandId;
    if (id == null || isDisposed) return;
    try {
      await _repo.saveWearable(patientId, WearableDevice(id, ArmBandProtocol.advertisedName, 3, null));
      if (_unsavedBandId == id) _unsavedBandId = null;
    } catch (_) {
      // Still offline: the heartbeat will try again.
    }
  }

  void cancelSearch() {
    _stopRetrying();
    _attempt++; // any in-flight scan/connect's result is now ignored
    unawaited(_ble.disconnect());
    state = WearableConnState.disconnected;
    notifyListeners();
  }

  /// Called by the Profile screen after [Forget wearable] deletes the
  /// paired row, so Home's status chip drops to Disconnected immediately
  /// rather than waiting for its next fetch. Also drops the real BLE link
  /// and forgets which device to reconnect to next time.
  void forget() {
    _stopRetrying();
    _attempt++;
    _deviceId = null;
    unawaited(_ble.disconnect());
    state = WearableConnState.disconnected;
    batteryPercent = null;
    notifyListeners();
  }

  // ---- live presence, for the clinic portal ----------------------------

  /// How often to tell the portal the link is still up. The portal counts a
  /// band as live for 45 s after the last report, so this leaves room for two
  /// missed beats.
  static const _heartbeat = Duration(seconds: 15);
  Timer? _presenceTimer;

  /// Starts/stops reporting. Called from every place [state] changes to or
  /// from connected, so the portal's view follows the real BLE link.
  void _syncPresence() {
    if (isDisposed) return;
    if (isConnected) {
      if (_presenceTimer != null) return;
      unawaited(_repo.reportWearablePresence(true));
      _presenceTimer = Timer.periodic(_heartbeat, (_) {
        unawaited(_repo.reportWearablePresence(true));
        unawaited(_trySaveNewBand());
      });
    } else if (_presenceTimer != null) {
      _presenceTimer!.cancel();
      _presenceTimer = null;
      unawaited(_repo.reportWearablePresence(false));
    }
  }

  @override
  void notifyListeners() {
    _syncPresence();
    super.notifyListeners();
  }

  bool isDisposed = false;

  @override
  void dispose() {
    _retryTimer?.cancel();
    final wasReporting = _presenceTimer != null;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    if (wasReporting) unawaited(_repo.reportWearablePresence(false));
    isDisposed = true;
    _attempt++;
    _ble.dispose();
    super.dispose();
  }
}
