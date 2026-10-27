import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/local_schedule_date_service.dart';
import '../../../core/utils/weekly_training_goal_calculator.dart';
import '../../../data/repositories/progress_period_comparison_repository.dart';
import '../../training/muscles_this_week.dart';

/// TP-9 (Plus): working sets per muscle group for the last 12 Mon–Sun
/// weeks in the local timezone, plus training days per week. Counts come
/// from [muscleSetsProvider], so the rule matches "Muscles this week".
@immutable
class MuscleHeatmap {
  const MuscleHeatmap({
    required this.weekStarts,
    required this.muscles,
    required this.sets,
    required this.trainingDays,
  });

  /// Builds the grid from one [MuscleSetCounts] per week, oldest first.
  factory MuscleHeatmap.fromWeeks({
    required List<String> weekStarts,
    required List<MuscleSetCounts> weeks,
    required List<int> trainingDays,
  }) {
    final totals = <String, double>{};
    for (final week in weeks) {
      for (final entry in week.sets.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    final muscles = totals.keys.toList()
      ..sort(
        (a, b) => totals[b] != totals[a]
            ? totals[b]!.compareTo(totals[a]!)
            : a.compareTo(b),
      );
    return MuscleHeatmap(
      weekStarts: List.unmodifiable(weekStarts),
      muscles: List.unmodifiable(muscles),
      sets: Map.unmodifiable({
        for (final muscle in muscles)
          muscle: List<double>.unmodifiable([
            for (final week in weeks) week.sets[muscle] ?? 0,
          ]),
      }),
      trainingDays: List.unmodifiable(trainingDays),
    );
  }

  /// Monday of each week, oldest first; the last is this week.
  final List<String> weekStarts;

  /// Muscle groups with any sets in the 12 weeks, most sets first.
  final List<String> muscles;

  /// Muscle → working sets per week, aligned with [weekStarts].
  final Map<String, List<double>> sets;

  /// Days with a saved workout per week, aligned with [weekStarts].
  final List<int> trainingDays;

  bool get isEmpty => muscles.isEmpty && trainingDays.every((d) => d == 0);

  /// The most sets any muscle got in one week; shading is relative to it.
  double get maxWeeklySets => sets.values
      .expand((weeks) => weeks)
      .fold<double>(0, (max, value) => value > max ? value : max);
}

abstract final class MuscleHeatmapWeeks {
  static const count = 12;

  static const legend =
      'Shaded by working sets per week · ${MuscleSetRule.ruleText}';

  /// Mondays of the [count] weeks ending with the week of [today], oldest
  /// first.
  static List<String> starts(
    String today, {
    required String timezoneId,
    required LocalScheduleDateService dates,
    int count = count,
  }) {
    final thisWeek = WeeklyTrainingGoalCalculator.weekStartOf(
      today,
      dates: dates,
    );
    return [
      for (var i = count - 1; i >= 0; i--)
        dates.addCalendarDays(thisWeek, timezoneId, -7 * i),
    ];
  }
}

final muscleHeatmapProvider = FutureProvider.autoDispose<MuscleHeatmap>((
  ref,
) async {
  ref.watch(civilDateRevisionProvider);
  final dates = ref.watch(localScheduleDateServiceProvider);
  final timezoneId = await ref
      .watch(localTimezoneServiceProvider)
      .currentTimezoneId();
  final starts = MuscleHeatmapWeeks.starts(
    dates.todayIn(timezoneId),
    timezoneId: timezoneId,
    dates: dates,
  );
  final ranges = [
    for (final start in starts)
      MuscleSetRange(
        startLocalDate: start,
        endLocalDate: dates.addCalendarDays(start, timezoneId, 6),
        timezoneId: timezoneId,
      ),
  ];
  final weeks = await Future.wait([
    for (final range in ranges) ref.watch(muscleSetsProvider(range).future),
  ]);
  final repository = ProgressPeriodComparisonRepository(
    database: ref.watch(databaseProvider),
    dates: dates,
  );
  final nowUtc = DateTime.now().toUtc();
  final trainingDays = <int>[];
  for (final range in ranges) {
    final summary = await repository.summarizeRange(
      startLocalDate: range.startLocalDate,
      endLocalDate: range.endLocalDate,
      nowUtc: nowUtc,
      timezoneId: timezoneId,
    );
    trainingDays.add(summary.training.trainingDayCount);
  }
  return MuscleHeatmap.fromWeeks(
    weekStarts: starts,
    weeks: weeks,
    trainingDays: trainingDays,
  );
});
