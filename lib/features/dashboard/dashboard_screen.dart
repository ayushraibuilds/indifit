import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/workout_draft_codec.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/confetti_overlay.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../activity/b02_activity_controller.dart';
import '../food_log/ai_meal_planner_screen.dart';
import '../nutrition/protein_distribution_screen.dart';
import '../settings/settings_screen.dart';
import '../workout_player/b02_strength_execution_controller.dart';
import '../workout_player/b02_strength_player_screen.dart';
import '../workout_player/routine_display_screen.dart';
import '../workout_player/workout_player_screen.dart';
import 'dashboard_controller.dart';
import 'widgets/calorie_ring_card.dart';
import 'widgets/dashboard_date_bar.dart';
import 'widgets/dashboard_meal_section.dart';
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
  bool _celebratingMilestone = false;

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
        await showDialog(
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
                  if (draft.scheduledOccurrenceId case final occurrenceId?) {
                    await ref
                        .read(workoutExecutionCompatibilityAdapterProvider)
                        .discardScheduledOccurrenceDraft(
                          occurrenceId: occurrenceId,
                          commandId: const Uuid().v4(),
                        );
                  } else {
                    await repo.deleteActiveDraft();
                  }
                },
                child: const Text(
                  'Discard',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  if (draft.executionStateJson != null &&
                      draft.activityType == 'strength') {
                    final b02 = ref.read(
                      b02StrengthExecutionControllerProvider.notifier,
                    );
                    await b02.recover(draft.id);
                    final b02State = ref.read(
                      b02StrengthExecutionControllerProvider,
                    );
                    if (b02State.status == B02StrengthExecutionStatus.ready &&
                        b02State.launch != null &&
                        mounted) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              B02StrengthPlayerScreen(launch: b02State.launch!),
                        ),
                      );
                      await ref
                          .read(dashboardControllerProvider.notifier)
                          .loadStateData();
                      return;
                    }
                    // A canonical B02 draft is never silently downgraded to
                    // name-based editing; preserve it and expose recovery.
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            b02State.errorMessage ??
                                'Strength draft recovery needs attention.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  if (draft.executionStateJson != null &&
                      draft.activityType != 'legacy') {
                    final activity = ref.read(
                      b02ActivityControllerProvider.notifier,
                    );
                    await activity.recover(draft.id);
                    if (mounted) {
                      await context.push(
                        '/activity-create?draftId=${draft.id}',
                      );
                    }
                    return;
                  }
                  final List<WorkoutSetsCompanion> loggedCompanions =
                      WorkoutDraftCodec.decodeLoggedSets(draft.loggedSetsJson);
                  final scheduledLaunch = draft.scheduledOccurrenceId == null
                      ? null
                      : await ref
                            .read(workoutExecutionCompatibilityAdapterProvider)
                            .resumeScheduledDraft(draft);
                  final exercises =
                      scheduledLaunch?.exercises ??
                      await repo.getExercisesForRoutineName(draft.routineName);
                  if (mounted) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkoutPlayerScreen(
                          routineName: draft.routineName,
                          exercises: exercises,
                          initialExerciseIndex: draft.currentExerciseIndex,
                          initialSetIndex: draft.currentSetIndex,
                          initialElapsedSeconds: draft.elapsedSeconds,
                          initialLoggedSets: loggedCompanions,
                          scheduledOccurrenceId: scheduledLaunch?.occurrenceId,
                          executionSnapshotJson:
                              scheduledLaunch?.executionSnapshotJson,
                          personalExerciseContextByName:
                              scheduledLaunch?.personalExerciseContextByName ??
                              const {},
                        ),
                      ),
                    );
                    await ref
                        .read(dashboardControllerProvider.notifier)
                        .loadStateData();
                  }
                },
                child: const Text('Resume'),
              ),
            ],
          ),
        );
      }
    } catch (e, st) {
      AppLogger.warning('Check active workout draft failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'dashboard active draft check error',
      );
    }
  }

  void _startTodayWorkout(DashboardState state) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
    );

    if (selectedDay.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You can't start a future workout. Switch to today or log a past session.",
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (state.isRestDay || state.todayExercises.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rest Day scheduled'),
          content: const Text(
            'Today is scheduled as a rest day. Would you like to view your training split to start a different workout?',
          ),
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
                  MaterialPageRoute(
                    builder: (context) => const RoutineDisplayScreen(),
                  ),
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
    final readModelAsync = ref.watch(nutritionReadModelRepositoryProvider);
    final canonicalHistoryStream = readModelAsync.when(
      data: (repository) =>
          repository.watchCanonicalChanges(userId: kLocalNutritionUserScopeId),
      loading: () => const Stream<void>.empty(),
      error: (_, _) => const Stream<void>.empty(),
    );

    // Achievement unlock toast & celebration
    ref.listen<DashboardState>(dashboardControllerProvider, (prev, next) {
      if (next.newlyUnlockedAchievementTitles.isNotEmpty &&
          (prev == null ||
              prev.newlyUnlockedAchievementTitles !=
                  next.newlyUnlockedAchievementTitles)) {
        setState(() => _celebratingMilestone = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _celebratingMilestone = false);
        });
        for (final title in next.newlyUnlockedAchievementTitles) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🏆 Achievement Unlocked: $title'),
              backgroundColor: AppColors.achievementGold,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      // Streak milestone toast & celebration
      final streakMilestones = [7, 14, 21, 30, 60, 100];
      if (prev != null && next.streakCount != prev.streakCount) {
        for (final milestone in streakMilestones) {
          if (next.streakCount >= milestone && prev.streakCount < milestone) {
            setState(() => _celebratingMilestone = true);
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _celebratingMilestone = false);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🔥 $milestone-day streak! Keep it up!'),
                backgroundColor: AppColors.streakOrange,
                duration: const Duration(seconds: 3),
              ),
            );
            break;
          }
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<Object?>(
          // Canonical snapshots do not emit through the legacy FoodLogs
          // stream. The read-model boundary supplies an invalidation-only
          // stream so this widget never reads the Drift graph directly.
          stream: canonicalHistoryStream,
          builder: (context, snapshot) {
            return StreamBuilder<List<FoodLog>>(
              stream: foodRepo.watchLogsForDay(state.selectedDate),
              builder: (context, foodSnapshot) {
                final logs = foodSnapshot.data ?? [];
                final legacyCalories = logs.fold(
                  0,
                  (sum, log) => sum + log.calories,
                );
                final legacyProtein = logs.fold(
                  0.0,
                  (sum, log) => sum + log.proteinG,
                );
                final legacyCarbs = logs.fold(
                  0.0,
                  (sum, log) => sum + log.carbsG,
                );
                final legacyFat = logs.fold(0.0, (sum, log) => sum + log.fatG);
                final dailyFuture = readModelAsync.when(
                  data: (repository) => repository.dailyTotals(
                    userId: kLocalNutritionUserScopeId,
                    localDate: _localDateKey(state.selectedDate),
                  ),
                  loading: () => null,
                  error: (_, _) => null,
                );
                return FutureBuilder<NutritionDailyReadModel>(
                  future: dailyFuture,
                  builder: (context, nutritionSnapshot) {
                    final daily = nutritionSnapshot.data;
                    final eatenCalories =
                        _energyValue(daily)?.round() ?? legacyCalories;
                    final eatenProtein =
                        _nutrientValue(daily, 'protein') ?? legacyProtein;
                    final eatenCarbs =
                        _nutrientValue(daily, 'carbohydrate') ?? legacyCarbs;
                    final eatenFat = _nutrientValue(daily, 'fat') ?? legacyFat;
                    final isCalorieGoalMet =
                        eatenCalories >= state.calorieGoal &&
                        state.calorieGoal > 0;

                    return ConfettiOverlay(
                      isPlaying: isCalorieGoalMet || _celebratingMilestone,
                      child: RefreshIndicator(
                        onRefresh: () async {
                          await controller.loadStateData();
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(context, state),
                              const SizedBox(height: 12),
                              DashboardDateBar(
                                selectedDate: state.selectedDate,
                                onDateChanged: (newDate) =>
                                    controller.setSelectedDate(newDate),
                              ),
                              if (state.weeklyActionText != null) ...[
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
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
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          state.weeklyActionText!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: state.weeklyActionTarget > 0
                                              ? (state.weeklyActionProgress /
                                                        state
                                                            .weeklyActionTarget)
                                                    .clamp(0.0, 1.0)
                                              : 0.0,
                                          backgroundColor: AppColors.border,
                                          color: AppColors.primary,
                                          minHeight: 6,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                              DashboardMealSection(
                                logs: logs,
                                selectedDate: state.selectedDate,
                                unifiedDay: daily,
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProteinDistributionScreen(
                                        localDate: _localDateKey(
                                          state.selectedDate,
                                        ),
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.bar_chart_outlined),
                                  label: const Text(
                                    'View protein logged by meal',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TodayWorkoutCard(
                                todayWorkoutName: state.todayWorkoutName,
                                isRestDay: state.isRestDay,
                                exerciseCount: state.todayExercises.length,
                                selectedDate: state.selectedDate,
                                onStartWorkout: () => _startTodayWorkout(state),
                                onLogCompleted: () =>
                                    controller.loadStateData(),
                                onRepeatWorkout: (lastSession) async {
                                  final exercises = await controller
                                      .getRepeatWorkoutExercises(lastSession);
                                  if (context.mounted) {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            WorkoutPlayerScreen(
                                              routineName: lastSession.name,
                                              exercises: exercises,
                                            ),
                                      ),
                                    );
                                    await controller.loadStateData();
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              const WaterTrackerCard(),
                              const SizedBox(height: 16),
                              WeightSparklineCard(
                                currentWeight: state.currentWeight,
                                weightHistory: state.weightHistory,
                                onWeightAdjusted: (w) =>
                                    controller.updateWeight(w),
                              ),
                              const SizedBox(height: 16),
                              const TodaysActivityCard(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  double? _energyValue(NutritionDailyReadModel? daily) =>
      _nutrientValue(daily, 'energy');

  double? _nutrientValue(NutritionDailyReadModel? daily, String nutrientId) =>
      daily?.totals.facts[nutrientId]?.point?.value.asDouble;

  String _localDateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Widget _buildHeader(BuildContext context, DashboardState state) {
    final userProfile = ref.watch(userProfileProvider);
    final name =
        (userProfile.userName != null &&
            userProfile.userName!.trim().isNotEmpty)
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
            Text(
              greeting,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Welcome, $name',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.streakOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.streakOrange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.streakOrange,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${state.streakCount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.streakOrange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textSecondary,
              ),
              color: AppColors.surface,
              onSelected: (val) {
                if (val == 'settings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                } else if (val == 'ai_planner') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AiMealPlannerScreen(),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'ai_planner',
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text('AI Diet Planner'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Settings'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
