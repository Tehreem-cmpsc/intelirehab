import '../models/dashboard_data_model.dart';

abstract class HomeDashboardRemoteDataSource {
  Future<DashboardDataModel> getDashboardData();
}

class HomeDashboardRemoteDataSourceImpl implements HomeDashboardRemoteDataSource {
  @override
  Future<DashboardDataModel> getDashboardData() async {
    return const DashboardDataModel(
      patientName: 'Patient',
      assignedExercise: 'Elbow Flexion',
      streakDays: 3,
      recoveryPercentage: 65.0,
    );
  }
}
