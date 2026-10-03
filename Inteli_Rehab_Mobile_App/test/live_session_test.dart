// LiveSession turns the real band's stream into reps, safety calls and
// fatigue. These tests feed it synthetic elbow-angle curves (a smooth lift
// and return, sampled at the band's ~31 Hz) so rep counting and the safety
// rules are pinned down without hardware.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/active_session_screen.dart';
import 'package:inteli_rehab_mobile_app/features/home/wearable_connection_controller.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/live_session.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/processing/fatigue_estimator.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/processing/rep_assessor.dart';
import 'package:inteli_rehab_mobile_app/features/home/ble/arm_band_protocol.dart';

const _exercise = AssignedExercise(
  assignmentId: 'a',
  exerciseId: 'e',
  name: 'Elbow flexion',
  target: null,
  difficulty: 'Beginner',
  description: null,
  sets: 1,
  repsTarget: 5,
  romTarget: 60,
);

/// Full range 150 deg x 60% target = a 90 deg target.
class _Rig {
  final LiveSession session;
  DateTime now = DateTime.utc(2026, 1, 1);
  _Rig({int repsTarget = 5})
      : session = LiveSession(
          repsTarget: repsTarget,
          romTargetPercent: 60,
          samples: const Stream.empty(),
        ) {
    session.start();
  }

  void feed(double angle, {double emg = 0}) {
    session.onSample(ArmBandSample(elbowDeg: angle, emg1Pct: emg), now);
    now = now.add(const Duration(milliseconds: 32)); // ~31 Hz
  }

  void rest([int samples = 6]) {
    for (var i = 0; i < samples; i++) {
      feed(0);
    }
  }

  /// One smooth lift to [peak] degrees and back down over [durationMs].
  void rep({double peak = 90, int durationMs = 2400, double emg = 0}) {
    final n = durationMs ~/ 32;
    for (var i = 0; i <= n; i++) {
      feed(peak * math.sin(math.pi * i / n), emg: emg);
    }
    rest();
  }
}

void main() {
  group('rep counting', () {
    test('counts clean reps, no alerts', () {
      final r = _Rig();
      r.rest();
      for (var i = 0; i < 3; i++) {
        r.rep();
      }
      expect(r.session.repsCompleted, 3);
      expect(r.session.currentTier, SafetyTier.normal);
      expect(r.session.alerts, isEmpty);
    });

    test('ignores small movements entirely', () {
      final r = _Rig();
      r.rest();
      r.rep(peak: 15);
      expect(r.session.repsCompleted, 0);
      expect(r.session.alerts, isEmpty);
    });

    test('a clear attempt that does not get far enough is prompted, not counted', () {
      final r = _Rig();
      r.rest();
      r.rep(peak: 35);
      expect(r.session.repsCompleted, 0);
      expect(r.session.alerts.single.message, contains('more of your range'));
      expect(r.session.currentTier, SafetyTier.needsCorrection);
    });

    test('a countable rep that falls short of the target gets a "reach further" prompt', () {
      final r = _Rig();
      r.rest();
      r.rep(peak: 60); // 67% of the 90 deg target
      expect(r.session.repsCompleted, 1);
      expect(r.session.currentTier, SafetyTier.needsCorrection);
      expect(r.session.alerts.single.message, contains('further'));
    });

    test('stops by itself once the target reps are done', () {
      final r = _Rig(repsTarget: 2);
      r.rest();
      r.rep();
      r.rep();
      expect(r.session.repsCompleted, 2);
      expect(r.session.isRunning, isFalse);
    });

    test('ignores samples while paused', () {
      final r = _Rig();
      r.rest();
      r.session.pause();
      r.rep();
      expect(r.session.repsCompleted, 0);
    });
  });

  group('safety', () {
    test('a rushed rep is told to slow down, without stopping', () {
      final r = _Rig();
      r.rest();
      r.rep(durationMs: 1000);
      expect(r.session.currentTier, SafetyTier.needsCorrection);
      expect(r.session.alerts.single.message, contains('Slow down'));
      expect(r.session.isRunning, isTrue);
    });

    test('a violently fast rep stops the session until acknowledged', () {
      final r = _Rig();
      r.rest();
      r.rep(durationMs: 600);
      expect(r.session.currentTier, SafetyTier.unsafe);
      expect(r.session.awaitingUnsafeAck, isTrue);
      expect(r.session.isRunning, isFalse);

      r.session.acknowledgeUnsafe();
      expect(r.session.awaitingUnsafeAck, isFalse);
      expect(r.session.isRunning, isTrue);
    });

    test('the elbow going well past full range stops immediately', () {
      final r = _Rig();
      r.rest();
      for (final a in [20.0, 60.0, 120.0, 165.0]) {
        r.feed(a);
      }
      expect(r.session.awaitingUnsafeAck, isTrue);
      expect(r.session.isRunning, isFalse);
      expect(r.session.worstTier, SafetyTier.unsafe);
    });
  });

  group('final-rep and start-time fixes', () {
    test('acknowledging an unsafe FINAL rep tells the screen, so it can finish the session', () {
      final r = _Rig(repsTarget: 1);
      r.rest();
      r.rep(durationMs: 600); // unsafe, and it was the last rep
      expect(r.session.repsCompleted, 1);
      expect(r.session.awaitingUnsafeAck, isTrue);

      var notified = 0;
      r.session.addListener(() => notified++);
      r.session.acknowledgeUnsafe();

      expect(r.session.awaitingUnsafeAck, isFalse);
      expect(r.session.isRunning, isFalse, reason: 'nothing left to run');
      expect(notified, greaterThan(0), reason: 'without a notification the screen never re-checks and stays stuck');
    });

    test('startedAt is when the patient started, not when the screen was built', () {
      final t0 = DateTime.utc(2026, 10, 1, 8);
      var now = t0;
      final session = LiveSession(
        repsTarget: 5,
        romTargetPercent: 60,
        samples: const Stream.empty(),
        clock: () => now,
      );
      now = t0.add(const Duration(minutes: 2)); // spent on the Get ready card
      session.start();
      expect(session.startedAt, t0.add(const Duration(minutes: 2)));

      now = t0.add(const Duration(minutes: 9));
      session.pause();
      session.resume();
      expect(session.startedAt, t0.add(const Duration(minutes: 2)), reason: 'only set once');
      session.dispose();
    });
  });

  group('result', () {
    test('reports the real peak angle, ROM% and range', () {
      final r = _Rig();
      r.rest();
      r.rep(peak: 90);
      final result = r.session.buildResult(_exercise);
      expect(result.peakJointAngle, closeTo(90, 2));
      expect(result.romAchieved, closeTo(60, 2)); // 90 / 150 deg
      expect(result.achievedRangeDegrees, closeTo(90, 2));
      expect(result.repsCompleted, 1);
    });
  });

  group('activation levels', () {
    test('map %MVC to the four bar levels', () {
      expect(LiveSession.activationOf(5), MuscleActivation.resting);
      expect(LiveSession.activationOf(20), MuscleActivation.light);
      expect(LiveSession.activationOf(45), MuscleActivation.moderate);
      expect(LiveSession.activationOf(80), MuscleActivation.high);
    });
  });

  group('FatigueEstimator', () {
    test('stays at zero while it learns the baseline', () {
      final f = FatigueEstimator();
      for (var i = 0; i < FatigueEstimator.baselineReps; i++) {
        expect(f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100), 0);
      }
    });

    test('does not rise when effort and speed stay the same', () {
      final f = FatigueEstimator();
      for (var i = 0; i < 12; i++) {
        f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100);
      }
      expect(f.score, 0);
    });

    test('rises when effort goes up and the movement slows', () {
      final f = FatigueEstimator();
      for (var i = 0; i < 3; i++) {
        f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100);
      }
      for (var i = 0; i < 8; i++) {
        f.addRep(meanEmgPct: 50, peakSpeedDegPerSec: 55);
      }
      expect(f.score, greaterThan(0.8));
    });

    test('works from speed alone when EMG is uncalibrated', () {
      final f = FatigueEstimator();
      for (var i = 0; i < 3; i++) {
        f.addRep(meanEmgPct: 0, peakSpeedDegPerSec: 100);
      }
      for (var i = 0; i < 8; i++) {
        f.addRep(meanEmgPct: 0, peakSpeedDegPerSec: 50);
      }
      expect(f.score, greaterThan(0.3));
    });

    test('easeBack lowers a high score so it does not instantly re-trigger', () {
      final f = FatigueEstimator();
      for (var i = 0; i < 3; i++) {
        f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100);
      }
      for (var i = 0; i < 10; i++) {
        f.addRep(meanEmgPct: 60, peakSpeedDegPerSec: 40);
      }
      f.easeBack();
      expect(f.score, lessThanOrEqualTo(0.55));
    });
  });

  group('RepAssessor', () {
    const a = RepAssessor();
    final now = DateTime.utc(2026);
    RepMetrics m({double peak = 90, double speed = 100, int ms = 2400}) => RepMetrics(
          peakDegrees: peak,
          targetDegrees: 90,
          peakSpeedDegPerSec: speed,
          duration: Duration(milliseconds: ms),
        );

    test('a controlled full rep is normal', () => expect(a.assess(m(), now).tier, SafetyTier.normal));
    test('too fast is unsafe', () => expect(a.assess(m(speed: 350), now).tier, SafetyTier.unsafe));
    test('fast is a correction', () => expect(a.assess(m(speed: 200), now).tier, SafetyTier.needsCorrection));
    test('short is a correction', () => expect(a.assess(m(peak: 60), now).tier, SafetyTier.needsCorrection));
  });

  testWidgets('a live session waits behind "Get ready" and cannot start while the band is disconnected',
      (tester) async {
    final connection = WearableConnectionController(patientId: 'p1', initiallyPaired: false);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ActiveSessionScreen(
        exercise: _exercise,
        patientId: 'p1',
        connection: connection,
        onViewProgress: () {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Get ready'), findsOneWidget);
    expect(find.text('Rep '), findsNothing, reason: 'live view stays hidden until the zero pose is set');
    final start = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Set zero position & start'));
    expect(start.onPressed, isNull, reason: 'no band connected, nothing to zero');

    await tester.pumpWidget(const SizedBox());
    connection.dispose();
  });
}
