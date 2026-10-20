import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/di/providers.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/services/local_timezone_service.dart';
import '../progress/weekly_check_in.dart';
import 'weigh_in_reminder.dart';

/// The check-in card on Today (R-5): from Sunday 12:00 to Monday 12:00
/// local, until "Not now" hides it for that check-in week. Progress always
/// has a "This week's check-in" row.
abstract final class CheckInReminder {
  /// The card shows on Sunday from this hour, and on Monday before it.
  static const turnHour = 12;

  /// The card's title now, or null outside its window: "This week's
  /// check-in" on Sunday afternoon, "Last week's check-in" on Monday
  /// morning.
  static String? titleAt(DateTime localNow) {
    if (localNow.weekday == DateTime.sunday && localNow.hour >= turnHour) {
      return "This week's check-in";
    }
    if (localNow.weekday == DateTime.monday && localNow.hour < turnHour) {
      return "Last week's check-in";
    }
    return null;
  }

  /// [titleAt], unless "Not now" hid the card for [weekStart].
  static String? title({
    required DateTime localNow,
    required String weekStart,
    required String? dismissedWeek,
  }) => dismissedWeek == weekStart ? null : titleAt(localNow);

  static Future<void> dismissFor(SharedPreferences prefs, String weekStart) =>
      prefs.setString(AppPreferenceKeys.prefCheckInDismissedWeek, weekStart);
}

/// Bumped after "Not now".
final checkInRevisionProvider = StateProvider<int>((ref) => 0);

/// The Monday of the check-in week at [now].
Future<String> checkInWeekStart(
  DateTime now,
  LocalTimezoneService timezones,
) async {
  final dates = LocalScheduleDateService();
  return WeeklyCheckIn.weekStartFor(
    dates.localDateFor(now.toUtc(), await timezones.currentTimezoneId()),
    dates,
  );
}

/// The Today card's title, or null when it doesn't show.
final checkInCardTitleProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  ref.watch(checkInRevisionProvider);
  final now = ref.watch(weighInClockProvider)();
  // Cheap check first: no preference read outside the window.
  if (CheckInReminder.titleAt(now) == null) return null;
  final prefs =
      sharedPreferencesOrNull(() => ref.watch(sharedPreferencesProvider)) ??
      await SharedPreferences.getInstance();
  return CheckInReminder.title(
    localNow: now,
    weekStart: await checkInWeekStart(
      now,
      ref.watch(localTimezoneServiceProvider),
    ),
    dismissedWeek: prefs.getString(AppPreferenceKeys.prefCheckInDismissedWeek),
  );
});
