import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// The arm band's real GATT profile — must match
/// firmware/lib/BLEStreamer.cpp exactly, on both sides, or the phone and
/// the band simply can't find each other. These are this project's own
/// arbitrary 128-bit UUIDs (not a standard BLE profile).
class ArmBandProtocol {
  ArmBandProtocol._();

  /// firmware/lib/ArmEMG_IMU.ino's BLE_DEVICE_NAME — the advertised name
  /// scan results are filtered to, so an unrelated nearby BLE device never
  /// shows up as a "band".
  static const advertisedName = 'ArmEMG-IMU';

  static final serviceUuid = Guid('a1b2c3d0-0001-4000-8000-00805f9b34fb');

  /// NOTIFY — the 16-byte sensor packet, ~31 Hz while connected.
  static final dataCharUuid = Guid('a1b2c3d0-0002-4000-8000-00805f9b34fb');

  /// WRITE — single-byte calibration commands (see [Command]).
  static final cmdCharUuid = Guid('a1b2c3d0-0003-4000-8000-00805f9b34fb');
}

/// firmware/lib/ArmEMG_IMU.ino's handleCommand() — the only three bytes it
/// recognises.
enum ArmBandCommand {
  /// 'g' — recalibrate gyro bias. Hold the band still.
  recalibrateGyro('g'),

  /// 'z' — set the current pose as the zero-angle reference. Arm fully
  /// extended, hanging relaxed.
  setZeroPose('z'),

  /// 'm' — start a 5 s max-voluntary-contraction window on all 3 EMG
  /// channels (contract as hard as possible), so activation afterwards is
  /// reported as %MVC.
  startMvcCalibration('m');

  final String _byte;
  const ArmBandCommand(this._byte);
  List<int> get bytes => _byte.codeUnits;
}

/// One sample off the band's data characteristic — firmware's
/// `SensorPacket` struct, decoded. elbowDeg is the real joint angle from
/// the two IMUs' relative orientation (Madgwick fusion done on-device);
/// the three EMG percentages are %MVC, meaningful once a max-voluntary-
/// contraction calibration ([ArmBandCommand.startMvcCalibration]) has run.
class ArmBandSample {
  final double elbowDeg;
  final double emg1Pct;
  final double emg2Pct;
  final double emg3Pct;

  const ArmBandSample({
    required this.elbowDeg,
    required this.emg1Pct,
    required this.emg2Pct,
    required this.emg3Pct,
  });

  /// Parses firmware's `__attribute__((packed)) SensorPacket`: 4
  /// little-endian float32s, no padding — 16 bytes total. Returns null for
  /// anything else (a malformed notify should never crash the session).
  static ArmBandSample? tryParse(List<int> bytes) {
    if (bytes.length != 16) return null;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return ArmBandSample(
      elbowDeg: data.getFloat32(0, Endian.little),
      emg1Pct: data.getFloat32(4, Endian.little),
      emg2Pct: data.getFloat32(8, Endian.little),
      emg3Pct: data.getFloat32(12, Endian.little),
    );
  }
}

/// One band seen during a scan — everything the pairing UI needs, already
/// stripped of flutter_blue_plus's own types so nothing outside this
/// folder needs to import the plugin.
class ArmBandScanResult {
  final String id; // device.remoteId.str — this project's serial_no
  final String name;
  final int rssi;
  const ArmBandScanResult({required this.id, required this.name, required this.rssi});

  /// 0–3 bars, the same scale WearableDevice.signal already used for the
  /// mock catalogue — real RSSI now instead of a fixed mock value.
  int get signalBars => switch (rssi) {
        > -60 => 3,
        > -75 => 2,
        > -90 => 1,
        _ => 0,
      };
}
