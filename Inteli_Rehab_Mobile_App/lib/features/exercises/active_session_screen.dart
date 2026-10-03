import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui_kit.dart';
import '../home/ble/arm_band_protocol.dart';
import '../home/bluetooth_rationale.dart';
import '../home/wearable_connection_controller.dart';
import '../home/widgets/rom_target_bar.dart';
import '../home/widgets/wearable_status_chip.dart';
import 'exercises_models.dart';
import 'exercises_repository.dart';
import 'session_journal.dart';
import 'live_session.dart';
import 'session_controller.dart';
import 'session_summary_screen.dart';
import 'widgets/fatigue_meter.dart';
import '../twin/live_twin_view.dart';
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

  /// Which arm model the live 3D twin shows ('left' or 'right').
  final String armSide;

  /// Builds what drives the session. Defaults to [LiveSession] on the real
  /// band's sensor stream; tests and demos can pass a simulator.
  final SessionController Function(WearableConnectionController connection, AssignedExercise exercise)? sessionFactory;

  const ActiveSessionScreen({
    super.key,
    required this.exercise,
    required this.patientId,
    required this.connection,
    required this.onViewProgress,
    this.armSide = 'left',
    this.sessionFactory,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> with WidgetsBindingObserver {
  late final SessionController _simulator = (widget.sessionFactory ?? _liveSession)(widget.connection, widget.exercise);

  static SessionController _liveSession(WearableConnectionController connection, AssignedExercise exercise) =>
      LiveSession(
        repsTarget: exercise.repsTarget,
        romTargetPercent: exercise.romTarget,
        samples: connection.liveSamples,
      );

  /// A live session can't start until the patient has set the band's zero
  /// pose - every angle is measured from it. Simulated sessions need no setup.
  late bool _ready = _simulator is! LiveSession;
  final _repo = ExercisesRepository();

  bool _fatigueDialogShown = false;
  bool _finishing = false;
  bool _resumeOnForeground = false;
  bool _pausedForDrop = false; // paused because the band dropped, so resume when it's back
  bool _inForeground = true;
  bool _endDialogOpen = false;
  int _lastReps = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addObserver(this);
    _simulator.addListener(_onTick);
    widget.connection.addListener(_onConnectionChanged);
    if (widget.connection.isConnected && _ready) _simulator.start();
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
        _inForeground = false;
        if (_simulator.isRunning) {
          _resumeOnForeground = true;
          _simulator.pause();
        }
        _journal();
      case AppLifecycleState.resumed:
        _inForeground = true;
        // If the band dropped while the app was away this waits for it to
        // come back (see _onConnectionChanged) rather than giving up.
        _tryAutoResume('Session resumed.');
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Rewrites the on-disk copy — the reps recorded so far are never only
  /// in memory. Best-effort: a failed write must not crash the session.
  void _journal() {
    if (!_ready) return; // nothing recorded yet
    unawaited(
      SessionJournal.saveInProgress(widget.patientId, _simulator.buildResult(widget.exercise)).catchError((_) {}),
    );
  }

  /// Everything that must be true before the session may run on its own.
  bool get _canRunNow =>
      _ready &&
      !_finishing &&
      _inForeground &&
      !_endDialogOpen &&
      widget.connection.isConnected &&
      !_simulator.awaitingUnsafeAck &&
      !_simulator.fatiguePauseOffered &&
      _simulator.repsCompleted < _simulator.repsTarget;

  /// Resumes after an automatic pause (app backgrounded, band dropped) as
  /// soon as nothing else is holding the session. One path for both causes,
  /// so no combination of them can leave it paused for good.
  bool _tryAutoResume(String message) {
    if (!(_resumeOnForeground || _pausedForDrop) || _simulator.isRunning || !_canRunNow) return false;
    _resumeOnForeground = false;
    _pausedForDrop = false;
    _simulator.resume();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
    }
    return true;
  }

  /// Pauses (and remembers to auto-resume) if there is no live band.
  void _pauseIfNoBand() {
    if (widget.connection.isConnected) return;
    if (_simulator.isRunning) _simulator.pause();
    _pausedForDrop = true;
  }

  void _onConnectionChanged() {
    if (!widget.connection.isConnected) {
      // Whatever state the session was in (running, or already paused by the
      // app going to the background or the End dialog), remember that the
      // band went away so it picks up again when it's back.
      if (_ready && !_finishing && _simulator.repsCompleted < _simulator.repsTarget) {
        if (_simulator.isRunning) _simulator.pause();
        _pausedForDrop = true;
        _journal();
      }
    } else {
      _tryAutoResume('Band reconnected. Session resumed.');
    }
    if (mounted) setState(() {});
  }

  void _acknowledgeUnsafe() {
    _simulator.acknowledgeUnsafe();
    _pauseIfNoBand();
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
    if (!mounted) return; // scheduled from a post-frame callback
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
      _pauseIfNoBand();
    } else {
      _finish();
    }
  }

  Future<void> _confirmEndSession() async {
    if (_finishing) return;
    final wasRunning = _simulator.isRunning;
    _endDialogOpen = true;
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
    _endDialogOpen = false;
    if (confirmed == true) {
      _finish();
    } else if (wasRunning) {
      // Keep going: carry on now, or as soon as the band is back.
      _pausedForDrop = true;
      if (!_tryAutoResume('Session resumed.')) {
        if (mounted) setState(() {});
      }
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
    var saveFailed = false;
    String? deviceId;
    try {
      deviceId = await _repo.pairedDeviceId(widget.patientId).timeout(const Duration(seconds: 8));
      await _repo
          .saveSession(patientId: widget.patientId, deviceId: deviceId, result: result)
          .timeout(const Duration(seconds: 15));
      await SessionJournal.clearInProgress();
    } catch (_) {
      // Offline or slow — keep it on the phone and sync later (Rule 26).
      try {
        await SessionJournal.enqueue(widget.patientId, deviceId, result);
        queued = true;
      } catch (_) {
        saveFailed = true; // disk full / storage error: still leave the screen
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionSummaryScreen(
          result: result,
          queued: queued,
          saveFailed: saveFailed,
          onViewProgress: widget.onViewProgress,
        ),
      ),
    );
  }

  Future<void> _setZeroAndStart() async {
    try {
      await widget.connection.sendBandCommand(ArmBandCommand.setZeroPose);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't reach your band. Check the connection and try again.")),
      );
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400)); // let the band latch the new zero
    if (!mounted || !widget.connection.isConnected) return;
    setState(() => _ready = true);
    _simulator.start();
  }

  Future<void> _calibrateMuscles() async {
    try {
      await widget.connection.sendBandCommand(ArmBandCommand.startMvcCalibration);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't reach your band. Check the connection and try again.")),
      );
    }
  }

  Future<void> _reconnect() async {
    if (!await BluetoothRationale.ensure(context)) return;
    await widget.connection.reconnect();
    if (!mounted) return;
    _tryAutoResume('Session resumed.');
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
            if (!_ready)
              _GetReadyCard(connected: connected, onStart: _setZeroAndStart, onCalibrateMuscles: _calibrateMuscles),
            if (_ready) ...[
              // Largest, most prominent element (Rule 8); announced as it changes.
              Semantics(
                liveRegion: true,
                child: SafetyBanner(tier: _simulator.currentTier, onAcknowledgeUnsafe: _acknowledgeUnsafe),
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
                      child: LiveTwinView(
                        // The raw band stream drives the twin even before the session
                        // starts, so the arm mirrors the patient from the first moment.
                        samples: _simulator is LiveSession ? widget.connection.liveSamples : null,
                        fallbackPercent: _simulator.liveAngle,
                        tier: _simulator.currentTier,
                        side: widget.armSide,
                      ),
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
          ],
        ),
        // Always visible, thumb-zone, never gesture-only (Rules 21, 33).
        bottomNavigationBar: BottomActionBar(
          children: [
            // Always a way back in: if anything left the session paused (and
            // nothing is waiting on a dialog or acknowledgement), Resume it.
            if (_ready &&
                !_finishing &&
                !_simulator.isRunning &&
                connected &&
                !_simulator.awaitingUnsafeAck &&
                !_simulator.fatiguePauseOffered &&
                _simulator.repsCompleted < _simulator.repsTarget)
              FilledButton.icon(
                onPressed: () {
                  _resumeOnForeground = false;
                  _pausedForDrop = false;
                  _simulator.resume();
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Resume'),
              ),
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

/// Shown before a live session: the band measures every angle from a zero
/// pose, so the patient sets it first. The muscle calibration is optional
/// (it makes the muscle-activation bar meaningful but isn't needed to count
/// reps).
class _GetReadyCard extends StatefulWidget {
  final bool connected;
  final Future<void> Function() onStart;
  final Future<void> Function() onCalibrateMuscles;
  const _GetReadyCard({required this.connected, required this.onStart, required this.onCalibrateMuscles});

  @override
  State<_GetReadyCard> createState() => _GetReadyCardState();
}

class _GetReadyCardState extends State<_GetReadyCard> {
  bool _starting = false;
  int _countdown = 0; // > 0 while the 5 s muscle calibration runs
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    await widget.onStart();
    if (mounted) setState(() => _starting = false);
  }

  Future<void> _calibrate() async {
    await widget.onCalibrateMuscles();
    if (!mounted) return;
    setState(() => _countdown = 5);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _countdown -= 1);
      if (_countdown <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final calibrating = _countdown > 0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Get ready', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 8),
          Text(
            'Let your arm hang straight down, relaxed. Your band measures every movement from this position.',
            style: TextStyle(fontSize: 14, color: c.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.connected && !_starting && !calibrating ? _start : null,
            icon: _starting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded),
            label: const Text('Set zero position & start'),
          ),
          const SizedBox(height: 14),
          Text(
            'Optional: muscle calibration. Squeeze your biceps as hard as you can for 5 seconds so the muscle bar is accurate.',
            style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.4),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.connected && !_starting && !calibrating ? _calibrate : null,
            child: Text(calibrating ? 'Squeeze hard… $_countdown' : 'Calibrate muscle strength'),
          ),
        ],
      ),
    );
  }
}
