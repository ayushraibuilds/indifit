import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/di/providers.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../data/repositories/workout_repository.dart';

/// The morning weigh-in chip on Today (UR-29, UF-18): before 12:00 local on
/// the chosen weigh-in days, until a weight is logged that day or the user
/// taps "Not today".
abstract final class WeighInReminder {
  /// The chip shows before this local hour.
  static const lastHour = 12;

  static const everyDay = [1, 2, 3, 4, 5, 6, 7];

  /// The chosen weekdays (1 = Monday); every day until changed.
  static List<int> days(SharedPreferences prefs) {
    final stored = prefs.getStringList(AppPreferenceKeys.prefWeighInDays);
    if (stored == null) return everyDay;
    return ({
      for (final day in stored) ?int.tryParse(day),
    }.where((day) => day >= 1 && day <= 7).toList()..sort());
  }

  static Future<void> setDays(SharedPreferences prefs, List<int> days) =>
      prefs.setStringList(AppPreferenceKeys.prefWeighInDays, [
        for (final day in ({...days}.toList()..sort())) '$day',
      ]);

  static Future<void> dismissFor(SharedPreferences prefs, String localDate) =>
      prefs.setString(AppPreferenceKeys.prefWeighInDismissedDate, localDate);

  static bool shouldShow({
    required DateTime localNow,
    required String todayLocalDate,
    required List<int> days,
    required String? dismissedDate,
    required bool weighedToday,
    required bool canLog,
  }) =>
      localNow.hour < lastHour &&
      days.contains(localNow.weekday) &&
      dismissedDate != todayLocalDate &&
      !weighedToday &&
      canLog;
}

/// The clock the chip reads; fixed in tests.
final weighInClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

SharedPreferences? _prefs(Ref ref) =>
    sharedPreferencesOrNull(() => ref.watch(sharedPreferencesProvider));

/// Bumped after a weigh-in, "Not today" or a change of days.
final weighInRevisionProvider = StateProvider<int>((ref) => 0);

/// Whether Today shows the weigh-in chip now.
final weighInChipVisibleProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  ref.watch(weighInRevisionProvider);
  final prefs = _prefs(ref) ?? await SharedPreferences.getInstance();
  final now = ref.watch(weighInClockProvider)();
  final timezoneId = await ref
      .watch(localTimezoneServiceProvider)
      .currentTimezoneId();
  final today = LocalScheduleDateService().localDateFor(
    now.toUtc(),
    timezoneId,
  );
  final days = WeighInReminder.days(prefs);
  final dismissed = prefs.getString(AppPreferenceKeys.prefWeighInDismissedDate);
  // Cheap checks first: no database read outside the window.
  if (!WeighInReminder.shouldShow(
    localNow: now,
    todayLocalDate: today,
    days: days,
    dismissedDate: dismissed,
    weighedToday: false,
    canLog: true,
  )) {
    return false;
  }
  final status = await ref
      .watch(workoutRepositoryProvider)
      .getWeightLogStatus();
  return WeighInReminder.shouldShow(
    localNow: now,
    todayLocalDate: today,
    days: days,
    dismissedDate: dismissed,
    weighedToday: status.todayWeight != null,
    canLog: status.canLog,
  );
});
