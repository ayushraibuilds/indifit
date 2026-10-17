import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../dashboard/today_surface_controller.dart';
import 'canonical_food_delete.dart';
import 'food_log_surface.dart';
import 'food_search_view_models.dart';
import 'thali/thali_builder_screen.dart';
import 'widgets/food_portion_bottom_sheet.dart';
import 'widgets/quick_add_macros_sheet.dart';

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

/// What the sheet for a whole logged record offers.
enum LoggedRecordAction { edit, delete }

/// The one entry point for a tap on any logged food row (UR-51): a direct
/// food item gets Edit amount / Copy / Delete; every other record (thali,
/// recipe, quick add, AI estimate) gets Edit / Delete. Delete always has the
/// same 5-second Undo as a swipe.
Future<void> runLoggedRecordActions({
  required BuildContext context,
  required WidgetRef ref,
  required NutritionHistoricalReadRecord record,
  NutritionHistoricalReadItem? item,
  required DateTime targetDate,
}) async {
  final direct =
      item ??
      (record.items.length == 1 &&
              record.items.single.originSourceType == 'direct_food' &&
              record.items.single.foodId != null
          ? record.items.single
          : null);
  if (direct != null && direct.originSourceType == 'direct_food') {
    return runCanonicalFoodItemActions(
      context: context,
      ref: ref,
      record: record,
      item: direct,
      targetDate: targetDate,
    );
  }
  final snapshot = record is NutritionCanonicalSnapshotReadModel
      ? record.snapshot
      : null;
  final label = record.displayLabel.trim().isEmpty
      ? 'This entry'
      : record.displayLabel.trim();
  final action = await showModalBottomSheet<LoggedRecordAction>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snapshot != null)
              B05ActionButton(
                label: _editLabel(snapshot.sourceType),
                icon: Icons.edit_outlined,
                onPressed: () =>
                    Navigator.of(sheetContext).pop(LoggedRecordAction.edit),
              ),
            const SizedBox(height: B05Layout.space8),
            B05ActionButton(
              label: 'Delete entry',
              icon: Icons.delete_outline_rounded,
              emphasis: B05ActionEmphasis.danger,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(LoggedRecordAction.delete),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case LoggedRecordAction.edit:
      if (snapshot != null) {
        await _editRecord(context, ref, snapshot, label, targetDate);
      }
    case LoggedRecordAction.delete:
      deleteLoggedRecordWithUndo(
        context: context,
        record: record,
        label: label,
        date: targetDate,
      );
    case null:
      break;
  }
}

String _editLabel(String sourceType) => switch (sourceType) {
  'thali' || 'recipe' => 'Edit items',
  _ => 'Edit entry',
};

/// Reopens the flow the record came from, pre-filled; logging there replaces
/// the original record.
Future<void> _editRecord(
  BuildContext context,
  WidgetRef ref,
  NutritionConsumptionSnapshot snapshot,
  String label,
  DateTime targetDate,
) async {
  switch (snapshot.sourceType) {
    case 'thali' || 'recipe':
      await Navigator.of(context).push<NutritionConsumptionSnapshot>(
        MaterialPageRoute(
          builder: (_) => ThaliBuilderScreen(
            mealCategory: snapshot.mealCategory,
            initialThaliId: snapshot.thaliId,
            selectedDate: targetDate,
            replacesSnapshot: snapshot,
          ),
        ),
      );
    default:
      final energy = snapshot.totals.facts['energy']?.point?.value.asDouble;
      await QuickAddMacrosSheet.show(
        context,
        initialMealType: snapshot.mealCategory,
        targetDate: targetDate,
        initialDescription: label,
        initialCalories: energy,
        replacesSnapshot: snapshot,
      );
  }
}

/// Retracts the record an edit replaced, once its replacement is logged.
Future<void> retractReplacedRecord(
  WidgetRef ref,
  NutritionConsumptionSnapshot replaced,
) async {
  final repository = await ref.read(
    nutritionConsumptionRepositoryProvider.future,
  );
  await repository.retractConsumption(
    userId: kLocalNutritionUserScopeId,
    snapshotId: replaced.id,
    expectedLocalDate: replaced.localDate ?? '',
    expectedMealCategory: replaced.mealCategory,
    commandId: 'record-edit-replace::${replaced.id}',
  );
  ref.read(todayNutritionRevisionProvider.notifier).state++;
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
