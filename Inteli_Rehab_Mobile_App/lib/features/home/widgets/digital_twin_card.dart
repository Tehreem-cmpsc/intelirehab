import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../home_models.dart';
import 'arm_model_viewer.dart';

/// Same activation → colour mapping as MuscleActivationBar (the live
/// version, on the Active Session screen) — so a patient sees the same
/// colour for "moderate" here as they did during the session.
const _activationColors = {
  'resting': Color(0xFF3B82F6),
  'light': Color(0xFF4C9F70),
  'moderate': Color(0xFFE7A24C),
  'high': Color(0xFFD96248),
};

String _activationLabel(String raw) => switch (raw) {
      'high' => 'High effort',
      _ => raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1),
    };

/// A still snapshot of where the patient's joint currently stands — the
/// last exercise session if there is one, otherwise the onboarding
/// calibration reading, otherwise a neutral pose with no numbers yet.
/// Always visible under the greeting (unlike the Last Session card,
/// which only shows once there's a real session). Deliberately static —
/// this is history/baseline, not a live feed.
class DigitalTwinCard extends StatelessWidget {
  final LastSessionSnapshot? lastSession;
  final BaselineReading? baseline;
  final int sessionsThisWeek;
  final int currentStreak;

  const DigitalTwinCard({
    super.key,
    required this.lastSession,
    required this.baseline,
    required this.sessionsThisWeek,
    required this.currentStreak,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (sourceLabel, metrics) = _resolve();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text('Your arm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.ink))),
              PillTag(sourceLabel, color: lastSession == null && baseline == null ? c.muted : c.primary),
            ],
          ),
          const SizedBox(height: 14),
          const ArmModelViewer(),
          const SizedBox(height: 14),
          Column(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) Divider(height: 14, color: c.border),
                _MetricRow(
                  icon: metrics[i].$1,
                  label: metrics[i].$2,
                  value: metrics[i].$3,
                  color: metrics[i].$4,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  (String, List<(IconData, String, String, Color?)>) _resolve() {
    final session = lastSession;
    if (session != null) {
      final activation = session.muscleActivation;
      return (
        'Last session',
        [
          (Icons.straighten, 'ROM', '${session.rom}%', null),
          (Icons.repeat, 'Reps', '${session.reps}', null),
          if (session.jointAngle != null) (Icons.rotate_right, 'Joint angle', '${session.jointAngle}°', null),
          if (activation != null)
            (Icons.bolt, 'Muscle activation', _activationLabel(activation), _activationColors[activation]),
          (Icons.local_fire_department_outlined, 'Streak', '$currentStreak ${currentStreak == 1 ? 'day' : 'days'}', null),
        ],
      );
    }
    final b = baseline;
    if (b != null) {
      return (
        'Calibration',
        [
          (Icons.architecture, 'Flexion', '${b.flexion.round()}°', null),
          (Icons.straighten, 'Range', '${b.range.round()}°', null),
          (Icons.calendar_today_outlined, 'This week', '$sessionsThisWeek', null),
        ],
      );
    }
    return (
      'Not calibrated yet',
      [
        (Icons.calendar_today_outlined, 'This week', '$sessionsThisWeek', null),
        (Icons.local_fire_department_outlined, 'Streak', '$currentStreak ${currentStreak == 1 ? 'day' : 'days'}', null),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _MetricRow({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? c.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.muted))),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color ?? c.ink)),
        ],
      ),
    );
  }
}
