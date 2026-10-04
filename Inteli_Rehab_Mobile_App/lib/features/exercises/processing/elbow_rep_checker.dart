import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'elbow_autoencoder.dart';

/// One reading of the elbow angle: seconds (any fixed origin) and degrees.
class RepSample {
  final double t;
  final double angle;
  const RepSample(this.t, this.angle);
}

/// How strict the check is. The notebook's test patients showed [gentle] works better for everyone:
/// [balanced] adds mostly false alarms (e.g. 18 of 35 correct wheelchair reps flagged against 6 with gentle).
/// Keep [balanced] as a clinician-only setting, not something patients choose.
enum RepCheckMode { gentle, balanced }

/// The verdict on one finished rep.
class RepCheck {
  /// The rebuild error (normalised units) and the threshold it was compared with.
  final double score;
  final double threshold;
  final double durationSeconds;

  /// The rep as the model saw it, and what a healthy rep "should" have looked like, in degrees.
  final List<double> angle;
  final List<double> rebuilt;

  /// What to tell the patient when the rep looks different from a healthy one (null = fine).
  final String? message;

  /// A soft, non-blaming note (a slow rep). Never fails the rep: patients' correct reps are slower
  /// than healthy ones (median 2.17 s against 1.6 s), and slowness can mean weakness, not bad form.
  final String? hint;

  const RepCheck({
    required this.score,
    required this.threshold,
    required this.durationSeconds,
    required this.angle,
    required this.rebuilt,
    required this.message,
    required this.hint,
  });

  bool get ok => message == null;
}

/// Amber check: after each rep, decides whether it looked like a healthy rep, using the trained model.
/// This is advice reported shortly after the arm comes back down - it cannot stop a movement in
/// progress. That is the job of [SafetyMonitor] (the red, live rule check).
class ElbowRepChecker {
  final ElbowAutoencoder model;
  final RepCheckMode mode;

  /// A rep shorter than this, or with fewer samples, is too little to judge.
  static const minDurationSeconds = 0.4;
  static const minSamples = 6;

  const ElbowRepChecker(this.model, {this.mode = RepCheckMode.gentle});

  double get threshold => mode == RepCheckMode.gentle ? model.thresholdGentle : model.thresholdBalanced;

  // ---- loading ----------------------------------------------------------------------------------

  static const assetPath = 'assets/ai/elbow_autoencoder.json';

  /// Set by [preload]; read by live sessions. Null until loaded (or if it cannot load), in which case
  /// a session falls back to its simple rules and carries on.
  static ElbowRepChecker? cached;

  /// Loads the model once, in the background. Never throws: a missing or damaged file just leaves
  /// [cached] null.
  static Future<ElbowRepChecker?> preload({AssetBundle? bundle, RepCheckMode mode = RepCheckMode.gentle}) async {
    if (cached != null) return cached;
    try {
      final text = await (bundle ?? rootBundle).loadString(assetPath);
      cached = ElbowRepChecker(ElbowAutoencoder.fromJson(text), mode: mode);
    } catch (e) {
      debugPrint('Elbow model not loaded, using the simple rep rules instead: $e');
    }
    return cached;
  }

  // ---- checking a rep ---------------------------------------------------------------------------

  /// Judges one rep given the angle readings from just before it started to just after it ended.
  /// Returns null if there is too little to judge.
  RepCheck? check(List<RepSample> samples) {
    if (samples.length < minSamples) return null;
    final duration = samples.last.t - samples.first.t;
    if (!(duration >= minDurationSeconds) || !duration.isFinite) return null;

    final curve = resample(samples, model.steps);
    final scored = model.score(curve, duration);
    final flagged = scored.score > threshold;
    final (_, slowAbove) = model.healthyDuration;

    return RepCheck(
      score: scored.score,
      threshold: threshold,
      durationSeconds: duration,
      angle: curve,
      rebuilt: scored.rebuiltDegrees,
      message: flagged ? _explain(curve, scored.rebuiltDegrees) : null,
      hint: duration > slowAbove ? 'That rep was slow. A steady pace is fine if it is comfortable.' : null,
    );
  }

  /// The readings spread evenly over the rep's time to exactly [n] points (linear interpolation).
  static List<double> resample(List<RepSample> s, int n) {
    final t0 = s.first.t, t1 = s.last.t;
    final out = List<double>.filled(n, 0);
    var j = 0;
    for (var i = 0; i < n; i++) {
      final t = t0 + (t1 - t0) * i / (n - 1);
      while (j < s.length - 2 && s[j + 1].t < t) {
        j++;
      }
      final a = s[j], b = s[j + 1];
      final span = b.t - a.t;
      final f = span <= 0 ? 0.0 : ((t - a.t) / span).clamp(0.0, 1.0);
      out[i] = a.angle + (b.angle - a.angle) * f;
    }
    return out;
  }

  /// Plain-language advice from how the rep differs from the rebuilt healthy curve. These are rules on
  /// top of the model's rebuild, not clinical advice.
  String _explain(List<double> actual, List<double> rebuilt) {
    final tol = model.tolerance;
    double mean(List<double> v, int a, int b) => v.sublist(a, b).reduce((x, y) => x + y) / (b - a);

    // The arm did not come all the way back down.
    if (mean(actual, 88, 100) - mean(rebuilt, 88, 100) > mean(tol, 88, 100)) {
      return 'Lower your arm all the way down at the end of each rep.';
    }
    // Peak compared with the rebuilt peak.
    final peak = actual.reduce(math.max);
    final peakAt = rebuilt.indexOf(rebuilt.reduce(math.max));
    final tolAtPeak = mean(tol, math.max(0, peakAt - 3), math.min(100, peakAt + 4));
    final rebuiltPeak = rebuilt[peakAt];
    if (peak < rebuiltPeak - tolAtPeak) return 'Try to bend a little further.';
    if (peak > rebuiltPeak + tolAtPeak) return 'You went higher than needed. Bend only as far as is comfortable.';
    // The start was not from a relaxed, lowered arm.
    if (mean(actual, 0, 12) - mean(rebuilt, 0, 12) > mean(tol, 0, 12)) {
      return 'Start each rep with your arm fully lowered.';
    }
    return 'That rep looked different from a typical one. Move smoothly: bend, then straighten, at a steady pace.';
  }
}
