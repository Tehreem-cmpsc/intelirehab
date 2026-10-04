// The three states of feedback in a live session, with the real trained model:
//   green - the rep looked like a healthy one;
//   amber - the model says it looked different, reported just after the rep (advice);
//   red   - a live rule check on every sample stops the session (angle / speed held briefly).
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/live_session.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/processing/elbow_autoencoder.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/processing/elbow_rep_checker.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/processing/safety_monitor.dart';
import 'package:inteli_rehab_mobile_app/features/home/ble/arm_band_protocol.dart';

final _model = ElbowAutoencoder.fromJson(File('assets/ai/elbow_autoencoder.json').readAsStringSync());
final _checker = ElbowRepChecker(_model);

/// A rep as the band would stream it: [peak] degrees, [seconds] long, ~31 Hz, with a moment of rest either side.
List<RepSample> _rep({double peak = 120, double seconds = 2.2, double shape = 1.0, double restSeconds = 0.3}) {
  final out = <RepSample>[];
  var t = 0.0;
  const dt = 0.032;
  for (var i = 0; i < restSeconds / dt; i++) {
    out.add(RepSample(t, 0));
    t += dt;
  }
  final n = (seconds / dt).round();
  for (var i = 0; i <= n; i++) {
    out.add(RepSample(t, peak * math.pow(math.sin(math.pi * i / n), shape)));
    t += dt;
  }
  for (var i = 0; i < restSeconds / dt; i++) {
    out.add(RepSample(t, 0));
    t += dt;
  }
  return out;
}

void main() {
  group('SafetyMonitor (red)', () {
    final t0 = DateTime.utc(2026);
    DateTime at(int ms) => t0.add(Duration(milliseconds: ms));
    SafetyMonitor monitor() =>
        SafetyMonitor(const SafetyLimits(maxAngleDeg: 160, maxSpeedDegPerSec: 300, hold: Duration(milliseconds: 100)));

    test('fires once the angle limit has been exceeded for the whole hold window', () {
      final m = monitor();
      expect(m.update(angle: 165, speed: 0, now: at(0)), isNull);
      expect(m.update(angle: 166, speed: 0, now: at(50)), isNull);
      expect(m.update(angle: 166, speed: 0, now: at(100)), SafetyViolation.angle);
    });

    test('a spike that comes back down inside the window is ignored', () {
      final m = monitor();
      expect(m.update(angle: 170, speed: 0, now: at(0)), isNull);
      expect(m.update(angle: 120, speed: 0, now: at(40)), isNull);
      expect(m.update(angle: 170, speed: 0, now: at(80)), isNull, reason: 'the clock restarted when it dipped');
      expect(m.update(angle: 170, speed: 0, now: at(120)), isNull);
    });

    test('fires on speed, separately from angle', () {
      final m = monitor();
      m.update(angle: 80, speed: 400, now: at(0));
      expect(m.update(angle: 85, speed: 410, now: at(110)), SafetyViolation.speed);
    });

    test('values at the limit are fine; reset forgets a streak', () {
      final m = monitor();
      m.update(angle: 160, speed: 300, now: at(0));
      expect(m.update(angle: 160, speed: 300, now: at(500)), isNull);
      m.update(angle: 170, speed: 0, now: at(600));
      m.reset();
      expect(m.update(angle: 170, speed: 0, now: at(710)), isNull);
    });
  });

  group('ElbowRepChecker (amber)', () {
    test('resampling keeps the shape and gives exactly 100 points', () {
      final out = ElbowRepChecker.resample([const RepSample(0, 0), const RepSample(1, 100)], 100);
      expect(out.length, 100);
      expect(out.first, 0);
      expect(out.last, 100);
      expect(out[50], closeTo(50.5, 0.6));
    });

    test('too little data is not judged', () {
      expect(_checker.check([const RepSample(0, 0), const RepSample(0.1, 5)]), isNull);
      expect(_checker.check([for (var i = 0; i < 20; i++) RepSample(i * 0.01, 10)]), isNull, reason: 'under 0.4 s');
    });

    test('a full, smooth rep looks healthy', () {
      final c = _checker.check(_rep(peak: 125, seconds: 2.0))!;
      expect(c.ok, isTrue, reason: 'score ${c.score} vs ${c.threshold}');
      expect(c.message, isNull);
      expect(c.durationSeconds, closeTo(2.0 + 2 * 0.3, 0.2));
    });

    test('a shallow rep is flagged and told to bend further', () {
      final c = _checker.check(_rep(peak: 50))!;
      expect(c.ok, isFalse);
      expect(c.score, greaterThan(c.threshold));
      expect(c.message, contains('further'));
    });

    test('a rep where the arm never comes back down is flagged and told to lower it', () {
      final up = _rep(peak: 120);
      final stuck = [for (final s in up.sublist(0, (up.length * 0.62).round())) s];
      final c = _checker.check(stuck)!;
      expect(c.ok, isFalse);
      expect(c.message, contains('Lower your arm'));
    });

    test('a slow rep gets a hint but is not failed for it', () {
      final c = _checker.check(_rep(peak: 125, seconds: 5.5))!;
      expect(c.hint, isNotNull);
      expect(c.hint!.toLowerCase(), contains('slow'));
      expect(c.ok, isTrue, reason: 'slowness alone is not a form error (score ${c.score})');
    });

    test('a normal-speed rep has no hint', () {
      expect(_checker.check(_rep(peak: 125, seconds: 2.0))!.hint, isNull);
    });

    test('gentle is the default and is the more forgiving threshold', () {
      expect(_checker.mode, RepCheckMode.gentle);
      expect(_checker.threshold, _model.thresholdGentle);
      expect(ElbowRepChecker(_model, mode: RepCheckMode.balanced).threshold, _model.thresholdBalanced);
      expect(_model.thresholdGentle, greaterThan(_model.thresholdBalanced));
    });
  });

  group('LiveSession with the model', () {
    // 150 deg full range x 60% = a 90 degree target, as in live_session_test.dart.
    LiveSession session({int reps = 5}) => LiveSession(
          repsTarget: reps,
          romTargetPercent: 60,
          samples: const Stream.empty(),
          checker: _checker,
        )..start();

    DateTime now = DateTime.utc(2026, 1, 1);
    void feed(LiveSession s, double angle) {
      s.onSample(ArmBandSample(elbowDeg: angle, emg1Pct: 0), now);
      now = now.add(const Duration(milliseconds: 32));
    }

    void play(LiveSession s, List<RepSample> rep) {
      for (final r in rep) {
        feed(s, r.angle);
      }
    }

    /// Feeds a rep only up to the moment it is counted (the arm crossing back below the rest line on
    /// the way down), leaving the last part of the descent still to come.
    void playUntilCounted(LiveSession s, List<RepSample> rep) {
      final before = s.repsCompleted;
      for (final r in rep) {
        feed(s, r.angle);
        if (s.repsCompleted > before) return;
      }
    }

    test('clean reps stay green', () {
      final s = session();
      for (var i = 0; i < 3; i++) {
        play(s, _rep(peak: 125, seconds: 2.0));
      }
      expect(s.repsCompleted, 3);
      expect(s.currentTier, SafetyTier.normal);
      expect(s.alerts, isEmpty);
      expect(s.currentMessage, isNull);
      expect(s.hasPendingCheck, isFalse);
      s.dispose();
    });

    test('a shallow but countable rep turns amber with the model message, a moment after it ends', () {
      final s = session();
      play(s, _rep(peak: 60, seconds: 2.2));
      expect(s.repsCompleted, 1, reason: 'it reached half the target, so it counts');
      expect(s.currentTier, SafetyTier.needsCorrection);
      expect(s.alerts.single.tier, SafetyTier.needsCorrection);
      expect(s.currentMessage, contains('further'));
      expect(s.isRunning, isTrue, reason: 'amber is advice, never a stop');
      s.dispose();
    });

    test('the verdict on the final rep still arrives, and the screen is told to wait for it', () {
      final s = session(reps: 1);
      final rep = _rep(peak: 60, seconds: 2.2, restSeconds: 0);
      playUntilCounted(s, rep); // counted as the arm crosses back below the rest line, not yet judged
      expect(s.repsCompleted, 1);
      expect(s.isRunning, isFalse, reason: 'all reps done');
      expect(s.hasPendingCheck, isTrue, reason: 'the model waits for the arm to finish coming down');

      for (var i = 0; i < 6; i++) {
        feed(s, 0);
      }
      expect(s.hasPendingCheck, isFalse);
      expect(s.currentTier, SafetyTier.needsCorrection, reason: 'it kept listening after the session paused');
      expect(s.buildResult(_exercise).worstTier, SafetyTier.needsCorrection);
      s.dispose();
    });

    test('ending the session right after a rep still includes that rep\'s verdict', () {
      final s = session();
      playUntilCounted(s, _rep(peak: 60, seconds: 2.2, restSeconds: 0));
      expect(s.hasPendingCheck, isTrue);
      final result = s.buildResult(_exercise); // e.g. "End session" pressed immediately
      expect(result.worstTier, SafetyTier.needsCorrection);
      expect(s.hasPendingCheck, isFalse);
      s.dispose();
    });

    test('a slow rep shows a hint and stays green', () {
      final s = session();
      play(s, _rep(peak: 125, seconds: 5.5));
      expect(s.currentTier, SafetyTier.normal);
      expect(s.repHint, isNotNull);
      play(s, _rep(peak: 125, seconds: 2.0));
      expect(s.repHint, isNull, reason: 'the next, normal rep clears it');
      s.dispose();
    });

    test('red stops mid-rep whatever the model would have said', () {
      final s = session();
      play(s, _rep(peak: 120, seconds: 0.7)); // far too fast
      expect(s.awaitingUnsafeAck, isTrue);
      expect(s.currentTier, SafetyTier.unsafe);
      expect(s.repsCompleted, 0, reason: 'stopped during the rep');
      expect(s.isRunning, isFalse);
      s.dispose();
    });

    test('with no model, reps are judged by the simple rules as before', () {
      final s = LiveSession(repsTarget: 5, romTargetPercent: 60, samples: const Stream.empty())..start();
      play(s, _rep(peak: 60, seconds: 2.2));
      expect(s.currentTier, SafetyTier.needsCorrection);
      expect(s.currentMessage, contains('further'));
      expect(s.hasPendingCheck, isFalse);
      s.dispose();
    });
  });
}

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
