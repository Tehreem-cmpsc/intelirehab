import '../entities/dashboard_data_entity.dart';

abstract class HomeDashboardRepository {
  Future<DashboardDataEntity> getDashboardData();
}
