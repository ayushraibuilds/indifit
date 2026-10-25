import '../../core/presentation/consumer_number_label.dart';
import '../../core/typed_quantities.dart';
import '../../data/repositories/nutrition_recipe_log_coordinator.dart';
import '../../data/repositories/nutrition_recipe_repository.dart';

/// How a recipe's pot is counted (UF-8).
enum RecipePotUnit {
  katori('katori'),
  servings('servings'),
  grams('g');

  const RecipePotUnit(this.label);

  final String label;
}

/// "This pot makes 6 katori": what the whole recipe cooks into. Eating part
/// of it logs the recipe's total facts × (amount eaten ÷ pot yield).
///
/// Katori and servings are the recipe's declared servings (a katori is one
/// serving counted in katoris); total grams is the recipe's yield.
class RecipePotYield {
  const RecipePotYield(this.unit, this.amount);

  final RecipePotUnit unit;
  final QuantityAmount amount;

  /// The pot of [version], or null when it has no yield (older recipes
  /// keep only "Whole recipe", "Fraction" and "Scale").
  static RecipePotYield? of(NutritionRecipeVersionModel version) {
    final yieldQuantity = version.yieldQuantity;
    if (yieldQuantity != null &&
        yieldQuantity.unit == QuantityUnit.gram &&
        !yieldQuantity.amount.isZero) {
      return RecipePotYield(RecipePotUnit.grams, yieldQuantity.amount);
    }
    final serving = version.servingDefinition;
    if (serving == null || serving.count.isZero) return null;
    return RecipePotYield(
      serving.unit == RecipePotUnit.katori.label
          ? RecipePotUnit.katori
          : RecipePotUnit.servings,
      serving.count,
    );
  }

  /// The share of the pot that [eaten] is, as the amount to log.
  NutritionRecipeLogAmount logAmount(QuantityAmount eaten) =>
      NutritionRecipeLogAmount.fraction(eaten.divide(amount));

  /// "6 katori", "4 servings", "900 g".
  String get label => amountLabel(amount);

  /// [value] in this pot's unit: "1½ katori", "1 serving", "250 g".
  String amountLabel(QuantityAmount value) {
    final number = potNumberLabel(value);
    return switch (unit) {
      RecipePotUnit.katori => '$number katori',
      RecipePotUnit.servings =>
        '$number serving${value.compareTo(QuantityAmount.one) == 0 ? '' : 's'}',
      RecipePotUnit.grams => '$number g',
    };
  }
}

/// "1½", "2", "0.3": halves and quarters read as people say them.
String potNumberLabel(QuantityAmount value) {
  final asDouble = value.asDouble;
  final whole = asDouble.floor();
  final rest = asDouble - whole;
  const fractions = [(0.25, '¼'), (0.5, '½'), (0.75, '¾')];
  for (final (share, glyph) in fractions) {
    if ((rest - share).abs() < 1e-9) return whole == 0 ? glyph : '$whole$glyph';
  }
  if (rest.abs() < 1e-9) return '$whole';
  return ConsumerNumberLabel.grams(asDouble).replaceAll(' g', '');
}

/// "1½", "1 1/2", "1.5", "½" or "3/4" as an amount; null when it isn't one
/// or isn't above zero.
QuantityAmount? parsePotAmount(String input) {
  var text = input.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  const glyphs = {'½': '1/2', '¼': '1/4', '¾': '3/4', '⅓': '1/3', '⅔': '2/3'};
  for (final MapEntry(key: glyph, value: fraction) in glyphs.entries) {
    text = text.replaceAll(glyph, ' $fraction');
  }
  final parts = text.trim().split(RegExp(r'\s+'));
  try {
    var total = QuantityAmount.zero;
    for (final part in parts) {
      final slash = part.split('/');
      if (slash.length == 2) {
        total =
            total +
            QuantityAmount.fromString(
              slash[0],
            ).divide(QuantityAmount.fromString(slash[1]));
      } else if (slash.length == 1) {
        total = total + QuantityAmount.fromString(part);
      } else {
        return null;
      }
    }
    return total.isZero ? null : total;
  } on Object {
    return null;
  }
}

/// The sum behind a pot portion: "Whole pot × 1½ ÷ 6 katori = 300 kcal".
/// The kcal is the preview's, once there is one.
String recipePotSum(RecipePotYield pot, QuantityAmount? eaten, {double? kcal}) {
  if (eaten == null) return 'Enter how much you ate.';
  final sum = 'Whole pot × ${potNumberLabel(eaten)} ÷ ${pot.label}';
  return kcal == null
      ? sum
      : '$sum = ${ConsumerNumberLabel.rounded(kcal)} kcal';
}
