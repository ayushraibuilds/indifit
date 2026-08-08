import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_legacy_read_models.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/models/b02_progress_read_models.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../coaching/b04_production_surface_widgets.dart';
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

/// Consumer Today composition. It consumes source-owned typed reads and the
/// normalized B05 module layout; it never queries Drift or derives domain
/// facts in a widget.
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

    return ColoredBox(
      color: context.b05Colors.page,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
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
                  _TodayGreeting(
                    userName: userName,
                    streakCount: streakCount,
                    referenceNow: referenceNow,
                    onOpenSettings: onOpenSettings,
                    onCustomize: onCustomize,
                  ),
                  const SizedBox(height: B05Layout.space12),
                  DashboardDateBar(
                    selectedDate: selectedDate,
                    today: referenceNow,
                    onDateChanged: onDateChanged,
                  ),
                  const SizedBox(height: B05Layout.space8),
                  _DateContext(relation: relation),
                  if (personalization.status ==
                      DashboardPersonalizationStatus.loading)
                    const _TodayInlineProgress(label: 'Preparing your layout'),
                  if (personalization.status ==
                      DashboardPersonalizationStatus.saving)
                    const _TodayInlineProgress(label: 'Saving your layout'),
                  if (personalization.status ==
                      DashboardPersonalizationStatus.error)
                    Padding(
                      padding: const EdgeInsets.only(top: B05Layout.space8),
                      child: _TodayRetry(
                        title: 'Your layout could not be saved',
                        onRetry: personalizationController.retry,
                      ),
                    ),
                  if (snapshotAsync.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: B05Layout.space8),
                      child: _TodayRetry(
                        title: 'Today could not be loaded',
                        onRetry: () => ref.invalidate(
                          todaySurfaceSnapshotProvider(selectedDate),
                        ),
                      ),
                    ),
                  const SizedBox(height: B05Layout.space12),
                  for (var index = 0; index < layout.length; index++)
                    if (layout[index].isVisible) ...[
                      _TodayModuleSurface(
                        item: layout[index],
                        index: index,
                        onCollapseChanged:
                            personalizationController.setCollapsed,
                        child: _moduleBody(
                          item: layout[index],
                          snapshot: snapshot,
                          loading:
                              snapshotAsync.isLoading &&
                              !snapshotAsync.hasError,
                          unavailable: snapshotAsync.hasError,
                          relation: relation,
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

  Widget _moduleBody({
    required DashboardModuleLayoutItem item,
    required TodaySurfaceSnapshot? snapshot,
    required bool loading,
    required bool unavailable,
    required TodayDateRelation relation,
  }) {
    final calendarRead =
        snapshot?.calendar ??
        (unavailable
            ? const TodayDomainRead<CalendarReadSnapshot>.unavailable(
                'Today information is unavailable right now.',
              )
            : null);
    final nutritionRead =
        snapshot?.nutrition ??
        (unavailable
            ? const TodayDomainRead<NutritionDailyReadModel>.unavailable(
                'Today information is unavailable right now.',
              )
            : null);
    final progressRead =
        snapshot?.progress ??
        (unavailable
            ? const TodayDomainRead<B02ProgressReadModel>.unavailable(
                'Today information is unavailable right now.',
              )
            : null);
    return switch (item.moduleId) {
      'today.next_action' => _TodayFocusModule(
        presentation: todayFocusPresentation(
          dateRelation: relation,
          snapshot: snapshot,
        ),
        onOpenWorkoutPlan: onOpenWorkoutPlan,
        onLogMeal: onLogMeal,
        onReturnToToday: () => onDateChanged(now ?? DateTime.now()),
      ),
      'today.workout' => _TodayWorkoutModule(
        presentation: TodayWorkoutPresentation.from(
          calendarRead,
          loading: loading,
        ),
        onOpenWorkoutPlan: onOpenWorkoutPlan,
      ),
      'today.meals' => _TodayNutritionModule(
        presentation: TodayNutritionPresentation.from(
          nutritionRead,
          loading: loading,
        ),
        showGuidance: relation == TodayDateRelation.today,
        onLogMeal: onLogMeal,
      ),
      'today.progress' => _TodayProgressModule(
        presentation: TodayProgressPresentation.from(
          progressRead,
          loading: loading,
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _TodayGreeting extends StatelessWidget {
  const _TodayGreeting({
    required this.userName,
    required this.streakCount,
    required this.referenceNow,
    required this.onOpenSettings,
    required this.onCustomize,
  });

  final String userName;
  final int streakCount;
  final DateTime referenceNow;
  final VoidCallback onOpenSettings;
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    final name = userName.trim();
    final greeting = switch (referenceNow.hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            label: 'Today',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty || name == 'there'
                      ? greeting
                      : '$greeting, $name',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: context.b05Colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: B05Layout.space4),
                Text(
                  streakCount > 0
                      ? '$streakCount-day streak · keep your rhythm going'
                      : 'A clear plan for your day, one step at a time.',
                  style: B05Typography.body(context),
                ),
              ],
            ),
          ),
        ),
        B05IconAction(
          icon: Icons.tune_rounded,
          label: 'Customize Today',
          hint: 'Reorder, show, hide, or collapse Today modules.',
          onPressed: onCustomize,
          focusOrder: 0,
        ),
        B05IconAction(
          icon: Icons.settings_outlined,
          label: 'Open settings',
          onPressed: onOpenSettings,
          focusOrder: 1,
        ),
      ],
    );
  }
}

class _DateContext extends StatelessWidget {
  const _DateContext({required this.relation});

  final TodayDateRelation relation;

  @override
  Widget build(BuildContext context) {
    final text = switch (relation) {
      TodayDateRelation.past => 'Reviewing a past day',
      TodayDateRelation.today => 'Your plan for today',
      TodayDateRelation.future => 'Planning ahead',
    };
    final icon = switch (relation) {
      TodayDateRelation.past => Icons.history_rounded,
      TodayDateRelation.today => Icons.check_circle_outline,
      TodayDateRelation.future => Icons.event_available_outlined,
    };
    final role = relation == TodayDateRelation.today
        ? context.b05Colors.success
        : context.b05Colors.info;
    return Semantics(
      container: true,
      label: text,
      child: Row(
        children: [
          Icon(icon, size: B05Layout.iconSmall, color: role.indicator),
          const SizedBox(width: B05Layout.space4),
          Flexible(child: Text(text, style: B05Typography.body(context))),
        ],
      ),
    );
  }
}

class _TodayModuleSurface extends StatelessWidget {
  const _TodayModuleSurface({
    required this.item,
    required this.index,
    required this.onCollapseChanged,
    required this.child,
  });

  final DashboardModuleLayoutItem item;
  final int index;
  final Future<void> Function(String moduleId, bool isCollapsed)
  onCollapseChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final descriptor = item.descriptor;
    final collapsed = item.isCollapsed && descriptor.collapsible;
    return FocusTraversalOrder(
      order: NumericFocusOrder(index + 2),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: B05Surface(
          padding: const EdgeInsets.all(B05Layout.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      label: descriptor.label,
                      child: ExcludeSemantics(
                        child: Text(
                          descriptor.label,
                          style: B05Typography.title(context),
                        ),
                      ),
                    ),
                  ),
                  if (descriptor.collapsible)
                    B05IconAction(
                      icon: collapsed
                          ? Icons.expand_more_rounded
                          : Icons.expand_less_rounded,
                      label:
                          '${collapsed ? 'Expand' : 'Collapse'} ${descriptor.customizationLabel}',
                      hint: collapsed
                          ? 'Shows this Today module.'
                          : 'Hides this Today module’s details.',
                      onPressed: () =>
                          onCollapseChanged(item.moduleId, !collapsed),
                    ),
                ],
              ),
              if (collapsed) ...[
                const SizedBox(height: B05Layout.space8),
                Semantics(
                  container: true,
                  label: 'Collapsed',
                  child: Text('Collapsed', style: B05Typography.body(context)),
                ),
              ] else ...[
                const SizedBox(height: B05Layout.space12),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayFocusModule extends StatelessWidget {
  const _TodayFocusModule({
    required this.presentation,
    required this.onOpenWorkoutPlan,
    required this.onLogMeal,
    required this.onReturnToToday,
  });

  final TodayFocusPresentation presentation;
  final VoidCallback onOpenWorkoutPlan;
  final VoidCallback onLogMeal;
  final VoidCallback onReturnToToday;

  @override
  Widget build(BuildContext context) {
    final callback = switch (presentation.action) {
      TodayNextAction.openWorkoutPlan => onOpenWorkoutPlan,
      TodayNextAction.logMeal => onLogMeal,
      TodayNextAction.returnToToday => onReturnToToday,
    };
    final icon = switch (presentation.action) {
      TodayNextAction.openWorkoutPlan => Icons.fitness_center_rounded,
      TodayNextAction.logMeal => Icons.restaurant_outlined,
      TodayNextAction.returnToToday => Icons.today_outlined,
    };
    return Semantics(
      container: true,
      label: 'What should I do? ${presentation.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            presentation.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: context.b05Colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: B05Layout.space4),
          Text(presentation.detail, style: B05Typography.body(context)),
          const SizedBox(height: B05Layout.space12),
          B05ActionButton(
            label: presentation.actionLabel,
            hint: 'Your most useful next step.',
            icon: icon,
            onPressed: callback,
            emphasis: B05ActionEmphasis.primary,
            focusOrder: 10,
          ),
        ],
      ),
    );
  }
}

class _TodayWorkoutModule extends StatelessWidget {
  const _TodayWorkoutModule({
    required this.presentation,
    required this.onOpenWorkoutPlan,
  });

  final TodayWorkoutPresentation presentation;
  final VoidCallback onOpenWorkoutPlan;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const _TodayLoadingState(label: 'Checking your workout plan');
    }
    final icon = presentation.state == TodayPresentationState.empty
        ? Icons.self_improvement_outlined
        : presentation.state == TodayPresentationState.unavailable
        ? Icons.info_outline
        : Icons.fitness_center_rounded;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.b05Colors.action),
            const SizedBox(width: B05Layout.space8),
            Expanded(
              child: Semantics(
                container: true,
                label: 'Workout: ${presentation.title}',
                value: presentation.status,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      presentation.title,
                      style: B05Typography.label(context),
                    ),
                    const SizedBox(height: B05Layout.space4),
                    Text(
                      presentation.detail,
                      style: B05Typography.body(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: B05Layout.space12),
        B05ActionButton(
          label: presentation.state == TodayPresentationState.empty
              ? 'Choose a workout'
              : 'Open workout plan',
          icon: Icons.calendar_month_outlined,
          hint: 'Opens your workout plan and calendar.',
          emphasis: B05ActionEmphasis.secondary,
          onPressed: onOpenWorkoutPlan,
        ),
      ],
    );
    return presentation.state == TodayPresentationState.unavailable
        ? Semantics(
            container: true,
            label: 'Unavailable: Your scheduled workout is unavailable',
            child: content,
          )
        : content;
  }
}

class _TodayNutritionModule extends StatelessWidget {
  const _TodayNutritionModule({
    required this.presentation,
    required this.showGuidance,
    required this.onLogMeal,
  });

  final TodayNutritionPresentation presentation;
  final bool showGuidance;
  final VoidCallback onLogMeal;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const _TodayLoadingState(label: 'Preparing your nutrition');
    }
    final children = <Widget>[];
    if (presentation.state == TodayPresentationState.unavailable) {
      children.add(
        Semantics(
          container: true,
          label: 'Unavailable: Nutrition is unavailable',
          child: SizedBox.shrink(),
        ),
      );
    }
    if (presentation.calories case final calories?) {
      children.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              calories.value,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: context.b05Colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: B05Layout.space4),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(calories.unit, style: B05Typography.body(context)),
            ),
            if (calories.estimated) ...[
              const SizedBox(width: B05Layout.space8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('estimated', style: B05Typography.body(context)),
              ),
            ],
          ],
        ),
      );
      children.add(const SizedBox(height: B05Layout.space4));
    }
    children.add(
      Text(presentation.headline, style: B05Typography.label(context)),
    );
    children.add(const SizedBox(height: B05Layout.space4));
    children.add(Text(presentation.detail, style: B05Typography.body(context)));
    if (presentation.macros.isNotEmpty) {
      children.add(const SizedBox(height: B05Layout.space12));
      children.add(
        Wrap(
          spacing: B05Layout.space8,
          runSpacing: B05Layout.space8,
          children: [
            for (final metric in presentation.macros)
              _NutritionMetric(metric: metric),
          ],
        ),
      );
    }
    if (presentation.meals.isNotEmpty) {
      children.add(const SizedBox(height: B05Layout.space12));
      children.add(
        Column(
          children: [
            for (final meal in presentation.meals) _MealRow(meal: meal),
          ],
        ),
      );
    }
    if (showGuidance) {
      children.add(const SizedBox(height: B05Layout.space12));
      children.add(const B04CurrentFoodSummary());
    }
    children.add(const SizedBox(height: B05Layout.space12));
    children.add(
      B05ActionGroup(
        children: [
          B05ActionButton(
            label: presentation.state == TodayPresentationState.empty
                ? 'Log your first meal'
                : 'Log meal',
            icon: Icons.restaurant_outlined,
            hint: 'Opens the food logging flow for this day.',
            emphasis: B05ActionEmphasis.secondary,
            onPressed: onLogMeal,
          ),
        ],
      ),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return content;
  }
}

class _NutritionMetric extends StatelessWidget {
  const _NutritionMetric({required this.metric});

  final TodayNutritionMetricPresentation metric;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '${metric.label}: ${metric.value} ${metric.unit}',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.b05Colors.surfaceSubtle,
        borderRadius: B05Radii.smallRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: B05Layout.space8,
          vertical: B05Layout.space8,
        ),
        child: Text(
          '${metric.label} ${metric.value}${metric.unit}',
          style: B05Typography.body(context),
        ),
      ),
    ),
  );
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal});

  final TodayMealPresentation meal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: B05Layout.space4),
    child: Row(
      children: [
        Icon(
          meal.logged ? Icons.check_circle_outline : Icons.circle_outlined,
          size: B05Layout.iconSmall,
          color: meal.logged
              ? context.b05Colors.success.indicator
              : context.b05Colors.textDisabled,
        ),
        const SizedBox(width: B05Layout.space8),
        Expanded(child: Text(meal.label, style: B05Typography.label(context))),
        Flexible(
          child: Text(
            meal.detail,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: B05Typography.body(context),
          ),
        ),
      ],
    ),
  );
}

class _TodayProgressModule extends StatelessWidget {
  const _TodayProgressModule({required this.presentation});

  final TodayProgressPresentation presentation;

  @override
  Widget build(BuildContext context) {
    if (presentation.state == TodayPresentationState.loading) {
      return const _TodayLoadingState(label: 'Preparing your progress');
    }
    final unavailableAlias =
        presentation.state == TodayPresentationState.unavailable
        ? Semantics(
            container: true,
            label: 'Unavailable: Progress is unavailable',
            child: SizedBox.shrink(),
          )
        : null;
    final content = Semantics(
      container: true,
      label: 'Progress: ${presentation.headline}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            presentation.headline,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.b05Colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: B05Layout.space4),
          Text(presentation.detail, style: B05Typography.body(context)),
          if (presentation.supporting != null) ...[
            const SizedBox(height: B05Layout.space8),
            Text(presentation.supporting!, style: B05Typography.body(context)),
          ],
        ],
      ),
    );
    return unavailableAlias == null
        ? content
        : Column(children: [unavailableAlias, content]);
  }
}

class _TodayLoadingState extends StatelessWidget {
  const _TodayLoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LoadingLine(widthFactor: .42),
        const SizedBox(height: B05Layout.space8),
        _LoadingLine(widthFactor: .82),
        const SizedBox(height: B05Layout.space8),
        _LoadingLine(widthFactor: .62),
        const SizedBox(height: B05Layout.space12),
        LinearProgressIndicator(
          minHeight: 2,
          color: context.b05Colors.action,
          backgroundColor: context.b05Colors.surfaceSubtle,
        ),
      ],
    ),
  );
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: widthFactor,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.b05Colors.surfaceSubtle,
        borderRadius: B05Radii.smallRadius,
      ),
      child: const SizedBox(height: 14),
    ),
  );
}

class _TodayInlineProgress extends StatelessWidget {
  const _TodayInlineProgress({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: B05Layout.space8),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.b05Colors.action,
          ),
        ),
        const SizedBox(width: B05Layout.space8),
        Text(label, style: B05Typography.body(context)),
      ],
    ),
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
      Expanded(child: Text(title, style: B05Typography.body(context))),
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
