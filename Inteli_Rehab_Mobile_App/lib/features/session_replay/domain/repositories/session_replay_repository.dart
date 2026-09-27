import '../entities/session_replay_entity.dart';

abstract class SessionReplayRepository {
  Future<SessionReplayEntity> getReplayData(String sessionId);
}
