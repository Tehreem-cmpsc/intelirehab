// Locks down ArmBandSample.tryParse against firmware/lib/BLEStreamer.cpp's
// actual wire format — a byte-order or field-order mistake here would
// silently corrupt every real reading with no error to surface it.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/features/home/ble/arm_band_protocol.dart';

/// Packs floats the same way firmware's `__attribute__((packed))
/// SensorPacket` does: 4 little-endian float32s, no padding.
List<int> _packet(double elbowDeg, double emg1, double emg2, double emg3) {
  final data = ByteData(16)
    ..setFloat32(0, elbowDeg, Endian.little)
    ..setFloat32(4, emg1, Endian.little)
    ..setFloat32(8, emg2, Endian.little)
    ..setFloat32(12, emg3, Endian.little);
  return data.buffer.asUint8List();
}

void main() {
  group('ArmBandSample.tryParse', () {
    test('decodes a well-formed 16-byte packet in field order', () {
      final sample = ArmBandSample.tryParse(_packet(87.5, 12.0, 43.25, 91.0));
      expect(sample, isNotNull);
      expect(sample!.elbowDeg, closeTo(87.5, 0.01));
      expect(sample.emg1Pct, closeTo(12.0, 0.01));
      expect(sample.emg2Pct, closeTo(43.25, 0.01));
      expect(sample.emg3Pct, closeTo(91.0, 0.01));
    });

    test('rejects anything that is not exactly 16 bytes', () {
      expect(ArmBandSample.tryParse([]), isNull);
      expect(ArmBandSample.tryParse(List.filled(15, 0)), isNull);
      expect(ArmBandSample.tryParse(List.filled(17, 0)), isNull);
    });

    test('is big-endian-safe: swapping byte order changes the value', () {
      final little = _packet(90, 0, 0, 0);
      final asBigEndian = little.reversed.toList(); // wrong on purpose
      final sample = ArmBandSample.tryParse(asBigEndian);
      // Still parses (right length), just not the same number — proves the
      // test would actually catch an endianness regression.
      expect(sample!.emg3Pct, isNot(closeTo(90, 0.01)));
    });
  });

  group('ArmBandScanResult.signalBars', () {
    const at = ArmBandScanResult(id: 'x', name: 'ArmEMG-IMU', rssi: -55);
    const near = ArmBandScanResult(id: 'x', name: 'ArmEMG-IMU', rssi: -70);
    const far = ArmBandScanResult(id: 'x', name: 'ArmEMG-IMU', rssi: -85);
    const outOfRange = ArmBandScanResult(id: 'x', name: 'ArmEMG-IMU', rssi: -95);

    test('maps RSSI to 0-3 bars, closer is more bars', () {
      expect(at.signalBars, 3);
      expect(near.signalBars, 2);
      expect(far.signalBars, 1);
      expect(outOfRange.signalBars, 0);
    });
  });

  test('ArmBandCommand bytes match the single ASCII byte firmware expects', () {
    expect(ArmBandCommand.recalibrateGyro.bytes, 'g'.codeUnits);
    expect(ArmBandCommand.setZeroPose.bytes, 'z'.codeUnits);
    expect(ArmBandCommand.startMvcCalibration.bytes, 'm'.codeUnits);
  });
}
