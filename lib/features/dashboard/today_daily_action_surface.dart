import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/nutrition_legacy_read_models.dart';
import '../../core/presentation/consumer_number_label.dart';
import '../../core/presentation/daypart_greeting.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/models/b02_progress_read_models.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../food_log/food_search_screen.dart';
import 'dashboard_module_registry.dart';
import 'dashboard_personalization_controller.dart';
import 'today_consumer_presentation.dart';
import 'today_presentation_types.dart';
import 'today_surface_controller.dart';
import 'widgets/dashboard_date_bar.dart';

export 'today_presentation_types.dart';

TodayDateRelation todayDateRelation(DateTime selectedDate, DateTime now) {
  DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);
  final selected = day(selectedDate);
  final current = day(now);
  if (selected.isBefore(current)) return TodayDateRelation.past;
  if (selected.isAfter(current)) return TodayDateRelation.future;
  return TodayDateRelation.today;
}

class TodayNextActionChoice {
  final TodayNextAction action;
  final String label;
  final String hint;

  const TodayNextActionChoice({
    required this.action,
    required this.label,
    required this.hint,
  });
}

/// Selects only among routes already owned by the application. It does not
/// rank workouts, calculate a recommendation, or infer a nutrition target.
TodayNextActionChoice chooseTodayNextAction({
  required TodayDateRelation dateRelation,
  TodaySurfaceSnapshot? snapshot,
}) {
  if (dateRelation == TodayDateRelation.future) {
    return const TodayNextActionChoice(
      action: TodayNextAction.returnToToday,
      label: 'Return to today',
      hint: 'Shows actions that are available today.',
    );
  }
  final scheduled = snapshot?.calendar.value?.rangeOccurrences.isNotEmpty;
  if (scheduled == true) {
    return const TodayNextActionChoice(
      action: TodayNextAction.openWorkoutPlan,
      label: 'View today’s workout',
      hint: 'Opens your workout plan for today.',
    );
  }
  final nutrition = snapshot?.nutrition.value;
  if (nutrition != null && nutrition.records.isEmpty) {
    return const TodayNextActionChoice(
      action: TodayNextAction.logMeal,
      label: 'Log your first meal',
      hint: 'Opens the food logging flow for this day.',
    );
  }
  return const TodayNextActionChoice(
    action: TodayNextAction.openWorkoutPlan,
    label: 'Open workout plan',
    hint: 'Choose a workout or take a recovery day.',
  );
}

enum TodayNutritionSummaryState { known, range, unknown, empty }

TodayNutritionSummaryState todayNutritionSummaryState(
  NutritionDailyReadModel daily,
) {
  if (daily.records.isEmpty) return TodayNutritionSummaryState.empty;
  final fact = daily.totals.facts['energy'];
  if (fact == null || !fact.isAvailable) {
    return TodayNutritionSummaryState.unknown;
  }
  if (fact.lower != null || fact.upper != null) {
    return TodayNutritionSummaryState.range;
  }
  return TodayNutritionSummaryState.known;
}

/// The R2 Today composition. It reads source-owned B01–B04 projections and
/// B05 layout preferences; it does not query Drift or calculate domain facts.
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
    this.onOpenFoodGuidance,
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
  final VoidCallback? onOpenFoodGuidance;

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
    final layout = personalization.layout.isEmpty
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
    );
    final activity = TodayActivityPresentation.from(
      snapshot?.progress ??
          (unavailable
              ? const TodayDomainRead<B02ProgressReadModel>.unavailable(
                  'Activity unavailable',
                )
              : null),
      loading: loading,
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
    final nextUpVisible = layout.any(
      (item) => item.moduleId == 'today.next_action' && item.isVisible,
    );

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
                  _TodayHeader(
                    userName: userName,
                    streakCount: streakCount,
                    selectedDate: selectedDate,
                    referenceNow: now,
                    onOpenSettings: onOpenSettings,
                    onCustomize: onCustomize,
                  ),
                  const SizedBox(height: B05Layout.space12),
                  DashboardDateBar(
                    selectedDate: selectedDate,
                    today: referenceNow,
                    onDateChanged: onDateChanged,
                  ),
                  if (personalization.status ==
                      DashboardPersonalizationStatus.saving)
                    const Padding(
                      padding: EdgeInsets.only(top: B05Layout.space8),
                      child: _TodayInlineProgress(label: 'Saving Today layout'),
                    ),
                  if (personalization.status ==
                      DashboardPersonalizationStatus.error)
                    Padding(
                      padding: const EdgeInsets.only(top: B05Layout.space8),
                      child: _TodayRetry(
                        title: 'Your layout could not be saved',
                        onRetry: personalizationController.retry,
                      ),
                    ),
                  const SizedBox(height: B05Layout.space16),
                  for (final item in layout)
                    if (item.isVisible) ...[
                      _module(
                        context: context,
                        ref: ref,
                        item: item,
                        relation: relation,
                        nutrition: nutrition,
                        nextUp: nextUp,
                        workout: workout,
                        activity: activity,
                        progress: progress,
                        hideWorkoutDuplicate:
                            nextUpVisible &&
                            (nextUp.action == TodayNextAction.startWorkout ||
                                nextUp.action ==
                                    TodayNextAction.openWorkoutPlan),
                        onRetry: () => ref.invalidate(
                          todaySurfaceSnapshotProvider(selectedDate),
                        ),
                        onLogMeal: _openMeal,
                        onStartWorkout: _startWorkout,
                        onOpenFoodGuidance: onOpenFoodGuidance ?? () {},
                        selectedDate: selectedDate,
                        onExpand: () => personalizationController.setCollapsed(
                          item.moduleId,
                          false,
                        ),
                      ),
                      const SizedBox(height: B05Layout.space12),
                    ],
                  if (!layout.any((item) => item.isVisible))
                    _NoVisibleModules(onCustomize: onCustomize),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

  Widget _module({
    required BuildContext context,
    required WidgetRef ref,
    required DashboardModuleLayoutItem item,
    required TodayDateRelation relation,
    required TodayNutritionPresentation nutrition,
    required TodayFocusPresentation nextUp,
    required TodayWorkoutPresentation workout,
    required TodayActivityPresentation activity,
    required TodayProgressPresentation progress,
    required bool hideWorkoutDuplicate,
    required VoidCallback onRetry,
    required ValueChanged<String> onLogMeal,
    required ValueChanged<CalendarOccurrenceReadItem> onStartWorkout,
    required VoidCallback onOpenFoodGuidance,
    required Future<void> Function() onExpand,
    required DateTime selectedDate,
  }) {
    if (item.isCollapsed && item.descriptor.collapsible) {
      return _CollapsedTodayModule(
        label: item.descriptor.label,
        onExpand: onExpand,
      );
    }
    return switch (item.moduleId) {
      'today.meals' => _TodayNutritionHero(
        presentation: nutrition,
        onLogFood: () => onLogMeal(''),
        onOpenFoodGuidance: onOpenFoodGuidance,
        onOpenTargetSetup: onOpenSettings,
        onRetry: onRetry,
      ),
      'today.next_action' => _TodayNextUpModule(
        presentation: nextUp,
        onOpenWorkoutPlan: onOpenWorkoutPlan,
        onLogMeal: () => onLogMeal(''),
        onReturnToToday: () => onDateChanged(now ?? DateTime.now()),
        onStartWorkout: onStartWorkout,
        onRetry: onRetry,
      ),
      'today.meal_rows' => _TodayMealsModule(
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
      'today.workout' => _TodayWorkoutModule(
        presentation: workout,
        onOpenWorkoutPlan: onOpenWorkoutPlan,
        onStartWorkout: onStartWorkout,
        canStart: relation == TodayDateRelation.today,
        onRetry: onRetry,
      ),
      'today.activity' => _TodayActivityModule(
        presentation: activity,
        onRetry: onRetry,
      ),
      'today.progress' => _TodayProgressModule(
        presentation: progress,
        onRetry: onRetry,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _TodayHeader extends StatefulWidget {
  const _TodayHeader({
    required this.userName,
    required this.streakCount,
    required this.selectedDate,
    required this.referenceNow,
    required this.onOpenSettings,
    required this.onCustomize,
  });

  final String userName;
  final int streakCount;
  final DateTime selectedDate;
  final DateTime? referenceNow;
  final VoidCallback onOpenSettings;
  final VoidCallback onCustomize;

  @override
  State<_TodayHeader> createState() => _TodayHeaderState();
}

class _TodayHeaderState extends State<_TodayHeader>
    with WidgetsBindingObserver {
  late DateTime _localNow;

  @override
  void initState() {
    super.initState();
    _localNow = widget.referenceNow ?? DateTime.now();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _TodayHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.referenceNow != oldWidget.referenceNow) {
      _localNow = widget.referenceNow ?? DateTime.now();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.referenceNow == null &&
        mounted) {
      setState(() => _localNow = DateTime.now());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userName.trim();
    final greeting = daypartGreeting(_localNow);
    final date = DateFormat('EEEE, d MMMM').format(widget.selectedDate);
    return Semantics(
      container: true,
      header: true,
      label: name.isEmpty || name == 'there' ? greeting : '$greeting, $name',
      value: date,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty || name == 'there'
                      ? greeting
                      : '$greeting, $name',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: B05Typography.pageTitle(context),
                ),
                const SizedBox(height: B05Layout.space4),
                Text(date, style: B05Typography.body(context)),
                if (widget.streakCount > 0) ...[
                  const SizedBox(height: B05Layout.space8),
                  _StreakChip(count: widget.streakCount),
                ],
              ],
            ),
          ),
          B05IconAction(
            icon: Icons.tune_rounded,
            label: 'Customize Today',
            hint: 'Reorder, show, hide, or collapse Today modules.',
            onPressed: widget.onCustomize,
            focusOrder: 0,
          ),
          B05IconAction(
            icon: Icons.settings_outlined,
            label: 'Open settings',
            onPressed: widget.onOpenSettings,
            focusOrder: 1,
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    return Semantics(
      label: '$count day streak',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.b05Colors.warning.container,
          borderRadius: B05Radii.smallRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: B05Layout.space8,
            vertical: B05Layout.space4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_outlined,
                size: B05Layout.iconSmall,
                color: context.b05Colors.warning.indicator,
              ),
              const SizedBox(width: B05Layout.space4),
              Text(
                compact ? '$count' : '$count day streak',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: B05Typography.caption(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayNutritionHero extends StatelessWidget {
  const _TodayNutritionHero({
    required this.presentation,
    required this.onLogFood,
    required this.onOpenFoodGuidance,
    required this.onOpenTargetSetup,
    required this.onRetry,
  });

  final TodayNutritionPresentation presentation;
  final VoidCallback onLogFood;
  final VoidCallback onOpenFoodGuidance;
  final VoidCallback onOpenTargetSetup;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const _TodayModuleSkeleton(label: 'Preparing nutrition');
    }
    if (presentation.state == TodayPresentationState.unavailable) {
      return _TodayUnavailableModule(
        title: 'Nutrition unavailable',
        detail: 'Try again to load your meals and nutrition.',
        onRetry: onRetry,
      );
    }
    return Semantics(
      container: true,
      label: 'Nutrition. ${presentation.headline}',
      child: B05Surface(
        radius: B05SurfaceRadius.large,
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrition', style: B05Typography.title(context)),
            const SizedBox(height: B05Layout.space12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < B05Layout.compactBreakpoint ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.35;
                final ring = _CalorieRing(
                  calories: presentation.calories,
                  hasTarget: presentation.hasAcceptedCalorieTarget,
                  incomplete: presentation.hasIncompleteNutrition,
                  noConsumption: presentation.isNoConsumptionKnown,
                );
                final macros = _MacroComparison(metrics: presentation.macros);
                return compact
                    ? Column(
                        children: [
                          ring,
                          const SizedBox(height: B05Layout.space16),
                          macros,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ring,
                          const SizedBox(width: B05Layout.space20),
                          Expanded(child: macros),
                        ],
                      );
              },
            ),
            if (presentation.hasIncompleteNutrition) ...[
              const SizedBox(height: B05Layout.space12),
              _NutritionNotice(
                icon: Icons.info_outline_rounded,
                label: 'Some nutrition is incomplete',
                color: context.b05Colors.unavailable.indicator,
              ),
            ],
            if (!presentation.hasAcceptedCalorieTarget) ...[
              const SizedBox(height: B05Layout.space12),
              _NutritionNotice(
                icon: Icons.track_changes_outlined,
                label: 'No daily target set',
                color: context.b05Colors.unavailable.indicator,
              ),
            ],
            const SizedBox(height: B05Layout.space16),
            Wrap(
              spacing: B05Layout.space8,
              runSpacing: B05Layout.space8,
              children: [
                B05ActionButton(
                  label: 'Log food',
                  icon: Icons.add_rounded,
                  hint: 'Search foods and log them for this day.',
                  onPressed: onLogFood,
                ),
                B05ActionButton(
                  label: 'What can I eat?',
                  icon: Icons.lightbulb_outline_rounded,
                  hint: 'Shows a concise meal suggestion when one is ready.',
                  emphasis: B05ActionEmphasis.secondary,
                  onPressed: onOpenFoodGuidance,
                ),
                if (!presentation.hasAcceptedCalorieTarget)
                  B05ActionButton(
                    label: 'Set a target',
                    emphasis: B05ActionEmphasis.tertiary,
                    hint: 'Opens settings where you can set your own target.',
                    onPressed: onOpenTargetSetup,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionNotice extends StatelessWidget {
  const _NutritionNotice({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Row(
      children: [
        Icon(icon, size: B05Layout.iconSmall, color: color),
        const SizedBox(width: B05Layout.space8),
        Expanded(child: Text(label, style: B05Typography.caption(context))),
      ],
    ),
  );
}

class _CalorieRing extends StatelessWidget {
  const _CalorieRing({
    required this.calories,
    required this.hasTarget,
    required this.incomplete,
    required this.noConsumption,
  });

  final TodayNutritionMetricPresentation? calories;
  final bool hasTarget;
  final bool incomplete;
  final bool noConsumption;

  @override
  Widget build(BuildContext context) {
    final metric = calories;
    if (metric == null) {
      return Semantics(
        label: 'Calories are unavailable.',
        child: const SizedBox(width: 152, height: 152),
      );
    }
    final colors = context.b05Colors;
    final isOver = metric.isOverTarget;
    final color = isOver ? colors.danger.indicator : colors.success.indicator;
    final high = hasTarget
        ? metric.upperProgress ?? metric.progress ?? 0.0
        : 0.0;
    final low = hasTarget ? metric.lowerProgress ?? high : 0;
    final reduceMotion = B05MotionPolicy.reduceMotion(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final diameter = largeText ? 176.0 : 152.0;
    final inset = largeText ? B05Layout.space16 : B05Layout.space20;
    final targetText = metric.hasTarget
        ? 'of ${_formatMetric(metric.targetValue!)} kcal'
        : metric.isAvailable
        ? 'kcal logged'
        : 'Nutrition incomplete';
    final status = !metric.isAvailable
        ? '—'
        : metric.isRange
        ? '${metric.value} kcal range'
        : metric.hasTarget
        ? isOver
              ? '${_formatMetric(metric.pointValue! - metric.targetValue!)} over'
              : '${_formatMetric(metric.targetValue! - (metric.pointValue ?? 0))} left'
        : noConsumption
        ? 'No meals yet'
        : incomplete
        ? 'Some nutrition incomplete'
        : 'Calories logged';
    final statusColor = isOver
        ? colors.danger.indicator
        : incomplete && !metric.isAvailable
        ? colors.unavailable.indicator
        : colors.textSecondary;
    final semantics = metric.isAvailable
        ? metric.hasTarget
              ? 'Calories ${metric.value} of ${_formatMetric(metric.targetValue!)} kilocalories. $status.'
              : 'Calories ${metric.value} kilocalories logged. No target set.'
        : 'Calories are incomplete. No total is shown.';

    return Semantics(
      label: semantics,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: high),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            final lowValue = high == 0 ? 0.0 : low * (value / high);
            return SizedBox(
              width: diameter,
              height: diameter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CalorieRingPainter(
                        progressLow: lowValue,
                        progressHigh: value,
                        color: color,
                        trackColor: colors.inset,
                        range: metric.isRange,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(inset),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          child: Text(
                            metric.value,
                            style: B05Typography.metric(
                              context,
                            ).copyWith(fontSize: 31, letterSpacing: -1),
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            targetText,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: B05Typography.caption(context),
                          ),
                        ),
                        const SizedBox(height: B05Layout.space4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            status,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: B05Typography.caption(context).copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  const _CalorieRingPainter({
    required this.progressLow,
    required this.progressHigh,
    required this.color,
    required this.trackColor,
    required this.range,
  });

  final double progressLow;
  final double progressHigh;
  final Color color;
  final Color trackColor;
  final bool range;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -1.5708, 6.28318, false, track);
    if (progressHigh <= 0) return;
    final base = Paint()
      ..color = range ? color.withValues(alpha: .48) : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (progressLow > 0) {
      canvas.drawArc(rect, -1.5708, 6.28318 * progressLow, false, base);
    }
    final remaining = progressHigh - progressLow;
    if (remaining > 0) {
      final high = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        -1.5708 + 6.28318 * progressLow,
        6.28318 * remaining,
        false,
        high,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) =>
      oldDelegate.progressLow != progressLow ||
      oldDelegate.progressHigh != progressHigh ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.range != range;
}

class _MacroComparison extends StatelessWidget {
  const _MacroComparison({required this.metrics});

  final List<TodayNutritionMetricPresentation> metrics;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < metrics.length; index++) ...[
        _MacroRow(metric: metrics[index]),
        if (index < metrics.length - 1)
          const SizedBox(height: B05Layout.space12),
      ],
    ],
  );
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.metric});

  final TodayNutritionMetricPresentation metric;

  @override
  Widget build(BuildContext context) {
    final role = switch (metric.nutrientId) {
      'protein' => context.b05Colors.success,
      'carbohydrate' => context.b05Colors.warning,
      'fat' => context.b05Colors.danger,
      'fibre' => context.b05Colors.info,
      _ => context.b05Colors.unavailable,
    };
    final icon = switch (metric.nutrientId) {
      'protein' => Icons.egg_alt_outlined,
      'carbohydrate' => Icons.grain_outlined,
      'fat' => Icons.water_drop_outlined,
      'fibre' => Icons.eco_outlined,
      _ => Icons.circle_outlined,
    };
    final compact = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final label =
        '${metric.label}: ${metric.comparisonLabel}'
        '${metric.estimated ? ', estimated' : ''}'
        '${metric.isIncomplete ? ', incomplete' : ''}';
    final header = Row(
      children: [
        Icon(icon, size: B05Layout.iconSmall, color: role.indicator),
        const SizedBox(width: B05Layout.space4),
        Expanded(
          child: Text(metric.label, style: B05Typography.label(context)),
        ),
        if (!compact)
          Flexible(
            child: Text(
              metric.comparisonLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: B05Typography.caption(context).copyWith(
                color: metric.isOverTarget
                    ? context.b05Colors.danger.indicator
                    : context.b05Colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            if (compact) ...[
              const SizedBox(height: B05Layout.space4),
              Text(
                metric.comparisonLabel,
                style: B05Typography.caption(context).copyWith(
                  color: metric.isOverTarget
                      ? context.b05Colors.danger.indicator
                      : context.b05Colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (metric.estimated || metric.isIncomplete) ...[
              const SizedBox(height: B05Layout.space4),
              Text(
                metric.estimated ? 'Estimated' : 'Some details are incomplete',
                style: B05Typography.caption(context),
              ),
            ],
            const SizedBox(height: B05Layout.space4),
            _MacroProgress(metric: metric, color: role.indicator),
          ],
        ),
      ),
    );
  }
}

class _MacroProgress extends StatelessWidget {
  const _MacroProgress({required this.metric, required this.color});

  final TodayNutritionMetricPresentation metric;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (!metric.isAvailable) {
      return Text('Not available', style: B05Typography.caption(context));
    }
    if (!metric.hasTarget || metric.progress == null) {
      return Text('No target set', style: B05Typography.caption(context));
    }
    final reduceMotion = B05MotionPolicy.reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: metric.upperProgress ?? metric.progress!),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final high = metric.upperProgress ?? value;
        final low = metric.lowerProgress ?? high;
        final displayedLow = high == 0 ? 0.0 : low * (value / high);
        return SizedBox(
          height: 7,
          width: double.infinity,
          child: CustomPaint(
            painter: _RangeBarPainter(
              low: displayedLow,
              high: value,
              color: metric.isOverTarget
                  ? context.b05Colors.danger.indicator
                  : color,
              track: context.b05Colors.inset,
              isRange: metric.isRange,
            ),
          ),
        );
      },
    );
  }
}

class _RangeBarPainter extends CustomPainter {
  const _RangeBarPainter({
    required this.low,
    required this.high,
    required this.color,
    required this.track,
    required this.isRange,
  });

  final double low;
  final double high;
  final Color color;
  final Color track;
  final bool isRange;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = track,
    );
    if (low > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * low, size.height),
          radius,
        ),
        Paint()..color = isRange ? color.withValues(alpha: .45) : color,
      );
    }
    if (high > low) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * low,
            0,
            size.width * (high - low),
            size.height,
          ),
          radius,
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RangeBarPainter oldDelegate) =>
      oldDelegate.low != low ||
      oldDelegate.high != high ||
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.isRange != isRange;
}

class _TodayNextUpModule extends StatelessWidget {
  const _TodayNextUpModule({
    required this.presentation,
    required this.onOpenWorkoutPlan,
    required this.onLogMeal,
    required this.onReturnToToday,
    required this.onStartWorkout,
    required this.onRetry,
  });

  final TodayFocusPresentation presentation;
  final VoidCallback onOpenWorkoutPlan;
  final VoidCallback onLogMeal;
  final VoidCallback onReturnToToday;
  final ValueChanged<CalendarOccurrenceReadItem> onStartWorkout;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const _TodayModuleSkeleton(label: 'Preparing your next step');
    }
    if (presentation.state == TodayPresentationState.unavailable) {
      return _TodayUnavailableModule(
        title: 'Next up unavailable',
        detail: 'Try again to load a useful next step.',
        onRetry: onRetry,
      );
    }
    final action = presentation.action!;
    final callback = switch (action) {
      TodayNextAction.startWorkout when presentation.workout != null =>
        () => onStartWorkout(presentation.workout!),
      TodayNextAction.openWorkoutPlan => onOpenWorkoutPlan,
      TodayNextAction.logMeal => onLogMeal,
      TodayNextAction.returnToToday => onReturnToToday,
      _ => onOpenWorkoutPlan,
    };
    final icon = switch (action) {
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
                  Text('NEXT UP', style: _eyebrow(context)),
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

class _TodayMealsModule extends StatelessWidget {
  const _TodayMealsModule({
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
    if (loading) return const _TodayModuleSkeleton(label: 'Preparing meals');
    if (unavailable) {
      return _TodayUnavailableModule(
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
              _TodayMealRow(
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

class _TodayMealRow extends StatelessWidget {
  const _TodayMealRow({
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
      _ => context.b05Colors.snack,
    };
    final icon = switch (meal.mealType) {
      'breakfast' => Icons.wb_sunny_outlined,
      'lunch' => Icons.wb_sunny_rounded,
      'dinner' => Icons.nightlight_round,
      _ => Icons.cookie_outlined,
    };
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
      style: B05Typography.label(context).copyWith(
        color: meal.nutritionIncomplete
            ? context.b05Colors.unavailable.indicator
            : role.indicator,
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
                          _MealIcon(icon: icon, color: role),
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
                      _MealIcon(icon: icon, color: role),
                      const SizedBox(width: B05Layout.space8),
                      Expanded(child: summary),
                      const SizedBox(width: B05Layout.space8),
                      Flexible(child: calories),
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

class _MealIcon extends StatelessWidget {
  const _MealIcon({required this.icon, required this.color});

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

class _TodayWorkoutModule extends StatelessWidget {
  const _TodayWorkoutModule({
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
      return const _TodayModuleSkeleton(label: 'Checking your workout');
    }
    if (presentation.state == TodayPresentationState.unavailable) {
      return _TodayUnavailableModule(
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
                Text('Workout', style: _eyebrow(context)),
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

class _TodayActivityModule extends StatelessWidget {
  const _TodayActivityModule({
    required this.presentation,
    required this.onRetry,
  });

  final TodayActivityPresentation presentation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const _TodayModuleSkeleton(label: 'Preparing activity');
    }
    if (presentation.state == TodayPresentationState.unavailable) {
      return _TodayUnavailableModule(
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
                  Text('ACTIVITY', style: _eyebrow(context)),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayProgressModule extends StatelessWidget {
  const _TodayProgressModule({
    required this.presentation,
    required this.onRetry,
  });

  final TodayProgressPresentation presentation;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const _TodayModuleSkeleton(label: 'Preparing progress');
    }
    if (presentation.state == TodayPresentationState.unavailable) {
      return _TodayUnavailableModule(
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
            Text('PROGRESS', style: _eyebrow(context)),
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

class _CollapsedTodayModule extends StatelessWidget {
  const _CollapsedTodayModule({required this.label, required this.onExpand});

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

class _TodayModuleSkeleton extends StatelessWidget {
  const _TodayModuleSkeleton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: label,
    child: B05Surface(
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _LoadingLine(widthFactor: .35, height: 14),
          SizedBox(height: B05Layout.space12),
          _LoadingLine(widthFactor: .82, height: 20),
          SizedBox(height: B05Layout.space8),
          _LoadingLine(widthFactor: .58, height: 14),
        ],
      ),
    ),
  );
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: widthFactor,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.b05Colors.inset,
        borderRadius: B05Radii.smallRadius,
      ),
      child: SizedBox(height: height),
    ),
  );
}

class _TodayUnavailableModule extends StatelessWidget {
  const _TodayUnavailableModule({
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

class _TodayInlineProgress extends StatelessWidget {
  const _TodayInlineProgress({required this.label});

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

class _TodayRetry extends StatelessWidget {
  const _TodayRetry({required this.title, required this.onRetry});

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

class _NoVisibleModules extends StatelessWidget {
  const _NoVisibleModules({required this.onCustomize});

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
          label: 'Customize Today',
          icon: Icons.tune_rounded,
          onPressed: onCustomize,
        ),
      ],
    ),
  );
}

TextStyle _eyebrow(BuildContext context) => B05Typography.caption(
  context,
).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.1);

String _formatMetric(double value) {
  return ConsumerNumberLabel.rounded(value);
}
