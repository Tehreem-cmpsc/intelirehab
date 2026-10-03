/// One exercise on the patient's active plan (patient_exercise_plans joined
/// to exercises). STATE 1/2 of the exercises flow.
class AssignedExercise {
  final String assignmentId;
  final String exerciseId;
  final String name;
  final String? target; // joint/muscle targeted
  final String difficulty;
  final String? description;

  /// Illustration/video of the movement (exercises.media_url / media_type); see ExerciseMedia.
  final String? mediaUrl;
  final String mediaType;
  final int sets;
  final int repsTarget;
  final int? romTarget;

  const AssignedExercise({
    required this.assignmentId,
    required this.exerciseId,
    required this.name,
    required this.target,
    required this.difficulty,
    required this.description,
    this.mediaUrl,
    this.mediaType = 'image',
    required this.sets,
    required this.repsTarget,
    required this.romTarget,
  });

  Map<String, dynamic> toJson() => {
        'assignmentId': assignmentId,
        'exerciseId': exerciseId,
        'name': name,
        'target': target,
        'difficulty': difficulty,
        'description': description,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'sets': sets,
        'repsTarget': repsTarget,
        'romTarget': romTarget,
      };

  factory AssignedExercise.fromJson(Map<String, dynamic> j) => AssignedExercise(
        assignmentId: j['assignmentId'] as String,
        exerciseId: j['exerciseId'] as String,
        name: j['name'] as String,
        target: j['target'] as String?,
        difficulty: j['difficulty'] as String? ?? 'Beginner',
        description: j['description'] as String?,
        mediaUrl: j['mediaUrl'] as String?,
        mediaType: j['mediaType'] as String? ?? 'image',
        sets: (j['sets'] as num).toInt(),
        repsTarget: (j['repsTarget'] as num).toInt(),
        romTarget: (j['romTarget'] as num?)?.toInt(),
      );
}

/// STATE 1's header + list.
class PlanSummary {
  final String planName;
  final String? physioName;
  final List<AssignedExercise> exercises;

  const PlanSummary({required this.planName, required this.physioName, required this.exercises});
}

enum SafetyTier { normal, needsCorrection, unsafe }

enum MuscleActivation { resting, light, moderate, high }

enum FatigueLevel { normal, mild, moderate, critical }

/// One correction/unsafe moment during a session — becomes an `alerts` row
/// and shows up factually in the Session Summary ("2 correction prompts",
/// never "2 mistakes").
class SessionAlert {
  /// Client-generated, so a retried upload doesn't duplicate the alert.
  final String id;
  final SafetyTier tier;
  final String message;
  final DateTime at;
  const SessionAlert({required this.id, required this.tier, required this.message, required this.at});

  Map<String, dynamic> toJson() => {'id': id, 'tier': tier.name, 'message': message, 'at': at.toIso8601String()};

  factory SessionAlert.fromJson(Map<String, dynamic> j) => SessionAlert(
        id: j['id'] as String,
        tier: SafetyTier.values.byName(j['tier'] as String),
        message: j['message'] as String,
        at: DateTime.parse(j['at'] as String),
      );
}

/// STATE 4 — what actually happened, ready to save and to summarize.
class SessionResult {
  /// sessions.id and movement_analysis.id, generated on the phone so the
  /// session journal can retry an upload without creating duplicates.
  final String id;
  final String analysisId;
  final DateTime startedAt;
  final AssignedExercise exercise;
  final int repsCompleted;
  final int romAchieved; // % of target, same convention as sessions.rom elsewhere
  final int peakJointAngle; // degrees, for movement_analysis
  final int achievedRangeDegrees;
  final MuscleActivation peakActivation; // activation reading at peak angle
  final Duration duration;
  final FatigueLevel peakFatigue;
  final SafetyTier worstTier;
  final List<SessionAlert> alerts;

  const SessionResult({
    required this.id,
    required this.analysisId,
    required this.startedAt,
    required this.exercise,
    required this.repsCompleted,
    required this.romAchieved,
    required this.peakJointAngle,
    required this.achievedRangeDegrees,
    required this.peakActivation,
    required this.duration,
    required this.peakFatigue,
    required this.worstTier,
    required this.alerts,
  });

  /// Written to the session journal (SessionJournal) so a session survives
  /// interruptions, process death and being offline.
  Map<String, dynamic> toJson() => {
        'id': id,
        'analysisId': analysisId,
        'startedAt': startedAt.toIso8601String(),
        'exercise': exercise.toJson(),
        'repsCompleted': repsCompleted,
        'romAchieved': romAchieved,
        'peakJointAngle': peakJointAngle,
        'achievedRangeDegrees': achievedRangeDegrees,
        'peakActivation': peakActivation.name,
        'durationMs': duration.inMilliseconds,
        'peakFatigue': peakFatigue.name,
        'worstTier': worstTier.name,
        'alerts': [for (final a in alerts) a.toJson()],
      };

  factory SessionResult.fromJson(Map<String, dynamic> j) => SessionResult(
        id: j['id'] as String,
        analysisId: j['analysisId'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        exercise: AssignedExercise.fromJson(Map<String, dynamic>.from(j['exercise'] as Map)),
        repsCompleted: (j['repsCompleted'] as num).toInt(),
        romAchieved: (j['romAchieved'] as num).toInt(),
        peakJointAngle: (j['peakJointAngle'] as num).toInt(),
        achievedRangeDegrees: (j['achievedRangeDegrees'] as num).toInt(),
        peakActivation: MuscleActivation.values.byName(j['peakActivation'] as String? ?? 'resting'),
        duration: Duration(milliseconds: (j['durationMs'] as num).toInt()),
        peakFatigue: FatigueLevel.values.byName(j['peakFatigue'] as String),
        worstTier: SafetyTier.values.byName(j['worstTier'] as String),
        alerts: [for (final a in j['alerts'] as List) SessionAlert.fromJson(Map<String, dynamic>.from(a as Map))],
      );
}
