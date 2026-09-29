import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../exercises_models.dart';

/// BR-12's activation scale: Blue -> Green -> Orange -> Red, each with a
/// text label, rendered as a labeled gradient bar with a small legend —
/// never a bare colored icon, and deliberately never sharing a shape or
/// layout with the safety banner below, so the two systems can't be read
/// as one (Rule 9): this one measures effort, that one measures safety.
class MuscleActivationBar extends StatelessWidget {
  final MuscleActivation level;
  const MuscleActivationBar({super.key, required this.level});

  static const _stops = [
    (MuscleActivation.resting, 'Resting', Color(0xFF3B82F6)),
    (MuscleActivation.light, 'Light', Color(0xFF4C9F70)),
    (MuscleActivation.moderate, 'Moderate', Color(0xFFE7A24C)),
    (MuscleActivation.high, 'High effort', Color(0xFFD96248)),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final index = _stops.indexWhere((s) => s.$1 == level);
    return Semantics(
      label: 'Muscle activation: ${_stops[index].$2}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('MUSCLE ACTIVATION',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: c.muted)),
              const Spacer(),
              Text(_stops[index].$2,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _stops[index].$3)),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final fraction = index / (_stops.length - 1);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(colors: [for (final s in _stops) s.$3]),
                  ),
                ),
                Positioned(
                  left: (constraints.maxWidth * fraction - 8).clamp(0, constraints.maxWidth - 16),
                  top: -3,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.surface,
                      border: Border.all(color: _stops[index].$3, width: 3),
                    ),
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final s in _stops)
                Expanded(
                  child: Text(
                    s.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: s.$1 == level ? FontWeight.w700 : FontWeight.w500,
                      color: s.$1 == level ? s.$3 : c.muted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
