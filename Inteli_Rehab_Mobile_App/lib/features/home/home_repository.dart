import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
import 'home_models.dart';

/// Everything the Home screen shows, straight from Supabase — no
/// placeholder numbers. A patient with no plan/sessions/device yet
/// correctly gets nulls, which the screen renders as its documented
/// empty states rather than fabricated data.
class HomeRepository {
  /// Matches OnboardingRepository.baselineMarker: the onboarding
  /// calibration is stored as a session too, but it's measured in
  /// degrees (not the % used for ROM here) and isn't an exercise the
  /// patient "did today" — excluded from everything below.
  static const _baselineMarker = 'baseline_calibration';

  SupabaseClient get _db => supabase;

  Future<HomeSnapshot> load(String patientId) async {
    final results = await Future.wait<dynamic>([
      _db
          .from('patient_exercise_plans')
          .select('exercise_id, rom_target, exercises(name)')
          .eq('patient_id', patientId)
          .eq('active', true),
      _db
          .from('rehabilitation_plans')
          .select('plan_name')
          .eq('patient_id', patientId)
          .eq('status', 'active')
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle(),
      // movement_analysis(*) rather than naming columns: muscle_activation
      // only exists once supabase_movement_analysis_activation.sql has run,
      // and an explicit select of a missing column errors outright where
      // `*` just omits it (same reasoning as ProgressRepository's sessions
      // select).
      _db
          .from('sessions')
          .select('performed_at, rom, reps, exercise_id, exercises(name), movement_analysis(*)')
          .eq('patient_id', patientId)
          .order('performed_at', ascending: false)
          .limit(60),
      _db.from('wearable_devices').select('serial_no').eq('patient_id', patientId).eq('status', 'paired').maybeSingle(),
    ]);

    final planRows = results[0] as List;
    final planRow = results[1] as Map?;
    final sessionRows = results[2] as List;
    final deviceRow = results[3] as Map?;

    final realSessions = sessionRows.where((s) => !_isBaseline(s)).toList()
      ..sort((a, b) => (b['performed_at'] as String).compareTo(a['performed_at'] as String));

    final todayStart = DateTime.now().let((n) => DateTime(n.year, n.month, n.day));
    final doneExerciseIdsToday = realSessions
        .where((s) => DateTime.parse(s['performed_at'] as String).isAfter(todayStart))
        .map((s) => s['exercise_id'] as String?)
        .whereType<String>()
        .toSet();

    TodaysPlan? plan;
    if (planRows.isNotEmpty) {
      final exercises = [
        for (final r in planRows)
          ExerciseAssignment(
            exerciseId: r['exercise_id'] as String,
            exerciseName: (r['exercises'] as Map?)?['name'] as String? ?? 'Exercise',
            romTarget: (r['rom_target'] as num?)?.toInt(),
            doneToday: doneExerciseIdsToday.contains(r['exercise_id'] as String),
          ),
      ];
      plan = TodaysPlan(planName: planRow?['plan_name'] as String? ?? 'Your exercise plan', exercises: exercises);
    }

    LastSessionSnapshot? lastSession;
    if (realSessions.isNotEmpty) {
      final s = realSessions.first;
      final analysis = ((s['movement_analysis'] as List?) ?? const []).cast<Map>().firstOrNull;
      lastSession = LastSessionSnapshot(
        performedAt: DateTime.parse(s['performed_at'] as String),
        exerciseName: (s['exercises'] as Map?)?['name'] as String? ?? 'Exercise',
        rom: (s['rom'] as num?)?.toInt() ?? 0,
        romTarget: _matchingRomTarget(s['exercise_id'] as String?, planRows),
        reps: (s['reps'] as num?)?.toInt() ?? 0,
        jointAngle: (analysis?['joint_angle'] as num?)?.round(),
        muscleActivation: analysis?['muscle_activation'] as String?,
      );
    }

    final sessionDates = realSessions.map((s) => DateTime.parse(s['performed_at'] as String)).toList();
    final sessionsThisWeek = sessionDates.where((d) => !d.isBefore(_startOfWeek(DateTime.now()))).length;
    final bestPriorWeek = _bestWeeklyCount(sessionDates, excludingWeekOf: DateTime.now());

    return HomeSnapshot(
      plan: plan,
      lastSession: lastSession,
      baseline: _extractBaseline(sessionRows),
      wearablePaired: deviceRow != null,
      deviceSerial: deviceRow?['serial_no'] as String?,
      motivation: _motivation(sessionsThisWeek, bestPriorWeek, sessionDates),
      sessionsThisWeek: sessionsThisWeek,
      currentStreak: _currentStreak(sessionDates),
    );
  }

  static bool _isBaseline(dynamic row) =>
      ((row['movement_analysis'] as List?) ?? []).any((m) => m['posture_status'] == _baselineMarker);

  /// The onboarding calibration reading — same source as
  /// OnboardingRepository.hydrate's baseline lookup, degrees not %.
  static BaselineReading? _extractBaseline(List sessionRows) {
    final baselineRows = sessionRows.where(_isBaseline).toList()
      ..sort((a, b) => (b['performed_at'] as String).compareTo(a['performed_at'] as String));
    if (baselineRows.isEmpty) return null;
    final row = baselineRows.first;
    final analysis = (row['movement_analysis'] as List?)
        ?.cast<Map>()
        .firstWhere((m) => m['posture_status'] == _baselineMarker, orElse: () => const {});
    final flexion = (analysis?['joint_angle'] as num?)?.toDouble();
    final range = (analysis?['rom'] as num?)?.toDouble();
    if (flexion == null || range == null) return null;
    return BaselineReading(flexion: flexion, range: range, recordedAt: DateTime.parse(row['performed_at'] as String));
  }

  static int? _matchingRomTarget(String? exerciseId, List planRows) {
    if (exerciseId == null) return null;
    for (final r in planRows) {
      if (r['exercise_id'] == exerciseId) return (r['rom_target'] as num?)?.toInt();
    }
    return null;
  }

  static DateTime _startOfWeek(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    // Monday-anchored, matching the web portal's computeStreak/startOfWeek.
    return d.subtract(Duration(days: (d.weekday - 1)));
  }

  static int _bestWeeklyCount(List<DateTime> dates, {required DateTime excludingWeekOf}) {
    final currentWeekStart = _startOfWeek(excludingWeekOf);
    final counts = <DateTime, int>{};
    for (final d in dates) {
      final week = _startOfWeek(d);
      if (week == currentWeekStart) continue;
      counts[week] = (counts[week] ?? 0) + 1;
    }
    if (counts.isEmpty) return 0;
    return counts.values.reduce((a, b) => a > b ? a : b);
  }

  /// Data-grounded, never a stock quote and never guilt about a missed day
  /// (see the mobile app's motivational-copy rule).
  static String _motivation(int thisWeek, int bestPriorWeek, List<DateTime> allDates) {
    if (allDates.isEmpty) return 'Complete your first session to get started.';
    if (thisWeek > 0 && thisWeek > bestPriorWeek) {
      return '$thisWeek session${thisWeek == 1 ? '' : 's'} this week — your best streak yet.';
    }
    final streak = _currentStreak(allDates);
    if (streak >= 2) return '$streak-day streak — keep it going.';
    if (thisWeek > 0) return '$thisWeek session${thisWeek == 1 ? '' : 's'} logged this week.';
    return 'Ready when you are — your plan is waiting.';
  }

  static int _currentStreak(List<DateTime> dates) {
    final days = dates.map((d) => DateTime(d.year, d.month, d.day)).toSet();
    var cursor = DateTime.now().let((n) => DateTime(n.year, n.month, n.day));
    if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    var streak = 0;
    while (days.contains(cursor)) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
