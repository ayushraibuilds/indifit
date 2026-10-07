import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/core_providers.dart';
import '../../core/utils/weekly_training_goal_calculator.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/weekly_training_goal_repository.dart';
import '../../data/repositories/workout_repository.dart';
import 'training_providers.dart';

export '../../core/utils/weekly_training_goal_calculator.dart';

final weeklyTrainingGoalRepositoryProvider =
    Provider<WeeklyTrainingGoalRepository>((ref) {
      final workouts = ref.watch(workoutRepositoryProvider);
      return WeeklyTrainingGoalRepository(
        sessionTimes: workouts.getAllSessionDates,
        dates: ref.watch(localScheduleDateServiceProvider),
        preferences: () async =>
            sharedPreferencesOrNull(
              () => ref.read(sharedPreferencesProvider),
            ) ??
            await SharedPreferences.getInstance(),
      );
    });

/// The plan's goal for a week: its scheduled sessions, cancelled ones
/// excluded. Null when the plan schedules nothing, so the user's goal applies.
int? trainingPlanWeekGoal(
  Iterable<CalendarOccurrenceReadItem> weekOccurrences,
) {
  final count = weekOccurrences
      .where((item) => item.occurrence.status != 'cancelled')
      .length;
  return count == 0 ? null : count;
}

/// This week's goal status for Progress and the workout summary. Training
/// reads the same repository from its landing snapshot.
final weeklyTrainingGoalStatusProvider =
    FutureProvider.autoDispose<WeeklyTrainingGoalStatus>((ref) async {
      ref.watch(civilDateRevisionProvider);
      final dates = ref.watch(localScheduleDateServiceProvider);
      final timezoneId = await ref
          .watch(localTimezoneServiceProvider)
          .currentTimezoneId();
      final today = dates.todayIn(timezoneId);
      final weekStart = WeeklyTrainingGoalCalculator.weekStartOf(
        today,
        dates: dates,
      );
      final weekEnd = dates.addCalendarDays(weekStart, timezoneId, 6);
      final calendarRepository = ref.watch(calendarReadRepositoryProvider);
      final calendarSubscription = calendarRepository
          .watchInvalidation(
            startLocalDate: weekStart,
            endLocalDate: weekEnd,
            timezoneId: timezoneId,
          )
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(calendarSubscription.cancel);
      final workoutSubscription = ref
          .watch(workoutRepositoryProvider)
          .watchTrainingInvalidation()
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(workoutSubscription.cancel);

      final calendar = await calendarRepository.readSnapshot(
        startLocalDate: weekStart,
        endLocalDate: weekEnd,
        timezoneId: timezoneId,
      );
      final activeVersionId = calendar.activeProgramVersionId;
      final planGoal = activeVersionId == null
          ? null
          : trainingPlanWeekGoal(
              calendar.rangeOccurrences.where(
                (item) => item.occurrence.programVersionId == activeVersionId,
              ),
            );
      return ref
          .watch(weeklyTrainingGoalRepositoryProvider)
          .status(timezoneId: timezoneId, planGoal: planGoal);
    });
