import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../data/repositories/workout_repository.dart';
import '../training/weekly_training_goal_providers.dart';
import 'training_bests.dart';
import 'training_bests_providers.dart';

/// One weigh-in: the day it counts for and the weight.
class CheckInWeighIn {
  const CheckInWeighIn({
    required this.localDate,
    required this.recordedAt,
    required this.weightKg,
  });

  final String localDate;
  final DateTime recordedAt;
  final double weightKg;
}

/// What the check-in is built from, all read from logged data.
class WeeklyCheckInInputs {
  const WeeklyCheckInInputs({
    required this.weekStart,
    required this.weekEnd,
    required this.workoutLocalDates,
    required this.goal,
    this.bests = const [],
    this.proteinByLoggedDay = const {},
    this.weighIns = const [],
    this.nextWeekTrainingDates = const [],
  });

  /// Monday and Sunday of the week, as local dates.
  final String weekStart;
  final String weekEnd;

  /// Every saved workout's local date; the week's are counted.
  final List<String> workoutLocalDates;
  final int goal;

  /// Bests earned in the week's workouts (training_bests).
  final List<TrainingBest> bests;

  /// Each day of the week with food logged, and that day's protein in grams
  /// (null when its protein isn't known).
  final Map<String, double?> proteinByLoggedDay;
  final List<CheckInWeighIn> weighIns;

  /// Next week's scheduled training days.
  final List<String> nextWeekTrainingDates;
}

/// The Sunday check-in (UF-15): Mon–Sun, every number from logged data.
class WeeklyCheckIn {
  const WeeklyCheckIn({
    required this.weekStart,
    required this.weekEnd,
    required this.workoutsDone,
    required this.goal,
    required this.bestSet,
    required this.newBests,
    required this.daysLogged,
    required this.averageProteinG,
    required this.proteinDays,
    required this.weighInDays,
    required this.firstWeightKg,
    required this.lastWeightKg,
    required this.nextWeekTrainingDates,
  });

  final String weekStart;
  final String weekEnd;
  final int workoutsDone;
  final int goal;

  /// The heaviest new best of the week; null when there was none.
  final TrainingBest? bestSet;
  final int newBests;
  final int daysLogged;

  /// Average protein over the logged days whose protein is known.
  final double? averageProteinG;
  final int proteinDays;
  final int weighInDays;

  /// Nothing to tell for the week: no workout, food, weigh-in or best.
  bool get isEmpty =>
      workoutsDone == 0 && daysLogged == 0 && weighInDays == 0 && newBests == 0;

  /// The first and last day's weight; both null under two weigh-in days.
  final double? firstWeightKg;
  final double? lastWeightKg;
  final List<String> nextWeekTrainingDates;

  double? get weightChangeKg => firstWeightKg == null || lastWeightKg == null
      ? null
      : lastWeightKg! - firstWeightKg!;

  /// The week a check-in on [today] covers: this week on Sunday, otherwise
  /// the last full Mon–Sun week.
  static String weekStartFor(String today, LocalScheduleDateService dates) {
    final monday = WeeklyTrainingGoalCalculator.weekStartOf(
      today,
      dates: dates,
    );
    return dates.weekday(today, 'UTC') == DateTime.sunday
        ? monday
        : dates.addCalendarDays(monday, 'UTC', -7);
  }

  static WeeklyCheckIn build(WeeklyCheckInInputs inputs) {
    bool inWeek(String date) =>
        date.compareTo(inputs.weekStart) >= 0 &&
        date.compareTo(inputs.weekEnd) <= 0;

    final workouts = inputs.workoutLocalDates.where(inWeek).length;

    TrainingBest? best;
    for (final candidate in inputs.bests) {
      if (best == null || candidate.set.loadKg > best.set.loadKg) {
        best = candidate;
      }
    }

    final logged = inputs.proteinByLoggedDay.entries
        .where((entry) => inWeek(entry.key))
        .toList();
    final proteins = [
      for (final entry in logged)
        if (entry.value != null) entry.value!,
    ];
    final averageProtein = proteins.isEmpty
        ? null
        : proteins.reduce((a, b) => a + b) / proteins.length;

    // A day's value is its last weigh-in.
    final daily = <String, CheckInWeighIn>{};
    for (final weighIn in inputs.weighIns.where((w) => inWeek(w.localDate))) {
      final current = daily[weighIn.localDate];
      if (current == null || weighIn.recordedAt.isAfter(current.recordedAt)) {
        daily[weighIn.localDate] = weighIn;
      }
    }
    final days = daily.keys.toList()..sort();
    final trend = days.length >= 2;

    return WeeklyCheckIn(
      weekStart: inputs.weekStart,
      weekEnd: inputs.weekEnd,
      workoutsDone: workouts,
      goal: inputs.goal,
      bestSet: best,
      newBests: inputs.bests.length,
      daysLogged: logged.length,
      averageProteinG: averageProtein,
      proteinDays: proteins.length,
      weighInDays: days.length,
      firstWeightKg: trend ? daily[days.first]!.weightKg : null,
      lastWeightKg: trend ? daily[days.last]!.weightKg : null,
      nextWeekTrainingDates: ({...inputs.nextWeekTrainingDates}.toList()
        ..sort()),
    );
  }
}

/// The check-in for the week [WeeklyCheckIn.weekStartFor] picks today.
final weeklyCheckInProvider = FutureProvider.autoDispose<WeeklyCheckIn>((
  ref,
) async {
  final dates = ref.watch(localScheduleDateServiceProvider);
  final timezoneId = await ref
      .watch(localTimezoneServiceProvider)
      .currentTimezoneId();
  final today = dates.todayIn(timezoneId);
  final weekStart = WeeklyCheckIn.weekStartFor(today, dates);
  final weekEnd = dates.addCalendarDays(weekStart, 'UTC', 6);
  final weekDates = [
    for (var i = 0; i < 7; i++) dates.addCalendarDays(weekStart, 'UTC', i),
  ];
  bool inWeek(String date) =>
      date.compareTo(weekStart) >= 0 && date.compareTo(weekEnd) <= 0;

  final workouts = ref.watch(workoutRepositoryProvider);
  final sessions = await workouts.getSessions();
  final sessionDates = <String>[];
  final bests = <TrainingBest>[];
  final performance = ref.watch(b02ExercisePerformanceReadRepositoryProvider);
  for (final session in sessions) {
    final date = dates.localDateFor(session.completedAt, timezoneId);
    sessionDates.add(date);
    if (inWeek(date)) {
      final result = await TrainingBestsSessionRead.read(
        performance,
        session.id,
      );
      bests.addAll(result.bests);
    }
  }

  final goals = ref.watch(weeklyTrainingGoalRepositoryProvider);
  final goal = WeeklyTrainingGoalCalculator.goalForWeek(
    weekStart,
    await goals.goalHistory(),
    fallback: await goals.userGoal(),
  );

  final readModels = await ref.watch(
    nutritionReadModelRepositoryProvider.future,
  );
  final totals = await readModels.dailyTotalsForLocalDates(
    userId: kLocalNutritionUserScopeId,
    localDates: weekDates,
  );
  final protein = <String, double?>{
    for (final entry in totals.entries)
      if (entry.value.records.isNotEmpty)
        entry.key: entry.value.totals.facts['protein']?.point?.value.asDouble,
  };

  final weighIns = [
    for (final row in await workouts.getBodyMeasurements())
      if (row.weight != null && row.weight! > 0)
        CheckInWeighIn(
          localDate: dates.localDateFor(row.recordedAt, timezoneId),
          recordedAt: row.recordedAt,
          weightKg: row.weight!,
        ),
  ];

  final nextStart = dates.addCalendarDays(weekStart, 'UTC', 7);
  final nextEnd = dates.addCalendarDays(weekStart, 'UTC', 13);
  final calendar = await ref
      .watch(calendarReadRepositoryProvider)
      .readSnapshot(
        startLocalDate: nextStart,
        endLocalDate: nextEnd,
        timezoneId: timezoneId,
      );
  final active = calendar.activeProgramVersionId;
  final nextWeek = [
    for (final item in calendar.rangeOccurrences)
      if (item.occurrence.status != 'cancelled' &&
          (active == null || item.occurrence.programVersionId == active))
        item.occurrence.effectiveLocalDate,
  ];

  return WeeklyCheckIn.build(
    WeeklyCheckInInputs(
      weekStart: weekStart,
      weekEnd: weekEnd,
      workoutLocalDates: sessionDates,
      goal: goal,
      bests: bests,
      proteinByLoggedDay: protein,
      weighIns: weighIns,
      nextWeekTrainingDates: nextWeek,
    ),
  );
});
