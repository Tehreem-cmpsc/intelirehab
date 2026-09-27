class ExerciseEntity {
  final String id;
  final String name;
  final String description;
  final String targetJoint;
  final int defaultTargetReps;
  final int defaultTargetSets;
  final double targetRomDegrees;
  final String? animationAssetPath;

  const ExerciseEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.targetJoint,
    required this.defaultTargetReps,
    required this.defaultTargetSets,
    required this.targetRomDegrees,
    this.animationAssetPath,
  });
}
