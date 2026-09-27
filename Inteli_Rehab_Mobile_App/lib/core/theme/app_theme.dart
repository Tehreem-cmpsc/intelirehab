import 'package:flutter/material.dart';

class AppTheme {
  // ─── Teal Green Palette from Logo ──────────────────────────────────────────
  static const Color primaryTealDark = Color(0xFF0F7159);   // Deep teal curve
  static const Color primaryTeal = Color(0xFF149B7B);       // Vibrant teal body
  static const Color tealLight = Color(0xFF27BA9B);          // Bright accent teal
  static const Color tealSoftBackground = Color(0xFFE8F7F4); // Pale teal tint
  static const Color tealPulse = Color(0xFF38E1C2);         // Neon teal sensor pulse

  // ─── Arm / Sensor Accent Colors ───────────────────────────────────────────
  static const Color peachAccent = Color(0xFFFFB088);       // Warm recovery glow
  static const Color sensorGrey = Color(0xFF37474F);        // Wearable band dark grey
  static const Color backgroundWhite = Color(0xFFF9FBFB);   // Clean medical white
  static const Color surfaceWhite = Colors.white;

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryTeal,
          primary: primaryTealDark,
          secondary: tealLight,
          tertiary: peachAccent,
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryTealDark,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryTealDark,
            side: const BorderSide(color: primaryTeal, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryTeal, width: 2),
          ),
          prefixIconColor: primaryTeal,
        ),
      );
}
