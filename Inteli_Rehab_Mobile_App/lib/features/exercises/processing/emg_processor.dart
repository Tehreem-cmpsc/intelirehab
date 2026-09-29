import 'dart:math' as math;

import '../exercises_models.dart';

/// Intelligence & Processing Layer — EMG Processor (SDD §3.1.3).
///
/// On real hardware this reads the biceps/triceps electrodes
/// (firmware/lib/EMGProcessor.cpp does the on-device filtering) and turns
/// muscle activity into two things the app shows: activation level (the
/// Blue→Green→Orange→Red bar) and a running fatigue score. No EMG hardware
/// is wired up yet, so both are derived from the rep's motion phase and
/// elapsed reps instead of real electrode data — kept as their own class so
/// this is a swap-in point, not logic buried in the session orchestrator.
class EmgProcessor {
  const EmgProcessor();

  /// Activation follows how far into the lift the patient is — resting at
  /// the start, highest effort near the peak.
  MuscleActivation activationAtPhase(double repPhase) => switch (repPhase) {
        < 0.15 => MuscleActivation.resting,
        < 0.45 => MuscleActivation.light,
        < 0.8 => MuscleActivation.moderate,
        _ => MuscleActivation.high,
      };

  /// How much the fatigue score (0..1) rises after one completed rep.
  /// Tuned so it takes ~5 reps to reach "mild", ~10 to "moderate", ~14 to
  /// "critical" — a real EMG signal's amplitude decay would set this
  /// instead of a fixed-plus-random step.
  double fatigueIncrement(math.Random random) => 0.04 + random.nextDouble() * 0.05;

  static FatigueLevel levelOf(double score) {
    if (score >= 0.9) return FatigueLevel.critical;
    if (score >= 0.65) return FatigueLevel.moderate;
    if (score >= 0.35) return FatigueLevel.mild;
    return FatigueLevel.normal;
  }
}
