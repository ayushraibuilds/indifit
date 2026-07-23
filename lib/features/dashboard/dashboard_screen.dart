import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/di/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/confetti_overlay.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../food_log/ai_meal_planner_screen.dart';
import '../settings/settings_screen.dart';
import '../workout_player/routine_display_screen.dart';
import '../workout_player/workout_player_screen.dart';
import 'dashboard_controller.dart';
import 'widgets/calorie_ring_card.dart';
import 'widgets/dashboard_date_bar.dart';
import 'widgets/dashboard_meal_section.dart';
import 'widgets/quick_log_bottom_sheet.dart';
import 'widgets/streak_freeze_card.dart';
import 'widgets/today_workout_card.dart';
import 'widgets/todays_activity_card.dart';
import 'widgets/water_tracker_card.dart';
import 'widgets/weight_sparkline_card.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkActiveWorkoutDraft();
    });
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
                    ).then((_) => ref.read(dashboardControllerProvider.notifier).loadStateData());
                  }
                },
                child: const Text('Resume'),
              )
            ],
          ),
        );
      }
    } catch (_) {}
  }

  void _startTodayWorkout(DashboardState state) {
    if (state.isRestDay || state.todayExercises.isEmpty) {
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
            routineName: state.todayWorkoutName,
            exercises: state.todayExercises,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final foodRepo = ref.watch(foodRepositoryProvider);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<FoodLog>>(
          stream: foodRepo.watchLogsForDay(state.selectedDate),
          builder: (context, snapshot) {
            final logs = snapshot.data ?? [];

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

            final isCalorieGoalMet = eatenCalories >= state.calorieGoal && state.calorieGoal > 0;

            return ConfettiOverlay(
              isPlaying: isCalorieGoalMet,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, state),
                    const SizedBox(height: 12),
                    DashboardDateBar(
                      selectedDate: state.selectedDate,
                      onDateChanged: (newDate) => controller.setSelectedDate(newDate),
                    ),
                    if (state.weeklyActionText != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'WEEKLY FOCUS ACTION',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    '${state.weeklyActionProgress}/${state.weeklyActionTarget}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                state.weeklyActionText!,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: state.weeklyActionTarget > 0
                                    ? (state.weeklyActionProgress / state.weeklyActionTarget).clamp(0.0, 1.0)
                                    : 0.0,
                                backgroundColor: AppColors.border,
                                color: AppColors.primary,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const StreakFreezeCard(),
                    const SizedBox(height: 16),
                    CalorieRingCard(
                      eatenCalories: eatenCalories,
                      eatenProtein: eatenProtein,
                      eatenCarbs: eatenCarbs,
                      eatenFat: eatenFat,
                    ),
                    const SizedBox(height: 16),
                    const TodaysActivityCard(),
                    const SizedBox(height: 16),
                    DashboardMealSection(logs: logs),
                    const SizedBox(height: 16),
                    TodayWorkoutCard(
                      todayWorkoutName: state.todayWorkoutName,
                      isRestDay: state.isRestDay,
                      exerciseCount: state.todayExercises.length,
                      onStartWorkout: () => _startTodayWorkout(state),
                      onRepeatWorkout: (lastSession) async {
                        final exercises = await controller.getRepeatWorkoutExercises(lastSession);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkoutPlayerScreen(
                                routineName: lastSession.name,
                                exercises: exercises,
                              ),
                            ),
                          ).then((_) => controller.loadStateData());
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const WaterTrackerCard(),
                    const SizedBox(height: 16),
                    WeightSparklineCard(
                      currentWeight: state.currentWeight,
                      weightHistory: state.weightHistory,
                      onWeightAdjusted: (w) => controller.updateWeight(w),
                    ),

                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DashboardState state) {
    final userProfile = ref.watch(userProfileProvider);
    final name = (userProfile.userName != null && userProfile.userName!.trim().isNotEmpty)
        ? userProfile.userName!.trim()
        : 'Champ';

    final now = DateTime.now();
    final hour = now.hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 2),
            Text('Welcome, $name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text('${state.streakCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
              color: AppColors.surface,
              onSelected: (val) {
                if (val == 'settings') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                } else if (val == 'ai_planner') {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AiMealPlannerScreen()));
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'ai_planner', child: Row(children: [Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary), SizedBox(width: 8), Text('AI Diet Planner')])),
                const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings_rounded, size: 18), SizedBox(width: 8), Text('Settings')])),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsRow(DashboardState state) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => const QuickLogBottomSheet(),
              );
            },
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
            onPressed: () => _startTodayWorkout(state),
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
}
