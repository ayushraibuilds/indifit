import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/streak_calculator.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/repositories/health_service.dart';

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
  }) : selectedDate = selectedDate ?? DateTime.now();

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
    );
  }
}


class DashboardController extends StateNotifier<DashboardState> {
  final Ref _ref;

  DashboardController(this._ref) : super(DashboardState()) {
    loadStateData();
  }

  void setSelectedDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  Future<void> loadStateData() async {
    final prefs = await SharedPreferences.getInstance();
    final weight = prefs.getDouble('current_weight') ?? 74.5;
    final calGoal = prefs.getInt('calorie_goal') ?? 2000;

    state = state.copyWith(
      currentWeight: weight,
      calorieGoal: calGoal,
    );

    await loadTodayWorkout();
    await calculateWeeklyAdherence();
    await loadWeightHistory();
    await computeStreak();
    await loadWeeklyActionProgress();
  }


  Future<void> loadWeightHistory() async {
    final repo = _ref.read(workoutRepositoryProvider);
    final measurements = await repo.getBodyMeasurements();
    final recent = measurements.take(6).toList().reversed.toList();
    final weights = recent.where((m) => m.weight != null).map((m) => m.weight!).toList();

    state = state.copyWith(
      weightHistory: weights,
      currentWeight: weights.isNotEmpty ? weights.last : state.currentWeight,
    );
  }

  Future<void> computeStreak() async {
    final foodRepo = _ref.read(foodRepositoryProvider);
    final workoutRepo = _ref.read(workoutRepositoryProvider);
    final prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey('streak_freezes_count')) {
      await prefs.setInt('streak_freezes_count', 1);
    }
    final freezes = prefs.getInt('streak_freezes_count') ?? 1;

    final foodDates = await foodRepo.getAllLogDates();
    final workoutDates = await workoutRepo.getAllSessionDates();

    final Set<String> activeDays = {};
    for (final d in foodDates) {
      activeDays.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    for (final d in workoutDates) {
      activeDays.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }

    final streak = StreakCalculator.calculateStreak(activeDays, streakFreezeCount: freezes);
    state = state.copyWith(
      streakCount: streak,
      streakFreezesCount: freezes,
    );
  }

  Future<void> purchaseStreakFreeze() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('streak_freezes_count') ?? 1;
    await prefs.setInt('streak_freezes_count', current + 1);
    await computeStreak();
  }

  Future<void> loadTodayWorkout() async {
    try {
      final repo = _ref.read(workoutRepositoryProvider);
      final routines = await repo.getSavedRoutines();
      if (routines.isNotEmpty) {
        final active = routines.last;
        final details = await repo.getRoutineDetails(active.id);
        final todayWeekday = DateTime.now().weekday;
        final dayData = details.firstWhere(
          (d) => (d['day'] as RoutineDay).dayOfWeek == todayWeekday,
          orElse: () => <String, dynamic>{},
        );
        if (dayData.isNotEmpty) {
          final RoutineDay day = dayData['day'];
          final List<RoutineExercise> exercises = dayData['exercises'] as List<RoutineExercise>;
          state = state.copyWith(
            todayWorkoutName: day.name,
            isRestDay: day.isRestDay,
            todayExercises: exercises,
          );
        }
      }
    } catch (_) {}
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
      final weekSessions = sessions.where((s) => s.completedAt.isAfter(now.subtract(const Duration(days: 7)))).toList();

      int targetWorkoutDays = 3;
      final savedRoutines = await workoutRepo.getSavedRoutines();
      if (savedRoutines.isNotEmpty) {
        final details = await workoutRepo.getRoutineDetails(savedRoutines.last.id);
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

      final double nutritionScore = activeLoggedDays == 0 ? 0.0 : (daysHit / activeLoggedDays.toDouble()) * 100.0;
      final double workoutScore = ((weekSessions.length / targetWorkoutDays.toDouble()).clamp(0.0, 1.0)) * 100.0;

      state = state.copyWith(adherenceScore: (nutritionScore * 0.7 + workoutScore * 0.3));
    } catch (e, stackTrace) {
      AppLogger.error('Failed to calculate weekly adherence', e, stackTrace, 'DashboardController');
    }
  }

  Future<void> loadWeeklyActionProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final type = prefs.getString('weekly_action_type');
      final text = prefs.getString('weekly_action_text');
      final target = prefs.getInt('weekly_action_target') ?? 5;

      if (type == null || text == null) {
        state = state.copyWith(weeklyActionText: null, weeklyActionProgress: 0, weeklyActionTarget: 0);
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
          final dayProtein = logs.fold<double>(0.0, (sum, item) => sum + item.proteinG);
          if (dayProtein >= proteinGoal) {
            progress++;
          }
        }
      } else if (type == 'workouts_count') {
        final workoutRepo = _ref.read(workoutRepositoryProvider);
        final sessions = await workoutRepo.watchSessions().first;
        final pastWeekSessions = sessions.where((s) => s.completedAt.isAfter(now.subtract(const Duration(days: 7)))).toList();
        progress = pastWeekSessions.length;
      } else if (type == 'water_intake') {
        final waterGoal = prefs.getInt('water_goal') ?? 8;
        final waterGlasses = prefs.getInt('water_glasses') ?? 0;
        if (waterGlasses >= waterGoal) {
          progress = 1;
        }
      }

      state = state.copyWith(
        weeklyActionText: text,
        weeklyActionProgress: progress,
        weeklyActionTarget: target,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load weekly action progress', e, stackTrace, 'DashboardController');
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('current_weight', w);
    await _ref.read(workoutRepositoryProvider).logBodyMeasurement(weight: w);
    try {
      await _ref.read(healthServiceProvider).writeBodyWeight(w);
    } catch (e) {
      AppLogger.warning('Failed to sync body weight to Health SDK: $e');
    }
    await loadWeightHistory();
  }
  Future<List<RoutineExercise>> getRepeatWorkoutExercises(WorkoutSession lastSession) async {
    final repo = _ref.read(workoutRepositoryProvider);
    final sets = await repo.getSetsForSession(lastSession.id);

    final Map<String, int> exerciseSets = {};
    for (final s in sets) {
      exerciseSets[s.exerciseName] = (exerciseSets[s.exerciseName] ?? 0) + 1;
    }

    final List<RoutineExercise> exercises = [];
    int index = 0;
    exerciseSets.forEach((name, count) {
      exercises.add(RoutineExercise(
        id: index++,
        dayId: -1,
        exerciseName: name,
        sets: count,
        repsRange: '10',
        orderIndex: index,
      ));
    });

    return exercises;
  }
}

final dashboardControllerProvider = StateNotifierProvider<DashboardController, DashboardState>((ref) {
  return DashboardController(ref);
});
