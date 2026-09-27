import '../../domain/entities/session_replay_entity.dart';
import '../../domain/repositories/session_replay_repository.dart';
import '../datasources/session_replay_remote_data_source.dart';

class SessionReplayRepositoryImpl implements SessionReplayRepository {
  final SessionReplayRemoteDataSource remoteDataSource;

  const SessionReplayRepositoryImpl(this.remoteDataSource);

  @override
  Future<SessionReplayEntity> getReplayData(String sessionId) {
    return remoteDataSource.getReplayData(sessionId);
  }
}
