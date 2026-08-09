import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Display-only unit preference. Canonical nutrition/workout quantities remain
/// stored in their existing typed units; this preference never rewrites them.
class UnitPreferenceNotifier extends StateNotifier<String> {
  static const key = 'display_units';

  UnitPreferenceNotifier() : super('Metric') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final value = prefs.getString(key);
    if (value == 'Imperial' || value == 'Metric') state = value!;
  }

  Future<void> setUnits(String value) async {
    if (value != 'Metric' && value != 'Imperial') return;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}

final unitPreferenceProvider =
    StateNotifierProvider<UnitPreferenceNotifier, String>(
      (ref) => UnitPreferenceNotifier(),
    );
