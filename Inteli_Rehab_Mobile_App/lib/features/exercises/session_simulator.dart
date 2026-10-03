import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/util/uuid.dart';
import 'exercises_models.dart';
import 'processing/ai_engine.dart';
import 'processing/emg_processor.dart';
import 'processing/sensor_fusion.dart';
import 'session_controller.dart';

/// Drives the Active Session screen — the Application Layer's session
/// orchestrator (SDD §3.1.4). It ticks the clock and calls down into the
/// Intelligence & Processing Layer (§3.1.3) for each reading: [SensorFusion]
/// for the joint angle, [EmgProcessor] for activation and fatigue, and
/// [AiEngine] for the safety-tier call and any resulting alert. Those three
/// are what a real BLE/EMG pipeline would replace; this class's own job —
/// rep timing, pause/resume, the fatigue-pause and unsafe-ack policies —
/// stays the same either way.
///
/// This is the TIMER-DRIVEN stand-in, kept for tests and demos: the app's
/// real sessions run on [LiveSession], fed by the band's sensor stream.
/// What feeds the processing layer here is a timer, not a device. What it produces is real enough to save as a real session
/// (ExercisesRepository.saveSession) and to exercise every UI state the
/// spec calls for.
class SessionSimulator extends ChangeNotifier implements SessionController {
  @override
  final int repsTarget;
  @override
  final int romTargetPercent;
  final math.Random _random;

  final SensorFusion _fusion;
  final EmgProcessor _emg;
  final AiEngine _ai;

  SessionSimulator({
    required this.repsTarget,
    required int? romTargetPercent,
    int? seed,
    SensorFusion sensorFusion = const SensorFusion(),
    EmgProcessor emgProcessor = const EmgProcessor(),
    AiEngine aiEngine = const AiEngine(),
  })  : romTargetPercent = romTargetPercent ?? 80,
        _random = math.Random(seed),
        _fusion = sensorFusion,
        _emg = emgProcessor,
        _ai = aiEngine;

  // Fixed for the life of the session, so the journal and every upload
  // retry refer to the same rows.
  final String sessionId = uuidV4();
  final String analysisId = uuidV4();
  final DateTime startedAt = DateTime.now();

  static const _tick = Duration(milliseconds: 80);
  static const _repDuration = Duration(milliseconds: 2800);

  Timer? _timer;
  final _stopwatch = Stopwatch();

  bool _running = false;
  @override
  bool get isRunning => _running;

  bool _awaitingUnsafeAck = false;
  @override
  bool get awaitingUnsafeAck => _awaitingUnsafeAck;

  bool _fatiguePauseOffered = false;
  @override
  bool get fatiguePauseOffered => _fatiguePauseOffered;

  Duration _repElapsed = Duration.zero;
  SafetyTier _repTier = SafetyTier.normal;

  @override
  int repsCompleted = 0;
  @override
  int liveAngle = 0; // this session's rough joint-angle/ROM% readout — see Home's same approximation
  int peakAngle = 0;
  @override
  MuscleActivation activation = MuscleActivation.resting;
  // The activation reading at the same tick as the current peakAngle — the
  // two are reported together on Home (Rule 1: no metric with no source).
  MuscleActivation peakActivation = MuscleActivation.resting;
  @override
  SafetyTier currentTier = SafetyTier.normal;
  SafetyTier worstTier = SafetyTier.normal;
  double fatigueScore = 0; // 0..1
  @override
  FatigueLevel get fatigueLevel => EmgProcessor.levelOf(fatigueScore);
  FatigueLevel peakFatigue = FatigueLevel.normal;

  final List<SessionAlert> alerts = [];

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  void start() {
    if (_running) return;
    _running = true;
    _stopwatch.start();
    _timer = Timer.periodic(_tick, (_) => _onTick());
  }

  @override
  void pause() {
    _running = false;
    _stopwatch.stop();
    _timer?.cancel();
    // Cleared so resume() starts a fresh timer — a cancelled Timer is not
    // null, and `??=` would otherwise leave the session frozen for good.
    _timer = null;
    notifyListeners();
  }

  @override
  void resume() {
    if (repsCompleted >= repsTarget) return;
    _running = true;
    _stopwatch.start();
    _timer ??= Timer.periodic(_tick, (_) => _onTick());
    notifyListeners();
  }

  /// The patient acknowledged an "unsafe" banner — resumes rep counting.
  @override
  void acknowledgeUnsafe() {
    _awaitingUnsafeAck = false;
    resume();
  }

  /// The patient chose [Resume] on the fatigue-pause dialog (Rule 19 —
  /// offered, not silently forced). Fatigue eases back so it doesn't
  /// immediately re-trigger.
  @override
  void acknowledgeFatiguePause() {
    _fatiguePauseOffered = false;
    fatigueScore = 0.55;
    resume();
  }

  void _onTick() {
    if (repsCompleted >= repsTarget) {
      pause();
      return;
    }

    _repElapsed += _tick;
    final phase = _fusion.phaseOf(_repElapsed, _repDuration);
    liveAngle = _fusion.angleAtPhase(phase, romTargetPercent);
    activation = _emg.activationAtPhase(phase);
    if (liveAngle >= peakAngle) {
      peakAngle = liveAngle;
      peakActivation = activation;
    }
    currentTier = _repTier;

    if (_repElapsed >= _repDuration) {
      repsCompleted += 1;
      _repElapsed = Duration.zero;
      _applyRepOutcome();
    }

    if (fatigueLevel == FatigueLevel.critical && !_fatiguePauseOffered) {
      _fatiguePauseOffered = true;
      pause();
      return;
    }

    notifyListeners();
  }

  void _applyRepOutcome() {
    // Fatigue builds per rep, not per tick (per-tick hit "critical" ~6s into
    // every session): ~5 reps to mild, ~10 to moderate, ~14 to critical.
    fatigueScore = (fatigueScore + _emg.fatigueIncrement(_random)).clamp(0.0, 1.0);
    if (fatigueLevel.index > peakFatigue.index) peakFatigue = fatigueLevel;

    final assessment = _ai.assessRep(_random);
    _repTier = assessment.tier;

    // Shown immediately — an "unsafe" rep pauses below, so waiting for the
    // next tick would leave the banner (and its acknowledge button) hidden.
    currentTier = _repTier;
    if (_repTier.index > worstTier.index) worstTier = _repTier;

    if (assessment.alert != null) alerts.add(assessment.alert!);
    if (_repTier == SafetyTier.unsafe) {
      _awaitingUnsafeAck = true;
      pause();
    }
  }

  @override
  SessionResult buildResult(AssignedExercise exercise) {
    return SessionResult(
      id: sessionId,
      analysisId: analysisId,
      startedAt: startedAt,
      exercise: exercise,
      repsCompleted: repsCompleted,
      romAchieved: (peakAngle).clamp(0, 100),
      peakJointAngle: peakAngle,
      achievedRangeDegrees: peakAngle,
      peakActivation: peakActivation,
      duration: elapsed,
      peakFatigue: peakFatigue,
      worstTier: worstTier,
      alerts: List.unmodifiable(alerts),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
