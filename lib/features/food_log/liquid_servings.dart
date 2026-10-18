import '../../core/typed_quantities.dart';
import '../../data/catalog/katori_size.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';

/// One amount chip for a drink: "1 glass · 250 ml".
class LiquidServingChip {
  const LiquidServingChip(this.label, this.quantity);

  final String label;
  final Quantity quantity;
}

/// A standard cup of chai or coffee.
const double kStandardCupMillilitres = 150;

/// Amount chips for a liquid (UR-09): millilitres, a cup and a glass, never
/// grams or a katori. Null when [option] isn't a liquid.
///
/// A drink measured per 100 ml gets cup, glass (the person's own glass when
/// they've set one) and 100 ml. A drink counted in glasses or cups with no
/// known volume ("Toned Milk (1 Glass)") gets halves and doubles of its own
/// unit: nothing honest converts it to millilitres.
List<LiquidServingChip>? liquidServingChips(
  NutritionFoodOption option, {
  double? myGlassMillilitres,
}) {
  final measure = option.measure;
  final perMillilitre =
      option.baseQuantity.dimension == QuantityDimension.volume ||
      (measure?.isPerMillilitre ?? false);
  if (perMillilitre) {
    Quantity ml(num amount) =>
        Quantity.fromNum(amount: amount, unit: QuantityUnit.millilitre);
    final glass = myGlassMillilitres ?? kStandardGlassMillilitres;
    return [
      LiquidServingChip(
        '1 cup · ${kStandardCupMillilitres.round()} ml',
        ml(kStandardCupMillilitres),
      ),
      LiquidServingChip(
        '${myGlassMillilitres == null ? '1 glass' : 'My glass'} · '
        '${glass.round()} ml',
        ml(glass),
      ),
      LiquidServingChip('100 ml', ml(100)),
    ];
  }
  final unit = measure?.unit;
  if (unit != 'glass' && unit != 'cup') return null;
  final base = option.defaultLoggingQuantity;
  final perServing = measure?.unitsPerServing?.asDouble ?? 1;
  Quantity times(double factor) => Quantity.fromNum(
    amount: base.amount.asDouble * factor,
    unit: base.unit,
    context: base.context,
  );
  String count(double units) {
    final text = units == 0.5
        ? '½'
        : units % 1 == 0
        ? units.toInt().toString()
        : units.toString();
    return units > 1
        ? '$text $unit${unit == 'glass' ? 'es' : 's'}'
        : '$text $unit';
  }

  return [
    for (final factor in const [0.5, 1.0, 2.0])
      LiquidServingChip(count(perServing * factor), times(factor)),
  ];
}
