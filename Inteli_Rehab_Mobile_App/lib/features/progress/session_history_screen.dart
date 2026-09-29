import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import 'progress_models.dart';
import 'session_detail_screen.dart';

/// A patient-facing extension of UC-11/FR-11 (gap #2) — a chronological
/// list a patient can browse, not literally UC-15's clinician-facing view.
class SessionHistoryScreen extends StatelessWidget {
  final List<SessionHistoryEntry> history;
  const SessionHistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session History')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          itemCount: history.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _HistoryRow(entry: history[i]),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final SessionHistoryEntry entry;
  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final when = [
      _formatDate(entry.performedAt),
      if (entry.durationSeconds != null) _formatDuration(entry.durationSeconds!)
    ].join(' · ');
    return AppCard(
      semanticLabel: '${entry.exerciseName}, $when, ROM ${entry.romAchieved} percent. Opens session details.',
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SessionDetailScreen(entry: entry))),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: c.primaryTint, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text('${entry.performedAt.day}',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.primary, height: 1.1)),
                Text(_month(entry.performedAt),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.primary)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.exerciseName, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.ink)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (entry.durationSeconds != null) _formatDuration(entry.durationSeconds!),
                    '${entry.reps} reps',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12.5, color: c.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${entry.romAchieved}%',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.primary)),
              Text('ROM', style: TextStyle(fontSize: 11, color: c.muted)),
            ],
          ),
          Icon(Icons.chevron_right, color: c.muted),
        ],
      ),
    );
  }
}

String _month(DateTime d) =>
    const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1];

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

String _formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return m > 0 ? '$m min ${s}s' : '${s}s';
}
