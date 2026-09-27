import '../../domain/entities/session_summary_entity.dart';
import '../../domain/repositories/session_summary_repository.dart';
import '../datasources/session_summary_remote_data_source.dart';

class SessionSummaryRepositoryImpl implements SessionSummaryRepository {
  final SessionSummaryRemoteDataSource remoteDataSource;

  const SessionSummaryRepositoryImpl(this.remoteDataSource);

  @override
  Future<SessionSummaryEntity> getSummary(String sessionId) {
    return remoteDataSource.getSummary(sessionId);
  }
}
