import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/presentation/consumer_copy.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/calendar_read_repository.dart';
import '../../food_log/food_search_screen.dart';
import '../../food_log/meal_presentation_registry.dart';
import '../today_consumer_presentation.dart';
import '../today_presentation_types.dart';
import 'today_helpers.dart';

/// Today module widgets (PV1-ENG-05B first pass).
///
/// Extracted verbatim from `today_daily_action_surface.dart`; unchanged.

class TodayNextUpModule extends StatelessWidget {
  const TodayNextUpModule({
    super.key,
    required this.presentation,
    required this.onOpenWorkoutPlan,
    required this.onLogMeal,
    required this.onReturnToToday,
    required this.onStartWorkout,
    required this.onResumeWorkout,
    required this.onRetry,
  });

  final TodayFocusPresentation presentation;
  final VoidCallback onOpenWorkoutPlan;
  final VoidCallback onLogMeal;
  final VoidCallback onReturnToToday;
  final ValueChanged<CalendarOccurrenceReadItem> onStartWorkout;
  final ValueChanged<WorkoutDraft> onResumeWorkout;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const TodayModuleSkeleton(label: 'Preparing your next step');
    }
    if (!presentation.shouldRender) return const SizedBox.shrink();
    if (presentation.state == TodayPresentationState.unavailable) {
      return TodayUnavailableModule(
        title: 'Next up unavailable',
        detail: 'Try again to load a useful next step.',
        onRetry: onRetry,
      );
    }
    final action = presentation.action!;
    final callback = switch (action) {
      TodayNextAction.startWorkout when presentation.workout != null =>
        () => onStartWorkout(presentation.workout!),
      TodayNextAction.resumeWorkout when presentation.activeDraft != null =>
        () => onResumeWorkout(presentation.activeDraft!),
      TodayNextAction.openWorkoutPlan => onOpenWorkoutPlan,
      TodayNextAction.logMeal => onLogMeal,
      TodayNextAction.returnToToday => onReturnToToday,
      _ => onOpenWorkoutPlan,
    };
    final icon = switch (action) {
      TodayNextAction.resumeWorkout => Icons.play_circle_outline_rounded,
      TodayNextAction.startWorkout => Icons.play_arrow_rounded,
      TodayNextAction.openWorkoutPlan => Icons.fitness_center_rounded,
      TodayNextAction.logMeal => Icons.restaurant_outlined,
      TodayNextAction.returnToToday => Icons.today_outlined,
    };
    return Semantics(
      container: true,
      label: 'Next up. ${presentation.title}. ${presentation.detail}',
      child: B05Surface(
        tone: B05SurfaceTone.selected,
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.b05Colors.success.container,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(B05Layout.space12),
                child: Icon(icon, color: context.b05Colors.success.indicator),
              ),
            ),
            const SizedBox(width: B05Layout.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next up', style: todayEyebrow(context)),
                  const SizedBox(height: B05Layout.space4),
                  Text(presentation.title, style: B05Typography.title(context)),
                  const SizedBox(height: B05Layout.space4),
                  Text(
                    presentation.detail,
                    style: B05Typography.caption(context),
                  ),
                  const SizedBox(height: B05Layout.space8),
                  B05ActionButton(
                    label: presentation.actionLabel!,
                    icon: icon,
                    hint: 'Your most useful next step.',
                    onPressed: callback,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodayMealsModule extends StatelessWidget {
  const TodayMealsModule({
    super.key,
    required this.meals,
    required this.loading,
    required this.unavailable,
    required this.onLogMeal,
    required this.onRetry,
    required this.selectedDate,
  });

  final List<TodayMealPresentation> meals;
  final bool loading;
  final bool unavailable;
  final ValueChanged<String> onLogMeal;
  final VoidCallback onRetry;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    if (loading) return const TodayModuleSkeleton(label: 'Preparing meals');
    if (unavailable) {
      return TodayUnavailableModule(
        title: 'Meals unavailable',
        detail: 'Try again to load today’s meals.',
        onRetry: onRetry,
      );
    }
    return Semantics(
      container: true,
      label: 'Meals',
      child: B05Surface(
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meals', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space8),
            for (var index = 0; index < meals.length; index++) ...[
              TodayMealRow(
                meal: meals[index],
                onAdd: () => onLogMeal(meals[index].mealType),
                selectedDate: selectedDate,
              ),
              if (index < meals.length - 1)
                Divider(
                  height: B05Layout.space16,
                  color: context.b05Colors.border,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class TodayMealRow extends StatelessWidget {
  const TodayMealRow({
    super.key,
    required this.meal,
    required this.onAdd,
    required this.selectedDate,
  });

  final TodayMealPresentation meal;
  final VoidCallback onAdd;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final role = switch (meal.mealType) {
      'breakfast' => context.b05Colors.breakfast,
      'lunch' => context.b05Colors.lunch,
      'dinner' => context.b05Colors.dinner,
      'snack' => context.b05Colors.snack,
      _ => () {
        final presentation = MealPresentationRegistry.forStableId(
          meal.mealType,
        );
        return presentation.accent != null
            ? context.b05Colors.meal(presentation.accent!)
            : context.b05Colors.snack;
      }(),
    };
    // One source for meal icons so Today, the Food diary and the meal
    // picker agree (Today hard-coded a different lunch icon).
    final icon = MealPresentationRegistry.forStableId(meal.mealType).icon;
    final compact = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    void showDetails() {
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => FoodMealDetailScreen(
              mealType: meal.mealType,
              selectedDate: selectedDate,
            ),
          ),
        ),
      );
    }

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(meal.label, style: B05Typography.label(context)),
        const SizedBox(height: 2),
        Text(meal.detail, style: B05Typography.caption(context)),
      ],
    );
    final calories = Text(
      meal.calorieLabel,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      // Meal accents tint only the meal icon; breakfast orange next to the
      // fat bar read as a macro (review O-4).
      style: B05Typography.label(context).copyWith(
        color: meal.nutritionIncomplete
            ? context.b05Colors.unavailable.indicator
            : context.b05Colors.textPrimary,
      ),
    );
    return Semantics(
      container: true,
      button: true,
      label: '${meal.label}. ${meal.detail}. ${meal.calorieLabel}',
      hint: 'Double tap to inspect this meal.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: B05Radii.smallRadius,
          onTap: showDetails,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: B05Layout.space4),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MealIcon(icon: icon, color: role),
                          const SizedBox(width: B05Layout.space8),
                          Expanded(child: summary),
                          B05IconAction(
                            icon: Icons.add_circle_outline_rounded,
                            label: 'Add ${meal.label}',
                            hint: 'Log food to ${meal.label.toLowerCase()}.',
                            onPressed: onAdd,
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: B05Layout.space32 + B05Layout.space8,
                          top: B05Layout.space4,
                        ),
                        child: calories,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      MealIcon(icon: icon, color: role),
                      const SizedBox(width: B05Layout.space8),
                      Expanded(child: summary),
                      const SizedBox(width: B05Layout.space8),
                      // Fixed column so every meal's + sits at the same x.
                      SizedBox(width: _kMealCalorieColumn, child: calories),
                      const SizedBox(width: B05Layout.space4),
                      B05IconAction(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Add ${meal.label}',
                        hint: 'Log food to ${meal.label.toLowerCase()}.',
                        onPressed: onAdd,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

const double _kMealCalorieColumn = 72;

class MealIcon extends StatelessWidget {
  const MealIcon({super.key, required this.icon, required this.color});

  final IconData icon;
  final B05ColorRole color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color.container, shape: BoxShape.circle),
    child: Padding(
      padding: const EdgeInsets.all(B05Layout.space8),
      child: Icon(icon, size: B05Layout.iconSmall, color: color.indicator),
    ),
  );
}

class TodayWorkoutModule extends StatelessWidget {
  const TodayWorkoutModule({
    super.key,
    required this.presentation,
    required this.onOpenWorkoutPlan,
    required this.onStartWorkout,
    required this.canStart,
    required this.onRetry,
  });

  final TodayWorkoutPresentation presentation;
  final VoidCallback onOpenWorkoutPlan;
  final ValueChanged<CalendarOccurrenceReadItem> onStartWorkout;
  final bool canStart;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const TodayModuleSkeleton(label: 'Checking your workout');
    }
    if (presentation.state == TodayPresentationState.unavailable) {
      return TodayUnavailableModule(
        title: 'Workout unavailable',
        detail: presentation.detail,
        onRetry: onRetry,
      );
    }
    final startable =
        canStart && presentation.canStart && presentation.occurrence != null;
    return B05Surface(
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            presentation.state == TodayPresentationState.empty
                ? Icons.self_improvement_outlined
                : Icons.fitness_center_rounded,
            color: context.b05Colors.info.indicator,
          ),
          const SizedBox(width: B05Layout.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Workout', style: todayEyebrow(context)),
                const SizedBox(height: B05Layout.space4),
                Text(presentation.title, style: B05Typography.title(context)),
                const SizedBox(height: B05Layout.space4),
                Text(presentation.detail, style: B05Typography.body(context)),
                const SizedBox(height: B05Layout.space8),
                B05ActionButton(
                  label: startable
                      ? presentation.isInProgress
                            ? 'Resume workout'
                            : 'Start workout'
                      : presentation.state == TodayPresentationState.empty
                      ? 'Choose workout'
                      : 'View workout',
                  icon: startable
                      ? Icons.play_arrow_rounded
                      : Icons.calendar_month_outlined,
                  emphasis: startable
                      ? B05ActionEmphasis.primary
                      : B05ActionEmphasis.secondary,
                  onPressed: startable
                      ? () => onStartWorkout(presentation.occurrence!)
                      : onOpenWorkoutPlan,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TodayActivityModule extends StatelessWidget {
  const TodayActivityModule({
    super.key,
    required this.presentation,
    required this.onRetry,
  });

  final TodayActivityPresentation presentation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const TodayModuleSkeleton(label: 'Preparing activity');
    }
    if (presentation.state == TodayPresentationState.unavailable) {
      return TodayUnavailableModule(
        title: 'Activity unavailable',
        detail: presentation.detail,
        onRetry: onRetry,
      );
    }
    return Semantics(
      container: true,
      label: '${presentation.headline}. ${presentation.detail}',
      child: B05Surface(
        tone: B05SurfaceTone.inset,
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              color: context.b05Colors.info.indicator,
            ),
            const SizedBox(width: B05Layout.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Activity', style: todayEyebrow(context)),
                  const SizedBox(height: B05Layout.space4),
                  Text(
                    presentation.headline,
                    style: B05Typography.label(context),
                  ),
                  const SizedBox(height: B05Layout.space4),
                  Text(presentation.detail, style: B05Typography.body(context)),
                  if (presentation.latestActivity != null) ...[
                    const SizedBox(height: B05Layout.space8),
                    Text(
                      'Latest: ${presentation.latestActivity}',
                      style: B05Typography.caption(context),
                    ),
                  ],
                  if (presentation.dailyMovementSummary != null &&
                      presentation.sessionCount != null) ...[
                    const SizedBox(height: B05Layout.space8),
                    Text(
                      presentation.dailyMovementSummary!,
                      style: B05Typography.caption(context),
                    ),
                  ],
                  if (presentation.primarySource != null) ...[
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      'Source: ${presentation.primarySource}',
                      style: B05Typography.caption(context).copyWith(
                        color: context.b05Colors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TodayProgressModule extends StatelessWidget {
  const TodayProgressModule({
    super.key,
    required this.presentation,
    required this.onRetry,
  });

  final TodayProgressPresentation presentation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const TodayModuleSkeleton(label: 'Preparing progress');
    }
    if (presentation.state == TodayPresentationState.unavailable) {
      return TodayUnavailableModule(
        title: 'Progress unavailable',
        detail: presentation.detail,
        onRetry: onRetry,
      );
    }
    return Semantics(
      container: true,
      label: 'Progress. ${presentation.headline}. ${presentation.detail}',
      child: B05Surface(
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progress', style: todayEyebrow(context)),
            const SizedBox(height: B05Layout.space4),
            Text(presentation.headline, style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space4),
            Text(presentation.detail, style: B05Typography.body(context)),
            if (presentation.supporting != null) ...[
              const SizedBox(height: B05Layout.space8),
              Text(
                presentation.supporting!,
                style: B05Typography.caption(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CollapsedTodayModule extends StatelessWidget {
  const CollapsedTodayModule({
    super.key,
    required this.label,
    required this.onExpand,
  });

  final String label;
  final Future<void> Function() onExpand;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label collapsed',
    hint: 'Double tap to expand $label.',
    child: B05Surface(
      tone: B05SurfaceTone.inset,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          title: Text(label, style: B05Typography.label(context)),
          subtitle: Text('Collapsed', style: B05Typography.caption(context)),
          trailing: const Icon(Icons.expand_more_rounded),
          onTap: () => unawaited(onExpand()),
        ),
      ),
    ),
  );
}

class TodayModuleSkeleton extends StatelessWidget {
  const TodayModuleSkeleton({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: label,
    child: B05Surface(
      padding: const EdgeInsets.all(B05Layout.space16),
      // Full width: the surface shrink-wraps its child, so the 0.82 line
      // used to size the whole card.
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            LoadingLine(widthFactor: .35, height: 14),
            SizedBox(height: B05Layout.space12),
            LoadingLine(widthFactor: .82, height: 20),
            SizedBox(height: B05Layout.space8),
            LoadingLine(widthFactor: .58, height: 14),
          ],
        ),
      ),
    ),
  );
}

class LoadingLine extends StatelessWidget {
  const LoadingLine({
    super.key,
    required this.widthFactor,
    required this.height,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final line = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.inset,
        borderRadius: B05Radii.smallRadius,
      ),
      child: SizedBox(height: height),
    );
    // Same shimmer as SkeletonBox/SkeletonCard so the cards read as loading.
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: B05MotionPolicy.reduceMotion(context)
          ? line
          : line
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .shimmer(duration: 1200.ms, color: colors.interactive),
    );
  }
}

class TodayUnavailableModule extends StatelessWidget {
  const TodayUnavailableModule({
    super.key,
    required this.title,
    required this.detail,
    required this.onRetry,
  });

  final String title;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => B05Surface(
    tone: B05SurfaceTone.inset,
    padding: const EdgeInsets.all(B05Layout.space16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          color: context.b05Colors.unavailable.indicator,
        ),
        const SizedBox(width: B05Layout.space8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: B05Typography.label(context)),
              const SizedBox(height: B05Layout.space4),
              Text(detail, style: B05Typography.body(context)),
              const SizedBox(height: B05Layout.space8),
              B05ActionButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class TodayInlineProgress extends StatelessWidget {
  const TodayInlineProgress({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      B05MotionPolicy.reduceMotion(context)
          ? Icon(
              Icons.hourglass_top_rounded,
              size: B05Layout.iconSmall,
              color: context.b05Colors.action,
            )
          : SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.b05Colors.action,
              ),
            ),
      const SizedBox(width: B05Layout.space8),
      Text(label, style: B05Typography.caption(context)),
    ],
  );
}

class TodayRetry extends StatelessWidget {
  const TodayRetry({super.key, required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(
        Icons.info_outline,
        size: B05Layout.iconSmall,
        color: context.b05Colors.unavailable.indicator,
      ),
      const SizedBox(width: B05Layout.space8),
      Expanded(child: Text(title, style: B05Typography.caption(context))),
      B05ActionButton(
        label: 'Retry',
        icon: Icons.refresh_rounded,
        emphasis: B05ActionEmphasis.secondary,
        onPressed: onRetry,
      ),
    ],
  );
}

class NoVisibleModules extends StatelessWidget {
  const NoVisibleModules({super.key, required this.onCustomize});

  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) => B05Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Today view is clear', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Choose a few modules to bring your daily plan back.',
          style: B05Typography.body(context),
        ),
        const SizedBox(height: B05Layout.space12),
        B05ActionButton(
          label: ConsumerCopy.customizeTodayAction,
          icon: Icons.tune_rounded,
          onPressed: onCustomize,
        ),
      ],
    ),
  );
}
