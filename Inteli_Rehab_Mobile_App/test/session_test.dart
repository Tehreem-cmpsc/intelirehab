import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/platform/device_services.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/active_session_screen.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercise_detail_screen.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_repository.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/session_journal.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/session_simulator.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/session_summary_screen.dart';
import 'package:inteli_rehab_mobile_app/features/home/wearable_connection_controller.dart';

const _exercise = AssignedExercise(
  assignmentId: 'a1',
  exerciseId: 'e1',
  name: 'Elbow flexion',
  target: 'Biceps',
  difficulty: 'Beginner',
  description: null,
  sets: 3,
  repsTarget: 10,
  romTarget: 80,
);

SessionResult _result({int reps = 4}) => SessionResult(
      id: 'sess-1',
      analysisId: 'ana-1',
      startedAt: DateTime.utc(2026, 9, 29, 8),
      exercise: _exercise,
      repsCompleted: reps,
      romAchieved: 72,
      peakJointAngle: 72,
      achievedRangeDegrees: 72,
      peakActivation: MuscleActivation.moderate,
      duration: const Duration(seconds: 95),
      peakFatigue: FatigueLevel.mild,
      worstTier: SafetyTier.needsCorrection,
      alerts: [
        SessionAlert(
          id: 'al-1',
          tier: SafetyTier.needsCorrection,
          message: 'Needs correction — lower your arm.',
          at: DateTime.utc(2026, 9, 29, 8, 1),
        ),
      ],
    );

/// Stands in for Supabase: succeeds or fails on demand, and records calls.
class _FakeRepo extends ExercisesRepository {
  bool online;
  final saved = <String>[];
  _FakeRepo({this.online = true});

  @override
  Future<void> saveSession({required String patientId, required String? deviceId, required SessionResult result}) async {
    if (!online) throw const SocketException('offline');
    saved.add(result.id);
  }
}

// This file's own storage folder: test files run in parallel and must not share one journal.
final _dir = Directory.systemTemp.createTempSync('session_test_');

Future<void> _clearJournal() async {
  final f = File('${_dir.path}/session_journal.json');
  if (await f.exists()) await f.delete();
}

void main() {
  setUpAll(() => DeviceServices.overrideFilesDir(_dir));
  group('SessionSimulator', () {
    testWidgets('peakActivation is captured at the same tick as peakAngle', (tester) async {
      final sim = SessionSimulator(repsTarget: 3, romTargetPercent: 80, seed: 2);
      sim.start();
      var sawNonResting = false;
      for (var i = 0; i < 120 && sim.repsCompleted < 3; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (sim.awaitingUnsafeAck) sim.acknowledgeUnsafe();
        if (sim.fatiguePauseOffered) sim.acknowledgeFatiguePause();
        // Whenever a tick sets a new peak, that tick's activation should be
        // exactly what peakActivation reports right now.
        if (sim.liveAngle >= sim.peakAngle && sim.activation != MuscleActivation.resting) {
          sawNonResting = true;
          expect(sim.peakActivation, sim.activation);
        }
      }
      expect(sawNonResting, isTrue, reason: 'session should reach a non-resting activation at least once');
      final result = sim.buildResult(_exercise);
      expect(result.peakActivation, isNot(MuscleActivation.resting), reason: 'peak angle is reached near full extension, not rest');
      sim.dispose();
    });

    testWidgets('resumes counting reps after a pause (regression: froze for good)', (tester) async {
      final sim = SessionSimulator(repsTarget: 20, romTargetPercent: 80, seed: 1);
      sim.start();
      await tester.pump(const Duration(seconds: 6));
      final before = sim.repsCompleted;
      expect(before, greaterThan(0));

      sim.pause();
      await tester.pump(const Duration(seconds: 6));
      expect(sim.repsCompleted, before, reason: 'no reps while paused');

      if (sim.awaitingUnsafeAck) sim.acknowledgeUnsafe();
      if (sim.fatiguePauseOffered) sim.acknowledgeFatiguePause();
      sim.resume();
      await tester.pump(const Duration(seconds: 6));
      expect(sim.repsCompleted, greaterThan(before), reason: 'counting continues after resume');
      sim.dispose();
    });

    testWidgets('fatigue builds per rep, not per tick (regression: paused ~6s into every session)', (tester) async {
      final sim = SessionSimulator(repsTarget: 20, romTargetPercent: 80, seed: 3);
      sim.start();
      // 5 reps' worth of time: even at the maximum per-rep increase that
      // stays well under "critical".
      for (var i = 0; i < 28; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (sim.awaitingUnsafeAck) sim.acknowledgeUnsafe();
      }
      expect(sim.fatiguePauseOffered, isFalse);
      expect(sim.fatigueLevel, isNot(FatigueLevel.critical));
      sim.dispose();
    });

    testWidgets('an unsafe rep shows on the banner while paused for acknowledgement', (tester) async {
      for (var seed = 0; seed < 50; seed++) {
        final sim = SessionSimulator(repsTarget: 30, romTargetPercent: 80, seed: seed);
        sim.start();
        for (var i = 0; i < 120 && !sim.awaitingUnsafeAck; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        if (sim.awaitingUnsafeAck) {
          expect(sim.isRunning, isFalse);
          expect(sim.currentTier, SafetyTier.unsafe);
          sim.dispose();
          return;
        }
        sim.dispose();
      }
      fail('no seed produced an unsafe rep');
    });
  });

  test('SessionResult survives a JSON round trip', () {
    final back = SessionResult.fromJson(_result().toJson());
    expect(back.id, 'sess-1');
    expect(back.exercise.name, 'Elbow flexion');
    expect(back.repsCompleted, 4);
    expect(back.duration, const Duration(seconds: 95));
    expect(back.alerts.single.id, 'al-1');
    expect(back.worstTier, SafetyTier.needsCorrection);
    expect(back.peakActivation, MuscleActivation.moderate);
  });

  group('SessionJournal', () {
    setUp(_clearJournal);
    tearDown(_clearJournal);

    test('keeps the in-progress session until cleared', () async {
      await SessionJournal.saveInProgress('p1', _result());
      expect((await SessionJournal.readInProgress('p1'))?.result.repsCompleted, 4);
      expect(await SessionJournal.readInProgress('someone-else'), isNull);
      await SessionJournal.clearInProgress();
      expect(await SessionJournal.readInProgress('p1'), isNull);
    });

    test('queues offline sessions and uploads them once back online', () async {
      final repo = _FakeRepo(online: false);
      await SessionJournal.enqueue('p1', null, _result());
      expect(await SessionJournal.pendingCount('p1'), 1);

      expect(await SessionJournal.syncPending('p1', repo), 0);
      expect(await SessionJournal.pendingCount('p1'), 1, reason: 'still queued while offline');

      repo.online = true;
      expect(await SessionJournal.syncPending('p1', repo), 1);
      expect(repo.saved, ['sess-1']);
      expect(await SessionJournal.pendingCount('p1'), 0);
    });

    test('re-queuing the same session does not duplicate it', () async {
      await SessionJournal.enqueue('p1', null, _result());
      await SessionJournal.enqueue('p1', null, _result(reps: 5));
      expect(await SessionJournal.pendingCount('p1'), 1);
    });
  });

  testWidgets('system back mid-session asks before ending (Rule 24)', (tester) async {
    final connection = WearableConnectionController(patientId: 'p1', initiallyPaired: true, deviceSerial: 'IR-A1F3');
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

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('End rehabilitation session?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Keep going'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('End rehabilitation session?'), findsNothing);
    expect(find.byType(ActiveSessionScreen), findsOneWidget, reason: 'back did not exit the session');

    await tester.pumpWidget(const SizedBox());
    connection.dispose();
  });

  testWidgets('summary says a queued session is saved on the phone', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: SessionSummaryScreen(result: _result(), queued: true, onViewProgress: () {}),
    ));
    expect(find.text('Session saved'), findsOneWidget);
    expect(find.textContaining("upload automatically when you're back online"), findsOneWidget);
    expect(find.text('1 correction prompt'), findsOneWidget);
  });

  group('200% text scale', () {
    for (final (name, build) in [
      ('Session Summary', () => SessionSummaryScreen(result: _result(), queued: true, onViewProgress: () {})),
      (
        'Exercise Detail',
        () => ExerciseDetailScreen(
              exercise: _exercise,
              patientId: 'p1',
              connection: WearableConnectionController(patientId: 'p1', initiallyPaired: false),
              onViewProgress: () {},
            ),
      ),
    ]) {
      testWidgets('$name lays out without overflow', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_scaled(build()));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// Rule 13/28: OS text scaling up to 200% must not break layouts — any
/// RenderFlex overflow surfaces as a test exception here.
Widget _scaled(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0), disableAnimations: true),
        child: c!,
      ),
      home: child,
    );
