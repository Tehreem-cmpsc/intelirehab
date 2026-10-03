import 'dart:math' as math;

import 'onboarding_data.dart';

/// Turns the band's elbow-angle stream into the onboarding baseline:
/// where the arm rests, and how far it bends over a few slow movements.
///
/// Two phases, fed sample by sample:
///  * [addNeutral] while the patient holds still - the mean is the
///    "starting point";
///  * [addMovement] while they bend and straighten - each lift that clears
///    [minLiftDegrees] and returns to rest is one counted movement, and the
///    typical (median) peak is the "furthest" reading.
/// All thresholds are relative to the neutral reading, so it works whatever
/// the band's zero pose happened to be.
class BaselineRecorder {
  /// Movements to record.
  final int reps;

  /// A lift must rise at least this far above neutral to count.
  static const minLiftDegrees = 25.0;
  static const _startLift = 20.0; // above neutral+this = a lift has begun
  static const _endLift = 10.0; // back under neutral+this = it has ended

  BaselineRecorder({this.reps = 3});

  final _neutral = <double>[];
  double? _neutralMean;
  final _peaks = <double>[];
  double _minAngle = double.infinity;
  bool _inLift = false;
  double _liftPeak = 0;

  double _lastAngle = 0;
  double get currentAngle => _lastAngle;

  int get neutralSamples => _neutral.length;
  int get repsDetected => _peaks.length;
  bool get complete => _peaks.length >= reps;

  void addNeutral(double angle) {
    if (!angle.isFinite) return;
    _lastAngle = angle;
    _neutral.add(angle);
    _neutralMean = _neutral.reduce((a, b) => a + b) / _neutral.length;
  }

  void addMovement(double angle) {
    if (!angle.isFinite) return;
    _lastAngle = angle;
    final neutral = _neutralMean ?? 0;
    _minAngle = math.min(_minAngle, angle);

    if (!_inLift) {
      if (angle > neutral + _startLift) {
        _inLift = true;
        _liftPeak = angle;
      }
    } else {
      _liftPeak = math.max(_liftPeak, angle);
      if (angle < neutral + _endLift) {
        _inLift = false;
        if (_liftPeak >= neutral + minLiftDegrees) _peaks.add(_liftPeak);
      }
    }
  }

  /// The baseline from what's been recorded, or null if no movement was
  /// detected (nothing meaningful to save).
  BaselineReading? result() {
    if (_peaks.isEmpty || _neutralMean == null) return null;
    final sorted = [..._peaks]..sort();
    final furthest = sorted[sorted.length ~/ 2]; // median: one wild rep can't skew it
    final start = math.max(0.0, math.min(_neutralMean!, _minAngle.isFinite ? _minAngle : _neutralMean!));
    return BaselineReading(
      neutral: _neutralMean!.round(),
      flexion: furthest.round(),
      extension: start.round(),
    );
  }
}
