import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Serves the digital-twin page and the arm models to the WebView over
/// http://127.0.0.1, straight out of the app's bundled assets.
///
/// Why a server rather than loading the asset directly: the page fetches
/// `../models/Arm_L.gltf` (and its `.bin`), and a WebView can't resolve
/// relative fetches against `flutter_assets` consistently across Android
/// and iOS. The server maps two URL prefixes onto the bundle:
///
///   /twin/...   -> assets/twin/...      (the page, three_bundle.js, twin.js)
///   /models/... -> assets/models/...    (only the four arm files below)
///
/// Loopback only and a fixed allow-list, so nothing else in the bundle is
/// reachable and nothing leaves the device (Android's network security
/// config already permits cleartext to 127.0.0.1 for exactly this).
class TwinAssetServer {
  TwinAssetServer._();
  static final TwinAssetServer instance = TwinAssetServer._();

  static const _twinFiles = {'index.html', 'three_bundle.js', 'twin.js'};
  static const _modelFiles = {'Arm_L.gltf', 'Arm_L.bin', 'Arm_R.gltf', 'Arm_R.bin'};

  HttpServer? _server;
  Future<HttpServer>? _starting;

  /// Where the page lives; starts the server on first use. One server serves
  /// every twin for the life of the app, so screens never pay the start-up
  /// twice.
  Future<Uri> pageUri({Map<String, String> query = const {}}) async {
    final server = await _start();
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      path: '/twin/index.html',
      queryParameters: query.isEmpty ? null : query,
    );
  }

  Future<HttpServer> _start() {
    final running = _server;
    if (running != null) return Future.value(running);
    return _starting ??= HttpServer.bind(InternetAddress.loopbackIPv4, 0).then((s) {
      _server = s;
      s.listen(_handle, onError: (Object _) {});
      return s;
    }).catchError((Object e) {
      _starting = null; // let the next caller retry
      throw e;
    });
  }

  Future<void> close() async {
    final s = _server;
    _server = null;
    _starting = null;
    await s?.close(force: true);
  }

  /// URL path -> bundled asset key, or null if that path isn't served.
  /// Public for tests; this is the whole allow-list.
  static String? assetKeyFor(String path) {
    final segments = Uri.parse(path).pathSegments;
    if (segments.length != 2) return null;
    final dir = segments[0], file = segments[1];
    switch (dir) {
      case 'twin':
        return _twinFiles.contains(file) ? 'assets/twin/$file' : null;
      case 'models':
        return _modelFiles.contains(file) ? 'assets/models/$file' : null;
      default:
        return null;
    }
  }

  static ContentType contentTypeFor(String path) {
    if (path.endsWith('.html')) return ContentType('text', 'html', charset: 'utf-8');
    if (path.endsWith('.js')) return ContentType('text', 'javascript', charset: 'utf-8');
    if (path.endsWith('.gltf')) return ContentType('model', 'gltf+json');
    return ContentType.binary; // .bin
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final key = request.method == 'GET' ? assetKeyFor(request.uri.path) : null;
      if (key == null) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final data = await rootBundle.load(key);
      response
        ..headers.contentType = contentTypeFor(key)
        ..headers.set('Cache-Control', 'no-cache')
        ..contentLength = data.lengthInBytes
        ..add(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }
}
