import '../../core/nutrients.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/presentation/consumer_count_label.dart';
import '../../core/presentation/consumer_number_label.dart';
import '../../data/models/b02_progress_read_models.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../progress/b02_progress_presentation.dart';
import 'today_presentation_types.dart';
import 'today_surface_controller.dart';

/// Display-ready state for the Today page. These values intentionally contain
/// no source IDs, policy metadata, or persistence vocabulary. The source read
/// models remain authoritative; this file only decides how to show them well.
enum TodayPresentationState { loading, ready, empty, unavailable }

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
    final occurrences = read.value!.rangeOccurrences;
    if (occurrences.isEmpty) {
      return const TodayWorkoutPresentation(
        state: TodayPresentationState.empty,
        title: 'Nothing planned today',
        detail: 'Choose a workout whenever you’re ready.',
      );
    }
    final occurrence = occurrences.first;
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
    this.hasIncompleteNutrition = false,
    this.isNoConsumptionKnown = false,
  });

  factory TodayNutritionPresentation.from(
    TodayDomainRead<NutritionDailyReadModel>? read, {
    required bool loading,
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
    final acceptedGoal = goal?.isAvailable == true ? goal!.value : null;
    final calorieTarget = acceptedGoal?.calorieTargetKcal?.toDouble();
    final noConsumption = daily.records.isEmpty;
    final targets = <String, double?>{
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
            targetValue: targets['energy'],
          )
        : TodayNutritionMetricPresentation.fromFact(
            nutrientId: 'energy',
            label: 'Calories',
            fallbackUnit: 'kcal',
            fact: facts['energy'],
            targetValue: targets['energy'],
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
                targetValue: targets[entry.$1],
              )
            : TodayNutritionMetricPresentation.fromFact(
                nutrientId: entry.$1,
                label: entry.$2,
                fallbackUnit: 'g',
                fact: facts[entry.$1],
                targetValue: targets[entry.$1],
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
          ? 'Some nutrition is incomplete'
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
    if (!read.isAvailable || read.value!.activityHistory == null) {
      return const TodayActivityPresentation(
        state: TodayPresentationState.unavailable,
        headline: 'Activity unavailable',
        detail: 'Try again later for your recent activity.',
      );
    }
    final history = read.value!.activityHistory!;
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
      headline: 'Activity this week',
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
    if (!read.isAvailable || read.value!.activityHistory == null) {
      return const TodayProgressPresentation(
        state: TodayPresentationState.unavailable,
        headline: 'Progress unavailable',
        detail: 'Try again later to see your recent activity.',
      );
    }
    final history = read.value!.activityHistory!;
    if (history.isEmpty) {
      return const TodayProgressPresentation(
        state: TodayPresentationState.empty,
        headline: 'Your progress starts with one workout',
        detail: 'Your weekly view will build from completed sessions.',
      );
    }
    return TodayProgressPresentation(
      state: TodayPresentationState.ready,
      headline: 'Your week is taking shape',
      detail: 'Keep building the routine that works for you.',
      supporting: B02ProgressPresentation.range(read.value!.query),
    );
  }
}

class TodayFocusPresentation {
  final TodayPresentationState state;
  final String title;
  final String detail;
  final String? actionLabel;
  final TodayNextAction? action;
  final CalendarOccurrenceReadItem? workout;

  const TodayFocusPresentation({
    required this.state,
    required this.title,
    required this.detail,
    this.actionLabel,
    required this.action,
    this.workout,
  });
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
  final scheduled = snapshot.calendar.value?.rangeOccurrences;
  if (scheduled != null && scheduled.isNotEmpty) {
    final item = scheduled.first;
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
  final hasNoMeals = snapshot.nutrition.value?.records.isEmpty == true;
  if (hasNoMeals) {
    return const TodayFocusPresentation(
      state: TodayPresentationState.ready,
      title: 'Log your first meal',
      detail: 'Start with breakfast whenever you’re ready.',
      actionLabel: 'Log breakfast',
      action: TodayNextAction.logMeal,
    );
  }
  return const TodayFocusPresentation(
    state: TodayPresentationState.ready,
    title: 'Nothing planned today',
    detail: 'Choose a workout or enjoy a recovery day.',
    actionLabel: 'Choose workout',
    action: TodayNextAction.openWorkoutPlan,
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
