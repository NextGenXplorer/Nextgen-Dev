import 'package:flutter/material.dart';

class AppThemes {
  // Premium Deep Dark Aesthetics
  static const Color bgDark = Color(0xFF0A0A0C);
  static const Color surfaceDark = Color(0xFF161618);
  static const Color surfaceCard = Color(0xFF1E1E22);
  static const Color inputBg = Color(0xFF161618);
  static const Color accentBlue = Color(0xFF4D90FE);
  static const Color accentBlueSoft = Color(0xFF3B7CEB);
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFFA0A0AB);
  static const Color dividerColor = Color(0xFF2A2A30);
  static const Color errorRed = Color(0xFFEF4444);

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
