import 'dart:math' as math;

import 'processing/safety_monitor.dart';

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

/// What a session needs to know about this patient before it starts: their own reference range and
/// any red-limit overrides their physiotherapist set. All optional; anything missing (offline, not
/// calibrated, migration not run) falls back to the built-in defaults.
class SessionSetup {
  /// The patient's calibrated peak elbow flexion, degrees: the angle that counts as 100% ROM.
  final double? referenceRangeDeg;

  /// Physiotherapist's red limits for this patient (patients.safety_max_*).
  final double? maxAngleDeg;
  final double? maxSpeedDegPerSec;

  const SessionSetup({this.referenceRangeDeg, this.maxAngleDeg, this.maxSpeedDegPerSec});

  static const defaults = SessionSetup();

  /// Typical elbow flexion, used when the patient has no usable calibration.
  static const defaultRangeDeg = 150.0;

  /// A calibration that read less than this is treated as a failed reading, not a real range.
  static const minPlausibleRangeDeg = 60.0;
  static const maxPlausibleRangeDeg = 180.0;

  double get fullRangeDegrees {
    final r = referenceRangeDeg;
    if (r == null || r < minPlausibleRangeDeg || r > maxPlausibleRangeDeg) return defaultRangeDeg;
    return r;
  }

  /// Null (use the session's own default) unless the physiotherapist set something.
  SafetyLimits? limitsFor(double fullRangeDegrees) {
    if (maxAngleDeg == null && maxSpeedDegPerSec == null) return null;
    final base = SafetyLimits(maxAngleDeg: maxAngleDeg ?? math.max(fullRangeDegrees, defaultRangeDeg) + 10);
    return SafetyLimits(
      maxAngleDeg: base.maxAngleDeg,
      maxSpeedDegPerSec: maxSpeedDegPerSec ?? base.maxSpeedDegPerSec,
    );
  }
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

  /// The patient pressed "This hurts". Not a form fault: it is kept apart from correction prompts
  /// in the summary and the quality score, and saved as its own alert type.
  final bool pain;
  const SessionAlert({
    required this.id,
    required this.tier,
    required this.message,
    required this.at,
    this.pain = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tier': tier.name,
        'message': message,
        'at': at.toIso8601String(),
        if (pain) 'pain': true,
      };

  factory SessionAlert.fromJson(Map<String, dynamic> j) => SessionAlert(
        id: j['id'] as String,
        tier: SafetyTier.values.byName(j['tier'] as String),
        message: j['message'] as String,
        at: DateTime.parse(j['at'] as String),
        pain: j['pain'] == true,
      );
}

/// Why a session stopped before every rep was done. Saved as sessions.ended_reason.
enum EndedReason {
  pain('pain', 'Pain'),
  tired('tired', 'Too tired'),
  bandProblem('band_problem', 'Band problem'),
  other('other', 'Something else');

  final String db;
  final String label;
  const EndedReason(this.db, this.label);

  static EndedReason? fromDb(Object? v) {
    for (final r in values) {
      if (r.db == v) return r;
    }
    return null;
  }
}

/// What happened in one set: reps, how far the arm got, prompts, and fatigue at its end
/// (session_sets row).
class SetResult {
  final int number; // 1-based
  final int reps;
  final int romPercent; // peak angle in the set, % of the patient's reference range
  final int corrections;
  final int unsafe;
  final FatigueLevel fatigue;

  const SetResult({
    required this.number,
    required this.reps,
    required this.romPercent,
    required this.corrections,
    required this.unsafe,
    required this.fatigue,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'reps': reps,
        'romPercent': romPercent,
        'corrections': corrections,
        'unsafe': unsafe,
        'fatigue': fatigue.name,
      };

  factory SetResult.fromJson(Map<String, dynamic> j) => SetResult(
        number: (j['number'] as num).toInt(),
        reps: (j['reps'] as num).toInt(),
        romPercent: (j['romPercent'] as num).toInt(),
        corrections: (j['corrections'] as num?)?.toInt() ?? 0,
        unsafe: (j['unsafe'] as num?)?.toInt() ?? 0,
        fatigue: FatigueLevel.values.byName(j['fatigue'] as String? ?? 'normal'),
      );
}

/// STATE 4 — what actually happened, ready to save and to summarize.
/// The arm's movement during a session, for the physiotherapist's replay (session_motion table).
/// The 3D twin is driven only by elbow angle and muscle activation, so these two series over time are
/// enough to replay exactly what the patient saw. Sampled at ~15 Hz.
class MotionRecording {
  final double sampleRateHz;
  final String side; // 'left' | 'right'
  final List<int> tMs; // since the session started
  final List<double> angle; // degrees
  final List<double> emg; // %MVC
  /// {"t_ms": int, "type": "rep"} and {"t_ms": int, "type": "tier", "tier": name, "message": text?}
  final List<Map<String, dynamic>> events;

  const MotionRecording({
    required this.sampleRateHz,
    required this.side,
    required this.tMs,
    required this.angle,
    required this.emg,
    required this.events,
  });

  bool get isEmpty => tMs.isEmpty;

  Map<String, dynamic> toJson() => {
        'sampleRateHz': sampleRateHz,
        'side': side,
        'tMs': tMs,
        'angle': angle,
        'emg': emg,
        'events': events,
      };

  factory MotionRecording.fromJson(Map<String, dynamic> j) => MotionRecording(
        sampleRateHz: (j['sampleRateHz'] as num).toDouble(),
        side: j['side'] as String? ?? 'left',
        tMs: [for (final v in j['tMs'] as List) (v as num).toInt()],
        angle: [for (final v in j['angle'] as List) (v as num).toDouble()],
        emg: [for (final v in j['emg'] as List) (v as num).toDouble()],
        events: [for (final e in j['events'] as List) Map<String, dynamic>.from(e as Map)],
      );
}

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

  /// The movement itself, for replay. Null for simulated sessions.
  final MotionRecording? motion;

  /// One entry per set that was started (the last may be partial).
  final List<SetResult> sets;

  /// Reps the whole session was meant to have (all sets); null on older saved sessions, where the
  /// exercise's own reps-per-set is all there is.
  final int? repsPlanned;

  /// The patient's own 0-10 rating at the end; null if they skipped it.
  final int? painLevel;

  /// Why the session stopped early; null when every rep was done (or no reason was given).
  final EndedReason? endedReason;

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
    this.motion,
    this.sets = const [],
    this.repsPlanned,
    this.painLevel,
    this.endedReason,
  });

  SessionResult withEnding({int? painLevel, EndedReason? endedReason}) => SessionResult(
        id: id,
        analysisId: analysisId,
        startedAt: startedAt,
        exercise: exercise,
        repsCompleted: repsCompleted,
        romAchieved: romAchieved,
        peakJointAngle: peakJointAngle,
        achievedRangeDegrees: achievedRangeDegrees,
        peakActivation: peakActivation,
        duration: duration,
        peakFatigue: peakFatigue,
        worstTier: worstTier,
        alerts: alerts,
        motion: motion,
        sets: sets,
        repsPlanned: repsPlanned,
        painLevel: painLevel ?? this.painLevel,
        endedReason: endedReason ?? this.endedReason,
      );

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
        if (motion != null) 'motion': motion!.toJson(),
        if (sets.isNotEmpty) 'sets': [for (final s in sets) s.toJson()],
        if (repsPlanned != null) 'repsPlanned': repsPlanned,
        if (painLevel != null) 'painLevel': painLevel,
        if (endedReason != null) 'endedReason': endedReason!.db,
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
        motion: j['motion'] == null ? null : MotionRecording.fromJson(Map<String, dynamic>.from(j['motion'] as Map)),
        sets: [
          for (final s in (j['sets'] as List?) ?? const [])
            SetResult.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        repsPlanned: (j['repsPlanned'] as num?)?.toInt(),
        painLevel: (j['painLevel'] as num?)?.toInt(),
        endedReason: EndedReason.fromDb(j['endedReason']),
      );
}
