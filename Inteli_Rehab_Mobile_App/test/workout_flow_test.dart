// Today's workout: the plan's exercises one after another, with one summary at the end. Driven with the
// timer-based SessionSimulator and a fake saver, so no band and no server are needed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/session_cues.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/session_simulator.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/workout_flow_screen.dart';
import 'package:inteli_rehab_mobile_app/features/home/wearable_connection_controller.dart';

AssignedExercise _ex(String id, String name, {int sets = 1, int reps = 5, int? rest}) => AssignedExercise(
      assignmentId: 'a-$id',
      exerciseId: 'e-$id',
      name: name,
      target: 'Biceps',
      difficulty: 'Beginner',
      description: 'How to do $name.',
      sets: sets,
      repsTarget: reps,
      romTarget: 70,
      restSeconds: rest,
    );

final _exercises = [
  _ex('1', 'Elbow flexion'),
  _ex('2', 'Elbow extension', sets: 3, reps: 8, rest: 45),
  _ex('3', 'Forearm rotation'),
];

SessionResult _result(AssignedExercise e, {int reps = 5, int? pain, EndedReason? ended}) => SessionResult(
      id: 's-${e.exerciseId}',
      analysisId: 'm-${e.exerciseId}',
      startedAt: DateTime.utc(2026, 1, 1),
      exercise: e,
      repsCompleted: reps,
      romAchieved: 74,
      peakJointAngle: 100,
      achievedRangeDegrees: 100,
      peakActivation: MuscleActivation.moderate,
      duration: const Duration(seconds: 70),
      peakFatigue: FatigueLevel.normal,
      worstTier: SafetyTier.normal,
      alerts: const [],
      painLevel: pain,
      endedReason: ended,
    );

void main() {
  late WearableConnectionController connection;
  late SessionCues cues;
  late List<SessionResult> saved;

  Future<void> open(WidgetTester tester, {List<AssignedExercise>? exercises}) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    connection = WearableConnectionController(patientId: 'p1', initiallyPaired: true, deviceSerial: 'IR-A1F3')
      ..state = WearableConnState.connected; // as if the band were on and talking
    cues = SessionCues(speak: (_) async {}, stop: () async {});
    saved = [];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WorkoutFlowScreen(
                  exercises: exercises ?? _exercises,
                  patientId: 'p1',
                  connection: connection,
                  onViewProgress: () {},
                  cues: cues,
                  loadSetup: () async => SessionSetup.defaults,
                  saveResult: (r) async {
                    saved.add(r);
                    return (queued: false, failed: false);
                  },
                  sessionFactory: (c, e) => SessionSimulator(repsTarget: e.repsTarget, romTargetPercent: 70, seed: 1),
                ),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(); // the tap pushes the route; the next frame builds it
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    connection.dispose();
    cues.dispose();
  }

  /// Starts the exercise on the "next up" screen and ends it straight away, skipping the question.
  Future<void> doExercise(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(); // the setup loads...
    await tester.pump(); // ...then the exercise screen is pushed...
    await tester.pump(const Duration(milliseconds: 600)); // ...and slides in
    await tester.tap(find.text('End Session'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'End session'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pump(); // the dialog closes and the result is saved...
    await tester.pump(); // ...the exercise screen hands it back...
    await tester.pump(const Duration(milliseconds: 600)); // ...and slides away
  }

  testWidgets('opens on the first exercise, with the whole workout in view', (tester) async {
    await open(tester);
    expect(find.text("Today's workout"), findsOneWidget);
    expect(find.text('First up'), findsOneWidget);
    expect(find.text('Exercise 1 of 3'), findsOneWidget);
    expect(find.text('Elbow flexion'), findsOneWidget);
    expect(find.text('How to do Elbow flexion.'), findsOneWidget);
    expect(find.text('Start exercise'), findsOneWidget);
    await close(tester);
  });

  testWidgets('shows the rest length only for exercises with more than one set', (tester) async {
    await open(tester, exercises: [_ex('2', 'Elbow extension', sets: 3, reps: 8, rest: 45)]);
    expect(find.textContaining('45s rest between sets'), findsOneWidget);
    await close(tester);
    await open(tester, exercises: [_ex('1', 'Elbow flexion')]);
    expect(find.textContaining('rest between sets'), findsNothing);
    await close(tester);
  });

  testWidgets('doing an exercise saves it and moves on to the next, with a recap', (tester) async {
    await open(tester);
    await doExercise(tester);

    expect(saved.length, 1);
    expect(saved.single.exercise.name, 'Elbow flexion');
    expect(find.text('Next up'), findsOneWidget);
    expect(find.text('Exercise 2 of 3'), findsOneWidget);
    expect(find.text('Elbow extension'), findsOneWidget);
    expect(find.textContaining('Elbow flexion:'), findsOneWidget, reason: 'a recap of the one just done');
    expect(find.text('Start next exercise'), findsOneWidget);
    await close(tester);
  });

  testWidgets('skipping every remaining exercise ends in one summary that lists what was left', (tester) async {
    await open(tester);
    await doExercise(tester);
    await tester.tap(find.text('Skip this one'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Exercise 3 of 3'), findsOneWidget);
    expect(find.text('Skip and finish'), findsOneWidget);
    await tester.tap(find.text('Skip and finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Workout summary'), findsOneWidget);
    expect(find.text('Left for another time'), findsOneWidget);
    expect(find.text('Elbow extension'), findsOneWidget);
    expect(find.text('Forearm rotation'), findsOneWidget);
    expect(find.text('Elbow flexion'), findsOneWidget, reason: 'listed once, under what was done');
    expect(saved.length, 1);
    await close(tester);
  });

  testWidgets('finishing early asks first, and the exercises not reached count as left for later', (tester) async {
    await open(tester);
    await doExercise(tester);
    await tester.tap(find.text('Finish workout'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Finish the workout here?'), findsOneWidget);

    await tester.tap(find.text('Keep going'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Workout summary'), findsNothing);

    await tester.tap(find.text('Finish workout'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Workout summary'), findsOneWidget);
    expect(find.text('Elbow extension'), findsOneWidget);
    expect(find.text('Forearm rotation'), findsOneWidget);
    await close(tester);
  });

  testWidgets('leaving before anything was done just closes the workout', (tester) async {
    await open(tester);
    await tester.tap(find.text('Finish workout'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nothing has been recorded yet.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("Today's workout"), findsNothing);
    expect(find.text('open'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the system back button asks before leaving', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Finish the workout here?'), findsOneWidget);
    await close(tester);
  });

  group('WorkoutSummaryScreen', () {
    Widget host(Widget child, {double scale = 1}) => MaterialApp(
          theme: AppTheme.light(),
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
            child: c!,
          ),
          home: child,
        );

    testWidgets('adds up the whole workout, and says when something is waiting to upload', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(WorkoutSummaryScreen(
        outcomes: [
          SessionOutcome(_result(_exercises[0], reps: 5), queued: true),
          SessionOutcome(_result(_exercises[1], reps: 8, pain: 3)),
        ],
        skipped: [_exercises[2]],
        onViewProgress: () {},
      )));
      expect(find.text('Workout done'), findsOneWidget);
      expect(find.text('13'), findsOneWidget, reason: '5 + 8 reps');
      expect(find.text('2m 20s'), findsOneWidget, reason: '70 s + 70 s');
      expect(find.textContaining("it'll upload automatically"), findsOneWidget);
      expect(find.textContaining('pain 3/10'), findsOneWidget);
      expect(find.text('Forearm rotation'), findsOneWidget);
    });

    testWidgets('a high pain rating is called out; a store failure is said plainly', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(WorkoutSummaryScreen(
        outcomes: [SessionOutcome(_result(_exercises[0], pain: 8, ended: EndedReason.pain), saveFailed: true)],
        skipped: const [],
        onViewProgress: () {},
      )));
      expect(find.text('Some of the workout was not saved'), findsOneWidget);
      expect(find.textContaining('You rated your pain 8 out of 10'), findsOneWidget);
      expect(find.textContaining('stopped early'), findsOneWidget);
      expect(find.text('Left for another time'), findsNothing);
    });

    testWidgets('an empty workout does not claim anything was done', (tester) async {
      await tester.pumpWidget(host(WorkoutSummaryScreen(outcomes: const [], skipped: [_exercises[0]], onViewProgress: () {})));
      expect(find.text('Nothing was recorded this time.'), findsOneWidget);
    });

    testWidgets('lays out at 200% text without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(
        WorkoutSummaryScreen(
          outcomes: [SessionOutcome(_result(_exercises[0], pain: 8, ended: EndedReason.tired), queued: true)],
          skipped: [_exercises[1]],
          onViewProgress: () {},
        ),
        scale: 2,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
