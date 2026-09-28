import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/auth_repository.dart';

/// In-memory fake authentication repository for frontend-only development and preview.
///
/// Rules:
/// 1. In-memory state only (zero network calls, zero Supabase interaction).
/// 2. Throws [UnsupportedError] in release mode ([kReleaseMode]).
/// 3. Enforces 30-minute inactivity session expiry.
/// 4. Provides controllable failure toggle for test harness.
class AuthRepositoryFake implements AuthRepository {
  AuthRepositoryFake({bool allowInReleaseForTesting = false})
    : _allowInRelease = allowInReleaseForTesting {
    _assertNotReleaseMode();
  }

  final bool _allowInRelease;
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  bool _isAuthenticated = false;
  String? _currentUserEmail;
  DateTime? _lastActiveTime;
  bool _simulateFailure = false;
  bool _simulateNetworkFailure = false;

  void _assertNotReleaseMode() {
    if (kReleaseMode && !_allowInRelease) {
      throw const AuthReleaseModeException();
    }
  }

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  String? get currentUserEmail => _currentUserEmail;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _assertNotReleaseMode();

    // Simulate minimal realistic async dispatch delay
    await Future<void>.delayed(const Duration(milliseconds: 150));

    if (_simulateNetworkFailure) {
      throw const AuthNetworkException();
    }

    if (_simulateFailure) {
      throw const InvalidCredentialsException();
    }

    _isAuthenticated = true;
    _currentUserEmail = email;
    _lastActiveTime = DateTime.now();
    _authStateController.add(true);
  }

  @override
  Future<void> registerWithRegId({
    required String email,
    required String password,
    required String regId,
  }) async {
    _assertNotReleaseMode();

    await Future<void>.delayed(const Duration(milliseconds: 150));

    if (_simulateFailure) {
      throw Exception('Registration rejected. Invalid Clinic Registration ID.');
    }

    // Frontend preview: Accepts input without storing data to any backend.
    // User is redirected back to login with a preview notification.
  }

  @override
  Future<void> signOut() async {
    _isAuthenticated = false;
    _currentUserEmail = null;
    _lastActiveTime = null;
    _authStateController.add(false);
  }

  @override
  void checkSessionExpiry() {
    if (!_isAuthenticated || _lastActiveTime == null) return;

    final elapsed = DateTime.now().difference(_lastActiveTime!);
    if (elapsed >= const Duration(minutes: 30)) {
      _isAuthenticated = false;
      _currentUserEmail = null;
      _lastActiveTime = null;
      _authStateController.add(false);
    }
  }

  @override
  void recordActivity() {
    if (_isAuthenticated) {
      _lastActiveTime = DateTime.now();
    }
  }

  @override
  void setSimulateFailure(bool shouldFail) {
    _simulateFailure = shouldFail;
  }

  /// Testing control: toggles simulated network/connection failure.
  void setSimulateNetworkFailure(bool shouldFail) {
    _simulateNetworkFailure = shouldFail;
  }

  @override
  void setLastActiveTimeForTesting(DateTime time) {
    _lastActiveTime = time;
  }

  void dispose() {
    _authStateController.close();
  }
}
