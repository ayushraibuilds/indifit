import '../../../core/typed_quantities.dart';
import '../../../data/catalog/catalogue_quantity_resolver.dart';

/// The unit a thali amount is counted in, in plain words: "piece",
/// "katori", "g", "serving". Never an internal measure id.
String thaliUnitLabel(Quantity quantity, {double? amount}) {
  final plural = amount != null && amount != 1;
  return switch (quantity.unit) {
    QuantityUnit.gram => 'g',
    QuantityUnit.milligram => 'mg',
    QuantityUnit.kilogram => 'kg',
    QuantityUnit.millilitre => 'ml',
    QuantityUnit.litre => 'L',
    QuantityUnit.piece => plural ? 'pieces' : 'piece',
    QuantityUnit.serving => plural ? 'servings' : 'serving',
    QuantityUnit.householdReference =>
      catalogueMeasureKey(quantity.context.householdMeasure?.measureType) ??
          'measure',
    _ => quantity.unit.name,
  };
}

/// "2 pieces", "1 katori", "150 g".
String thaliQuantityLabel(Quantity quantity) {
  final value = quantity.amount.asDouble;
  final amount = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : quantity.amount.format(decimalPlaces: 2);
  return '$amount ${thaliUnitLabel(quantity, amount: value)}';
}
