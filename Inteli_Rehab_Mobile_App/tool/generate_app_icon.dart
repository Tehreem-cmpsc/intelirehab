// Renders the app's real logo mark (AppLogoIcon, lib/core/widgets/app_logo.dart)
// to assets/icon/app_icon.png, the source flutter_launcher_icons builds every
// launcher icon from. Keeps the launcher icon pixel-identical to the logo
// used everywhere else in the app, instead of a hand-exported copy that can
// drift out of sync if the mark is ever tweaked.
//
// Not part of the normal test suite (lives outside test/, so `flutter test`
// never picks it up) — it's a generator, not a correctness check. Re-run it
// whenever app_logo.dart changes:
//   flutter test tool/generate_app_icon.dart
// then re-run `dart run flutter_launcher_icons` to regenerate the actual
// per-platform icon files from the new PNG.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/core/widgets/app_logo.dart';

const _size = 1024.0;

// The mark's own pale-teal backdrop (AppLogoIcon's light palette,
// `_lightPalette.background` — private to app_logo.dart, so duplicated
// here as a literal; everything else about the mark comes from the real
// AppLogoIcon widget, not redrawn). iOS icons must be fully opaque, and
// the painter only fills its own circle, not the full square — this
// backdrop is what fills the corners outside it.
const _backdrop = Color(0xFFE4FAF6);

// Android adaptive-icon foregrounds are masked (circle/squircle/rounded
// square) outside a centered ~66% "safe zone" — some launchers crop
// tighter still. The flattened icon's mark already sits comfortably
// inside that on its own, but rendered small enough here to have real
// margin rather than relying on that being exactly right.
const _foregroundMarkSize = _size * 0.62;

Future<void> _capture(WidgetTester tester, Widget child, String path) async {
  tester.view.physicalSize = const Size(_size, _size);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(key: const ValueKey('icon'), child: child),
    ),
  );
  await tester.pump();

  // toImage() and file IO both need a real event loop turn, which the fake
  // test async zone doesn't drive on its own — without runAsync this hangs
  // forever instead of erroring.
  await tester.runAsync(() async {
    final boundary = tester.renderObject(find.byKey(const ValueKey('icon'))) as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);

    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('Wrote ${file.path} (${bytes.lengthInBytes} bytes)');
  });
}

void main() {
  testWidgets('generate app_icon.png (flattened, for the legacy/iOS icon)', (tester) async {
    await _capture(
      tester,
      Container(
        width: _size,
        height: _size,
        color: _backdrop,
        child: const Center(child: AppLogoIcon(size: _size, light: true)),
      ),
      'assets/icon/app_icon.png',
    );
  });

  testWidgets('generate app_icon_foreground.png (transparent, for Android adaptive icons)', (tester) async {
    await _capture(
      tester,
      const SizedBox(
        width: _size,
        height: _size,
        child: Center(child: AppLogoIcon(size: _foregroundMarkSize, light: true)),
      ),
      'assets/icon/app_icon_foreground.png',
    );
  });
}
