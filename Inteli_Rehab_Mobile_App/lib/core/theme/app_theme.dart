import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic colors for Inteli-Rehab supporting both Light and Dark themes.
/// Conforms to WCAG AA contrast requirements (>= 4.5:1 for normal text, >= 3:1 for large text and controls).
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color pageBackground;
  final Color cardSurface;
  final Color inputSurface;
  final Color primaryButton;
  final Color primaryButtonText;
  final Color heading;
  final Color bodyText;
  final Color secondaryText;
  final Color border;
  final Color inputBorder;
  final Color inputFocusBorder;
  final Color infoSurface;
  final Color infoText;
  final Color errorBackground;
  final Color errorText;
  final Color errorBorder;
  final Color previewBannerBackground;
  final Color previewBannerText;
  final Color previewBannerBorder;

  const AppThemeColors({
    required this.pageBackground,
    required this.cardSurface,
    required this.inputSurface,
    required this.primaryButton,
    required this.primaryButtonText,
    required this.heading,
    required this.bodyText,
    required this.secondaryText,
    required this.border,
    required this.inputBorder,
    required this.inputFocusBorder,
    required this.infoSurface,
    required this.infoText,
    required this.errorBackground,
    required this.errorText,
    required this.errorBorder,
    required this.previewBannerBackground,
    required this.previewBannerText,
    required this.previewBannerBorder,
  });

  /// Light Theme Palette per Inteli-Rehab design specifications.
  static const light = AppThemeColors(
    pageBackground: Color(0xFFF5F8F7), // #F5F8F7 Page background
    cardSurface: Color(0xFFFFFFFF), // #FFFFFF Cards and input surfaces
    inputSurface: Color(0xFFFFFFFF),
    primaryButton: Color(0xFF0D6E76), // #0D6E76 Primary buttons and links
    primaryButtonText: Color(0xFFFFFFFF), // #FFFFFF Button text
    heading: Color(0xFF093D42), // #093D42 Headings
    bodyText: Color(0xFF12242B), // #12242B Body text
    secondaryText: Color(0xFF4C6360), // #4C6360 Secondary text
    border: Color(0xFFDEE7E5), // #DEE7E5 Borders
    inputBorder: Color(
      0xFF647B78,
    ), // Clearly visible input boundary (achieves >= 3:1 contrast against white)
    inputFocusBorder: Color(0xFF0D6E76), // Strong focus outline
    infoSurface: Color(0xFFE4F1F0), // #E4F1F0 Soft teal information surfaces
    infoText: Color(0xFF093D42), // #093D42 Text on information surfaces
    errorBackground: Color(0xFFFCE8E6), // Error background light
    errorText: Color(0xFFB3261E), // Error text light
    errorBorder: Color(0xFFF7B2AD),
    previewBannerBackground: Color(0xFFFEF3E2),
    previewBannerText: Color(0xFF8A5314),
    previewBannerBorder: Color(0xFFF5D3A6),
  );

  /// Dark Theme Palette per Inteli-Rehab design specifications.
  static const dark = AppThemeColors(
    pageBackground: Color(0xFF0B2023), // #0B2023 Page background
    cardSurface: Color(0xFF102F32), // #102F32 Cards and input surfaces
    inputSurface: Color(0xFF102F32),
    primaryButton: Color(
      0xFF31E8C6,
    ), // #31E8C6 Primary buttons and links (bright mint)
    primaryButtonText: Color(
      0xFF093D42,
    ), // #093D42 Text on mint buttons (dark text on bright mint)
    heading: Color(0xFFF1F7F6), // #F1F7F6 Headings and body text
    bodyText: Color(0xFFF1F7F6),
    secondaryText: Color(0xFFB6CBC8), // #B6CBC8 Secondary text
    border: Color(0xFF365356), // #365356 Borders
    inputBorder: Color(
      0xFF4A6F73,
    ), // Clearly visible boundary on dark background
    inputFocusBorder: Color(0xFF31E8C6), // Strong focus outline (bright mint)
    infoSurface: Color(0xFF163E3D), // #163E3D Soft teal information surfaces
    infoText: Color(0xFFC4F5EA), // #C4F5EA Text on information surfaces
    errorBackground: Color(0xFF4A2020), // Error background dark
    errorText: Color(0xFFFFB4AB), // Error text dark
    errorBorder: Color(0xFF7E353B),
    previewBannerBackground: Color(0xFF2C2213),
    previewBannerText: Color(0xFFFDD89B),
    previewBannerBorder: Color(0xFF5D4823),
  );

  @override
  AppThemeColors copyWith({
    Color? pageBackground,
    Color? cardSurface,
    Color? inputSurface,
    Color? primaryButton,
    Color? primaryButtonText,
    Color? heading,
    Color? bodyText,
    Color? secondaryText,
    Color? border,
    Color? inputBorder,
    Color? inputFocusBorder,
    Color? infoSurface,
    Color? infoText,
    Color? errorBackground,
    Color? errorText,
    Color? errorBorder,
    Color? previewBannerBackground,
    Color? previewBannerText,
    Color? previewBannerBorder,
  }) {
    return AppThemeColors(
      pageBackground: pageBackground ?? this.pageBackground,
      cardSurface: cardSurface ?? this.cardSurface,
      inputSurface: inputSurface ?? this.inputSurface,
      primaryButton: primaryButton ?? this.primaryButton,
      primaryButtonText: primaryButtonText ?? this.primaryButtonText,
      heading: heading ?? this.heading,
      bodyText: bodyText ?? this.bodyText,
      secondaryText: secondaryText ?? this.secondaryText,
      border: border ?? this.border,
      inputBorder: inputBorder ?? this.inputBorder,
      inputFocusBorder: inputFocusBorder ?? this.inputFocusBorder,
      infoSurface: infoSurface ?? this.infoSurface,
      infoText: infoText ?? this.infoText,
      errorBackground: errorBackground ?? this.errorBackground,
      errorText: errorText ?? this.errorText,
      errorBorder: errorBorder ?? this.errorBorder,
      previewBannerBackground:
          previewBannerBackground ?? this.previewBannerBackground,
      previewBannerText: previewBannerText ?? this.previewBannerText,
      previewBannerBorder: previewBannerBorder ?? this.previewBannerBorder,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      inputSurface: Color.lerp(inputSurface, other.inputSurface, t)!,
      primaryButton: Color.lerp(primaryButton, other.primaryButton, t)!,
      primaryButtonText: Color.lerp(
        primaryButtonText,
        other.primaryButtonText,
        t,
      )!,
      heading: Color.lerp(heading, other.heading, t)!,
      bodyText: Color.lerp(bodyText, other.bodyText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      border: Color.lerp(border, other.border, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      inputFocusBorder: Color.lerp(
        inputFocusBorder,
        other.inputFocusBorder,
        t,
      )!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      infoText: Color.lerp(infoText, other.infoText, t)!,
      errorBackground: Color.lerp(errorBackground, other.errorBackground, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      previewBannerBackground: Color.lerp(
        previewBannerBackground,
        other.previewBannerBackground,
        t,
      )!,
      previewBannerText: Color.lerp(
        previewBannerText,
        other.previewBannerText,
        t,
      )!,
      previewBannerBorder: Color.lerp(
        previewBannerBorder,
        other.previewBannerBorder,
        t,
      )!,
    );
  }
}

/// Clinical Brand Theme matching https://inteli-rehab.vercel.app/ exactly.
class AppTheme {
  AppTheme._();

  /// Semantic accessor for AppThemeColors from context.
  static AppThemeColors colors(BuildContext context) {
    return Theme.of(context).extension<AppThemeColors>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppThemeColors.dark
            : AppThemeColors.light);
  }

  // ─── Direct Constants for Backward Compatibility / Global Use ─────────────
  static const Color navy = Color(0xFF093D42);
  static const Color navyMid = Color(0xFF102F32);
  static const Color navyLight = Color(0xFF365356);
  static const Color primaryTeal = Color(0xFF0D6E76);
  static const Color primaryTealDark = Color(0xFF093D42);
  static const Color tealLight = Color(0xFFE4F1F0);
  static const Color tealBright = Color(0xFF31E8C6);
  static const Color tealSoftBackground = Color(0xFFE4F1F0);
  static const Color backgroundWhite = Color(0xFFF5F8F7);
  static const Color surfaceWhite = Colors.white;

  // ─── Status, Severity & Biological Feedback ────────────────────────────────
  static const Color amber = Color(0xFFE7A24C);
  static const Color amberLight = Color(0xFFFDF1E4);
  static const Color amberDim = Color(0xFFA76316);
  static const Color red = Color(0xFFB3261E);
  static const Color redLight = Color(0xFFFCE8E6);
  static const Color green = Color(0xFF4C9F70);
  static const Color greenLight = Color(0xFFE9F5EC);

  // ─── Neutrals & Hardware Accents ───────────────────────────────────────────
  static const Color slate50 = Color(0xFFF5F8F7);
  static const Color slate100 = Color(0xFFEEF4F3);
  static const Color slate200 = Color(0xFFDEE7E5);
  static const Color slate400 = Color(0xFF4C6360);
  static const Color slate500 = Color(0xFF5A6F6B);
  static const Color slate600 = Color(0xFF647B78);
  static const Color slate800 = Color(0xFF12242B);
  static const Color sensorGrey = Color(0xFF37474F);
  static const Color peachAccent = Color(0xFFFFB088);

  // ─── Typography (Sora for Headings, Manrope for Body) ───────────────────────
  static TextTheme _buildTextTheme({
    required Color headingColor,
    required Color bodyColor,
    required Color secondaryColor,
  }) {
    return TextTheme(
      headlineLarge: GoogleFonts.sora(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: headingColor,
      ),
      headlineMedium: GoogleFonts.sora(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: headingColor,
      ),
      headlineSmall: GoogleFonts.sora(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: headingColor,
      ),
      titleLarge: GoogleFonts.sora(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: headingColor,
      ),
      titleMedium: GoogleFonts.sora(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: headingColor,
      ),
      titleSmall: GoogleFonts.sora(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: headingColor,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: bodyColor,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: bodyColor,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: secondaryColor,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: headingColor,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
      ),
    );
  }

  // ─── Light Clinical Theme ──────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: GoogleFonts.manrope().fontFamily,
    extensions: const [AppThemeColors.light],
    textTheme: _buildTextTheme(
      headingColor: AppThemeColors.light.heading,
      bodyColor: AppThemeColors.light.bodyText,
      secondaryColor: AppThemeColors.light.secondaryText,
    ),
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF0D6E76),
      onPrimary: Color(0xFFFFFFFF),
      secondary: Color(0xFF31E8C6),
      onSecondary: Color(0xFF093D42),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF12242B),
      error: Color(0xFFB3261E),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFCE8E6),
      onErrorContainer: Color(0xFFB3261E),
      outline: Color(0xFFDEE7E5),
      outlineVariant: Color(0xFFDEE7E5),
    ),
    scaffoldBackgroundColor: AppThemeColors.light.pageBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppThemeColors.light.heading),
      titleTextStyle: GoogleFonts.sora(
        color: AppThemeColors.light.heading,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppThemeColors.light.cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppThemeColors.light.border, width: 1.2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppThemeColors.light.primaryButton,
        foregroundColor: AppThemeColors.light.primaryButtonText,
        disabledBackgroundColor: const Color(0xFFDEE7E5),
        disabledForegroundColor: const Color(0xFF8AA8A3),
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppThemeColors.light.primaryButton,
        foregroundColor: AppThemeColors.light.primaryButtonText,
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppThemeColors.light.primaryButton,
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        side: BorderSide(color: AppThemeColors.light.primaryButton, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppThemeColors.light.primaryButton,
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppThemeColors.light.inputSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppThemeColors.light.inputBorder,
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppThemeColors.light.inputBorder,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppThemeColors.light.inputFocusBorder,
          width: 2.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppThemeColors.light.errorText,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppThemeColors.light.errorText,
          width: 2.0,
        ),
      ),
      prefixIconColor: AppThemeColors.light.primaryButton,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: GoogleFonts.manrope(
        fontSize: 15,
        color: AppThemeColors.light.secondaryText,
      ),
      hintStyle: GoogleFonts.manrope(
        fontSize: 15,
        color: AppThemeColors.light.secondaryText.withValues(alpha: 0.75),
      ),
      errorStyle: GoogleFonts.manrope(
        fontSize: 14,
        color: AppThemeColors.light.errorText,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  // ─── Dark Clinical Theme ───────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: GoogleFonts.manrope().fontFamily,
    extensions: const [AppThemeColors.dark],
    textTheme: _buildTextTheme(
      headingColor: AppThemeColors.dark.heading,
      bodyColor: AppThemeColors.dark.bodyText,
      secondaryColor: AppThemeColors.dark.secondaryText,
    ),
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF31E8C6), // Mint
      onPrimary: Color(0xFF093D42), // Dark text on mint
      secondary: Color(0xFF0D6E76),
      onSecondary: Color(0xFFFFFFFF),
      surface: Color(0xFF102F32),
      onSurface: Color(0xFFF1F7F6),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF4A2020),
      errorContainer: Color(0xFF4A2020),
      onErrorContainer: Color(0xFFFFB4AB),
      outline: Color(0xFF365356),
      outlineVariant: Color(0xFF365356),
    ),
    scaffoldBackgroundColor: AppThemeColors.dark.pageBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppThemeColors.dark.heading),
      titleTextStyle: GoogleFonts.sora(
        color: AppThemeColors.dark.heading,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppThemeColors.dark.cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppThemeColors.dark.border, width: 1.2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppThemeColors.dark.primaryButton, // Bright mint
        foregroundColor:
            AppThemeColors.dark.primaryButtonText, // Dark text on mint!
        disabledBackgroundColor: const Color(0xFF1A383B),
        disabledForegroundColor: const Color(0xFF5A7B7E),
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppThemeColors.dark.primaryButton,
        foregroundColor: AppThemeColors.dark.primaryButtonText,
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppThemeColors.dark.primaryButton,
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        side: BorderSide(color: AppThemeColors.dark.primaryButton, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppThemeColors.dark.primaryButton,
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppThemeColors.dark.inputSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppThemeColors.dark.inputBorder,
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppThemeColors.dark.inputBorder,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppThemeColors.dark.inputFocusBorder,
          width: 2.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppThemeColors.dark.errorText,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppThemeColors.dark.errorText,
          width: 2.0,
        ),
      ),
      prefixIconColor: AppThemeColors.dark.primaryButton,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: GoogleFonts.manrope(
        fontSize: 15,
        color: AppThemeColors.dark.secondaryText,
      ),
      hintStyle: GoogleFonts.manrope(
        fontSize: 15,
        color: AppThemeColors.dark.secondaryText.withValues(alpha: 0.75),
      ),
      errorStyle: GoogleFonts.manrope(
        fontSize: 14,
        color: AppThemeColors.dark.errorText,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
