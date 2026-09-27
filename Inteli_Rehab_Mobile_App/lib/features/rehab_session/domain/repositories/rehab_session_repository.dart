import '../entities/rehab_session_entity.dart';

abstract class RehabSessionRepository {
  Future<void> startSession(String exerciseId);
  Future<void> saveSession(RehabSessionEntity session);
}
