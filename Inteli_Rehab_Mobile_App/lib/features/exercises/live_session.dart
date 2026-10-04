import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/util/uuid.dart';
import '../home/ble/arm_band_protocol.dart';
import 'exercises_models.dart';
import 'processing/ai_engine.dart' show RepAssessment;
import 'processing/elbow_rep_checker.dart';
import 'processing/emg_processor.dart';
import 'processing/fatigue_estimator.dart';
import 'processing/rep_assessor.dart';
import 'processing/safety_monitor.dart';
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
///  * three states of feedback:
///      green - the rep was fine;
///      amber - needs correction: the trained model's check ([ElbowRepChecker]),
///        reported a moment after the arm comes back down (it cannot stop a
///        movement in progress). With no model loaded, the simple [RepAssessor]
///        rules judge each rep instead;
///      red - stop: [SafetyMonitor] watches every sample live (angle and speed
///        limits held over a short window) and pauses the session at once;
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

  /// The model's amber check after each rep. Null when the model is not available.
  final ElbowRepChecker? _checker;

  /// The red, live stop rules.
  final SafetyMonitor _safety;
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

  /// Past this many degrees beyond full range is the (placeholder) red angle limit; see [SafetyLimits].
  static const _overFlexMarginDeg = 10.0;

  /// The model looks at a rep from where the arm was last down to where it is down again.
  static const _modelRestDeg = 8.0;
  static const _leadInSeconds = 1.5;

  /// After a rep the model waits this long for the arm to finish coming down, then judges what it has.
  static const _pendingGrace = Duration(milliseconds: 600);

  /// How much recent angle history is kept for the model.
  static const _bufferSeconds = 20.0;

  static const _minRep = Duration(milliseconds: 500);

  LiveSession({
    required this.repsTarget,
    required int? romTargetPercent,
    required Stream<ArmBandSample> samples,
    this.fullRangeDegrees = 150,
    RepAssessor assessor = const RepAssessor(),
    ElbowRepChecker? checker,
    SafetyLimits? limits,
    DateTime Function()? clock,
  })  : romTargetPercent = romTargetPercent ?? 80,
        _assessor = assessor,
        _checker = checker ?? ElbowRepChecker.cached,
        _safety = SafetyMonitor(limits ?? SafetyLimits(maxAngleDeg: fullRangeDegrees + _overFlexMarginDeg)),
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

  /// What to tell the patient for the current amber/red state (null while everything is fine).
  @override
  String? currentMessage;

  /// A soft note about the last rep (e.g. it was slow); never a failure.
  @override
  String? repHint;

  /// The last rep has been counted but the model has not judged it yet (well under a second).
  @override
  bool get hasPendingCheck => _pending != null;
  _PendingCheck? _pending;
  Timer? _pendingTimer;
  final List<RepSample> _buf = [];

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
    _safety.reset();
    _atRest = true;
    _repFlagged = false;
    _lastAt = null;
    _smoothedVelocity = 0;
  }

  /// One reading from the band. Public so tests can drive it directly;
  /// in the app it's fed by the sample stream.
  void onSample(ArmBandSample s, DateTime now) {
    if (!s.elbowDeg.isFinite) return;
    final angle = math.max(0.0, s.elbowDeg);
    if (_checker != null) {
      _buffer(angle, now);
      _advancePending(angle, now); // carries on while paused, e.g. right after the last rep
    }
    if (!_running) return;
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
      _safety.reset();
      if (angle > restDeg) {
        _finalizePending(); // a new rep is starting: judge the last one with what there is
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

      final violation = _safety.update(angle: angle, speed: speed, now: now);
      if (violation != null && !_repFlagged) {
        _repFlagged = true;
        _safety.reset();
        _raiseUnsafe(
          now,
          violation == SafetyViolation.angle
              ? 'Your elbow went past a safe range - pause and reset your form.'
              : 'Potentially unsafe movement - pause and reset your form.',
        );
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

    // With the model loaded it judges the rep a moment later (_finalizePending); until then the
    // rep stands as fine. Without it, the simple rules judge it straight away.
    final assessment = _checker != null
        ? const RepAssessment(tier: SafetyTier.normal, alert: null)
        : _assessor.assess(
            RepMetrics(
              peakDegrees: _repPeak,
              targetDegrees: target,
              peakSpeedDegPerSec: _repMaxSpeed,
              duration: duration,
            ),
            now,
          );
    _record(assessment.tier, assessment.alert);
    if (_checker != null) _startPending(now);

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
    currentMessage = tier == SafetyTier.normal ? null : alert?.message;
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

  // ---- the model check (amber) -----------------------------------------------------------------

  /// Keeps the recent angle history: the lead-in to a rep and its return are both needed.
  void _buffer(double angle, DateTime now) {
    final t = now.microsecondsSinceEpoch / 1e6;
    _buf.add(RepSample(t, angle));
    var drop = 0;
    while (drop < _buf.length - 1 && t - _buf[drop].t > _bufferSeconds) {
      drop++;
    }
    if (drop > 0) _buf.removeRange(0, drop);
  }

  void _startPending(DateTime endedAt) {
    _pending = _PendingCheck(start: _repStart, endedAt: endedAt);
    _pendingTimer?.cancel();
    // If the band goes quiet, still judge the rep from what has been seen.
    _pendingTimer = Timer(_pendingGrace * 2, _finalizePending);
  }

  void _advancePending(double angle, DateTime now) {
    final p = _pending;
    if (p == null) return;
    final settled = angle <= _modelRestDeg && now.isAfter(p.endedAt);
    if (settled || now.difference(p.endedAt) >= _pendingGrace) _finalizePending();
  }

  /// Judges the rep that just ended with the model: amber if it looked different from a healthy rep.
  void _finalizePending() {
    final p = _pending;
    if (p == null) return;
    _pending = null;
    _pendingTimer?.cancel();
    _pendingTimer = null;
    final checker = _checker;
    if (checker == null) return;

    final startT = p.start.microsecondsSinceEpoch / 1e6;
    final endT = p.endedAt.microsecondsSinceEpoch / 1e6;
    var i = _buf.indexWhere((s) => s.t >= startT);
    if (i < 0) return;
    // Back to where the arm was last down, so the rep starts from rest as the model's training reps did.
    while (i > 0 && _buf[i].angle > _modelRestDeg && startT - _buf[i - 1].t < _leadInSeconds) {
      i--;
    }
    // On to where the arm is down again, or as far as there is.
    var j = _buf.length - 1;
    for (var k = i; k < _buf.length; k++) {
      if (_buf[k].t >= endT && _buf[k].angle <= _modelRestDeg) {
        j = k;
        break;
      }
    }

    final check = checker.check(_buf.sublist(i, j + 1));
    if (check == null) return;
    repHint = check.hint;
    if (!check.ok) {
      _record(
        SafetyTier.needsCorrection,
        SessionAlert(id: uuidV4(), tier: SafetyTier.needsCorrection, message: check.message!, at: _clock()),
      );
    }
    notifyListeners();
  }

  @override
  SessionResult buildResult(AssignedExercise exercise) {
    _finalizePending(); // the last rep's verdict belongs in the result
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
    _pendingTimer?.cancel();
    super.dispose();
  }
}

/// A counted rep waiting a moment for the arm to finish coming down before the model judges it.
class _PendingCheck {
  final DateTime start;
  final DateTime endedAt;
  const _PendingCheck({required this.start, required this.endedAt});
}
