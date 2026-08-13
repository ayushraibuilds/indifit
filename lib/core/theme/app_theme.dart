import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_logger.dart';
import 'app_colors_extension.dart';
import 'b05_semantic_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    const colors = B05SemanticColors.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.page,
      extensions: const [AppColorsExtension.dark, colors],

      colorScheme: ColorScheme.dark(
        primary: colors.action,
        onPrimary: colors.onAction,
        surface: colors.section,
        onSurface: colors.textPrimary,
        error: colors.danger.indicator,
        onError: colors.danger.container,
      ),

      // Text Theme
      textTheme: _getTextTheme(Brightness.dark),

      // Card Theme
      cardTheme: CardThemeData(
        color: colors.section,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        margin: EdgeInsets.zero,
        elevation: 0,
      ),

      navigationBarTheme: _navigationBarTheme(Brightness.dark),
      appBarTheme: _appBarTheme(colors),
      bottomSheetTheme: _bottomSheetTheme(colors),
      dialogTheme: _dialogTheme(colors),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: colors.action,
        textColor: colors.textPrimary,
        subtitleTextStyle: TextStyle(color: colors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      filledButtonTheme: _filledButtonTheme(colors),
      outlinedButtonTheme: _outlinedButtonTheme(colors),
      textButtonTheme: _textButtonTheme(colors),
      chipTheme: _chipTheme(colors),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        fillColor: colors.inset,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 14.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: colors.focus, width: 2),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    const colors = B05SemanticColors.light;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: colors.page,
      extensions: const [AppColorsExtension.light, colors],
      colorScheme: ColorScheme.light(
        primary: colors.action,
        onPrimary: colors.onAction,
        surface: colors.section,
        onSurface: colors.textPrimary,
        error: colors.danger.indicator,
        onError: Color(0xFFFFFFFF),
      ),
      textTheme: _getTextTheme(Brightness.light),
      cardTheme: CardThemeData(
        color: colors.section,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        margin: EdgeInsets.zero,
        elevation: 0,
      ),
      navigationBarTheme: _navigationBarTheme(Brightness.light),
      appBarTheme: _appBarTheme(colors),
      bottomSheetTheme: _bottomSheetTheme(colors),
      dialogTheme: _dialogTheme(colors),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: colors.action,
        textColor: colors.textPrimary,
        subtitleTextStyle: TextStyle(color: colors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      filledButtonTheme: _filledButtonTheme(colors),
      outlinedButtonTheme: _outlinedButtonTheme(colors),
      textButtonTheme: _textButtonTheme(colors),
      chipTheme: _chipTheme(colors),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: colors.inset,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 14.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: colors.focus, width: 2),
        ),
      ),
    );
  }

  static TextTheme _getTextTheme([Brightness brightness = Brightness.dark]) {
    final baseTextTheme = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    TextTheme theme = baseTextTheme;
    if (GoogleFonts.config.allowRuntimeFetching != false) {
      try {
        theme = GoogleFonts.outfitTextTheme(baseTextTheme);
      } catch (e) {
        AppLogger.warning('GoogleFonts.outfitTextTheme failed: $e');
      }
    }
    return theme.copyWith(
      displaySmall: theme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineSmall: theme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      titleLarge: theme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: theme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: theme.bodyMedium?.copyWith(height: 1.45),
      bodySmall: theme.bodySmall?.copyWith(height: 1.4),
      labelLarge: theme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: theme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  static NavigationBarThemeData _navigationBarTheme(Brightness brightness) {
    final colors = brightness == Brightness.dark
        ? B05SemanticColors.dark
        : B05SemanticColors.light;
    return NavigationBarThemeData(
      backgroundColor: colors.navigationSurface,
      indicatorColor: colors.selected,
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected
              ? colors.navigationSelected
              : colors.navigationUnselected,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? colors.navigationSelected
              : colors.navigationUnselected,
          size: 24,
        );
      }),
    );
  }

  static AppBarTheme _appBarTheme(B05SemanticColors colors) => AppBarTheme(
    backgroundColor: colors.page,
    foregroundColor: colors.textPrimary,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: colors.textPrimary,
      fontSize: 22,
      fontWeight: FontWeight.w700,
    ),
    iconTheme: IconThemeData(color: colors.textPrimary),
  );

  static BottomSheetThemeData _bottomSheetTheme(B05SemanticColors colors) =>
      BottomSheetThemeData(
        backgroundColor: colors.section,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.section,
        modalElevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      );

  static DialogThemeData _dialogTheme(B05SemanticColors colors) =>
      DialogThemeData(
        backgroundColor: colors.section,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: colors.textSecondary, height: 1.45),
      );

  static FilledButtonThemeData _filledButtonTheme(B05SemanticColors colors) =>
      FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.action,
          foregroundColor: colors.onAction,
          disabledBackgroundColor: colors.disabled,
          disabledForegroundColor: colors.textDisabled,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme(
    B05SemanticColors colors,
  ) => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: colors.action,
      disabledForegroundColor: colors.textDisabled,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      side: BorderSide(color: colors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );

  static TextButtonThemeData _textButtonTheme(B05SemanticColors colors) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.action,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );

  static ChipThemeData _chipTheme(B05SemanticColors colors) => ChipThemeData(
    backgroundColor: colors.inset,
    selectedColor: colors.selected,
    disabledColor: colors.disabled,
    labelStyle: TextStyle(color: colors.textPrimary),
    secondaryLabelStyle: TextStyle(color: colors.action),
    side: BorderSide(color: colors.border),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  );
}
