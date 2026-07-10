import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/providers.dart';

import '../../core/theme/colors.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../food_log/food_search_screen.dart';
import '../food_log/ai_meal_logger_screen.dart';
import '../food_log/ai_meal_planner_screen.dart';
import '../settings/settings_screen.dart';
import '../workout_player/workout_player_screen.dart';
import '../workout_player/routine_display_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  double _currentWeight = 74.5;
  int _streakCount = 3;
  
  // Goals parameters (loaded dynamically from SharedPreferences, falling back to defaults)
  int _calorieGoal = 2000;
  double _proteinGoal = 120.0;
  double _carbsGoal = 230.0;
  double _fatGoal = 65.0;

  double _adherenceScore = 0.0;

  // Today's workout state variables
  String _todayWorkoutName = 'Rest Day';
  bool _isRestDay = true;
  List<RoutineExercise> _todayExercises = [];

  @override
  void initState() {
    super.initState();
    _loadStateData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkActiveWorkoutDraft();
    });
  }

  Future<void> _loadStateData() async {
    final prefs = await SharedPreferences.getInstance();
    await ref.read(waterProvider.notifier).loadState();

    setState(() {
      _currentWeight = prefs.getDouble('current_weight') ?? 74.5;
      _streakCount = prefs.getInt('streak_count') ?? 3;
      
      // Load user goals computed during onboarding
      _calorieGoal = prefs.getInt('calorie_goal') ?? 2000;
      _proteinGoal = prefs.getDouble('protein_goal') ?? 120.0;
      _carbsGoal = prefs.getDouble('carbs_goal') ?? 230.0;
      _fatGoal = prefs.getDouble('fat_goal') ?? 65.0;
    });
    await _loadTodayWorkout();
    await _calculateWeeklyAdherence();
  }

  Future<void> _checkActiveWorkoutDraft() async {
    try {
      final repo = ref.read(workoutRepositoryProvider);
      final draft = await repo.getActiveDraft();
      if (draft != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Resume Workout?'),
            backgroundColor: AppColors.surface,
            content: Text(
              'You have an unfinished workout session ("${draft.routineName}") from your last visit. Would you like to resume it?',
              style: const TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  await repo.deleteActiveDraft();
                },
                child: const Text('Discard', style: TextStyle(color: AppColors.danger)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  
                  final List<dynamic> rawSets = jsonDecode(draft.loggedSetsJson);
                  final List<WorkoutSetsCompanion> loggedCompanions = rawSets.map((s) {
                    final map = s as Map<String, dynamic>;
                    return WorkoutSetsCompanion.insert(
                      sessionId: map['sessionId'] ?? 0,
                      exerciseName: map['exerciseName'] ?? '',
                      weight: (map['weight'] as num).toDouble(),
                      reps: map['reps'] ?? 0,
                      setNumber: map['setNumber'] ?? 1,
                      isPr: Value(map['isPr'] ?? false),
                    );
                  }).toList();

                  final exercises = await repo.getExercisesForRoutineName(draft.routineName);

                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutPlayerScreen(
                          routineName: draft.routineName,
                          exercises: exercises,
                          initialExerciseIndex: draft.currentExerciseIndex,
                          initialSetIndex: draft.currentSetIndex,
                          initialElapsedSeconds: draft.elapsedSeconds,
                          initialLoggedSets: loggedCompanions,
                        ),
                      ),
                    ).then((_) => _loadStateData());
                  }
                },
                child: const Text('Resume'),
              )
            ],
          ),
        );
      }
    } catch (_) {
      // Safe guard against missing routine references
    }
  }

  Future<void> _loadTodayWorkout() async {
    if (!mounted) return;
    try {
      final repo = ref.read(workoutRepositoryProvider);
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
          setState(() {
            _todayWorkoutName = day.name;
            _isRestDay = day.isRestDay;
            _todayExercises = exercises;
          });
        }
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _calculateWeeklyAdherence() async {
    if (!mounted) return;
    
    try {
      final foodRepo = ref.read(foodRepositoryProvider);
      final workoutRepo = ref.read(workoutRepositoryProvider);
      
      final now = DateTime.now();
      int daysHit = 0;
      
      for (int i = 0; i < 7; i++) {
        final day = now.subtract(Duration(days: i));
        final dayLogs = await foodRepo.watchLogsForDay(day).first;
        int dayCals = 0;
        for (final log in dayLogs) {
          dayCals += log.calories;
        }
        
        if (dayCals > 0) {
          final diff = (dayCals - _calorieGoal).abs();
          if (diff <= _calorieGoal * 0.15) { // Within 15% range of calorie goal
            daysHit++;
          }
        }
      }
      
      final sessions = await workoutRepo.watchSessions().first;
      final weekSessions = sessions.where((s) => s.completedAt.isAfter(now.subtract(const Duration(days: 7)))).toList();
      
      double nutritionScore = (daysHit / 7.0) * 100;
      double workoutScore = 0.0;
      if (weekSessions.length >= 3) {
        workoutScore = 100.0;
      } else if (weekSessions.length == 2) {
        workoutScore = 80.0;
      } else if (weekSessions.length == 1) {
        workoutScore = 50.0;
      }
      
      if (mounted) {
        setState(() {
          _adherenceScore = (nutritionScore * 0.7 + workoutScore * 0.3);
        });
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _incrementWater() async {
    await ref.read(waterProvider.notifier).logWater(1);
  }

  Future<void> _decrementWater() async {
    await ref.read(waterProvider.notifier).logWater(-1);
  }

  Future<void> _resetWater() async {
    final current = ref.read(waterProvider).waterLogged;
    await ref.read(waterProvider.notifier).logWater(-current);
  }

  Future<void> _repeatLastMeal(String type, List<FoodLog> lastMeal) async {
    final repo = ref.read(foodRepositoryProvider);
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Repeated last $type!')),
      );
      _loadStateData();
    }
  }

  Future<void> _repeatLastWorkout(WorkoutSession lastSession) async {
    final repo = ref.read(workoutRepositoryProvider);
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

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkoutPlayerScreen(
            routineName: lastSession.name,
            exercises: exercises,
          ),
        ),
      ).then((_) => _loadStateData());
    }
  }

  Future<void> _updateWeight(double w) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentWeight = w;
      prefs.setDouble('current_weight', w);
    });
  }

  @override
  Widget build(BuildContext context) {
    final foodRepo = ref.watch(foodRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<FoodLog>>(
          stream: foodRepo.watchLogsForDay(DateTime.now()),
          builder: (context, snapshot) {
            final logs = snapshot.data ?? [];
            
            // Calc total macros logged
            int eatenCalories = 0;
            double eatenProtein = 0.0;
            double eatenCarbs = 0.0;
            double eatenFat = 0.0;

            for (final log in logs) {
              eatenCalories += log.calories;
              eatenProtein += log.proteinG;
              eatenCarbs += log.carbsG;
              eatenFat += log.fatG;
            }

            double calPercent = eatenCalories / _calorieGoal;
            if (calPercent > 1.0) calPercent = 1.0;
            if (calPercent < 0.0) calPercent = 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Responsive Header (Greeting & Streak & PopupMenu)
                  _buildHeader(),
                  const SizedBox(height: 20),

                  // 2. Calorie Ring & Macro Bars
                  _buildCalorieSection(eatenCalories, eatenProtein, eatenCarbs, eatenFat, calPercent),
                  const SizedBox(height: 16),

                  FutureBuilder<double>(
                    future: Future.wait(logs.map((l) => foodRepo.getFiberForLog(l))).then((fibers) => fibers.fold<double>(0.0, (sum, f) => sum + f)),
                    builder: (context, fiberSnapshot) {
                      final fiber = fiberSnapshot.data ?? 0.0;
                      final waterState = ref.watch(waterProvider);
                      return _buildNutritionReviewCard(logs, fiber, waterState.waterLogged, waterState.waterGoal, waterState.glassSize);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Quick Actions Bar
                  _buildQuickActionsRow(),
                  const SizedBox(height: 16),

                  // Today's Workout Card
                  _buildTodayWorkoutCard(),
                  const SizedBox(height: 16),

                  // Weekly Adherence Score Card
                  _buildAdherenceCard(),
                  const SizedBox(height: 24),

                  // 3. Log Meals Section Cards
                  _buildMealLogSection(logs),
                  const SizedBox(height: 24),

                  // 4. Water Tracker Card
                  _buildWaterCard(),
                  const SizedBox(height: 24),

                  // 5. Weight Trend Sparkline
                  _buildWeightSparklineCard(),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdherenceCard() {
    Color scoreColor = AppColors.danger;
    String feedback = 'Need focus';
    if (_adherenceScore >= 80) {
      scoreColor = AppColors.success;
      feedback = 'Excellent Consistency!';
    } else if (_adherenceScore >= 50) {
      scoreColor = AppColors.warning;
      feedback = 'Good progress, keep going!';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 36.0,
              lineWidth: 6.0,
              percent: _adherenceScore / 100.0,
              center: Text(
                '${_adherenceScore.round()}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              progressColor: scoreColor,
              backgroundColor: AppColors.border,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Adherence',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feedback,
                    style: TextStyle(color: scoreColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Calorie accuracy (70%) & workouts completed (30%) in past 7 days.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Greeting Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Namaste, Champ',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              const Text(
                'Crush your goals today!',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              )
            ],
          ),
        ),
        
        // Streak Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 14),
              const SizedBox(width: 2),
              Text(
                '${_streakCount}d',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),

        // Actions Menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
          onSelected: (val) {
            if (val == 'planner') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AiMealPlannerScreen()),
              );
            } else if (val == 'settings') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'planner',
              child: Row(
                children: [
                  Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('AI Meal Planner'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_rounded, color: AppColors.textSecondary, size: 20),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showQuickLogMealSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Log Meal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _startTodayWorkout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGlow,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.primary, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Start Workout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  void _showQuickLogMealSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Meal Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _mealQuickActionButton('Breakfast', 'breakfast', Icons.breakfast_dining_rounded),
                  _mealQuickActionButton('Lunch', 'lunch', Icons.lunch_dining_rounded),
                  _mealQuickActionButton('Dinner', 'dinner', Icons.dinner_dining_rounded),
                  _mealQuickActionButton('Snacks', 'snack', Icons.cookie_rounded),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mealQuickActionButton(String label, String type, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: AppColors.primary, size: 28),
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FoodSearchScreen(mealType: type)),
            );
          },
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  void _startTodayWorkout() {
    if (_isRestDay || _todayExercises.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rest Day scheduled'),
          content: const Text('Today is scheduled as a rest day. Would you like to view your training split to start a different workout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RoutineDisplayScreen()),
                );
              },
              child: const Text('View Split'),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkoutPlayerScreen(
            routineName: _todayWorkoutName,
            exercises: _todayExercises,
          ),
        ),
      );
    }
  }

  Widget _buildTodayWorkoutCard() {
    return FutureBuilder<WorkoutSession?>(
      future: ref.read(workoutRepositoryProvider).getLastCompletedSession(),
      builder: (context, snapshot) {
        final lastSession = snapshot.data;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isRestDay ? Colors.blue.withOpacity(0.1) : AppColors.primaryGlow,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRestDay ? Icons.spa_rounded : Icons.fitness_center_rounded,
                        color: _isRestDay ? Colors.blue : AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TODAY\'S WORKOUT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(_todayWorkoutName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            _isRestDay ? 'Time to recover and heal' : '${_todayExercises.length} Exercises scheduled',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (!_isRestDay)
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 32),
                        onPressed: _startTodayWorkout,
                      )
                  ],
                ),
                if (lastSession != null) ...[
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Last: ${lastSession.name} (${(lastSession.durationSeconds / 60).round()}m)',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _repeatLastWorkout(lastSession),
                        icon: const Icon(Icons.history_rounded, size: 14),
                        label: const Text('Repeat Last', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                    ],
                  )
                ]
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildCalorieSection(int eaten, double p, double c, double f, double calPercent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Circular Ring
            CircularPercentIndicator(
              radius: 60.0,
              lineWidth: 10.0,
              percent: calPercent,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$eaten',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'of $_calorieGoal kcal',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
              circularStrokeCap: CircularStrokeCap.round,
              backgroundColor: AppColors.border,
              progressColor: AppColors.primary,
            ),
            const SizedBox(width: 24),

            // Horizontal Macro Bars
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMacroBar('Protein', p, _proteinGoal, AppColors.success),
                  const SizedBox(height: 12),
                  _buildMacroBar('Carbs', c, _carbsGoal, AppColors.warning),
                  const SizedBox(height: 12),
                  _buildMacroBar('Fat', f, _fatGoal, AppColors.danger),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(String label, double eaten, double goal, Color color) {
    double percent = eaten / goal;
    if (percent > 1.0) percent = 1.0;
    if (percent < 0.0) percent = 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            Text('${eaten.round()}/${goal.round()}g', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6.0,
          ),
        ),
      ],
    );
  }

  Widget _buildMealLogSection(List<FoodLog> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MEALS TODAY',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.0),
        ),
        const SizedBox(height: 12),
        _buildMealCard('Breakfast', 'breakfast', logs),
        const SizedBox(height: 8),
        _buildMealCard('Lunch', 'lunch', logs),
        const SizedBox(height: 8),
        _buildMealCard('Dinner', 'dinner', logs),
        const SizedBox(height: 8),
        _buildMealCard('Snacks', 'snack', logs),
      ],
    );
  }

  Widget _buildMealCard(String title, String type, List<FoodLog> allLogs) {
    final mealLogs = allLogs.where((l) => l.mealType == type).toList();
    int totalCals = mealLogs.fold(0, (sum, item) => sum + item.calories);

    return Card(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('$totalCals kcal', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        subtitle: Text(
          mealLogs.isEmpty ? 'Tap plus to log item' : '${mealLogs.length} items logged',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Log Food Item',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.search_rounded, color: AppColors.primary),
                        title: const Text('Search Food Database', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Search common Indian items & scan barcodes'),
                        onTap: () {
                          Navigator.pop(context); // Close selection sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => FoodSearchScreen(mealType: type)),
                          );
                        },
                      ),
                      const Divider(color: AppColors.border),
                      ListTile(
                        leading: const Icon(Icons.psychology_rounded, color: AppColors.success),
                        title: const Text('AI Meal Estimator', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Estimate calories & macros from photos or text'),
                        onTap: () {
                          Navigator.pop(context); // Close selection sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AiMealLoggerScreen(mealType: type)),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: [
          if (mealLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                children: [
                  const Text('No food logged yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  FutureBuilder<List<FoodLog>>(
                    future: ref.read(foodRepositoryProvider).getLastLoggedMeal(type),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        final lastMeal = snapshot.data!;
                        final cals = lastMeal.fold(0, (sum, item) => sum + item.calories);
                        return TextButton.icon(
                          onPressed: () => _repeatLastMeal(type, lastMeal),
                          icon: const Icon(Icons.history_rounded, size: 14),
                          label: Text('Repeat Last ($cals kcal)', style: const TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            )
          else
            ...mealLogs.map((log) => _buildLoggedItemRow(log)),
        ],
      ),
    );
  }

  Widget _buildLoggedItemRow(FoodLog log) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Text(
                  '${log.servingLogged} logged • ${log.calories} kcal',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
            onPressed: () async {
              final repo = ref.read(foodRepositoryProvider);
              await repo.deleteLogEntry(log.id);
            },
          )
        ],
      ),
    );
  }

  Widget _buildWaterCard() {
    final waterState = ref.watch(waterProvider);
    final waterGlasses = waterState.waterLogged;
    final waterGoal = waterState.waterGoal;
    final glassSize = waterState.glassSize;

    final double percent = waterGoal > 0 ? (waterGlasses / waterGoal).clamp(0.0, 1.0) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            // Goal progress ring
            CircularPercentIndicator(
              radius: 22.0,
              lineWidth: 4.5,
              percent: percent,
              animation: true,
              animateFromLastPercent: true,
              circularStrokeCap: CircularStrokeCap.round,
              backgroundColor: const Color(0xFF0066FF).withOpacity(0.08),
              progressColor: const Color(0xFF0066FF),
              center: Icon(
                Icons.local_drink_rounded,
                color: waterGlasses >= waterGoal ? Colors.green : const Color(0xFF0066FF),
                size: 16,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Water Intake', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                    'Logged: ${waterGlasses * glassSize} ml (Goal: ${(waterGoal * glassSize / 1000.0).toStringAsFixed(1)}L)',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (waterGlasses > 0) ...[
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textMuted, size: 20),
                    onPressed: _decrementWater,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.textMuted, size: 18),
                    onPressed: _resetWater,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                ],
                ElevatedButton(
                  onPressed: _incrementWater,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF).withOpacity(0.12),
                    foregroundColor: const Color(0xFF0066FF),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 13),
                      const SizedBox(width: 2),
                      Text('${glassSize}ml', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSparklineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Weight Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      'Current weight: $_currentWeight kg',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                
                // Weight entry adjust button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.textSecondary, size: 16),
                      onPressed: () => _updateWeight(_currentWeight - 0.1),
                    ),
                    Text('${_currentWeight.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.primary, size: 16),
                      onPressed: () => _updateWeight(_currentWeight + 0.1),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            
            // Sparkline LineChart
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 5,
                  minY: 73.0,
                  maxY: 76.0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 75.8),
                        const FlSpot(1, 75.5),
                        const FlSpot(2, 75.2),
                        const FlSpot(3, 74.9),
                        const FlSpot(4, 74.7),
                        FlSpot(5, _currentWeight),
                      ],
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionReviewCard(List<FoodLog> logs, double fiber, int waterLogged, int waterGoal, int glassSize) {
    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Daily Nutrition Review',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dietary Fiber', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '${fiber.toStringAsFixed(1)}g logged',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    const Text('Goal: 25.0g - 30.0g', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: AppColors.border,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Hydration', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '${waterLogged * glassSize} ml',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
                    ),
                    Text('Goal: ${(waterGoal * glassSize / 1000.0).toStringAsFixed(1)}L', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              'PLANNED VS ACTUAL MEALS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: mealTypes.map((type) {
                final isLogged = logs.any((l) => l.mealType.toLowerCase() == type);
                return Column(
                  children: [
                    Icon(
                      isLogged ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isLogged ? AppColors.success : AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isLogged ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
