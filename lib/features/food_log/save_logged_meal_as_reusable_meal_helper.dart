import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/nutrition_thali.dart' as thali;
import '../../core/theme/colors.dart';
import '../../core/typed_quantities.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';

class SaveLoggedMealHelper {
  /// Prompts the user with a dialog to name and save an existing logged meal
  /// as a reusable Saved Meal (`NutritionThaliDraft`).
  static Future<bool> saveLoggedMealAsReusable({
    required BuildContext context,
    required WidgetRef ref,
    required String mealCategory,
    required List<FoodLog> legacyFoodLogs,
    List<NutritionHistoricalReadItem>? snapshotItems,
  }) async {
    if (legacyFoodLogs.isEmpty &&
        (snapshotItems == null || snapshotItems.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logged items to save in this meal.')),
      );
      return false;
    }

    final defaultName =
        'My ${mealCategory.substring(0, 1).toUpperCase()}${mealCategory.substring(1)}';
    final nameController = TextEditingController(text: defaultName);

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
            TextField(
              controller: nameController,
              autofocus: true,
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
              final trimmed = nameController.text.trim();
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
      final catalogRepo = await ref.read(
        nutritionFoodCatalogRepositoryProvider.future,
      );
      final legacyFoodRepo = ref.read(foodRepositoryProvider);

      // Convert logged items to NutritionThaliItem components
      final thaliId = 'thali::${const Uuid().v4()}';
      final thaliItems = <thali.NutritionThaliItem>[];
      var position = 0;

      for (final log in legacyFoodLogs) {
        // Resolve food option or custom food by name
        final searchResults = await catalogRepo.search(query: log.name);
        final matchedOption = searchResults.isNotEmpty
            ? searchResults.first
            : null;

        Quantity quantity;
        if (matchedOption != null) {
          quantity = Quantity(
            amount: QuantityAmount.fromNum(log.servingLogged),
            unit: matchedOption.baseQuantity.unit,
            context: matchedOption.baseQuantity.context,
          );
        } else {
          quantity = Quantity.serving(
            amount: log.servingLogged.toString(),
            definition: ServingDefinitionReference(
              id: 'serving-def::${const Uuid().v4()}',
              revision: '1',
              source: 'logged_history',
            ),
            source: 'logged_history',
          );
        }

        thaliItems.add(
          thali.NutritionThaliItem(
            id: 'thali-item::${const Uuid().v4()}',
            position: position++,
            source: thali.NutritionThaliItemSource.food,
            foodId: matchedOption?.id,
            recipeVersionId: null,
            quantity: quantity,
            measureId: null,
            optional: false,
            notes: null,
            displayLabel: log.name,
          ),
        );
      }

      final draft = thali.NutritionThaliDraft(
        id: thaliId,
        userId: kLocalNutritionUserScopeId,
        name: mealName.trim(),
        description: 'Created from logged $mealCategory',
        lifecycle: 'active',
        currentVersion: 1,
        createdAtUtc: DateTime.now().toUtc(),
        updatedAtUtc: DateTime.now().toUtc(),
        items: thaliItems,
      );

      // Save canonical thali draft
      await thaliRepo.saveDraft(draft);

      // Also save to legacy food repository for dual-stack compatibility
      try {
        await legacyFoodRepo.saveMealTemplate(
          name: mealName.trim(),
          defaultMealType: mealCategory,
          items: legacyFoodLogs,
        );
      } catch (_) {}

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
}
