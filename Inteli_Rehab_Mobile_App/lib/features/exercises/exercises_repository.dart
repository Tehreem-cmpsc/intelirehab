import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
import '../onboarding/onboarding_repository.dart';
import 'exercises_models.dart';

/// STATE 1's data (the active plan) and STATE 3/4's write (saving a
/// completed session). Reuses OnboardingRepository's clinic/physio lookups
/// to resolve "Assigned by {name}" — patients have no direct read access
/// to `physiotherapists` by id, only through those SECURITY DEFINER
/// functions (same reasoning as ProfileRepository's Care Team section).
class ExercisesRepository {
  final OnboardingRepository _onboarding;
  SupabaseClient get _db => supabase;

  ExercisesRepository({OnboardingRepository? onboarding}) : _onboarding = onboarding ?? OnboardingRepository();

  static const _planColumns = 'id, exercise_id, sets, reps, rom_target, exercises(name, target, difficulty, description';

  /// The active plan rows. The illustration columns (exercises.media_url / media_type) arrive with
  /// a database migration; until it has been run the plan must still load, just without pictures.
  Future<List<dynamic>> _planRows(String patientId) async {
    Future<List<dynamic>> query(String columns) =>
        _db.from('patient_exercise_plans').select(columns).eq('patient_id', patientId).eq('active', true);
    try {
      return await query('$_planColumns, media_url, media_type)');
    } on PostgrestException catch (e) {
      final missingColumn = e.code == '42703' || e.message.contains('media_url') || e.message.contains('media_type');
      if (!missingColumn) rethrow;
      return query('$_planColumns)');
    }
  }

  Future<PlanSummary> loadPlan(String patientId) async {
    final results = await Future.wait<dynamic>([
      _planRows(patientId),
      _db
          .from('rehabilitation_plans')
          .select('plan_name')
          .eq('patient_id', patientId)
          .eq('status', 'active')
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle(),
      _db.from('patients').select('clinic_id, physio_id').eq('id', patientId).single(),
    ]);

    final planRows = results[0] as List;
    final planRow = results[1] as Map?;
    final patientRow = results[2] as Map;

    final exercises = [
      for (final r in planRows)
        AssignedExercise(
          assignmentId: r['id'] as String,
          exerciseId: r['exercise_id'] as String,
          name: (r['exercises'] as Map?)?['name'] as String? ?? 'Exercise',
          target: (r['exercises'] as Map?)?['target'] as String?,
          difficulty: (r['exercises'] as Map?)?['difficulty'] as String? ?? 'Beginner',
          description: (r['exercises'] as Map?)?['description'] as String?,
          mediaUrl: (r['exercises'] as Map?)?['media_url'] as String?,
          mediaType: (r['exercises'] as Map?)?['media_type'] as String? ?? 'image',
          sets: (r['sets'] as num?)?.toInt() ?? 3,
          repsTarget: (r['reps'] as num?)?.toInt() ?? 10,
          romTarget: (r['rom_target'] as num?)?.toInt(),
        ),
    ];

    String? physioName;
    final clinicId = patientRow['clinic_id'] as String?;
    final physioId = patientRow['physio_id'] as String?;
    if (clinicId != null && physioId != null) {
      final physios = await _onboarding.listPhysiotherapists(clinicId);
      physioName = physios.where((p) => p.id == physioId).firstOrNull?.fullName;
    }

    return PlanSummary(
      planName: planRow?['plan_name'] as String? ?? 'Your exercise plan',
      physioName: physioName,
      exercises: exercises,
    );
  }

  /// The patient's paired device id, for sessions.device_id — null if none.
  Future<String?> pairedDeviceId(String patientId) async {
    final row = await _db
        .from('wearable_devices')
        .select('id')
        .eq('patient_id', patientId)
        .eq('status', 'paired')
        .maybeSingle();
    return row?['id'] as String?;
  }

  /// Writes the session, its movement_analysis row, and one `alerts` row per
  /// correction/unsafe moment — so the physiotherapist sees the same alerts
  /// in the portal.
  ///
  /// Idempotent: every row carries a client-generated id and is written with
  /// ON CONFLICT DO NOTHING, so SessionJournal can retry after a dropped
  /// connection (even one that failed half-way) without duplicating
  /// anything. performed_at is when the session actually happened, not when
  /// a queued copy finally uploads.
  Future<void> saveSession({
    required String patientId,
    required String? deviceId,
    required SessionResult result,
  }) async {
    await _upsertSession(patientId: patientId, deviceId: deviceId, result: result);
    await _upsertMovementAnalysis(result);

    if (result.alerts.isNotEmpty) {
      await _db.from('alerts').upsert([
        for (final a in result.alerts)
          {
            'id': a.id,
            'session_id': result.id,
            'alert_type': a.tier == SafetyTier.unsafe ? 'unsafe_movement' : 'correction',
            'severity': a.tier == SafetyTier.unsafe ? 'critical' : 'warning',
            'message': a.message,
            'created_at': a.at.toUtc().toIso8601String(),
          },
      ], onConflict: 'id', ignoreDuplicates: true);
    }
  }

  /// Falls back to writing without `muscle_activation` if that migration
  /// (supabase_movement_analysis_activation.sql) hasn't been run yet — same
  /// reasoning as _upsertSession's duration_seconds fallback below.
  Future<void> _upsertMovementAnalysis(SessionResult result) async {
    final payload = {
      'id': result.analysisId,
      'session_id': result.id,
      'joint_angle': result.peakJointAngle,
      'rom': result.achievedRangeDegrees,
      'repetition_count': result.repsCompleted,
      'movement_score': _qualityScore(result),
      'posture_status': _postureLabel(result.worstTier),
      'compensation_detected': result.worstTier == SafetyTier.unsafe,
      'fatigue_level': result.peakFatigue.name,
      'muscle_activation': result.peakActivation.name,
    };
    try {
      await _db.from('movement_analysis').upsert(payload, onConflict: 'id', ignoreDuplicates: true);
    } on PostgrestException catch (e) {
      if (e.code != '42703' && e.code != 'PGRST204') rethrow;
      payload.remove('muscle_activation');
      await _db.from('movement_analysis').upsert(payload, onConflict: 'id', ignoreDuplicates: true);
    }
  }

  /// Falls back to writing without `duration_seconds` if that migration
  /// (supabase_session_duration.sql) hasn't been run yet — session saving
  /// shouldn't hard-fail on a column that's still pending, it should just
  /// lose the one field until it is.
  Future<void> _upsertSession({
    required String patientId,
    required String? deviceId,
    required SessionResult result,
  }) async {
    final payload = {
      'id': result.id,
      'patient_id': patientId,
      'exercise_id': result.exercise.exerciseId,
      'device_id': deviceId,
      'performed_at': result.startedAt.toUtc().toIso8601String(),
      'rom': result.romAchieved,
      'quality': _qualityScore(result),
      'fatigue': _fatigueScore(result.peakFatigue),
      'reps': result.repsCompleted,
      'duration_seconds': result.duration.inSeconds,
    };
    try {
      await _db.from('sessions').upsert(payload, onConflict: 'id', ignoreDuplicates: true);
    } on PostgrestException catch (e) {
      if (e.code != '42703' && e.code != 'PGRST204') rethrow;
      payload.remove('duration_seconds');
      await _db.from('sessions').upsert(payload, onConflict: 'id', ignoreDuplicates: true);
    }
  }

  static int _qualityScore(SessionResult r) {
    final penalty = r.alerts.fold<int>(0, (sum, a) => sum + (a.tier == SafetyTier.unsafe ? 15 : 6));
    return (100 - penalty).clamp(0, 100);
  }

  static int _fatigueScore(FatigueLevel level) => switch (level) {
        FatigueLevel.normal => 0,
        FatigueLevel.mild => 1,
        FatigueLevel.moderate => 2,
        FatigueLevel.critical => 3,
      };

  static String _postureLabel(SafetyTier tier) => switch (tier) {
        SafetyTier.normal => 'normal',
        SafetyTier.needsCorrection => 'needs_correction',
        SafetyTier.unsafe => 'unsafe',
      };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
