import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/core/di/injection.dart';
import 'package:inteli_rehab/core/theme/app_theme.dart';
import 'package:inteli_rehab/features/auth/data/repositories/auth_repository_fake.dart';
import 'package:inteli_rehab/features/auth/domain/repositories/auth_repository.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/login_screen.dart';
import 'package:inteli_rehab/features/patient_feedback/data/repositories/patient_feedback_repository_fake.dart';
import 'package:inteli_rehab/features/patient_feedback/domain/entities/patient_feedback_entity.dart';
import 'package:inteli_rehab/features/patient_feedback/domain/repositories/patient_feedback_repository.dart';
import 'package:inteli_rehab/features/patient_feedback/presentation/screens/patient_feedback_screen.dart';
import 'package:inteli_rehab/features/patient_feedback/presentation/widgets/feedback_state_panel.dart';
import 'package:inteli_rehab/features/patient_feedback/presentation/widgets/patient_feedback_card.dart';
import 'package:inteli_rehab/features/patient_feedback/presentation/widgets/patient_stories_header.dart';

class _DelayedFeedbackRepo implements PatientFeedbackRepository {
  final Completer<List<PatientFeedbackEntity>> completer = Completer();
  @override
  Future<List<PatientFeedbackEntity>> getFeaturedFeedback() => completer.future;
}

class _EmptyFeedbackRepo implements PatientFeedbackRepository {
  @override
  Future<List<PatientFeedbackEntity>> getFeaturedFeedback() async => [];
}

class _ErrorFeedbackRepo implements PatientFeedbackRepository {
  int callCount = 0;
  bool shouldFail = true;

  @override
  Future<List<PatientFeedbackEntity>> getFeaturedFeedback() async {
    callCount++;
    if (shouldFail) {
      throw Exception('Network error');
    }
    return [
      PatientFeedbackEntity(
        id: 'retry-1',
        patientDisplayName: 'Recovered Patient',
        message: 'Successfully loaded after retry.',
        exerciseName: 'Patient experience',
        rating: 5,
        submittedAt: DateTime(2026, 9, 28),
      ),
    ];
  }
}

Widget _wrap(Widget child, {TextScaler textScaler = TextScaler.noScaling}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    themeMode: ThemeMode.light,
    home: Builder(
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child,
        );
      },
    ),
  );
}

void main() {
  group('PatientFeedbackScreen Visual Hierarchy & Behavior', () {
    late AuthRepositoryFake fakeAuthRepo;
    late PatientFeedbackRepositoryFake fakeFeedbackRepo;

    setUp(() {
      sl.reset();
      fakeAuthRepo = AuthRepositoryFake(allowInReleaseForTesting: true);
      fakeFeedbackRepo = PatientFeedbackRepositoryFake();
      sl.registerLazySingleton<AuthRepository>(() => fakeAuthRepo);
      sl.registerLazySingleton<PatientFeedbackRepository>(() => fakeFeedbackRepo);
    });

    tearDown(() {
      fakeAuthRepo.dispose();
      sl.reset();
    });

    testWidgets('Header displays aligned logo and wordmark without extra clutter', (tester) async {
      await tester.pumpWidget(_wrap(PatientFeedbackScreen(repository: fakeFeedbackRepo)));
      await tester.pumpAndSettle();

      expect(find.byType(PatientStoriesHeader), findsOneWidget);
      expect(find.text('Inteli-Rehab'), findsOneWidget);
      expect(find.bySemanticsLabel('Inteli-Rehab logo'), findsOneWidget);
    });

    testWidgets('Introduction is persistent and visible across loading state', (tester) async {
      final delayedRepo = _DelayedFeedbackRepo();
      await tester.pumpWidget(_wrap(PatientFeedbackScreen(repository: delayedRepo)));
      await tester.pump();

      // Introduction must remain visible during loading
      expect(find.text('Patient stories'), findsOneWidget);
      expect(find.text('Experiences shared by people using Inteli-Rehab.'), findsOneWidget);
      expect(find.text('Loading patient stories…'), findsOneWidget);
      expect(find.byType(FeedbackStatePanel), findsOneWidget);

      delayedRepo.completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('Introduction is persistent and visible across empty state', (tester) async {
      await tester.pumpWidget(_wrap(PatientFeedbackScreen(repository: _EmptyFeedbackRepo())));
      await tester.pumpAndSettle();

      expect(find.text('Patient stories'), findsOneWidget);
      expect(find.text('Experiences shared by people using Inteli-Rehab.'), findsOneWidget);
      expect(find.text('Patient stories will appear here'), findsOneWidget);
      expect(find.text('You can continue to sign in.'), findsOneWidget);
    });

    testWidgets('Introduction is persistent and error state allows retry', (tester) async {
      final errorRepo = _ErrorFeedbackRepo();
      await tester.pumpWidget(_wrap(PatientFeedbackScreen(repository: errorRepo)));
      await tester.pumpAndSettle();

      expect(find.text('Patient stories'), findsOneWidget);
      expect(find.text("Patient stories couldn't load"), findsOneWidget);
      expect(find.text('Please try again, or continue to sign in.'), findsOneWidget);

      final tryAgainBtn = find.byType(OutlinedButton);
      expect(tryAgainBtn, findsOneWidget);

      errorRepo.shouldFail = false;
      await tester.tap(tryAgainBtn);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Recovered Patient'), findsOneWidget);
      expect(find.text('“Successfully loaded after retry.”'), findsOneWidget);
    });

    testWidgets('Renders refined cards with honest preview notice and Unicode initials', (tester) async {
      await tester.pumpWidget(_wrap(PatientFeedbackScreen(repository: fakeFeedbackRepo)));
      await tester.pumpAndSettle();

      expect(find.text('Sample stories for this preview.'), findsOneWidget);
      expect(find.byType(PatientFeedbackCard), findsNWidgets(3));

      expect(find.text('“I find the exercise instructions easy to follow, with everything I need in one place.”'), findsOneWidget);
      expect(find.text('Ayesha K.'), findsOneWidget);
      expect(find.text('AK'), findsOneWidget);

      expect(find.text('“My session summary helps me explain how practice went when I speak with my physiotherapist.”'), findsOneWidget);
      expect(find.text('Ahmed R.'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
    });

    testWidgets('Continue to sign in button is pinned and min height is at least 56dp', (tester) async {
      await tester.pumpWidget(_wrap(PatientFeedbackScreen(repository: fakeFeedbackRepo)));
      await tester.pumpAndSettle();

      final btnFinder = find.byKey(const Key('patient_stories_continue_button'));
      expect(btnFinder, findsOneWidget);

      final size = tester.getSize(btnFinder);
      expect(size.height, greaterThanOrEqualTo(56.0));
    });

    testWidgets('Tapping Continue to sign in disables button during navigation to prevent duplicates', (tester) async {
      await tester.pumpWidget(_wrap(PatientFeedbackScreen(repository: fakeFeedbackRepo, authRepository: fakeAuthRepo)));
      await tester.pumpAndSettle();

      final btnFinder = find.byKey(const Key('patient_stories_continue_button'));
      await tester.tap(btnFinder);
      await tester.pump();

      // Check button is disabled while navigating
      final buttonWidget = tester.widget<ElevatedButton>(btnFinder);
      expect(buttonWidget.onPressed, isNull);

      // Complete navigation
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Responsiveness: renders cleanly on narrow screen (320dp)', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(PatientFeedbackScreen(repository: fakeFeedbackRepo)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Patient stories'), findsOneWidget);
      expect(find.byKey(const Key('patient_stories_continue_button')), findsOneWidget);
    });

    testWidgets('Accessibility: renders cleanly with 200% text scaling without overflow', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(
        PatientFeedbackScreen(repository: fakeFeedbackRepo),
        textScaler: const TextScaler.linear(2.0),
      ));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      if (err != null) {
        // ignore: avoid_print
        print(err.toString());
      }
      expect(err, isNull);
      expect(find.text('Patient stories'), findsOneWidget);
    });

    testWidgets('Landscape layout: scrollable without overflow', (tester) async {
      tester.view.physicalSize = const Size(800 * 2, 400 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(PatientFeedbackScreen(repository: fakeFeedbackRepo)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('patient_stories_continue_button')), findsOneWidget);
    });
  });
}
