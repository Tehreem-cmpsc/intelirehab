import 'package:flutter/material.dart';

/// Clinical Brand Theme matching https://inteli-rehab.vercel.app/ exactly.
class AppTheme {
  // ─── Exact Web Portal Palette ──────────────────────────────────────────────
  static const Color navy = Color(0xFF093D42);         // #093D42 Deep Portal Navy/Teal
  static const Color navyMid = Color(0xFF134D52);      // #134D52
  static const Color navyLight = Color(0xFF1E5A61);    // #1E5A61
  static const Color primaryTeal = Color(0xFF0D6E76);  // #0D6E76 Primary Clinical Teal
  static const Color primaryTealDark = Color(0xFF073C41); // #073C41 Teal Dim / Deep Header
  static const Color tealLight = Color(0xFFE4F1F0);    // #E4F1F0 Soft Surface Tint
  static const Color tealBright = Color(0xFF31E8C6);   // #31E8C6 Sensor Pulse Neon Mint
  static const Color tealSoftBackground = Color(0xFFEEF4F3); // #EEF4F3 Slate 100
  static const Color backgroundWhite = Color(0xFFF5F8F7);   // #F5F8F7 Slate 50 Medical Base
  static const Color surfaceWhite = Colors.white;

  // ─── Status, Severity & Biological Feedback ────────────────────────────────
  static const Color amber = Color(0xFFE7A24C);        // #E7A24C Warning / Moderate Fatigue
  static const Color amberLight = Color(0xFFFDF1E4);   // #FDF1E4
  static const Color amberDim = Color(0xFFA76316);     // #A76316 Amber Dim from web theme
  static const Color red = Color(0xFFD96248);          // #D96248 High Fatigue / Muscle Strain
  static const Color redLight = Color(0xFFFBEAE5);     // #FBEAE5
  static const Color green = Color(0xFF4C9F70);        // #4C9F70 Good Form / Completed
  static const Color greenLight = Color(0xFFE9F5EC);   // #E9F5EC

  // ─── Neutrals & Hardware Accents ───────────────────────────────────────────
  static const Color slate50 = Color(0xFFF5F8F7);      // #F5F8F7 Slate 50
  static const Color slate100 = Color(0xFFEEF4F3);   // #EEF4F3 Slate 100
  static const Color slate200 = Color(0xFFDEE7E5);     // Border outline
  static const Color slate400 = Color(0xFF4C6360);     // Muted text
  static const Color slate500 = Color(0xFF5A6F6B);     // Secondary text
  static const Color slate600 = Color(0xFF647B78);     // Subtitles
  static const Color slate800 = Color(0xFF12242B);     // Deep body text
  static const Color sensorGrey = Color(0xFF37474F);    // Wearable hardware band
  static const Color peachAccent = Color(0xFFFFB088);   // Human joint anatomical accent

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: null,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryTeal,
          primary: primaryTeal,
          onPrimary: Colors.white,
          secondary: tealBright,
          surface: surfaceWhite,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: backgroundWhite,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: primaryTealDark),
          titleTextStyle: TextStyle(
            color: primaryTealDark,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: slate200, width: 1.2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryTeal,
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
            side: const BorderSide(color: primaryTeal, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: slate200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: slate200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryTeal, width: 2),
          ),
          prefixIconColor: primaryTeal,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(fontSize: 15, color: slate500),
          hintStyle: const TextStyle(fontSize: 15, color: slate400),
          errorStyle: const TextStyle(fontSize: 14, color: red),
        ),
      );
}
