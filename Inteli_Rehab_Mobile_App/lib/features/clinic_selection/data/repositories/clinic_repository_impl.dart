import '../../domain/entities/clinic_entity.dart';
import '../../domain/repositories/clinic_repository.dart';
import '../datasources/clinic_remote_data_source.dart';

class ClinicRepositoryImpl implements ClinicRepository {
  final ClinicRemoteDataSource remoteDataSource;

  const ClinicRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<ClinicEntity>> getClinics() {
    return remoteDataSource.getClinics();
  }
}
