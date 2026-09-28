import 'package:flutter/material.dart';

/// Colour tokens copied from the web portal's `.cp-root` variables
/// (Intelli_Rehab_Web_Portal/src/index.css) so the patient app and the
/// clinic portal read as one product. Dark values match the portal's
/// `[data-theme="dark"]` block.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color ink;
  final Color primary;
  final Color primaryDeep;
  final Color primaryTint;
  final Color onPrimary;
  final Color accent;
  final Color success;
  final Color successTint;
  final Color alert;
  final Color alertTint;
  final Color bg;
  final Color surface;
  final Color border;
  final Color muted;

  /// The portal login's hero panel gradient (primary-deep -> primary).
  /// Kept fixed-dark in dark mode so white header text stays legible.
  final Color headerStart;
  final Color headerEnd;

  const AppColors({
    required this.ink,
    required this.primary,
    required this.primaryDeep,
    required this.primaryTint,
    required this.onPrimary,
    required this.accent,
    required this.success,
    required this.successTint,
    required this.alert,
    required this.alertTint,
    required this.bg,
    required this.surface,
    required this.border,
    required this.muted,
    required this.headerStart,
    required this.headerEnd,
  });

  static const light = AppColors(
    ink: Color(0xFF12242B),
    primary: Color(0xFF0D6E76),
    primaryDeep: Color(0xFF073C41),
    primaryTint: Color(0xFFE4F1F0),
    onPrimary: Colors.white,
    accent: Color(0xFFE7A24C),
    success: Color(0xFF4C9F70),
    successTint: Color(0xFFE9F5EC),
    alert: Color(0xFFD96248),
    alertTint: Color(0xFFFBEAE5),
    bg: Color(0xFFF5F8F7),
    surface: Colors.white,
    border: Color(0xFFDEE7E5),
    muted: Color(0xFF4C6360),
    headerStart: Color(0xFF073C41),
    headerEnd: Color(0xFF0D6E76),
  );

  static const dark = AppColors(
    ink: Color(0xE0FFFFFF),
    primary: Color(0xFF31E8C6),
    primaryDeep: Color(0xFF1AADA0),
    primaryTint: Color(0x1F31E8C6),
    // White on #31E8C6 is unreadable; use the deep teal instead.
    onPrimary: Color(0xFF062A2E),
    accent: Color(0xFFF0B86E),
    success: Color(0xFF6CE09F),
    successTint: Color(0x264C9F70),
    alert: Color(0xFFF08070),
    alertTint: Color(0x26D96248),
    bg: Color(0xFF0F1F22),
    surface: Color(0xFF122B30),
    border: Color(0x1AFFFFFF),
    muted: Color(0xC7FFFFFF),
    headerStart: Color(0xFF0B2428),
    headerEnd: Color(0xFF134D52),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      ink: l(ink, other.ink),
      primary: l(primary, other.primary),
      primaryDeep: l(primaryDeep, other.primaryDeep),
      primaryTint: l(primaryTint, other.primaryTint),
      onPrimary: l(onPrimary, other.onPrimary),
      accent: l(accent, other.accent),
      success: l(success, other.success),
      successTint: l(successTint, other.successTint),
      alert: l(alert, other.alert),
      alertTint: l(alertTint, other.alertTint),
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      border: l(border, other.border),
      muted: l(muted, other.muted),
      headerStart: l(headerStart, other.headerStart),
      headerEnd: l(headerEnd, other.headerEnd),
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: c.primary, brightness: brightness).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.accent,
      error: c.alert,
      surface: c.surface,
      onSurface: c.ink,
      outline: c.border,
    );

    final radius = BorderRadius.circular(10);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: color, width: width));

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    final text = base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink);

    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: text.bodyMedium?.copyWith(color: c.muted, height: 1.45),
        bodySmall: text.bodySmall?.copyWith(color: c.muted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border(c.border),
        enabledBorder: border(c.border),
        focusedBorder: border(c.primary, 1.5),
        errorBorder: border(c.alert),
        focusedErrorBorder: border(c.alert, 1.5),
        hintStyle: TextStyle(color: c.muted.withValues(alpha: 0.7)),
        labelStyle: TextStyle(color: c.muted),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        errorStyle: TextStyle(color: c.alert),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.primary.withValues(alpha: 0.4),
          disabledForegroundColor: c.onPrimary.withValues(alpha: 0.8),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.border),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : null),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
        side: BorderSide(color: c.muted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.primaryDeep,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    );
  }
}
