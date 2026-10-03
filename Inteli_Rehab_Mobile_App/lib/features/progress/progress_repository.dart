import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
import '../../core/util/dates.dart';
import 'progress_models.dart';

/// Everything the Progress screen shows (UC-11) — real sessions,
/// movement_analysis, patient_exercise_plans (for each session's ROM
/// target), alerts (for Session History's factual "N correction prompts"),
/// and earned badges. The onboarding calibration session is excluded
/// throughout, same as HomeRepository — it isn't an exercise session.
class ProgressRepository {
  static const _baselineMarker = 'baseline_calibration';

  /// Newest sessions shown in history/summary, and the most alert rows ever
  /// requested in one query (see [_alertCounts]).
  static const _maxSessions = 200;
  static const _alertBatch = 50;

  SupabaseClient get _db => supabase;

  Future<ProgressData> load(String patientId) async {
    final results = await Future.wait<dynamic>([
      // `*` rather than naming duration_seconds explicitly: that column
      // only exists once supabase_session_duration.sql has been run, and
      // an explicit select of a missing column errors outright where `*`
      // just omits it (same reasoning as ProfileRepository's height/weight).
      _db
          .from('sessions')
          .select('*, exercises(name), movement_analysis(posture_status)')
          .eq('patient_id', patientId)
          .order('performed_at', ascending: false)
          .limit(_maxSessions), // unbounded, PostgREST silently truncates at ~1000 anyway
      _db
          .from('patient_exercise_plans')
          .select('exercise_id, rom_target')
          .eq('patient_id', patientId)
          .eq('active', true),
      _db
          .from('patient_badges')
          .select('earned_at, badges(name, description, icon_url)')
          .eq('patient_id', patientId)
          .order('earned_at', ascending: false),
    ]);

    final sessionRows = (results[0] as List).where((s) => !_isBaseline(s)).toList()
      ..sort((a, b) => (b['performed_at'] as String).compareTo(a['performed_at'] as String));
    final planRows = results[1] as List;
    final badgeRows = results[2] as List;

    final romTargetByExercise = <String, int>{
      for (final r in planRows)
        if (r['rom_target'] != null) r['exercise_id'] as String: (r['rom_target'] as num).toInt(),
    };

    final sessionIds = [for (final s in sessionRows) s['id'] as String];
    final alertsBySession = await _alertCounts(sessionIds);

    final history = [
      for (final s in sessionRows)
        SessionHistoryEntry(
          id: s['id'] as String,
          performedAt: parseTimestamp(s['performed_at'] as String),
          exerciseName: (s['exercises'] as Map?)?['name'] as String? ?? 'Exercise',
          durationSeconds: (s['duration_seconds'] as num?)?.toInt(),
          romAchieved: (s['rom'] as num?)?.toInt() ?? 0,
          romTarget: romTargetByExercise[s['exercise_id'] as String?],
          reps: (s['reps'] as num?)?.toInt() ?? 0,
          correctionCount: alertsBySession[s['id']]?.$1 ?? 0,
          unsafeCount: alertsBySession[s['id']]?.$2 ?? 0,
        ),
    ];

    final trendSource = history.reversed.take(12).toList(); // oldest -> newest, last 12
    final romTrend = [
      for (final h in trendSource) RomTrendPoint(date: h.performedAt, achieved: h.romAchieved, target: h.romTarget),
    ];

    final badges = [
      for (final b in badgeRows)
        EarnedBadge(
          name: (b['badges'] as Map?)?['name'] as String? ?? 'Badge',
          description: (b['badges'] as Map?)?['description'] as String?,
          iconUrl: (b['badges'] as Map?)?['icon_url'] as String?,
          earnedAt: parseTimestamp(b['earned_at'] as String),
        ),
    ];

    return ProgressData(
      summary: _summary(history),
      romTrend: romTrend,
      badges: badges,
      history: history,
    );
  }

  static bool _isBaseline(dynamic row) =>
      ((row['movement_analysis'] as List?) ?? []).any((m) => m['posture_status'] == _baselineMarker);

  Future<Map<String, (int, int)>> _alertCounts(List<String> sessionIds) async {
    if (sessionIds.isEmpty) return {};
    // Batched: one IN (...) list of every session id outgrows the URL limit
    // for a long-term patient and fails the whole screen.
    final rows = <dynamic>[];
    for (var i = 0; i < sessionIds.length; i += _alertBatch) {
      final end = i + _alertBatch > sessionIds.length ? sessionIds.length : i + _alertBatch;
      final batch = sessionIds.sublist(i, end);
      rows.addAll(await _db.from('alerts').select('session_id, alert_type').inFilter('session_id', batch) as List);
    }
    final out = <String, (int, int)>{};
    for (final r in rows) {
      final id = r['session_id'] as String;
      final unsafe = r['alert_type'] == 'unsafe_movement';
      final prev = out[id] ?? (0, 0);
      out[id] = unsafe ? (prev.$1, prev.$2 + 1) : (prev.$1 + 1, prev.$2);
    }
    return out;
  }

  /// Recovery % is the most recently logged ROM achieved (the same number
  /// shown as "ROM" on Home/Session Summary), not a separate formula.
  /// Adherence % is how many of the days since the first session had at
  /// least one session logged — there's no prescribed session-per-day
  /// target anywhere in the schema to compare against instead.
  static ProgressSummary _summary(List<SessionHistoryEntry> history) {
    if (history.isEmpty) {
      return const ProgressSummary(recoveryPercent: 0, sessionsCompleted: 0, adherencePercent: 0);
    }
    final recovery = history.first.romAchieved;
    final activeDays = history.map((h) => dayOf(h.performedAt)).toSet();
    final first = history.map((h) => h.performedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final totalDays = calendarDaysBetween(first, DateTime.now()) + 1;
    final adherence = ((activeDays.length / (totalDays < 1 ? 1 : totalDays)) * 100).round().clamp(0, 100);

    return ProgressSummary(recoveryPercent: recovery, sessionsCompleted: history.length, adherencePercent: adherence);
  }
}
