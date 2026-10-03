import 'dart:math' as math;

/// Running fatigue score (0..1) from what the band actually measures.
///
/// Two signs of fatigue in repeated dynamic movement, compared with the
/// patient's own first few reps (so no absolute thresholds are assumed):
///  * muscle effort for the same movement rises (EMG amplitude, %MVC);
///  * the movement slows down.
/// The first [baselineReps] reps only learn the baseline; the score starts
/// moving after that. It is an amplitude/speed heuristic - true EMG
/// fatigue analysis uses frequency content, which the band doesn't send -
/// so treat it as a trend, not a measurement. Without an EMG calibration
/// (all readings ~0) it degrades gracefully to speed alone.
class FatigueEstimator {
  static const baselineReps = 3;

  /// A 50% rise in EMG vs baseline counts as the full EMG contribution.
  static const _emgFullRise = 0.5;

  /// A 40% drop in speed vs baseline counts as the full speed contribution.
  static const _speedFullDrop = 0.4;

  final _baselineEmg = <double>[];
  final _baselineSpeed = <double>[];
  double _score = 0;

  double get score => _score;

  /// Records one completed rep; returns the updated score.
  double addRep({required double meanEmgPct, required double peakSpeedDegPerSec}) {
    if (_baselineEmg.length < baselineReps) {
      _baselineEmg.add(meanEmgPct);
      _baselineSpeed.add(peakSpeedDegPerSec);
      return _score;
    }
    final baseEmg = _mean(_baselineEmg);
    final baseSpeed = _mean(_baselineSpeed);

    final emgRise = ((meanEmgPct - baseEmg) / math.max(baseEmg, 5) / _emgFullRise).clamp(0.0, 1.0);
    final speedDrop =
        baseSpeed <= 0 ? 0.0 : ((1 - peakSpeedDegPerSec / baseSpeed) / _speedFullDrop).clamp(0.0, 1.0);

    final raw = 0.6 * emgRise + 0.4 * speedDrop;
    _score = (0.5 * _score + 0.5 * raw).clamp(0.0, 1.0);
    return _score;
  }

  /// The patient chose to carry on after a fatigue pause: ease the score
  /// back so it doesn't re-trigger on the very next rep.
  void easeBack([double to = 0.55]) => _score = math.min(_score, to);

  static double _mean(List<double> v) => v.reduce((a, b) => a + b) / v.length;
}
