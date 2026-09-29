/// One exercise assignment (patient_exercise_plans, joined to exercises)
/// and whether it's already been done today.
class ExerciseAssignment {
  final String exerciseId;
  final String exerciseName;
  final int? romTarget;
  final bool doneToday;

  const ExerciseAssignment({
    required this.exerciseId,
    required this.exerciseName,
    required this.romTarget,
    required this.doneToday,
  });
}

/// The active rehabilitation_plans row plus today's standing against it.
/// [planName] falls back to a generic label when the physio assigned
/// exercises without naming a plan (rehabilitation_plans.plan_name is
/// nullable) or without a rehabilitation_plans row at all.
class TodaysPlan {
  final String planName;
  final List<ExerciseAssignment> exercises;

  const TodaysPlan({required this.planName, required this.exercises});

  int get remaining => exercises.where((e) => !e.doneToday).length;
}

/// The most recent real exercise session (onboarding's baseline
/// calibration is excluded — see HomeRepository._isBaseline).
class LastSessionSnapshot {
  final DateTime performedAt;
  final String exerciseName;
  final int rom;
  final int? romTarget;
  final int reps;
  // Both from movement_analysis, and both nullable: only sessions saved
  // after supabase_movement_analysis_activation.sql (muscle_activation) or
  // with a real joint_angle reading have them — an older row just omits
  // the metric rather than showing a fabricated one.
  final int? jointAngle;
  final String? muscleActivation;

  const LastSessionSnapshot({
    required this.performedAt,
    required this.exerciseName,
    required this.rom,
    required this.romTarget,
    required this.reps,
    this.jointAngle,
    this.muscleActivation,
  });
}

/// The onboarding calibration reading (OnboardingRepository.saveBaseline) —
/// in degrees, unlike sessions.rom which is a %. Used as the digital twin's
/// fallback pose/metrics before the patient has a real exercise session.
class BaselineReading {
  final double flexion;
  final double range;
  final DateTime recordedAt;

  const BaselineReading({required this.flexion, required this.range, required this.recordedAt});
}

/// Everything the Home screen needs in one fetch.
class HomeSnapshot {
  final TodaysPlan? plan;
  final LastSessionSnapshot? lastSession;
  final BaselineReading? baseline;
  final bool wearablePaired;
  final String? deviceSerial;
  final String motivation;
  final int sessionsThisWeek;
  final int currentStreak;

  const HomeSnapshot({
    required this.plan,
    required this.lastSession,
    required this.baseline,
    required this.wearablePaired,
    required this.deviceSerial,
    required this.motivation,
    required this.sessionsThisWeek,
    required this.currentStreak,
  });
}
