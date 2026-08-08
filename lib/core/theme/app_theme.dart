import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_logger.dart';
import 'app_colors_extension.dart';
import 'b05_semantic_colors.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      extensions: const [AppColorsExtension.dark, B05SemanticColors.dark],

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.surface,
        onSurface: Color(0xFFF1F5F9),
        error: AppColors.danger,
      ),

      // Text Theme
      textTheme: _getTextTheme(Brightness.dark),

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

      navigationBarTheme: _navigationBarTheme(Brightness.dark),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        fillColor: const Color(0x0F060A12),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 14.0,
        ),
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

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      extensions: const [AppColorsExtension.light, B05SemanticColors.light],
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        surface: Colors.white,
        onSurface: Color(0xFF0F172A),
        error: AppColors.danger,
      ),
      textTheme: _getTextTheme(Brightness.light),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        margin: EdgeInsets.zero,
        elevation: 0,
      ),
      navigationBarTheme: _navigationBarTheme(Brightness.light),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: const Color(0xFFF1F5F9),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 14.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  static TextTheme _getTextTheme([Brightness brightness = Brightness.dark]) {
    final baseTextTheme = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    if (GoogleFonts.config.allowRuntimeFetching == false) {
      return baseTextTheme;
    }

    try {
      return GoogleFonts.outfitTextTheme(baseTextTheme);
    } catch (e) {
      AppLogger.warning('GoogleFonts.outfitTextTheme failed: $e');
      return baseTextTheme;
    }
  }

  static NavigationBarThemeData _navigationBarTheme(Brightness brightness) {
    final colors = brightness == Brightness.dark
        ? B05SemanticColors.dark
        : B05SemanticColors.light;
    return NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.action.withValues(alpha: 0.18),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? colors.action : colors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? colors.action : colors.textSecondary,
          size: 24,
        );
      }),
    );
  }
}
