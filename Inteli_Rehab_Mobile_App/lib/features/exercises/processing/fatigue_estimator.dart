import 'dart:math' as math;

/// Running fatigue score (0..1) from what the band actually measures.
///
/// Two signs of fatigue in repeated dynamic movement, compared with the
/// patient's own early reps (so no absolute thresholds are assumed):
///  * muscle effort for the same movement rises (EMG amplitude, %MVC);
///  * the movement slows down.
/// The first [warmupReps] rep is ignored (people start stiff or hesitant), the next [baselineReps]
/// only learn the baseline (their median, so one odd rep cannot skew it), and the score starts
/// moving after that. It is an amplitude/speed heuristic - true EMG fatigue analysis uses frequency
/// content, which the band doesn't send - so treat it as a trend, not a measurement.
///
/// Without an EMG calibration (baseline readings ~0) there is only speed to go on, and slowing down
/// is also what the patient is told to do when a rep was too fast. So in that case ([speedOnly])
/// the score needs a bigger slowdown and is capped below "critical": it can show fatigue, but it
/// can never stop the session by itself.
class FatigueEstimator {
  static const warmupReps = 1;
  static const baselineReps = 3;

  /// A 50% rise in EMG vs baseline counts as the full EMG contribution.
  static const _emgFullRise = 0.5;

  /// A 40% drop in speed vs baseline counts as the full speed contribution (60% when speed is all
  /// there is).
  static const _speedFullDrop = 0.4;
  static const _speedOnlyFullDrop = 0.6;

  /// The most a speed-only score can reach (below the 0.9 "critical" level).
  static const speedOnlyCap = 0.8;

  /// A baseline EMG below this %MVC means the muscle sensor was not calibrated (or not on the muscle).
  static const _emgUsableBaseline = 3.0;

  int _seen = 0;
  final _baselineEmg = <double>[];
  final _baselineSpeed = <double>[];
  double _score = 0;

  double get score => _score;

  /// True once the baseline is learned and it showed no usable EMG signal.
  bool get speedOnly => _baselineEmg.length >= baselineReps && _median(_baselineEmg) < _emgUsableBaseline;

  /// Records one completed rep; returns the updated score.
  double addRep({required double meanEmgPct, required double peakSpeedDegPerSec}) {
    if (_seen < warmupReps) {
      _seen++;
      return _score;
    }
    if (_baselineEmg.length < baselineReps) {
      _baselineEmg.add(meanEmgPct);
      _baselineSpeed.add(peakSpeedDegPerSec);
      return _score;
    }
    final baseEmg = _median(_baselineEmg);
    final baseSpeed = _median(_baselineSpeed);
    final speedOnlyMode = baseEmg < _emgUsableBaseline;

    final speedDrop = baseSpeed <= 0
        ? 0.0
        : ((1 - peakSpeedDegPerSec / baseSpeed) / (speedOnlyMode ? _speedOnlyFullDrop : _speedFullDrop))
            .clamp(0.0, 1.0);

    final double raw;
    if (speedOnlyMode) {
      raw = speedDrop * speedOnlyCap;
    } else {
      final emgRise = ((meanEmgPct - baseEmg) / math.max(baseEmg, 5) / _emgFullRise).clamp(0.0, 1.0);
      raw = 0.6 * emgRise + 0.4 * speedDrop;
    }
    _score = (0.5 * _score + 0.5 * raw).clamp(0.0, 1.0);
    return _score;
  }

  /// The patient chose to carry on after a fatigue pause: ease the score
  /// back so it doesn't re-trigger on the very next rep.
  void easeBack([double to = 0.55]) => _score = math.min(_score, to);

  static double _median(List<double> v) {
    final s = [...v]..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
  }
}
