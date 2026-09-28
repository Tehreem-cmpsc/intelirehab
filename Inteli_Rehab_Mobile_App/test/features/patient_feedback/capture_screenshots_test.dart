import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inteli_rehab/core/theme/app_theme.dart';
import 'package:inteli_rehab/features/patient_feedback/data/repositories/patient_feedback_repository_fake.dart';
import 'package:inteli_rehab/features/patient_feedback/presentation/screens/patient_feedback_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Capture Normal Text Size Screenshot', (tester) async {
    final repo = PatientFeedbackRepositoryFake();
    final boundaryKey = GlobalKey();

    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: boundaryKey,
          child: PatientFeedbackScreen(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      const path =
          r'C:\Users\malax\.gemini\antigravity\brain\b7838171-4afe-460f-965a-59e5df70a481\patient_stories_normal.png';
      final file = File(path);
      if (file.parent.existsSync()) {
        file.writeAsBytesSync(byteData!.buffer.asUint8List());
      }
    });
  });

  testWidgets('Capture Enlarged Text Size Screenshot (1.5x)', (tester) async {
    final repo = PatientFeedbackRepositoryFake();
    final boundaryKey = GlobalKey();

    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: RepaintBoundary(
                key: boundaryKey,
                child: PatientFeedbackScreen(repository: repo),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      const path =
          r'C:\Users\malax\.gemini\antigravity\brain\b7838171-4afe-460f-965a-59e5df70a481\patient_stories_enlarged.png';
      final file = File(path);
      if (file.parent.existsSync()) {
        file.writeAsBytesSync(byteData!.buffer.asUint8List());
      }
    });
  });
}
