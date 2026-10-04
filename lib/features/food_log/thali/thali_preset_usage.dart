import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_logger.dart';
import 'thali_presets.dart';

/// Counts how often each thali preset ends up logged, on this device only,
/// so a new thali can start from the one the user actually eats.
class ThaliPresetUsage {
  ThaliPresetUsage(this._prefs);

  static const storageKey = 'thali_preset_log_counts_v1';

  final SharedPreferences? _prefs;

  Map<String, int> counts() {
    final raw = _prefs?.getString(storageKey);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is int)
            entry.key as String: entry.value as int,
      };
    } on FormatException catch (error) {
      AppLogger.warning('Ignoring unreadable thali preset counts: $error');
      return const {};
    }
  }

  /// The most-logged preset that still exists; ties go to the one listed
  /// first. Null until a preset has been logged at least once.
  ThaliPresetDefinition? mostUsed() {
    final counts = this.counts();
    ThaliPresetDefinition? best;
    var bestCount = 0;
    for (final preset in ThaliPresets.all) {
      final count = counts[preset.id] ?? 0;
      if (count > bestCount) {
        best = preset;
        bestCount = count;
      }
    }
    return best;
  }

  Future<void> recordLogged(String presetId) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final next = {...counts()};
    next[presetId] = (next[presetId] ?? 0) + 1;
    await prefs.setString(storageKey, jsonEncode(next));
  }
}
