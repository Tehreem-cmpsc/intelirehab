import '../entities/exercise_plan_entity.dart';
import '../repositories/exercise_plan_repository.dart';

class GetExercisePlanUsecase {
  final ExercisePlanRepository repository;
  const GetExercisePlanUsecase(this.repository);

  Future<List<ExercisePlanEntity>> call() {
    return repository.getAssignedPlan();
  }
}
