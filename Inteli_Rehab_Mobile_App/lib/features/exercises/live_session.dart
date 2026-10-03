import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/util/uuid.dart';
import '../home/ble/arm_band_protocol.dart';
import 'exercises_models.dart';
import 'processing/emg_processor.dart';
import 'processing/fatigue_estimator.dart';
import 'processing/rep_assessor.dart';
import 'session_controller.dart';

/// Drives the Active Session screen from the REAL band: elbow angle and EMG
/// off the Bluetooth stream (~31 Hz), replacing [SessionSimulator]'s timer.
///
/// What it does with each sample:
///  * live joint angle and muscle activation for the digital twin / bars;
///  * rep counting - a rep is a lift away from rest that reaches at least
///    [_countFraction] of the target angle and returns to rest. Smaller
///    movements are ignored or, if a clear attempt, prompted ("move further")
///    without counting;
///  * a per-rep safety call ([RepAssessor]) plus an immediate stop if the
///    elbow goes past a safe range;
///  * a running fatigue estimate ([FatigueEstimator]).
///
/// The angle is relative to the band's zero pose, so the patient must have
/// set it (ArmBandCommand.setZeroPose) before [start]. "Full range" defaults
/// to 150 degrees, a typical elbow flexion range; pass the patient's own
/// when known.
class LiveSession extends ChangeNotifier implements SessionController {
  @override
  final int repsTarget;
  @override
  final int romTargetPercent;
  final double fullRangeDegrees;

  final RepAssessor _assessor;
  final FatigueEstimator _fatigue = FatigueEstimator();
  final DateTime Function() _clock;
  StreamSubscription<ArmBandSample>? _sub;

  /// Below this fraction of the target the arm counts as at rest.
  static const _restFraction = 0.15;

  /// A lift must reach this fraction of the target to count as a rep.
  static const _countFraction = 0.5;

  /// A lift reaching at least this much (but not enough to count) gets a
  /// "move further" prompt instead of being silently ignored.
  static const _attemptFraction = 0.25;

  /// Past this many degrees beyond full range, stop immediately.
  static const _overFlexMarginDeg = 10.0;

  static const _minRep = Duration(milliseconds: 500);

  LiveSession({
    required this.repsTarget,
    required int? romTargetPercent,
    required Stream<ArmBandSample> samples,
    this.fullRangeDegrees = 150,
    RepAssessor assessor = const RepAssessor(),
    DateTime Function()? clock,
  })  : romTargetPercent = romTargetPercent ?? 80,
        _assessor = assessor,
        _clock = clock ?? DateTime.now {
    _sub = samples.listen((s) => onSample(s, _clock()));
  }

  // Fixed for the life of the session, so the journal and every upload
  // retry refer to the same rows.
  final String sessionId = uuidV4();
  final String analysisId = uuidV4();
  /// When the patient actually started (set at the first [start]), not when the
  /// screen was built - the "Get ready" step must not count as exercise time.
  DateTime startedAt = DateTime.now();
  bool _started = false;

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

  @override
  int repsCompleted = 0;
  @override
  int liveAngle = 0; // % of full range
  @override
  MuscleActivation activation = MuscleActivation.resting;
  @override
  SafetyTier currentTier = SafetyTier.normal;
  SafetyTier worstTier = SafetyTier.normal;
  FatigueLevel peakFatigue = FatigueLevel.normal;
  @override
  FatigueLevel get fatigueLevel => EmgProcessor.levelOf(_fatigue.score);
  final List<SessionAlert> alerts = [];

  @override
  Duration get elapsed => _stopwatch.elapsed;

  // Session-wide extremes, for the saved result.
  double _peakDeg = 0;
  double _minDeg = double.infinity;
  MuscleActivation peakActivation = MuscleActivation.resting;

  // Sample-to-sample state.
  DateTime? _lastAt;
  double _lastAngle = 0;
  double _smoothedVelocity = 0;

  // The rep in progress.
  bool _atRest = true;
  DateTime _repStart = DateTime.fromMillisecondsSinceEpoch(0);
  double _repPeak = 0;
  double _repMaxSpeed = 0;
  double _repEmgSum = 0;
  int _repEmgCount = 0;
  bool _repFlagged = false;

  double get _targetDegrees => fullRangeDegrees * romTargetPercent / 100;

  @override
  void start() {
    if (_running) return;
    if (!_started) {
      _started = true;
      startedAt = _clock();
    }
    _running = true;
    _stopwatch.start();
    _resetRep();
  }

  @override
  void pause() {
    _running = false;
    _stopwatch.stop();
    notifyListeners();
  }

  @override
  void resume() {
    if (repsCompleted >= repsTarget) {
      // All reps are done (e.g. the last one was flagged unsafe): nothing to
      // resume, but the screen must be told so it can finish the session.
      notifyListeners();
      return;
    }
    _running = true;
    _stopwatch.start();
    _resetRep(); // whatever was half-done before the pause isn't a rep
    notifyListeners();
  }

  @override
  void acknowledgeUnsafe() {
    _awaitingUnsafeAck = false;
    resume();
  }

  @override
  void acknowledgeFatiguePause() {
    _fatiguePauseOffered = false;
    _fatigue.easeBack();
    resume();
  }

  void _resetRep() {
    _atRest = true;
    _repFlagged = false;
    _lastAt = null;
    _smoothedVelocity = 0;
  }

  /// One reading from the band. Public so tests can drive it directly;
  /// in the app it's fed by the sample stream.
  void onSample(ArmBandSample s, DateTime now) {
    if (!_running || !s.elbowDeg.isFinite) return;
    final angle = math.max(0.0, s.elbowDeg);
    final emg = s.emg1Pct.isFinite ? s.emg1Pct.clamp(0.0, 100.0) : 0.0;

    // Smoothed angular speed (deg/s) - the band's angle is already filtered
    // on-device, this just steadies the sample-to-sample difference.
    var speed = 0.0;
    final lastAt = _lastAt;
    if (lastAt != null) {
      final dt = now.difference(lastAt).inMicroseconds / 1e6;
      if (dt > 0.005 && dt < 1.0) {
        _smoothedVelocity = 0.6 * _smoothedVelocity + 0.4 * ((angle - _lastAngle) / dt);
        speed = _smoothedVelocity.abs();
      }
    }
    _lastAt = now;
    _lastAngle = angle;

    liveAngle = (angle / fullRangeDegrees * 100).round().clamp(0, 100);
    activation = activationOf(emg);
    if (angle > _peakDeg) {
      _peakDeg = angle;
      peakActivation = activation;
    }
    if (angle < _minDeg) _minDeg = angle;

    final restDeg = math.max(_targetDegrees * _restFraction, 8.0);
    if (_atRest) {
      if (angle > restDeg) {
        _atRest = false;
        _repStart = now;
        _repPeak = angle;
        _repMaxSpeed = speed;
        _repEmgSum = emg;
        _repEmgCount = 1;
        _repFlagged = false;
      }
    } else {
      _repPeak = math.max(_repPeak, angle);
      _repMaxSpeed = math.max(_repMaxSpeed, speed);
      _repEmgSum += emg;
      _repEmgCount++;

      if (angle > fullRangeDegrees + _overFlexMarginDeg && !_repFlagged) {
        _repFlagged = true;
        _raiseUnsafe(now, 'Your elbow went past a safe range - pause and reset your form.');
        return;
      }
      if (angle <= restDeg) {
        _atRest = true;
        _finishRep(now);
      }
    }
    notifyListeners();
  }

  void _finishRep(DateTime now) {
    final duration = now.difference(_repStart);
    final target = _targetDegrees;
    if (duration < _minRep || _repPeak < target * _attemptFraction) return; // a twitch, not an attempt

    if (_repPeak < target * _countFraction) {
      // A clear attempt that didn't get far enough: prompt, don't count.
      _record(
        SafetyTier.needsCorrection,
        SessionAlert(
          id: uuidV4(),
          tier: SafetyTier.needsCorrection,
          message: 'Try to move through more of your range.',
          at: now,
        ),
      );
      return;
    }

    repsCompleted += 1;
    _fatigue.addRep(
      meanEmgPct: _repEmgCount == 0 ? 0 : _repEmgSum / _repEmgCount,
      peakSpeedDegPerSec: _repMaxSpeed,
    );
    if (fatigueLevel.index > peakFatigue.index) peakFatigue = fatigueLevel;

    final assessment = _assessor.assess(
      RepMetrics(
        peakDegrees: _repPeak,
        targetDegrees: target,
        peakSpeedDegPerSec: _repMaxSpeed,
        duration: duration,
      ),
      now,
    );
    _record(assessment.tier, assessment.alert);

    if (assessment.tier == SafetyTier.unsafe) {
      _awaitingUnsafeAck = true;
      pause();
    } else if (repsCompleted >= repsTarget) {
      pause();
    } else if (fatigueLevel == FatigueLevel.critical && !_fatiguePauseOffered) {
      _fatiguePauseOffered = true;
      pause();
    }
  }

  void _record(SafetyTier tier, SessionAlert? alert) {
    currentTier = tier;
    if (tier.index > worstTier.index) worstTier = tier;
    if (alert != null) alerts.add(alert);
  }

  void _raiseUnsafe(DateTime now, String message) {
    _record(SafetyTier.unsafe, SessionAlert(id: uuidV4(), tier: SafetyTier.unsafe, message: message, at: now));
    _awaitingUnsafeAck = true;
    pause();
  }

  /// Blue -> Green -> Orange -> Red bar, from the EMG channel
  /// (%MVC; meaningful once an MVC calibration has been run).
  static MuscleActivation activationOf(double emgPct) {
    if (emgPct < 10) return MuscleActivation.resting;
    if (emgPct < 30) return MuscleActivation.light;
    if (emgPct < 60) return MuscleActivation.moderate;
    return MuscleActivation.high;
  }

  @override
  SessionResult buildResult(AssignedExercise exercise) {
    final peakRomPct = (_peakDeg / fullRangeDegrees * 100).round().clamp(0, 100);
    final range = _minDeg.isFinite ? math.max(0.0, _peakDeg - _minDeg) : 0.0;
    return SessionResult(
      id: sessionId,
      analysisId: analysisId,
      startedAt: startedAt,
      exercise: exercise,
      repsCompleted: repsCompleted,
      romAchieved: peakRomPct,
      peakJointAngle: _peakDeg.round(),
      achievedRangeDegrees: range.round(),
      peakActivation: peakActivation,
      duration: elapsed,
      peakFatigue: peakFatigue,
      worstTier: worstTier,
      alerts: List.unmodifiable(alerts),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
