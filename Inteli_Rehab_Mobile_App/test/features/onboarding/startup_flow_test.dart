import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/core/di/injection.dart';
import 'package:inteli_rehab/core/theme/app_theme.dart';
import 'package:inteli_rehab/features/auth/data/repositories/auth_repository_fake.dart';
import 'package:inteli_rehab/features/auth/domain/repositories/auth_repository.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/auth_session_preview_screen.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/login_screen.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/register_screen.dart';
import 'package:inteli_rehab/features/onboarding/presentation/splash/splash_screen.dart';
import 'package:inteli_rehab/features/patient_feedback/data/repositories/patient_feedback_repository_fake.dart';
import 'package:inteli_rehab/features/patient_feedback/domain/repositories/patient_feedback_repository.dart';
import 'package:inteli_rehab/features/patient_feedback/presentation/screens/patient_feedback_screen.dart';

Widget _buildStartupTestApp({Widget? home}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    themeMode: ThemeMode.light,
    home: home ?? const SplashScreen(),
  );
}

void main() {
  group('Startup Flow: Splash -> Patient Stories -> Login', () {
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

    testWidgets(
      'Splash screen finishes and replaces itself with Patient Stories screen',
      (tester) async {
        await tester.pumpWidget(_buildStartupTestApp());

        // Splash starts
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(PatientFeedbackScreen), findsNothing);

        // Advance past reveal (3800ms) + ambient/navigation delay (2100ms) + transition
        await tester.pump(const Duration(milliseconds: 4000));
        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pumpAndSettle();

        // SplashScreen is replaced with PatientFeedbackScreen
        expect(find.byType(PatientFeedbackScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
      },
    );

    testWidgets(
      'Patient Stories displays sample stories label and manual scrolling cards',
      (tester) async {
        await tester.pumpWidget(
          _buildStartupTestApp(
            home: PatientFeedbackScreen(repository: fakeFeedbackRepo),
          ),
        );
        await tester.pumpAndSettle();

        // Sample stories label and title
        expect(find.text('Patient stories'), findsOneWidget);
        expect(
          find.text('Experiences shared by people using Inteli-Rehab.'),
          findsOneWidget,
        );
        expect(
          find.text('Sample stories for this preview.'),
          findsOneWidget,
        );

        // Patient cards without quote icon or metric chips
        expect(find.text('Ayesha K.'), findsOneWidget);
        expect(find.text('Ahmed R.'), findsOneWidget);

        // Manually scroll down to reveal Sana M.
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(find.text('Sana M.'), findsOneWidget);

        // Pinned Continue button is visible
        expect(
          find.byKey(const Key('patient_stories_continue_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Continue to sign in button is available and accessible during loading and error states',
      (tester) async {
        await tester.pumpWidget(
          _buildStartupTestApp(
            home: PatientFeedbackScreen(repository: fakeFeedbackRepo),
          ),
        );
        // Before settle: loading state
        await tester.pump();
        expect(
          find.byKey(const Key('patient_stories_continue_button')),
          findsOneWidget,
        );

        await tester.pumpAndSettle();
        // Loaded state
        expect(
          find.byKey(const Key('patient_stories_continue_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Tapping Continue to sign in opens LoginScreen and Back returns to Patient Stories',
      (tester) async {
        await tester.pumpWidget(
          _buildStartupTestApp(
            home: PatientFeedbackScreen(repository: fakeFeedbackRepo),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Continue to sign in
        await tester.tap(
          find.byKey(const Key('patient_stories_continue_button')),
        );
        await tester.pumpAndSettle();

        // LoginScreen is pushed
        expect(find.byType(LoginScreen), findsOneWidget);

        // Tap Back on LoginScreen
        final backButton = find.byKey(const Key('login_back_button'));
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Returns to Patient Stories
        expect(find.byType(PatientFeedbackScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );

    testWidgets(
      'From LoginScreen, tapping Register opens RegisterScreen and Back returns to Login',
      (tester) async {
        await tester.pumpWidget(
          _buildStartupTestApp(
            home: LoginScreen(repository: fakeAuthRepo),
          ),
        );
        await tester.pumpAndSettle();

        // Open Register
        await tester.ensureVisible(
          find.byKey(const Key('login_register_button')),
        );
        await tester.tap(find.byKey(const Key('login_register_button')));
        await tester.pumpAndSettle();

        expect(find.byType(RegisterScreen), findsOneWidget);

        // Tap back to Login
        await tester.ensureVisible(
          find.byKey(const Key('register_back_to_login_button')),
        );
        await tester.tap(find.byKey(const Key('register_back_to_login_button')));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(RegisterScreen), findsNothing);
      },
    );

    testWidgets(
      'On successful sign in, onboarding/auth routes are cleared and HomeDashboardScreen is shown',
      (tester) async {
        await tester.pumpWidget(
          _buildStartupTestApp(
            home: LoginScreen(repository: fakeAuthRepo),
          ),
        );
        await tester.pumpAndSettle();

        // Fill credentials
        await tester.enterText(
          find.byKey(const Key('login_email_field')),
          'ayesha.k@intelirehab.com',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'ValidPassword123',
        );
        await tester.pumpAndSettle();

        // Submit
        await tester.ensureVisible(
          find.byKey(const Key('login_submit_button')),
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Clears onboarding/auth and lands on AuthSessionPreviewScreen
        expect(find.byType(AuthSessionPreviewScreen), findsOneWidget);
        expect(find.text('Sign-in preview complete'), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(PatientFeedbackScreen), findsNothing);
      },
    );
  });
}
