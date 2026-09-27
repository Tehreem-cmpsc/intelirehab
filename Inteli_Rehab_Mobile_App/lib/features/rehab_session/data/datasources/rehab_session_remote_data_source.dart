import '../models/rehab_session_model.dart';

abstract class RehabSessionRemoteDataSource {
  Future<void> saveSession(RehabSessionModel model);
}

class RehabSessionRemoteDataSourceImpl implements RehabSessionRemoteDataSource {
  @override
  Future<void> saveSession(RehabSessionModel model) async {}
}
