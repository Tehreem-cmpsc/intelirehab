import '../entities/exercise_plan_entity.dart';

abstract class ExercisePlanRepository {
  Future<List<ExercisePlanEntity>> getAssignedPlan();
}
