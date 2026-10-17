import '../../../core/typed_quantities.dart';

/// The unit a thali amount is counted in, in plain words: "piece",
/// "katori", "g", "serving". Never an internal measure id.
String thaliUnitLabel(Quantity quantity, {double? amount}) =>
    QuantityFormatter.unitLabel(
      quantity.unit,
      amount: amount == null ? null : QuantityAmount.fromNum(amount),
      householdMeasure: quantity.context.householdMeasure,
    );

/// "2 pieces", "1 katori", "150 g".
String thaliQuantityLabel(Quantity quantity) {
  final value = quantity.amount.asDouble;
  final amount = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : quantity.amount.format(decimalPlaces: 2);
  return '$amount ${thaliUnitLabel(quantity, amount: value)}';
}
