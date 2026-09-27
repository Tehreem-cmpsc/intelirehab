import '../../domain/entities/progress_record_entity.dart';
import '../../domain/repositories/progress_repository.dart';
import '../datasources/progress_remote_data_source.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  final ProgressRemoteDataSource remoteDataSource;

  const ProgressRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<ProgressRecordEntity>> getProgressHistory() {
    return remoteDataSource.getProgressHistory();
  }
}
