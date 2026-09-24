// `flutter create .` generated a counter-app smoke test referencing `MyApp`,
// which doesn't exist in this project (the real app widget is
// `InteliRehabApp` in lib/app.dart). Pumping it directly isn't wired up yet:
// `AuthGate` reads `Supabase.instance.client`, which throws unless
// `Supabase.initialize()` has run first — that happens in main.dart's
// `main()`, not in a widget test. A real test here needs Supabase mocked
// (or a test-only initialize against a local/test project) before
// `InteliRehabApp` can be pumped safely.
//
// Placeholder until that's set up, so `flutter analyze`/`flutter test`
// have something real to run rather than a broken reference.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sanity check: test harness itself works', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Inteli Rehab'))));
    expect(find.text('Inteli Rehab'), findsOneWidget);
  });
}
