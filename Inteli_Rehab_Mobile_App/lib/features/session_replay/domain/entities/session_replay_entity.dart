class SessionReplayEntity {
  final String sessionId;
  final List<double> angleFrames;
  final Duration totalDuration;

  const SessionReplayEntity({
    required this.sessionId,
    required this.angleFrames,
    required this.totalDuration,
  });
}
