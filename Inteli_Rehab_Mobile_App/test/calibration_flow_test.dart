// The guided calibration, end to end, against a simulated band: the commands
// it sends, the order of the steps, what it records, and how it fails.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/home/ble/arm_band_ble_service.dart';
import 'package:inteli_rehab_mobile_app/features/home/ble/arm_band_protocol.dart';
import 'package:inteli_rehab_mobile_app/features/onboarding/onboarding_data.dart';
import 'package:inteli_rehab_mobile_app/features/onboarding/steps/calibration_step.dart';

/// A band that records the commands it is sent and plays back whatever the test emits.
class FakeBand extends ArmBandBleService {
  final sent = <ArmBandCommand>[];
  final _out = StreamController<ArmBandSample>.broadcast();
  bool failCommands = false;

  @override
  Stream<ArmBandSample> get samples => _out.stream;

  @override
  bool get isConnected => true;

  @override
  Future<void> sendCommand(ArmBandCommand command) async {
    if (failCommands) throw StateError('write failed');
    sent.add(command);
  }

  void emit(double angle, {double emg = 0}) => _out.add(ArmBandSample(elbowDeg: angle, emg1Pct: emg));
}

Future<({OnboardingData data, FakeBand band})> _start(WidgetTester tester, {BaselineReading? baseline}) async {
  final band = FakeBand();
  final data = OnboardingData()
    ..wearable = const WearableDevice('24:6F:28:AA:BB:CC', 'ArmEMG-IMU', 3, null)
    ..affectedSide = 'left'
    ..baseline = baseline
    ..baselineSaved = baseline != null
    ..band = band;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: CalibrationStep(data: data, onBackToWearable: () {}),
      ),
    ),
  ));
  return (data: data, band: band);
}

/// Plays [seconds] of band readings (about 30 per second), one value per call.
Future<void> _play(WidgetTester tester, double seconds, double Function(double t) angle,
    FakeBand band, {double Function(double t)? emg}) async {
  var t = 0.0;
  while (t < seconds) {
    band.emit(angle(t), emg: emg?.call(t) ?? 0);
    await tester.pump(const Duration(milliseconds: 50));
    t += 0.05;
  }
}

/// EMG during the muscle step: squeezing hard for the 5 s window, relaxed after it.
double _squeezeThenRelax(double t) => t < 5.0 ? 100 : 3;

/// One slow bend: 0 -> [peak] -> 0 over [seconds].
double _bend(double t, double seconds, double peak) {
  final x = (t % seconds) / seconds;
  return peak * (x < 0.5 ? x * 2 : (1 - x) * 2);
}

void main() {
  testWidgets('runs every step in order and records the baseline', (tester) async {
    final (:data, :band) = await _start(tester);
    expect(find.text("I'm ready — start"), findsOneWidget);
    expect(find.textContaining('Calibrate later'), findsNothing, reason: 'calibration is compulsory');

    await tester.tap(find.text("I'm ready — start"));
    await tester.pump();
    expect(band.sent, [ArmBandCommand.recalibrateGyro], reason: 'sensors first');
    expect(find.text('Calibrating your sensors'), findsOneWidget);

    await _play(tester, 3.3, (_) => 0, band); // arm still while the gyros settle
    expect(band.sent.last, ArmBandCommand.setZeroPose, reason: 'then the zero pose');
    await _play(tester, 0.6, (_) => 0, band);
    expect(find.text('Hold still'), findsOneWidget);

    await _play(tester, 5.3, (_) => 2, band); // hold at ~2 degrees
    expect(find.textContaining('Move slowly'), findsOneWidget);

    // Three bends to ~80 degrees. Nothing is asked of the muscle until they're done.
    await _play(tester, 3 * 2.2, (t) => 2 + _bend(t, 2.0, 80), band);
    expect(band.sent.last, ArmBandCommand.startMvcCalibration, reason: 'muscle squeeze after the movements');
    expect(find.text('Squeeze as hard as you can'), findsOneWidget);
    expect(data.baseline, isNull, reason: 'not recorded until the muscle step passes too');

    await _play(tester, 5.8, (_) => 2, band, emg: _squeezeThenRelax); // the maximum squeeze, then relaxing
    expect(find.text('Now squeeze about half as hard'), findsOneWidget);

    await _play(tester, 1.0, (_) => 2, band, emg: (_) => 55); // the lighter test squeeze
    expect(find.text('Calibration complete'), findsOneWidget);

    expect(band.sent, [
      ArmBandCommand.recalibrateGyro,
      ArmBandCommand.setZeroPose,
      ArmBandCommand.startMvcCalibration,
    ]);
    final b = data.baseline!;
    expect(b.flexion, closeTo(82, 6), reason: 'furthest reach of the bends');
    expect(b.extension, closeTo(2, 3), reason: 'starting point');
    expect(b.range, closeTo(80, 8));
    expect(data.musclesCalibrated, isTrue);
  });

  testWidgets('a band that reports no movement gets a hint, then the attempt ends', (tester) async {
    final (:data, :band) = await _start(tester);
    await tester.tap(find.text("I'm ready — start"));
    await tester.pump();
    await _play(tester, 3.3 + 0.6 + 5.3, (_) => 0, band);
    expect(find.textContaining('Move slowly'), findsOneWidget);

    await _play(tester, 9, (_) => 0, band); // angle never changes
    expect(find.textContaining("We aren't seeing your arm move"), findsOneWidget);

    await _play(tester, 40, (_) => 0, band);
    expect(find.textContaining("didn't detect any movement"), findsOneWidget, reason: 'times out back to the intro');
    expect(data.baseline, isNull);
    expect(find.text("I'm ready — start"), findsOneWidget, reason: 'and can be tried again');
  });

  testWidgets('a muscle that never responds can retry but cannot skip', (tester) async {
    final (:data, :band) = await _start(tester);
    await tester.tap(find.text("I'm ready — start"));
    await tester.pump();
    await _play(tester, 3.9 + 5.3, (_) => 2, band);
    await _play(tester, 3 * 2.2, (t) => 2 + _bend(t, 2.0, 80), band);
    await _play(tester, 5.8, (_) => 2, band, emg: _squeezeThenRelax);
    expect(find.text('Now squeeze about half as hard'), findsOneWidget);

    for (var attempt = 1; attempt <= 3; attempt++) {
      await _play(tester, 6.5, (_) => 2, band, emg: (_) => 4); // the sensor never reads a squeeze
      expect(find.text('Try the muscle step again'), findsOneWidget, reason: 'attempt $attempt');
      expect(find.text('Continue without confirming'), findsNothing, reason: 'there is no way round it');
      expect(data.baseline, isNull);
      await tester.tap(find.text('Try the muscle step again'));
      await tester.pump();
      expect(band.sent.last, ArmBandCommand.startMvcCalibration, reason: 'each retry restarts the squeeze window');
      await _play(tester, 5.8, (_) => 2, band, emg: _squeezeThenRelax);
    }

    await _play(tester, 1.0, (_) => 2, band, emg: (_) => 60); // finally it responds
    expect(find.text('Calibration complete'), findsOneWidget);
    expect(data.baseline, isNotNull);
  });

  testWidgets('if the band cannot be reached, it says so and nothing is recorded', (tester) async {
    final (:data, :band) = await _start(tester);
    band.failCommands = true;
    await tester.tap(find.text("I'm ready — start"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining("Couldn't reach your band"), findsOneWidget);
    expect(data.baseline, isNull);
  });

  testWidgets('a tail-end squeeze does not pass the check; it must relax first', (tester) async {
    final (:data, :band) = await _start(tester);
    await tester.tap(find.text("I'm ready — start"));
    await tester.pump();
    await _play(tester, 3.9 + 5.3, (_) => 2, band);
    await _play(tester, 3 * 2.2, (t) => 2 + _bend(t, 2.0, 80), band);
    await _play(tester, 5.7, (_) => 2, band, emg: (_) => 100); // still squeezing when the check starts
    await _play(tester, 0.5, (_) => 2, band, emg: (_) => 100);
    expect(data.baseline, isNull, reason: 'a muscle that never relaxes has not shown it responds');
    await _play(tester, 0.4, (_) => 2, band, emg: (_) => 3); // relaxes...
    await _play(tester, 0.5, (_) => 2, band, emg: (_) => 60); // ...then squeezes
    expect(find.text('Calibration complete'), findsOneWidget);
  });

  testWidgets('redo clears the result, and a redo is saved again', (tester) async {
    final (:data, band: _) = await _start(
      tester,
      baseline: const BaselineReading(neutral: 2, flexion: 80, extension: 2),
    );
    expect(find.text('Calibration complete'), findsOneWidget);
    await tester.tap(find.text('Redo calibration'));
    await tester.pump();
    expect(data.baseline, isNull);
    expect(data.baselineSaved, isFalse, reason: 'otherwise the new baseline would never be saved');
    expect(find.text("I'm ready — start"), findsOneWidget);
  });
}
