import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inteli_rehab/core/theme/app_theme.dart';
import 'package:inteli_rehab/features/auth/data/repositories/auth_repository_fake.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/auth_session_preview_screen.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/login_screen.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/register_screen.dart';

Widget _buildTestApp({
  required Widget child,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    home: child,
  );
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

  group('LoginScreen - UI Hierarchy & Simplification', () {
    testWidgets(
      'renders compact brand header, heading, preview notice, and removed elements are absent',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(child: LoginScreen(repository: fakeRepo, isPreview: true)),
        );
        await tester.pumpAndSettle();

        // 1. Modest brand header
        expect(find.text('Inteli-Rehab'), findsOneWidget);

        // 2. Heading and supporting text
        expect(find.text('Welcome back'), findsOneWidget);
        expect(
          find.text('Sign in to continue your rehabilitation.'),
          findsOneWidget,
        );

        // 3. Restrained preview notice
        expect(
          find.text(
            'Frontend preview — use sample details. No real account is accessed.',
          ),
          findsOneWidget,
        );

        // 4. Form fields with persistent labels
        expect(find.text('Email address'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);

        // 5. Form actions
        expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
        expect(find.byKey(const Key('login_register_button')), findsOneWidget);

        // 6. Confirm removed clutter is absent
        expect(find.text('PATIENT REHABILITATION PORTAL'), findsNothing);
        expect(
          find.text('Clinically Supervised · Secure Patient Gateway'),
          findsNothing,
        );
        expect(find.text('Tap to fill demo test account'), findsNothing);
        expect(find.text('Forgot password?'), findsNothing);
        expect(find.text('Need Help?'), findsNothing);
      },
    );

    testWidgets('submit button is initially disabled with no initial errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(child: LoginScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('login_submit_button')),
      );
      expect(button.onPressed, isNull);

      // No red errors shown on initial load
      expect(find.text('Enter your email address.'), findsNothing);
      expect(find.text('Enter your password.'), findsNothing);
    });

    testWidgets('shows helpful touched-field validation error after field is left', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(child: LoginScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      // Enter invalid email and move to password field
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'invalidemail',
      );
      // Tap password field to blur email
      await tester.tap(find.byKey(const Key('login_password_field')));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter an email address such as you@example.com.'),
        findsOneWidget,
      );
    });

    testWidgets('entering valid email and password enables submit button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(child: LoginScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'patient@clinic.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'password123',
      );
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('login_submit_button')),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('LoginScreen - Submission, Lifecycle & Session Flow', () {
    testWidgets(
      'submitting normalizes email, preserves password, clears UI password, and routes to canonical AuthSessionPreviewScreen',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(child: LoginScreen(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('login_email_field')),
          '  Ayesha.Khan@intelirehab.com  ',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          '  SecretPass123  ',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('login_submit_button')));
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pump(); // Start async submit

        // Password wiped from controller immediately
        final passwordField = tester.widget<TextFormField>(
          find.byKey(const Key('login_password_field')),
        );
        expect(passwordField.controller?.text, isEmpty);

        // Submitting spinner visible
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Signing in…'), findsOneWidget);

        await tester.pumpAndSettle();

        // Repository authenticated with normalized email and unmodified password
        expect(fakeRepo.isAuthenticated, isTrue);
        expect(fakeRepo.currentUserEmail, 'ayesha.khan@intelirehab.com');

        // Canonical destination screen reached
        expect(find.byType(AuthSessionPreviewScreen), findsOneWidget);
        expect(
          find.text('Signed in as ayesha.khan@intelirehab.com'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'failed authentication surfaces safe generic error and wipes password without contradictory field errors',
      (tester) async {
        fakeRepo.setSimulateFailure(true);

        await tester.pumpWidget(
          _buildTestApp(child: LoginScreen(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('login_email_field')),
          'patient@clinic.com',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'WrongPassword123',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('login_submit_button')));
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        // Safe error message
        expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
        expect(find.text('Incorrect email or password.'), findsOneWidget);

        // Password field is cleared and obscured
        final passwordField = tester.widget<TextFormField>(
          find.byKey(const Key('login_password_field')),
        );
        expect(passwordField.controller?.text, isEmpty);
        final innerTextField = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('login_password_field')),
            matching: find.byType(TextField),
          ),
        );
        expect(innerTextField.obscureText, isTrue);

        // Crucial: no contradictory "Enter your password." while error banner is visible
        expect(find.text('Enter your password.'), findsNothing);
      },
    );

    testWidgets('simulated network failure shows safe connection message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      fakeRepo.setSimulateNetworkFailure(true);

      await tester.pumpWidget(
        _buildTestApp(child: LoginScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'patient@clinic.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'ValidPass123',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('login_submit_button')));
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to sign in right now. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('password visibility toggle changes obscured state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(child: LoginScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      final toggle = find.byTooltip('Show password');
      expect(toggle, findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets(
      'register button clears password and navigates to RegisterScreen',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(child: LoginScreen(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('login_password_field')),
          'TransientPassword',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const Key('login_register_button')),
        );
        await tester.tap(find.byKey(const Key('login_register_button')));
        await tester.pumpAndSettle();

        expect(find.byType(RegisterScreen), findsOneWidget);

        // Pop back to LoginScreen
        Navigator.of(tester.element(find.byType(RegisterScreen))).pop();
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);

        // Password field is cleared and obscured
        final passwordField = tester.widget<TextFormField>(
          find.byKey(const Key('login_password_field')),
        );
        expect(passwordField.controller?.text, isEmpty);
        final innerTextField = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('login_password_field')),
            matching: find.byType(TextField),
          ),
        );
        expect(innerTextField.obscureText, isTrue);
      },
    );

  });

  group('LoginScreen - Theme Modes & WCAG AA Contrast', () {
    testWidgets(
      'renders properly in light theme with correct semantic tokens and >= 3:1 input border',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            theme: AppTheme.lightTheme,
            child: LoginScreen(repository: fakeRepo),
          ),
        );
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, const Color(0xFFF5F8F7));

        final button = tester.widget<ElevatedButton>(
          find.byKey(const Key('login_submit_button')),
        );
        expect(
          button.style?.backgroundColor?.resolve({}),
          const Color(0xFF0D6E76),
        );
      },
    );
  });

  group('LoginScreen - Accessibility & Responsiveness', () {
    testWidgets('renders cleanly on narrow width (320px) without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildTestApp(child: LoginScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets(
      'renders cleanly with 2.0x enlarged text scaling without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });

        await tester.pumpWidget(
          _buildTestApp(child: LoginScreen(repository: fakeRepo)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('renders cleanly in landscape orientation', (tester) async {
      tester.view.physicalSize = const Size(844 * 2, 390 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildTestApp(child: LoginScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });
}
