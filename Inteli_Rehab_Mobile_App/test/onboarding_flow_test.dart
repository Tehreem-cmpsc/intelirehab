import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/onboarding/onboarding_flow.dart';

// The onboarding screens are frontend-only (no Supabase calls), so they
// can be pumped directly without initialising Supabase.
// Reduced motion stops the decorative spinning rings, so pumpAndSettle can settle.
Widget _app() => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
      home: const OnboardingFlow(),
    );

void main() {
  testWidgets('starts on personal details and blocks Continue until answered', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    expect(find.text('Tell us about you'), findsOneWidget);
    expect(find.textContaining('STEP 1 OF 7'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Tell us about you'), findsOneWidget);
  });

  testWidgets('personal details advances to injury details once complete', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());

    await tester.enterText(find.byType(TextFormField).first, 'Ayesha Khan');
    await tester.tap(find.text('Select date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Female'));
    await tester.ensureVisible(find.text('Active'));
    await tester.tap(find.text('Active'));
    await tester.ensureVisible(find.text('Right'));
    await tester.tap(find.text('Right'));
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('About your injury'), findsOneWidget);
    expect(find.textContaining('STEP 2 OF 7'), findsOneWidget);
  });
}
