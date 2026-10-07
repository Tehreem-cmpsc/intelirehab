// The digital-twin plumbing: what the local asset server will and won't
// serve, and how TwinBridge turns a ~31 Hz sample stream into WebView calls.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inteli_rehab_mobile_app/features/exercises/exercises_models.dart';
import 'package:inteli_rehab_mobile_app/features/twin/twin_asset_server.dart';
import 'package:inteli_rehab_mobile_app/features/twin/twin_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TwinAssetServer.assetKeyFor', () {
    test('maps the page, its scripts and the arm models', () {
      expect(TwinAssetServer.assetKeyFor('/twin/index.html'), 'assets/twin/index.html');
      expect(TwinAssetServer.assetKeyFor('/twin/three_bundle.js'), 'assets/twin/three_bundle.js');
      expect(TwinAssetServer.assetKeyFor('/twin/twin.js'), 'assets/twin/twin.js');
      expect(TwinAssetServer.assetKeyFor('/models/Arm_L.gltf'), 'assets/models/Arm_L.gltf');
      expect(TwinAssetServer.assetKeyFor('/models/Arm_R.bin'), 'assets/models/Arm_R.bin');
      expect(TwinAssetServer.assetKeyFor('/models/arm_skin_color.jpg'), 'assets/models/arm_skin_color.jpg');
      expect(TwinAssetServer.assetKeyFor('/models/arm_skin_normal.png'), 'assets/models/arm_skin_normal.png');
    });

    test('a ../ path is normalised first, so it can only ever reach an allowed file', () {
      expect(TwinAssetServer.assetKeyFor('/twin/../models/Arm_L.gltf'), 'assets/models/Arm_L.gltf');
      expect(TwinAssetServer.assetKeyFor('/twin/../../pubspec.yaml'), isNull);
    });

    test('refuses everything else in the bundle', () {
      for (final p in [
        '/',
        '/twin/',
        '/twin/secret.js',
        '/models/arm_anatomy.glb',
        '/icon/app_icon.png',
        '/../pubspec.yaml',
        '/twin/index.html/extra',
        '/models/%2e%2e/pubspec.yaml',
      ]) {
        expect(TwinAssetServer.assetKeyFor(p), isNull, reason: p);
      }
    });
  });

  group('TwinAssetServer over HTTP', () {
    // The test binding stubs every HttpClient to answer 400; this test talks
    // to the real loopback server.
    setUpAll(() => HttpOverrides.global = null);
    tearDownAll(() => TwinAssetServer.instance.close());

    test('serves the page and model from the bundle; 404s the rest', () async {
      {
        final uri = await TwinAssetServer.instance.pageUri(query: {'side': 'right'});
        expect(uri.host, '127.0.0.1');
        expect(uri.queryParameters['side'], 'right');

        final client = HttpClient();
        Future<(int, String, int)> get(String path) async {
          final res = await (await client.getUrl(uri.replace(path: path, query: ''))).close();
          final body = await res.fold<int>(0, (n, chunk) => n + chunk.length);
          return (res.statusCode, res.headers.contentType?.mimeType ?? '', body);
        }

        final page = await get('/twin/index.html');
        expect(page.$1, 200);
        expect(page.$2, 'text/html');
        expect(page.$3, greaterThan(0));

        final js = await get('/twin/three_bundle.js');
        expect(js.$1, 200);
        expect(js.$2, 'text/javascript');

        final model = await get('/models/Arm_L.gltf');
        expect(model.$1, 200);
        expect(model.$2, 'model/gltf+json');

        final skin = await get('/models/arm_skin_color.jpg');
        expect(skin.$1, 200);
        expect(skin.$2, 'image/jpeg');

        expect((await get('/models/arm_anatomy.glb')).$1, 404);
        expect((await get('/pubspec.yaml')).$1, 404);
        client.close(force: true);
      }
    });
  });

  group('TwinBridge', () {
    late List<String> sent;
    late TwinBridge bridge;

    Future<void> run(String js) async => sent.add(js);
    String ready() => jsonEncode({'type': 'ready'});

    setUp(() {
      sent = [];
      bridge = TwinBridge(run: run, minInterval: const Duration(milliseconds: 40));
    });
    tearDown(() => bridge.dispose());

    test('sends nothing before the page is ready', () async {
      bridge.setElbow(45);
      bridge.setTier(SafetyTier.unsafe);
      bridge.setEmg(biceps: 30, triceps: 10);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(sent, isEmpty);
    });

    test('on ready, pushes the latest tier and values', () {
      bridge.setElbow(45);
      bridge.setTier(SafetyTier.needsCorrection);
      bridge.setEmg(biceps: 30, triceps: 10);
      bridge.handleMessage(ready());
      expect(sent, [
        "twin.setTier('needsCorrection')",
        'twin.setElbow(45.0);twin.setEmg(30,10)',
      ]);
    });

    test('coalesces a burst into the first call plus one trailing call with the newest value', () async {
      bridge.handleMessage(ready());
      await Future<void>.delayed(const Duration(milliseconds: 60)); // let the throttle window pass
      sent.clear();
      for (var i = 1; i <= 10; i++) {
        bridge.setElbow(i * 10.0);
      }
      // First goes out immediately (throttle window has passed), the other
      // nine collapse into a single trailing call.
      expect(sent, ['twin.setElbow(10.0)']);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(sent, ['twin.setElbow(10.0)', 'twin.setElbow(100.0)']);
    });

    test('skips calls that would not change anything', () async {
      bridge.handleMessage(ready());
      sent.clear();
      bridge.setElbow(30);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      bridge.setElbow(30.04); // under 0.1 degree
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(sent, ['twin.setElbow(30.0)']);
    });

    test('ignores NaN/infinite samples rather than sending them', () async {
      bridge.handleMessage(ready());
      sent.clear();
      bridge.setElbow(20);
      bridge.setElbow(double.nan);
      bridge.setElbow(double.infinity);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(sent.join(';'), isNot(contains('NaN')));
      expect(sent.join(';'), isNot(contains('Infinity')));
    });

    test('tier changes go out immediately, and only when they change', () {
      bridge.handleMessage(ready());
      sent.clear();
      bridge.setTier(SafetyTier.unsafe);
      bridge.setTier(SafetyTier.unsafe);
      expect(sent, ["twin.setTier('unsafe')"]);
    });

    test('a side change makes the page reload; its next ready re-pushes state', () {
      bridge.handleMessage(ready());
      bridge.setElbow(70);
      sent.clear();
      bridge.setSide('right');
      expect(sent, ["twin.setSide('right')"]);
      expect(bridge.isReady, isFalse);
      sent.clear();
      bridge.handleMessage(ready());
      expect(sent, ["twin.setTier('normal')", 'twin.setElbow(70.0);twin.setEmg(0,0)']);
    });

    test('an error message flags failure and notifies', () {
      String? seen;
      bridge.onError = (m) => seen = m;
      bridge.handleMessage(jsonEncode({'type': 'error', 'detail': 'no webgl'}));
      expect(bridge.hasFailed, isTrue);
      expect(seen, 'no webgl');
    });

    test('garbage from the page is ignored', () {
      bridge.handleMessage('not json');
      bridge.handleMessage('[1,2]');
      bridge.handleMessage(jsonEncode({'type': 'mystery'}));
      expect(bridge.isReady, isFalse);
      expect(bridge.hasFailed, isFalse);
    });

    test('a JS call that throws never reaches the caller', () async {
      final flaky = TwinBridge(run: (_) async => throw StateError('webview gone'));
      flaky.handleMessage(ready());
      flaky.setElbow(10);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      flaky.dispose();
    });
  });
}

