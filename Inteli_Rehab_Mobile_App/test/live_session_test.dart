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
import 'package:inteli_rehab_mobile_app/features/exercises/processing/emg_processor.dart';
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
  group('motion recording (physiotherapist replay)', () {
    test('records the movement at ~15 Hz with a marker for every counted rep', () {
      final r = _Rig();
      r.rest();
      for (var i = 0; i < 3; i++) {
        r.rep(emg: 40);
      }
      final m = r.session.buildResult(_exercise).motion!;
      expect(m.tMs.length, m.angle.length);
      expect(m.emg.length, m.angle.length);
      expect(m.sampleRateHz, closeTo(15.6, 0.1));
      expect(m.angle.reduce(math.max), closeTo(90, 2), reason: 'the peaks are in the recording');
      expect(m.events.where((e) => e['type'] == 'rep').length, 3);
      for (var i = 1; i < m.tMs.length; i++) {
        expect(m.tMs[i], greaterThanOrEqualTo(m.tMs[i - 1]), reason: 'time only moves forward');
      }
    });

    test('marks amber/red moments, and survives the offline journal round trip', () {
      final r = _Rig();
      r.rest();
      r.rep(peak: 35); // a "move further" prompt
      final result = r.session.buildResult(_exercise);
      final tiers = result.motion!.events.where((e) => e['type'] == 'tier').toList();
      expect(tiers.first['tier'], 'needsCorrection');
      expect(tiers.first['message'], contains('more of your range'));

      final back = SessionResult.fromJson(result.toJson()).motion!;
      expect(back.angle, result.motion!.angle);
      expect(back.events.length, result.motion!.events.length);
    });
  });

  group('rep counting', () {
    test('counts at the top of the hill, before the arm is back down', () {
      final r = _Rig();
      r.rest();
      // Up to 90 degrees...
      for (var a = 0.0; a <= 90; a += 3) {
        r.feed(a);
      }
      expect(r.session.repsCompleted, 0, reason: 'still on the way up');
      // ...and a little way back down: past the peak, counted already.
      for (var a = 87.0; a >= 70; a -= 3) {
        r.feed(a);
      }
      expect(r.session.repsCompleted, 1, reason: 'counted at the peak, not at rest');
    });

    test('back-to-back hills count without straightening fully in between', () {
      final r = _Rig();
      r.rest();
      for (var a = 0.0; a < 40; a += 3) {
        r.feed(a); // a smooth start, not a jump (a jump is fast enough to trip the red speed rule)
      }
      for (var hill = 0; hill < 3; hill++) {
        for (var a = 40.0; a <= 90; a += 3) {
          r.feed(a);
        }
        for (var a = 90.0; a >= 40; a -= 3) {
          r.feed(a); // turns at 40 degrees, never back near rest (the 13.5 degree rest band)
        }
      }
      expect(r.session.repsCompleted, 3);
    });

    test('wobble at the top of a hill does not count twice', () {
      final r = _Rig();
      r.rest();
      for (var a = 0.0; a <= 90; a += 3) {
        r.feed(a);
      }
      for (var i = 0; i < 20; i++) {
        r.feed(i.isEven ? 90 : 85); // sensor noise of a few degrees while holding at the top
      }
      expect(r.session.repsCompleted, 0, reason: 'a 5 degree dip is not the top of a hill');
      for (var a = 87.0; a >= 0; a -= 3) {
        r.feed(a);
      }
      r.rest();
      expect(r.session.repsCompleted, 1);
    });

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

    test('the elbow staying well past full range stops the session at once, mid-rep', () {
      final r = _Rig();
      r.rest();
      // A calm bend (about 60 degrees a second), carried on past the limit and held there.
      for (var a = 20.0; a <= 165; a += 2) {
        r.feed(a);
      }
      for (var i = 0; i < 5; i++) {
        r.feed(166);
      }
      expect(r.session.awaitingUnsafeAck, isTrue);
      expect(r.session.isRunning, isFalse);
      expect(r.session.worstTier, SafetyTier.unsafe);
      expect(r.session.currentMessage, contains('safe range'));
    });

    test('one noisy sample over the limit does not stop the session', () {
      final r = _Rig();
      r.rest();
      for (var a = 20.0; a <= 120; a += 2) {
        r.feed(a);
      }
      r.feed(175); // a glitch of a single sample...
      for (var a = 122.0; a >= 40; a -= 2) {
        r.feed(a); // ...then the arm carries on normally
      }
      expect(r.session.awaitingUnsafeAck, isFalse);
      expect(r.session.isRunning, isTrue);
    });
  });

  group('final-rep and start-time fixes', () {
    test('a stop during the FINAL rep does not count it; after acknowledging, the rep can be redone', () {
      final r = _Rig(repsTarget: 1);
      r.rest();
      r.rep(durationMs: 600); // unsafe: stopped mid-rep, so it was never counted
      expect(r.session.awaitingUnsafeAck, isTrue);
      expect(r.session.repsCompleted, 0);

      var notified = 0;
      r.session.addListener(() => notified++);
      r.session.acknowledgeUnsafe();
      expect(r.session.awaitingUnsafeAck, isFalse);
      expect(r.session.isRunning, isTrue, reason: 'the last rep is still to do');
      expect(notified, greaterThan(0));

      r.rest();
      r.rep(); // a calm rep this time
      expect(r.session.repsCompleted, 1);
      expect(r.session.isRunning, isFalse, reason: 'that was the last one');
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
    const learning = FatigueEstimator.warmupReps + FatigueEstimator.baselineReps;

    test('stays at zero while it learns the baseline', () {
      final f = FatigueEstimator();
      for (var i = 0; i < learning; i++) {
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
      for (var i = 0; i < learning; i++) {
        f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100);
      }
      for (var i = 0; i < 8; i++) {
        f.addRep(meanEmgPct: 50, peakSpeedDegPerSec: 55);
      }
      expect(f.score, greaterThan(0.8));
    });

    test('works from speed alone when EMG is uncalibrated, but never reaches critical on its own', () {
      final f = FatigueEstimator();
      for (var i = 0; i < learning; i++) {
        f.addRep(meanEmgPct: 0, peakSpeedDegPerSec: 100);
      }
      expect(f.speedOnly, isTrue);
      for (var i = 0; i < 20; i++) {
        f.addRep(meanEmgPct: 0, peakSpeedDegPerSec: 30);
      }
      expect(f.score, greaterThan(0.65), reason: 'a big slowdown shows as moderate fatigue');
      expect(f.score, lessThanOrEqualTo(FatigueEstimator.speedOnlyCap));
      expect(EmgProcessor.levelOf(f.score), isNot(FatigueLevel.critical));
    });

    test('with a calibrated muscle sensor it is not speed-only', () {
      final f = FatigueEstimator();
      for (var i = 0; i < learning; i++) {
        f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100);
      }
      expect(f.speedOnly, isFalse);
    });

    test('the first rep is a warm-up and does not set the baseline', () {
      final f = FatigueEstimator();
      f.addRep(meanEmgPct: 5, peakSpeedDegPerSec: 20); // a hesitant first rep
      for (var i = 0; i < FatigueEstimator.baselineReps; i++) {
        f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100);
      }
      for (var i = 0; i < 6; i++) {
        f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100); // steady as the real baseline: no fatigue
      }
      expect(f.score, 0);
    });

    test('one odd rep among the baseline reps does not skew it (median)', () {
      final f = FatigueEstimator();
      f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100); // warm-up
      f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100);
      f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 400); // a jerk
      f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100);
      for (var i = 0; i < 6; i++) {
        f.addRep(meanEmgPct: 30, peakSpeedDegPerSec: 100);
      }
      expect(f.score, 0, reason: 'the baseline speed is 100, not the 200 a mean would give');
    });

    test('easeBack lowers a high score so it does not instantly re-trigger', () {
      final f = FatigueEstimator();
      for (var i = 0; i < learning; i++) {
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
