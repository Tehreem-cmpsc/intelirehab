class ExercisePlanEntity {
  final String id;
  final String exerciseName;
  final int targetReps;
  final int targetSets;
  final String instructions;

  const ExercisePlanEntity({
    required this.id,
    required this.exerciseName,
    required this.targetReps,
    required this.targetSets,
    required this.instructions,
  });
}
