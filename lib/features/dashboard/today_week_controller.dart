import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../data/repositories/nutrition_target_authority.dart';
import 'today_surface_controller.dart';

/// One day in Today's week strip: calories logged against that day's target.
class TodayWeekDay {
  const TodayWeekDay({
    required this.date,
    required this.logged,
    this.kcal,
    this.targetKcal,
  });

  final DateTime date;

  /// Whether anything was logged on this day.
  final bool logged;

  /// Calories logged, or null when the total is unknown (partial facts).
  final double? kcal;

  /// The accepted calorie target for this date, if there was one.
  final double? targetKcal;

  bool get hasTarget => targetKcal != null && targetKcal! > 0;

  /// 0–1 share of the target, or null when there is no target to compare to.
  double? get progress => hasTarget && kcal != null
      ? (kcal! / targetKcal!).clamp(0, 1).toDouble()
      : null;
}

/// The seven civil days ending on [end], oldest first.
List<DateTime> todayWeekDates(DateTime end) => [
  for (var offset = 6; offset >= 0; offset--)
    DateTime(end.year, end.month, end.day - offset),
];

/// The last day of the strip: today, unless the selected date lies outside
/// the last seven days (chosen from the date picker), so it always shows.
DateTime todayWeekEnd({required DateTime selected, required DateTime today}) {
  final day = DateTime(selected.year, selected.month, selected.day);
  final current = DateTime(today.year, today.month, today.day);
  final oldest = DateTime(current.year, current.month, current.day - 6);
  if (day.isBefore(oldest) || day.isAfter(current)) return day;
  return current;
}

/// Read-only kcal totals and targets for the strip's seven days. One history
/// pass for the totals; targets come from the same authority as the hero.
final todayWeekDaysProvider = FutureProvider.autoDispose
    .family<Map<String, TodayWeekDay>, DateTime>((ref, end) async {
      ref.watch(civilDateRevisionProvider);
      ref.watch(todayNutritionRevisionProvider);
      ref.watch(nutritionTargetAuthorityChangesProvider);
      final timezoneId = await ref
          .watch(localTimezoneServiceProvider)
          .currentTimezoneId();
      final dates = todayWeekDates(end);
      final keys = [for (final date in dates) todaySurfaceDateKey(date)];
      final repository = await ref.read(
        nutritionReadModelRepositoryProvider.future,
      );
      final totals = await repository.dailyTotalsForLocalDates(
        userId: kLocalNutritionUserScopeId,
        localDates: keys,
      );
      final authority = ref.read(nutritionTargetAuthorityProvider);
      final targets = await Future.wait([
        for (final key in keys)
          authority
              .resolve(
                NutritionTargetDateQuery(
                  localDate: key,
                  timezoneId: timezoneId,
                ),
              )
              .then<double?>(
                (value) => value.goalVersion?.calorieTargetKcal?.toDouble(),
              )
              .catchError((Object _) => null),
      ]);
      return {
        for (final (index, key) in keys.indexed)
          key: _weekDay(dates[index], totals[key], targets[index]),
      };
    });

TodayWeekDay _weekDay(
  DateTime date,
  NutritionDailyReadModel? daily,
  double? target,
) {
  if (daily == null || daily.records.isEmpty) {
    return TodayWeekDay(date: date, logged: false, kcal: 0, targetKcal: target);
  }
  final energy = daily.totals.facts['energy'];
  final kcal = energy != null && energy.isAvailable
      ? energy.point?.value.asDouble
      : null;
  return TodayWeekDay(date: date, logged: true, kcal: kcal, targetKcal: target);
}
