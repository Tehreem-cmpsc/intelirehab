// The on-phone session journal holds finished sessions that haven't reached
// the server. These tests pin down the ways it used to lose or strand them:
// a transient read error (or a corrupt file) wiping the queue, and one bad
// session blocking every session behind it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_repository.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/session_journal.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const _exercise = AssignedExercise(
  assignmentId: 'a',
  exerciseId: 'e',
  name: 'Elbow flexion',
  target: null,
  difficulty: 'Beginner',
  description: null,
  sets: 1,
  repsTarget: 5,
  romTarget: 80,
);

SessionResult _result(String id) => SessionResult(
      id: id,
      analysisId: 'an-$id',
      startedAt: DateTime.utc(2026, 10, 1, 8),
      exercise: _exercise,
      repsCompleted: 3,
      romAchieved: 70,
      peakJointAngle: 100,
      achievedRangeDegrees: 95,
      peakActivation: MuscleActivation.light,
      duration: const Duration(seconds: 60),
      peakFatigue: FatigueLevel.normal,
      worstTier: SafetyTier.normal,
      alerts: const [],
    );

/// Stands in for Supabase. [reject] ids fail permanently, [offline] fails
/// transiently, everything else uploads and is recorded with its device id.
class _Repo extends ExercisesRepository {
  final Set<String> reject;
  bool offline;
  String? pairedDevice;
  final uploaded = <String, String?>{};
  _Repo({this.reject = const {}, this.offline = false, this.pairedDevice});

  @override
  Future<String?> pairedDeviceId(String patientId) async => pairedDevice;

  @override
  Future<void> saveSession(
      {required String patientId, required String? deviceId, required SessionResult result}) async {
    if (offline) throw const SocketException('offline');
    if (reject.contains(result.id)) {
      throw const PostgrestException(message: 'violates foreign key constraint', code: '23503');
    }
    uploaded[result.id] = deviceId;
  }
}

File get _journalFile => File('${Directory.systemTemp.path}/session_journal.json');

Future<void> _clean() async {
  if (await _journalFile.exists()) await _journalFile.delete();
  for (final f in Directory.systemTemp.listSync().whereType<File>()) {
    if (f.path.contains('session_journal.json.corrupt-')) await f.delete();
  }
}

void main() {
  setUp(_clean);
  tearDown(_clean);

  test('a corrupt journal is set aside, not overwritten, and the app carries on', () async {
    await _journalFile.writeAsString('{ this is not json');

    expect(await SessionJournal.pendingCount('p1'), 0);

    final kept = Directory.systemTemp.listSync().whereType<File>().where((f) => f.path.contains('.corrupt-'));
    expect(kept, hasLength(1), reason: 'the unreadable bytes are kept for recovery');
    expect(await kept.single.readAsString(), '{ this is not json');

    await SessionJournal.enqueue('p1', null, _result('s1'));
    expect(await SessionJournal.pendingCount('p1'), 1, reason: 'journal works again straight away');
  });

  test('one permanently rejected session does not block the ones behind it', () async {
    await SessionJournal.enqueue('p1', null, _result('bad'));
    await SessionJournal.enqueue('p1', null, _result('good'));
    final repo = _Repo(reject: {'bad'});

    expect(await SessionJournal.syncPending('p1', repo), 1);
    expect(repo.uploaded.keys, ['good']);
    expect(await SessionJournal.pendingCount('p1'), 0);
    expect(await SessionJournal.failedCount('p1'), 1, reason: 'kept, not deleted, and not retried forever');
  });

  test('a transient failure stops and keeps everything queued', () async {
    await SessionJournal.enqueue('p1', null, _result('s1'));
    await SessionJournal.enqueue('p1', null, _result('s2'));
    final repo = _Repo(offline: true);

    expect(await SessionJournal.syncPending('p1', repo), 0);
    expect(await SessionJournal.pendingCount('p1'), 2);
    expect(await SessionJournal.failedCount('p1'), 0);
  });

  test('an unreadable queued entry is set aside and the rest still upload', () async {
    await SessionJournal.enqueue('p1', null, _result('good'));
    // Add a pending entry whose session JSON is broken.
    final raw = await _journalFile.readAsString();
    final broken =
        raw.replaceFirst('"pending":[', '"pending":[{"patientId":"p1","deviceId":null,"result":{"id":"x"}},');
    await _journalFile.writeAsString(broken);
    final repo = _Repo();

    expect(await SessionJournal.syncPending('p1', repo), 1);
    expect(repo.uploaded.keys, ['good']);
    expect(await SessionJournal.failedCount('p1'), 1);
  });

  test('a session queued without a device id gets the paired band attached at upload', () async {
    await SessionJournal.enqueue('p1', null, _result('s1'));
    final repo = _Repo(pairedDevice: 'dev-1');

    await SessionJournal.syncPending('p1', repo);
    expect(repo.uploaded['s1'], 'dev-1');
  });

  test('an already-known device id is kept', () async {
    await SessionJournal.enqueue('p1', 'dev-original', _result('s1'));
    final repo = _Repo(pairedDevice: 'dev-other');

    await SessionJournal.syncPending('p1', repo);
    expect(repo.uploaded['s1'], 'dev-original');
  });
}
