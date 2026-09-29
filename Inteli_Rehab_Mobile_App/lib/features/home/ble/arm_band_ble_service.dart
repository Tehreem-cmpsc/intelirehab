import 'dart:async';
import 'dart:io';

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

class ArmBandNotFound extends ArmBandException {
  const ArmBandNotFound() : super("No band found nearby. Make sure it's switched on.");
}

class ArmBandProtocolMismatch extends ArmBandException {
  const ArmBandProtocolMismatch()
      : super("This device doesn't look like an Inteli Band — its Bluetooth service didn't match.");
}

/// The real BLE central for the arm band — Communication Layer (SDD §3.1.2),
/// matched against firmware/lib/BLEStreamer.cpp's GATT profile
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

  final _samples = StreamController<ArmBandSample>.broadcast();
  final _connectionState = StreamController<BluetoothConnectionState>.broadcast();

  /// Live sensor readings — empty until a device is connected and has
  /// started notifying.
  Stream<ArmBandSample> get samples => _samples.stream;

  /// Fires on every connect/disconnect, including one the band itself
  /// initiated (out of range, powered off) — not just ones this app asked
  /// for.
  Stream<BluetoothConnectionState> get connectionState => _connectionState.stream;

  bool get isConnected => _device != null;

  /// The connected device's id (== wearable_devices.serial_no), if any.
  String? get connectedDeviceId => _device?.remoteId.str;

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
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    final results = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return (results[Permission.bluetoothScan]?.isGranted ?? true) &&
        (results[Permission.bluetoothConnect]?.isGranted ?? true);
  }

  /// Scans for nearby bands (filtered to [ArmBandProtocol.serviceUuid], so
  /// nothing else nearby ever shows up), emitting the accumulated list as
  /// more are found. Runs until the caller cancels their subscription —
  /// the UI decides how long to show a spinner before that.
  Stream<List<ArmBandScanResult>> scan() async* {
    if (!await requestPermissions()) throw const ArmBandPermissionDenied();
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      throw const ArmBandBluetoothOff();
    }
    if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();

    final seen = <String, ArmBandScanResult>{};
    try {
      await FlutterBluePlus.startScan(
        withServices: [ArmBandProtocol.serviceUuid],
        timeout: const Duration(seconds: 30), // a battery-saving cap on the radio itself
      );
      await for (final results in FlutterBluePlus.onScanResults) {
        for (final r in results) {
          seen[r.device.remoteId.str] = ArmBandScanResult(
            id: r.device.remoteId.str,
            name: r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : ArmBandProtocol.advertisedName,
            rssi: r.rssi,
          );
        }
        yield seen.values.toList(growable: false);
      }
    } finally {
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
    }
  }

  /// Connects to the given band, discovers its service, and starts
  /// notifying [samples]. Throws [ArmBandProtocolMismatch] if it connects
  /// to something that doesn't have our GATT service — a stale/wrong
  /// device id saved from a previous pairing, say.
  Future<void> connect(String deviceId, {Duration timeout = const Duration(seconds: 12)}) async {
    await disconnect();
    if (!await requestPermissions()) throw const ArmBandPermissionDenied();

    final device = BluetoothDevice.fromId(deviceId);
    // flutter_blue_plus 2.x requires declaring which of its own license
    // terms this use falls under (see License's doc comments) — nonprofit
    // covers personal/nonprofit/educational use. This is an academic
    // project (docs/sdd, docs/srs, docs/presentations), so that's this
    // choice; switch to License.commercial (a paid license from the
    // package's author) if Inteli Rehab is ever sold/operated commercially.
    await device.connect(license: License.nonprofit, timeout: timeout, autoConnect: false);

    try {
      final services = await device.discoverServices();
      final service = services.where((s) => s.uuid == ArmBandProtocol.serviceUuid).firstOrNull;
      if (service == null) throw const ArmBandProtocolMismatch();

      final dataChar = service.characteristics.where((c) => c.uuid == ArmBandProtocol.dataCharUuid).firstOrNull;
      final cmdChar = service.characteristics.where((c) => c.uuid == ArmBandProtocol.cmdCharUuid).firstOrNull;
      if (dataChar == null || cmdChar == null) throw const ArmBandProtocolMismatch();

      await dataChar.setNotifyValue(true);
      _dataSub = dataChar.onValueReceived.listen((bytes) {
        final sample = ArmBandSample.tryParse(bytes);
        if (sample != null) _samples.add(sample);
      });
      _connSub = device.connectionState.listen((state) {
        _connectionState.add(state);
        if (state == BluetoothConnectionState.disconnected) _teardown();
      });

      _device = device;
      _cmdChar = cmdChar;
    } catch (_) {
      await device.disconnect();
      rethrow;
    }
  }

  /// Sends one calibration command — see [ArmBandCommand].
  Future<void> sendCommand(ArmBandCommand command) async {
    final c = _cmdChar;
    if (c == null) throw StateError('sendCommand called with no band connected.');
    await c.write(command.bytes, withoutResponse: false);
  }

  Future<void> disconnect() async {
    final device = _device;
    _teardown();
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {
        // Already gone (out of range, powered off) — nothing more to do.
      }
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
    disconnect();
    _samples.close();
    _connectionState.close();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
