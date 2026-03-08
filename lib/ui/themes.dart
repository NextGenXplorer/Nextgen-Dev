import 'package:flutter/material.dart';

class AppThemes {
  // Kimi-style color tokens
  static const Color bgDark = Color(0xFF111111);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color surfaceCard = Color(0xFF222224);
  static const Color inputBg = Color(0xFF222224);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentBlueSoft = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color dividerColor = Color(0xFF2C2C2E);
  static const Color errorRed = Color(0xFF7A1515);

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: accentBlue,
    scaffoldBackgroundColor: bgDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: bgDark,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: accentBlue,
      secondary: accentBlueSoft,
      surface: surfaceDark,
      error: errorRed,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      selectedItemColor: accentBlue,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: dividerColor,
      thickness: 0.5,
    ),
    cardTheme: CardThemeData(
      color: surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: textSecondary, fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    useMaterial3: true,
    fontFamily: 'Inter',
  );

  // Keep light theme for future preference toggle
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: accentBlue,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
    useMaterial3: true,
    fontFamily: 'Inter',
  );
}
