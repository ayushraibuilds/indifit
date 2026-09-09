import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/health_provider.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b02_progress_read_models.dart';
import '../../data/models/hydration_models.dart';
import '../../data/repositories/calendar_read_repository.dart';
import 'dashboard_module_registry.dart';
import 'dashboard_personalization_controller.dart';
import 'today_consumer_presentation.dart';
import 'today_presentation_types.dart';
import 'today_surface_controller.dart';
import 'widgets/dashboard_date_bar.dart';
import 'widgets/today_helpers.dart';
import 'widgets/today_hydration_card.dart';
import 'widgets/today_module_widgets.dart';
import 'widgets/today_nutrition_widgets.dart';

export 'today_presentation_types.dart';
export 'widgets/today_helpers.dart';
export 'widgets/today_hydration_card.dart';
export 'widgets/today_module_widgets.dart';
export 'widgets/today_nutrition_widgets.dart';

class TodayDailyActionSurface extends ConsumerWidget {
  const TodayDailyActionSurface({
    required this.selectedDate,
    required this.userName,
    required this.streakCount,
    required this.onDateChanged,
    required this.onRefresh,
    required this.onOpenSettings,
    required this.onCustomize,
    required this.onOpenWorkoutPlan,
    required this.onLogMeal,
    super.key,
    this.now,
    this.onLogMealForMeal,
    this.onStartWorkout,
    this.onResumeWorkout,
    this.onOpenFoodGuidance,
    this.onOpenNutritionTargets,
  });

  final DateTime selectedDate;
  final String userName;
  final int streakCount;
  final ValueChanged<DateTime> onDateChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenSettings;
  final VoidCallback onCustomize;
  final VoidCallback onOpenWorkoutPlan;
  final VoidCallback onLogMeal;
  final DateTime? now;

  /// The meal-row path retains the selected civil date and always uses the
  /// ordinary food-search route. [onLogMeal] remains the compatible default.
  final Future<void> Function(String mealType)? onLogMealForMeal;
  final Future<void> Function(CalendarOccurrenceReadItem item)? onStartWorkout;
  final Future<void> Function(WorkoutDraft draft)? onResumeWorkout;
  final VoidCallback? onOpenFoodGuidance;
  final VoidCallback? onOpenNutritionTargets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personalization = ref.watch(
      dashboardPersonalizationControllerProvider,
    );
    final personalizationController = ref.read(
      dashboardPersonalizationControllerProvider.notifier,
    );
    final snapshotAsync = ref.watch(todaySurfaceSnapshotProvider(selectedDate));
    final referenceNow = now ?? DateTime.now();
    final relation = todayDateRelation(selectedDate, referenceNow);

    final configuredLayout = personalization.layout.isEmpty
        ? standardDashboardModuleRegistry.normalize(const [])
        : personalization.layout;
    final snapshot = snapshotAsync.valueOrNull;
    final loading = snapshotAsync.isLoading && !snapshotAsync.hasError;
    final unavailable = snapshotAsync.hasError;
    final nutrition = TodayNutritionPresentation.from(
      snapshot?.nutrition ??
          (unavailable
              ? const TodayDomainRead<NutritionDailyReadModel>.unavailable(
                  'Nutrition unavailable',
                )
              : null),
      loading: loading,
      targetRead: snapshot?.targets,
      goal: snapshot?.goal,
    );
    final workout = TodayWorkoutPresentation.from(
      snapshot?.calendar ??
          (unavailable
              ? const TodayDomainRead<CalendarReadSnapshot>.unavailable(
                  'Workout unavailable',
                )
              : null),
      loading: loading,
      resolution: snapshot?.nextActionResolution,
      localDate: snapshot?.localDate ?? todaySurfaceDateKey(selectedDate),
    );
    final healthState = relation == TodayDateRelation.today
        ? ref.watch(healthStateProvider)
        : null;
    final activity = TodayActivityPresentation.from(
      snapshot?.progress ??
          (unavailable
              ? const TodayDomainRead<B02ProgressReadModel>.unavailable(
                  'Activity unavailable',
                )
              : null),
      loading: loading,
      healthSummary: healthState?.summary,
    );
    final progress = TodayProgressPresentation.from(
      snapshot?.progress ??
          (unavailable
              ? const TodayDomainRead<B02ProgressReadModel>.unavailable(
                  'Progress unavailable',
                )
              : null),
      loading: loading,
    );
    final nextUp = todayFocusPresentation(
      dateRelation: relation,
      snapshot: snapshot,
      loading: loading,
      unavailable: unavailable,
    );
    final nextUpVisible =
        nextUp.shouldRender &&
        configuredLayout.any(
          (item) => item.moduleId == 'today.next_action' && item.isVisible,
        );
    // The B02 read is a trailing range ending on the selected date. For a
    // future date that range can include present-day records, which must not
    // be presented as evidence for that future Today context.
    final evidenceDateSupported = relation != TodayDateRelation.future;
    final layout = [
      for (final item in configuredLayout)
        if (_shouldRenderTodayModule(
          item: item,
          nextUp: nextUp,
          activity: activity,
          progress: progress,
          evidenceDateSupported: evidenceDateSupported,
          hideWorkoutDuplicate:
              nextUpVisible &&
              (nextUp.action == TodayNextAction.resumeWorkout ||
                  nextUp.action == TodayNextAction.startWorkout ||
                  nextUp.action == TodayNextAction.openWorkoutPlan),
        ))
          item,
    ];

    return ColoredBox(
      color: context.b05Colors.page,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                B05Layout.space16,
                B05Layout.space12,
                B05Layout.space16,
                B05Layout.space24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TodayHeader(
                    userName: userName,
                    streakCount: streakCount,
                    selectedDate: selectedDate,
                    referenceNow: now,
                    onOpenSettings: onOpenSettings,
                    onCustomize: onCustomize,
                  ),
                  const SizedBox(height: B05Layout.space8),
                  DashboardDateBar(
                    selectedDate: selectedDate,
                    today: referenceNow,
                    onDateChanged: onDateChanged,
                  ),
                  if (personalization.status ==
                      DashboardPersonalizationStatus.saving)
                    const Padding(
                      padding: EdgeInsets.only(top: B05Layout.space8),
                      child: TodayInlineProgress(label: 'Saving Today layout'),
                    ),
                  if (personalization.status ==
                      DashboardPersonalizationStatus.error)
                    Padding(
                      padding: const EdgeInsets.only(top: B05Layout.space8),
                      child: TodayRetry(
                        title: 'Your layout could not be saved',
                        onRetry: personalizationController.retry,
                      ),
                    ),
                  if (relation == TodayDateRelation.today &&
                      nutrition.state != TodayPresentationState.loading &&
                      nutrition.state != TodayPresentationState.unavailable &&
                      nutrition.hasAcceptedCalorieTarget) ...[
                    const SizedBox(height: B05Layout.space8),
                    TodayOnboardingHandoff(
                      presentation: nutrition,
                      onReviewTargets: onOpenNutritionTargets ?? onOpenSettings,
                      onLogFood: () => _openMeal(''),
                    ),
                  ],
                  const SizedBox(height: B05Layout.space12),
                  for (final item in layout)
                    if (item.isVisible) ...[
                      _module(
                        context: context,
                        ref: ref,
                        item: item,
                        relation: relation,
                        nutrition: nutrition,
                        hydration: snapshot?.hydration ??
                            (unavailable
                                ? const TodayDomainRead<HydrationDailyReadModel>.unavailable(
                                    'Hydration unavailable',
                                  )
                                : const TodayDomainRead<HydrationDailyReadModel>.unavailable(
                                    'Hydration loading',
                                  )),
                        nextUp: nextUp,
                        workout: workout,
                        activity: activity,
                        progress: progress,
                        hideWorkoutDuplicate:
                            nextUpVisible &&
                            (nextUp.action == TodayNextAction.resumeWorkout ||
                                nextUp.action == TodayNextAction.startWorkout ||
                                nextUp.action ==
                                    TodayNextAction.openWorkoutPlan),
                        onRetry: () => ref.invalidate(
                          todaySurfaceSnapshotProvider(selectedDate),
                        ),
                        onLogMeal: _openMeal,
                        onStartWorkout: _startWorkout,
                        onResumeWorkout: _resumeWorkout,
                        onOpenFoodGuidance: onOpenFoodGuidance,
                        selectedDate: selectedDate,
                        onExpand: () => personalizationController.setCollapsed(
                          item.moduleId,
                          false,
                        ),
                      ),
                      const SizedBox(height: B05Layout.space8),
                    ],
                  if (!configuredLayout.any((item) => item.isVisible))
                    NoVisibleModules(onCustomize: onCustomize),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldRenderTodayModule({
    required DashboardModuleLayoutItem item,
    required TodayFocusPresentation nextUp,
    required TodayActivityPresentation activity,
    required TodayProgressPresentation progress,
    required bool evidenceDateSupported,
    required bool hideWorkoutDuplicate,
  }) {
    if (!item.isVisible) return false;
    if (item.moduleId == 'today.next_action' && !nextUp.shouldRender) {
      return false;
    }
    if (item.moduleId == 'today.activity' &&
        (!evidenceDateSupported || !activity.shouldRender)) {
      return false;
    }
    if (item.moduleId == 'today.progress' &&
        (!evidenceDateSupported || !progress.shouldRender)) {
      return false;
    }
    // A collapsed module is an explicit user choice. Keep its compact row
    // available while a renderable source is loading; empty/error optional
    // evidence has already failed closed above.
    if (item.isCollapsed && item.descriptor.collapsible) return true;
    return switch (item.moduleId) {
      'today.workout' => !hideWorkoutDuplicate,
      // Meal rows retain their direct add actions even on an empty day. The
      // activity and progress descriptors are hidden by default and remain
      // available through Customize Today when a person wants them.
      'today.meal_rows' => true,
      'today.hydration' => true,
      'today.activity' || 'today.progress' => true,
      'today.next_action' || 'today.meals' => true,
      _ => false,
    };
  }

  void _openMeal(String mealType) {
    final callback = onLogMealForMeal;
    if (callback == null) {
      onLogMeal();
      return;
    }
    unawaited(callback(mealType));
  }

  void _startWorkout(CalendarOccurrenceReadItem item) {
    final callback = onStartWorkout;
    if (callback == null) {
      onOpenWorkoutPlan();
      return;
    }
    unawaited(callback(item));
  }

  void _resumeWorkout(WorkoutDraft draft) {
    final callback = onResumeWorkout;
    if (callback == null) {
      onOpenWorkoutPlan();
      return;
    }
    unawaited(callback(draft));
  }

  Widget _module({
    required BuildContext context,
    required WidgetRef ref,
    required DashboardModuleLayoutItem item,
    required TodayDateRelation relation,
    required TodayNutritionPresentation nutrition,
    required TodayDomainRead<HydrationDailyReadModel> hydration,
    required TodayFocusPresentation nextUp,
    required TodayWorkoutPresentation workout,
    required TodayActivityPresentation activity,
    required TodayProgressPresentation progress,
    required bool hideWorkoutDuplicate,
    required VoidCallback onRetry,
    required ValueChanged<String> onLogMeal,
    required ValueChanged<CalendarOccurrenceReadItem> onStartWorkout,
    required ValueChanged<WorkoutDraft> onResumeWorkout,
    required VoidCallback? onOpenFoodGuidance,
    required Future<void> Function() onExpand,
    required DateTime selectedDate,
  }) {
    if (item.isCollapsed && item.descriptor.collapsible) {
      return CollapsedTodayModule(
        label: item.descriptor.label,
        onExpand: onExpand,
      );
    }
    return switch (item.moduleId) {
      'today.meals' => TodayNutritionHero(
        presentation: nutrition,
        onLogFood: () => onLogMeal(''),
        onOpenFoodGuidance: onOpenFoodGuidance,
        dateRelation: relation,
        selectedDate: selectedDate,
        onOpenTargetSetup: onOpenNutritionTargets ?? onOpenSettings,
        onRetry: onRetry,
      ),
      'today.hydration' => TodayHydrationCard(
        hydrationRead: hydration,
        selectedDate: selectedDate,
        onRetry: onRetry,
      ),
      'today.next_action' => TodayNextUpModule(
        presentation: nextUp,
        onOpenWorkoutPlan: onOpenWorkoutPlan,
        onLogMeal: () => onLogMeal(''),
        onReturnToToday: () => onDateChanged(now ?? DateTime.now()),
        onStartWorkout: onStartWorkout,
        onResumeWorkout: onResumeWorkout,
        onRetry: onRetry,
      ),
      'today.meal_rows' => TodayMealsModule(
        meals: nutrition.meals,
        loading: nutrition.state == TodayPresentationState.loading,
        unavailable: nutrition.state == TodayPresentationState.unavailable,
        onLogMeal: onLogMeal,
        onRetry: onRetry,
        selectedDate: selectedDate,
      ),
      // When visible, Next Up owns the single workout CTA for this state. The
      // independently customizable Workout module remains available whenever
      // a person hides Next Up.
      'today.workout' when hideWorkoutDuplicate => const SizedBox.shrink(),
      'today.workout' => TodayWorkoutModule(
        presentation: workout,
        onOpenWorkoutPlan: onOpenWorkoutPlan,
        onStartWorkout: onStartWorkout,
        canStart: relation == TodayDateRelation.today,
        onRetry: onRetry,
      ),
      'today.activity' => TodayActivityModule(
        presentation: activity,
        onRetry: onRetry,
      ),
      'today.progress' => TodayProgressModule(
        presentation: progress,
        onRetry: onRetry,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

