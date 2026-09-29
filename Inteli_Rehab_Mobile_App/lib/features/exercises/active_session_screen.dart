import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../home/bluetooth_rationale.dart';
import '../home/wearable_connection_controller.dart';
import '../home/widgets/rom_target_bar.dart';
import '../home/widgets/wearable_status_chip.dart';
import 'exercises_models.dart';
import 'exercises_repository.dart';
import 'session_journal.dart';
import 'session_simulator.dart';
import 'session_summary_screen.dart';
import 'widgets/fatigue_meter.dart';
import 'widgets/live_digital_twin.dart';
import 'widgets/muscle_activation_bar.dart';
import 'widgets/safety_banner.dart';
import 'widgets/session_state_chip.dart';

/// STATE 3 — the genuinely live view (gap #1's real home for it, unlike
/// Home's static digital twin). Covers UC-8/UC-9/UC-10's real-time
/// feedback, muscle activation, fatigue pause and End Session.
///
/// Mobile-lifecycle rules applied here:
///  * Rule 22/27 — backgrounding pauses (never discards) and every rep is
///    journalled to disk, so a call, a lock or the OS killing the app loses
///    nothing; returning resumes with "Session resumed."
///  * Rule 24 — system back goes through the same End Session confirm.
///  * Rule 26 — saving is offline-first: no connection just queues it.
///  * Rule 29 — a haptic pulse per rep and on completion (eyes are on the
///    arm, not the screen). Rule 30 — portrait-locked while live.
class ActiveSessionScreen extends StatefulWidget {
  final AssignedExercise exercise;
  final String patientId;
  final WearableConnectionController connection;
  final VoidCallback onViewProgress;

  const ActiveSessionScreen({
    super.key,
    required this.exercise,
    required this.patientId,
    required this.connection,
    required this.onViewProgress,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> with WidgetsBindingObserver {
  late final _simulator = SessionSimulator(
    repsTarget: widget.exercise.repsTarget,
    romTargetPercent: widget.exercise.romTarget,
  );
  final _repo = ExercisesRepository();

  bool _fatigueDialogShown = false;
  bool _finishing = false;
  bool _resumeOnForeground = false;
  int _lastReps = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addObserver(this);
    _simulator.addListener(_onTick);
    widget.connection.addListener(_onConnectionChanged);
    if (widget.connection.isConnected) _simulator.start();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []); // back to the app default
    WidgetsBinding.instance.removeObserver(this);
    _simulator.removeListener(_onTick);
    widget.connection.removeListener(_onConnectionChanged);
    _simulator.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_finishing) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_simulator.isRunning) {
          _resumeOnForeground = true;
          _simulator.pause();
        }
        _journal();
      case AppLifecycleState.resumed:
        if (_resumeOnForeground &&
            widget.connection.isConnected &&
            !_simulator.awaitingUnsafeAck &&
            !_simulator.fatiguePauseOffered) {
          _simulator.resume();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session resumed.'), duration: Duration(seconds: 2)),
          );
        }
        _resumeOnForeground = false;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Rewrites the on-disk copy — the reps recorded so far are never only
  /// in memory.
  void _journal() {
    unawaited(SessionJournal.saveInProgress(widget.patientId, _simulator.buildResult(widget.exercise)));
  }

  void _onConnectionChanged() {
    if (!widget.connection.isConnected && _simulator.isRunning) {
      _simulator.pause();
      _journal();
    }
    if (mounted) setState(() {});
  }

  void _onTick() {
    if (!mounted) return;
    if (_simulator.repsCompleted > _lastReps) {
      _lastReps = _simulator.repsCompleted;
      HapticFeedback.mediumImpact();
      _journal();
    }
    setState(() {});

    if (_simulator.fatiguePauseOffered && !_fatigueDialogShown) {
      _fatigueDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showFatigueDialog());
    }
    if (!_simulator.isRunning &&
        !_simulator.fatiguePauseOffered &&
        !_simulator.awaitingUnsafeAck &&
        _simulator.repsCompleted >= _simulator.repsTarget) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    }
  }

  Future<void> _showFatigueDialog() async {
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.self_improvement, color: context.colors.accent, size: 32),
        title: const Text("Let's take a break."),
        content: const Text('High fatigue detected.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop('end'), child: const Text('End session')),
          FilledButton(onPressed: () => Navigator.of(context).pop('resume'), child: const Text('Resume')),
        ],
      ),
    );
    _fatigueDialogShown = false;
    if (!mounted) return;
    if (action == 'resume') {
      _simulator.acknowledgeFatiguePause();
    } else {
      _finish();
    }
  }

  Future<void> _confirmEndSession() async {
    if (_finishing) return;
    final wasRunning = _simulator.isRunning;
    _simulator.pause();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End rehabilitation session?'),
        content: const Text('Your progress so far will be saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('End session')),
        ],
      ),
    );
    if (confirmed == true) {
      _finish();
    } else if (wasRunning && widget.connection.isConnected) {
      _simulator.resume();
    }
  }

  Future<void> _finish() async {
    // Every exit path (auto-complete, fatigue "End", End Session) lands
    // here — guarded so a session is only ever saved once.
    if (!mounted || _finishing) return;
    _finishing = true;
    _simulator.pause();
    HapticFeedback.heavyImpact();
    final result = _simulator.buildResult(widget.exercise);

    var queued = false;
    String? deviceId;
    try {
      deviceId = await _repo.pairedDeviceId(widget.patientId).timeout(const Duration(seconds: 8));
      await _repo
          .saveSession(patientId: widget.patientId, deviceId: deviceId, result: result)
          .timeout(const Duration(seconds: 15));
      await SessionJournal.clearInProgress();
    } catch (_) {
      // Offline or slow — keep it on the phone and sync later (Rule 26).
      await SessionJournal.enqueue(widget.patientId, deviceId, result);
      queued = true;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionSummaryScreen(result: result, queued: queued, onViewProgress: widget.onViewProgress),
      ),
    );
  }

  Future<void> _reconnect() async {
    if (!await BluetoothRationale.ensure(context)) return;
    await widget.connection.reconnect();
    if (!mounted) return;
    if (widget.connection.isConnected && !_simulator.awaitingUnsafeAck && !_simulator.fatiguePauseOffered) {
      _simulator.resume();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session resumed.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final connected = widget.connection.isConnected;
    final reps = _simulator.repsCompleted.clamp(0, _simulator.repsTarget);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmEndSession();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.exercise.name),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: SessionStateChip(recording: _simulator.isRunning)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child:
                  WearableStatusChip(state: widget.connection.state, batteryPercent: widget.connection.batteryPercent),
            ),
            const SizedBox(height: 12),
            if (!connected) ...[
              _ConnectionLostBanner(connection: widget.connection, onReconnect: _reconnect),
              const SizedBox(height: 14),
            ],
            // Largest, most prominent element (Rule 8); announced as it changes.
            Semantics(
              liveRegion: true,
              child: SafetyBanner(tier: _simulator.currentTier, onAcknowledgeUnsafe: _simulator.acknowledgeUnsafe),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  Semantics(
                    liveRegion: true,
                    label: 'Rep $reps of ${_simulator.repsTarget}',
                    excludeSemantics: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Rep ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.muted)),
                        Text('$reps',
                            style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: c.ink, height: 1)),
                        Text(' of ${_simulator.repsTarget}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _simulator.repsTarget == 0 ? 0 : reps / _simulator.repsTarget,
                      minHeight: 8,
                      backgroundColor: c.border,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: LiveDigitalTwin(angleDegrees: _simulator.liveAngle, tier: _simulator.currentTier),
                  ),
                  const SizedBox(height: 14),
                  RomTargetBar(achieved: _simulator.liveAngle, target: _simulator.romTargetPercent),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(child: MuscleActivationBar(level: _simulator.activation)),
            const SizedBox(height: 14),
            Row(
              children: [
                FatigueMeter(level: _simulator.fatigueLevel),
                const Spacer(),
                Text(_elapsedLabel(_simulator.elapsed), style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ],
        ),
        // Always visible, thumb-zone, never gesture-only (Rules 21, 33).
        bottomNavigationBar: BottomActionBar(
          children: [
            OutlinedButton.icon(
              onPressed: _finishing ? null : _confirmEndSession,
              icon: const Icon(Icons.stop_circle_outlined),
              style: OutlinedButton.styleFrom(foregroundColor: c.alert, side: BorderSide(color: c.alert)),
              label: const Text('End Session'),
            ),
          ],
        ),
      ),
    );
  }

  static String _elapsedLabel(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s elapsed';
  }
}

class _ConnectionLostBanner extends StatelessWidget {
  final WearableConnectionController connection;
  final VoidCallback onReconnect;
  const _ConnectionLostBanner({required this.connection, required this.onReconnect});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final busy = connection.state == WearableConnState.searching || connection.state == WearableConnState.calibrating;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.alertTint, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(Icons.link_off, color: c.alert),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                busy ? 'Reconnecting…' : 'Connection lost. Reconnect to continue.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.alert),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: busy ? null : onReconnect,
              style: FilledButton.styleFrom(backgroundColor: c.alert, minimumSize: const Size(0, 44)),
              child: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Reconnect'),
            ),
          ],
        ),
      ),
    );
  }
}
