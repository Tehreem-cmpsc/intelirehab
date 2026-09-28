import '../models/session_replay_model.dart';

abstract class SessionReplayRemoteDataSource {
  Future<SessionReplayModel> getReplayData(String sessionId);
}

class SessionReplayRemoteDataSourceImpl
    implements SessionReplayRemoteDataSource {
  @override
  Future<SessionReplayModel> getReplayData(String sessionId) async {
    return const SessionReplayModel(
      sessionId: '1',
      angleFrames: [],
      totalDuration: Duration(seconds: 60),
    );
  }
}
