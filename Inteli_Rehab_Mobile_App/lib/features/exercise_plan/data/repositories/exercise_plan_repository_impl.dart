import '../../domain/entities/exercise_plan_entity.dart';
import '../../domain/repositories/exercise_plan_repository.dart';
import '../datasources/exercise_plan_remote_data_source.dart';

class ExercisePlanRepositoryImpl implements ExercisePlanRepository {
  final ExercisePlanRemoteDataSource remoteDataSource;

  const ExercisePlanRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<ExercisePlanEntity>> getAssignedPlan() {
    return remoteDataSource.getAssignedPlan();
  }
}
