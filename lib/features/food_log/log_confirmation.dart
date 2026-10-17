import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/typed_quantities.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../dashboard/today_surface_controller.dart';
import 'food_log_surface.dart';
import 'food_search_view_models.dart';
import 'meal_presentation_registry.dart';

/// "Snacks", "Lunch": the meal as the app names it elsewhere.
String loggedMealLabel(String? stableId) {
  if (stableId == null || stableId.trim().isEmpty) return 'your meal';
  final presentation = MealPresentationRegistry.forStableId(stableId);
  return presentation.isKnown ? presentation.label : 'your meal';
}

/// "Added 1 glass Full Cream Milk · 150 kcal to Snacks" (UR-12). [amount]
/// is the amount as the user picked it; it defaults to the logged quantity.
String loggedConfirmationMessage(
  NutritionConsumptionSnapshot snapshot, {
  String? amount,
  String? name,
  bool again = false,
}) {
  final items = snapshot.items;
  final String what;
  if (items.length <= 1) {
    final item = items.firstOrNull;
    final label = item?.displayLabel?.trim().isNotEmpty == true
        ? item!.displayLabel!.trim()
        : name ?? 'food';
    final shown =
        amount ?? (item == null ? '' : QuantityFormatter.format(item.quantity));
    what = shown.isEmpty ? label : '$shown $label';
  } else {
    final names = [
      for (final item in items)
        if (item.displayLabel?.trim().isNotEmpty == true)
          item.displayLabel!.trim(),
    ];
    what = names.isEmpty
        ? '${items.length} items'
        : names.length <= 2
        ? names.join(', ')
        : '${names.take(2).join(', ')} +${names.length - 2}';
  }
  final energy = snapshot.totals.facts['energy'];
  final kcal = energy != null && energy.isAvailable && energy.point != null
      ? ' · ${energy.point!.value.format(decimalPlaces: 0)} kcal'
      : '';
  final verb = again ? 'Added again:' : 'Added';
  return '$verb $what$kcal to ${loggedMealLabel(snapshot.mealCategory)}';
}

/// The one confirmation every add path shows: what was logged, its kcal and
/// meal, with Undo that removes it again (UR-12, UR-15).
void showLoggedFoodUndo(
  BuildContext context,
  NutritionConsumptionSnapshot snapshot, {
  String? amount,
  String? name,
  bool again = false,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  showIndiFitUndoFeedback(
    context,
    message: loggedConfirmationMessage(
      snapshot,
      amount: amount,
      name: name,
      again: again,
    ),
    duration: const Duration(seconds: 5),
    onUndo: () async {
      try {
        final repository = await container.read(
          nutritionConsumptionRepositoryProvider.future,
        );
        await repository.retractConsumption(
          userId: kLocalNutritionUserScopeId,
          snapshotId: snapshot.id,
          expectedLocalDate: snapshot.localDate ?? '',
          expectedMealCategory: snapshot.mealCategory,
          commandId: 'log-undo::${snapshot.id}',
          reason: 'User undid a log.',
        );
      } catch (error, stackTrace) {
        AppLogger.error('Undo log failed', error, stackTrace);
        messenger?.showSnackBar(
          const SnackBar(
            content: Text("Couldn't undo. Delete it from the meal instead."),
          ),
        );
      }
      container.invalidate(foodDiaryReadModelProvider);
      container.invalidate(canonicalFoodRecordsForDayProvider);
      container.invalidate(canonicalRecentFoodsProvider);
      container.read(todayNutritionRevisionProvider.notifier).state++;
    },
  );
}
