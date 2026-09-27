abstract class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  final String userId;
  const Authenticated(this.userId);
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}
