import '../models/exercise_plan_model.dart';

abstract class ExercisePlanRemoteDataSource {
  Future<List<ExercisePlanModel>> getAssignedPlan();
}

class ExercisePlanRemoteDataSourceImpl implements ExercisePlanRemoteDataSource {
  @override
  Future<List<ExercisePlanModel>> getAssignedPlan() async {
    return [];
  }
}
