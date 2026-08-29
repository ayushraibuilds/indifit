import '../../core/nutrients.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/presentation/consumer_count_label.dart';
import '../../core/presentation/consumer_number_label.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b02_progress_read_models.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/nutrition_target_authority.dart';
import '../../data/repositories/training_next_action_resolver.dart';
import '../progress/b02_progress_presentation.dart';
import 'today_presentation_types.dart';
import 'today_surface_controller.dart';

/// Display-ready state for the Today page. These values intentionally contain
/// no source IDs, policy metadata, or persistence vocabulary. The source read
/// models remain authoritative; this file only decides how to show them well.
enum TodayPresentationState { loading, ready, empty, unavailable }

/// Skipped and cancelled dates are retained as history, but they are not a
/// current Today workout. Completed/partial evidence remains readable.
List<CalendarOccurrenceReadItem> todayVisibleWorkoutOccurrences(
  CalendarReadSnapshot snapshot, {
  String? localDate,
}) {
  final activeVersionId = snapshot.activeProgramVersionId;
  return snapshot.rangeOccurrences
      .where(
        (item) =>
            activeVersionId != null &&
            item.occurrence.programVersionId == activeVersionId &&
            (localDate == null ||
                item.occurrence.effectiveLocalDate == localDate) &&
            item.occurrence.status != 'skipped' &&
            item.occurrence.status != 'cancelled',
      )
      .toList(growable: false);
}

class TodayWorkoutPresentation {
  final TodayPresentationState state;
  final String title;
  final String detail;
  final String? status;
  final CalendarOccurrenceReadItem? occurrence;
  final int exerciseCount;
  final bool canStart;
  final bool isInProgress;

  const TodayWorkoutPresentation({
    required this.state,
    required this.title,
    required this.detail,
    this.status,
    this.occurrence,
    this.exerciseCount = 0,
    this.canStart = false,
    this.isInProgress = false,
  });

  factory TodayWorkoutPresentation.from(
    TodayDomainRead<CalendarReadSnapshot>? read, {
    required bool loading,
    TrainingNextActionResolution? resolution,
    String? localDate,
  }) {
    if (loading || read == null) {
      return const TodayWorkoutPresentation(
        state: TodayPresentationState.loading,
        title: 'Checking your plan',
        detail: 'Your workout details will appear here.',
      );
    }
    if (!read.isAvailable) {
      return const TodayWorkoutPresentation(
        state: TodayPresentationState.unavailable,
        title: 'Workout unavailable',
        detail: 'Try again to load your plan.',
      );
    }
    if (resolution != null && !resolution.activeDraftReadAvailable) {
      return const TodayWorkoutPresentation(
        state: TodayPresentationState.unavailable,
        title: 'Workout unavailable',
        detail: 'Try again to check your active workout.',
      );
    }
    if (resolution?.hasActiveDraft == true && resolution?.activeDraft == null) {
      return const TodayWorkoutPresentation(
        state: TodayPresentationState.ready,
        title: 'Workout in progress',
        detail: 'Resolve your active workout before starting another.',
        canStart: false,
      );
    }
    final occurrences = todayVisibleWorkoutOccurrences(
      read.value!,
      localDate: localDate,
    );
    if (occurrences.isEmpty) {
      return const TodayWorkoutPresentation(
        state: TodayPresentationState.empty,
        title: 'Nothing planned today',
        detail: 'Choose a workout whenever you’re ready.',
      );
    }
    final occurrence = resolution?.todayOccurrence ?? occurrences.first;
    final status = _workoutStatus(occurrence.occurrence.status);
    final isInProgress = occurrence.occurrence.status == 'inProgress';
    final canStart =
        isInProgress ||
        occurrence.occurrence.status == 'planned' ||
        occurrence.occurrence.status == 'rescheduled';
    final count = occurrence.prescriptions.length;
    return TodayWorkoutPresentation(
      state: TodayPresentationState.ready,
      title: ConsumerCopy.label(occurrence.template.name, fallback: 'Workout'),
      detail: count == 0
          ? status
          : '${ConsumerCountLabel.format(count, 'exercise')} · $status',
      status: status,
      occurrence: occurrence,
      exerciseCount: count,
      canStart: canStart,
      isInProgress: isInProgress,
    );
  }
}

/// A current nutrition value and, when an accepted B04 goal exists, its
/// comparison target. A missing fact is deliberately represented by [isAvailable]
/// rather than a numeric zero.
class TodayNutritionMetricPresentation {
  final String nutrientId;
  final String label;
  final String value;
  final String unit;
  final bool estimated;
  final bool isAvailable;
  final bool isRange;
  final bool isIncomplete;
  final double? pointValue;
  final double? lowerValue;
  final double? upperValue;
  final double? targetValue;

  const TodayNutritionMetricPresentation({
    required this.nutrientId,
    required this.label,
    required this.value,
    required this.unit,
    required this.estimated,
    required this.isAvailable,
    required this.isRange,
    required this.isIncomplete,
    required this.pointValue,
    required this.lowerValue,
    required this.upperValue,
    required this.targetValue,
  });

  bool get hasTarget => targetValue != null && targetValue! > 0;

  bool get isOverTarget =>
      hasTarget && pointValue != null && pointValue! > targetValue!;

  double? get progress => hasTarget && pointValue != null
      ? (pointValue! / targetValue!).clamp(0, 1).toDouble()
      : null;

  double? get lowerProgress => hasTarget && lowerValue != null
      ? (lowerValue! / targetValue!).clamp(0, 1).toDouble()
      : progress;

  double? get upperProgress => hasTarget && upperValue != null
      ? (upperValue! / targetValue!).clamp(0, 1).toDouble()
      : progress;

  String get comparisonLabel {
    if (!isAvailable) return 'Not available';
    if (!hasTarget) return '$value $unit';
    return '$value / ${_formatNumber(targetValue!)} $unit';
  }

  factory TodayNutritionMetricPresentation.fromFact({
    required String nutrientId,
    required String label,
    required String fallbackUnit,
    required NutrientFact? fact,
    required double? targetValue,
  }) {
    if (fact == null || !fact.isAvailable) {
      return TodayNutritionMetricPresentation(
        nutrientId: nutrientId,
        label: label,
        value: '—',
        unit: fallbackUnit,
        estimated: false,
        isAvailable: false,
        isRange: false,
        isIncomplete: true,
        pointValue: null,
        lowerValue: null,
        upperValue: null,
        targetValue: targetValue,
      );
    }
    final point = fact.point?.value.asDouble;
    final lower = fact.lower?.value.asDouble;
    final upper = fact.upper?.value.asDouble;
    final range = lower != null || upper != null;
    return TodayNutritionMetricPresentation(
      nutrientId: nutrientId,
      label: label,
      value: _factValue(fact) ?? '—',
      unit: fact.unit.symbol,
      estimated: fact.status == NutrientFactStatus.estimated,
      isAvailable: true,
      isRange: range,
      isIncomplete: fact.coverageIncomplete,
      pointValue: point,
      lowerValue: lower,
      upperValue: upper,
      targetValue: targetValue,
    );
  }

  factory TodayNutritionMetricPresentation.knownZero({
    required String nutrientId,
    required String label,
    required String unit,
    required double? targetValue,
  }) => TodayNutritionMetricPresentation(
    nutrientId: nutrientId,
    label: label,
    value: '0',
    unit: unit,
    estimated: false,
    isAvailable: true,
    isRange: false,
    isIncomplete: false,
    pointValue: 0,
    lowerValue: 0,
    upperValue: 0,
    targetValue: targetValue,
  );
}

class TodayMealPresentation {
  final String mealType;
  final String label;
  final String detail;
  final String calorieLabel;
  final bool logged;
  final bool nutritionIncomplete;
  final int itemCount;
  final List<String> itemLabels;

  const TodayMealPresentation({
    required this.mealType,
    required this.label,
    required this.detail,
    required this.calorieLabel,
    required this.logged,
    required this.nutritionIncomplete,
    required this.itemCount,
    this.itemLabels = const [],
  });
}

class TodayNutritionPresentation {
  final TodayPresentationState state;
  final String headline;
  final String detail;
  final TodayNutritionMetricPresentation? calories;
  final List<TodayNutritionMetricPresentation> macros;
  final List<TodayMealPresentation> meals;
  final bool hasAcceptedCalorieTarget;
  final bool targetUnavailable;
  final bool hasIncompleteNutrition;
  final bool isNoConsumptionKnown;

  const TodayNutritionPresentation({
    required this.state,
    required this.headline,
    required this.detail,
    this.calories,
    this.macros = const [],
    this.meals = const [],
    this.hasAcceptedCalorieTarget = false,
    this.targetUnavailable = false,
    this.hasIncompleteNutrition = false,
    this.isNoConsumptionKnown = false,
  });

  factory TodayNutritionPresentation.from(
    TodayDomainRead<NutritionDailyReadModel>? read, {
    required bool loading,
    TodayDomainRead<NutritionTargetsForDate?>? targetRead,
    TodayDomainRead<NutritionGoalVersionReadModel?>? goal,
  }) {
    if (loading || read == null) {
      return const TodayNutritionPresentation(
        state: TodayPresentationState.loading,
        headline: 'Nutrition today',
        detail: 'Preparing your daily totals.',
      );
    }
    if (!read.isAvailable) {
      return const TodayNutritionPresentation(
        state: TodayPresentationState.unavailable,
        headline: 'Nutrition unavailable',
        detail: 'Try again to load your meals.',
      );
    }

    final daily = read.value!;
    // A supplied target read is authoritative even when it resolves to no
    // goal for the requested historical date. The legacy goal parameter is a
    // compatibility path for older presentation fixtures only.
    final targetUnavailable = targetRead != null && !targetRead.isAvailable;
    final acceptedGoal = targetRead != null
        ? (targetRead.isAvailable ? targetRead.value?.goalVersion : null)
        : (goal?.isAvailable == true ? goal!.value : null);
    final calorieTarget = acceptedGoal?.calorieTargetKcal?.toDouble();
    final noConsumption = daily.records.isEmpty;
    final targetValues = <String, double?>{
      'energy': calorieTarget,
      'protein': acceptedGoal?.proteinTargetG,
      'carbohydrate': acceptedGoal?.carbsTargetG,
      'fat': acceptedGoal?.fatTargetG,
      // There is no B04 fibre target authority. Keeping this null is more
      // truthful than reviving the legacy fixed 30 g reference.
      'fibre': null,
    };

    final facts = daily.totals.facts;
    final calories = noConsumption
        ? TodayNutritionMetricPresentation.knownZero(
            nutrientId: 'energy',
            label: 'Calories',
            unit: 'kcal',
            targetValue: targetValues['energy'],
          )
        : TodayNutritionMetricPresentation.fromFact(
            nutrientId: 'energy',
            label: 'Calories',
            fallbackUnit: 'kcal',
            fact: facts['energy'],
            targetValue: targetValues['energy'],
          );
    final macros = <TodayNutritionMetricPresentation>[
      for (final entry in const [
        ('protein', 'Protein'),
        ('carbohydrate', 'Carbs'),
        ('fat', 'Fat'),
        ('fibre', 'Fiber'),
      ])
        noConsumption
            ? TodayNutritionMetricPresentation.knownZero(
                nutrientId: entry.$1,
                label: entry.$2,
                unit: 'g',
                targetValue: targetValues[entry.$1],
              )
            : TodayNutritionMetricPresentation.fromFact(
                nutrientId: entry.$1,
                label: entry.$2,
                fallbackUnit: 'g',
                fact: facts[entry.$1],
                targetValue: targetValues[entry.$1],
              ),
    ];
    final primaryMetrics = [calories, ...macros];
    final incomplete =
        !noConsumption &&
        primaryMetrics.any(
          (metric) => !metric.isAvailable || metric.isIncomplete,
        );
    final known = primaryMetrics.any((metric) => metric.isAvailable);
    return TodayNutritionPresentation(
      state: noConsumption
          ? TodayPresentationState.empty
          : known
          ? TodayPresentationState.ready
          : TodayPresentationState.empty,
      headline: noConsumption
          ? 'No meals yet'
          : incomplete
          ? ConsumerCopy.nutritionDetailsIncomplete
          : 'Nutrition today',
      detail: noConsumption
          ? 'Tap + to add breakfast.'
          : incomplete
          ? 'Available totals stay visible while missing details remain unknown.'
          : 'Your day at a glance.',
      calories: calories,
      macros: macros,
      meals: _mealRows(daily.records),
      hasAcceptedCalorieTarget: calorieTarget != null && calorieTarget > 0,
      targetUnavailable: targetUnavailable,
      hasIncompleteNutrition: incomplete,
      isNoConsumptionKnown: noConsumption,
    );
  }

  static List<TodayMealPresentation> _mealRows(
    List<NutritionHistoricalReadRecord> records,
  ) {
    const categories = <(String, String)>[
      ('breakfast', 'Breakfast'),
      ('lunch', 'Lunch'),
      ('dinner', 'Dinner'),
      ('snack', 'Snacks'),
    ];
    final byCategory = <String, List<NutritionHistoricalReadRecord>>{};
    for (final record in records) {
      final category = _mealCategory(record.mealCategory);
      if (category != null) {
        (byCategory[category] ??= []).add(record);
      }
    }
    return [
      for (final category in categories)
        _mealPresentation(
          mealType: category.$1,
          label: category.$2,
          records: byCategory[category.$1] ?? const [],
        ),
    ];
  }

  static TodayMealPresentation _mealPresentation({
    required String mealType,
    required String label,
    required List<NutritionHistoricalReadRecord> records,
  }) {
    if (records.isEmpty) {
      return TodayMealPresentation(
        mealType: mealType,
        label: label,
        detail: 'Tap + to add',
        calorieLabel: '—',
        logged: false,
        nutritionIncomplete: false,
        itemCount: 0,
      );
    }
    final itemLabels = [
      for (final record in records)
        for (final item in record.items)
          ConsumerCopy.label(item.displayLabel, fallback: 'Food item'),
    ];
    final itemCount = itemLabels.length;
    final calories = _mealCalories(records);
    return TodayMealPresentation(
      mealType: mealType,
      label: label,
      detail: itemCount == 0
          ? '${ConsumerCountLabel.format(records.length, 'meal')} logged'
          : ConsumerCountLabel.format(itemCount, 'item'),
      calorieLabel: calories.label,
      logged: true,
      nutritionIncomplete: calories.incomplete,
      itemCount: itemCount,
      itemLabels: itemLabels,
    );
  }
}

class _MealCalories {
  final String label;
  final bool incomplete;

  const _MealCalories({required this.label, required this.incomplete});
}

_MealCalories _mealCalories(List<NutritionHistoricalReadRecord> records) {
  final facts = [for (final record in records) record.totals.facts['energy']];
  if (facts.any((fact) => fact == null || !fact.isAvailable)) {
    return const _MealCalories(label: '—', incomplete: true);
  }
  final available = facts.cast<NutrientFact>();
  if (available.any((fact) => fact.unit != NutrientUnit.kilocalorie)) {
    return const _MealCalories(label: '—', incomplete: true);
  }
  final hasRange = available.any(
    (fact) => fact.lower != null || fact.upper != null,
  );
  if (hasRange) {
    if (available.any((fact) => fact.lower == null || fact.upper == null)) {
      return const _MealCalories(label: '—', incomplete: true);
    }
    final lower = available.fold<double>(
      0,
      (sum, fact) => sum + fact.lower!.value.asDouble,
    );
    final upper = available.fold<double>(
      0,
      (sum, fact) => sum + fact.upper!.value.asDouble,
    );
    return _MealCalories(
      label: '${_formatNumber(lower)}–${_formatNumber(upper)} kcal',
      incomplete: available.any((fact) => fact.coverageIncomplete),
    );
  }
  if (available.any((fact) => fact.point == null)) {
    return const _MealCalories(label: '—', incomplete: true);
  }
  final total = available.fold<double>(
    0,
    (sum, fact) => sum + fact.point!.value.asDouble,
  );
  return _MealCalories(
    label: '${_formatNumber(total)} kcal',
    incomplete: available.any((fact) => fact.coverageIncomplete),
  );
}

class TodayActivityPresentation {
  final TodayPresentationState state;
  final String headline;
  final String detail;
  final String? latestActivity;
  final int? sessionCount;

  const TodayActivityPresentation({
    required this.state,
    required this.headline,
    required this.detail,
    this.latestActivity,
    this.sessionCount,
  });

  /// Activity is optional evidence. Loading is renderable so an explicitly
  /// enabled module can settle without a layout jump; empty and unavailable
  /// reads fail closed and are omitted by the Today composition.
  bool get shouldRender =>
      state == TodayPresentationState.loading ||
      state == TodayPresentationState.ready;

  factory TodayActivityPresentation.from(
    TodayDomainRead<B02ProgressReadModel>? read, {
    required bool loading,
  }) {
    if (loading || read == null) {
      return const TodayActivityPresentation(
        state: TodayPresentationState.loading,
        headline: 'Activity',
        detail: 'Checking your recent movement.',
      );
    }
    if (!read.isAvailable ||
        read.value == null ||
        read.value!.activityHistory == null) {
      return const TodayActivityPresentation(
        state: TodayPresentationState.unavailable,
        headline: 'Activity unavailable',
        detail: 'Try again later for your recent activity.',
      );
    }
    final history = read.value!.activityHistory!
        .where(_isMeaningfulActivityRecord)
        .toList(growable: false);
    if (history.isEmpty) {
      return const TodayActivityPresentation(
        state: TodayPresentationState.empty,
        headline: 'No activity yet',
        detail: 'Completed workouts will appear here.',
      );
    }
    final latest = history.first;
    return TodayActivityPresentation(
      state: TodayPresentationState.ready,
      headline: 'Recent activity',
      detail: '${ConsumerCountLabel.format(history.length, 'session')} logged',
      latestActivity: ConsumerCopy.label(latest.name, fallback: 'Workout'),
      sessionCount: history.length,
    );
  }
}

class TodayProgressPresentation {
  final TodayPresentationState state;
  final String headline;
  final String detail;
  final String? supporting;

  const TodayProgressPresentation({
    required this.state,
    required this.headline,
    required this.detail,
    this.supporting,
  });

  /// Progress is optional evidence, not a placeholder destination. A known
  /// empty history or a failed read is therefore hidden by Today.
  bool get shouldRender =>
      state == TodayPresentationState.loading ||
      state == TodayPresentationState.ready;

  factory TodayProgressPresentation.from(
    TodayDomainRead<B02ProgressReadModel>? read, {
    required bool loading,
  }) {
    if (loading || read == null) {
      return const TodayProgressPresentation(
        state: TodayPresentationState.loading,
        headline: 'Progress',
        detail: 'Preparing your recent activity.',
      );
    }
    if (!read.isAvailable ||
        read.value == null ||
        read.value!.activityHistory == null) {
      return const TodayProgressPresentation(
        state: TodayPresentationState.unavailable,
        headline: 'Progress unavailable',
        detail: 'Try again later to see your recent activity.',
      );
    }
    final history = read.value!.activityHistory!
        .where(_isMeaningfulActivityRecord)
        .toList(growable: false);
    if (history.isEmpty) {
      return const TodayProgressPresentation(
        state: TodayPresentationState.empty,
        headline: 'Progress not shown',
        detail: 'There is no recent progress evidence to show.',
      );
    }

    final targetEvidence = _firstMeaningfulTargetEvidence(
      read.value!.targetEvidence,
    );
    final latest = history.first;
    if (targetEvidence != null) {
      final exercise = ConsumerCopy.label(
        targetEvidence.actualExerciseName,
        fallback: 'Strength work',
      );
      final setCount = targetEvidence.workingSetCount > 0
          ? '${targetEvidence.workingSetCount} working sets recorded'
          : '${targetEvidence.totalSetCount} sets recorded';
      return TodayProgressPresentation(
        state: TodayPresentationState.ready,
        headline: exercise,
        detail: setCount,
        supporting:
            '${ConsumerCountLabel.format(history.length, 'session')} completed · '
            '${B02ProgressPresentation.range(read.value!.query)}',
      );
    }

    return TodayProgressPresentation(
      state: TodayPresentationState.ready,
      headline:
          '${ConsumerCountLabel.format(history.length, 'session')} completed',
      detail:
          'Latest: ${ConsumerCopy.label(latest.name, fallback: 'Activity')}',
      supporting: B02ProgressPresentation.range(read.value!.query),
    );
  }
}

bool _isMeaningfulActivityRecord(B02ProgressActivityRecord record) =>
    record.name.trim().isNotEmpty ||
    record.performedExerciseCount > 0 ||
    record.performedGroupCount > 0 ||
    record.cardioIntervalCount > 0 ||
    record.hasCardioDetail ||
    record.hasMobilityDetail ||
    record.durationSeconds > 0;

B02ProgressTargetEvidence? _firstMeaningfulTargetEvidence(
  List<B02ProgressTargetEvidence>? values,
) {
  if (values == null) return null;
  for (final value in values) {
    if (value.actualExerciseName.trim().isNotEmpty &&
        (value.workingSetCount > 0 || value.totalSetCount > 0)) {
      return value;
    }
  }
  return null;
}

class TodayFocusPresentation {
  final TodayPresentationState state;
  final String title;
  final String detail;
  final String? actionLabel;
  final TodayNextAction? action;
  final CalendarOccurrenceReadItem? workout;
  final WorkoutDraft? activeDraft;

  const TodayFocusPresentation({
    required this.state,
    required this.title,
    required this.detail,
    this.actionLabel,
    required this.action,
    this.workout,
    this.activeDraft,
  });

  /// Loading and source failure remain visible as safe status/retry states.
  /// A loaded focus with no canonical action is omitted so Today does not
  /// turn a generic route into a false “next up” recommendation.
  bool get shouldRender =>
      state == TodayPresentationState.loading ||
      state == TodayPresentationState.unavailable ||
      (state == TodayPresentationState.ready && action != null);
}

TodayFocusPresentation todayFocusPresentation({
  required TodayDateRelation dateRelation,
  TodaySurfaceSnapshot? snapshot,
  bool loading = false,
  bool unavailable = false,
}) {
  if (dateRelation == TodayDateRelation.future) {
    return const TodayFocusPresentation(
      state: TodayPresentationState.ready,
      title: 'Plan ahead',
      detail: 'You’re viewing a future day.',
      actionLabel: 'Return to today',
      action: TodayNextAction.returnToToday,
    );
  }
  if (loading) {
    return const TodayFocusPresentation(
      state: TodayPresentationState.loading,
      title: 'Getting your next step ready',
      detail: 'Your plan will appear here in a moment.',
      action: null,
    );
  }
  if (unavailable ||
      snapshot == null ||
      (!snapshot.calendar.isAvailable &&
          !snapshot.nutrition.isAvailable &&
          !snapshot.progress.isAvailable)) {
    return const TodayFocusPresentation(
      state: TodayPresentationState.unavailable,
      title: 'Next up unavailable',
      detail: 'Try again to load a useful next step.',
      actionLabel: 'Retry',
      action: null,
    );
  }
  final resolution = snapshot.nextActionResolution;
  if (resolution != null && !resolution.activeDraftReadAvailable) {
    return const TodayFocusPresentation(
      state: TodayPresentationState.unavailable,
      title: 'Workout state unavailable',
      detail: 'Try again to check your active workout before starting another.',
      actionLabel: 'Retry',
      action: null,
    );
  }
  final activeDraft = resolution?.activeDraft;
  if (activeDraft != null) {
    return TodayFocusPresentation(
      state: TodayPresentationState.ready,
      title: ConsumerCopy.label(activeDraft.routineName, fallback: 'Workout'),
      detail: 'Your saved workout is ready to resume.',
      actionLabel: 'Resume workout',
      action: TodayNextAction.resumeWorkout,
      activeDraft: activeDraft,
      workout: resolution?.currentOccurrence,
    );
  }
  if (resolution?.currentOccurrence != null) {
    return const TodayFocusPresentation(
      state: TodayPresentationState.ready,
      title: 'Workout in progress',
      detail: 'This workout needs attention before another one can start.',
      actionLabel: 'Open workout plan',
      action: TodayNextAction.openWorkoutPlan,
    );
  }
  if (resolution?.hasActiveDraft == true) {
    return const TodayFocusPresentation(
      state: TodayPresentationState.ready,
      title: 'Workout in progress',
      detail: 'Resolve your active workout before starting another.',
      actionLabel: 'Open workout plan',
      action: TodayNextAction.openWorkoutPlan,
    );
  }
  final overdue = resolution?.overdueOccurrence;
  if (overdue != null) {
    return TodayFocusPresentation(
      state: TodayPresentationState.ready,
      title:
          'Overdue: ${ConsumerCopy.label(overdue.template.name, fallback: 'Workout')}',
      detail:
          'This planned workout is still pending. Start or reschedule it explicitly.',
      actionLabel: 'Start workout',
      action: TodayNextAction.startWorkout,
      workout: overdue,
    );
  }
  final item = resolution?.todayOccurrence;
  if (item != null) {
    final startable =
        dateRelation == TodayDateRelation.today &&
        (item.occurrence.status == 'planned' ||
            item.occurrence.status == 'rescheduled' ||
            item.occurrence.status == 'inProgress');
    final isInProgress = item.occurrence.status == 'inProgress';
    return TodayFocusPresentation(
      state: TodayPresentationState.ready,
      title: ConsumerCopy.label(item.template.name, fallback: 'Workout'),
      detail: item.prescriptions.isEmpty
          ? 'Workout planned for today'
          : '${ConsumerCountLabel.format(item.prescriptions.length, 'exercise')} planned',
      actionLabel: startable
          ? isInProgress
                ? 'Resume workout'
                : 'Start workout'
          : 'View workout',
      action: startable
          ? TodayNextAction.startWorkout
          : TodayNextAction.openWorkoutPlan,
      workout: item,
    );
  }
  final completed = resolution?.todayCompletedOccurrence;
  if (completed != null) {
    return TodayFocusPresentation(
      state: TodayPresentationState.ready,
      title: 'Workout complete today',
      detail: 'Your completed workout is saved. Choose what to do next.',
      actionLabel: 'View workout',
      action: TodayNextAction.openWorkoutPlan,
    );
  }
  final next = resolution?.nextOccurrence;
  if (next != null && dateRelation == TodayDateRelation.today) {
    return TodayFocusPresentation(
      state: TodayPresentationState.ready,
      title:
          'Next: ${ConsumerCopy.label(next.template.name, fallback: 'Workout')}',
      detail:
          'Your next planned workout is ${next.occurrence.effectiveLocalDate}.',
      actionLabel: 'View workout plan',
      action: TodayNextAction.openWorkoutPlan,
      workout: next,
    );
  }
  return const TodayFocusPresentation(
    state: TodayPresentationState.empty,
    title: 'No next step',
    detail: 'There’s no next step right now.',
    action: null,
  );
}

String? _mealCategory(String value) {
  final key = value.trim().toLowerCase().replaceAll('-', '_');
  return switch (key) {
    'breakfast' => 'breakfast',
    'lunch' => 'lunch',
    'dinner' => 'dinner',
    'snack' || 'snacks' => 'snack',
    _ => null,
  };
}

String? _factValue(NutrientFact fact) {
  final point = fact.point == null
      ? null
      : ConsumerNumberLabel.rounded(fact.point!.value.asDouble);
  final lower = fact.lower == null
      ? null
      : ConsumerNumberLabel.rounded(fact.lower!.value.asDouble);
  final upper = fact.upper == null
      ? null
      : ConsumerNumberLabel.rounded(fact.upper!.value.asDouble);
  if (lower != null || upper != null) {
    if (lower != null && upper != null) return '$lower–$upper';
    if (lower != null) return '$lower+';
    if (upper != null) return 'Up to $upper';
  }
  return point;
}

String _formatNumber(double value) {
  return ConsumerNumberLabel.rounded(value);
}

String _workoutStatus(Object? value) {
  final key = value?.toString().toLowerCase().replaceAll('_', ' ') ?? '';
  return switch (key) {
    'planned' || 'rescheduled' || 'scheduled' => 'Planned for today',
    'inprogress' || 'in progress' => 'In progress',
    'completed' || 'complete' => 'Completed today',
    'skipped' => 'Skipped',
    'cancelled' || 'canceled' => 'Cancelled',
    _ => ConsumerCopy.state(key),
  };
}
