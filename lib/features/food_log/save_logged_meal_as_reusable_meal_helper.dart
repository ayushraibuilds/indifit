import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/nutrition_thali.dart' as thali;
import '../../core/theme/colors.dart';
import '../../core/typed_quantities.dart';

class SaveLoggedMealError implements Exception {
  final String code;
  final String message;

  const SaveLoggedMealError(this.code, this.message);

  @override
  String toString() => 'SaveLoggedMealError($code): $message';
}

class SaveLoggedMealHelper {
  /// Prompts the user with a dialog to name and save an existing logged meal
  /// as a reusable Saved Meal (`NutritionThaliDraft`).
  ///
  /// Only canonical snapshot items are eligible. Older entries do not always
  /// retain a portable food or recipe identity, so guessing from their display
  /// names would create a different reusable meal than the one the user logged.
  static Future<bool> saveLoggedMealAsReusable({
    required BuildContext context,
    required WidgetRef ref,
    required String mealCategory,
    required List<NutritionHistoricalReadItem> snapshotItems,
    int legacyItemCount = 0,
  }) async {
    if (snapshotItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logged items to save in this meal.')),
      );
      return false;
    }
    if (legacyItemCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This meal includes older entries that cannot be copied safely. Create a saved meal to choose those items again.',
          ),
        ),
      );
      return false;
    }

    late final List<thali.NutritionThaliItem> thaliItems;
    try {
      thaliItems = reusableComponentsFromSnapshotItems(snapshotItems);
    } on SaveLoggedMealError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.danger,
        ),
      );
      return false;
    }

    final defaultName =
        'My ${mealCategory.substring(0, 1).toUpperCase()}${mealCategory.substring(1)}';
    var enteredName = defaultName;

    final mealName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Reusable Meal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save this meal combination to quickly log it again in the future.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: defaultName,
              autofocus: true,
              onChanged: (value) => enteredName = value,
              decoration: const InputDecoration(
                labelText: 'Meal Name',
                hintText: 'e.g. Usual Lunch, Post-workout',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final trimmed = enteredName.trim();
              Navigator.pop(ctx, trimmed.isNotEmpty ? trimmed : defaultName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (mealName == null || mealName.trim().isEmpty) return false;

    try {
      final thaliRepo = await ref.read(nutritionThaliRepositoryProvider.future);
      final thaliId = 'thali::${const Uuid().v4()}';
      final now = DateTime.now().toUtc();

      final draft = thali.NutritionThaliDraft(
        id: thaliId,
        userId: kLocalNutritionUserScopeId,
        name: mealName.trim(),
        description: 'Created from logged $mealCategory',
        lifecycle: 'active',
        currentVersion: 1,
        createdAtUtc: now,
        updatedAtUtc: now,
        items: thaliItems,
      );

      await thaliRepo.saveDraft(draft);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "$mealName" as a reusable meal!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save meal. Please try again.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return false;
    }
  }

  /// Builds a reusable composition from frozen, typed snapshot inputs without
  /// resolving a display label back to a current catalogue record.
  static List<thali.NutritionThaliItem> reusableComponentsFromSnapshotItems(
    Iterable<NutritionHistoricalReadItem> snapshotItems,
  ) {
    final components = <thali.NutritionThaliItem>[];
    for (final item in snapshotItems) {
      final foodId = item.foodId?.trim();
      final recipeVersionId = item.recipeVersionId?.trim();
      final hasFood = foodId != null && foodId.isNotEmpty;
      final hasRecipe = recipeVersionId != null && recipeVersionId.isNotEmpty;
      final quantity = item.quantity.quantity;
      if (!item.quantity.isResolved || quantity == null) {
        throw const SaveLoggedMealError(
          'unresolved_logged_quantity',
          'One or more logged portions cannot be reused safely. Create a saved meal and choose those items again.',
        );
      }
      if (hasFood == hasRecipe) {
        throw const SaveLoggedMealError(
          'unresolved_logged_identity',
          'One or more logged items no longer have a reusable food or recipe reference. Create a saved meal and choose those items again.',
        );
      }
      final measureId = quantity.unit == QuantityUnit.householdReference
          ? quantity.context.householdMeasure?.measureType
          : null;
      if (quantity.unit == QuantityUnit.householdReference &&
          (measureId == null || measureId.trim().isEmpty)) {
        throw const SaveLoggedMealError(
          'unresolved_logged_measure',
          'One or more logged portions no longer have a reusable measure. Create a saved meal and choose those items again.',
        );
      }
      components.add(
        thali.NutritionThaliItem(
          id: 'thali-item::${const Uuid().v4()}',
          position: components.length,
          source: hasFood
              ? thali.NutritionThaliItemSource.food
              : thali.NutritionThaliItemSource.recipe,
          foodId: hasFood ? foodId : null,
          recipeVersionId: hasRecipe ? recipeVersionId : null,
          quantity: quantity,
          measureId: measureId,
          optional: false,
          notes: null,
          displayLabel: item.displayLabel,
        ),
      );
    }
    if (components.isEmpty) {
      throw const SaveLoggedMealError(
        'empty_logged_meal',
        'No reusable items were found in this meal.',
      );
    }
    return List.unmodifiable(components);
  }
}
