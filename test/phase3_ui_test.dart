import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/theme_provider.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3 UI/UX & Theme System Unit Tests', () {
    test('AppTheme lightTheme and darkTheme initialize properly', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.useMaterial3, true);
      expect(dark.useMaterial3, true);
    });

    test('ThemeModeNotifier updates state and persists preference', () async {
      final notifier = ThemeModeNotifier();

      expect(notifier.state, ThemeMode.system);

      await notifier.setThemeMode(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeModeNotifier.prefKey), 'light');

      await notifier.setThemeMode(ThemeMode.dark);
      expect(notifier.state, ThemeMode.dark);
      expect(prefs.getString(ThemeModeNotifier.prefKey), 'dark');
    });
  });
}
