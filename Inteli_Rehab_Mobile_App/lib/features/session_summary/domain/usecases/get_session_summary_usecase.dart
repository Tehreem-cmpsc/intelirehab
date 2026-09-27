import '../entities/session_summary_entity.dart';
import '../repositories/session_summary_repository.dart';

class GetSessionSummaryUsecase {
  final SessionSummaryRepository repository;
  const GetSessionSummaryUsecase(this.repository);

  Future<SessionSummaryEntity> call(String sessionId) {
    return repository.getSummary(sessionId);
  }
}
