import 'dart:async';

import '../../features/onboarding/onboarding_repository.dart';

/// Rule 26: no infinite spinners. Every screen load goes through this, so a
/// hung request falls back to the screen's error state (with Try again)
/// instead of spinning forever.
const loadTimeout = Duration(seconds: 15);

extension LoadGuard<T> on Future<T> {
  Future<T> guarded() => timeout(loadTimeout);
}

/// Plain-language text for a failed load — used by every error state.
String friendlyError(Object error, {String fallback = 'Something went wrong.'}) {
  if (error is OnboardingException) return error.message;
  if (error is TimeoutException) {
    return 'This is taking longer than usual. Check your connection and try again.';
  }
  return '$fallback Check your connection and try again.';
}
