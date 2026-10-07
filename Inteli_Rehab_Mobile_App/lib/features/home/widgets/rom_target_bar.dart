import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// ROM achieved vs. target, as a simple labeled bar with a target tick —
/// deliberately not a chart; this is a static history card, not a live
/// monitoring surface.
class RomTargetBar extends StatelessWidget {
  final int achieved;
  final int? target;
  const RomTargetBar({super.key, required this.achieved, this.target});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final cap = target != null && target! > achieved ? target! : achieved;
    final scale = cap == 0 ? 1 : cap;
    final achievedFraction = (achieved / scale).clamp(0.0, 1.0);
    final targetFraction = target == null ? null : (target! / scale).clamp(0.0, 1.0);
    final metTarget = target != null && achieved >= target!;
    final spoken = [
      'Range of motion $achieved percent',
      if (target != null) 'target $target percent${metTarget ? ', target met' : ''}',
    ].join(', ');

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label under the number, and a target that can shrink: fits narrow
          // phones and OS text scaling up to 200% (Rule 13) without overflow.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Flexible: at 200% text the number + label column was 4px too wide for the row.
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$achieved%',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.ink, height: 1.1)),
                    Text('ROM achieved', style: TextStyle(fontSize: 12, color: c.muted)),
                  ],
                ),
              ),
              if (target != null) ...[
                const SizedBox(width: 12),
                const Spacer(),
                Icon(metTarget ? Icons.check_circle : Icons.flag_outlined,
                    size: 14, color: metTarget ? c.success : c.muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    metTarget ? 'Target $target% met' : 'Target $target%',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: metTarget ? c.success : c.muted),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                    height: 10, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(6))),
                FractionallySizedBox(
                  widthFactor: achievedFraction,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: metTarget ? c.success : c.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                if (targetFraction != null)
                  Positioned(
                    left: (constraints.maxWidth * targetFraction - 1).clamp(0, constraints.maxWidth - 2),
                    child: Container(width: 2, height: 10, color: c.ink.withValues(alpha: 0.4)),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
