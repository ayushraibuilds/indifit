import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/di/core_providers.dart';

/// Display-only unit preference. Canonical nutrition/workout quantities remain
/// stored in their existing typed units; this preference never rewrites them.
class UnitPreferenceNotifier extends StateNotifier<String> {
  static const key = AppPreferenceKeys.displayUnits;
  static const metric = 'Metric';
  static const imperial = 'Imperial';

  final SharedPreferences? _prefs;
  bool _changedLocally = false;

  UnitPreferenceNotifier([this._prefs]) : super(metric) {
    _load();
  }

  Future<SharedPreferences> _getPrefs() async =>
      _prefs ?? await SharedPreferences.getInstance();

  Future<void> _load() async {
    final prefs = await _getPrefs();
    if (!mounted || _changedLocally) return;
    final value = prefs.getString(key);
    if (value == imperial || value == metric) state = value!;
  }

  Future<void> setUnits(String value) async {
    if (value != metric && value != imperial) return;
    _changedLocally = true;
    state = value;
    final prefs = await _getPrefs();
    await prefs.setString(key, value);
  }
}

/// Converts only at the presentation boundary. Database and preference-backed
/// profile measurements continue to use kilograms and centimetres.
abstract final class UnitPreferencePresentation {
  static const _poundsPerKilogram = 2.2046226218;
  static const _centimetresPerInch = 2.54;

  static bool isImperial(String value) =>
      value == UnitPreferenceNotifier.imperial;

  static double weightForDisplay(double kilograms, String units) =>
      isImperial(units) ? kilograms * _poundsPerKilogram : kilograms;

  static double weightForStorage(double displayed, String units) =>
      isImperial(units) ? displayed / _poundsPerKilogram : displayed;

  static double heightForDisplay(double centimetres, String units) =>
      isImperial(units) ? centimetres / _centimetresPerInch : centimetres;

  static double heightForStorage(double displayed, String units) =>
      isImperial(units) ? displayed * _centimetresPerInch : displayed;

  static String weightSymbol(String units) => isImperial(units) ? 'lb' : 'kg';

  static String heightSymbol(String units) => isImperial(units) ? 'in' : 'cm';
}

final unitPreferenceProvider =
    StateNotifierProvider<UnitPreferenceNotifier, String>(
      (ref) {
        SharedPreferences? prefs;
        try {
          prefs = ref.watch(sharedPreferencesProvider);
        } catch (_) {}
        return UnitPreferenceNotifier(prefs);
      },
    );
