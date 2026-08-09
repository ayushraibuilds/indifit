import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/b02_progress_read_models.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/repositories/b02_progress_read_repository.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/nutrition_goal_repository.dart';
import '../../data/repositories/nutrition_read_model_repository.dart';

/// A typed result from an existing B01–B03 read authority. A failed source
/// remains distinguishable from an available source with no records, so the
/// Today UI never turns an unavailable value into a zero or an empty state.
class TodayDomainRead<T> {
  final T? value;
  final String? errorMessage;

  const TodayDomainRead._({this.value, this.errorMessage});

  const TodayDomainRead.available(T value) : this._(value: value);

  const TodayDomainRead.unavailable(String errorMessage)
    : this._(errorMessage: errorMessage);

  bool get isAvailable => value != null;
}

/// Date-scoped, read-only inputs for the B05 daily action surface.
///
/// This model contains source projections rather than a new dashboard
/// calculation. B01–B04 remain responsible for their own facts.
class TodaySurfaceSnapshot {
  final DateTime selectedDate;
  final String localDate;
  final String timezoneId;
  final TodayDomainRead<CalendarReadSnapshot> calendar;
  final TodayDomainRead<B02ProgressReadModel> progress;
  final TodayDomainRead<NutritionDailyReadModel> nutrition;

  /// A nullable value is a known absence of an accepted target. An unavailable
  /// read remains distinct, so Today never invents a target just to fill the
  /// calorie ring.
  final TodayDomainRead<NutritionGoalVersionReadModel?> goal;

  const TodaySurfaceSnapshot({
    required this.selectedDate,
    required this.localDate,
    required this.timezoneId,
    required this.calendar,
    required this.progress,
    required this.nutrition,
    this.goal = const TodayDomainRead<NutritionGoalVersionReadModel?>.available(
      null,
    ),
  });
}

/// A source seam around existing production repositories. It is read-only;
/// mutations remain with existing B01/B03 routes and commands.
class TodaySurfaceReadRepository {
  final CalendarReadRepository _calendar;
  final B02ProgressReadRepository _progress;
  final Future<NutritionReadModelRepository> Function() _nutrition;
  final NutritionGoalRepository _goals;
  final LocalScheduleDateService _dates;

  TodaySurfaceReadRepository({
    required CalendarReadRepository calendar,
    required B02ProgressReadRepository progress,
    required Future<NutritionReadModelRepository> Function() nutrition,
    required NutritionGoalRepository goals,
    required LocalScheduleDateService dates,
  }) : _calendar = calendar,
       _progress = progress,
       _nutrition = nutrition,
       _goals = goals,
       _dates = dates;

  Future<TodaySurfaceSnapshot> read({
    required DateTime selectedDate,
    required String timezoneId,
  }) async {
    final localDate = _dateKey(selectedDate);
    final weekStart = _dates.addCalendarDays(localDate, timezoneId, -6);
    final reads = await Future.wait<Object>([
      _safeRead(
        () => _calendar.readSnapshot(
          startLocalDate: localDate,
          endLocalDate: localDate,
          timezoneId: timezoneId,
        ),
      ),
      _safeRead(
        () => _progress.read(
          B02ProgressQuery(
            startLocalDate: weekStart,
            endLocalDate: localDate,
            timezoneId: timezoneId,
          ),
        ),
      ),
      _safeRead(() async {
        final repository = await _nutrition();
        return repository.dailyTotals(
          userId: kLocalNutritionUserScopeId,
          localDate: localDate,
        );
      }),
      _safeRead(
        () => _goals.activeGoal(
          userId: kLocalNutritionUserScopeId,
          localDate: localDate,
          timezoneId: timezoneId,
        ),
      ),
    ]);

    return TodaySurfaceSnapshot(
      selectedDate: selectedDate,
      localDate: localDate,
      timezoneId: timezoneId,
      calendar: reads[0] as TodayDomainRead<CalendarReadSnapshot>,
      progress: reads[1] as TodayDomainRead<B02ProgressReadModel>,
      nutrition: reads[2] as TodayDomainRead<NutritionDailyReadModel>,
      goal: reads[3] as TodayDomainRead<NutritionGoalVersionReadModel?>,
    );
  }

  Future<TodayDomainRead<T>> _safeRead<T>(Future<T> Function() action) async {
    try {
      return TodayDomainRead.available(await action());
    } catch (error, _) {
      AppLogger.warning('Today daily surface read unavailable: $error');
      return const TodayDomainRead.unavailable(
        'This information is unavailable right now. Try again.',
      );
    }
  }
}

String todaySurfaceDateKey(DateTime value) => _dateKey(value);

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

final todaySurfaceReadRepositoryProvider = Provider<TodaySurfaceReadRepository>(
  (ref) => TodaySurfaceReadRepository(
    calendar: ref.watch(calendarReadRepositoryProvider),
    progress: B02ProgressReadRepository(
      ref.watch(databaseProvider),
      civilDates: ref.watch(localScheduleDateServiceProvider),
    ),
    nutrition: () => ref.read(nutritionReadModelRepositoryProvider.future),
    goals: ref.watch(nutritionGoalRepositoryProvider),
    dates: ref.watch(localScheduleDateServiceProvider),
  ),
);

/// Presentation invalidation owned by successful nutrition logging commands.
/// The underlying record remains B03-owned; this counter carries no data.
final todayNutritionRevisionProvider = StateProvider<int>((ref) => 0);

/// The single production read boundary consumed by the Today composition.
///
/// Basic B01-B03 reads intentionally use the device timezone and the existing
/// local nutrition scope. They must remain available when profile onboarding
/// is skipped; B04 surfaces retain their separate fail-closed profile gate.
final todaySurfaceSnapshotProvider = FutureProvider.autoDispose
    .family<TodaySurfaceSnapshot, DateTime>((ref, selectedDate) async {
      ref.watch(todayNutritionRevisionProvider);
      final timezoneId = await ref
          .watch(localTimezoneServiceProvider)
          .currentTimezoneId();
      return ref
          .watch(todaySurfaceReadRepositoryProvider)
          .read(selectedDate: selectedDate, timezoneId: timezoneId);
    });
