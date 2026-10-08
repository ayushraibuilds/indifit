import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_preferences_keys.dart';
import '../utils/app_logger.dart';
import 'core_providers.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String prefKey = AppPreferenceKeys.userThemeMode;
  final SharedPreferences? _prefs;

  ThemeModeNotifier([SharedPreferences? prefs])
    : _prefs = prefs,
      super(_loadInitialMode(prefs));

  /// Dark until the user picks a mode. It matches the dark launch screen, so a
  /// cold start never flashes from navy to white.
  static const ThemeMode defaultMode = ThemeMode.dark;

  static ThemeMode _loadInitialMode(SharedPreferences? prefs) {
    if (prefs == null) return defaultMode;
    final val = prefs.getString(prefKey);
    return switch (val) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => defaultMode,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final val = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(prefKey, val);
    } catch (e) {
      AppLogger.warning('Failed to persist theme mode preference: $e');
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  SharedPreferences? prefs = sharedPreferencesOrNull(
    () => ref.watch(sharedPreferencesProvider),
  );
  return ThemeModeNotifier(prefs);
});
