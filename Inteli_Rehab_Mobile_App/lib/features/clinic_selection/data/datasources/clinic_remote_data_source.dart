import '../models/clinic_model.dart';

abstract class ClinicRemoteDataSource {
  Future<List<ClinicModel>> getClinics();
}

class ClinicRemoteDataSourceImpl implements ClinicRemoteDataSource {
  @override
  Future<List<ClinicModel>> getClinics() async {
    return [];
  }
}
