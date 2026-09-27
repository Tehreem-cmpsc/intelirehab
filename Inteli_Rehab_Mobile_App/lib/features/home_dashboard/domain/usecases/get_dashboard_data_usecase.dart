import '../entities/dashboard_data_entity.dart';
import '../repositories/home_dashboard_repository.dart';

class GetDashboardDataUsecase {
  final HomeDashboardRepository repository;
  const GetDashboardDataUsecase(this.repository);

  Future<DashboardDataEntity> call() {
    return repository.getDashboardData();
  }
}
