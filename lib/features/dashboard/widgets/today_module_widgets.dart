import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/motion/indifit_motion.dart';
import '../../../core/presentation/consumer_copy.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/calendar_read_repository.dart';
import '../../food_log/food_search_screen.dart';
import '../../food_log/meal_presentation_registry.dart';
import '../../food_log/widgets/meal_icon_chip.dart';
import '../today_consumer_presentation.dart';
import '../today_presentation_types.dart';
import 'today_helpers.dart';
import 'today_motion.dart';
import 'today_nutrition_widgets.dart';

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
        lift: true,
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meals', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space8),
            for (var index = 0; index < meals.length; index++) ...[
              TodayMealRow(
                key: TodayMotion.maybeOf(
                  context,
                )?.rowKey(meals[index].mealType),
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
    // One source for meal marks so Today, the Food diary and the meal picker
    // agree (Today hard-coded a different lunch icon).
    final presentation = MealPresentationRegistry.forStableId(meal.mealType);
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
        Text(
          meal.detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: B05Typography.caption(context),
        ),
      ],
    );
    // Meal accents tint only the meal icon; breakfast orange next to the
    // fat bar read as a macro (review O-4).
    final caloriesStyle = B05Typography.label(context).copyWith(
      color: meal.nutritionIncomplete
          ? context.b05Colors.unavailable.indicator
          : context.b05Colors.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Text caloriesText(String text) => Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: caloriesStyle,
    );
    final kcal = meal.kcal ?? (meal.logged ? null : 0.0);
    // A log counts the row's kcal up from what it showed (T3).
    final calories = kcal == null
        ? caloriesText(meal.calorieLabel)
        : IndiFitCountUp(
            value: kcal,
            builder: (context, value) => caloriesText(
              meal.logged || value > 0
                  ? '${formatTodayMetric(value)} kcal'
                  : meal.calorieLabel,
            ),
          );
    final motion = TodayMotion.maybeOf(context);
    final moment = motion?.moment?.mealType == meal.mealType
        ? motion!.moment
        : null;
    final chipLabel = motion?.chipPlace == TodayChipPlace.row
        ? moment?.chipLabel
        : null;
    return Semantics(
      container: true,
      button: true,
      label: [
        meal.label,
        meal.detail,
        if (meal.calorieLabel.isNotEmpty) meal.calorieLabel,
      ].join('. '),
      hint: 'Double tap to inspect this meal.',
      child: TodayMealRowWash(
        serial: moment?.serial,
        chip: chipLabel == null
            ? null
            : TodayLoggedChip(
                key: ValueKey<int>(moment!.serial),
                label: chipLabel,
                onDone: motion!.onChipDone,
              ),
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
                            MealIconChip(
                              presentation: presentation,
                              color: role,
                            ),
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
                            left: 40 + B05Layout.space8,
                            top: B05Layout.space4,
                          ),
                          child: calories,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        MealIconChip(presentation: presentation, color: role),
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
      ),
    );
  }
}

const double _kMealCalorieColumn = 72;

/// A green wash behind a meal row whose food just changed, once per
/// [serial], with the "+kcal" [chip] rising from the row's kcal (T3).
class TodayMealRowWash extends StatefulWidget {
  const TodayMealRowWash({
    super.key,
    required this.serial,
    required this.child,
    this.chip,
  });

  final int? serial;
  final Widget child;
  final Widget? chip;

  @override
  State<TodayMealRowWash> createState() => _TodayMealRowWashState();
}

class _TodayMealRowWashState extends State<TodayMealRowWash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TodayMotionTiming.wash,
  );
  late final Animation<double> _wash = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: B05MotionPolicy.standardCurve)),
      weight: 20,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 25),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 55,
    ),
  ]).animate(_controller);
  int? _played;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePlay();
  }

  @override
  void didUpdateWidget(covariant TodayMealRowWash oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePlay();
  }

  void _maybePlay() {
    final serial = widget.serial;
    if (serial == null || serial == _played) return;
    if (!TickerMode.valuesOf(context).enabled) return;
    _played = serial;
    if (B05MotionPolicy.reduceMotion(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wash = context.b05Colors.success.container;
    final chip = widget.chip;
    // One structure with or without the chip, so the row keeps its
    // count-up state when the chip comes and goes.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _wash,
              builder: (context, _) => DecoratedBox(
                decoration: BoxDecoration(
                  color: wash.withValues(alpha: wash.a * .9 * _wash.value),
                  borderRadius: B05Radii.smallRadius,
                ),
              ),
            ),
          ),
        ),
        widget.child,
        Positioned(
          top: -B05Layout.space16,
          // Over the kcal column, clear of the + button.
          right: B05Layout.minTouchTarget + B05Layout.space4,
          child: chip ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
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
      lift: true,
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
        lift: true,
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
      lift: true,
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
    lift: true,
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
