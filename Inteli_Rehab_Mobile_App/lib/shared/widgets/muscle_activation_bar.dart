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

  @override
  Widget build(BuildContext context) {
    final clamped = activationPercent.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(muscleName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text('${(clamped * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: _barColor, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
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
