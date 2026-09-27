import '../models/progress_record_model.dart';

abstract class ProgressRemoteDataSource {
  Future<List<ProgressRecordModel>> getProgressHistory();
}

class ProgressRemoteDataSourceImpl implements ProgressRemoteDataSource {
  @override
  Future<List<ProgressRecordModel>> getProgressHistory() async {
    return [];
  }
}
