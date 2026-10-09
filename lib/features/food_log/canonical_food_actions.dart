import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import 'canonical_food_delete.dart';
import 'food_search_view_models.dart';
import 'widgets/food_portion_bottom_sheet.dart';

/// Edit / copy / delete chooser for one logged canonical food item.
///
/// The sheet is shown on the navigator that owns [context], so it always sits
/// over the screen the user tapped from. Actions are stacked full width: this
/// is a short action list, not an inline button row, so it does not use
/// [B05ActionGroup]'s wrap layout (which left the buttons hugging the left
/// edge on phones wider than the compact breakpoint).
Future<CanonicalFoodAction?> showCanonicalFoodActionSheet(
  BuildContext context,
) {
  return showModalBottomSheet<CanonicalFoodAction>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            B05ActionButton(
              label: 'Edit amount',
              icon: Icons.edit_outlined,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(CanonicalFoodAction.edit),
            ),
            const SizedBox(height: B05Layout.space8),
            B05ActionButton(
              label: 'Copy food',
              icon: Icons.copy_outlined,
              emphasis: B05ActionEmphasis.secondary,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(CanonicalFoodAction.copy),
            ),
            const SizedBox(height: B05Layout.space8),
            B05ActionButton(
              label: 'Delete food',
              icon: Icons.delete_outline_rounded,
              emphasis: B05ActionEmphasis.danger,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(CanonicalFoodAction.delete),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Runs the full edit / copy / delete flow for [item] in place, over the
/// screen that owns [context]. Used by the meal detail screen, which has no
/// search state of its own to log through.
Future<void> runCanonicalFoodItemActions({
  required BuildContext context,
  required WidgetRef ref,
  required NutritionHistoricalReadRecord record,
  required NutritionHistoricalReadItem item,
  required DateTime targetDate,
}) async {
  final foodId = item.foodId;
  if (item.originSourceType != 'direct_food' || foodId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This logged item cannot be edited from this screen.'),
      ),
    );
    return;
  }
  final catalog = await ref.read(nutritionFoodCatalogRepositoryProvider.future);
  final option = await catalog.getOption(foodId);
  if (option == null || !context.mounted) return;
  final action = await showCanonicalFoodActionSheet(context);
  if (!context.mounted) return;
  Future<String?> mealContext() async => record.mealCategory;
  switch (action) {
    case CanonicalFoodAction.edit:
      await FoodPortionBottomSheet.show(
        context,
        ref: ref,
        option: option,
        mealType: record.mealCategory,
        initialQuantity: item.quantity.quantity ?? option.baseQuantity,
        targetDate: targetDate,
        correctionRecord: record,
        correctionItem: item,
        ensureMealContext: mealContext,
      );
    case CanonicalFoodAction.copy:
      await FoodPortionBottomSheet.show(
        context,
        ref: ref,
        option: option,
        mealType: record.mealCategory,
        targetDate: targetDate,
        ensureMealContext: mealContext,
      );
    case CanonicalFoodAction.delete:
      await showCanonicalFoodItemDelete(
        context: context,
        ref: ref,
        record: record,
        item: item,
      );
    case null:
      break;
  }
}
