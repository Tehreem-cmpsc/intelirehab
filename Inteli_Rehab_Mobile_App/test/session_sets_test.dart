// Sets and rests, pain reports, the patient's own reference range, and replaying recorded movement
// through LiveSession. Synthetic elbow-angle curves again (a smooth lift and return), so none of it
// needs hardware.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/live_session.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/processing/safety_monitor.dart';
import 'package:inteli_rehab_mobile_app/features/home/ble/arm_band_protocol.dart';

const _exercise = AssignedExercise(
  assignmentId: 'a',
  exerciseId: 'e',
  name: 'Elbow flexion',
  target: null,
  difficulty: 'Beginner',
  description: null,
  sets: 3,
  repsTarget: 2,
  romTarget: 60,
);

/// 150 deg full range (unless given) x 60% target.
class _Rig {
  late final LiveSession session;
  DateTime now = DateTime.utc(2026, 1, 1);

  _Rig({int reps = 2, int sets = 3, double fullRange = 150, SafetyLimits? limits}) {
    session = LiveSession(
      repsTarget: reps,
      sets: sets,
      romTargetPercent: 60,
      samples: const Stream.empty(),
      fullRangeDegrees: fullRange,
      limits: limits,
      clock: () => now, // the session's own timeline (the recording's t_ms) follows the fed samples
    )..start();
  }

  void feed(double angle) {
    session.onSample(ArmBandSample(elbowDeg: angle, emg1Pct: 0), now);
    now = now.add(const Duration(milliseconds: 32));
  }

  void rest([int samples = 6]) {
    for (var i = 0; i < samples; i++) {
      feed(0);
    }
  }

  void rep({double peak = 90, int durationMs = 2400}) {
    final n = durationMs ~/ 32;
    for (var i = 0; i <= n; i++) {
      feed(peak * math.sin(math.pi * i / n));
    }
    rest();
  }
}

void main() {
  group('sets and rests', () {
    test('the session is sets x reps, and the rep display is per set', () {
      final r = _Rig();
      expect(r.session.setsTarget, 3);
      expect(r.session.repsPerSet, 2);
      expect(r.session.repsTarget, 6);
      expect(r.session.currentSet, 1);
      expect(r.session.repsInCurrentSet, 0);
      r.session.dispose();
    });

    test('finishing a set pauses for a rest; nothing counts until the rest is ended', () {
      final r = _Rig();
      r.rest();
      r.rep();
      expect(r.session.repsInCurrentSet, 1);
      expect(r.session.isResting, isFalse);
      r.rep();
      expect(r.session.repsCompleted, 2);
      expect(r.session.isResting, isTrue);
      expect(r.session.isRunning, isFalse);
      expect(r.session.currentSet, 1, reason: 'still showing the set that was just finished');
      expect(r.session.repsInCurrentSet, 2);

      r.rep(); // movement during the rest is ignored
      expect(r.session.repsCompleted, 2);

      r.session.endRest();
      expect(r.session.isResting, isFalse);
      r.session.resume();
      expect(r.session.isRunning, isTrue);
      expect(r.session.currentSet, 2);
      expect(r.session.repsInCurrentSet, 0);
      r.session.dispose();
    });

    test('resume() does not cut a rest short', () {
      final r = _Rig();
      r.rest();
      r.rep();
      r.rep();
      expect(r.session.isResting, isTrue);
      r.session.resume();
      expect(r.session.isResting, isTrue);
      expect(r.session.isRunning, isFalse);
      r.session.dispose();
    });

    test('three sets run to the end, with no rest after the last one, and are all in the result', () {
      final r = _Rig();
      r.rest();
      for (var set = 0; set < 3; set++) {
        r.rep();
        r.rep();
        if (set < 2) {
          expect(r.session.isResting, isTrue, reason: 'rest after set ${set + 1}');
          r.session.endRest();
          r.session.resume();
        }
      }
      expect(r.session.repsCompleted, 6);
      expect(r.session.isResting, isFalse);
      expect(r.session.isRunning, isFalse, reason: 'all done');

      final result = r.session.buildResult(_exercise);
      expect(result.sets.map((s) => s.number), [1, 2, 3]);
      expect(result.sets.map((s) => s.reps), [2, 2, 2]);
      expect(result.sets.every((s) => s.romPercent >= 55), isTrue, reason: 'each set reached about 90/150');
      expect(result.repsPlanned, 6);
      r.session.dispose();
    });

    test('a half-finished set is in the result as a partial set', () {
      final r = _Rig();
      r.rest();
      r.rep();
      r.rep();
      r.session.endRest();
      r.session.resume();
      r.rep(); // one rep of set 2
      final result = r.session.buildResult(_exercise);
      expect(result.sets.map((s) => s.reps), [2, 1]);
      r.session.dispose();
    });

    test('one set (the default) never rests', () {
      final r = _Rig(sets: 1);
      r.rest();
      r.rep();
      r.rep();
      expect(r.session.isResting, isFalse);
      expect(r.session.repsCompleted, 2);
      expect(r.session.isRunning, isFalse);
      r.session.dispose();
    });

    test('per-set results count that set\'s prompts only', () {
      final r = _Rig();
      r.rest();
      r.rep(peak: 35); // too shallow to count, but a clear attempt: a "move further" prompt in set 1
      r.rep();
      r.rep();
      r.session.endRest();
      r.session.resume();
      r.rep();
      r.rep();
      final sets = r.session.buildResult(_exercise).sets;
      expect(sets[0].corrections, 1);
      expect(sets[1].corrections, 0);
      r.session.dispose();
    });
  });

  group('pain', () {
    test('"This hurts" pauses and is recorded, without counting as a form fault', () {
      final r = _Rig(sets: 1, reps: 5);
      r.rest();
      r.rep();
      r.session.reportPain();
      expect(r.session.isRunning, isFalse);
      expect(r.session.worstTier, SafetyTier.normal);
      expect(r.session.currentTier, SafetyTier.normal);
      expect(r.session.alerts.single.pain, isTrue);

      final result = r.session.buildResult(_exercise);
      expect(result.worstTier, SafetyTier.normal);
      expect(result.sets.single.corrections, 0);
      expect(result.motion!.events.where((e) => e['type'] == 'pain').length, 1);
      r.session.dispose();
    });

    test('pain, the early-end reason and the sets survive the offline journal round trip', () {
      final r = _Rig();
      r.rest();
      r.rep();
      r.rep();
      r.session.reportPain();
      final result = r.session.buildResult(_exercise).withEnding(painLevel: 7, endedReason: EndedReason.pain);
      final back = SessionResult.fromJson(jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>);
      expect(back.painLevel, 7);
      expect(back.endedReason, EndedReason.pain);
      expect(back.alerts.where((a) => a.pain).length, 1);
      expect(back.sets.length, result.sets.length);
      expect(back.repsPlanned, 6);
      r.session.dispose();
    });

    test('a journal written before sets and pain existed still loads', () {
      final r = _Rig(sets: 1, reps: 2);
      r.rest();
      r.rep();
      final json = r.session.buildResult(_exercise).toJson()
        ..remove('sets')
        ..remove('repsPlanned')
        ..remove('painLevel')
        ..remove('endedReason');
      final back = SessionResult.fromJson(json);
      expect(back.sets, isEmpty);
      expect(back.repsPlanned, isNull);
      expect(back.painLevel, isNull);
      expect(back.endedReason, isNull);
      r.session.dispose();
    });
  });

  group('the patient\'s own reference range', () {
    test('ROM is measured against it, so a smaller range can still reach its target', () {
      // 100 deg reference x 60% = a 60 deg target; a 62 deg rep counts and is ~62% ROM.
      final r = _Rig(sets: 1, reps: 3, fullRange: 100);
      r.rest();
      r.rep(peak: 62);
      expect(r.session.repsCompleted, 1);
      expect(r.session.buildResult(_exercise).romAchieved, closeTo(62, 3));
      r.session.dispose();
    });

    test('the red angle limit does not shrink with it: going past the baseline is not "unsafe"', () {
      final r = _Rig(sets: 1, reps: 3, fullRange: 100);
      r.rest();
      r.rep(peak: 125, durationMs: 3000); // well past the 100 deg baseline, but a normal elbow
      expect(r.session.worstTier, SafetyTier.normal);
      expect(r.session.awaitingUnsafeAck, isFalse);
      r.session.dispose();
    });

    test('SessionSetup: a missing or implausible calibration falls back to the default range', () {
      expect(SessionSetup.defaults.fullRangeDegrees, 150);
      expect(const SessionSetup(referenceRangeDeg: 112).fullRangeDegrees, 112);
      expect(const SessionSetup(referenceRangeDeg: 20).fullRangeDegrees, 150, reason: 'a failed reading');
      expect(const SessionSetup(referenceRangeDeg: 400).fullRangeDegrees, 150);
    });
  });

  group('physiotherapist\'s red limits', () {
    test('no override leaves the session on its own default', () {
      expect(SessionSetup.defaults.limitsFor(150), isNull);
    });

    test('an override is used, and a missing half keeps its default', () {
      final onlyAngle = const SessionSetup(maxAngleDeg: 120).limitsFor(150)!;
      expect(onlyAngle.maxAngleDeg, 120);
      expect(onlyAngle.maxSpeedDegPerSec, 300);
      final onlySpeed = const SessionSetup(maxSpeedDegPerSec: 180).limitsFor(150)!;
      expect(onlySpeed.maxAngleDeg, 160);
      expect(onlySpeed.maxSpeedDegPerSec, 180);
    });

    test('a stricter angle limit stops the session where the default would not', () {
      final limits = const SessionSetup(maxAngleDeg: 100).limitsFor(150);
      final r = _Rig(sets: 1, reps: 3, limits: limits);
      r.rest();
      r.rep(peak: 120, durationMs: 3000);
      expect(r.session.worstTier, SafetyTier.unsafe);
      r.session.dispose();
    });
  });

  group('replaying recorded movement', () {
    /// Feeds a recording's own angles, at its own timestamps, to a fresh session.
    LiveSession replay(MotionRecording m, {int reps = 20, double fullRange = 150}) {
      final s = LiveSession(
        repsTarget: reps,
        romTargetPercent: 60,
        samples: const Stream.empty(),
        fullRangeDegrees: fullRange,
      )..start();
      final t0 = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < m.tMs.length; i++) {
        s.onSample(ArmBandSample(elbowDeg: m.angle[i], emg1Pct: m.emg[i]), t0.add(Duration(milliseconds: m.tMs[i])));
      }
      return s;
    }

    /// A synthetic recording: [reps] lifts of [peak] degrees, [repMs] each, with a pause between, at 15.6 Hz.
    MotionRecording synth({required int reps, double peak = 90, int repMs = 2400, int pauseMs = 600}) {
      const stepMs = 64;
      final t = <int>[];
      final a = <double>[];
      var clock = 0;
      void add(double v) {
        t.add(clock);
        a.add(v);
        clock += stepMs;
      }

      for (var i = 0; i < 6; i++) {
        add(0);
      }
      for (var r = 0; r < reps; r++) {
        final n = repMs ~/ stepMs;
        for (var i = 0; i <= n; i++) {
          add(peak * math.sin(math.pi * i / n));
        }
        for (var i = 0; i < pauseMs ~/ stepMs; i++) {
          add(0);
        }
      }
      return MotionRecording(
        sampleRateHz: 15.6,
        side: 'left',
        tMs: t,
        angle: a,
        emg: List.filled(t.length, 0),
        events: const [],
      );
    }

    test('good reps recorded at the replay rate are all counted, and stay green', () {
      final s = replay(synth(reps: 5));
      expect(s.repsCompleted, 5);
      expect(s.worstTier, SafetyTier.normal);
      s.dispose();
    });

    test('shallow reps are not counted', () {
      final s = replay(synth(reps: 4, peak: 30));
      expect(s.repsCompleted, 0);
      s.dispose();
    });

    test('a double-bounce at the top counts once per lift, not twice', () {
      // Each lift rises to 90, dips 10 degrees (sensor wobble / a stutter), and back up.
      const stepMs = 64;
      final t = <int>[];
      final a = <double>[];
      var clock = 0;
      void add(double v) {
        t.add(clock);
        a.add(v);
        clock += stepMs;
      }

      for (var i = 0; i < 6; i++) {
        add(0);
      }
      for (var lift = 0; lift < 3; lift++) {
        for (var i = 0; i <= 18; i++) {
          add(90 * math.sin(math.pi / 2 * i / 18)); // up
        }
        for (var i = 0; i < 3; i++) {
          add(84); // a small stutter near the top
        }
        add(90);
        for (var i = 0; i <= 18; i++) {
          add(90 * math.cos(math.pi / 2 * i / 18)); // down
        }
        for (var i = 0; i < 8; i++) {
          add(0);
        }
      }
      final s = replay(MotionRecording(
        sampleRateHz: 15.6,
        side: 'left',
        tMs: t,
        angle: a,
        emg: List.filled(t.length, 0),
        events: const [],
      ));
      expect(s.repsCompleted, 3);
      s.dispose();
    });

    test('a saved recording replays to the same rep count it was recorded with', () {
      final live = _Rig(sets: 1, reps: 4);
      live.rest();
      for (var i = 0; i < 3; i++) {
        live.rep();
      }
      final recorded = live.session.buildResult(_exercise);
      final back = MotionRecording.fromJson(jsonDecode(jsonEncode(recorded.motion!.toJson())) as Map<String, dynamic>);
      final s = replay(back, reps: 4);
      expect(s.repsCompleted, recorded.repsCompleted);
      s.dispose();
      live.session.dispose();
    });

    // Real recordings go in test/fixtures/replays/<name>.json as
    //   { "expect": { "reps": 8, "worstTier": "normal" }, "fullRange": 150, "motion": <MotionRecording JSON> }
    // (the motion column of a session_motion row, in the app's camelCase form), and are checked here.
    final dir = Directory('test/fixtures/replays');
    final files = dir.existsSync() ? dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')) : <File>[];
    for (final file in files) {
      test('fixture ${file.uri.pathSegments.last}', () {
        final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final expected = j['expect'] as Map<String, dynamic>;
        final s = replay(
          MotionRecording.fromJson(Map<String, dynamic>.from(j['motion'] as Map)),
          fullRange: (j['fullRange'] as num?)?.toDouble() ?? 150,
        );
        expect(s.repsCompleted, expected['reps']);
        if (expected['worstTier'] != null) expect(s.worstTier.name, expected['worstTier']);
        s.dispose();
      });
    }
  });
}
