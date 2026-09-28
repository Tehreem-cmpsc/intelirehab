import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inteli_rehab/core/theme/app_theme.dart';
import 'package:inteli_rehab/features/auth/data/repositories/auth_repository_fake.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/login_screen.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/register_screen.dart';

Widget _buildTestApp({required Widget child, ThemeData? theme}) {
  return MaterialApp(theme: theme ?? AppTheme.lightTheme, home: child);
}

void main() {
  late AuthRepositoryFake fakeRepo;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    fakeRepo = AuthRepositoryFake(allowInReleaseForTesting: true);
  });

  tearDown(() {
    fakeRepo.dispose();
  });

  group('RegisterScreen - UI Hierarchy & Layout', () {
    testWidgets('renders clean hierarchy A through J without clutter or logo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: RegisterScreen(repository: fakeRepo, isPreview: true),
        ),
      );
      await tester.pumpAndSettle();

      // A. Compact Back control
      expect(find.byKey(const Key('register_back_button')), findsOneWidget);
      expect(find.byTooltip('Back to sign in'), findsOneWidget);

      // B. Heading: "Patient registration"
      expect(find.text('Patient registration'), findsOneWidget);

      // C. Supporting text
      expect(
        find.text('Use the registration ID provided by your clinic.'),
        findsOneWidget,
      );

      // D. Restrained preview notice
      expect(
        find.text(
          'Frontend preview — use sample details. No account will be created.',
        ),
        findsOneWidget,
      );

      // E, F, G. Field labels
      expect(find.text('Clinic registration ID'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Create password'), findsOneWidget);

      // Helper texts
      expect(
        find.text('Use the registration ID given to you by your clinic.'),
        findsOneWidget,
      );
      expect(find.text('Use at least 8 characters.'), findsOneWidget);

      // I, J. Actions
      expect(find.byKey(const Key('register_submit_button')), findsOneWidget);
      expect(
        find.byKey(const Key('register_back_to_login_button')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('Already registered?'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Sign in'),
        ),
        findsOneWidget,
      );

      // Ensure NO logo on registration screen
      expect(find.byType(Image), findsNothing);

      // Ensure old card clutter is removed
      expect(find.textContaining('Frontend Preview Mode'), findsNothing);
      expect(find.text('Clinic-Issued Registration ID'), findsNothing);
    });

    testWidgets(
      'register button is initially disabled with no initial errors',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(child: RegisterScreen(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('register_submit_button')),
        );
        expect(button.onPressed, isNull);

        // No red errors shown on initial load
        expect(find.text('Enter your clinic registration ID.'), findsNothing);
        expect(find.text('Enter your email address.'), findsNothing);
        expect(find.text('Enter your password.'), findsNothing);
      },
    );

    testWidgets(
      'shows considerate touched-field validation only after leaving field',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(child: RegisterScreen(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        // Enter invalid clinic ID
        await tester.enterText(
          find.byKey(const Key('register_reg_id_field')),
          'NO',
        );
        await tester.pump();
        // While typing, error is suppressed until focus moves away
        expect(
          find.text('Registration ID must be at least 3 characters long.'),
          findsNothing,
        );

        // Move focus to email
        await tester.tap(find.byKey(const Key('register_email_field')));
        await tester.pumpAndSettle();

        // Error appears on reg ID
        expect(
          find.text('Registration ID must be at least 3 characters long.'),
          findsOneWidget,
        );

        // Enter invalid email
        await tester.enterText(
          find.byKey(const Key('register_email_field')),
          'invalid-email',
        );
        await tester.pump();

        // Move focus to password
        await tester.ensureVisible(
          find.byKey(const Key('register_password_field')),
        );
        await tester.tap(find.byKey(const Key('register_password_field')));
        await tester.pumpAndSettle();

        // Error appears on email
        expect(
          find.text('Enter an email address such as you@example.com.'),
          findsOneWidget,
        );

        // Correct the reg ID
        await tester.enterText(
          find.byKey(const Key('register_reg_id_field')),
          'REG-101',
        );
        await tester.pumpAndSettle();

        // Reg ID error disappears
        expect(
          find.text('Registration ID must be at least 3 characters long.'),
          findsNothing,
        );
      },
    );

    testWidgets('validating inputs enables register button', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(child: RegisterScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register_reg_id_field')),
        'REG-101',
      );
      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'ayesha@intelirehab.com',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'ValidPassword123',
      );
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('register_submit_button')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('password visibility toggle changes obscured state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(child: RegisterScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      final toggle = find.byTooltip('Show password');
      expect(toggle, findsOneWidget);

      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide password'), findsOneWidget);
    });
  });

  group('RegisterScreen - Submission, Lifecycle & Result Return', () {
    testWidgets(
      'submitting clears password immediately, pops with true, and LoginScreen shows confirmation',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(child: LoginScreen(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        // Navigate to RegisterScreen
        await tester.ensureVisible(
          find.byKey(const Key('login_register_button')),
        );
        await tester.tap(find.byKey(const Key('login_register_button')));
        await tester.pumpAndSettle();

        expect(find.byType(RegisterScreen), findsOneWidget);

        // Enter valid registration details
        await tester.enterText(
          find.byKey(const Key('register_reg_id_field')),
          'AMC-004',
        );
        await tester.enterText(
          find.byKey(const Key('register_email_field')),
          'patient@clinic.com',
        );
        await tester.enterText(
          find.byKey(const Key('register_password_field')),
          'Password123!',
        );
        await tester.pumpAndSettle();

        // Submit
        await tester.ensureVisible(
          find.byKey(const Key('register_submit_button')),
        );
        await tester.tap(find.byKey(const Key('register_submit_button')));
        await tester.pump(); // Submit initiates

        // Password wiped immediately from controller
        final passwordField = tester.widget<TextFormField>(
          find.byKey(const Key('register_password_field')),
        );
        expect(passwordField.controller?.text, isEmpty);

        await tester.pumpAndSettle();

        // Popped back to LoginScreen
        expect(find.byType(RegisterScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);

        // Accessible confirmation banner displayed on LoginScreen
        expect(
          find.byKey(const Key('login_confirmation_banner')),
          findsOneWidget,
        );
        expect(
          find.text('Registration preview complete. No account was created.'),
          findsOneWidget,
        );
        // Does NOT echo the clinic registration ID
        expect(find.textContaining('AMC-004'), findsNothing);

        // Editing email on LoginScreen dismisses the confirmation banner
        await tester.enterText(find.byKey(const Key('login_email_field')), 'a');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('login_confirmation_banner')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'error state displays safe message without popping and preserves inputs',
      (tester) async {
        fakeRepo.setSimulateFailure(true);

        await tester.pumpWidget(
          _buildTestApp(child: RegisterScreen(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('register_reg_id_field')),
          'AMC-004',
        );
        await tester.enterText(
          find.byKey(const Key('register_email_field')),
          'patient@clinic.com',
        );
        await tester.enterText(
          find.byKey(const Key('register_password_field')),
          'Password123!',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('register_submit_button')),
        );
        await tester.tap(find.byKey(const Key('register_submit_button')));
        await tester.pumpAndSettle();

        // Screen stays open
        expect(find.byType(RegisterScreen), findsOneWidget);

        // Safe error banner displayed
        expect(find.byKey(const Key('register_error_banner')), findsOneWidget);
        expect(
          find.text('We couldn’t complete registration. Please try again.'),
          findsOneWidget,
        );

        // Email and clinic ID preserved
        final regIdField = tester.widget<TextFormField>(
          find.byKey(const Key('register_reg_id_field')),
        );
        expect(regIdField.controller?.text, 'AMC-004');

        final emailField = tester.widget<TextFormField>(
          find.byKey(const Key('register_email_field')),
        );
        expect(emailField.controller?.text, 'patient@clinic.com');

        // Password cleared
        final passwordField = tester.widget<TextFormField>(
          find.byKey(const Key('register_password_field')),
        );
        expect(passwordField.controller?.text, isEmpty);

        // No contradictory password required error
        expect(find.text('Enter your password.'), findsNothing);
      },
    );

    testWidgets('password field done action submits form when valid', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RegisterScreen(repository: fakeRepo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('register_reg_id_field')),
        'AMC-004',
      );
      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'patient@clinic.com',
      );
      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'Password123!',
      );
      await tester.pumpAndSettle();

      // Trigger Done on password field
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Should initiate submit and clear password
      final passwordField = tester.widget<TextFormField>(
        find.byKey(const Key('register_password_field')),
      );
      expect(passwordField.controller?.text, isEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('back button returns to Login without result', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(child: LoginScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('login_register_button')),
      );
      await tester.tap(find.byKey(const Key('login_register_button')));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('register_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byKey(const Key('login_confirmation_banner')), findsNothing);
    });

    testWidgets('secondary Sign In action returns to Login', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(child: LoginScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('login_register_button')),
      );
      await tester.tap(find.byKey(const Key('login_register_button')));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('register_back_to_login_button')),
      );
      await tester.tap(find.byKey(const Key('register_back_to_login_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byKey(const Key('login_confirmation_banner')), findsNothing);
    });
  });

  group('RegisterScreen - Accessibility & Responsiveness', () {
    testWidgets('renders cleanly on narrow width (320px) without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestApp(child: RegisterScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly with 200% text scaling without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _buildTestApp(child: RegisterScreen(repository: fakeRepo)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders cleanly in landscape orientation without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844 * 2, 390 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestApp(child: RegisterScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
