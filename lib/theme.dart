import 'package:flutter/material.dart';

class FloryColors {
  static const background   = Color(0xFF0A1E1E);
  static const card         = Color(0xFF142727);
  static const cardLight    = Color(0xFF1A3030);
  static const accent       = Color(0xFF00FF88);
  static const accentDark   = Color(0xFF00CC6A);
  static const warning      = Color(0xFFFFA733);
  static const danger       = Color(0xFFFF6B6B);
  static const textPrimary  = Color(0xFFECF0F1);
  static const textSecondary= Color(0xFF7F8C8D);
  static const border       = Color(0xFF1E3535);
}

ThemeData floryTheme() {
  return ThemeData(
    scaffoldBackgroundColor: FloryColors.background,
    colorScheme: const ColorScheme.dark(
      primary:   FloryColors.accent,
      secondary: FloryColors.warning,
      surface:   FloryColors.card,
    ),
    fontFamily: 'sans-serif',
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: FloryColors.textPrimary,  fontSize: 32, fontWeight: FontWeight.w700),
      titleLarge:   TextStyle(color: FloryColors.textPrimary,  fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium:  TextStyle(color: FloryColors.textPrimary,  fontSize: 16, fontWeight: FontWeight.w500),
      bodyMedium:   TextStyle(color: FloryColors.textSecondary,fontSize: 14),
      labelSmall:   TextStyle(color: FloryColors.textSecondary,fontSize: 12),
    ),
    cardTheme: CardThemeData(
      color: FloryColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FloryColors.accent,
        foregroundColor: FloryColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FloryColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FloryColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FloryColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FloryColors.accent, width: 2),
      ),
      labelStyle: const TextStyle(color: FloryColors.textSecondary),
      prefixIconColor: FloryColors.textSecondary,
    ),
  );
}
