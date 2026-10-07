import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../exercises/exercises_models.dart';
import '../exercises/widgets/live_digital_twin.dart';
import '../home/ble/arm_band_protocol.dart';
import 'twin_asset_server.dart';
import 'twin_controller.dart';

/// The live 3D arm: a Three.js scene in a WebView (assets/twin/) whose elbow
/// follows the band's angle and whose colour follows the AI's safety tier.
///
/// Display-only (touches pass through, so it never fights a scroll view).
/// Until the model has loaded - and for good if it can't (no WebGL, no
/// WebView on this platform, a load error or timeout) - the existing 2D
/// [LiveDigitalTwin] is shown instead, so a rendering problem never blocks
/// a session (Rule 26).
///
/// Feed it either the band's raw [samples] (the real thing: true elbow
/// degrees and EMG) or, for the simulator/tests, just [fallbackPercent]
/// (joint angle as % of [fullRangeDegrees]).
class LiveTwinView extends StatefulWidget {
  final Stream<ArmBandSample>? samples;
  final int fallbackPercent;
  final SafetyTier tier;

  /// 'left' or 'right' - which arm model to show.
  final String side;
  final double fullRangeDegrees;

  /// False while the view is kept alive but not on screen (e.g. the Home tab behind a session):
  /// the 3D scene stops rendering until it is true again, so two twins never draw at once.
  final bool active;

  const LiveTwinView({
    super.key,
    this.samples,
    required this.fallbackPercent,
    required this.tier,
    this.side = 'left',
    this.fullRangeDegrees = 150,
    this.active = true,
  });

  @override
  State<LiveTwinView> createState() => _LiveTwinViewState();
}

class _LiveTwinViewState extends State<LiveTwinView> with WidgetsBindingObserver {
  static const _loadTimeout = Duration(seconds: 12);

  late final TwinBridge _bridge;
  WebViewController? _web;
  StreamSubscription<ArmBandSample>? _sub;
  Timer? _timeout;
  bool _ready = false;
  bool _failed = false;

  /// What the page has done so far, newest last. Shown on long-press so
  /// "I don't see the 3D arm" can be answered without a debugger.
  final List<String> _log = [];
  void _note(String s) {
    _log.add(s);
    if (_log.length > 12) _log.removeAt(0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bridge = TwinBridge(run: (js) async => _web?.runJavaScript(js));
    _bridge
      ..onReady = _onReady
      ..onError = _fail
      ..setSide(widget.side)
      ..setTier(widget.tier);
    _listen();
    _start();
  }

  Future<void> _start() async {
    final WebViewController web;
    try {
      // Throws where there's no WebView implementation (desktop, tests).
      web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel('Twin', onMessageReceived: (m) => _bridge.handleMessage(m.message))
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (url) => _note('page started: $url'),
          onPageFinished: (_) => _note('page finished'),
          onWebResourceError: (e) {
            if (e.isForMainFrame ?? true) _fail('page failed to load: ${e.description}');
          },
        ));
      if (kDebugMode) {
      }
      unawaited(web.setOnConsoleMessage((m) {
        _note('js ${m.level.name}: ${m.message}');
        if (kDebugMode) debugPrint('[twin] ${m.level.name}: ${m.message}');
      }).catchError((_) {}));
    } catch (e) {
      _fail('no WebView on this platform: $e');
      return;
    }
    _web = web;
    if (mounted) setState(() {}); // build the WebViewWidget now; it needs a loaded page afterwards

    _timeout = Timer(_loadTimeout, () => _fail('timed out loading the 3D model'));
    try {
      final uri = await TwinAssetServer.instance.pageUri(query: {'side': _bridge.initialSide});
      _note('loading $uri');
      await web.loadRequest(uri);
    } catch (e) {
      _fail('could not start the page: $e');
    }
  }

  void _listen() {
    _sub?.cancel();
    _sub = widget.samples?.listen((s) {
      _bridge.setElbow(s.elbowDeg);
      // The band has one EMG channel for now; it drives the biceps tint.
      _bridge.setEmg(biceps: s.emg1Pct);
    });
  }

  void _onReady() {
    _timeout?.cancel();
    _note('model ready');
    if (!widget.active) _setRendering(false);
    if (mounted) setState(() => _ready = true);
  }

  void _fail(String why) {
    if (_failed) return;
    _timeout?.cancel();
    _note('FAILED: $why');
    debugPrint('3D twin unavailable, using the 2D view: $why');
    if (mounted) setState(() => _failed = true);
  }

  @override
  void didUpdateWidget(LiveTwinView old) {
    super.didUpdateWidget(old);
    if (!identical(old.samples, widget.samples)) _listen();
    if (old.tier != widget.tier) _bridge.setTier(widget.tier);
    if (old.side != widget.side) _bridge.setSide(widget.side);
    if (old.active != widget.active) _setRendering(widget.active);
    if (widget.samples == null) {
      // Simulated session: derive degrees from the percentage.
      _bridge.setElbow(widget.fallbackPercent * widget.fullRangeDegrees / 100);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready || _failed) return;
    // No point rendering while the app is in the background (or this view is not on screen).
    _setRendering(state == AppLifecycleState.resumed && widget.active);
  }

  void _setRendering(bool on) {
    if (!_ready || _failed) return;
    unawaited(_web?.runJavaScript(on ? 'twin.resume()' : 'twin.pause()').catchError((_) {}) ?? Future<void>.value());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    _sub?.cancel();
    _bridge.dispose();
    super.dispose();
  }

  void _showStatus() {
    final state = _failed ? 'using the 2D view' : (_ready ? '3D running' : 'loading the 3D model');
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 12),
        content: Text('3D twin: $state\n${_log.join('\n')}', style: const TextStyle(fontSize: 11)),
      ));
  }

  @override
  Widget build(BuildContext context) =>
      GestureDetector(behavior: HitTestBehavior.translucent, onLongPress: _showStatus, child: _buildTwin());

  Widget _buildTwin() {
    final fallback = LiveDigitalTwin(angleDegrees: widget.fallbackPercent, tier: widget.tier);
    final web = _web;
    if (_failed || web == null) return fallback;

    final degrees = widget.samples == null ? widget.fallbackPercent * widget.fullRangeDegrees / 100 : null;
    return Semantics(
      image: true,
      label: 'Live 3D model of your arm movement'
          '${degrees == null ? '' : ', elbow at ${degrees.round()} degrees'}.',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(child: WebViewWidget(controller: web)),
              // Covers the page until the model has loaded, then goes.
              if (!_ready) fallback,
            ],
          ),
        ),
      ),
    );
  }
}
