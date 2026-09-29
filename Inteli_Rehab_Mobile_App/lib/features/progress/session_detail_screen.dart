import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../home/widgets/rom_target_bar.dart';
import '../../core/widgets/ui_kit.dart';
import 'progress_models.dart';

/// The same shape of information a physiotherapist reviews (UC-15), but
/// in patient language — reps, ROM vs. target, duration, and corrections
/// stated factually. No raw sensor values (no quality score, no fatigue
/// number, no joint-angle dump).
class SessionDetailScreen extends StatelessWidget {
  final SessionHistoryEntry entry;
  const SessionDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(entry.exerciseName)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(_formatFullDate(entry.performedAt), style: TextStyle(fontSize: 13, color: c.muted)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: StatTile(icon: Icons.repeat, value: '${entry.reps}', label: 'Reps')),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.timer_outlined,
                    value: entry.durationSeconds == null ? '—' : _formatDuration(entry.durationSeconds!),
                    label: 'Duration',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(child: RomTargetBar(achieved: entry.romAchieved, target: entry.romTarget)),
            const SizedBox(height: 22),
            const SectionLabel('During this session'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.correctionCount == 0 && entry.unsafeCount == 0)
                    Text('No correction prompts — good form throughout.', style: TextStyle(fontSize: 13, color: c.ink))
                  else ...[
                    if (entry.correctionCount > 0)
                      _AlertLine(
                        icon: Icons.change_history,
                        color: c.accent,
                        text: '${entry.correctionCount} correction prompt${entry.correctionCount == 1 ? '' : 's'}',
                      ),
                    if (entry.unsafeCount > 0)
                      _AlertLine(
                        icon: Icons.report,
                        color: c.alert,
                        text:
                            '${entry.unsafeCount} potentially unsafe movement prompt${entry.unsafeCount == 1 ? '' : 's'}',
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatFullDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m min ${s}s' : '${s}s';
  }
}

class _AlertLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _AlertLine({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: context.colors.ink))),
        ],
      ),
    );
  }
}
