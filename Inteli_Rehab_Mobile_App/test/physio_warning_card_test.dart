import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/theme/app_theme.dart';
import 'package:inteli_rehab_mobile_app/features/progress/widgets/physio_warning_card.dart';

void main() {
  Widget host(ThemeData theme) => MaterialApp(
        theme: theme,
        home: const Scaffold(body: PhysioWarningCard(message: 'Please rest your arm for two days.')),
      );

  testWidgets('shows who the message is from and the physiotherapist\'s words', (tester) async {
    await tester.pumpWidget(host(AppTheme.light()));
    expect(find.text('Message from your physiotherapist'), findsOneWidget);
    expect(find.text('Please rest your arm for two days.'), findsOneWidget);
  });

  testWidgets('renders in the dark theme too', (tester) async {
    await tester.pumpWidget(host(AppTheme.dark()));
    expect(find.text('Please rest your arm for two days.'), findsOneWidget);
  });
}
