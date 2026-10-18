import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../data/repositories/nutrition_read_model_repository.dart';
import '../dashboard/today_surface_controller.dart';
import 'meal_presentation_registry.dart';
import 'repeat_meal.dart';

/// The meal someone eats in one slot most days, so Today can offer it in
/// one tap (UF-1): "Your usual breakfast: Poha + Chai · 305 kcal".
class UsualMeal {
  const UsualMeal({
    required this.slot,
    required this.mealCategory,
    required this.records,
    required this.days,
    required this.names,
    required this.signature,
    this.kcal,
  });

  /// The slot kind: breakfast, lunch, snack or dinner (see
  /// [UsualMealFinder.slotOf]).
  final String slot;

  /// The meal it was last logged into, so a repeat lands in the same row.
  final String mealCategory;

  /// The newest day's records of this meal; repeating them logs the usual.
  final List<NutritionHistoricalReadRecord> records;

  /// Days in the window this meal was logged in [slot].
  final int days;
  final List<String> names;

  /// The foods in the meal, sorted; see [UsualMealFinder.signatureOf].
  final String signature;

  /// The newest day's logged kcal; null when any record has no energy fact.
  final double? kcal;

  /// "Poha + Chai".
  String get title => names.join(' + ');
}

abstract final class UsualMealFinder {
  /// How far back "usual" looks.
  static const window = Duration(days: 14);

  /// The same foods on at least this many days before it's called usual.
  static const minimumDays = 4;

  /// Folds the snack rows into one slot, so a usual evening snack still
  /// counts when Today asks for "snack".
  static String slotOf(String mealCategory) {
    final id = mealCategory.trim().toLowerCase();
    return switch (id) {
      'snacks' ||
      'morning_snack' ||
      'afternoon_snack' ||
      'evening_snack' ||
      'late_snack' => 'snack',
      _ => id,
    };
  }

  /// The slot Today offers at [localTime]: the Today hero's time rule.
  static String slotAt(DateTime localTime) =>
      slotOf(MealPresentationRegistry.forLocalTime(localTime).stableId);

  /// What a record contributes to a meal's identity: the thali, the recipe
  /// or each catalogue food. Estimates and quick adds have nothing exact to
  /// repeat, so they add nothing.
  static List<String> keysOf(NutritionHistoricalReadRecord record) {
    final plan = planRepeat([record]);
    return [
      for (final thali in plan.thalis) 'thali:${thali.thaliId}',
      for (final recipe in plan.recipes) 'recipe:${recipe.recipeId}',
      for (final food in plan.foods) 'food:${food.foodId}',
    ];
  }

  /// The set of foods in [records], sorted; empty when nothing repeats.
  static String signatureOf(Iterable<NutritionHistoricalReadRecord> records) =>
      ({
        for (final record in records) ...keysOf(record),
      }.toList()..sort()).join(';');

  /// The meal logged in [slot] on the most days of [history] (ties go to the
  /// most recent), or null when none reached [minimumDays].
  static UsualMeal? find(
    Iterable<NutritionHistoricalReadRecord> history, {
    required String slot,
  }) {
    final byDay = <String, List<NutritionHistoricalReadRecord>>{};
    for (final record in history) {
      if (slotOf(record.mealCategory) != slot) continue;
      if (keysOf(record).isEmpty) continue;
      byDay.putIfAbsent(record.localDate, () => []).add(record);
    }
    final daysBySignature = <String, List<String>>{};
    for (final day in byDay.entries) {
      daysBySignature
          .putIfAbsent(signatureOf(day.value), () => [])
          .add(day.key);
    }
    String? bestSignature;
    var bestDays = <String>[];
    for (final entry in daysBySignature.entries) {
      final days = entry.value..sort();
      if (days.length < minimumDays) continue;
      if (days.length > bestDays.length ||
          (days.length == bestDays.length &&
              days.last.compareTo(bestDays.last) > 0)) {
        bestSignature = entry.key;
        bestDays = days;
      }
    }
    if (bestSignature == null) return null;
    final records = byDay[bestDays.last]!
      ..sort((a, b) => a.loggedAtUtc.compareTo(b.loggedAtUtc));
    final plan = planRepeat(records);
    double? kcal = 0;
    for (final record in records) {
      final energy = record.totals.facts['energy'];
      final value = energy?.point?.value.asDouble;
      kcal = value == null || kcal == null ? null : kcal + value;
    }
    return UsualMeal(
      slot: slot,
      mealCategory: records.last.mealCategory,
      records: List.unmodifiable(records),
      days: bestDays.length,
      names: plan.names,
      signature: bestSignature,
      kcal: kcal,
    );
  }
}

/// The usual meal for the slot at this time of day over the last 14 days;
/// null when there isn't one.
final usualMealProvider = FutureProvider.autoDispose.family<UsualMeal?, String>(
  (ref, slot) async {
    ref.watch(todayNutritionRevisionProvider);
    final repository = await ref.watch(
      nutritionReadModelRepositoryProvider.future,
    );
    return readUsualMeal(repository, slot);
  },
);

/// The usual meal for [slot] over the last 14 days, read from [repository];
/// also what the meal reminders name (UF-19).
Future<UsualMeal?> readUsualMeal(
  NutritionReadModelRepository repository,
  String slot,
) async {
  final now = DateTime.now().toUtc();
  final history = await repository.listHistory(
    userId: kLocalNutritionUserScopeId,
    fromUtc: now.subtract(UsualMealFinder.window),
    toUtc: now,
  );
  return UsualMealFinder.find(history, slot: slot);
}
