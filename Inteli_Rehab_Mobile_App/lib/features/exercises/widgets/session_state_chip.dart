import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Extends the shared status-chip idiom (see WearableStatusChip) with the
/// session's own Recording/Paused state — separate from the connection
/// chip, which stays visible alongside it.
class SessionStateChip extends StatelessWidget {
  final bool recording;
  const SessionStateChip({super.key, required this.recording});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = recording ? c.alert : c.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(recording ? Icons.fiber_manual_record : Icons.pause, size: 12, color: color),
          const SizedBox(width: 6),
          Text(recording ? 'Recording' : 'Paused',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
