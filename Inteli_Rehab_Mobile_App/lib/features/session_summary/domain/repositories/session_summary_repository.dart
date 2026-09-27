import '../entities/session_summary_entity.dart';

abstract class SessionSummaryRepository {
  Future<SessionSummaryEntity> getSummary(String sessionId);
}
