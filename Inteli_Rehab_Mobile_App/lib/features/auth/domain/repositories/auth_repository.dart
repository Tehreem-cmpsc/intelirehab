import 'dart:async';

/// Abstract repository interface for Authentication operations.
/// Pure Dart — zero Flutter or Supabase imports.
abstract class AuthRepository {
  /// Stream emitting authentication state changes (true if authenticated, false otherwise).
  Stream<bool> get authStateChanges;

  /// Current authentication status in-memory.
  bool get isAuthenticated;

  /// Email of the currently signed-in user, if any.
  String? get currentUserEmail;

  /// Signs in with email and password.
  Future<void> signIn({required String email, required String password});

  /// Registers a new patient with clinic-issued registration ID, email, and password.
  Future<void> registerWithRegId({
    required String email,
    required String password,
    required String regId,
  });

  /// Signs out and clears all in-memory session data.
  Future<void> signOut();

  /// Checks if the session has expired after 30 minutes of inactivity.
  void checkSessionExpiry();

  /// Records fresh user activity to refresh the 30-minute inactivity timer.
  void recordActivity();

  /// Testing control: toggles simulated authentication failure.
  void setSimulateFailure(bool shouldFail);

  /// Testing control: manually set the last activity timestamp to test expiry.
  void setLastActiveTimeForTesting(DateTime time);
}

/// Thrown when authentication fails due to incorrect credentials.
class InvalidCredentialsException implements Exception {
  final String message;
  const InvalidCredentialsException([
    this.message = 'Incorrect email or password.',
  ]);

  @override
  String toString() => message;
}

/// Thrown when authentication fails due to connectivity or backend outage.
class AuthNetworkException implements Exception {
  final String message;
  const AuthNetworkException([
    this.message = 'Unable to sign in right now. Please try again.',
  ]);

  @override
  String toString() => message;
}

/// Thrown when fake authentication is attempted in production release builds.
class AuthReleaseModeException implements Exception {
  final String message;
  const AuthReleaseModeException([
    this.message =
        'Preview authentication is disabled in production release builds. Backend integration is required.',
  ]);

  @override
  String toString() => message;
}
