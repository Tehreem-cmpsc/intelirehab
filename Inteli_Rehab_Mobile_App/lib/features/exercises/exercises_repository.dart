import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
import '../onboarding/onboarding_repository.dart';
import 'exercises_models.dart';
import 'widgets/warning_banner.dart' show WarningState;

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

  /// The patient's own reference range (their calibrated peak flexion) and any red limits their
  /// physiotherapist set. Best effort: each part is read on its own and anything that can't be read
  /// (offline, not calibrated, migration not run) is simply left to the built-in default.
  Future<SessionSetup> loadSessionSetup(String patientId) async {
    double? maxAngle;
    double? maxSpeed;
    double? reference;
    try {
      final row = await _db
          .from('patients')
          .select('safety_max_angle_deg, safety_max_speed_deg_s')
          .eq('id', patientId)
          .maybeSingle();
      maxAngle = (row?['safety_max_angle_deg'] as num?)?.toDouble();
      maxSpeed = (row?['safety_max_speed_deg_s'] as num?)?.toDouble();
    } catch (_) {}
    try {
      final row = await _db
          .from('sessions')
          .select('performed_at, movement_analysis!inner(joint_angle, posture_status)')
          .eq('patient_id', patientId)
          .eq('movement_analysis.posture_status', OnboardingRepository.baselineMarker)
          .order('performed_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final analysis = (row?['movement_analysis'] as List?)?.firstOrNull as Map?;
      reference = (analysis?['joint_angle'] as num?)?.toDouble();
    } catch (_) {}
    return SessionSetup(referenceRangeDeg: reference, maxAngleDeg: maxAngle, maxSpeedDegPerSec: maxSpeed);
  }

  /// The physiotherapist's current warning for this patient, and whether they have tapped "Got it" on it.
  /// Null when there is none. The text comes from patients.warning; whether it was seen from the warning
  /// log (supabase_warning_autoclear.sql), which may not exist yet - then it simply reads as not seen.
  Future<WarningState?> currentWarning(String patientId) async {
    final row = await _db.from('patients').select('warning').eq('id', patientId).maybeSingle();
    final text = (row?['warning'] as String?)?.trim();
    if (text == null || text.isEmpty) return null;
    var seen = false;
    try {
      final log = await _db
          .from('patient_warning_log')
          .select('read_at')
          .eq('patient_id', patientId)
          .isFilter('cleared_at', null)
          .order('sent_at', ascending: false)
          .limit(1)
          .maybeSingle();
      seen = log?['read_at'] != null;
    } catch (_) {}
    return WarningState(text, seen: seen);
  }

  /// Tells the physiotherapist's portal this patient has seen their current warning. A no-op until
  /// supabase_warning_autoclear.sql has been run.
  Future<void> acknowledgeWarning() async {
    try {
      await _db.rpc('acknowledge_my_warning');
    } on PostgrestException catch (e) {
      // 42883 / PGRST202: the function does not exist yet.
      if (e.code != '42883' && e.code != 'PGRST202') rethrow;
    }
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
    await _upsertMotion(result);
    await _upsertSets(result);

    if (result.alerts.isNotEmpty) {
      await _db.from('alerts').upsert([
        for (final a in result.alerts)
          {
            'id': a.id,
            'session_id': result.id,
            'alert_type': a.pain ? 'pain_reported' : (a.tier == SafetyTier.unsafe ? 'unsafe_movement' : 'correction'),
            'severity': a.pain ? 'warning' : (a.tier == SafetyTier.unsafe ? 'critical' : 'warning'),
            'message': a.message,
            'created_at': a.at.toUtc().toIso8601String(),
          },
      ], onConflict: 'id', ignoreDuplicates: true);
    }
  }

  /// One row per set (supabase_session_module_v2.sql). Written once, keyed by session and set number,
  /// so a retried upload is a no-op. Until that migration has been run the table does not exist: the
  /// session still saves, just without the per-set breakdown.
  Future<void> _upsertSets(SessionResult result) async {
    if (result.sets.isEmpty) return;
    try {
      await _db.from('session_sets').upsert([
        for (final s in result.sets)
          {
            'session_id': result.id,
            'set_number': s.number,
            'reps': s.reps,
            'rom': s.romPercent,
            'corrections': s.corrections,
            'unsafe': s.unsafe,
            'fatigue': _fatigueScore(s.fatigue),
          },
      ], onConflict: 'session_id,set_number', ignoreDuplicates: true);
    } on PostgrestException catch (e) {
      if (e.code != '42P01' && e.code != 'PGRST205') rethrow;
    }
  }

  /// The movement recording for the physiotherapist's replay (supabase_session_motion.sql). Written
  /// once, keyed by the session id, so a retried upload is a no-op. Until that migration has been run
  /// the table does not exist: the session still saves, just without a replay.
  Future<void> _upsertMotion(SessionResult result) async {
    final m = result.motion;
    if (m == null || m.isEmpty) return;
    try {
      await _db.from('session_motion').upsert({
        'session_id': result.id,
        'sample_rate_hz': m.sampleRateHz,
        'side': m.side,
        't_ms': m.tMs,
        'angle': m.angle,
        'emg': m.emg,
        'events': m.events,
      }, onConflict: 'session_id', ignoreDuplicates: true);
    } on PostgrestException catch (e) {
      // 42P01 / PGRST205: table not created yet. Anything else is a real failure.
      if (e.code != '42P01' && e.code != 'PGRST205') rethrow;
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

  /// Falls back to writing without the optional columns (`duration_seconds`, `pain_level`,
  /// `ended_reason`) that a migration hasn't added yet — session saving shouldn't hard-fail on a
  /// column that's still pending, it should just lose that field until it is.
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
      'pain_level': result.painLevel,
      'ended_reason': result.endedReason?.db,
    };
    const optional = ['duration_seconds', 'pain_level', 'ended_reason'];
    // Each retry drops the optional column(s) the error names (all of them if it names none), so a
    // missing pain column never costs the duration, and vice versa.
    for (var attempt = 0; attempt <= optional.length; attempt++) {
      try {
        await _db.from('sessions').upsert(payload, onConflict: 'id', ignoreDuplicates: true);
        return;
      } on PostgrestException catch (e) {
        if (e.code != '42703' && e.code != 'PGRST204') rethrow;
        final named = optional.where((c) => payload.containsKey(c) && e.message.contains(c)).toList();
        final drop = named.isNotEmpty ? named : optional.where(payload.containsKey).toList();
        if (drop.isEmpty) rethrow;
        drop.forEach(payload.remove);
      }
    }
  }

  static int _qualityScore(SessionResult r) {
    // Pain reports are not form faults, so they do not lower the quality score.
    final penalty = r.alerts.where((a) => !a.pain).fold<int>(0, (sum, a) => sum + (a.tier == SafetyTier.unsafe ? 15 : 6));
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
