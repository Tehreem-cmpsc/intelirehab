import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/ble/arm_band_ble_service.dart';
import '../../home/ble/arm_band_protocol.dart';
import '../../home/bluetooth_rationale.dart';
import '../../home/wearable_connection_controller.dart' show simulatedWearableBattery;
import '../onboarding_data.dart';
import '../widgets/form_widgets.dart';

enum _BleState { idle, scanning, found, connecting, connected, error }

/// Real BLE pairing, against firmware/lib/BLEStreamer.cpp's GATT profile
/// (ArmBandProtocol) — own [ArmBandBleService] instance, since this runs
/// before a patient is fully registered (WearableConnectionController,
/// used everywhere after onboarding, doesn't exist yet at this point).
class WearableSetupStep extends StatefulWidget {
  final OnboardingData data;

  const WearableSetupStep({super.key, required this.data});

  @override
  State<WearableSetupStep> createState() => _WearableSetupStepState();
}

class _WearableSetupStepState extends State<WearableSetupStep> with SingleTickerProviderStateMixin {
  late final AnimationController _radar =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  final _ble = ArmBandBleService();
  StreamSubscription<List<ArmBandScanResult>>? _scanSub;
  List<ArmBandScanResult> _found = [];
  String? _connectingId;
  String? _errorMessage;
  late _BleState _state = widget.data.wearable != null ? _BleState.connected : _BleState.idle;

  OnboardingData get data => widget.data;

  @override
  void dispose() {
    _scanSub?.cancel();
    _radar.dispose();
    _ble.dispose();
    super.dispose();
  }

  /// Explains Bluetooth first, in context (Rule 23), then scans for real.
  Future<void> _scan() async {
    if (!await BluetoothRationale.ensure(context) || !mounted) return;
    setState(() {
      _state = _BleState.scanning;
      _found = [];
      _errorMessage = null;
    });
    _radar.repeat();
    await _scanSub?.cancel();
    _scanSub = _ble.scan().listen(
      (results) {
        if (!mounted) return;
        setState(() {
          _found = results;
          if (_state == _BleState.scanning) _state = _BleState.found;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        _radar.stop();
        setState(() {
          _state = _BleState.error;
          _errorMessage = e is ArmBandException ? e.message : "Couldn't scan for bands.";
        });
      },
    );
    // A scan runs until stopped — show whatever's found after a fixed
    // window rather than waiting forever for more.
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted || _state != _BleState.scanning) return;
      _radar.stop();
      setState(() => _state = _found.isEmpty ? _BleState.error : _BleState.found);
      if (_found.isEmpty) _errorMessage = "No bands found nearby. Make sure it's switched on.";
    });
  }

  void _cancelScan() {
    _scanSub?.cancel();
    _radar.stop();
    setState(() => _state = _BleState.idle);
  }

  Future<void> _connect(ArmBandScanResult found) async {
    setState(() {
      _state = _BleState.connecting;
      _connectingId = found.id;
    });
    await _scanSub?.cancel();
    try {
      await _ble.connect(found.id);
      if (!mounted) return;
      final device = WearableDevice(
        found.id,
        ArmBandProtocol.advertisedName,
        found.signalBars,
        simulatedWearableBattery(found.id),
        macAddress: Platform.isAndroid ? found.id : null, // Android's remoteId IS the MAC; iOS's isn't
      );
      data.update(() {
        data.wearable = device;
      });
      setState(() => _state = _BleState.connected);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _BleState.error;
        _errorMessage = e is ArmBandException ? e.message : "Couldn't connect to that band.";
      });
    }
  }

  void _disconnect() {
    _ble.disconnect();
    data.update(() {
      data.wearable = null;
      data.baseline = null;
    });
    setState(() => _state = _BleState.idle);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(_state == _BleState.connecting ? _BleState.found : _state),
        child: switch (_state) {
          _BleState.idle => _idle(context),
          _BleState.scanning => _scanning(context),
          _BleState.found || _BleState.connecting => _found_(context),
          _BleState.connected => _connected(context),
          _BleState.error => _error(context),
        },
      ),
    );
  }

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
          'Your band is required to use Inteli Rehab. The app will ask for Bluetooth and nearby-device permission.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: c.muted),
        ),
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

  Widget _found_(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('${_found.length} band${_found.length == 1 ? '' : 's'} found',
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
        for (final d in _found) ...[
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
                          _SignalBars(bars: d.signalBars),
                          const SizedBox(width: 6),
                          Text(d.signalBars >= 2 ? 'Strong signal' : 'Weak signal — move closer',
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
      ],
    );
  }

  Widget _error(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Icon(Icons.bluetooth_disabled_rounded, size: 56, color: c.alert),
        const SizedBox(height: 14),
        Text(
          _errorMessage ?? "Couldn't find or connect to your band.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5, color: c.ink, height: 1.4),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _scan,
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('Try again'),
        ),
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
