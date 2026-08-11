import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../dashboard/today_surface_controller.dart';

/// Consumer-facing delete flow for canonical B03 direct-food history.
///
/// The UI uses ordinary delete terminology while the repository preserves the
/// immutable record through its append-only retraction command.
Future<bool> showCanonicalFoodDelete({
  required BuildContext context,
  required WidgetRef ref,
  required NutritionHistoricalReadRecord record,
}) async {
  final localDate = record.localDate.trim();
  final meal = record.mealCategory.trim().toLowerCase();
  if (localDate.isEmpty || meal.isEmpty) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete this food?'),
      content: Text(
        'This will remove it from your ${_mealLabel(meal)} totals.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  try {
    final repository = await ref.read(
      nutritionConsumptionRepositoryProvider.future,
    );
    await repository.retractConsumption(
      userId: kLocalNutritionUserScopeId,
      snapshotId: record.stableId,
      expectedLocalDate: localDate,
      expectedMealCategory: meal,
      commandId: 'food-retraction-command::${const Uuid().v4()}',
    );
    ref.read(todayNutritionRevisionProvider.notifier).state++;
    ref.invalidate(b04ProductionRecommendationContextProvider);
    ref.invalidate(b04CurrentFoodControllerProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Food deleted from ${_mealLabel(meal)}'),
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
