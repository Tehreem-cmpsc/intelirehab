import '../repositories/rehab_session_repository.dart';

class StartSessionUsecase {
  final RehabSessionRepository repository;
  const StartSessionUsecase(this.repository);

  Future<void> call(String exerciseId) {
    return repository.startSession(exerciseId);
  }
}
