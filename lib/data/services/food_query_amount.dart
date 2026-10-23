import '../../core/typed_quantities.dart';
import '../repositories/nutrition_food_catalog_repository.dart';

/// An amount typed with a food search: "3" in "3 roti", "1 plate" in
/// "chawal 1 plate", "200 ml" in "200 ml milk" (UR-01, UR-02).
class FoodQueryAmount {
  const FoodQueryAmount(this.amount, [this.unit]);

  final double amount;

  /// `g`, `ml`, `katori`, `plate`, `piece`, … or null for a bare number,
  /// which counts the food in its own unit.
  final String? unit;

  /// "3 pieces", "1 plate", "200 ml". A bare number takes [servingUnit],
  /// the food's own unit, when it is a count.
  String label({String? servingUnit}) {
    final value = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toString();
    final own = unit ?? _countUnit(servingUnit) ?? 'serving';
    return QuantityFormatter.formatStored(value, own);
  }

  static String? _countUnit(String? servingUnit) {
    final unit = servingUnit?.trim().toLowerCase();
    if (unit == null || unit.isEmpty) return null;
    return const {'g', 'gm', 'gram', 'grams', 'ml', 'kg', 'l'}.contains(unit)
        ? null
        : unit;
  }

  /// This amount as a quantity [option] can be logged in, already in the
  /// basis of its facts; null when it doesn't fit the food (a plate of a
  /// food counted in pieces).
  Quantity? quantityFor(NutritionFoodOption option) {
    final measure = option.measure;
    final value = QuantityAmount.fromNum(amount);
    final Quantity typed;
    switch (unit) {
      case 'g' || 'kg':
        typed = Quantity(
          amount: unit == 'kg'
              ? value.multiply(QuantityAmount.fromNum(1000))
              : value,
          unit: QuantityUnit.gram,
        );
      case 'ml' || 'l':
        typed = Quantity(
          amount: unit == 'l'
              ? value.multiply(QuantityAmount.fromNum(1000))
              : value,
          unit: QuantityUnit.millilitre,
        );
      case 'serving':
        typed = _servings(option, value);
      case null:
        final own = measure?.unit;
        typed = own != null
            ? measure!.householdQuantity(own, value)
            : option.baseQuantity.unit == QuantityUnit.piece
            ? Quantity(amount: value, unit: QuantityUnit.piece)
            : _servings(option, value);
      case final household:
        final own = measure?.unit;
        if (own != null && (own == household || _sameCount(own, household))) {
          typed = measure!.householdQuantity(own, value);
        } else if (_servingLabelNames(option, household)) {
          typed = _servings(option, value);
        } else {
          return null;
        }
    }
    try {
      if (measure != null) return measure.toFactBasis(typed);
      final base = option.baseQuantity;
      if (typed.unit == base.unit) return typed;
      if (typed.dimension == base.dimension &&
          typed.dimension != QuantityDimension.unknown) {
        return typed.convertTo(base.unit);
      }
    } on Object {
      return null;
    }
    return null;
  }

  static bool _sameCount(String own, String typed) =>
      own == 'piece' && const {'slice', 'roti', 'idli'}.contains(typed);

  static bool _servingLabelNames(NutritionFoodOption option, String unit) =>
      option.baseQuantity.unit == QuantityUnit.serving &&
      (option.servingUnitLabel?.toLowerCase().contains(unit) ?? false);

  static Quantity _servings(NutritionFoodOption option, QuantityAmount value) {
    final base = option.baseQuantity;
    return base.unit == QuantityUnit.serving
        ? Quantity(
            amount: value.multiply(base.amount),
            unit: QuantityUnit.serving,
            context: base.context,
          )
        : Quantity(amount: value, unit: QuantityUnit.serving);
  }
}

/// A search typed as words: the food to look for and any amount with it.
class ParsedFoodQuery {
  const ParsedFoodQuery({
    required this.original,
    required this.food,
    this.amount,
    this.bareNumber = false,
  });

  final String original;

  /// The words to search for, without the amount.
  final String food;
  final FoodQueryAmount? amount;

  /// The amount was a lone number before the food ("3 roti"). It may be
  /// part of the name instead ("7 up", "5 star"), so the search checks.
  final bool bareNumber;
}

/// Splits an amount from a food search (UR-01).
class FoodQueryParser {
  FoodQueryParser._();

  static const _number =
      r'(\d+(?:\.\d+)?(?:\s*/\s*\d+)?|half|quarter|one|two|three|four|five|'
      r'six|seven|eight|nine|ten)';
  static const _unit =
      r'(bowls?|katoris?|cups?|glass(?:es)?|plates?|pieces?|pcs?|slices?|'
      r'spoons?|tbsp|tsp|servings?|scoops?|handfuls?|bottles?|packets?|'
      r'ladles?|gms?|grams?|g|kgs?|kilograms?|ml|millilit(?:re|er)s?|'
      r'lit(?:re|er)s?|l)';

  static final RegExp _leading = RegExp(
    '^$_number\\s*$_unit\\b\\s*(?:of\\s+)?',
    caseSensitive: false,
  );
  static final RegExp _trailing = RegExp(
    '\\s+$_number\\s*$_unit\\s*\$',
    caseSensitive: false,
  );
  static final RegExp _bare = RegExp(
    '^$_number\\s+(?=[^\\d\\s])',
    caseSensitive: false,
  );

  static final RegExp _bareTrailing = RegExp(r'^(.*[^\d\s])\s+(\d{1,2})$');

  static ParsedFoodQuery parse(String query) {
    final text = query.trim();
    for (final pattern in [_leading, _trailing]) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final rest = text.replaceRange(match.start, match.end, ' ').trim();
      // "2 cups" alone names no food: search it as typed.
      if (rest.isEmpty) return ParsedFoodQuery(original: text, food: text);
      return ParsedFoodQuery(
        original: text,
        food: rest,
        amount: FoodQueryAmount(
          _amount(match.group(1)!),
          _unitKey(match.group(2)!),
        ),
      );
    }
    final bare = _bare.firstMatch(text);
    if (bare != null) {
      return ParsedFoodQuery(
        original: text,
        food: text.substring(bare.end).trim(),
        amount: FoodQueryAmount(_amount(bare.group(1)!)),
        bareNumber: true,
      );
    }
    // "roti 2": a small count after the food. Bigger numbers name the dish
    // ("chicken 65"), so they stay in the search.
    final trailing = _bareTrailing.firstMatch(text);
    if (trailing != null && int.parse(trailing.group(2)!) <= 12) {
      return ParsedFoodQuery(
        original: text,
        food: trailing.group(1)!.trim(),
        amount: FoodQueryAmount(double.parse(trailing.group(2)!)),
        bareNumber: true,
      );
    }
    return ParsedFoodQuery(original: text, food: text);
  }

  static double _amount(String raw) {
    final text = raw.toLowerCase().replaceAll(' ', '');
    const words = {
      'half': 0.5,
      'quarter': 0.25,
      'one': 1.0,
      'two': 2.0,
      'three': 3.0,
      'four': 4.0,
      'five': 5.0,
      'six': 6.0,
      'seven': 7.0,
      'eight': 8.0,
      'nine': 9.0,
      'ten': 10.0,
    };
    final word = words[text];
    if (word != null) return word;
    if (text.contains('/')) {
      final parts = text.split('/');
      final top = double.parse(parts[0]);
      final bottom = double.parse(parts[1]);
      return bottom == 0 ? top : top / bottom;
    }
    return double.parse(text);
  }

  static String _unitKey(String raw) {
    final unit = raw.toLowerCase();
    if (RegExp(r'^(g|gms?|grams?)$').hasMatch(unit)) return 'g';
    if (RegExp(r'^(kgs?|kilograms?)$').hasMatch(unit)) return 'kg';
    if (RegExp(r'^(ml|millilit(re|er)s?)$').hasMatch(unit)) return 'ml';
    if (RegExp(r'^(l|lit(re|er)s?)$').hasMatch(unit)) return 'l';
    if (RegExp(r'^(pieces?|pcs?)$').hasMatch(unit)) return 'piece';
    if (unit == 'glass' || unit == 'glasses') return 'glass';
    if (unit == 'tbsp' || unit == 'tsp') return unit;
    if (unit == 'katoris') return 'katori';
    return unit.endsWith('s') ? unit.substring(0, unit.length - 1) : unit;
  }
}
