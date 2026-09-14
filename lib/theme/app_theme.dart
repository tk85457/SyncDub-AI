import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Emerald Accent System
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDim = Color(0x2110B981); // rgba(16, 185, 129, 0.13)
  static const Color emeraldGlow = Color(0x4710B981); // rgba(16, 185, 129, 0.28)

  // Status Colors
  static const Color warn = Color(0xFFF59E0B);
  static const Color amber = Color(0xFFF59E0B);
  static const Color warnDim = Color(0x21F59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerDim = Color(0x21EF4444);

  // Light Mode Tokens (Exact Prototype)
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF8FAFC);
  static const Color lightSurface2 = Color(0xFFF1F5F9);
  static const Color lightSurfaceSubtle = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Mode Tokens (Exact Prototype)
  static const Color darkBg = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurface2 = Color(0xFF1E293B);
  static const Color darkSurfaceSubtle = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF475569);

  // Dynamic Token Helpers
  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color surface2(bool isDark) => isDark ? darkSurface2 : lightSurface2;
  static Color surfaceElevated(bool isDark) => isDark ? darkSurface2 : lightSurface2;
  static Color border(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color textPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color textMuted(bool isDark) => isDark ? darkTextMuted : lightTextMuted;

  static Color ctaBg(bool isDark) => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color ctaFg(bool isDark) => isDark ? const Color(0xFF090D16) : const Color(0xFFFFFFFF);

  static ThemeData get lightTheme {
    final base = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: lightTextPrimary,
        surface: lightSurface,
        onSurface: lightTextPrimary,
      ),
      textTheme: base,
    );
  }

  static ThemeData get darkTheme {
    final base = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: darkTextPrimary,
        surface: darkSurface,
        onSurface: darkTextPrimary,
      ),
      textTheme: base,
    );
  }
}
