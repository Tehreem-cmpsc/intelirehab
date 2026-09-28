import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/core/theme/theme_controller.dart';
import 'package:inteli_rehab_mobile_app/core/widgets/theme_toggle.dart';
import 'package:inteli_rehab_mobile_app/features/onboarding/welcome_screen.dart';

/// Mirrors InteliRehabApp's wiring (ThemeScope above MaterialApp) without
/// the Supabase-backed AuthGate.
Widget _app(ThemeController controller) => ThemeScope(
      controller: controller,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: controller,
        builder: (context, mode, _) => MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          builder: (context, child) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
          home: const WelcomeScreen(),
        ),
      ),
    );

Brightness _brightnessOf(WidgetTester tester, Finder finder) =>
    Theme.of(tester.element(finder)).brightness;

void main() {
  testWidgets('theme chosen on the welcome page carries through onboarding', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final controller = ThemeController(ThemeMode.light);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    expect(_brightnessOf(tester, find.byType(WelcomeScreen)), Brightness.light);

    await tester.tap(find.byType(ThemeToggle));
    await tester.pumpAndSettle();
    expect(controller.value, ThemeMode.dark);
    expect(_brightnessOf(tester, find.byType(WelcomeScreen)), Brightness.dark);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us about you'), findsOneWidget);
    expect(_brightnessOf(tester, find.text('Tell us about you')), Brightness.dark);

    // The header toggle flips it back for the rest of the flow.
    await tester.tap(find.byType(ThemeToggle));
    await tester.pumpAndSettle();
    expect(controller.value, ThemeMode.light);
    expect(_brightnessOf(tester, find.text('Tell us about you')), Brightness.light);
  });
}
