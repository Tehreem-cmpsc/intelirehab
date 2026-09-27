abstract class AuthEvent {
  const AuthEvent();
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  const LoginRequested({required this.email, required this.password});
}

class RegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  const RegisterRequested({required this.email, required this.password, required this.name});
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}
