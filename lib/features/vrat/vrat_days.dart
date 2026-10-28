import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/di/providers.dart';
import '../../core/utils/app_logger.dart';

/// Vrat / festival days (UF-9): days the user marked themselves; there is
/// no festival calendar. A marked day is excused from the streak (it
/// neither breaks nor extends it), swaps in vrat foods on search and the
/// thali quick start, and leaves targets unchanged.
abstract final class VratDays {
  /// Longest range one action marks: Navratri is 9 nights.
  static const maxRangeDays = 31;

  static Set<String> read(SharedPreferences prefs) =>
      (prefs.getStringList(AppPreferenceKeys.prefVratDays) ?? const [])
          .where(_isCivilDate)
          .toSet();

  static Future<void> write(SharedPreferences prefs, Set<String> days) {
    if (days.isEmpty) return prefs.remove(AppPreferenceKeys.prefVratDays);
    return prefs.setStringList(
      AppPreferenceKeys.prefVratDays,
      days.toList()..sort(),
    );
  }

  /// Every civil date from [start] to [end] inclusive (either order),
  /// capped at [maxRangeDays].
  static List<String> range(DateTime start, [DateTime? end]) {
    var first = DateTime(start.year, start.month, start.day);
    var last = end == null ? first : DateTime(end.year, end.month, end.day);
    if (last.isBefore(first)) (first, last) = (last, first);
    return [
      for (
        var day = first, i = 0;
        !day.isAfter(last) && i < maxRangeDays;
        day = DateTime(day.year, day.month, day.day + 1), i++
      )
        civilDate(day),
    ];
  }

  static String civilDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static final _civil = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static bool _isCivilDate(String value) => _civil.hasMatch(value);
}

class VratDaysController extends StateNotifier<Set<String>> {
  VratDaysController(this._prefs)
    : super(_prefs == null ? const {} : VratDays.read(_prefs));

  final SharedPreferences? _prefs;

  bool isMarked(DateTime day) => state.contains(VratDays.civilDate(day));

  /// Marks [start], or every day from [start] to [end].
  Future<void> mark(DateTime start, [DateTime? end]) =>
      _save({...state, ...VratDays.range(start, end)});

  /// Unmarks [start], or every day from [start] to [end].
  Future<void> unmark(DateTime start, [DateTime? end]) =>
      _save(state.difference(VratDays.range(start, end).toSet()));

  Future<void> _save(Set<String> next) async {
    state = Set.unmodifiable(next);
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      await VratDays.write(prefs, next);
    } on Object catch (error) {
      AppLogger.error('Saving vrat days failed', error);
    }
  }
}

final vratDaysProvider = StateNotifierProvider<VratDaysController, Set<String>>(
  (ref) => VratDaysController(
    sharedPreferencesOrNull(() => ref.watch(sharedPreferencesProvider)),
  ),
);

/// Whether [day] (any time on it) is marked; rebuilds when marks change.
bool watchIsVratDay(WidgetRef ref, DateTime day) =>
    ref.watch(vratDaysProvider).contains(VratDays.civilDate(day));
