import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../exercises_models.dart';

/// Separate small indicator — not part of the safety banner or the
/// activation bar. Mild/moderate/critical only shows visual weight at
/// "critical" (Rule 17 — reserve intensity for what's genuinely important;
/// that's also the one state the Active Session screen auto-pauses on).
class FatigueMeter extends StatelessWidget {
  final FatigueLevel level;

  /// The estimate rests on movement speed alone (no usable muscle signal), so say so.
  final bool speedOnly;
  const FatigueMeter({super.key, required this.level, this.speedOnly = false});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color, bars) = switch (level) {
      FatigueLevel.normal => ('Normal', c.muted, 0),
      FatigueLevel.mild => ('Mild fatigue', c.muted, 1),
      FatigueLevel.moderate => ('Moderate fatigue', c.accent, 2),
      FatigueLevel.critical => ('Critical fatigue', c.alert, 3),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(right: 3),
            width: 6,
            height: 6 + i * 3,
            decoration: BoxDecoration(
              color: i < bars ? color : c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        if (speedOnly) ...[
          const SizedBox(width: 6),
          Text('(from speed only)', style: TextStyle(fontSize: 11, color: c.muted)),
        ],
      ],
    );
  }
}
