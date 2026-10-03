import 'dart:async';
import 'dart:convert';

import '../exercises/exercises_models.dart';

/// What the rest of the app knows about the 3D digital twin. Screens and
/// [LiveSession] talk to this, never to a WebView, so the renderer behind it
/// can be replaced (e.g. by a native 3D engine) without touching them.
abstract class TwinController {
  /// Current elbow angle in degrees, 0 = fully extended (the band's zero pose).
  void setElbow(double degrees);

  void setTier(SafetyTier tier);

  /// Biceps (and optionally triceps) activation, 0-100 (%MVC).
  void setEmg({required double biceps, double triceps = 0});

  /// 'left' or 'right' arm model.
  void setSide(String side);
}

typedef JsRunner = Future<void> Function(String javascript);

/// [TwinController] for the Three.js page in a WebView (`window.twin` in
/// assets/twin/twin.js).
///
/// Samples arrive at ~31 Hz but the page only needs the latest one, so
/// elbow/EMG values are coalesced: at most one JavaScript call per
/// [minInterval], always carrying the newest values, with a trailing call so
/// the last value is never left unsent. Values are dropped, not queued, so a
/// slow WebView can fall behind by at most one update.
///
/// Nothing is sent until the page reports `ready` (its model has loaded);
/// the latest desired state is then pushed in one go, and again each time the
/// page reloads its model (side change).
class TwinBridge implements TwinController {
  final JsRunner _run;
  final Duration minInterval;
  final DateTime Function() _clock;

  TwinBridge({
    required JsRunner run,
    this.minInterval = const Duration(milliseconds: 33),
    DateTime Function()? clock,
  })  : _run = run,
        _clock = clock ?? DateTime.now;

  bool _ready = false;
  bool _disposed = false;
  bool _failed = false;
  Timer? _trailing;
  DateTime? _lastSend;

  String _side = 'left';
  SafetyTier _tier = SafetyTier.normal;
  double _elbow = 0, _biceps = 0, _triceps = 0;

  // What the page last received, to skip no-op calls.
  double? _sentElbow, _sentBiceps, _sentTriceps;

  /// True once the page has reported an unrecoverable error (e.g. WebGL
  /// unavailable). The widget uses this to fall back to the 2D twin.
  bool get hasFailed => _failed;
  bool get isReady => _ready;

  /// The side the page should start with (pass as the `side` URL param).
  String get initialSide => _side;

  /// Fired when the page reports an error.
  void Function(String message)? onError;

  /// Fired each time the page reports its model is loaded.
  void Function()? onReady;

  @override
  void setElbow(double degrees) {
    if (degrees.isFinite) _elbow = degrees;
    _scheduleFlush();
  }

  @override
  void setEmg({required double biceps, double triceps = 0}) {
    if (biceps.isFinite) _biceps = biceps;
    if (triceps.isFinite) _triceps = triceps;
    _scheduleFlush();
  }

  @override
  void setTier(SafetyTier tier) {
    if (tier == _tier) return;
    _tier = tier;
    if (_ready) _sendTier();
  }

  @override
  void setSide(String side) {
    final s = side == 'right' ? 'right' : 'left';
    if (s == _side) return;
    _side = s;
    if (_ready) {
      // The page reloads its model and reports `ready` again, which
      // re-pushes the full state.
      _ready = false;
      _exec("twin.setSide('$_side')");
    }
  }

  /// Wire to the WebView's `Twin` JavaScript channel.
  void handleMessage(String raw) {
    if (_disposed) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    switch (decoded['type']) {
      case 'ready':
        _ready = true;
        _sentElbow = _sentBiceps = _sentTriceps = null;
        _sendTier();
        _flush();
        onReady?.call();
      case 'error':
        _failed = true;
        onError?.call('${decoded['detail']}');
    }
  }

  /// The page is being reloaded or recreated; wait for its next `ready`.
  void reset() {
    _ready = false;
    _failed = false;
    _trailing?.cancel();
    _trailing = null;
  }

  void dispose() {
    _disposed = true;
    _trailing?.cancel();
  }

  void _scheduleFlush() {
    if (!_ready || _disposed || (_trailing?.isActive ?? false)) return;
    final last = _lastSend;
    final wait = last == null ? Duration.zero : minInterval - _clock().difference(last);
    if (wait <= Duration.zero) {
      _flush();
    } else {
      _trailing = Timer(wait, _flush);
    }
  }

  void _flush() {
    _trailing = null;
    if (!_ready || _disposed) return;
    final calls = <String>[];
    if (_sentElbow == null || (_elbow - _sentElbow!).abs() >= 0.1) {
      calls.add('twin.setElbow(${_elbow.toStringAsFixed(1)})');
      _sentElbow = _elbow;
    }
    if (_sentBiceps == null ||
        _sentTriceps == null ||
        (_biceps - _sentBiceps!).abs() >= 0.5 ||
        (_triceps - _sentTriceps!).abs() >= 0.5) {
      calls.add('twin.setEmg(${_biceps.toStringAsFixed(0)},${_triceps.toStringAsFixed(0)})');
      _sentBiceps = _biceps;
      _sentTriceps = _triceps;
    }
    if (calls.isEmpty) return;
    _lastSend = _clock();
    _exec(calls.join(';'));
  }

  void _sendTier() {
    final name = switch (_tier) {
      SafetyTier.normal => 'normal',
      SafetyTier.needsCorrection => 'needsCorrection',
      SafetyTier.unsafe => 'unsafe',
    };
    _exec("twin.setTier('$name')");
  }

  void _exec(String js) {
    // A failed call (page torn down mid-flight) must never surface into the
    // session screen driving this.
    unawaited(_run(js).catchError((Object _) {}));
  }
}
