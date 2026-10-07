import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'arm_band_protocol.dart';

sealed class ArmBandException implements Exception {
  final String message;
  const ArmBandException(this.message);
  @override
  String toString() => message;
}

class ArmBandPermissionDenied extends ArmBandException {
  const ArmBandPermissionDenied() : super('Bluetooth permission is needed to connect your band.');
}

class ArmBandBluetoothOff extends ArmBandException {
  const ArmBandBluetoothOff() : super('Turn on Bluetooth to connect your band.');
}

/// Bluetooth LE to the band is only wired up for Android and iOS (the BLE
/// plugin has no Windows support, and the web build has no Web Bluetooth
/// path). Reported plainly instead of failing as a generic connect error.
class ArmBandUnsupportedPlatform extends ArmBandException {
  const ArmBandUnsupportedPlatform()
      : super("Connecting the band needs the Android or iOS app - Bluetooth to the band isn't available on this device.");
}

/// The band connected but then stopped answering mid-setup.
class ArmBandStepTimeout extends ArmBandException {
  const ArmBandStepTimeout(String step)
      : super("Your band connected but didn't respond while $step. Switch it off and on, then try again.");
}

class ArmBandNotFound extends ArmBandException {
  const ArmBandNotFound() : super("No band found nearby. Make sure it's switched on.");
}

class ArmBandProtocolMismatch extends ArmBandException {
  const ArmBandProtocolMismatch()
      : super("This device doesn't look like an Inteli Band — its Bluetooth service didn't match.");
}

/// A newer connect/disconnect request replaced this one while it was still
/// in flight. Not an error the patient should see.
class ArmBandSuperseded extends ArmBandException {
  const ArmBandSuperseded() : super('Connection attempt was replaced by a newer one.');
}

/// The real BLE central for the arm band — Communication Layer (SDD §3.1.2),
/// matched against firmware/lib/ArmEMG_IMU/BLEStreamer.cpp's GATT profile
/// (ArmBandProtocol). One instance manages exactly one connection at a
/// time, same as the single-band model the rest of the app already
/// assumes (WearableConnectionController).
///
/// Everything here is real: this is not a simulation to be swapped out
/// later, unlike SessionSimulator's Intelligence & Processing Layer
/// stand-ins — a genuine BLE connection to real firmware.
class ArmBandBleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _cmdChar;
  StreamSubscription<List<int>>? _dataSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  /// Bumped by every connect()/disconnect()/dispose(). A connect() that
  /// finds it changed while it was waiting knows it has been superseded and
  /// backs out - so overlapping attempts (auto-retry, manual retry, cancel)
  /// can never leave two data listeners (every sample twice) or a link that
  /// comes up after the patient cancelled.
  int _generation = 0;
  bool _disposed = false;

  final _samples = StreamController<ArmBandSample>.broadcast();
  final _connectionState = StreamController<BluetoothConnectionState>.broadcast();

  /// Live sensor readings — empty until a device is connected and has
  /// started notifying.
  Stream<ArmBandSample> get samples => _samples.stream;

  /// Fires on every connect/disconnect, including one the band itself
  /// initiated (out of range, powered off) — not just ones this app asked
  /// for.
  Stream<BluetoothConnectionState> get connectionState => _connectionState.stream;

  /// Plain-language stage updates ("Searching...", "Connecting...") for the
  /// UI, so a slow step reads as progress rather than a frozen spinner.
  void Function(String stage)? onProgress;

  bool get isConnected => _device != null;

  /// The connected device's id (== wearable_devices.serial_no), if any.
  String? get connectedDeviceId => _device?.remoteId.str;

  /// Whether [id] can be a real BLE device id: a MAC address (Android) or a
  /// UUID (iOS). Saved band ids from before pairing was real (e.g. the
  /// simulated "IR-A1F3" serials) are neither, and the OS rejects them
  /// outright, so callers must treat them as "no band remembered".
  static bool isValidDeviceId(String id) =>
      RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$').hasMatch(id) ||
      RegExp(r'^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$').hasMatch(id);

  /// Runtime permissions BLE scanning needs. Android 12+'s BLUETOOTH_SCAN/
  /// BLUETOOTH_CONNECT are requested unconditionally — they gate the
  /// result on that OS version and are normal (auto-granted, no dialog) on
  /// older ones. Location is requested best-effort alongside them for
  /// Android <12, where the OS additionally requires it for BLE scanning
  /// specifically (nothing to do with this app reading location) — but
  /// isn't required for this method to report success, since on Android
  /// 12+ or iOS a location prompt may not appear at all and would
  /// otherwise incorrectly read as "denied".
  Future<bool> requestPermissions() async {
    _ensureSupportedPlatform();
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return (results[Permission.bluetoothScan]?.isGranted ?? true) &&
        (results[Permission.bluetoothConnect]?.isGranted ?? true);
  }

  void _ensureSupportedPlatform() {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) throw const ArmBandUnsupportedPlatform();
  }

  /// Throws [ArmBandBluetoothOff] if the radio is off. Right after launch or
  /// a permission grant the adapter can briefly report `unknown` (notably on
  /// iOS); that is waited out rather than mistaken for "off".
  Future<void> _ensureBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState
        .firstWhere((s) => s != BluetoothAdapterState.unknown)
        .timeout(const Duration(seconds: 3), onTimeout: () => BluetoothAdapterState.unknown);
    if (state == BluetoothAdapterState.off || state == BluetoothAdapterState.unavailable) {
      throw const ArmBandBluetoothOff();
    }
  }

  /// Scans for nearby bands (filtered to [ArmBandProtocol.serviceUuid], so
  /// nothing else nearby ever shows up), emitting the accumulated list as
  /// more are found. Runs until the caller cancels their subscription —
  /// the UI decides how long to show a spinner before that.
  ///
  /// Built on a StreamController rather than `async*`: an async* generator
  /// waiting on the plugin's results stream can't be cancelled until that
  /// stream next emits, so with no band in range, cancelling (the 15 s
  /// timeout in [findStrongest]) never completed and the UI spun forever.
  Stream<List<ArmBandScanResult>> scan() {
    late final StreamController<List<ArmBandScanResult>> controller;
    StreamSubscription<List<ScanResult>>? resultsSub;
    final seen = <String, ArmBandScanResult>{};

    Future<void> stop() async {
      try {
        if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
      } catch (_) {
        // Nothing useful to do if the radio refuses to stop.
      }
    }

    Future<void> begin() async {
      try {
        if (!await requestPermissions()) throw const ArmBandPermissionDenied();
        await _ensureBluetoothOn();
        await stop();
        if (controller.isClosed) return;
        resultsSub = FlutterBluePlus.onScanResults.listen((results) {
          for (final r in results) {
            seen[r.device.remoteId.str] = ArmBandScanResult(
              id: r.device.remoteId.str,
              name: r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : ArmBandProtocol.advertisedName,
              rssi: r.rssi,
            );
          }
          if (!controller.isClosed) controller.add(seen.values.toList(growable: false));
        });
        onProgress?.call('Searching for your band...');
        await FlutterBluePlus.startScan(
          withServices: [ArmBandProtocol.serviceUuid],
          timeout: const Duration(seconds: 30), // a battery-saving cap on the radio itself
        );
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    controller = StreamController<List<ArmBandScanResult>>(
      onListen: () => unawaited(begin()),
      onCancel: () async {
        await resultsSub?.cancel();
        await stop();
      },
    );
    return controller.stream;
  }

  /// Scans and returns the strongest-signal band, or throws
  /// [ArmBandNotFound] if none turns up within [timeout]. After the first
  /// band appears it keeps listening briefly so a closer band that is a
  /// beat slower to advertise still wins - several bands in a clinic all
  /// advertise the same name and service, so "first seen" is a coin toss.
  /// The scan subscription is always cancelled (a plain `firstWhere` with
  /// `.timeout` leaves it running).
  Future<ArmBandScanResult> findStrongest({
    Duration timeout = const Duration(seconds: 15),
    Duration settle = const Duration(milliseconds: 1500),
  }) async {
    final done = Completer<void>();
    List<ArmBandScanResult> best = const [];
    Timer? settleTimer;
    final overall = Timer(timeout, () {
      if (!done.isCompleted) done.complete();
    });
    final sub = scan().listen(
      (results) {
        best = results;
        if (results.isNotEmpty) {
          settleTimer ??= Timer(settle, () {
            if (!done.isCompleted) done.complete();
          });
        }
      },
      onError: (Object e, StackTrace st) {
        if (!done.isCompleted) done.completeError(e, st);
      },
    );
    try {
      await done.future;
    } finally {
      overall.cancel();
      settleTimer?.cancel();
      await sub.cancel();
    }
    if (best.isEmpty) throw const ArmBandNotFound();
    return best.reduce((a, b) => b.rssi > a.rssi ? b : a);
  }

  /// Connects to the given band, discovers its service, and starts
  /// notifying [samples]. Throws [ArmBandProtocolMismatch] if it connects
  /// to something that doesn't have our GATT service — a stale/wrong
  /// device id saved from a previous pairing, say. Throws
  /// [ArmBandSuperseded] if a newer connect/disconnect replaced this call.
  Future<void> connect(String deviceId, {Duration timeout = const Duration(seconds: 12)}) async {
    final generation = ++_generation;
    bool stale() => generation != _generation || _disposed;

    await _disconnectCurrent();
    if (!await requestPermissions()) throw const ArmBandPermissionDenied();
    await _ensureBluetoothOn();
    if (stale()) throw const ArmBandSuperseded();

    onProgress?.call('Connecting to your band...');
    final device = BluetoothDevice.fromId(deviceId);
    // flutter_blue_plus 2.x requires declaring which of its own license
    // terms this use falls under (see License's doc comments) — nonprofit
    // covers personal/nonprofit/educational use. This is an academic
    // project (docs/sdd, docs/srs, docs/presentations), so that's this
    // choice; switch to License.commercial (a paid license from the
    // package's author) if Inteli Rehab is ever sold/operated commercially.
    await device.connect(license: License.nonprofit, timeout: timeout, autoConnect: false);
    if (stale()) {
      await _quietDisconnect(device);
      throw const ArmBandSuperseded();
    }

    try {
      onProgress?.call('Setting up the connection...');
      final services = await device.discoverServices().timeout(const Duration(seconds: 10),
          onTimeout: () => throw const ArmBandStepTimeout('finding its services'));
      if (stale()) throw const ArmBandSuperseded();
      final service = services.where((s) => s.uuid == ArmBandProtocol.serviceUuid).firstOrNull;
      if (service == null) throw const ArmBandProtocolMismatch();

      final dataChar = service.characteristics.where((c) => c.uuid == ArmBandProtocol.dataCharUuid).firstOrNull;
      final cmdChar = service.characteristics.where((c) => c.uuid == ArmBandProtocol.cmdCharUuid).firstOrNull;
      if (dataChar == null || cmdChar == null) throw const ArmBandProtocolMismatch();

      await dataChar.setNotifyValue(true).timeout(const Duration(seconds: 8),
          onTimeout: () => throw const ArmBandStepTimeout('starting its data stream'));
      if (stale()) throw const ArmBandSuperseded();

      // Only now, with this attempt still the current one, take ownership.
      await _dataSub?.cancel();
      await _connSub?.cancel();
      _dataSub = dataChar.onValueReceived.listen((bytes) {
        final sample = ArmBandSample.tryParse(bytes);
        if (sample != null && !_samples.isClosed) _samples.add(sample);
      });
      _connSub = device.connectionState.listen((state) {
        if (!_connectionState.isClosed) _connectionState.add(state);
        if (state == BluetoothConnectionState.disconnected && identical(_device, device)) _teardown();
      });

      _device = device;
      _cmdChar = cmdChar;
    } catch (_) {
      await _quietDisconnect(device);
      rethrow;
    }
  }

  /// Sends one calibration command — see [ArmBandCommand].
  Future<void> sendCommand(ArmBandCommand command) async {
    final c = _cmdChar;
    if (c == null) throw StateError('sendCommand called with no band connected.');
    await c.write(command.bytes, withoutResponse: false);
  }

  /// Drops the link, and abandons any connect() that is still in flight.
  Future<void> disconnect() {
    _generation++;
    return _disconnectCurrent();
  }

  Future<void> _disconnectCurrent() async {
    final device = _device;
    _teardown();
    if (device != null) await _quietDisconnect(device);
  }

  Future<void> _quietDisconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {
      // Already gone (out of range, powered off) — nothing more to do.
    }
  }

  void _teardown() {
    _dataSub?.cancel();
    _dataSub = null;
    _connSub?.cancel();
    _connSub = null;
    _device = null;
    _cmdChar = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _samples.close();
    _connectionState.close();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
