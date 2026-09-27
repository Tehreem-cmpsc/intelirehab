import '../models/session_summary_model.dart';

abstract class SessionSummaryRemoteDataSource {
  Future<SessionSummaryModel> getSummary(String sessionId);
}

class SessionSummaryRemoteDataSourceImpl implements SessionSummaryRemoteDataSource {
  @override
  Future<SessionSummaryModel> getSummary(String sessionId) async {
    return const SessionSummaryModel(
      sessionId: '1',
      completedReps: 10,
      movementQuality: 'Excellent',
      romImproved: 5.0,
      consistencyScore: 85,
    );
  }
}
