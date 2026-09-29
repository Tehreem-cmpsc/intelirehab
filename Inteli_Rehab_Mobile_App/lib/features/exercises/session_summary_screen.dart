import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../home/widgets/rom_target_bar.dart';
import 'exercises_models.dart';

/// STATE 4. "Session saved" (Rule 3) — true either way: uploaded, or kept on
/// the phone to sync later (Rule 26, offline-first; [queued]). Alerts are
/// listed factually — "N correction prompts", never a shaming tone.
class SessionSummaryScreen extends StatelessWidget {
  final SessionResult result;
  final bool queued;
  final VoidCallback onViewProgress;
  const SessionSummaryScreen({super.key, required this.result, this.queued = false, required this.onViewProgress});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final corrections = result.alerts.where((a) => a.tier == SafetyTier.needsCorrection).length;
    final unsafe = result.alerts.where((a) => a.tier == SafetyTier.unsafe).length;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Session Summary')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                IconBadge(Icons.check_rounded, color: c.success, size: 72),
                const SizedBox(height: 14),
                Text('Session saved', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.ink)),
                const SizedBox(height: 4),
                Text(
                  queued
                      ? "Saved on this phone — it'll upload automatically when you're back online."
                      : 'Nice work on ${result.exercise.name}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.repeat,
                  value: '${result.repsCompleted}/${result.exercise.repsTarget}',
                  label: 'Reps',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(icon: Icons.timer_outlined, value: _duration(result.duration), label: 'Duration'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(child: RomTargetBar(achieved: result.romAchieved, target: result.exercise.romTarget)),
          const SizedBox(height: 22),
          const SectionLabel('During this session'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.alerts.isEmpty)
                  _AlertLine(
                      icon: Icons.check_circle_outline,
                      color: c.success,
                      text: 'No correction prompts — good form throughout.')
                else ...[
                  if (corrections > 0)
                    _AlertLine(
                      icon: Icons.change_history,
                      color: c.accent,
                      text: '$corrections correction prompt${corrections == 1 ? '' : 's'}',
                    ),
                  if (unsafe > 0)
                    _AlertLine(
                      icon: Icons.report_outlined,
                      color: c.alert,
                      text: '$unsafe potentially unsafe movement prompt${unsafe == 1 ? '' : 's'}',
                    ),
                ],
                if (result.peakFatigue == FatigueLevel.critical)
                  _AlertLine(icon: Icons.self_improvement, color: c.accent, text: 'High fatigue — a break was offered'),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              onViewProgress();
            },
            child: const Text('View Progress'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Back to Exercises'),
          ),
        ],
      ),
    );
  }

  static String _duration(Duration d) {
    if (d.inMinutes == 0) return '${d.inSeconds}s';
    return '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13.5, color: context.colors.ink))),
        ],
      ),
    );
  }
}
