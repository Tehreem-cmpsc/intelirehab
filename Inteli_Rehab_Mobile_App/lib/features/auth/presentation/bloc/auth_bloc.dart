import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc {
  AuthState _state = const AuthInitial();
  AuthState get state => _state;

  void emit(AuthState newState) {
    _state = newState;
  }

  void add(AuthEvent event) {
    // Process auth events
  }
}
