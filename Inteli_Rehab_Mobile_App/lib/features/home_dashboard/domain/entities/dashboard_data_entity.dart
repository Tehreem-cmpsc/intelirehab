class DashboardDataEntity {
  final String patientName;
  final String assignedExercise;
  final int streakDays;
  final double recoveryPercentage;

  const DashboardDataEntity({
    required this.patientName,
    required this.assignedExercise,
    required this.streakDays,
    required this.recoveryPercentage,
  });
}
