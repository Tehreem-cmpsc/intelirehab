import '../entities/progress_record_entity.dart';
import '../repositories/progress_repository.dart';

class GetProgressUsecase {
  final ProgressRepository repository;
  const GetProgressUsecase(this.repository);

  Future<List<ProgressRecordEntity>> call() {
    return repository.getProgressHistory();
  }
}
