import '../../core/nutrition_thali.dart';
import '../../core/typed_quantities.dart';

/// Formats a saved-meal quantity without resolving it into another unit.
///
/// A saved meal is a reusable composition, so its displayed quantity must
/// remain the exact typed input that will be sent to the canonical calculator.
/// In particular, household references and servings are never turned into
/// grams merely for presentation.
String savedMealQuantityLabel(NutritionThaliItem item) {
  final quantity = item.quantity;
  if (quantity.unit == QuantityUnit.householdReference &&
      quantity.context.householdMeasure == null &&
      item.measureId != null) {
    return '${quantity.amount} ${QuantityFormatter.unitLabel(
      quantity.unit,
      amount: quantity.amount,
      householdMeasure: HouseholdMeasureReference(measureType: item.measureId!),
    )}';
  }
  return QuantityFormatter.format(quantity);
}

String savedMealItemKindLabel(NutritionThaliItem item) =>
    item.source == NutritionThaliItemSource.food ? 'Food' : 'Recipe';

String savedMealItemDisplayName(NutritionThaliItem item) =>
    item.displayLabel ??
    (item.source == NutritionThaliItemSource.food ? 'Food item' : 'Recipe');

String savedMealItemSemanticsLabel(NutritionThaliItem item) =>
    '${savedMealItemKindLabel(item)} ${savedMealItemDisplayName(item)}, '
    '${savedMealQuantityLabel(item)}';
