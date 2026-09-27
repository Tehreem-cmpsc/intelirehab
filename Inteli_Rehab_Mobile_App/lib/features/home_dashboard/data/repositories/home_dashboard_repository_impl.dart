import '../../domain/entities/dashboard_data_entity.dart';
import '../../domain/repositories/home_dashboard_repository.dart';
import '../datasources/home_dashboard_remote_data_source.dart';

class HomeDashboardRepositoryImpl implements HomeDashboardRepository {
  final HomeDashboardRemoteDataSource remoteDataSource;

  const HomeDashboardRepositoryImpl(this.remoteDataSource);

  @override
  Future<DashboardDataEntity> getDashboardData() {
    return remoteDataSource.getDashboardData();
  }
}
