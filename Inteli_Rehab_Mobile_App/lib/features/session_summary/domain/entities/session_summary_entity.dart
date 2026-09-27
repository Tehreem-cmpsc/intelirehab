class SessionSummaryEntity {
  final String sessionId;
  final int completedReps;
  final String movementQuality;
  final double romImproved;
  final int consistencyScore;

  const SessionSummaryEntity({
    required this.sessionId,
    required this.completedReps,
    required this.movementQuality,
    required this.romImproved,
    required this.consistencyScore,
  });
}
