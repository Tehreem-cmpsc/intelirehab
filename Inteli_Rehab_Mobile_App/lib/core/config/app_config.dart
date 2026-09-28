/// App-level runtime configuration.
class AppConfig {
  AppConfig._();

  /// Flag indicating whether the app is currently running in frontend-only preview mode.
  /// 
  /// When `true`:
  /// - Real Supabase network initialization is skipped.
  /// - In-memory fake repositories are used across all screens.
  /// - Honest preview notices are presented to patients.
  /// - Backend integration will be integrated by Tehreem.
  static const bool isFrontendPreview = true;
}
