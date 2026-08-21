import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b02_progress_read_models.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/repositories/b02_progress_read_repository.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/nutrition_read_model_repository.dart';
import '../../data/repositories/nutrition_target_authority.dart';
import '../../data/repositories/training_next_action_resolver.dart';
import '../../data/repositories/workout_repository.dart';

/// A typed result from an existing B01–B03 read authority. A failed source
/// remains distinguishable from an available source with no records, so the
/// Today UI never turns an unavailable value into a zero or an empty state.
class TodayDomainRead<T> {
  final T? value;
  final String? errorMessage;
  final bool _available;

  const TodayDomainRead._({
    this.value,
    this.errorMessage,
    required bool available,
  }) : _available = available;

  const TodayDomainRead.available(T value)
    : this._(value: value, available: true);

  const TodayDomainRead.unavailable(String errorMessage)
    : this._(errorMessage: errorMessage, available: false);

  bool get isAvailable => _available;
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

  /// The sole B02 active draft read. A null available value means there is no
  /// active draft; an unavailable value remains distinguishable from that
  /// absence.
  final TodayDomainRead<WorkoutDraft?> activeDraft;

  /// A nullable value is a known absence of an accepted target. An unavailable
  /// read remains distinct, so Today never invents a target just to fill the
  /// calorie ring.
  final TodayDomainRead<NutritionTargetsForDate?>? targets;

  /// Compatibility projection for older test/read callers. Production Today
  /// reads [targets] from the shared date-scoped authority; this field is
  /// retained while existing presentation fixtures migrate to that model.
  @Deprecated('Use targets from NutritionTargetAuthority.')
  final TodayDomainRead<NutritionGoalVersionReadModel?> goal;

  const TodaySurfaceSnapshot({
    required this.selectedDate,
    required this.localDate,
    required this.timezoneId,
    required this.calendar,
    required this.progress,
    required this.nutrition,
    this.activeDraft = const TodayDomainRead<WorkoutDraft?>.available(null),
    this.targets,
    this.goal = const TodayDomainRead<NutritionGoalVersionReadModel?>.available(
      null,
    ),
  });

  TrainingNextActionResolution? get nextActionResolution {
    final calendarRead = calendar;
    if (!calendarRead.isAvailable || calendarRead.value == null) return null;
    final draft =
        activeDraft.isAvailable &&
            activeDraft.value != null &&
            isTrainingResumableDraft(activeDraft.value!)
        ? activeDraft.value
        : null;
    return resolveTrainingNextAction(
      snapshot: calendarRead.value!,
      localDate: localDate,
      activeDraft: draft,
      activeDraftReadAvailable: activeDraft.isAvailable,
    );
  }
}

/// A source seam around existing production repositories. It is read-only;
/// mutations remain with existing B01/B03 routes and commands.
class TodaySurfaceReadRepository {
  final CalendarReadRepository _calendar;
  final B02ProgressReadRepository _progress;
  final Future<NutritionReadModelRepository> Function() _nutrition;
  final NutritionTargetAuthority _targets;
  final LocalScheduleDateService _dates;
  final WorkoutRepository? _workouts;

  TodaySurfaceReadRepository({
    required CalendarReadRepository calendar,
    required B02ProgressReadRepository progress,
    required Future<NutritionReadModelRepository> Function() nutrition,
    required NutritionTargetAuthority targets,
    required LocalScheduleDateService dates,
    WorkoutRepository? workouts,
  }) : _calendar = calendar,
       _progress = progress,
       _nutrition = nutrition,
       _targets = targets,
       _dates = dates,
       _workouts = workouts;

  Future<TodaySurfaceSnapshot> read({
    required DateTime selectedDate,
    required String timezoneId,
  }) async {
    final localDate = _dateKey(selectedDate);
    final calendarEndDate = _dates.addCalendarDays(localDate, timezoneId, 14);
    final weekStart = _dates.addCalendarDays(localDate, timezoneId, -6);
    final reads = await Future.wait<Object>([
      _safeRead(
        () => _calendar.readSnapshot(
          startLocalDate: localDate,
          endLocalDate: calendarEndDate,
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
      _safeRead<NutritionTargetsForDate?>(
        () => _targets.resolve(
          NutritionTargetDateQuery(
            localDate: localDate,
            timezoneId: timezoneId,
          ),
        ),
      ),
      _safeRead<WorkoutDraft?>(
        () => _workouts?.getActiveDraft() ?? Future<WorkoutDraft?>.value(null),
      ),
    ]);

    final targetRead = reads[3] as TodayDomainRead<NutritionTargetsForDate?>;
    final goalRead = targetRead.isAvailable
        ? TodayDomainRead<NutritionGoalVersionReadModel?>.available(
            targetRead.value?.goalVersion,
          )
        : const TodayDomainRead<NutritionGoalVersionReadModel?>.unavailable(
            'Nutrition target unavailable',
          );
    return TodaySurfaceSnapshot(
      selectedDate: selectedDate,
      localDate: localDate,
      timezoneId: timezoneId,
      calendar: reads[0] as TodayDomainRead<CalendarReadSnapshot>,
      progress: reads[1] as TodayDomainRead<B02ProgressReadModel>,
      nutrition: reads[2] as TodayDomainRead<NutritionDailyReadModel>,
      activeDraft: reads[4] as TodayDomainRead<WorkoutDraft?>,
      targets: targetRead,
      // Keep the older projection coherent for existing read fixtures. Both
      // values are derived from the same authority result above.
      goal: goalRead,
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
  (ref) {
    ref.watch(nutritionTargetAuthorityChangesProvider);
    return TodaySurfaceReadRepository(
      calendar: ref.watch(calendarReadRepositoryProvider),
      progress: B02ProgressReadRepository(
        ref.watch(databaseProvider),
        civilDates: ref.watch(localScheduleDateServiceProvider),
      ),
      nutrition: () => ref.read(nutritionReadModelRepositoryProvider.future),
      targets: ref.watch(nutritionTargetAuthorityProvider),
      dates: ref.watch(localScheduleDateServiceProvider),
      workouts: ref.watch(workoutRepositoryProvider),
    );
  },
);

/// Presentation invalidation owned by successful nutrition logging commands.
/// The underlying record remains B03-owned; this counter carries no data.
final todayNutritionRevisionProvider = StateProvider<int>((ref) => 0);

/// The single production read boundary consumed by the Today composition.
///
/// Basic B01-B03 reads intentionally use the device timezone and the existing
/// local nutrition scope. They must remain available when profile onboarding
/// is skipped. The optional B04 target is resolved under the profile-owned goal
/// history, which safely yields no target when setup has not created a profile.
final todaySurfaceSnapshotProvider = FutureProvider.autoDispose
    .family<TodaySurfaceSnapshot, DateTime>((ref, selectedDate) async {
      ref.watch(civilDateRevisionProvider);
      ref.watch(todayNutritionRevisionProvider);
      final timezoneId = await ref
          .watch(localTimezoneServiceProvider)
          .currentTimezoneId();
      final localDate = todaySurfaceDateKey(selectedDate);
      final calendarEndDate = ref
          .watch(localScheduleDateServiceProvider)
          .addCalendarDays(localDate, timezoneId, 14);
      final calendarRepository = ref.watch(calendarReadRepositoryProvider);
      final calendarInvalidation = calendarRepository.watchInvalidation(
        startLocalDate: localDate,
        endLocalDate: calendarEndDate,
        timezoneId: timezoneId,
      );
      final calendarSubscription = calendarInvalidation.listen(
        (_) => ref.invalidateSelf(),
      );
      ref.onDispose(calendarSubscription.cancel);
      final workoutSubscription = ref
          .watch(workoutRepositoryProvider)
          .watchTrainingInvalidation()
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(workoutSubscription.cancel);
      return ref
          .watch(todaySurfaceReadRepositoryProvider)
          .read(selectedDate: selectedDate, timezoneId: timezoneId);
    });
