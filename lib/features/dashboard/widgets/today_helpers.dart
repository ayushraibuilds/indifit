import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/nutrition_legacy_read_models.dart';
import '../../../core/presentation/consumer_number_label.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/models/b04_current_food_models.dart';
import '../../nutrition/current_food_controller.dart';
import '../today_consumer_presentation.dart';
import '../today_presentation_types.dart';
import '../today_surface_controller.dart';

/// Pure Today helpers: date relations, next-action choice, nutrition state,
/// and formatting (PV1-ENG-05B first pass).
///
/// Extracted verbatim from `today_daily_action_surface.dart`; unchanged.

TodayDateRelation todayDateRelation(DateTime selectedDate, DateTime now) {
  DateTime day(DateTime value) => DateTime(value.year, value.month, value.day);
  final selected = day(selectedDate);
  final current = day(now);
  if (selected.isBefore(current)) return TodayDateRelation.past;
  if (selected.isAfter(current)) return TodayDateRelation.future;
  return TodayDateRelation.today;
}

/// Returns the visible context for the selected civil date without changing
/// the date authority. The short relative word makes historical and future
/// browsing obvious while the full date keeps the context unambiguous.
String todayDateContextLabel(DateTime selectedDate, DateTime now) {
  final formatted = DateFormat('EEEE, d MMMM').format(selectedDate);
  return switch (todayDateRelation(selectedDate, now)) {
    TodayDateRelation.today => 'Today · $formatted',
    TodayDateRelation.past => 'Past day · $formatted',
    TodayDateRelation.future => 'Upcoming · $formatted',
  };
}

/// Returns true only for a current-day B04 result that already contains a
/// canonical, actionable candidate card. The Today surface does not infer
/// usefulness from calories, macros, or local thresholds.
bool todayMealIdeasAreAvailable({
  required TodayDateRelation dateRelation,
  required B04CurrentFoodState state,
  String? expectedLocalDate,
}) {
  if (dateRelation != TodayDateRelation.today ||
      state.status != B04CurrentFoodControllerStatus.ready) {
    return false;
  }
  final guidance = state.guidance;
  return guidance != null &&
      guidance.status == B04CurrentFoodGuidanceStatus.available &&
      guidance.cards.isNotEmpty &&
      (expectedLocalDate == null || guidance.localDate == expectedLocalDate);
}

class TodayNextActionChoice {
  final TodayNextAction? action;
  final String label;
  final String hint;

  const TodayNextActionChoice({
    required this.action,
    required this.label,
    required this.hint,
  });

  bool get shouldRender => action != null;
}

/// Compatibility projection for callers that still consume the older choice
/// shape. The current/next decision remains entirely in
/// [todayFocusPresentation], which consumes the shared R08A.2 resolver.
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
  final focus = todayFocusPresentation(
    dateRelation: dateRelation,
    snapshot: snapshot,
  );
  return TodayNextActionChoice(
    action: focus.action,
    label: focus.actionLabel ?? 'No next action',
    hint: focus.action == null
        ? focus.detail
        : '${focus.title}. ${focus.detail}',
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

/// The Today foundation composition. It reads source-owned B01–B04
/// projections and B05 layout preferences; it does not query Drift or
/// calculate domain facts.
String handoffNumber(double value) => value == value.roundToDouble()
    ? NumberFormat.decimalPattern().format(value.toInt())
    : NumberFormat.decimalPattern().format(value);

TextStyle todayEyebrow(BuildContext context) => B05Typography.caption(
  context,
).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.1);

String formatTodayMetric(double value) {
  return ConsumerNumberLabel.rounded(value);
}
