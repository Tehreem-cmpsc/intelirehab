// Where there's no WebView implementation (desktop, tests) the live twin
// must quietly fall back to the 2D view rather than break the session screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/widgets/live_digital_twin.dart';
import 'package:inteli_rehab_mobile_app/features/twin/live_twin_view.dart';

void main() {
  testWidgets('falls back to the 2D twin when no WebView is available', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: SizedBox(
          width: 200,
          height: 200,
          child: LiveTwinView(fallbackPercent: 40, tier: SafetyTier.normal, side: 'right'),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(LiveDigitalTwin), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
