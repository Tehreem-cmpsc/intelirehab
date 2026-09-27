class RehabSessionEntity {
  final String id;
  final String exerciseId;
  final int completedReps;
  final double maxRom;
  final double averageScore;
  final DateTime timestamp;

  const RehabSessionEntity({
    required this.id,
    required this.exerciseId,
    required this.completedReps,
    required this.maxRom,
    required this.averageScore,
    required this.timestamp,
  });
}
