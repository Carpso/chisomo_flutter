import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFE65100); // deep orange
  static const primaryLight = Color(0xFFFF8A50);
  static const primarySoft = Color(0xFFFFE0D0); // very light orange
  static const gold = Color(0xFFD4A017);
  static const background = Color(0xFFFBF7F4);
  static const surface = Colors.white;
  static const textDark = Color(0xFF2B2018);
  static const textMuted = Color(0xFF7A6A5C);
  static const danger = Color(0xFFC62828);

  // Accent colors for campaigns and cards
  static const campaignAccent1 = Color(0xFF8E5BA6); // Purple
  static const campaignAccent2 = Color(0xFF9B6B43); // Brown
  static const campaignAccent3 = Color(0xFF5B8C5A); // Green
  static const campaignAccent4 = Color(0xFF4A90E2); // Blue
  static const campaignAccent5 = Color(0xFFE57200); // Amber
  static const campaignAccent6 = Color(0xFFD0026B); // Rose

  static const campaignAccents = [
    campaignAccent1,
    campaignAccent2,
    campaignAccent3,
    campaignAccent4,
    campaignAccent5,
    campaignAccent6,
  ];

  /// Deterministic accent color for a campaign/card based on its id.
  static Color accentFor(int seed) =>
      campaignAccents[seed.abs() % campaignAccents.length];
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.gold,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE0E6E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE0E6E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.primarySoft,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
    ),
  );
}
