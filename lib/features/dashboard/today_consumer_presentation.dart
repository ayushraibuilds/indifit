import '../../core/nutrients.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../data/models/b02_progress_read_models.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../progress/b02_progress_presentation.dart';
import 'today_presentation_types.dart';
import 'today_surface_controller.dart';

/// Display-ready copy for the Today page. These values intentionally contain
/// no source identifiers, reason codes, policy metadata, or persistence
/// vocabulary. The read models remain authoritative; this file only decides
/// what is useful to show a person.
enum TodayPresentationState { loading, ready, empty, unavailable }

class TodayWorkoutPresentation {
  final TodayPresentationState state;
  final String title;
  final String detail;
  final String? status;

  const TodayWorkoutPresentation({
    required this.state,
    required this.title,
    required this.detail,
    this.status,
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
        title: 'Your plan is unavailable',
        detail: 'Open your workout plan to try again.',
      );
    }
    final occurrences = read.value!.rangeOccurrences;
    if (occurrences.isEmpty) {
      return const TodayWorkoutPresentation(
        state: TodayPresentationState.empty,
        title: 'Nothing planned today',
        detail: 'Choose a workout or enjoy a recovery day.',
      );
    }
    final occurrence = occurrences.first;
    return TodayWorkoutPresentation(
      state: TodayPresentationState.ready,
      title: ConsumerCopy.label(occurrence.template.name, fallback: 'Workout'),
      detail: _workoutStatus(occurrence.occurrence.status),
      status: _workoutStatus(occurrence.occurrence.status),
    );
  }
}

class TodayNutritionMetricPresentation {
  final String label;
  final String value;
  final String unit;
  final bool estimated;

  const TodayNutritionMetricPresentation({
    required this.label,
    required this.value,
    required this.unit,
    this.estimated = false,
  });
}

class TodayMealPresentation {
  final String label;
  final String detail;
  final bool logged;

  const TodayMealPresentation({
    required this.label,
    required this.detail,
    required this.logged,
  });
}

class TodayNutritionPresentation {
  final TodayPresentationState state;
  final String headline;
  final String detail;
  final TodayNutritionMetricPresentation? calories;
  final List<TodayNutritionMetricPresentation> macros;
  final List<TodayMealPresentation> meals;

  const TodayNutritionPresentation({
    required this.state,
    required this.headline,
    required this.detail,
    this.calories,
    this.macros = const [],
    this.meals = const [],
  });

  factory TodayNutritionPresentation.from(
    TodayDomainRead<NutritionDailyReadModel>? read, {
    required bool loading,
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
        headline: 'Nutrition is unavailable',
        detail: 'Log a meal or try again later.',
      );
    }
    final daily = read.value!;
    if (daily.records.isEmpty) {
      return const TodayNutritionPresentation(
        state: TodayPresentationState.empty,
        headline: 'Your nutrition starts here',
        detail: "Log your first meal to see today's totals.",
        meals: [
          TodayMealPresentation(
            label: 'Breakfast',
            detail: 'Ready when you are',
            logged: false,
          ),
          TodayMealPresentation(
            label: 'Lunch',
            detail: 'Ready when you are',
            logged: false,
          ),
          TodayMealPresentation(
            label: 'Dinner',
            detail: 'Ready when you are',
            logged: false,
          ),
        ],
      );
    }

    final facts = daily.totals.facts;
    final calories = _metric(facts['energy']);
    final macros = <TodayNutritionMetricPresentation>[];
    for (final id in const ['protein', 'carbohydrate', 'fat', 'fiber']) {
      final metric = _metric(facts[id]);
      if (metric != null) macros.add(metric);
    }
    final known = calories != null || macros.isNotEmpty;
    final mealRows = _mealRows(daily.records);
    return TodayNutritionPresentation(
      state: known
          ? TodayPresentationState.ready
          : TodayPresentationState.empty,
      headline: known ? 'Nutrition today' : 'Add a little more detail',
      detail: known
          ? 'Keep building a clear picture of your day.'
          : 'Some meals do not have enough detail for a total yet.',
      calories: calories,
      macros: macros,
      meals: mealRows,
    );
  }

  static TodayNutritionMetricPresentation? _metric(NutrientFact? fact) {
    if (fact == null || !fact.isAvailable) return null;
    final value = _factValue(fact);
    if (value == null) return null;
    return TodayNutritionMetricPresentation(
      label: ConsumerCopy.nutrient(fact.nutrientId),
      value: value,
      unit: fact.unit.symbol,
      estimated: fact.status == NutrientFactStatus.estimated,
    );
  }

  static String? _factValue(NutrientFact fact) {
    final point = fact.point?.value.toString();
    final lower = fact.lower?.value.toString();
    final upper = fact.upper?.value.toString();
    if (lower != null || upper != null) {
      if (lower != null && upper != null) return '$lower–$upper';
      if (lower != null) return '$lower+';
      if (upper != null) return 'Up to $upper';
    }
    return point;
  }

  static List<TodayMealPresentation> _mealRows(
    List<NutritionHistoricalReadRecord> records,
  ) {
    final byCategory = <String, NutritionHistoricalReadRecord>{};
    for (final record in records) {
      final category = _mealCategory(record.mealCategory);
      byCategory.putIfAbsent(category, () => record);
    }
    return [
      for (final category in const ['Breakfast', 'Lunch', 'Dinner', 'Snack'])
        if (byCategory[category] case final record?)
          TodayMealPresentation(
            label: category,
            detail: ConsumerCopy.label(
              record.displayLabel,
              fallback: 'Meal logged',
            ),
            logged: true,
          ),
    ];
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
        headline: 'Your progress',
        detail: 'Preparing your recent activity.',
      );
    }
    if (!read.isAvailable) {
      return const TodayProgressPresentation(
        state: TodayPresentationState.unavailable,
        headline: 'Progress is unavailable',
        detail: 'Try again later to see your recent activity.',
      );
    }
    final history = read.value!.activityHistory;
    if (history == null) {
      return const TodayProgressPresentation(
        state: TodayPresentationState.unavailable,
        headline: 'Progress is still loading',
        detail: 'We will show your activity when it is ready.',
      );
    }
    if (history.isEmpty) {
      return const TodayProgressPresentation(
        state: TodayPresentationState.empty,
        headline: 'Your progress starts with your first workout',
        detail: 'Complete a workout to start seeing your week take shape.',
      );
    }
    final sessions = history.length;
    final duration = history.fold<int>(
      0,
      (total, item) => total + item.durationSeconds,
    );
    final minutes = duration ~/ 60;
    return TodayProgressPresentation(
      state: TodayPresentationState.ready,
      headline: '$sessions ${sessions == 1 ? 'session' : 'sessions'} this week',
      detail: minutes == 0
          ? 'Nice work keeping your momentum going.'
          : '$minutes minutes of movement recorded this week.',
      supporting: B02ProgressPresentation.range(read.value!.query),
    );
  }
}

class TodayFocusPresentation {
  final String title;
  final String detail;
  final String actionLabel;
  final TodayNextAction action;

  const TodayFocusPresentation({
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.action,
  });
}

TodayFocusPresentation todayFocusPresentation({
  required TodayDateRelation dateRelation,
  TodaySurfaceSnapshot? snapshot,
}) {
  if (dateRelation == TodayDateRelation.future) {
    return const TodayFocusPresentation(
      title: 'Plan ahead',
      detail: 'Future dates are for planning. Come back today to get moving.',
      actionLabel: 'Return to today',
      action: TodayNextAction.returnToToday,
    );
  }
  final hasWorkout = snapshot?.calendar.value?.rangeOccurrences.isNotEmpty;
  if (hasWorkout == true) {
    return const TodayFocusPresentation(
      title: 'Your workout is up next',
      detail: 'A focused session is waiting in your plan.',
      actionLabel: 'View today’s workout',
      action: TodayNextAction.openWorkoutPlan,
    );
  }
  final hasMeals = snapshot?.nutrition.value?.records.isNotEmpty ?? false;
  if (!hasMeals) {
    return const TodayFocusPresentation(
      title: 'Start with one small win',
      detail: 'Log your first meal and make today easier to follow.',
      actionLabel: 'Log your first meal',
      action: TodayNextAction.logMeal,
    );
  }
  return const TodayFocusPresentation(
    title: 'Choose your next move',
    detail: 'Open your plan to pick a workout or take a recovery day.',
    actionLabel: 'Open workout plan',
    action: TodayNextAction.openWorkoutPlan,
  );
}

String _mealCategory(String value) {
  final key = value.trim().toLowerCase().replaceAll('-', '_');
  return switch (key) {
    'breakfast' => 'Breakfast',
    'lunch' => 'Lunch',
    'dinner' => 'Dinner',
    'snack' || 'snacks' => 'Snack',
    _ => 'Meal',
  };
}

String _workoutStatus(Object? value) {
  final key = value?.toString().toLowerCase().replaceAll('_', ' ') ?? '';
  return switch (key) {
    'scheduled' || 'planned' => 'Planned for today',
    'completed' || 'complete' => 'Completed today',
    'skipped' => 'Skipped',
    'cancelled' || 'canceled' => 'Cancelled',
    _ => ConsumerCopy.state(key),
  };
}
