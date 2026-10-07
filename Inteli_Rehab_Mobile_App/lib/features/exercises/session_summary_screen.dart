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

  /// Neither the server nor the phone's own storage accepted the session.
  final bool saveFailed;
  final VoidCallback onViewProgress;
  const SessionSummaryScreen({
    super.key,
    required this.result,
    this.queued = false,
    this.saveFailed = false,
    required this.onViewProgress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final formAlerts = result.alerts.where((a) => !a.pain);
    final corrections = formAlerts.where((a) => a.tier == SafetyTier.needsCorrection).length;
    final unsafe = formAlerts.where((a) => a.tier == SafetyTier.unsafe).length;
    final painReports = result.alerts.where((a) => a.pain).length;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Session Summary')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                IconBadge(saveFailed ? Icons.warning_amber_rounded : Icons.check_rounded,
                    color: saveFailed ? c.alert : c.success, size: 72),
                const SizedBox(height: 14),
                Text(saveFailed ? 'Session not saved' : 'Session saved',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.ink)),
                const SizedBox(height: 4),
                Text(
                  saveFailed
                      ? "We couldn't store this session - your phone may be low on space. Free some space and tell your "
                          'physiotherapist.'
                      : queued
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
                  value: '${result.repsCompleted}/${result.repsPlanned ?? result.exercise.repsTarget}',
                  label: 'Reps',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: Icons.timer_outlined,
                  value: _duration(result.duration),
                  label: result.rest.inSeconds >= 5 ? 'Exercise · ${_duration(result.rest)} rest' : 'Duration',
                ),
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
                if (formAlerts.isEmpty)
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
                if (painReports > 0)
                  _AlertLine(
                    icon: Icons.healing_outlined,
                    color: c.alert,
                    text: 'You reported pain $painReports time${painReports == 1 ? '' : 's'}',
                  ),
                if (result.painLevel != null)
                  _AlertLine(
                    icon: Icons.sentiment_neutral_outlined,
                    color: result.painLevel! >= 7 ? c.alert : c.muted,
                    text: 'Pain rating: ${result.painLevel} out of 10',
                  ),
                if (result.endedReason != null)
                  _AlertLine(
                    icon: Icons.flag_outlined,
                    color: c.muted,
                    text: 'Stopped early: ${result.endedReason!.label.toLowerCase()}',
                  ),
              ],
            ),
          ),
          if (result.sets.length > 1) ...[
            const SizedBox(height: 22),
            const SectionLabel('Set by set'),
            AppCard(
              child: Column(
                children: [
                  for (final set in result.sets) _SetRow(set: set, repsPerSet: result.exercise.repsTarget),
                ],
              ),
            ),
          ],
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

class _SetRow extends StatelessWidget {
  final SetResult set;
  final int repsPerSet;
  const _SetRow({required this.set, required this.repsPerSet});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final prompts = set.corrections + set.unsafe;
    final detail = [
      '${set.reps}/$repsPerSet reps',
      '${set.romPercent}% ROM',
      prompts == 0 ? 'no prompts' : '$prompts prompt${prompts == 1 ? '' : 's'}',
      if (set.fatigue != FatigueLevel.normal) '${set.fatigue.name} fatigue',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set ${set.number}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 2),
          Text(detail, style: TextStyle(fontSize: 13, color: c.muted)),
        ],
      ),
    );
  }
}
