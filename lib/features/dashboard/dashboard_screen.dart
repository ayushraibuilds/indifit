import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/workout_draft_codec.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/services/workout_session_wake_lock_coordinator.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/training_next_action_resolver.dart';
import '../../data/repositories/workout_repository.dart';
import '../activity/b02_activity_controller.dart';
import '../calendar/workout_contextual_launcher.dart';
import '../coaching/b04_production_surface_widgets.dart';
import '../settings/nutrition_targets_hub_screen.dart';
import '../workout_player/b02_strength_execution_controller.dart';
import '../workout_player/b02_strength_player_screen.dart';
import '../workout_player/workout_player_screen.dart';
import 'dashboard_controller.dart';
import 'today_daily_action_surface.dart';
import 'today_surface_controller.dart';
import 'widgets/dashboard_module_customization_panel.dart';

/// B05's daily action surface. It composes source-owned B01–B04 reads and
/// existing routes; it is not another dashboard data authority.
bool shouldShowDashboardActivityRecoveryPrompt(WorkoutDraft? draft) =>
    draft != null && !isTrainingResumableDraft(draft);

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
      // Today and Training already expose the one canonical Resume action for
      // workout drafts. Keep this launch-time recovery prompt only for the
      // competing non-training activity drafts that those surfaces cannot
      // resume themselves.
      if (draft == null ||
          !mounted ||
          !shouldShowDashboardActivityRecoveryPrompt(draft)) {
        return;
      }

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Resume activity?'),
          content: Text(
            'You have an unfinished activity ("${draft.routineName}") from your last visit. Would you like to resume it?',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
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
                final wakeLock = ref.read(
                  workoutSessionWakeLockCoordinatorProvider,
                );
                unawaited(
                  wakeLock.clearActiveSession(
                    b02WorkoutSessionWakeLockKey(draft.id),
                  ),
                );
                unawaited(
                  wakeLock.clearActiveSession(
                    legacyWorkoutSessionWakeLockKey(
                      draft.scheduledOccurrenceId,
                    ),
                  ),
                );
              },
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
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
                    await _refreshToday();
                    return;
                  }
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
                    await context.push('/activity-create?draftId=${draft.id}');
                  }
                  return;
                }
                final loggedCompanions = WorkoutDraftCodec.decodeLoggedSets(
                  draft.loggedSetsJson,
                );
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
                  await _refreshToday();
                }
              },
              child: const Text('Resume activity'),
            ),
          ],
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.warning('Check active workout draft failed: $error');
      CrashReportingService.recordCrash(
        error,
        stackTrace,
        reason: 'dashboard active draft check error',
      );
    }
  }

  Future<void> _refreshToday() async {
    await ref.read(dashboardControllerProvider.notifier).loadStateData();
    if (!mounted) return;
    final selectedDate = ref.read(dashboardControllerProvider).selectedDate;
    ref.invalidate(todaySurfaceSnapshotProvider(selectedDate));
  }

  Future<void> _resumeTodayWorkout(WorkoutDraft draft) async {
    if (draft.activityType == 'strength' && draft.executionStateJson != null) {
      try {
        final controller = ref.read(
          b02StrengthExecutionControllerProvider.notifier,
        );
        await controller.recover(draft.id);
        final recovered = ref.read(b02StrengthExecutionControllerProvider);
        if (!mounted ||
            recovered.status != B02StrengthExecutionStatus.ready ||
            recovered.launch == null) {
          throw StateError('The saved workout could not be recovered.');
        }
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => B02StrengthPlayerScreen(launch: recovered.launch!),
          ),
        );
        if (mounted) await _refreshToday();
        return;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved workout unavailable. Try again.'),
          ),
        );
        return;
      }
    }
    if (mounted) goToTrainingTab(context);
  }

  Future<void> _openFoodForMeal(String mealType) async {
    final date = ref.read(dashboardControllerProvider).selectedDate;
    final dateValue =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final queryParameters = <String, String>{'date': dateValue};
    final normalizedMealType = mealType.trim().toLowerCase();
    if (normalizedMealType.isNotEmpty) {
      queryParameters['mealType'] = normalizedMealType;
    }
    final route = Uri(path: '/food', queryParameters: queryParameters);
    await context.push(route.toString());
    if (mounted) await _refreshToday();
  }

  void _openFoodGuidance() {
    showIndiFitBottomSheet<void>(
      context: context,
      semanticLabel: 'Food guidance',
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'What can I eat?',
                    style: B05Typography.title(sheetCtx),
                  ),
                ),
                B05IconAction(
                  icon: Icons.close_rounded,
                  label: 'Close food guidance',
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                ),
              ],
            ),
            const SizedBox(height: B05Layout.space12),
            const B04CurrentFoodSummary(),
          ],
        ),
      ),
    );
  }

  Future<void> _startTodayWorkout(CalendarOccurrenceReadItem item) async {
    final needsConfirmation =
        WorkoutContextualLauncher.requiresDateConfirmation(ref, item);
    if (needsConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start outside scheduled date?'),
          content: Text(
            'This workout is scheduled for ${ConsumerDateLabel.day(item.occurrence.effectiveLocalDate)}. Starting it will not move or skip any other workout.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                item.occurrence.status == 'inProgress'
                    ? 'Resume workout'
                    : 'Start workout',
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      final target = await WorkoutContextualLauncher.prepare(
        ref: ref,
        item: item,
        confirmedOutsideEffectiveDate: needsConfirmation,
      );
      if (!mounted) return;
      await WorkoutContextualLauncher.push(context, target);
      if (mounted) await _refreshToday();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ProductFailurePresentation.fromError(
              error,
              title: 'Workout unavailable',
              code: 'workout_unavailable',
            ).message,
          ),
        ),
      );
    }
  }

  void _openCustomization() {
    showIndiFitBottomSheet<void>(
      context: context,
      semanticLabel: ConsumerCopy.customizeTodayAction,
      maxHeightFactor: 0.85,
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          B05Layout.space8,
          B05Layout.space16,
          B05Layout.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: ConsumerCopy.customizeTodayAction,
              header: true,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ConsumerCopy.customizeTodayAction,
                      style: B05Typography.title(sheetCtx),
                    ),
                  ),
                  B05IconAction(
                    icon: Icons.close_rounded,
                    label: 'Close customization',
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: B05Layout.space8),
            const Flexible(child: DashboardModuleCustomizationPanel()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardControllerProvider);
    final profile = ref.watch(userProfileProvider);
    final userName = profile.userName?.trim();
    return Scaffold(
      body: TodayDailyActionSurface(
        selectedDate: state.selectedDate,
        userName: userName == null || userName.isEmpty ? 'there' : userName,
        streakCount: state.streakCount,
        onDateChanged: (date) {
          ref
              .read(dashboardControllerProvider.notifier)
              .setSelectedDate(DateTime(date.year, date.month, date.day));
        },
        onRefresh: _refreshToday,
        onOpenSettings: () => context.push('/settings'),
        onCustomize: _openCustomization,
        onOpenWorkoutPlan: () => context.push('/calendar'),
        onLogMeal: () => unawaited(_openFoodForMeal('')),
        onLogMealForMeal: _openFoodForMeal,
        onStartWorkout: _startTodayWorkout,
        onResumeWorkout: _resumeTodayWorkout,
        onOpenFoodGuidance: _openFoodGuidance,
        onOpenNutritionTargets: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NutritionTargetsHubScreen(),
            ),
          );
        },
      ),
    );
  }
}
