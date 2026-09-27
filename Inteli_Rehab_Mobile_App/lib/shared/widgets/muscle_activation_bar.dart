import 'package:flutter/material.dart';
import '../enums/fatigue_level.dart';

/// Real-time or summary EMG muscle activation bar with fatigue threshold markers.
class MuscleActivationBar extends StatelessWidget {
  final String muscleName;
  final double activationPercent; // 0.0 - 1.0
  final FatigueLevel fatigueLevel;
  final double height;

  const MuscleActivationBar({
    super.key,
    required this.muscleName,
    required this.activationPercent,
    this.fatigueLevel = FatigueLevel.none,
    this.height = 20,
  });

  Color get _barColor {
    switch (fatigueLevel) {
      case FatigueLevel.critical:
        return Colors.red.shade700;
      case FatigueLevel.high:
        return Colors.red.shade400;
      case FatigueLevel.moderate:
        return Colors.orange;
      case FatigueLevel.mild:
        return Colors.amber;
      case FatigueLevel.none:
        return Colors.teal;
    }
  }

  IconData get _statusIcon {
    switch (fatigueLevel) {
      case FatigueLevel.critical:
        return Icons.pause_circle_outline_rounded;
      case FatigueLevel.high:
        return Icons.warning_amber_rounded;
      case FatigueLevel.moderate:
        return Icons.info_outline_rounded;
      case FatigueLevel.mild:
      case FatigueLevel.none:
        return Icons.check_circle_outline_rounded;
    }
  }

  String get _statusLabel {
    switch (fatigueLevel) {
      case FatigueLevel.critical:
        return 'Fatigue Alert (Break)';
      case FatigueLevel.high:
        return 'High Strain';
      case FatigueLevel.moderate:
        return 'Moderate';
      case FatigueLevel.mild:
        return 'Active';
      case FatigueLevel.none:
        return 'Optimal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final clamped = activationPercent.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              muscleName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon, size: 16, color: _barColor),
                const SizedBox(width: 4),
                Text(
                  '${(clamped * 100).toStringAsFixed(0)}% ($_statusLabel)',
                  style: TextStyle(
                    fontSize: 14,
                    color: _barColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: height,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(_barColor),
          ),
        ),
      ],
    );
  }
}
