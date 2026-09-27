import 'session_summary_state.dart';

class SessionSummaryCubit {
  SessionSummaryState _state = const SessionSummaryInitial();
  SessionSummaryState get state => _state;

  void emit(SessionSummaryState newState) {
    _state = newState;
  }

  void loadSummary(String sessionId) {}
}
