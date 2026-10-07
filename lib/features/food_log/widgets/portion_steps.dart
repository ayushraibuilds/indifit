import '../../../core/typed_quantities.dart';

/// The portion stepper's next amount (audit C-05).
///
/// Steps are fixed, never a fraction of the current amount: ½ for servings,
/// pieces and household measures (¼ at or below 1), 10 g or 10 ml for mass
/// and volume (0.01 kg or L). The result snaps to that grid, so 1 katori
/// goes 1.5, 2 on + and 0.75 on −, and an odd typed amount like 1.3 moves
/// to 1.5 or 1. Returns null when − would reach zero.
Quantity? nextPortion(Quantity current, {required bool increase}) {
  final value = current.amount.asDouble;
  final step = _stepFor(current.unit, value, increase: increase);
  // Work in whole steps so binary fractions never leak into the amount.
  final steps = value / step;
  final whole = steps.roundToDouble();
  final onGrid = (steps - whole).abs() < 1e-9;
  final nextSteps = increase
      ? (onGrid ? whole + 1 : steps.ceilToDouble())
      : (onGrid ? whole - 1 : steps.floorToDouble());
  if (nextSteps <= 0) return null;
  final next = nextSteps * step;
  return Quantity(
    amount: QuantityAmount.fromString(_decimal(next)),
    unit: current.unit,
    context: current.context,
  );
}

double _stepFor(QuantityUnit unit, double value, {required bool increase}) {
  switch (unit) {
    case QuantityUnit.gram:
    case QuantityUnit.millilitre:
      return 10;
    case QuantityUnit.milligram:
      return 100;
    case QuantityUnit.kilogram:
    case QuantityUnit.litre:
      return 0.01;
    default:
      final small = increase ? value < 1 : value <= 1;
      return small ? 0.25 : 0.5;
  }
}

String _decimal(double value) {
  final fixed = value.toStringAsFixed(4);
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : fixed;
}
