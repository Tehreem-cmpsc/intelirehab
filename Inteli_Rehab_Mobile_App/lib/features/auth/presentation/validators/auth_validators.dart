/// Pure validation logic separated from UI widgets.
/// Follows HCI error-prevention principles: provides explicit, actionable guidance.
class AuthValidators {
  AuthValidators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  /// Trims and converts email to lower case according to security standards.
  static String normalizeEmail(String? rawEmail) {
    if (rawEmail == null) return '';
    return rawEmail.trim().toLowerCase();
  }

  /// Validates email address.
  /// Returns null if valid, or an explicit correction message.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your email address.';
    }
    final trimmed = value.trim();
    if (!trimmed.contains('@') || !_emailRegExp.hasMatch(trimmed)) {
      return 'Enter an email address such as you@example.com.';
    }
    return null;
  }

  /// Validates existing password for login.
  /// Follows authentication contract: does not silently enforce new-password length policies at sign-in.
  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your password.';
    }
    return null;
  }

  /// Validates new password policy for patient registration (minimum 8 characters).
  static String? validateRegisterPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your password.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    return null;
  }

  /// Backward-compatible alias for registration password validation.
  static String? validatePassword(String? value) =>
      validateRegisterPassword(value);

  static final RegExp _regIdCharsRegExp = RegExp(r'^[a-zA-Z0-9\-_]+$');

  /// Validates clinic-issued patient registration ID (e.g. "REG-101", "AMC-004", "CLI_09").
  static String? validateClinicRegId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your clinic registration ID.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Registration ID must be at least 3 characters long.';
    }
    if (trimmed.length > 20) {
      return 'Registration ID cannot exceed 20 characters.';
    }
    if (!_regIdCharsRegExp.hasMatch(trimmed)) {
      return 'Registration ID may only contain letters, numbers, hyphens, and underscores.';
    }
    return null;
  }

  /// Determines if the sign-in form is ready for submission.
  static bool isLoginFormValid({
    required String? email,
    required String? password,
  }) {
    return validateEmail(email) == null &&
        validateLoginPassword(password) == null;
  }

  /// Determines if the registration form is ready for submission.
  static bool isRegisterFormValid({
    required String? regId,
    required String? email,
    required String? password,
  }) {
    return validateClinicRegId(regId) == null &&
        validateEmail(email) == null &&
        validateRegisterPassword(password) == null;
  }
}
