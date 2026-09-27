import '../entities/session_replay_entity.dart';
import '../repositories/session_replay_repository.dart';

class GetSessionReplayDataUsecase {
  final SessionReplayRepository repository;
  const GetSessionReplayDataUsecase(this.repository);

  Future<SessionReplayEntity> call(String sessionId) {
    return repository.getReplayData(sessionId);
  }
}
