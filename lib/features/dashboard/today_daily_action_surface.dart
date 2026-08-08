import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrients.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../data/models/b02_progress_read_models.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../coaching/b04_production_surface_widgets.dart';
import 'dashboard_module_registry.dart';
import 'dashboard_personalization_controller.dart';
import 'today_surface_controller.dart';
import 'widgets/dashboard_date_bar.dart';

enum TodayDateRelation { past, today, future }

TodayDateRelation todayDateRelation(DateTime selectedDate, DateTime now) {
  DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);
  final selected = day(selectedDate);
  final current = day(now);
  if (selected.isBefore(current)) return TodayDateRelation.past;
  if (selected.isAfter(current)) return TodayDateRelation.future;
  return TodayDateRelation.today;
}

enum TodayNextAction { openWorkoutPlan, logMeal, returnToToday }

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
      label: 'Open workout plan',
      hint: 'Opens the authoritative workout calendar.',
    );
  }
  final nutrition = snapshot?.nutrition.value;
  if (nutrition != null && nutrition.records.isEmpty) {
    return const TodayNextActionChoice(
      action: TodayNextAction.logMeal,
      label: 'Log a meal',
      hint: 'Opens the food logging flow for this day.',
    );
  }
  return const TodayNextActionChoice(
    action: TodayNextAction.openWorkoutPlan,
    label: 'Open today’s plan',
    hint: 'Opens your existing workout plan and calendar.',
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

/// B05's daily action surface. It consumes source-owned typed reads and the
/// normalized B05-03 module layout; it never queries Drift or derives domain
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
              padding: const EdgeInsets.all(B05Layout.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TodayHeader(
                    userName: userName,
                    streakCount: streakCount,
                    onOpenSettings: onOpenSettings,
                    onCustomize: onCustomize,
                  ),
                  const SizedBox(height: B05Layout.space12),
                  DashboardDateBar(
                    selectedDate: selectedDate,
                    onDateChanged: onDateChanged,
                  ),
                  const SizedBox(height: B05Layout.space12),
                  _DateContextMessage(relation: relation),
                  if (personalization.status ==
                      DashboardPersonalizationStatus.loading)
                    const Padding(
                      padding: EdgeInsets.only(top: B05Layout.space12),
                      child: B05StatusMessage(
                        status: B05SemanticStatus.info,
                        label: 'Loading your Today layout',
                      ),
                    ),
                  if (personalization.status ==
                      DashboardPersonalizationStatus.saving)
                    const Padding(
                      padding: EdgeInsets.only(top: B05Layout.space12),
                      child: B05StatusMessage(
                        status: B05SemanticStatus.info,
                        label: 'Saving your Today layout',
                      ),
                    ),
                  if (personalization.status ==
                      DashboardPersonalizationStatus.error)
                    Padding(
                      padding: const EdgeInsets.only(top: B05Layout.space12),
                      child: _RetryStatus(
                        label: 'Your saved Today layout is unavailable',
                        message: personalization.errorMessage,
                        onRetry: personalizationController.retry,
                      ),
                    ),
                  if (snapshotAsync.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: B05Layout.space12),
                      child: _RetryStatus(
                        label: 'Today information is unavailable',
                        message: 'Try again to load your current local data.',
                        onRetry: () => ref.invalidate(
                          todaySurfaceSnapshotProvider(selectedDate),
                        ),
                      ),
                    ),
                  const SizedBox(height: B05Layout.space12),
                  for (var index = 0; index < layout.length; index++)
                    if (layout[index].isVisible) ...[
                      _TodayQuestionModule(
                        item: layout[index],
                        index: index,
                        onCollapseChanged:
                            personalizationController.setCollapsed,
                        child: _moduleBody(
                          item: layout[index],
                          snapshot: snapshot,
                          snapshotLoading:
                              snapshotAsync.isLoading &&
                              !snapshotAsync.hasError,
                          snapshotUnavailable: snapshotAsync.hasError,
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
    required bool snapshotLoading,
    required bool snapshotUnavailable,
    required TodayDateRelation relation,
  }) {
    final calendarRead =
        snapshot?.calendar ??
        (snapshotUnavailable
            ? const TodayDomainRead<CalendarReadSnapshot>.unavailable(
                'Today information is unavailable right now. Try again.',
              )
            : null);
    final nutritionRead =
        snapshot?.nutrition ??
        (snapshotUnavailable
            ? const TodayDomainRead<NutritionDailyReadModel>.unavailable(
                'Today information is unavailable right now. Try again.',
              )
            : null);
    final progressRead =
        snapshot?.progress ??
        (snapshotUnavailable
            ? const TodayDomainRead<B02ProgressReadModel>.unavailable(
                'Today information is unavailable right now. Try again.',
              )
            : null);
    return switch (item.moduleId) {
      'today.workout' => _WorkoutModuleBody(
        read: calendarRead,
        loading: snapshotLoading,
        showBriefing: relation == TodayDateRelation.today,
        onOpenWorkoutPlan: onOpenWorkoutPlan,
      ),
      'today.meals' => _MealsModuleBody(
        read: nutritionRead,
        loading: snapshotLoading,
        showCurrentFood: relation == TodayDateRelation.today,
        onLogMeal: onLogMeal,
      ),
      'today.progress' => _ProgressModuleBody(
        read: progressRead,
        loading: snapshotLoading,
        showReview: relation == TodayDateRelation.today,
      ),
      'today.next_action' => _NextActionModuleBody(
        choice: chooseTodayNextAction(
          dateRelation: relation,
          snapshot: snapshot,
        ),
        onOpenWorkoutPlan: onOpenWorkoutPlan,
        onLogMeal: onLogMeal,
        onReturnToToday: () => onDateChanged(now ?? DateTime.now()),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.userName,
    required this.streakCount,
    required this.onOpenSettings,
    required this.onCustomize,
  });

  final String userName;
  final int streakCount;
  final VoidCallback onOpenSettings;
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Semantics(
          header: true,
          label: 'Today',
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today', style: B05Typography.title(context)),
                const SizedBox(height: B05Layout.space4),
                Text(
                  'Welcome, $userName · $streakCount day streak',
                  style: B05Typography.body(context),
                ),
              ],
            ),
          ),
        ),
      ),
      B05IconAction(
        icon: Icons.tune_rounded,
        label: 'Customize Today dashboard',
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

class _DateContextMessage extends StatelessWidget {
  const _DateContextMessage({required this.relation});

  final TodayDateRelation relation;

  @override
  Widget build(BuildContext context) {
    final (status, label) = switch (relation) {
      TodayDateRelation.past => (
        B05SemanticStatus.info,
        'Viewing a past day. Actions open the existing historical flows.',
      ),
      TodayDateRelation.today => (
        B05SemanticStatus.success,
        'Viewing today’s available actions.',
      ),
      TodayDateRelation.future => (
        B05SemanticStatus.info,
        'Viewing a future day. Return to today before starting a workout.',
      ),
    };
    return B05StatusMessage(status: status, label: label);
  }
}

class _TodayQuestionModule extends StatelessWidget {
  const _TodayQuestionModule({
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                const B05StatusMessage(
                  status: B05SemanticStatus.info,
                  label: 'Collapsed. Expand to see details.',
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

class _WorkoutModuleBody extends StatelessWidget {
  const _WorkoutModuleBody({
    required this.read,
    required this.loading,
    required this.showBriefing,
    required this.onOpenWorkoutPlan,
  });

  final TodayDomainRead<CalendarReadSnapshot>? read;
  final bool loading;
  final bool showBriefing;
  final VoidCallback onOpenWorkoutPlan;

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[_CalendarReadStatus(read: read, loading: loading)];
    if (showBriefing) {
      content.addAll([
        const SizedBox(height: B05Layout.space12),
        const B04DailyBriefingCard(),
      ]);
    }
    content.addAll([
      const SizedBox(height: B05Layout.space12),
      B05ActionButton(
        label: 'Open workout plan',
        hint: 'Opens the existing calendar and workout controls.',
        icon: Icons.calendar_month_outlined,
        onPressed: onOpenWorkoutPlan,
      ),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content,
    );
  }
}

class _CalendarReadStatus extends StatelessWidget {
  const _CalendarReadStatus({required this.read, required this.loading});

  final TodayDomainRead<CalendarReadSnapshot>? read;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading || read == null) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'Loading your scheduled workout',
      );
    }
    if (!read!.isAvailable) {
      return B05StatusMessage(
        status: B05SemanticStatus.unavailable,
        label: 'Your scheduled workout is unavailable',
        value: 'Open your workout plan to try again.',
      );
    }
    final occurrences = read!.value!.rangeOccurrences;
    if (occurrences.isEmpty) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'No scheduled workout for this day',
        value: 'Use your workout plan to view or choose an existing session.',
      );
    }
    final occurrence = occurrences.first;
    return Semantics(
      container: true,
      label: 'Scheduled workout: ${occurrence.template.name}',
      value: _calendarStatusLabel(occurrence.occurrence.status),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(occurrence.template.name, style: B05Typography.label(context)),
            const SizedBox(height: B05Layout.space4),
            Text(
              _calendarStatusLabel(occurrence.occurrence.status),
              style: B05Typography.body(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealsModuleBody extends StatelessWidget {
  const _MealsModuleBody({
    required this.read,
    required this.loading,
    required this.showCurrentFood,
    required this.onLogMeal,
  });

  final TodayDomainRead<NutritionDailyReadModel>? read;
  final bool loading;
  final bool showCurrentFood;
  final VoidCallback onLogMeal;

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[
      _NutritionReadStatus(read: read, loading: loading),
    ];
    if (showCurrentFood) {
      content.addAll([
        const SizedBox(height: B05Layout.space12),
        const B04CurrentFoodCard(),
      ]);
    }
    content.addAll([
      const SizedBox(height: B05Layout.space12),
      B05ActionButton(
        label: 'Log a meal',
        hint: 'Opens the existing food logging flow.',
        icon: Icons.restaurant_outlined,
        onPressed: onLogMeal,
      ),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content,
    );
  }
}

class _NutritionReadStatus extends StatelessWidget {
  const _NutritionReadStatus({required this.read, required this.loading});

  final TodayDomainRead<NutritionDailyReadModel>? read;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading || read == null) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'Loading daily nutrition totals',
      );
    }
    if (!read!.isAvailable) {
      return B05StatusMessage(
        status: B05SemanticStatus.unavailable,
        label: 'Daily nutrition totals are unavailable',
        value: 'Log a meal or try again later.',
      );
    }
    final daily = read!.value!;
    final state = todayNutritionSummaryState(daily);
    if (state == TodayNutritionSummaryState.empty) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'No meals have been logged for this day',
        value: 'Log your first meal to start tracking today.',
      );
    }
    final fact = daily.totals.facts['energy'];
    if (state == TodayNutritionSummaryState.unknown || fact == null) {
      return const B05StatusMessage(
        status: B05SemanticStatus.unavailable,
        label: 'Calories are not available yet',
        value: 'We couldn’t calculate a total from today’s meals.',
      );
    }
    final value = state == TodayNutritionSummaryState.range
        ? _rangeLabel(fact)
        : _pointLabel(fact);
    return B05StatusMessage(
      status: state == TodayNutritionSummaryState.range
          ? B05SemanticStatus.warning
          : B05SemanticStatus.success,
      label: state == TodayNutritionSummaryState.range
          ? 'Energy total is a range'
          : 'Energy total is available',
      value: value,
    );
  }

  String _pointLabel(NutrientFact fact) =>
      '${fact.point?.value.toString() ?? 'Not available'} ${fact.unit.symbol}';

  String _rangeLabel(NutrientFact fact) {
    final lower = fact.lower?.value.toString() ?? 'Not available';
    final upper = fact.upper?.value.toString() ?? 'Not available';
    return '$lower–$upper ${fact.unit.symbol}';
  }
}

class _ProgressModuleBody extends StatelessWidget {
  const _ProgressModuleBody({
    required this.read,
    required this.loading,
    required this.showReview,
  });

  final TodayDomainRead<B02ProgressReadModel>? read;
  final bool loading;
  final bool showReview;

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[_ProgressReadStatus(read: read, loading: loading)];
    if (showReview) {
      content.addAll([
        const SizedBox(height: B05Layout.space12),
        const B04WeeklyReviewCard(),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content,
    );
  }
}

class _ProgressReadStatus extends StatelessWidget {
  const _ProgressReadStatus({required this.read, required this.loading});

  final TodayDomainRead<B02ProgressReadModel>? read;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading || read == null) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'Loading activity and progress',
      );
    }
    if (!read!.isAvailable) {
      return B05StatusMessage(
        status: B05SemanticStatus.unavailable,
        label: 'Activity and progress are unavailable',
        value: 'Complete a workout or try again later.',
      );
    }
    final history = read!.value!.activityHistory;
    if (history == null) {
      return const B05StatusMessage(
        status: B05SemanticStatus.unavailable,
        label: 'Activity history is unavailable',
        value: 'This is not the same as having no completed activity.',
      );
    }
    if (history.isEmpty) {
      return const B05StatusMessage(
        status: B05SemanticStatus.info,
        label: 'No completed activity yet',
        value: 'Complete a workout to start seeing progress.',
      );
    }
    return B05StatusMessage(
      status: B05SemanticStatus.success,
      label: 'Activity history is available',
      value: '${history.length} activities so far.',
    );
  }
}

class _NextActionModuleBody extends StatelessWidget {
  const _NextActionModuleBody({
    required this.choice,
    required this.onOpenWorkoutPlan,
    required this.onLogMeal,
    required this.onReturnToToday,
  });

  final TodayNextActionChoice choice;
  final VoidCallback onOpenWorkoutPlan;
  final VoidCallback onLogMeal;
  final VoidCallback onReturnToToday;

  @override
  Widget build(BuildContext context) {
    final callback = switch (choice.action) {
      TodayNextAction.openWorkoutPlan => onOpenWorkoutPlan,
      TodayNextAction.logMeal => onLogMeal,
      TodayNextAction.returnToToday => onReturnToToday,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose one existing action to keep moving.',
          style: B05Typography.body(context),
        ),
        const SizedBox(height: B05Layout.space12),
        B05ActionButton(
          label: choice.label,
          hint: choice.hint,
          icon: switch (choice.action) {
            TodayNextAction.openWorkoutPlan => Icons.calendar_month_outlined,
            TodayNextAction.logMeal => Icons.restaurant_outlined,
            TodayNextAction.returnToToday => Icons.today_outlined,
          },
          onPressed: callback,
          focusOrder: 10,
        ),
      ],
    );
  }
}

class _RetryStatus extends StatelessWidget {
  const _RetryStatus({
    required this.label,
    required this.message,
    required this.onRetry,
  });

  final String label;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      B05StatusMessage(
        status: B05SemanticStatus.unavailable,
        label: label,
        value: 'We couldn’t load this right now. Try again.',
      ),
      const SizedBox(height: B05Layout.space8),
      B05ActionButton(
        label: 'Retry',
        hint: 'Retries loading this Today information.',
        emphasis: B05ActionEmphasis.secondary,
        icon: Icons.refresh_rounded,
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
        const B05StatusMessage(
          status: B05SemanticStatus.info,
          label: 'All Today modules are hidden',
          value: 'Customize Today to show a daily question again.',
        ),
        const SizedBox(height: B05Layout.space12),
        B05ActionButton(
          label: 'Customize Today dashboard',
          onPressed: onCustomize,
        ),
      ],
    ),
  );
}

String _calendarStatusLabel(Object? value) {
  final key = value?.toString().toLowerCase().replaceAll('_', ' ') ?? '';
  return switch (key) {
    'scheduled' || 'planned' => 'Planned for today',
    'completed' || 'complete' => 'Completed today',
    'skipped' => 'Skipped',
    'cancelled' || 'canceled' => 'Cancelled',
    _ => ConsumerCopy.state(key),
  };
}
