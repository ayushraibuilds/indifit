import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../dashboard/today_surface_controller.dart';

/// Consumer-facing delete flow for one canonical B03 direct-food item.
///
/// The UI uses ordinary delete terminology while the coordinator preserves
/// immutable history through an exact-item correction or retraction command.
Future<bool> showCanonicalFoodDelete({
  required BuildContext context,
  required WidgetRef ref,
  required NutritionHistoricalReadRecord record,
}) async {
  final item = record.items
      .where(
        (candidate) =>
            candidate.originSourceType == 'direct_food' &&
            candidate.foodId != null,
      )
      .firstOrNull;
  if (item == null ||
      record.items
              .where(
                (candidate) =>
                    candidate.originSourceType == 'direct_food' &&
                    candidate.foodId != null,
              )
              .length !=
          1) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Choose one food entry at a time.'),
        ),
      );
    }
    return false;
  }
  return showCanonicalFoodItemDelete(
    context: context,
    ref: ref,
    record: record,
    item: item,
  );
}

/// Deletes one exact persisted item from a canonical direct-food snapshot.
Future<bool> showCanonicalFoodItemDelete({
  required BuildContext context,
  required WidgetRef ref,
  required NutritionHistoricalReadRecord record,
  required NutritionHistoricalReadItem item,
}) async {
  final localDate = record.localDate.trim();
  final meal = record.mealCategory.trim().toLowerCase();
  if (localDate.isEmpty ||
      meal.isEmpty ||
      item.originSourceType != 'direct_food' ||
      item.foodId == null ||
      item.stableId.trim().isEmpty) {
    return false;
  }
  final label = item.displayLabel?.trim().isNotEmpty == true
      ? item.displayLabel!.trim()
      : 'this food';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: dialogContext.b05Colors.section,
      title: const Text('Delete this food?'),
      content: Text('Remove “$label” from your ${_mealLabel(meal)} totals?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: dialogContext.b05Colors.danger.container,
            foregroundColor: dialogContext.b05Colors.danger.foreground,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    final coordinator = await ref.read(
      nutritionFoodLoggingCoordinatorProvider.future,
    );
    final timezoneId = record is NutritionCanonicalSnapshotReadModel
        ? record.snapshot.timezoneId ??
              await ref.read(localTimezoneServiceProvider).currentTimezoneId()
        : await ref.read(localTimezoneServiceProvider).currentTimezoneId();
    await coordinator.correctDirectFoodItem(
      userId: kLocalNutritionUserScopeId,
      snapshotId: record.stableId,
      itemId: item.stableId,
      expectedMealCategory: meal,
      mealCategory: meal,
      localDate: localDate,
      timezoneId: timezoneId,
      loggedAtUtc: record.loggedAtUtc,
      commandId: 'food-delete-command::${record.stableId}::${item.stableId}',
      correctionReason: 'User deleted logged food.',
    );
    ref.read(todayNutritionRevisionProvider.notifier).state++;
    ref.invalidate(b04ProductionRecommendationContextProvider);
    ref.invalidate(b04CurrentFoodControllerProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$label deleted from ${_mealLabel(meal)}'),
        ),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Food could not be deleted. Refresh and try again.'),
        ),
      );
    }
    return false;
  }
}

String _mealLabel(String meal) => switch (meal) {
  'breakfast' => 'breakfast',
  'lunch' => 'lunch',
  'dinner' => 'dinner',
  'snack' || 'snacks' => 'snack',
  _ => 'meal',
};
