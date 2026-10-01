import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/radial_progress.dart';
import '../onboarding_data.dart';
import '../widgets/form_widgets.dart';

enum _Phase { intro, neutral, movement, done }

/// Baseline capture — UI only. The live angle and the final reading are
/// simulated; the real values will come from the band's IMU stream.
class CalibrationStep extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onBackToWearable;

  const CalibrationStep({super.key, required this.data, required this.onBackToWearable});

  /// Movements recorded for the baseline (also saved as sessions.reps).
  static const reps = 3;

  @override
  State<CalibrationStep> createState() => _CalibrationStepState();
}

class _CalibrationStepState extends State<CalibrationStep> {
  static const _neutralSeconds = 5;
  static const _reps = CalibrationStep.reps;
  static const _repDuration = Duration(milliseconds: 2600);
  static const _tick = Duration(milliseconds: 50);

  Timer? _timer;
  late _Phase _phase = widget.data.baseline != null ? _Phase.done : _Phase.intro;
  Duration _elapsed = Duration.zero;

  OnboardingData get data => widget.data;

  ({String instruction, String metric, int lo, int hi}) get _movement => switch (data.affectedJoint) {
        'upper_arm' => (
            instruction: 'Slowly raise your arm forward as high as is comfortable, then lower it.',
            metric: 'Shoulder raise',
            lo: 6,
            hi: 132,
          ),
        'forearm' => (
            instruction: 'Keep your elbow at your side and slowly turn your palm up, then down.',
            metric: 'Forearm rotation',
            lo: 12,
            hi: 148,
          ),
        _ => (
            instruction: 'Slowly bend your elbow as far as is comfortable, then straighten it.',
            metric: 'Elbow bend',
            lo: 8,
            hi: 118,
          ),
      };

  @override
  void initState() {
    super.initState();
    // Live capture: an accidental rotation mustn't re-layout mid-rep (Rule 30).
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.neutral;
      _elapsed = Duration.zero;
    });
    _timer = Timer.periodic(_tick, (_) {
      setState(() => _elapsed += _tick);
      if (_phase == _Phase.neutral && _elapsed >= const Duration(seconds: _neutralSeconds)) {
        setState(() {
          _phase = _Phase.movement;
          _elapsed = Duration.zero;
        });
      } else if (_phase == _Phase.movement && _elapsed >= _repDuration * _reps) {
        _timer?.cancel();
        final m = _movement;
        data.update(() => data.baseline = BaselineReading(neutral: 3, flexion: m.hi, extension: m.lo));
        setState(() => _phase = _Phase.done);
      }
    });
  }

  void _redo() {
    data.update(() => data.baseline = null);
    setState(() => _phase = _Phase.intro);
  }

  @override
  Widget build(BuildContext context) {
    if (data.wearable == null) return _noWearable(context);
    if (data.calibrationSkipped) return _skipped(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(_phase),
        child: switch (_phase) {
          _Phase.intro => _intro(context),
          _Phase.neutral => _neutral(context),
          _Phase.movement => _moving(context),
          _Phase.done => _done(context),
        },
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Takes about 20 seconds', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'This records how your ${data.sideLabel} moves today, so your physiotherapist '
                'can measure your progress from here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const _PhaseRow(icon: Icons.chair_outlined, title: 'Sit upright', text: 'Feet flat, back supported.'),
              const _PhaseRow(
                  icon: Icons.pan_tool_outlined,
                  title: 'Hold still for $_neutralSeconds seconds',
                  text: 'Arm relaxed by your side.'),
              _PhaseRow(icon: Icons.sync, title: 'Move $_reps times', text: _movement.instruction),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const InfoBanner(
          icon: Icons.health_and_safety_outlined,
          tone: BannerTone.warning,
          text: 'Only move as far as feels comfortable. Stop if it hurts — a small range is still a useful baseline.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text("I'm ready — start"),
        ),
        Center(
          child: TextButton(
            onPressed: () => data.update(() => data.calibrationSkipped = true),
            child: Text('Calibrate later', style: TextStyle(color: c.muted)),
          ),
        ),
      ],
    );
  }

  Widget _neutral(BuildContext context) {
    final c = context.colors;
    final total = const Duration(seconds: _neutralSeconds).inMilliseconds;
    final progress = _elapsed.inMilliseconds / total;
    final remaining = (_neutralSeconds - _elapsed.inMilliseconds / 1000).ceil().clamp(0, _neutralSeconds);
    return _LiveCard(
      label: 'STEP 1 OF 2',
      title: 'Hold still',
      text: 'Relax your arm by your side and keep it still.',
      ring: RadialProgress(
        value: progress,
        size: 170,
        stroke: 12,
        color: c.accent,
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$remaining', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w700, color: c.ink, height: 1)),
            Text('seconds', style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ),
      ),
    );
  }

  Widget _moving(BuildContext context) {
    final c = context.colors;
    final m = _movement;
    final repProgress = (_elapsed.inMilliseconds % _repDuration.inMilliseconds) / _repDuration.inMilliseconds;
    final rep = (_elapsed.inMilliseconds ~/ _repDuration.inMilliseconds + 1).clamp(1, _reps);
    // Simulated sensor: smooth up-and-back sweep between lo and hi.
    final angle = m.lo + (m.hi - m.lo) * (0.5 - 0.5 * math.cos(repProgress * 2 * math.pi));
    return _LiveCard(
      label: 'STEP 2 OF 2',
      title: 'Move slowly — $rep of $_reps',
      text: m.instruction,
      ring: RadialProgress(
        value: (angle - m.lo) / (m.hi - m.lo),
        size: 170,
        stroke: 12,
        center: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${angle.round()}°',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: c.ink, height: 1)),
            Text(m.metric, style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ),
      ),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 1; i <= _reps; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == rep ? 26 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: i <= rep ? c.primary : c.border,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _done(BuildContext context) {
    final c = context.colors;
    final b = data.baseline!;
    final m = _movement;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: c.successTint, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, color: c.success, size: 32),
              ),
              const SizedBox(height: 12),
              Text('Baseline recorded', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${m.metric} · ${data.sideLabel}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Metric(label: 'Starting point', value: '${b.extension}°'),
                  _Metric(label: 'Furthest', value: '${b.flexion}°'),
                  _Metric(label: 'Range', value: '${b.range}°', highlight: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const InfoBanner(
          icon: Icons.insights_outlined,
          text: 'Your physiotherapist will see these numbers and set targets from them.',
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
              onPressed: _redo, icon: const Icon(Icons.replay, size: 18), label: const Text('Redo calibration')),
        ),
      ],
    );
  }

  Widget _noWearable(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(
          icon: Icons.bluetooth_disabled,
          tone: BannerTone.warning,
          text: 'Calibration needs your Inteli Band. Pair it first.',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: widget.onBackToWearable,
          icon: const Icon(Icons.bluetooth, size: 18),
          label: const Text('Pair my band'),
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
          text: "Calibration skipped. We'll ask you to record a baseline before your first session.",
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => data.update(() => data.calibrationSkipped = false),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Calibrate now instead'),
        ),
      ],
    );
  }
}

class _LiveCard extends StatelessWidget {
  final String label, title, text;
  final Widget ring;
  final Widget? footer;

  const _LiveCard({required this.label, required this.title, required this.text, required this.ring, this.footer});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: c.accent)),
          const SizedBox(height: 6),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(text, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ring,
          if (footer != null) ...[const SizedBox(height: 20), footer!],
        ],
      ),
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _PhaseRow({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.primaryTint, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 19, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.ink)),
                const SizedBox(height: 1),
                Text(text, style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _Metric({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: highlight ? c.primaryTint : c.bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: highlight ? c.primary : c.ink)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: c.muted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
