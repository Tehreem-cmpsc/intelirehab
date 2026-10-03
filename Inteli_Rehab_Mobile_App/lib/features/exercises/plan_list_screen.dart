import 'package:flutter/material.dart';

import '../../core/network/load_guard.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../home/wearable_connection_controller.dart';
import 'exercise_detail_screen.dart';
import 'exercises_models.dart';
import 'widgets/exercise_media.dart';
import 'exercises_repository.dart';

/// STATE 1 — the always-visible active plan (covers UC-6). No day-of-week
/// gating: the schema has no field for it (gap #3), so the whole active
/// plan shows, not a "today only" subset.
class PlanListScreen extends StatefulWidget {
  final String patientId;
  final WearableConnectionController connection;
  final VoidCallback onViewProgress;
  final String armSide;
  const PlanListScreen({
    super.key,
    required this.patientId,
    required this.connection,
    required this.onViewProgress,
    this.armSide = 'left',
  });

  @override
  State<PlanListScreen> createState() => _PlanListScreenState();
}

class _PlanListScreenState extends State<PlanListScreen> {
  final _repo = ExercisesRepository();
  late Future<PlanSummary> _future = _load();

  Future<PlanSummary> _load() => _repo.loadPlan(widget.patientId).guarded();

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body: FutureBuilder<PlanSummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return MessageState(
              icon: Icons.cloud_off_outlined,
              isError: true,
              title: "Couldn't load your plan",
              text: friendlyError(snap.error!),
              actionLabel: 'Try again',
              onAction: _reload,
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final plan = snap.data!;
          if (plan.exercises.isEmpty) {
            return MessageState(
              icon: Icons.event_note_outlined,
              title: "Your physiotherapist hasn't assigned exercises yet.",
              text: "You'll be notified when they do.",
              actionLabel: 'Refresh',
              onAction: _reload,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                _PlanHeader(plan: plan),
                const SizedBox(height: 22),
                SectionLabel('Your exercises', trailing: PillTag('${plan.exercises.length}')),
                for (final ex in plan.exercises) ...[
                  _ExerciseCard(
                    exercise: ex,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ExerciseDetailScreen(
                          exercise: ex,
                          patientId: widget.patientId,
                          connection: widget.connection,
                          onViewProgress: widget.onViewProgress,
                          armSide: widget.armSide,
                        ),
                      ));
                      _reload();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final PlanSummary plan;
  const _PlanHeader({required this.plan});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final physio = plan.physioName ?? 'your physiotherapist';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.headerStart, c.headerEnd],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE PLAN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: c.accent),
          ),
          const SizedBox(height: 6),
          Text(
            plan.planName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: Text(
                  plan.physioName == null ? '' : initialsOf(plan.physioName!),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Assigned by $physio',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final AssignedExercise exercise;
  final VoidCallback onTap;
  const _ExerciseCard({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = [
      '${exercise.sets} × ${exercise.repsTarget} reps',
      if (exercise.romTarget != null) 'ROM ${exercise.romTarget}%',
    ].join(' · ');
    return AppCard(
      onTap: onTap,
      semanticLabel: '${exercise.name}. $meta. ${exercise.difficulty}. Opens exercise details.',
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
      child: Row(
        children: [
          ExerciseThumb(mediaUrl: exercise.mediaUrl, mediaType: exercise.mediaType, name: exercise.name, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.name, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: c.ink)),
                if (exercise.target != null) ...[
                  const SizedBox(height: 2),
                  Text(exercise.target!, style: TextStyle(fontSize: 12.5, color: c.muted)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    PillTag(meta, icon: Icons.repeat),
                    PillTag(exercise.difficulty, color: c.accent),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.muted),
        ],
      ),
    );
  }
}
