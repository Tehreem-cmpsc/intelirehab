import '../../domain/entities/exercise_plan_entity.dart';

class ExercisePlanModel extends ExercisePlanEntity {
  const ExercisePlanModel({
    required super.id,
    required super.exerciseName,
    required super.targetReps,
    required super.targetSets,
    required super.instructions,
  });

  factory ExercisePlanModel.fromJson(Map<String, dynamic> json) {
    return ExercisePlanModel(
      id: json['id'] as String? ?? '',
      exerciseName: json['exerciseName'] as String? ?? '',
      targetReps: json['targetReps'] as int? ?? 0,
      targetSets: json['targetSets'] as int? ?? 0,
      instructions: json['instructions'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'targetReps': targetReps,
      'targetSets': targetSets,
      'instructions': instructions,
    };
  }
}
