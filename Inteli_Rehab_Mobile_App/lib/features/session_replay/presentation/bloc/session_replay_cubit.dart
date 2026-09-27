import 'session_replay_state.dart';

class SessionReplayCubit {
  SessionReplayState _state = const SessionReplayInitial();
  SessionReplayState get state => _state;

  void emit(SessionReplayState newState) {
    _state = newState;
  }

  void loadReplay(String sessionId) {}
}
