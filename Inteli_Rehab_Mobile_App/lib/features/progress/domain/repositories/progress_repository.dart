import '../entities/progress_record_entity.dart';

abstract class ProgressRepository {
  Future<List<ProgressRecordEntity>> getProgressHistory();
}
