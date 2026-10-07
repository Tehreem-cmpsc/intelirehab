import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../home/bluetooth_rationale.dart';
import '../home/wearable_connection_controller.dart';
import 'active_session_screen.dart';
import 'exercises_models.dart';
import 'session_controller.dart';
import 'session_cues.dart';
import 'session_setup_loader.dart';
import 'widgets/exercise_media.dart';
import 'widgets/warning_banner.dart';

/// Today's workout: every exercise on the plan, one after the other, with a short "next up" screen between
/// them and one summary at the end, instead of starting each exercise separately from the list.
///
/// Each exercise is still its own session (its own saved result, its own safety checks): this only walks
/// the patient through them. They can skip an exercise, or finish the workout early, at any point - and an
/// exercise they stop part-way does not end the workout unless they say so.
class WorkoutFlowScreen extends StatefulWidget {
  final List<AssignedExercise> exercises;
  final String patientId;
  final WearableConnectionController connection;
  final VoidCallback onViewProgress;
  final String armSide;

  /// Test seams: where the setup (the whole of it, replacing the server read and the phone's cache), the
  /// saving, the session itself and the cues come from.
  final Future<SessionSetup> Function()? loadSetup;
  final SessionSaver? saveResult;
  final SessionController Function(WearableConnectionController, AssignedExercise)? sessionFactory;
  final SessionCues? cues;

  const WorkoutFlowScreen({
    super.key,
    required this.exercises,
    required this.patientId,
    required this.connection,
    required this.onViewProgress,
    this.armSide = 'left',
    this.loadSetup,
    this.saveResult,
    this.sessionFactory,
    this.cues,
  });

  @override
  State<WorkoutFlowScreen> createState() => _WorkoutFlowScreenState();
}

class _WorkoutFlowScreenState extends State<WorkoutFlowScreen> {
  late final Future<SessionSetup> _setup = widget.loadSetup?.call() ?? loadSessionSetup(widget.patientId);
  final _outcomes = <SessionOutcome>[];
  final _skipped = <AssignedExercise>[];
  int _index = 0;
  bool _starting = false;

  AssignedExercise get _next => widget.exercises[_index];
  bool get _isLast => _index >= widget.exercises.length - 1;

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    final setup = await _setup;
    if (!mounted) return;
    final exercise = _next;
    final outcome = await Navigator.of(context).push<SessionOutcome>(MaterialPageRoute(
      builder: (_) => ActiveSessionScreen(
        exercise: exercise,
        patientId: widget.patientId,
        connection: widget.connection,
        onViewProgress: widget.onViewProgress,
        armSide: widget.armSide,
        setup: setup,
        returnOutcome: true,
        saveResult: widget.saveResult,
        sessionFactory: widget.sessionFactory,
        cues: widget.cues,
      ),
    ));
    if (!mounted) return;
    setState(() => _starting = false);
    if (outcome == null) return; // left without a result: stay on this exercise
    _outcomes.add(outcome);
    _advance();
  }

  void _skip() {
    _skipped.add(_next);
    _advance();
  }

  void _advance() {
    if (_isLast) {
      _showSummary();
    } else {
      setState(() => _index++);
    }
  }

  void _showSummary() {
    final done = {for (final o in _outcomes) o.result.exercise.assignmentId};
    final skippedIds = {for (final s in _skipped) s.assignmentId};
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WorkoutSummaryScreen(
        outcomes: List.unmodifiable(_outcomes),
        // Skipped on purpose, plus anything not reached because the patient finished early.
        skipped: List.unmodifiable([
          ..._skipped,
          for (final e in widget.exercises)
            if (!done.contains(e.assignmentId) && !skippedIds.contains(e.assignmentId)) e,
        ]),
        onViewProgress: widget.onViewProgress,
      ),
    ));
  }

  Future<void> _finishEarly() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish the workout here?'),
        content: Text(_outcomes.isEmpty
            ? 'Nothing has been recorded yet.'
            : 'What you have done so far is already saved. The rest will be left for another time.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Finish')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    if (_outcomes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    _showSummary();
  }

  Future<void> _reconnect() async {
    if (!await BluetoothRationale.ensure(context)) return;
    await widget.connection.reconnect();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = widget.exercises.length;
    final last = _outcomes.isEmpty ? null : _outcomes.last;
    final ex = _next;
    final meta = [
      '${ex.sets} × ${ex.repsTarget} reps',
      if (ex.romTarget != null) 'ROM ${ex.romTarget}%',
      if (ex.sets > 1) '${ex.restBetweenSets}s rest between sets',
    ].join(' · ');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finishEarly();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Today's workout")),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            WarningBanner(patientId: widget.patientId),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_outcomes.length + _skipped.length) / total,
                      minHeight: 8,
                      backgroundColor: c.border,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Exercise ${_index + 1} of $total',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
              ],
            ),
            if (last != null) ...[
              const SizedBox(height: 16),
              AppCard(
                color: c.primaryTint,
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: c.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${last.result.exercise.name}: ${last.result.repsCompleted} reps, ${last.result.romAchieved}% ROM'
                        '${last.result.endedReason == null ? '' : ' (stopped early)'}',
                        style: TextStyle(fontSize: 13.5, color: c.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Take a moment to shake out your arm before the next one.',
                    style: TextStyle(fontSize: 13, color: c.muted)),
              ),
            ],
            const SizedBox(height: 20),
            SectionLabel(_outcomes.isEmpty && _skipped.isEmpty ? 'First up' : 'Next up'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExerciseMedia(mediaUrl: ex.mediaUrl, mediaType: ex.mediaType, name: ex.name),
                  const SizedBox(height: 14),
                  Text(ex.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(meta, style: TextStyle(fontSize: 13.5, color: c.muted)),
                  if (ex.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text(ex.description!.trim(), style: TextStyle(fontSize: 14, height: 1.5, color: c.ink)),
                  ],
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: AnimatedBuilder(
          animation: widget.connection,
          builder: (context, _) {
            final connected = widget.connection.isConnected;
            final busy = widget.connection.state == WearableConnState.searching ||
                widget.connection.state == WearableConnState.calibrating;
            return BottomActionBar(
              children: [
                if (!connected)
                  Row(
                    children: [
                      Icon(Icons.bluetooth_disabled_rounded, size: 18, color: c.alert),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          busy ? 'Connecting to your wearable…' : 'Reconnect your wearable to continue.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.alert),
                        ),
                      ),
                      TextButton(onPressed: busy ? null : _reconnect, child: const Text('Reconnect')),
                    ],
                  ),
                FilledButton.icon(
                  onPressed: connected && !_starting ? _start : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(_outcomes.isEmpty && _skipped.isEmpty ? 'Start exercise' : 'Start next exercise'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _starting ? null : _skip,
                        child: Text(_isLast ? 'Skip and finish' : 'Skip this one'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _starting ? null : _finishEarly,
                        child: const Text('Finish workout'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One summary for the whole workout: what was done, what was skipped, and whether anything is still
/// waiting to upload.
class WorkoutSummaryScreen extends StatelessWidget {
  final List<SessionOutcome> outcomes;
  final List<AssignedExercise> skipped;
  final VoidCallback onViewProgress;

  const WorkoutSummaryScreen({
    super.key,
    required this.outcomes,
    required this.skipped,
    required this.onViewProgress,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reps = outcomes.fold<int>(0, (sum, o) => sum + o.result.repsCompleted);
    final time = outcomes.fold<Duration>(Duration.zero, (sum, o) => sum + o.result.duration);
    final queued = outcomes.any((o) => o.queued);
    final failed = outcomes.any((o) => o.saveFailed);
    final highestPain = outcomes.map((o) => o.result.painLevel).whereType<int>().fold<int?>(null, (a, b) => a == null || b > a ? b : a);

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Workout summary')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                IconBadge(failed ? Icons.warning_amber_rounded : Icons.check_rounded,
                    color: failed ? c.alert : c.success, size: 72),
                const SizedBox(height: 14),
                Text(failed ? 'Some of the workout was not saved' : 'Workout done',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.ink)),
                const SizedBox(height: 4),
                Text(
                  failed
                      ? "We couldn't store everything - your phone may be low on space. Free some space and tell your physiotherapist."
                      : queued
                          ? "Saved on this phone — it'll upload automatically when you're back online."
                          : outcomes.isEmpty
                              ? 'Nothing was recorded this time.'
                              : 'Nice work today.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: StatTile(icon: Icons.fitness_center, value: '${outcomes.length}', label: 'Exercises')),
              const SizedBox(width: 12),
              Expanded(child: StatTile(icon: Icons.repeat, value: '$reps', label: 'Reps')),
              const SizedBox(width: 12),
              Expanded(child: StatTile(icon: Icons.timer_outlined, value: _duration(time), label: 'Time')),
            ],
          ),
          if (outcomes.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionLabel('Exercise by exercise'),
            AppCard(
              child: Column(
                children: [for (final o in outcomes) _OutcomeRow(outcome: o)],
              ),
            ),
          ],
          if (highestPain != null && highestPain >= 7) ...[
            const SizedBox(height: 14),
            AppCard(
              color: c.alertTint,
              child: Row(
                children: [
                  Icon(Icons.healing_outlined, color: c.alert),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You rated your pain $highestPain out of 10. Your physiotherapist can see this.',
                      style: TextStyle(fontSize: 13.5, color: c.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (skipped.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionLabel('Left for another time'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in skipped)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(s.name, style: TextStyle(fontSize: 13.5, color: c.ink)),
                    ),
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

class _OutcomeRow extends StatelessWidget {
  final SessionOutcome outcome;
  const _OutcomeRow({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = outcome.result;
    final prompts = r.alerts.where((a) => !a.pain).length;
    final detail = [
      '${r.repsCompleted}/${r.repsPlanned ?? r.exercise.repsTarget} reps',
      '${r.romAchieved}% ROM',
      prompts == 0 ? 'no prompts' : '$prompts prompt${prompts == 1 ? '' : 's'}',
      if (r.painLevel != null) 'pain ${r.painLevel}/10',
      if (r.endedReason != null) 'stopped early',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.exercise.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 2),
          Text(detail, style: TextStyle(fontSize: 13, color: c.muted)),
        ],
      ),
    );
  }
}
