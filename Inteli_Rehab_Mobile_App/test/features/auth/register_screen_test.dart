import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/core/theme/app_theme.dart';
import 'package:inteli_rehab/features/auth/data/repositories/auth_repository_fake.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/register_screen.dart';

Widget _buildTestApp({
  required Widget child,
  ThemeData? theme,
  double textScaleFactor = 1.0,
  Size size = const Size(400, 800),
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      textScaler: TextScaler.linear(textScaleFactor),
    ),
    child: MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late AuthRepositoryFake fakeRepo;

  setUp(() {
    fakeRepo = AuthRepositoryFake(allowInReleaseForTesting: true);
  });

  tearDown(() {
    fakeRepo.dispose();
  });

  group('RegisterScreen - UI & Error Prevention', () {
    testWidgets('renders preview mode banner and instructions card', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(child: RegisterScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Frontend Preview Mode'), findsOneWidget);
      expect(find.text('Clinic-Issued Registration ID'), findsOneWidget);
      expect(find.text('Register'), findsOneWidget);
    });

    testWidgets('register button is initially disabled', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(child: RegisterScreen(repository: fakeRepo)),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('register_submit_button')),
      );
      expect(button.onPressed, isNull);
    });

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
  });

  group('RegisterScreen - Submission & Honest Feedback', () {
    testWidgets(
      'submitting clears password, completes preview, pops, and shows honest SnackBar',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  key: const Key('open_register'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RegisterScreen(repository: fakeRepo),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open screen
        await tester.tap(find.byKey(const Key('open_register')));
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

        // Password wiped immediately
        final passwordField = tester.widget<TextFormField>(
          find.byKey(const Key('register_password_field')),
        );
        expect(passwordField.controller?.text, isEmpty);

        await tester.pumpAndSettle();

        // Popped back
        expect(find.byType(RegisterScreen), findsNothing);

        // Honest confirmation SnackBar displayed
        expect(
          find.textContaining(
            'Frontend Preview: Input accepted for AMC-004. Honest note: No real account was saved to the database.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('error state displays banner and does not pop', (tester) async {
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

      expect(find.byKey(const Key('register_error_banner')), findsOneWidget);
    });
  });

  group('RegisterScreen - Theme Modes & WCAG AA Contrast', () {
    testWidgets('renders properly in light theme', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.lightTheme,
          child: RegisterScreen(repository: fakeRepo),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(scaffold.backgroundColor, const Color(0xFFF5F8F7));

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('register_submit_button')),
      );
      expect(
        button.style?.backgroundColor?.resolve({}),
        const Color(0xFF0D6E76),
      );
      expect(
        button.style?.foregroundColor?.resolve({}),
        const Color(0xFFFFFFFF),
      );
    });

    testWidgets('renders properly in dark theme with bright mint button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          theme: AppTheme.darkTheme,
          child: RegisterScreen(repository: fakeRepo),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(scaffold.backgroundColor, const Color(0xFF0B2023));

      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('register_submit_button')),
      );
      expect(
        button.style?.backgroundColor?.resolve({}),
        const Color(0xFF31E8C6),
      );
      expect(
        button.style?.foregroundColor?.resolve({}),
        const Color(0xFF093D42),
      );
    });
  });

  group('RegisterScreen - Accessibility & Responsiveness', () {
    testWidgets('renders cleanly on narrow width (320px) without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildTestApp(
          child: RegisterScreen(repository: fakeRepo),
          size: const Size(320, 700),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders cleanly with 1.5x enlarged text scaling without overflow',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            child: RegisterScreen(repository: fakeRepo),
            textScaleFactor: 1.5,
            size: const Size(400, 900),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
