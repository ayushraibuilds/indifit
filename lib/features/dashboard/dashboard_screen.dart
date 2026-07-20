import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/streak_calculator.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../food_log/food_search_screen.dart';
import '../food_log/ai_meal_logger_screen.dart';
import '../food_log/ai_meal_planner_screen.dart';
import '../settings/settings_screen.dart';
import '../workout_player/workout_player_screen.dart';
import '../workout_player/routine_display_screen.dart';
import 'widgets/calorie_ring_card.dart';
import 'widgets/water_tracker_card.dart';
import 'widgets/weight_sparkline_card.dart';
import 'widgets/today_workout_card.dart';
import 'widgets/dashboard_date_bar.dart';
import 'widgets/todays_activity_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  double _currentWeight = 74.5;
  int _streakCount = 0;
  List<double> _weightHistory = [];
  
  // Goals parameter (loaded dynamically from UserProfileProvider)
  int _calorieGoal = 2000;

  double _adherenceScore = 0.0;
  DateTime _selectedDate = DateTime.now();

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
      _calorieGoal = prefs.getInt('calorie_goal') ?? 2000;
    });
    await _loadTodayWorkout();
    await _calculateWeeklyAdherence();
    await _loadWeightHistory();
    await _computeStreak();
  }

  Future<void> _loadWeightHistory() async {
    final repo = ref.read(workoutRepositoryProvider);
    final measurements = await repo.getBodyMeasurements();
    final recent = measurements.take(6).toList().reversed.toList();
    final weights = recent.where((m) => m.weight != null).map((m) => m.weight!).toList();
    
    if (mounted) {
      setState(() {
        _weightHistory = weights;
        if (weights.isNotEmpty) {
          _currentWeight = weights.last;
        }
      });
    }
  }

  Future<void> _computeStreak() async {
    final foodRepo = ref.read(foodRepositoryProvider);
    final workoutRepo = ref.read(workoutRepositoryProvider);

    final foodDates = await foodRepo.getAllLogDates();
    final workoutDates = await workoutRepo.getAllSessionDates();

    final Set<String> activeDays = {};
    for (final d in foodDates) {
      activeDays.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    for (final d in workoutDates) {
      activeDays.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }

    final now = DateTime.now();
    int streak = StreakCalculator.calculateStreak(activeDays);

    if (mounted) {
      setState(() {
        _streakCount = streak;
      });
    }
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
          final diff = (dayCals - _calorieGoal).abs();
          if (diff <= _calorieGoal * 0.15) { // Within 15% range of calorie goal
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
        final nonRestDays = details.where((d) {
          final day = d['day'] as RoutineDay;
          return !day.isRestDay;
        }).length;
        if (nonRestDays > 0) {
          targetWorkoutDays = nonRestDays;
        }
      }

      final double nutritionScore = activeLoggedDays == 0 
          ? 0.0 
          : (daysHit / activeLoggedDays.toDouble()) * 100.0;
      final double workoutScore = ((weekSessions.length / targetWorkoutDays.toDouble()).clamp(0.0, 1.0)) * 100.0;
      
      if (mounted) {
        setState(() {
          _adherenceScore = (nutritionScore * 0.7 + workoutScore * 0.3);
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to calculate weekly adherence', e, stackTrace, 'DashboardScreen');
    }
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
    await prefs.setDouble('current_weight', w);
    
    // Insert canonical record into BodyMeasurements table
    await ref.read(workoutRepositoryProvider).logBodyMeasurement(weight: w);
    
    await _loadWeightHistory();
  }

  @override
  Widget build(BuildContext context) {
    final foodRepo = ref.watch(foodRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<FoodLog>>(
          stream: foodRepo.watchLogsForDay(_selectedDate),
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
                  const SizedBox(height: 12),

                  // Date Navigation Bar
                  DashboardDateBar(
                    selectedDate: _selectedDate,
                    onDateChanged: (newDate) {
                      setState(() {
                        _selectedDate = newDate;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. Calorie Ring & Macro Bars
                  CalorieRingCard(
                    eatenCalories: eatenCalories,
                    eatenProtein: eatenProtein,
                    eatenCarbs: eatenCarbs,
                    eatenFat: eatenFat,
                  ),
                  const SizedBox(height: 16),

                  // Health OS Today's Activity Card
                  const TodaysActivityCard(),
                  const SizedBox(height: 16),

                  FutureBuilder<double>(
                    future: Future.wait(logs.map((l) => foodRepo.getFiberForLog(l))).then((fibers) => fibers.fold<double>(0.0, (sum, f) => sum + f)),
                    builder: (context, fiberSnapshot) {
                      if (fiberSnapshot.connectionState == ConnectionState.waiting) {
                        return _buildSkeletonNutritionCard();
                      }
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
                  TodayWorkoutCard(
                    todayWorkoutName: _todayWorkoutName,
                    isRestDay: _isRestDay,
                    exerciseCount: _todayExercises.length,
                    onStartWorkout: _startTodayWorkout,
                    onRepeatWorkout: _repeatLastWorkout,
                  ),
                  const SizedBox(height: 16),

                  // Weekly Adherence Score Card
                  _buildAdherenceCard(),
                  const SizedBox(height: 24),

                  // 3. Log Meals Section Cards
                  _buildMealLogSection(logs),
                  const SizedBox(height: 24),

                  // 4. Water Tracker Card
                  const WaterTrackerCard(),
                  const SizedBox(height: 24),

                  // 5. Weight Trend Sparkline
                  WeightSparklineCard(
                    currentWeight: _currentWeight,
                    weightHistory: _weightHistory,
                    onWeightAdjusted: _updateWeight,
                  ),
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
              padding: const EdgeInsets.symmetric(vertical: 14),
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
              padding: const EdgeInsets.symmetric(vertical: 14),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dietary Fiber', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '${fiber.toStringAsFixed(1)}g / 25.0g',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (fiber / 25.0).clamp(0.0, 1.0),
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            fiber >= 25.0 ? AppColors.success : Colors.orangeAccent,
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 40,
                  width: 1,
                  color: AppColors.border,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Hydration', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '${waterLogged * glassSize} ml',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: waterGoal > 0 ? (waterLogged / waterGoal).clamp(0.0, 1.0) : 0.0,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildSkeletonNutritionCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 20, height: 20, borderRadius: 4),
                SizedBox(width: 8),
                SkeletonBox(width: 120, height: 16),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 80, height: 12),
                    SizedBox(height: 6),
                    SkeletonBox(width: 60, height: 16),
                  ],
                ),
                SizedBox(
                  height: 40,
                  width: 1,
                  child: VerticalDivider(color: AppColors.border),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 80, height: 12),
                    SizedBox(height: 6),
                    SkeletonBox(width: 60, height: 16),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
