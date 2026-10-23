import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/consumer_number_label.dart';
import '../../core/utils/app_logger.dart';
import '../dashboard/day_marks.dart';
import 'food_log_surface.dart';
import 'food_search_view_models.dart';
import 'log_confirmation.dart';
import 'meal_presentation_registry.dart';
import 'repeat_meal.dart';
import 'widgets/food_diary_widgets.dart';

/// UF-6: copy a meal or a whole day to another day, through the repeat
/// path. Single foods, thalis and recipes log again as themselves; AI
/// estimates and quick adds copy as they were logged, estimate tag
/// included. A copy always adds: what is on the target day stays.
///
/// Copies [records] to [targetDay]. With [mealType] everything lands in
/// that meal; without it each record keeps its own meal (a day copy).
Future<RepeatOutcome> copyMealRecords(
  WidgetRef ref, {
  required Iterable<NutritionHistoricalReadRecord> records,
  required DateTime targetDay,
  String? mealType,
}) async {
  if (mealType != null) {
    return repeatMealRecords(
      ref,
      mealType: mealType,
      records: records,
      targetDay: targetDay,
      copyAsLogged: true,
    );
  }
  final byMeal = <String, List<NutritionHistoricalReadRecord>>{};
  for (final record in records) {
    byMeal.putIfAbsent(record.mealCategory, () => []).add(record);
  }
  var outcome = const RepeatOutcome();
  for (final MapEntry(key: meal, value: mealRecords) in byMeal.entries) {
    outcome += await repeatMealRecords(
      ref,
      mealType: meal,
      records: mealRecords,
      targetDay: targetDay,
      copyAsLogged: true,
    );
  }
  return outcome;
}

/// "Copied Lunch (3 items · 540 kcal) to Thu, 23 Oct". The count and
/// calories are those of the entries just logged; calories are left out
/// when any of them has no single value.
String copiedMessage({
  required String what,
  required RepeatOutcome outcome,
  required String targetLocalDate,
}) {
  final items = outcome.logged == 1 ? '1 item' : '${outcome.logged} items';
  final kcal = _kcal(outcome.snapshots);
  final summary = kcal == null
      ? items
      : '$items · ${ConsumerNumberLabel.rounded(kcal)} kcal';
  final skipped = outcome.skipped == 0
      ? ''
      : '. ${outcome.skipped} changed since and '
            '${outcome.skipped == 1 ? 'was' : 'were'} not copied';
  return 'Copied $what ($summary) to '
      '${ConsumerDateLabel.date(targetLocalDate)}$skipped';
}

double? _kcal(List<NutritionConsumptionSnapshot> snapshots) {
  var total = 0.0;
  for (final snapshot in snapshots) {
    final fact = snapshot.totals.facts['energy'];
    final value = fact?.point?.value.asDouble;
    if (fact == null || !fact.isAvailable || value == null) return null;
    total += value;
  }
  return total;
}

/// The whole "Copy to another day" flow from a menu: pick the day on the
/// month sheet, for a single meal confirm or change the meal, copy, then
/// confirm with Undo for every entry copied. [sourceMealType] is null for
/// a whole day.
Future<void> copyToAnotherDay(
  BuildContext context,
  WidgetRef ref, {
  required List<NutritionHistoricalReadRecord> records,
  required DateTime sourceDay,
  String? sourceMealType,
  List<String> mealTypes = const [],
}) async {
  if (records.isEmpty) return;
  final day = await pickDiaryDay(
    context,
    initialDay: sourceDay,
    title: sourceMealType == null
        ? 'Copy this day to'
        : 'Copy ${foodDiaryMealTitle(sourceMealType)} to',
  );
  if (day == null || !context.mounted) return;
  var mealType = sourceMealType;
  if (sourceMealType != null) {
    mealType = await _pickMeal(
      context,
      current: sourceMealType,
      mealTypes: mealTypes,
    );
    if (mealType == null || !context.mounted) return;
  }
  try {
    final outcome = await copyMealRecords(
      ref,
      records: records,
      targetDay: day,
      mealType: mealType,
    );
    ref.invalidate(foodDiaryReadModelProvider);
    ref.invalidate(canonicalFoodRecordsForDayProvider);
    ref.invalidate(canonicalRecentFoodsProvider);
    if (!context.mounted || outcome.snapshots.isEmpty) return;
    final what = sourceMealType == null
        ? ConsumerDateLabel.date(_isoDate(sourceDay))
        : foodDiaryMealTitle(sourceMealType);
    showLoggedSnapshotsUndo(
      context,
      outcome.snapshots,
      message: copiedMessage(
        what: what,
        outcome: outcome,
        targetLocalDate: outcome.snapshots.first.localDate ?? _isoDate(day),
      ),
    );
  } on Object catch (error, stackTrace) {
    AppLogger.error('Copy to another day failed', error, stackTrace);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not copy. Try again.'),
        ),
      );
    }
  }
}

/// The meal to copy into: [current] unless another is picked.
Future<String?> _pickMeal(
  BuildContext context, {
  required String current,
  required List<String> mealTypes,
}) {
  final options = {
    current,
    ...mealTypes,
    if (mealTypes.isEmpty)
      for (final meal in MealPresentationRegistry.values) meal.stableId,
  }.toList(growable: false);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      var picked = current;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Copy into'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final meal in options)
                ChoiceChip(
                  key: ValueKey('copy_meal_$meal'),
                  label: Text(foodDiaryMealTitle(meal)),
                  selected: picked == meal,
                  onSelected: (_) => setState(() => picked = meal),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('copy_meal_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(picked),
              child: const Text('Copy'),
            ),
          ],
        ),
      );
    },
  );
}

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
