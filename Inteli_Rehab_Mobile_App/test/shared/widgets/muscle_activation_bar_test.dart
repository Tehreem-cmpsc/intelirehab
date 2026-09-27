import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/shared/enums/fatigue_level.dart';
import 'package:inteli_rehab/shared/widgets/muscle_activation_bar.dart';

void main() {
  group('MuscleActivationBar Multimodal Accessibility', () {
    testWidgets('renders muscle name and percentage with Optimal label when fatigue is none', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MuscleActivationBar(
              muscleName: 'Biceps Brachii',
              activationPercent: 0.45,
              fatigueLevel: FatigueLevel.none,
            ),
          ),
        ),
      );

      expect(find.text('Biceps Brachii'), findsOneWidget);
      expect(find.text('45% (Optimal)'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders High Strain label and warning icon for high fatigue', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MuscleActivationBar(
              muscleName: 'Triceps Brachii',
              activationPercent: 0.82,
              fatigueLevel: FatigueLevel.high,
            ),
          ),
        ),
      );

      expect(find.text('Triceps Brachii'), findsOneWidget);
      expect(find.text('82% (High Strain)'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Fatigue Alert label and pause icon for critical fatigue', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MuscleActivationBar(
              muscleName: 'Deltoid Anterior',
              activationPercent: 0.95,
              fatigueLevel: FatigueLevel.critical,
            ),
          ),
        ),
      );

      expect(find.text('95% (Fatigue Alert (Break))'), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline_rounded), findsOneWidget);
    });
  });
}
