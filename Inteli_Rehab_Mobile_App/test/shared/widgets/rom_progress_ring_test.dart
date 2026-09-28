import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab/shared/widgets/rom_progress_ring.dart';

void main() {
  group('RomProgressRing', () {
    testWidgets('renders without overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: RomProgressRing(
                currentRom: 65.0,
                targetRom: 90.0,
                label: 'ROM',
              ),
            ),
          ),
        ),
      );
      expect(find.text('65°'), findsOneWidget);
      expect(find.text('ROM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows 0° when currentRom is zero', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: RomProgressRing(currentRom: 0, targetRom: 90)),
          ),
        ),
      );
      expect(find.text('0°'), findsOneWidget);
    });
  });
}
