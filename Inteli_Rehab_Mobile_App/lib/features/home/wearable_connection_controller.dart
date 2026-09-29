import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' show BluetoothConnectionState;

import '../onboarding/onboarding_data.dart';
import '../onboarding/onboarding_repository.dart';
import 'ble/arm_band_ble_service.dart';
import 'ble/arm_band_protocol.dart';

enum WearableConnState { connected, calibrating, disconnected, searching }

/// A stable pseudo-battery from the serial, so it doesn't flicker between
/// rebuilds — placeholder until real telemetry exists. The firmware's own
/// GATT profile (ArmBandProtocol) has no battery characteristic yet, so
/// this stays simulated even though the connection itself is now real;
/// shared by the Home screen's status chip and the Profile screen's
/// wearable section, so they never disagree.
int simulatedWearableBattery(String serial) {
  final hash = serial.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0x7fffffff);
  return 35 + (hash % 65); // 35–99%
}

/// Communication Layer (SDD §3.1.2) — the app-side half of BLE pairing and
/// connection state, matched against firmware/lib/BLEStreamer.cpp's real
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
  int? batteryPercent;
  String? lastError;

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
        _deviceId = deviceSerial,
        state = WearableConnState.disconnected,
        batteryPercent = null {
    _ble.connectionState.listen(_onBleConnectionChanged);
    // Being "paired" only means a database row exists — the BLE link
    // itself never survives an app restart, so it has to be re-established
    // for real, not assumed.
    if (initiallyPaired && deviceSerial != null) _autoReconnect(deviceSerial);
  }

  bool get isConnected => state == WearableConnState.connected;

  /// The live sensor stream, once connected — exposed for whatever reads
  /// it next (e.g. a future Active Session redesign that consumes real
  /// data instead of SessionSimulator's synthetic one); nothing in this
  /// pass subscribes to it itself.
  Stream<ArmBandSample> get liveSamples => _ble.samples;

  void _onBleConnectionChanged(BluetoothConnectionState bleState) {
    if (bleState == BluetoothConnectionState.disconnected && state == WearableConnState.connected) {
      // The band dropped on its own — out of range or powered off, not
      // something this app asked for.
      state = WearableConnState.disconnected;
      batteryPercent = null;
      notifyListeners();
    }
  }

  Future<void> _autoReconnect(String deviceId) async {
    final attempt = ++_attempt;
    state = WearableConnState.searching;
    notifyListeners();
    try {
      await _ble.connect(deviceId);
      if (attempt != _attempt) return; // superseded by forget()/a newer attempt
      batteryPercent = simulatedWearableBattery(deviceId);
      state = WearableConnState.connected;
    } catch (_) {
      // Quiet on launch — the band just wasn't in range yet. Home's
      // ambient "Wearable not connected" card (Rule 17) is what tells the
      // patient, not an error dialog they didn't ask for.
      if (attempt != _attempt) return;
      state = WearableConnState.disconnected;
    }
    notifyListeners();
  }

  /// Reconnects to the remembered band, or — if none is remembered yet —
  /// scans and pairs with the first one found (this app only ever manages
  /// one band at a time).
  Future<void> reconnect() async {
    final attempt = ++_attempt;
    lastError = null;
    state = WearableConnState.searching;
    notifyListeners();

    try {
      var targetId = _deviceId;
      if (targetId == null) {
        final found = await _ble
            .scan()
            .firstWhere((results) => results.isNotEmpty, orElse: () => const <ArmBandScanResult>[])
            .timeout(const Duration(seconds: 15), onTimeout: () => const <ArmBandScanResult>[]);
        if (attempt != _attempt) return;
        if (found.isEmpty) throw const ArmBandNotFound();
        targetId = found.first.id;
      }

      state = WearableConnState.calibrating; // the connect+service-discovery handshake
      notifyListeners();

      await _ble.connect(targetId);
      if (attempt != _attempt) return;

      await _repo.saveWearable(patientId, WearableDevice(targetId, ArmBandProtocol.advertisedName, 3, null));
      _deviceId = targetId;
      batteryPercent = simulatedWearableBattery(targetId);
      state = WearableConnState.connected;
    } on ArmBandException catch (e) {
      if (attempt != _attempt) return;
      lastError = e.message;
      state = WearableConnState.disconnected;
      batteryPercent = null;
    } catch (_) {
      if (attempt != _attempt) return;
      lastError = "Couldn't connect to your band. Check it's charged and nearby.";
      state = WearableConnState.disconnected;
      batteryPercent = null;
    }
    notifyListeners();
  }

  void cancelSearch() {
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
    _attempt++;
    _deviceId = null;
    unawaited(_ble.disconnect());
    state = WearableConnState.disconnected;
    batteryPercent = null;
    notifyListeners();
  }

  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    _attempt++;
    _ble.dispose();
    super.dispose();
  }
}
