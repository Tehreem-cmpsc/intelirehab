/// The three top-of-screen summary numbers (Rule 8's chart-before-badges
/// hierarchy starts here — see ProgressRepository for how each is derived
/// from real data, never a placeholder).
class ProgressSummary {
  final int recoveryPercent;
  final int sessionsCompleted;
  final int adherencePercent;

  const ProgressSummary({
    required this.recoveryPercent,
    required this.sessionsCompleted,
    required this.adherencePercent,
  });
}

/// One point on the ROM trend chart — a real session's achieved ROM,
/// paired with that exercise's assigned target where one is still known.
class RomTrendPoint {
  final DateTime date;
  final int achieved;
  final int? target;
  const RomTrendPoint({required this.date, required this.achieved, required this.target});
}

class EarnedBadge {
  final String name;
  final String? description;
  final String? iconUrl;
  final DateTime earnedAt;
  const EarnedBadge({required this.name, required this.description, required this.iconUrl, required this.earnedAt});
}

/// One row of Session History — patient language, no raw sensor values
/// (no quality score, no fatigue number, no joint-angle dump).
class SessionHistoryEntry {
  final String id;
  final DateTime performedAt;
  final String exerciseName;
  final int? durationSeconds;
  final int romAchieved;
  final int? romTarget;
  final int reps;
  final int correctionCount;
  final int unsafeCount;

  const SessionHistoryEntry({
    required this.id,
    required this.performedAt,
    required this.exerciseName,
    required this.durationSeconds,
    required this.romAchieved,
    required this.romTarget,
    required this.reps,
    required this.correctionCount,
    required this.unsafeCount,
  });
}

class ProgressData {
  final ProgressSummary summary;
  final List<RomTrendPoint> romTrend;
  final List<EarnedBadge> badges;
  final List<SessionHistoryEntry> history;

  const ProgressData({
    required this.summary,
    required this.romTrend,
    required this.badges,
    required this.history,
  });

  bool get isEmpty => history.isEmpty;
}
