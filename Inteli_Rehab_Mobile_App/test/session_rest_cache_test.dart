// Rest length per exercise, the "target reached" signal, the plan query's fallbacks, and the on-phone
// cache of the patient's range and safety limits.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/platform/device_services.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_repository.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/live_session.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/session_setup_cache.dart';
import 'package:inteli_rehab_mobile_app/features/home/ble/arm_band_protocol.dart';

const _exercise = AssignedExercise(
  assignmentId: 'a',
  exerciseId: 'e',
  name: 'Elbow flexion',
  target: null,
  difficulty: 'Beginner',
  description: null,
  sets: 2,
  repsTarget: 2,
  romTarget: 60,
);

final _dir = Directory.systemTemp.createTempSync('session_rest_cache_test_');

/// 150 deg full range x 60% = a 90 degree target.
class _Rig {
  late final LiveSession session;
  DateTime now = DateTime.utc(2026, 1, 1);

  _Rig({int reps = 2, int sets = 2}) {
    session = LiveSession(
      repsTarget: reps,
      sets: sets,
      romTargetPercent: 60,
      samples: const Stream.empty(),
      clock: () => now,
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

  void rep({double peak = 100, int durationMs = 2400}) {
    final n = durationMs ~/ 32;
    for (var i = 0; i <= n; i++) {
      feed(peak * math.sin(math.pi * i / n));
    }
    rest();
  }
}

void main() {
  setUpAll(() => DeviceServices.overrideFilesDir(_dir));

  group('rest between sets', () {
    test('an exercise without a rest length uses 30 s; one with it uses its own', () {
      expect(_exercise.restBetweenSets, 30);
      const withRest = AssignedExercise(
        assignmentId: 'a',
        exerciseId: 'e',
        name: 'x',
        target: null,
        difficulty: 'Beginner',
        description: null,
        sets: 3,
        repsTarget: 10,
        romTarget: 70,
        restSeconds: 75,
      );
      expect(withRest.restBetweenSets, 75);
      expect(AssignedExercise.fromJson(withRest.toJson()).restSeconds, 75);
      expect(AssignedExercise.fromJson(_exercise.toJson()).restSeconds, isNull, reason: 'older journals have none');
    });

    test('the session reports the rest length it was given', () {
      final s = LiveSession(
        repsTarget: 5,
        sets: 3,
        restSeconds: 75,
        romTargetPercent: 60,
        samples: const Stream.empty(),
      );
      expect(s.restSeconds, 75);
      s.dispose();
    });

    test('time spent resting is recorded, and is not part of the exercise time', () async {
      final r = _Rig();
      r.rest();
      r.rep();
      r.rep();
      expect(r.session.isResting, isTrue);
      expect(r.session.buildResult(_exercise).rest, greaterThanOrEqualTo(Duration.zero));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      r.session.endRest();
      final result = r.session.buildResult(_exercise);
      expect(result.rest, greaterThanOrEqualTo(const Duration(milliseconds: 50)));
      expect(result.duration, lessThan(result.rest), reason: 'the stopwatch stopped while resting');
      r.session.dispose();
    });

    test('rest survives the offline journal, and an older journal has none', () async {
      final r = _Rig();
      r.rest();
      r.rep();
      r.rep();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      r.session.endRest();
      final result = r.session.buildResult(_exercise);
      final back = SessionResult.fromJson(jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>);
      expect(back.rest.inMilliseconds, result.rest.inMilliseconds, reason: "saved to the millisecond");
      final old = SessionResult.fromJson(result.toJson()..remove('restMs'));
      expect(old.rest, Duration.zero);
      r.session.dispose();
    });
  });

  group('target reached', () {
    test('counts once per rep, at the moment the arm gets to the target', () {
      final r = _Rig(reps: 5, sets: 1);
      r.rest();
      expect(r.session.targetReaches, 0);
      r.rep(peak: 100);
      expect(r.session.targetReaches, 1);
      r.rep(peak: 100);
      expect(r.session.targetReaches, 2);
      r.session.dispose();
    });

    test('is already signalled before the rep is counted or finished', () {
      final r = _Rig(reps: 5, sets: 1);
      r.rest();
      // Up past the 90 degree target and no further: not yet counted, but reached.
      for (var a = 0.0; a <= 95; a += 3) {
        r.feed(a);
      }
      expect(r.session.repsCompleted, 0);
      expect(r.session.targetReaches, 1);
      r.session.dispose();
    });

    test('does not fire for a rep that counts but falls short of the target', () {
      final r = _Rig(reps: 5, sets: 1);
      r.rest();
      r.rep(peak: 70); // more than half the target, so it counts, but the target is 90
      expect(r.session.repsCompleted, 1);
      expect(r.session.targetReaches, 0);
      r.session.dispose();
    });

    test('hovering at the top does not fire again', () {
      final r = _Rig(reps: 5, sets: 1);
      r.rest();
      for (var a = 0.0; a <= 100; a += 4) {
        r.feed(a);
      }
      for (var i = 0; i < 30; i++) {
        r.feed(100 + (i.isEven ? 2 : -2)); // wobbling around the top
      }
      expect(r.session.targetReaches, 1);
      r.session.dispose();
    });
  });

  group('plan query', () {
    test('asks for the rest length and the pictures, and can drop either', () {
      final all = ExercisesRepository.planSelect(rest: true, media: true);
      expect(all, contains('rest_seconds'));
      expect(all, contains('media_url, media_type'));
      expect(all, contains('exercises(name, target, difficulty, description'));

      final noRest = ExercisesRepository.planSelect(rest: false, media: true);
      expect(noRest, isNot(contains('rest_seconds')));
      expect(noRest, contains('media_url'));

      final base = ExercisesRepository.planSelect(rest: false, media: false);
      expect(base, 'id, exercise_id, sets, reps, rom_target, exercises(name, target, difficulty, description)');
    });

    test('rest_seconds is a column of the plan row, outside the embedded exercises(...)', () {
      final s = ExercisesRepository.planSelect(rest: true, media: true);
      expect(s.indexOf('rest_seconds'), lessThan(s.indexOf('exercises(')));
    });
  });

  group('SessionSetupCache', () {
    const reference = 118.0;

    test('nothing cached and nothing readable: still unknown, so the defaults apply', () async {
      final got = await SessionSetupCache.resolve('nobody', SessionSetup.unreadable);
      expect(got.referenceKnown, isFalse);
      expect(got.safetyKnown, isFalse);
      expect(got.fullRangeDegrees, 150);
      expect(got.limitsFor(got.fullRangeDegrees), isNull);
      expect(await SessionSetupCache.read('nobody'), isNull, reason: 'nothing worth saving');
    });

    test('a good read is remembered and used when the next one fails', () async {
      await SessionSetupCache.resolve(
        'p1',
        const SessionSetup(referenceRangeDeg: reference, maxAngleDeg: 120, maxSpeedDegPerSec: 200),
      );
      final offline = await SessionSetupCache.resolve('p1', SessionSetup.unreadable);
      expect(offline.referenceRangeDeg, reference);
      expect(offline.fullRangeDegrees, reference);
      expect(offline.maxAngleDeg, 120);
      expect(offline.maxSpeedDegPerSec, 200);
      expect(offline.limitsFor(offline.fullRangeDegrees)!.maxAngleDeg, 120, reason: "the physio's limit still applies offline");
    });

    test('each part falls back on its own', () async {
      await SessionSetupCache.resolve(
        'p2',
        const SessionSetup(referenceRangeDeg: reference, maxAngleDeg: 130, maxSpeedDegPerSec: 250),
      );
      // This time only the limits could be read (and the physio loosened them).
      final got = await SessionSetupCache.resolve(
        'p2',
        const SessionSetup(maxAngleDeg: 150, maxSpeedDegPerSec: 300, referenceKnown: false),
      );
      expect(got.referenceRangeDeg, reference, reason: 'range from the cache');
      expect(got.maxAngleDeg, 150, reason: 'limits are fresh');
      expect((await SessionSetupCache.read('p2'))!.maxAngleDeg, 150, reason: 'and the cache is updated');
    });

    test('a limit the physiotherapist removed is removed here too, not kept stale', () async {
      await SessionSetupCache.resolve('p3', const SessionSetup(maxAngleDeg: 110, maxSpeedDegPerSec: 180));
      final got = await SessionSetupCache.resolve('p3', const SessionSetup(referenceRangeDeg: reference));
      expect(got.maxAngleDeg, isNull);
      expect(got.maxSpeedDegPerSec, isNull);
      expect(got.limitsFor(got.fullRangeDegrees), isNull);
      expect((await SessionSetupCache.read('p3'))!.maxAngleDeg, isNull);
    });

    test('patients do not share a cache, and odd ids are safe file names', () async {
      await SessionSetupCache.resolve('a/b..c', const SessionSetup(referenceRangeDeg: 101));
      await SessionSetupCache.resolve('other', const SessionSetup(referenceRangeDeg: 140));
      expect((await SessionSetupCache.read('a/b..c'))!.referenceRangeDeg, 101);
      expect((await SessionSetupCache.read('other'))!.referenceRangeDeg, 140);
    });

    test('an unreadable cache file is ignored, not an error, and is replaced by the next good read', () async {
      final file = File('${_dir.path}${Platform.pathSeparator}session_setup_broken.json');
      await file.writeAsString('{not json');
      expect(await SessionSetupCache.read('broken'), isNull);
      final got = await SessionSetupCache.resolve('broken', const SessionSetup(referenceRangeDeg: 125));
      expect(got.referenceRangeDeg, 125);
      expect((await SessionSetupCache.read('broken'))!.referenceRangeDeg, 125);
    });
  });
}
