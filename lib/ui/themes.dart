import 'package:flutter/material.dart';

class AppThemes {
  // 🌌 SuperGravity: Aurora Obsidian Color Palette
  static const Color bgDark = Color(0xFF05070A); // Deep Galactic Ink
  static const Color surfaceDark = Color(0xFF0F172A); // Frosted Obsidian
  static const Color surfaceCard = Color(0xFF161B22); // Elevated Obsidian
  static const Color inputBg = Color(0xFF0B101A); // Dark Bridge

  // ⚡ Energy Accents
  static const Color accentCyan = Color(0xFF00F5FF); // Electric Aurora
  static const Color accentCyanSoft = Color(0xFF0099B3);
  static const Color accentCobalt = Color(0xFF2E3192); // Deep Space Cobalt
  static const Color accentGold = Color(0xFFFFD700); // Sun-Flare Gold
  static const Color accentGreen = Color(0xFF4ADE80); // Success Emerald

  // 📝 Typography Colors
  static const Color textPrimary = Color(0xFFF8FAFC); // Silken Pearl
  static const Color textSecondary = Color(0xFF94A3B8); // Muted Steel
  static const Color dividerColor = Color(0xFF1E293B); // Thin Light-Line
  static const Color errorRed = Color(0xFFFF2D55); // Neon Crimson

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: accentCyan,
    scaffoldBackgroundColor: bgDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
        letterSpacing: -0.5,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: accentCyan,
      secondary: accentGold,
      surface: surfaceDark,
      error: errorRed,
      onPrimary: bgDark,
      onSurface: textPrimary,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:
          Colors.transparent, // Floating glassmorphism will handle bg
      selectedItemColor: accentCyan,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: dividerColor, thickness: 0.5),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: dividerColor, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: dividerColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: dividerColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: accentCyan, width: 1.5),
      ),
      hintStyle: const TextStyle(color: textSecondary, fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentCyan,
        foregroundColor: bgDark,
        elevation: 8,
        shadowColor: accentCyan.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    useMaterial3: true,
    fontFamily: 'Inter',
  );

  // Light theme stub (SuperGravity is meant to be Dark Mode native)
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: accentCyan,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    useMaterial3: true,
    fontFamily: 'Inter',
  );
}
