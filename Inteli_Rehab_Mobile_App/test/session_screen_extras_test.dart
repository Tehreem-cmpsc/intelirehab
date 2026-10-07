// The session screens' newer parts: "This hurts", the end-of-session question, the set-by-set summary,
// and the spoken-cue switch. Driven with the timer-based SessionSimulator, so no band is needed.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/platform/device_services.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/active_session_screen.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/session_cues.dart';
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
  repsTarget: 5,
  romTarget: 80,
);

final _dir = Directory.systemTemp.createTempSync('session_extras_test_');

SessionResult _result() => SessionResult(
      id: 's1',
      analysisId: 'a1',
      startedAt: DateTime.utc(2026, 1, 1),
      exercise: _exercise,
      repsCompleted: 12,
      romAchieved: 72,
      peakJointAngle: 110,
      achievedRangeDegrees: 100,
      peakActivation: MuscleActivation.moderate,
      duration: const Duration(minutes: 6),
      peakFatigue: FatigueLevel.mild,
      worstTier: SafetyTier.needsCorrection,
      alerts: [
        SessionAlert(id: 'x1', tier: SafetyTier.needsCorrection, message: 'Slow down', at: DateTime.utc(2026, 1, 1)),
        SessionAlert(
            id: 'x2', tier: SafetyTier.needsCorrection, message: 'You reported pain.', at: DateTime.utc(2026, 1, 1), pain: true),
      ],
      sets: const [
        SetResult(number: 1, reps: 5, romPercent: 80, corrections: 1, unsafe: 0, fatigue: FatigueLevel.normal),
        SetResult(number: 2, reps: 5, romPercent: 74, corrections: 0, unsafe: 0, fatigue: FatigueLevel.mild),
        SetResult(number: 3, reps: 2, romPercent: 60, corrections: 0, unsafe: 0, fatigue: FatigueLevel.moderate),
      ],
      repsPlanned: 15,
      painLevel: 8,
      endedReason: EndedReason.tired,
    );

/// Saving the session ends in a real file write (the offline journal), which FakeAsync's clock does
/// not advance: give it real time, then draw the screen it navigates to. Only ONE test per file may
/// save a session this way: the journal's static lock keeps the first test's (finished) clock, so a
/// second save in the same file never completes. The "Skip" path lives in session_skip_question_test.dart.
Future<void> _letSaveFinish(WidgetTester tester) async {
  // Each await in the save needs real time for its file write, then a pump to resume the code after it.
  for (var i = 0; i < 60 && find.text('Session Summary').evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => DeviceServices.overrideFilesDir(_dir));

  testWidgets('summary shows the sets, the pain rating and why it stopped, and keeps pain out of the prompts',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 4200); // tall enough that the lazy list builds every row
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: SessionSummaryScreen(result: _result(), onViewProgress: () {}),
    ));
    expect(find.text('12/15'), findsOneWidget, reason: 'out of every set, not just one');
    expect(find.text('1 correction prompt'), findsOneWidget, reason: 'the pain report is not a form fault');
    expect(find.text('You reported pain 1 time'), findsOneWidget);
    expect(find.text('Pain rating: 8 out of 10'), findsOneWidget);
    expect(find.text('Stopped early: too tired'), findsOneWidget);
    expect(find.text('Set by set'), findsOneWidget);
    expect(find.text('Set 3'), findsOneWidget);
    expect(find.textContaining('2/5 reps'), findsOneWidget);
  });

  testWidgets('summary of a one-set or older session has no set table', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final plain = SessionResult.fromJson(_result().toJson()..remove('sets')..remove('repsPlanned'));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: SessionSummaryScreen(result: plain, onViewProgress: () {}),
    ));
    expect(find.text('Set by set'), findsNothing);
  });

  testWidgets('summary lays out at 200% text without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0), disableAnimations: true),
        child: c!,
      ),
      home: SessionSummaryScreen(result: _result(), onViewProgress: () {}),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  group('the session screen', () {
    late WearableConnectionController connection;
    late List<String> spoken;
    late SessionCues cues;

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      connection = WearableConnectionController(patientId: 'p1', initiallyPaired: true, deviceSerial: 'IR-A1F3');
      spoken = [];
      cues = SessionCues(speak: (t) async => spoken.add(t), stop: () async {});
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: ActiveSessionScreen(
          exercise: _exercise,
          patientId: 'p1',
          connection: connection,
          onViewProgress: () {},
          cues: cues,
          sessionFactory: (c, e) => SessionSimulator(repsTarget: 5, romTargetPercent: 80, seed: 1),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> close(WidgetTester tester) async {
      // Let the session's own background file writes (its journal) finish before the next test starts,
      // or their queue stays blocked behind work that needs this test's clock.
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpWidget(const SizedBox());
      connection.dispose();
      cues.dispose();
    }

    testWidgets('ending early asks how it felt and why, and the answers reach the summary', (tester) async {
      await open(tester);
      await tester.tap(find.text('End Session'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(FilledButton, 'End session'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('How did that feel?'), findsOneWidget);
      expect(find.text('Why did you stop early?'), findsOneWidget);
      await tester.tap(find.text('Too tired'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await _letSaveFinish(tester);

      expect(find.text('Session Summary'), findsOneWidget);
      expect(find.text('Stopped early: too tired'), findsOneWidget);
      expect(find.textContaining('Pain rating'), findsNothing, reason: 'the pain slider was left alone');
      await close(tester);
    });

    testWidgets('the speaker button switches spoken cues off and on', (tester) async {
      await open(tester);
      expect(cues.enabled, isTrue);
      await tester.tap(find.byTooltip('Turn spoken cues off'));
      await tester.pump();
      expect(cues.enabled, isFalse);
      cues.say('hello');
      expect(spoken, isEmpty, reason: 'muted');
      await tester.tap(find.byTooltip('Turn spoken cues on'));
      await tester.pump();
      expect(cues.enabled, isTrue);
      cues.say('hello');
      expect(spoken, ['hello']);
      await close(tester);
    });

    // Last in the group: it leaves the session's background journal writes running, which must not
    // hold up the save flows above.
    testWidgets('"This hurts" pauses at once and offers to stop or carry on', (tester) async {
      await open(tester);
      expect(find.text('This hurts'), findsOneWidget);

      await tester.tap(find.text('This hurts'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Pain noted'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Carry on'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Pain noted'), findsNothing);
      expect(find.byType(ActiveSessionScreen), findsOneWidget);
      await close(tester);
    });
  });

  group('SessionCues', () {
    test('says nothing for blank text, and never throws if speaking fails', () async {
      final said = <String>[];
      final cues = SessionCues(speak: (t) async => said.add(t), stop: () async {});
      cues.say('   ');
      expect(said, isEmpty);
      final broken = SessionCues(speak: (_) async => throw StateError('no engine'), stop: () async {});
      broken.say('rep');
      await Future<void>.delayed(Duration.zero);
      cues.dispose();
      broken.dispose();
    });

    test('the off switch is remembered', () async {
      final a = SessionCues(speak: (_) async {}, stop: () async {});
      await a.setEnabled(false);
      final b = SessionCues(speak: (_) async {}, stop: () async {});
      await b.load();
      expect(b.enabled, isFalse);
      await b.setEnabled(true);
      final c = SessionCues(speak: (_) async {}, stop: () async {});
      await c.load();
      expect(c.enabled, isTrue);
      a.dispose();
      b.dispose();
      c.dispose();
    });
  });
}
