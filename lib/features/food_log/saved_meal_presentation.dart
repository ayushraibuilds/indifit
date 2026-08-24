import '../../core/nutrition_thali.dart';
import '../../core/typed_quantities.dart';

/// Formats a saved-meal quantity without resolving it into another unit.
///
/// A saved meal is a reusable composition, so its displayed quantity must
/// remain the exact typed input that will be sent to the canonical calculator.
/// In particular, household references and servings are never turned into
/// grams merely for presentation.
String savedMealQuantityLabel(NutritionThaliItem item) {
  final amount = item.quantity.amount.toString();
  final unit = item.quantity.unit;
  final definition = QuantityUnitRegistry.definitionFor(unit);

  return switch (unit) {
    QuantityUnit.piece =>
      '$amount ${amount == '1' ? definition.symbol : 'pieces'}',
    QuantityUnit.serving =>
      '$amount ${amount == '1' ? definition.symbol : 'servings'}',
    QuantityUnit.householdReference =>
      '$amount ${item.quantity.context.householdMeasure?.measureType ?? item.measureId ?? definition.symbol}',
    _ => '$amount ${definition.symbol}',
  };
}

String savedMealItemKindLabel(NutritionThaliItem item) =>
    item.source == NutritionThaliItemSource.food ? 'Food' : 'Recipe';

String savedMealItemDisplayName(NutritionThaliItem item) =>
    item.displayLabel ??
    (item.source == NutritionThaliItemSource.food ? 'Food item' : 'Recipe');

String savedMealItemSemanticsLabel(NutritionThaliItem item) =>
    '${savedMealItemKindLabel(item)} ${savedMealItemDisplayName(item)}, '
    '${savedMealQuantityLabel(item)}';
