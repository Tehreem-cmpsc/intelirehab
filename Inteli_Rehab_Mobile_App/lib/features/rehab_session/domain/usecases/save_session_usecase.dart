import '../entities/rehab_session_entity.dart';
import '../repositories/rehab_session_repository.dart';

class SaveSessionUsecase {
  final RehabSessionRepository repository;
  const SaveSessionUsecase(this.repository);

  Future<void> call(RehabSessionEntity session) {
    return repository.saveSession(session);
  }
}
