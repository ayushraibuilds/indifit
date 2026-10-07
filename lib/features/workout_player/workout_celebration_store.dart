import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';

/// Remembers which saved workouts already had their one summary
/// celebration, so reopening or rebuilding a summary never repeats it.
///
/// The only stored state for bests (training plan § 4.1): session IDs,
/// newest last, capped at [limit].
abstract final class WorkoutCelebrationStore {
  static const key = AppPreferenceKeys.trainingBestsCelebrated;
  static const limit = 200;

  static bool hasCelebrated(SharedPreferences prefs, int sessionId) =>
      (prefs.getStringList(key) ?? const []).contains('$sessionId');

  static Future<void> markCelebrated(
    SharedPreferences prefs,
    int sessionId,
  ) async {
    final ids =
        (prefs.getStringList(key) ?? const <String>[])
            .where((id) => id != '$sessionId')
            .toList()
          ..add('$sessionId');
    final kept = ids.length > limit ? ids.sublist(ids.length - limit) : ids;
    await prefs.setStringList(key, kept);
  }
}
