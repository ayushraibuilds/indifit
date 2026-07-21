import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/streak_calculator.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/workout_repository.dart';

class DashboardState {
  final DateTime selectedDate;
  final double currentWeight;
  final int streakCount;
  final List<double> weightHistory;
  final int calorieGoal;
  final double adherenceScore;
  final String todayWorkoutName;
  final bool isRestDay;
  final List<RoutineExercise> todayExercises;

  DashboardState({
    DateTime? selectedDate,
    this.currentWeight = 74.5,
    this.streakCount = 0,
    this.weightHistory = const [],
    this.calorieGoal = 2000,
    this.adherenceScore = 0.0,
    this.todayWorkoutName = 'Rest Day',
    this.isRestDay = true,
    this.todayExercises = const [],
  }) : selectedDate = selectedDate ?? DateTime.now();

  DashboardState copyWith({
    DateTime? selectedDate,
    double? currentWeight,
    int? streakCount,
    List<double>? weightHistory,
    int? calorieGoal,
    double? adherenceScore,
    String? todayWorkoutName,
    bool? isRestDay,
    List<RoutineExercise>? todayExercises,
  }) {
    return DashboardState(
      selectedDate: selectedDate ?? this.selectedDate,
      currentWeight: currentWeight ?? this.currentWeight,
      streakCount: streakCount ?? this.streakCount,
      weightHistory: weightHistory ?? this.weightHistory,
      calorieGoal: calorieGoal ?? this.calorieGoal,
      adherenceScore: adherenceScore ?? this.adherenceScore,
      todayWorkoutName: todayWorkoutName ?? this.todayWorkoutName,
      isRestDay: isRestDay ?? this.isRestDay,
      todayExercises: todayExercises ?? this.todayExercises,
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

    final foodDates = await foodRepo.getAllLogDates();
    final workoutDates = await workoutRepo.getAllSessionDates();

    final Set<String> activeDays = {};
    for (final d in foodDates) {
      activeDays.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    for (final d in workoutDates) {
      activeDays.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }

    final streak = StreakCalculator.calculateStreak(activeDays);
    state = state.copyWith(streakCount: streak);
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
        final nonRestDays = details.where((d) => !(d['day'] as RoutineDay).isRestDay).length;
        if (nonRestDays > 0) {
          targetWorkoutDays = nonRestDays;
        }
      }

      final double nutritionScore = activeLoggedDays == 0 ? 0.0 : (daysHit / activeLoggedDays.toDouble()) * 100.0;
      final double workoutScore = ((weekSessions.length / targetWorkoutDays.toDouble()).clamp(0.0, 1.0)) * 100.0;

      state = state.copyWith(adherenceScore: (nutritionScore * 0.7 + workoutScore * 0.3));
    } catch (e, stackTrace) {
      AppLogger.error('Failed to calculate weekly adherence', e, stackTrace, 'DashboardController');
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
