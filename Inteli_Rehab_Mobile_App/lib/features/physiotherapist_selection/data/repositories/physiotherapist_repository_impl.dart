import '../../domain/entities/physiotherapist_entity.dart';
import '../../domain/repositories/physiotherapist_repository.dart';
import '../datasources/physiotherapist_remote_data_source.dart';

class PhysiotherapistRepositoryImpl implements PhysiotherapistRepository {
  final PhysiotherapistRemoteDataSource remoteDataSource;

  const PhysiotherapistRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<PhysiotherapistEntity>> getPhysiotherapists(String clinicId) {
    return remoteDataSource.getPhysiotherapists(clinicId);
  }
}
