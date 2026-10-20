import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/presentation/consumer_number_label.dart';
import '../../core/services/indifit_haptics.dart';
import '../../core/typed_quantities.dart';
import '../../core/utils/app_logger.dart';
import '../../core/widgets/indi_fit_feedback.dart';
import '../dashboard/today_surface_controller.dart';
import 'food_log_surface.dart';
import 'food_search_view_models.dart';
import 'meal_presentation_registry.dart';
import 'widgets/meal_icon_chip.dart';

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

/// "1,846 kcal left · +8 g protein": the day after this log (TF-1).
/// [dayKcal] is the day's total including this log; parts that can't be
/// read are left out, and null when neither can.
String? loggedDayChangeLine({
  double? dayKcal,
  int? calorieTargetKcal,
  double? addedProteinG,
}) {
  final parts = <String>[
    if (dayKcal != null && calorieTargetKcal != null)
      calorieTargetKcal >= dayKcal
          ? '${ConsumerNumberLabel.rounded(calorieTargetKcal - dayKcal)} kcal left'
          : '${ConsumerNumberLabel.rounded(dayKcal - calorieTargetKcal)} kcal over',
    if (addedProteinG != null && addedProteinG > 0)
      '+${ConsumerNumberLabel.grams(addedProteinG)} protein',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

double? _kcal(Iterable<NutrientFact?> facts) {
  final list = facts.toList(growable: false);
  if (list.isEmpty ||
      list.any((fact) => fact?.isAvailable != true || fact!.point == null)) {
    return null;
  }
  return list.fold<double>(0, (sum, fact) => sum + fact!.point!.value.asDouble);
}

/// Reads the day as the diary does: its records' energy and its target.
Future<String?> _dayChangeAfter(
  ProviderContainer container,
  List<NutritionConsumptionSnapshot> snapshots,
) async {
  final snapshot = snapshots.first;
  double? addedProteinG;
  for (final each in snapshots) {
    final protein = each.totals.facts['protein'];
    if (protein?.isAvailable == true && protein!.point != null) {
      addedProteinG = (addedProteinG ?? 0) + protein.point!.value.asDouble;
    }
  }
  final day = DateTime.tryParse(snapshot.localDate ?? '');
  if (day == null) return loggedDayChangeLine(addedProteinG: addedProteinG);
  final provider = foodDiaryReadModelProvider(
    DateTime(day.year, day.month, day.day),
  );
  // Keep the auto-dispose read alive until it resolves.
  final keepAlive = container.listen(provider, (_, _) {});
  try {
    final diary = await container.read(provider.future);
    return loggedDayChangeLine(
      dayKcal: _kcal([
        for (final record in diary.daily.records) record.totals.facts['energy'],
      ]),
      calorieTargetKcal: diary.targets.value?.calorieTargetKcal,
      addedProteinG: addedProteinG,
    );
  } catch (error, stackTrace) {
    AppLogger.error('Log confirmation day totals failed', error, stackTrace);
    return loggedDayChangeLine(addedProteinG: addedProteinG);
  } finally {
    keepAlive.close();
  }
}

/// The food-log confirmation card (TF-1, UR-42): the meal's art, what was
/// added, the day's change after the write, Undo, and one light tap. Shows
/// for 4 s above the tab bar or search's meal bar. Callers have already
/// invalidated the day's reads.
void showFoodLogConfirmation(
  BuildContext context,
  NutritionConsumptionSnapshot snapshot, {
  required VoidCallback onUndo,
  String? amount,
  String? name,
  bool again = false,
  String? message,
  bool haptic = true,
  List<NutritionConsumptionSnapshot> moreSnapshots = const [],
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (haptic) unawaited(IndiFitHaptics.light());
  showIndiFitUndoFeedback(
    context,
    message:
        message ??
        loggedConfirmationMessage(
          snapshot,
          amount: amount,
          name: name,
          again: again,
        ),
    leading: ExcludeSemantics(
      child: MealIconChip(
        presentation: MealPresentationRegistry.forStableId(
          snapshot.mealCategory,
        ),
        size: 36,
      ),
    ),
    detail: _dayChangeAfter(container, [snapshot, ...moreSnapshots]),
    duration: const Duration(seconds: 4),
    onUndo: onUndo,
  );
}

/// The one confirmation every add path shows: what was logged, its kcal and
/// meal, with Undo that removes it again (UR-12, UR-15).
void showLoggedFoodUndo(
  BuildContext context,
  NutritionConsumptionSnapshot snapshot, {
  String? amount,
  String? name,
  bool again = false,
  void Function(String snapshotId)? onUndone,
}) {
  showLoggedSnapshotsUndo(
    context,
    [snapshot],
    message: loggedConfirmationMessage(
      snapshot,
      amount: amount,
      name: name,
      again: again,
    ),
    onUndone: onUndone,
  );
}

/// [showLoggedFoodUndo] for several entries logged by one tap, such as a
/// usual meal (UF-1): one message, and Undo removes all of them.
void showLoggedSnapshotsUndo(
  BuildContext context,
  List<NutritionConsumptionSnapshot> snapshots, {
  required String message,
  void Function(String snapshotId)? onUndone,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  showFoodLogConfirmation(
    context,
    snapshots.first,
    message: message,
    moreSnapshots: snapshots.skip(1).toList(growable: false),
    onUndo: () async {
      try {
        final repository = await container.read(
          nutritionConsumptionRepositoryProvider.future,
        );
        for (final snapshot in snapshots) {
          await repository.retractConsumption(
            userId: kLocalNutritionUserScopeId,
            snapshotId: snapshot.id,
            expectedLocalDate: snapshot.localDate ?? '',
            expectedMealCategory: snapshot.mealCategory,
            commandId: 'log-undo::${snapshot.id}',
            reason: 'User undid a log.',
          );
          onUndone?.call(snapshot.id);
        }
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
