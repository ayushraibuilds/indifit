import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      
      // Text Theme
      textTheme: _getTextTheme(),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: AppColors.border, width: 1.0),
        ),
        margin: EdgeInsets.zero,
        elevation: 0,
      ),
      
      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        fillColor: const Color(0x0F060A12),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  static TextTheme _getTextTheme() {
    final baseTextTheme = ThemeData.dark().textTheme;
    
    // Check if running in a widget test to avoid font loading network calls
    bool isTest = false;
    try {
      if (WidgetsBinding.instance.toString().contains('Test')) {
        isTest = true;
      }
    } catch (_) {}

    if (isTest) {
      return baseTextTheme;
    }

    return GoogleFonts.outfitTextTheme(
      baseTextTheme,
    ).copyWith(
      titleLarge: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: 22.0,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: 18.0,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.outfit(
        color: AppColors.textPrimary,
        fontSize: 16.0,
      ),
      bodyMedium: GoogleFonts.outfit(
        color: AppColors.textSecondary,
        fontSize: 14.0,
      ),
      labelLarge: GoogleFonts.outfit(
        color: AppColors.textMuted,
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
