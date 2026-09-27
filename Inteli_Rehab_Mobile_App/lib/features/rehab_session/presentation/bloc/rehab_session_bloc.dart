import 'rehab_session_event.dart';
import 'rehab_session_state.dart';

class RehabSessionBloc {
  RehabSessionState _state = const RehabSessionInitial();
  RehabSessionState get state => _state;

  void emit(RehabSessionState newState) {
    _state = newState;
  }

  void add(RehabSessionEvent event) {}
}
