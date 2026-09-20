import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/di/providers.dart';
import '../../core/services/achievement_service.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/streak_calculator.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/health_service.dart';
import '../../data/repositories/legacy_program_compatibility_adapter.dart';
import '../../data/repositories/progress_statistics_repository.dart';
import '../../data/repositories/workout_repository.dart';

class DashboardState {
  final DateTime selectedDate;
  final double currentWeight;
  final int streakCount;
  final int streakFreezesCount;
  final List<double> weightHistory;
  final int calorieGoal;
  final double adherenceScore;
  final String todayWorkoutName;
  final bool isRestDay;
  final List<RoutineExercise> todayExercises;
  final String? weeklyActionText;
  final int weeklyActionProgress;
  final int weeklyActionTarget;
  final List<String> newlyUnlockedAchievementIds;
  final int? streakMilestone;

  /// Derived titles for presentation and backward compatibility.
  List<String> get newlyUnlockedAchievementTitles {
    final catalog = AchievementService.evaluateAchievements(
      completedWorkoutsCount: 0,
      currentStreakDays: 0,
      totalVolumeKg: 0,
      totalLoggedMealsCount: 0,
    );
    final titleMap = {for (final a in catalog) a.id: a.title};
    return newlyUnlockedAchievementIds
        .map((id) => titleMap[id] ?? id)
        .toList();
  }

  DashboardState({
    DateTime? selectedDate,
    this.currentWeight = 74.5,
    this.streakCount = 0,
    this.streakFreezesCount = 1,
    this.weightHistory = const [],
    this.calorieGoal = 2000,
    this.adherenceScore = 0.0,
    this.todayWorkoutName = 'Rest Day',
    this.isRestDay = true,
    this.todayExercises = const [],
    this.weeklyActionText,
    this.weeklyActionProgress = 0,
    this.weeklyActionTarget = 0,
    List<String>? newlyUnlockedAchievementIds,
    List<String>? newlyUnlockedAchievementTitles,
    this.streakMilestone,
  })  : selectedDate = selectedDate ?? DateTime.now(),
        newlyUnlockedAchievementIds = newlyUnlockedAchievementIds ??
            (newlyUnlockedAchievementTitles ?? const []);

  DashboardState copyWith({
    DateTime? selectedDate,
    double? currentWeight,
    int? streakCount,
    int? streakFreezesCount,
    List<double>? weightHistory,
    int? calorieGoal,
    double? adherenceScore,
    String? todayWorkoutName,
    bool? isRestDay,
    List<RoutineExercise>? todayExercises,
    String? weeklyActionText,
    int? weeklyActionProgress,
    int? weeklyActionTarget,
    List<String>? newlyUnlockedAchievementIds,
    List<String>? newlyUnlockedAchievementTitles,
    int? streakMilestone,
  }) {
    return DashboardState(
      selectedDate: selectedDate ?? this.selectedDate,
      currentWeight: currentWeight ?? this.currentWeight,
      streakCount: streakCount ?? this.streakCount,
      streakFreezesCount: streakFreezesCount ?? this.streakFreezesCount,
      weightHistory: weightHistory ?? this.weightHistory,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      adherenceScore: adherenceScore ?? this.adherenceScore,
      todayWorkoutName: todayWorkoutName ?? this.todayWorkoutName,
      isRestDay: isRestDay ?? this.isRestDay,
      todayExercises: todayExercises ?? this.todayExercises,
      weeklyActionText: weeklyActionText ?? this.weeklyActionText,
      weeklyActionProgress: weeklyActionProgress ?? this.weeklyActionProgress,
      weeklyActionTarget: weeklyActionTarget ?? this.weeklyActionTarget,
      newlyUnlockedAchievementIds: newlyUnlockedAchievementIds ??
          (newlyUnlockedAchievementTitles ?? this.newlyUnlockedAchievementIds),
      streakMilestone: streakMilestone,
    );
  }
}

class DashboardController extends StateNotifier<DashboardState> {
  final Ref _ref;
  final SharedPreferences? _prefs;
  late DateTime _automaticDate;
  var _followsAutomaticDate = true;

  DashboardController(
    this._ref, {
    SharedPreferences? prefs,
    DashboardState? initialState,
    bool loadOnInit = true,
  })  : _prefs = prefs,
        super(initialState ?? DashboardState()) {
    _automaticDate = _day(state.selectedDate);
    _followsAutomaticDate = _sameDay(_automaticDate, _day(DateTime.now()));
    if (loadOnInit) loadStateData();
  }

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs;
    try {
      return _ref.read(sharedPreferencesProvider);
    } catch (_) {
      return await SharedPreferences.getInstance();
    }
  }

  void setSelectedDate(DateTime date) {
    final normalized = _day(date);
    _followsAutomaticDate = _sameDay(normalized, _day(DateTime.now()));
    if (_followsAutomaticDate) _automaticDate = normalized;
    state = state.copyWith(selectedDate: normalized);
  }

  /// Keeps the default Today selection aligned with a civil-date transition
  /// while preserving an explicitly browsed past/future date.
  ///
  /// When the date actually rolls over, the legacy cached fields
  /// ([DashboardState.todayWorkoutSession], adherence, streaks) are reloaded
  /// via [loadStateData] so they never show yesterday's data. The
  /// same-day early return above keeps repeated revision ticks from
  /// triggering reload storms.
  Future<void> refreshForCivilDate(DateTime today) async {
    if (!_followsAutomaticDate) return;
    final normalized = _day(today);
    if (_sameDay(normalized, _automaticDate) &&
        _sameDay(state.selectedDate, _automaticDate)) {
      return;
    }
    if (_sameDay(state.selectedDate, _automaticDate)) {
      _automaticDate = normalized;
      state = state.copyWith(selectedDate: normalized);
      await loadStateData();
    }
  }

  Future<void> loadStateData() async {
    final prefs = await _getPrefs();
    if (!mounted) return;
    final weight = prefs.getDouble(AppPreferenceKeys.currentWeight) ?? 74.5;
    final calGoal = prefs.getInt(AppPreferenceKeys.calorieGoal) ?? 2000;

    state = state.copyWith(currentWeight: weight, calorieGoal: calGoal);

    await loadTodayWorkout();
    if (!mounted) return;
    await calculateWeeklyAdherence();
    if (!mounted) return;
    await loadWeightHistory();
    if (!mounted) return;
    await computeStreak();
    if (!mounted) return;
    await loadWeeklyActionProgress();
    if (!mounted) return;
    await _evaluateAchievements();
  }

  Future<void> _evaluateAchievements() async {
    try {
      final statsRepo = _ref.read(progressStatisticsRepositoryProvider);
      final prefs = await _getPrefs();

      // Reconciled to the single authoritative AchievementService.
      // Workout achievements are celebrated exclusively on the workout summary screen;
      // non-workout achievements (e.g. meals/thali) are surfaced here without duplicate announces.
      // Legacy prefs key 'unlocked_achievement_ids' is left inert and no longer written to.
      final uncelebrated =
          await AchievementService.getUncelebratedNonWorkoutUnlocks(
        statsRepository: statsRepo,
        prefs: prefs,
      );

      state = state.copyWith(
        newlyUnlockedAchievementIds: uncelebrated.map((a) => a.id).toList(),
      );
    } catch (e) {
      AppLogger.info('[AchievementEval] Error: $e');
    }
  }

  Future<void> loadWeightHistory() async {
    final repo = _ref.read(workoutRepositoryProvider);
    final measurements = await repo.getBodyMeasurements();
    if (!mounted) return;
    final recent = measurements.take(6).toList().reversed.toList();
    final weights = recent
        .where((m) => m.weight != null)
        .map((m) => m.weight!)
        .toList();

    state = state.copyWith(
      weightHistory: weights,
      currentWeight: weights.isNotEmpty ? weights.last : state.currentWeight,
    );
  }

  Future<void> computeStreak() async {
    final foodRepo = _ref.read(foodRepositoryProvider);
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final prefs = await _getPrefs();

    if (!prefs.containsKey(AppPreferenceKeys.streakFreezesCount)) {
      await prefs.setInt(AppPreferenceKeys.streakFreezesCount, 1);
    }
    final freezes = prefs.getInt(AppPreferenceKeys.streakFreezesCount) ?? 1;

    final foodDates = await foodRepo.getAllLogDates();
    if (!mounted) return;
    final workoutDates = await workoutRepo.getAllSessionDates();
    if (!mounted) return;

    final Set<String> activeDays = {};
    for (final d in foodDates) {
      activeDays.add(
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }
    for (final d in workoutDates) {
      activeDays.add(
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }

    final streak = StreakCalculator.calculateStreak(
      activeDays,
      streakFreezeCount: freezes,
    );
    // Persist the computed streak so achievement surfaces (Achievements
    // screen, B02 player) reading userStreakCount agree with the dashboard
    // instead of showing a stale or default value.
    await prefs.setInt(AppPreferenceKeys.userStreakCount, streak);
    state = state.copyWith(streakCount: streak, streakFreezesCount: freezes);
  }

  Future<String> purchaseStreakFreeze() async {
    final prefs = await _getPrefs();
    final current = prefs.getInt(AppPreferenceKeys.streakFreezesCount) ?? 1;
    if (current >= 2) {
      return 'Max freeze tokens (2/2) already active!';
    }

    final lastClaimMs = prefs.getInt(AppPreferenceKeys.lastFreezeClaimedAt) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cooldownMs = 3 * 24 * 60 * 60 * 1000; // 3 days

    if (lastClaimMs > 0 && (nowMs - lastClaimMs) < cooldownMs) {
      final remainingHours =
          ((cooldownMs - (nowMs - lastClaimMs)) / (1000 * 60 * 60)).ceil();
      final remainingDays = (remainingHours / 24).ceil();
      return 'Cooldown active. Next freeze available in $remainingDays day${remainingDays > 1 ? 's' : ''}.';
    }

    await prefs.setInt(AppPreferenceKeys.streakFreezesCount, current + 1);
    await prefs.setInt(AppPreferenceKeys.lastFreezeClaimedAt, nowMs);
    await computeStreak();
    return 'Claimed 1 Streak Freeze token! ❄️';
  }

  Future<void> loadTodayWorkout() async {
    try {
      final repo = _ref.read(workoutRepositoryProvider);
      final selection = await _ref
          .read(legacyProgramCompatibilityAdapterProvider)
          .resolveActivePlanSelection();
      if (selection.type == ActivePlanType.b01Program) {
        state = state.copyWith(
          todayWorkoutName: 'Scheduled program',
          isRestDay: false,
          todayExercises: const [],
        );
        return;
      }
      if (selection.type == ActivePlanType.legacyRoutine) {
        final active = (await repo.getSavedRoutines()).singleWhere(
          (routine) => routine.id == selection.legacyRoutineId,
        );
        final details = await repo.getRoutineDetails(active.id);
        final todayWeekday = DateTime.now().weekday;
        final dayData = details.firstWhere(
          (d) => (d['day'] as RoutineDay).dayOfWeek == todayWeekday,
          orElse: () => <String, dynamic>{},
        );
        if (dayData.isNotEmpty) {
          final RoutineDay day = dayData['day'];
          final List<RoutineExercise> exercises =
              dayData['exercises'] as List<RoutineExercise>;
          state = state.copyWith(
            todayWorkoutName: day.name,
            isRestDay: day.isRestDay,
            todayExercises: exercises,
          );
        }
      }
    } catch (e, st) {
      AppLogger.warning('_loadTodayWorkout failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'dashboard_controller _loadTodayWorkout error',
      );
    }
  }

  Future<void> calculateWeeklyAdherence() async {
    try {
      final foodRepo = _ref.read(foodRepositoryProvider);
      final workoutRepo = _ref.read(workoutRepositoryProvider);

      final now = DateTime.now();
      int activeLoggedDays = 0;
      int daysHit = 0;

      for (int i = 0; i < 7; i++) {
        final day = now.subtract(Duration(days: i));
        final dayLogs = await foodRepo.watchLogsForDay(day).first;
        int dayCals = 0;
        for (final log in dayLogs) {
          dayCals += log.calories;
        }

        if (dayCals > 0) {
          activeLoggedDays++;
          final diff = (dayCals - state.calorieGoal).abs();
          if (diff <= state.calorieGoal * 0.15) {
            daysHit++;
          }
        }
      }

      final sessions = await workoutRepo.watchSessions().first;
      final weekSessions = sessions
          .where(
            (s) => s.completedAt.isAfter(now.subtract(const Duration(days: 7))),
          )
          .toList();

      int targetWorkoutDays = 3;
      final selection = await _ref
          .read(legacyProgramCompatibilityAdapterProvider)
          .resolveActivePlanSelection();
      if (selection.type == ActivePlanType.legacyRoutine) {
        final details = await workoutRepo.getRoutineDetails(
          selection.legacyRoutineId!,
        );
        final Map<int, bool> restDayMap = {};
        for (final d in details) {
          final day = d['day'] as RoutineDay;
          restDayMap[day.dayOfWeek] = day.isRestDay;
        }

        int plannedWorkoutDaysInPastWeek = 0;
        for (int i = 0; i < 7; i++) {
          final day = now.subtract(Duration(days: i));
          final isRest = restDayMap[day.weekday] ?? false;
          if (!isRest) {
            plannedWorkoutDaysInPastWeek++;
          }
        }
        if (plannedWorkoutDaysInPastWeek > 0) {
          targetWorkoutDays = plannedWorkoutDaysInPastWeek;
        }
      }

      final double nutritionScore = activeLoggedDays == 0
          ? 0.0
          : (daysHit / activeLoggedDays.toDouble()) * 100.0;
      final double workoutScore =
          ((weekSessions.length / targetWorkoutDays.toDouble()).clamp(
            0.0,
            1.0,
          )) *
          100.0;

      state = state.copyWith(
        adherenceScore: (nutritionScore * 0.7 + workoutScore * 0.3),
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to calculate weekly adherence',
        e,
        stackTrace,
        'DashboardController',
      );
    }
  }

  Future<void> loadWeeklyActionProgress() async {
    try {
      final prefs = await _getPrefs();
      final type = prefs.getString(AppPreferenceKeys.weeklyActionType);
      final text = prefs.getString(AppPreferenceKeys.weeklyActionText);
      final target = prefs.getInt(AppPreferenceKeys.weeklyActionTarget) ?? 5;

      if (type == null || text == null) {
        state = state.copyWith(
          weeklyActionText: null,
          weeklyActionProgress: 0,
          weeklyActionTarget: 0,
        );
        return;
      }

      final now = DateTime.now();
      int progress = 0;

      if (type == 'log_breakfast') {
        final foodRepo = _ref.read(foodRepositoryProvider);
        for (int i = 0; i < 7; i++) {
          final day = now.subtract(Duration(days: i));
          final logs = await foodRepo.watchLogsForDay(day).first;
          if (logs.any((l) => l.mealType.toLowerCase() == 'breakfast')) {
            progress++;
          }
        }
      } else if (type == 'protein_target') {
        final foodRepo = _ref.read(foodRepositoryProvider);
        final proteinGoal = prefs.getDouble('protein_goal') ?? 160.0;
        for (int i = 0; i < 7; i++) {
          final day = now.subtract(Duration(days: i));
          final logs = await foodRepo.watchLogsForDay(day).first;
          final dayProtein = logs.fold<double>(
            0.0,
            (sum, item) => sum + item.proteinG,
          );
          if (dayProtein >= proteinGoal) {
            progress++;
          }
        }
      } else if (type == 'workouts_count') {
        final workoutRepo = _ref.read(workoutRepositoryProvider);
        final sessions = await workoutRepo.watchSessions().first;
        final pastWeekSessions = sessions
            .where(
              (s) =>
                  s.completedAt.isAfter(now.subtract(const Duration(days: 7))),
            )
            .toList();
        progress = pastWeekSessions.length;
      } else if (type == 'water_intake') {
        final waterGoal = prefs.getInt('water_goal') ?? 8;
        final waterLogged = prefs.getInt('water_logged') ?? 0;
        if (waterLogged >= waterGoal) {
          progress = 1;
        }
      }

      state = state.copyWith(
        weeklyActionText: text,
        weeklyActionProgress: progress,
        weeklyActionTarget: target,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to load weekly action progress',
        e,
        stackTrace,
        'DashboardController',
      );
    }
  }

  Future<void> repeatLastMeal(String type, List<FoodLog> lastMeal) async {
    final repo = _ref.read(foodRepositoryProvider);
    for (final item in lastMeal) {
      await repo.logFoodEntry(
        name: item.name,
        calories: item.calories,
        proteinG: item.proteinG,
        carbsG: item.carbsG,
        fatG: item.fatG,
        servingLogged: item.servingLogged,
        servingUnit: item.servingUnit,
        mealType: type,
        foodItemId: item.foodItemId,
      );
    }
    await loadStateData();
  }

  Future<void> updateWeight(double w) async {
    // 1. Write to database in a single atomic transaction for body measurements + profile.
    // If this fails, stop execution immediately without updating SharedPreferences or state.
    await _ref
        .read(workoutRepositoryProvider)
        .logWeightAndSyncProfile(weight: w);

    // 2. Only after database write succeeds, update SharedPreferences and in-memory profile state.
    final prefs = await _getPrefs();
    await prefs.setDouble(AppPreferenceKeys.currentWeight, w);
    await prefs.setDouble(AppPreferenceKeys.userWeight, w);
    _ref.read(userProfileProvider.notifier).syncWeightFromPersistence(w);

    try {
      await _ref.read(healthServiceProvider).writeBodyWeight(w);
    } catch (e) {
      AppLogger.warning('Failed to sync body weight to Health SDK: $e');
    }
    await loadWeightHistory();
  }

  Future<List<RoutineExercise>> getRepeatWorkoutExercises(
    WorkoutSession lastSession,
  ) async {
    final repo = _ref.read(workoutRepositoryProvider);
    final sets = await repo.getSetsForSession(lastSession.id);

    final Map<String, int> exerciseSets = {};
    for (final s in sets) {
      exerciseSets[s.exerciseName] = (exerciseSets[s.exerciseName] ?? 0) + 1;
    }

    final List<RoutineExercise> exercises = [];
    int index = 0;
    exerciseSets.forEach((name, count) {
      exercises.add(
        RoutineExercise(
          id: index++,
          dayId: -1,
          exerciseName: name,
          sets: count,
          repsRange: '10',
          orderIndex: index,
        ),
      );
    });

    return exercises;
  }
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } on Object catch (_) {
        AppLogger.info(
          'Unable to read sharedPreferencesProvider in dashboardControllerProvider; falling back to null prefs',
          'DashboardController',
        );
      }
      final controller = DashboardController(ref, prefs: prefs);
      ref.listen<int>(civilDateRevisionProvider, (_, _) {
        unawaited(controller.refreshForCivilDate(DateTime.now()));
      });
      return controller;
    });
