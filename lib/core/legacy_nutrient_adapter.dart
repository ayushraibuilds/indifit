import 'nutrients.dart';
import 'typed_quantities.dart';

/// Bounded, read-only compatibility adapter for the wide B01/B02 nutrient
/// columns. It deliberately accepts typed units and bases from the caller;
/// it never guesses from food names or mutates a database row.
class LegacyNutrientAdapter {
  LegacyNutrientAdapter._();

  static const String legacyFactVersion = 'legacy-v1';

  static NutrientFact adapt({
    required NutrientRegistry registry,
    required String nutrientId,
    required num? value,
    required NutrientUnit unit,
    required NutrientBasis basis,
    String? sourceReference,
  }) {
    final definition = registry.definitionFor(nutrientId);
    if (definition.unit != unit) {
      throw NutrientUnitMismatchError(
        '$nutrientId requires ${definition.unit.symbol}; legacy value supplied ${unit.symbol}.',
      );
    }
    if (value == null) {
      return NutrientFact.missing(
        nutrientId: nutrientId,
        unit: unit,
        basis: basis,
        source: NutrientSourceType.legacy,
        sourceReference: sourceReference,
        factVersion: legacyFactVersion,
      );
    }
    late final NutrientAmount amount;
    try {
      amount = NutrientAmount(value: QuantityAmount.fromNum(value), unit: unit);
    } on QuantityError catch (error) {
      throw NutrientValidationError(
        'Legacy nutrient value is invalid: ${error.message}',
      );
    }
    if (amount.value.isZero) {
      return NutrientFact.knownZero(
        nutrientId: nutrientId,
        unit: unit,
        basis: basis,
        source: NutrientSourceType.legacy,
        sourceReference: sourceReference,
        factVersion: legacyFactVersion,
      );
    }
    return NutrientFact.known(
      nutrientId: nutrientId,
      point: amount,
      basis: basis,
      source: NutrientSourceType.legacy,
      sourceReference: sourceReference,
      factVersion: legacyFactVersion,
    );
  }

  static Map<String, NutrientFact> adaptMacros({
    required NutrientRegistry registry,
    required num? calories,
    required num? proteinG,
    required num? carbohydrateG,
    required num? fatG,
    required num? fibreG,
    required NutrientBasis basis,
    String? sourceReference,
  }) => {
    'energy': adapt(
      registry: registry,
      nutrientId: 'energy',
      value: calories,
      unit: NutrientUnit.kilocalorie,
      basis: basis,
      sourceReference: sourceReference,
    ),
    'protein': adapt(
      registry: registry,
      nutrientId: 'protein',
      value: proteinG,
      unit: NutrientUnit.gram,
      basis: basis,
      sourceReference: sourceReference,
    ),
    'carbohydrate': adapt(
      registry: registry,
      nutrientId: 'carbohydrate',
      value: carbohydrateG,
      unit: NutrientUnit.gram,
      basis: basis,
      sourceReference: sourceReference,
    ),
    'fat': adapt(
      registry: registry,
      nutrientId: 'fat',
      value: fatG,
      unit: NutrientUnit.gram,
      basis: basis,
      sourceReference: sourceReference,
    ),
    'fibre': adapt(
      registry: registry,
      nutrientId: 'fibre',
      value: fibreG,
      unit: NutrientUnit.gram,
      basis: basis,
      sourceReference: sourceReference,
    ),
  };
}
