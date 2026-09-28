import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../mock_directory.dart';
import '../onboarding_data.dart';
import '../widgets/form_widgets.dart';

enum _BleState { idle, scanning, found, connecting, connected }

/// BLE pairing — UI only. Scanning and connecting are simulated with
/// timers against [mockWearables]; swap in a real BLE plugin later.
class WearableSetupStep extends StatefulWidget {
  final OnboardingData data;

  const WearableSetupStep({super.key, required this.data});

  @override
  State<WearableSetupStep> createState() => _WearableSetupStepState();
}

class _WearableSetupStepState extends State<WearableSetupStep> with SingleTickerProviderStateMixin {
  late final AnimationController _radar =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  Timer? _timer;
  late _BleState _state = widget.data.wearable != null ? _BleState.connected : _BleState.idle;
  String? _connectingId;

  OnboardingData get data => widget.data;

  @override
  void dispose() {
    _timer?.cancel();
    _radar.dispose();
    super.dispose();
  }

  void _scan() {
    setState(() => _state = _BleState.scanning);
    _radar.repeat();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2600), () {
      _radar.stop();
      setState(() => _state = _BleState.found);
    });
  }

  void _cancelScan() {
    _timer?.cancel();
    _radar.stop();
    setState(() => _state = _BleState.idle);
  }

  void _connect(WearableDevice device) {
    setState(() {
      _state = _BleState.connecting;
      _connectingId = device.id;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      data.update(() {
        data.wearable = device;
        data.wearableSkipped = false;
      });
      setState(() => _state = _BleState.connected);
    });
  }

  void _disconnect() {
    data.update(() {
      data.wearable = null;
      data.baseline = null;
    });
    setState(() => _state = _BleState.idle);
  }

  @override
  Widget build(BuildContext context) {
    if (data.wearableSkipped) return _skipped(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(_state == _BleState.connecting ? _BleState.found : _state),
        child: switch (_state) {
          _BleState.idle => _idle(context),
          _BleState.scanning => _scanning(context),
          _BleState.found || _BleState.connecting => _found(context),
          _BleState.connected => _connected(context),
        },
      ),
    );
  }

  Widget _skipLink() => Center(
        child: TextButton(
          onPressed: () => data.update(() => data.wearableSkipped = true),
          child: const Text("I don't have my band yet — set up later"),
        ),
      );

  Widget _idle(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const _BandIllustration(),
              const SizedBox(height: 18),
              Text('Get your Inteli Band ready',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: c.ink)),
              const SizedBox(height: 16),
              const _NumberedTip(n: 1, text: 'Make sure the band is charged.'),
              const _NumberedTip(n: 2, text: 'Hold its button for 3 seconds until the light blinks blue.'),
              const _NumberedTip(n: 3, text: 'Keep your phone close by with Bluetooth turned on.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _scan,
          icon: const Icon(Icons.bluetooth_searching, size: 20),
          label: const Text('Search for my band'),
        ),
        const SizedBox(height: 8),
        Text(
          'The app will ask for Bluetooth and nearby-device permission.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: c.muted),
        ),
        const SizedBox(height: 8),
        _skipLink(),
      ],
    );
  }

  Widget _scanning(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: AnimatedBuilder(
            animation: _radar,
            builder: (context, _) => CustomPaint(
              painter: _RadarPainter(_radar.value, c.primary),
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                  child: Icon(Icons.bluetooth, color: c.onPrimary, size: 34),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Looking for nearby bands…', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Keep the band within arm’s reach.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: _cancelScan, child: const Text('Cancel')),
      ],
    );
  }

  Widget _found(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('${mockWearables.length} bands found',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink)),
            const Spacer(),
            TextButton.icon(
              onPressed: _state == _BleState.connecting ? null : _scan,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Scan again'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final d in mockWearables) ...[
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: c.primaryTint, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.watch_outlined, color: c.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _SignalBars(bars: d.signal),
                          const SizedBox(width: 6),
                          Text(d.signal >= 2 ? 'Strong signal' : 'Weak signal — move closer',
                              style: TextStyle(fontSize: 12, color: c.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: _connectingId == d.id && _state == _BleState.connecting
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 18),
                          child: Center(
                            child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        )
                      : FilledButton(
                          onPressed: _state == _BleState.connecting ? null : () => _connect(d),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('Connect'),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        const InfoBanner(
          icon: Icons.lightbulb_outline,
          text: 'Not sure which is yours? The code on the back of your band matches the last 4 characters.',
        ),
        const SizedBox(height: 8),
        _skipLink(),
      ],
    );
  }

  Widget _connected(BuildContext context) {
    final c = context.colors;
    final device = data.wearable!;
    final placement = switch (data.affectedJoint) {
      'upper_arm' => 'on your upper arm, halfway between shoulder and elbow',
      'elbow' => 'on your forearm, two fingers below the elbow crease',
      _ => 'on your forearm, halfway between elbow and wrist',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: c.successTint, shape: BoxShape.circle),
                child: Icon(Icons.bluetooth_connected, color: c.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StatusPill(label: 'Connected', color: c.success, background: c.successTint),
                        if (device.battery != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.battery_5_bar, size: 15, color: c.muted),
                          Text('${device.battery}%', style: TextStyle(fontSize: 12, color: c.muted)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Put it on', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Strap the band to your ${data.sideLabel.replaceAll(' arm', '')} arm, $placement.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              const _NumberedTip(n: 1, text: 'Light on the band facing up, towards you.'),
              const _NumberedTip(n: 2, text: 'Snug, but you can still slide a finger under the strap.'),
              const _NumberedTip(n: 3, text: 'Wear it on bare skin, not over a sleeve.'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(onPressed: _disconnect, child: const Text('Use a different band')),
        ),
      ],
    );
  }

  Widget _skipped(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(
          icon: Icons.schedule,
          tone: BannerTone.warning,
          text: "No problem — you can pair your band later from Settings. You'll need it before your first "
              'tracked session.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => data.update(() => data.wearableSkipped = false),
          icon: const Icon(Icons.bluetooth, size: 18),
          label: const Text('Set up my band now instead'),
        ),
      ],
    );
  }
}

class _BandIllustration extends StatelessWidget {
  const _BandIllustration();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 120,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 36,
            decoration: BoxDecoration(color: c.primaryTint, borderRadius: BorderRadius.circular(18)),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: c.primaryDeep,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: c.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))
              ],
            ),
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFF31E8C6), shape: BoxShape.circle),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: c.accent, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
              child: const Icon(Icons.bluetooth, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberedTip extends StatelessWidget {
  final int n;
  final String text;
  const _NumberedTip({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.primaryTint, shape: BoxShape.circle),
            child: Text('$n', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: TextStyle(fontSize: 13.5, color: c.ink, height: 1.35)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int bars;
  const _SignalBars({required this.bars});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(right: 2),
            width: 4,
            height: 5.0 + i * 3,
            decoration: BoxDecoration(
              color: i < bars ? (bars >= 2 ? c.success : c.accent) : c.border,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  final Color color;
  const _RadarPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      canvas.drawCircle(
        center,
        36 + (maxR - 36) * p,
        Paint()
          ..color = color.withValues(alpha: (1 - p) * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t || old.color != color;
}
