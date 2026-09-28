import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inteli_rehab/core/theme/app_theme.dart';
import 'package:inteli_rehab/features/auth/data/repositories/auth_repository_fake.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/login_screen.dart';
import 'package:inteli_rehab/features/auth/presentation/screens/register_screen.dart';

class _TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final file = File(key);
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      return ByteData.view(bytes.buffer);
    }
    return rootBundle.load(key);
  }
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

  testWidgets('Capture 1: Registration Normal State', (tester) async {
    final boundaryKey = GlobalKey();

    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: boundaryKey,
          child: RegisterScreen(repository: fakeRepo, isPreview: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      const path =
          r'C:\Users\malax\.gemini\antigravity\brain\b7838171-4afe-460f-965a-59e5df70a481\registration_normal.png';
      final file = File(path);
      if (file.parent.existsSync()) {
        file.writeAsBytesSync(byteData!.buffer.asUint8List());
      }
    });
  });

  testWidgets('Capture 2: Registration With Validation Errors', (tester) async {
    final boundaryKey = GlobalKey();

    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: boundaryKey,
          child: RegisterScreen(repository: fakeRepo, isPreview: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Trigger touched-field errors
    await tester.enterText(
      find.byKey(const Key('register_reg_id_field')),
      'AB',
    );
    await tester.ensureVisible(find.byKey(const Key('register_email_field')));
    await tester.tap(find.byKey(const Key('register_email_field')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('register_email_field')),
      'not-an-email',
    );
    await tester.ensureVisible(
      find.byKey(const Key('register_password_field')),
    );
    await tester.tap(find.byKey(const Key('register_password_field')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'short',
    );
    await tester.ensureVisible(find.byKey(const Key('register_submit_button')));
    await tester.tap(
      find.byKey(const Key('register_submit_button')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      const path =
          r'C:\Users\malax\.gemini\antigravity\brain\b7838171-4afe-460f-965a-59e5df70a481\registration_errors.png';
      final file = File(path);
      if (file.parent.existsSync()) {
        file.writeAsBytesSync(byteData!.buffer.asUint8List());
      }
    });
  });

  testWidgets('Capture 3: Registration With 200% Enlarged Text', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();

    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: RepaintBoundary(
            key: boundaryKey,
            child: RegisterScreen(repository: fakeRepo, isPreview: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      const path =
          r'C:\Users\malax\.gemini\antigravity\brain\b7838171-4afe-460f-965a-59e5df70a481\registration_enlarged.png';
      final file = File(path);
      if (file.parent.existsSync()) {
        file.writeAsBytesSync(byteData!.buffer.asUint8List());
      }
    });
  });

  testWidgets('Capture 4: Login With Corrected Transparent Logo', (
    tester,
  ) async {
    final boundaryKey = GlobalKey();
    final bundle = _TestAssetBundle();

    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: boundaryKey,
            child: LoginScreen(repository: fakeRepo, isPreview: true),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/full_logo.png'),
        boundaryKey.currentContext!,
      );
    });
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      const path =
          r'C:\Users\malax\.gemini\antigravity\brain\b7838171-4afe-460f-965a-59e5df70a481\login_transparent_logo.png';
      final file = File(path);
      if (file.parent.existsSync()) {
        file.writeAsBytesSync(byteData!.buffer.asUint8List());
      }
    });
  });
}
