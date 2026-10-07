// Skipping the end-of-session question ("How did that feel?") still saves the session, with no pain
// rating and no reason. Its own file because only one test per file can save a session through the
// widget tree (see _letSaveFinish in session_screen_extras_test.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/platform/device_services.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/active_session_screen.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/session_cues.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/session_simulator.dart';
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

final _dir = Directory.systemTemp.createTempSync('session_skip_test_');

void main() {
  setUpAll(() => DeviceServices.overrideFilesDir(_dir));

  testWidgets('skipping the question still saves the session', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final connection = WearableConnectionController(patientId: 'p1', initiallyPaired: true, deviceSerial: 'IR-A1F3');
    final cues = SessionCues(speak: (_) async {}, stop: () async {});
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

    await tester.tap(find.text('End Session'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'End session'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('How did that feel?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    await tester.pump();

    // The save ends in real file writes; give them real time, resuming the code after each.
    for (var i = 0; i < 60 && find.text('Session Summary').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Session Summary'), findsOneWidget);
    expect(find.textContaining('Stopped early'), findsNothing);
    expect(find.textContaining('Pain rating'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    connection.dispose();
    cues.dispose();
  });
}
