import 'package:drift/drift.dart';

import '../../core/typed_quantities.dart';
import '../database/app_database.dart';
import 'catalog_pack.dart';

class CatalogueQuantityError implements Exception {
  final String code;
  final String message;

  const CatalogueQuantityError(this.code, this.message);

  @override
  String toString() => 'CatalogueQuantityError($code): $message';
}

/// How one food is measured: the basis of its current facts and what one
/// serving is in household units and grams, from the installed pack.
class CatalogueFoodMeasure {
  final String foodId;
  final String displayName;

  /// `per_serving`, `per_100_grams` or `per_100_millilitres`.
  final String basis;

  /// The household unit one serving is counted in (`katori`, `piece`, …),
  /// or null for metric foods.
  final String? unit;

  /// How many [unit]s make one serving ("Boiled Eggs (2 pieces)": 2).
  final QuantityAmount? unitsPerServing;
  final QuantityAmount? gramsPerServing;
  final QuantityAmount? millilitresPerServing;

  const CatalogueFoodMeasure({
    required this.foodId,
    required this.displayName,
    required this.basis,
    required this.unit,
    required this.unitsPerServing,
    required this.gramsPerServing,
    required this.millilitresPerServing,
  });

  bool get isPerServing => basis == 'per_serving';
  bool get isPerMillilitre => basis == 'per_100_millilitres';

  /// Whether a gram amount can be logged for this food.
  bool get acceptsGrams =>
      basis == 'per_100_grams' || (isPerServing && gramsPerServing != null);

  /// One serving in this food's own unit: "2 pieces", "1 katori", "100 g".
  Quantity get defaultQuantity {
    final household = unit;
    final units = unitsPerServing;
    if (household != null && units != null) {
      return householdQuantity(household, units);
    }
    final grams = gramsPerServing;
    if (grams != null) return Quantity(amount: grams, unit: QuantityUnit.gram);
    final millilitres = millilitresPerServing;
    if (millilitres != null) {
      return Quantity(amount: millilitres, unit: QuantityUnit.millilitre);
    }
    return CatalogueServing.quantity(foodId, QuantityAmount.one);
  }

  /// [amount] of this food's household unit as a typed quantity. Pieces are
  /// counts; katori, glass and the other reviewed vessels are household
  /// references; anything else ("serving", "tiffin") is a food serving.
  Quantity householdQuantity(String household, QuantityAmount amount) {
    if (household == 'piece') {
      return Quantity(amount: amount, unit: QuantityUnit.piece);
    }
    if (kCatalogueVesselUnits.contains(household)) {
      return Quantity(
        amount: amount,
        unit: QuantityUnit.householdReference,
        context: QuantityContext(
          householdMeasure: HouseholdMeasureReference(
            measureType: catalogueMeasureId(household),
          ),
        ),
      );
    }
    final units = unitsPerServing;
    return CatalogueServing.quantity(
      foodId,
      units == null ? amount : amount.divide(units),
    );
  }

  /// [quantity] expressed in the basis of this food's facts, or a
  /// [CatalogueQuantityError] when it can't be converted honestly.
  Quantity toFactBasis(Quantity quantity) {
    switch (basis) {
      case 'per_100_grams':
        if (quantity.dimension == QuantityDimension.mass) return quantity;
        final grams = gramsPerServing;
        final servings = _servings(quantity);
        if (servings == null || grams == null) throw _unsupported(quantity);
        return Quantity(
          amount: servings.multiply(grams),
          unit: QuantityUnit.gram,
        );
      case 'per_100_millilitres':
        if (quantity.dimension == QuantityDimension.volume) return quantity;
        final millilitres = millilitresPerServing;
        final servings = _servings(quantity);
        if (servings == null || millilitres == null) {
          throw _unsupported(quantity);
        }
        return Quantity(
          amount: servings.multiply(millilitres),
          unit: QuantityUnit.millilitre,
        );
      default:
        final servings = _servings(quantity);
        if (servings == null) throw _unsupported(quantity);
        return CatalogueServing.quantity(foodId, servings);
    }
  }

  QuantityAmount? _servings(Quantity quantity) {
    if (quantity.unit == QuantityUnit.serving) {
      return quantity.context.servingDefinition ==
              CatalogueServing.reference(foodId)
          ? quantity.amount
          : null;
    }
    final units = unitsPerServing;
    final household = switch (quantity.unit) {
      QuantityUnit.piece => 'piece',
      QuantityUnit.householdReference => catalogueMeasureKey(
        quantity.context.householdMeasure?.measureType,
      ),
      _ => null,
    };
    if (household != null) {
      return household == unit && units != null
          ? quantity.amount.divide(units)
          : null;
    }
    final grams = gramsPerServing;
    if (quantity.dimension == QuantityDimension.mass && grams != null) {
      return quantity.convertTo(QuantityUnit.gram).amount.divide(grams);
    }
    return null;
  }

  CatalogueQuantityError _unsupported(Quantity quantity) {
    final own = unit ?? (gramsPerServing != null ? 'grams' : 'servings');
    return CatalogueQuantityError(
      'unsupported_food_unit',
      '$displayName is measured in ${own == 'piece' ? 'pieces' : own}. '
          'Change its amount to that unit.',
    );
  }
}

/// Household units that are reviewed vessels in
/// `NutritionStandardHouseholdMeasures`, so the thali can show them as such.
const Set<String> kCatalogueVesselUnits = {
  'katori',
  'bowl',
  'glass',
  'cup',
  'plate',
  'thali',
};

String catalogueMeasureId(String key) => 'household_measure_${key}_v1';

/// The household key inside a measure id (`household_measure_katori_v1` →
/// `katori`). Roti and chapati measures count pieces.
String? catalogueMeasureKey(String? measureId) {
  if (measureId == null) return null;
  final match = RegExp(r'^household_measure_(.+)_v\d+$').firstMatch(measureId);
  final key = match?.group(1) ?? measureId;
  return key == 'roti' || key == 'chapati' ? 'piece' : key;
}

/// Reads [CatalogueFoodMeasure]s from the canonical tables (CAT-4).
class CatalogueQuantityResolver {
  final AppDatabase _db;

  CatalogueQuantityResolver(this._db);

  /// The measure of [foodId], or null when it has no current facts (the
  /// calculation then reports its nutrition as unknown).
  Future<CatalogueFoodMeasure?> measureFor(String foodId) async {
    return (await measuresFor([foodId]))[foodId];
  }

  Future<Map<String, CatalogueFoodMeasure>> measuresFor(
    Iterable<String> foodIds,
  ) async {
    final ids = foodIds.toSet().toList(growable: false);
    if (ids.isEmpty) return const {};
    final foods = {
      for (final row in await (_db.select(
        _db.nutritionFoods,
      )..where((food) => food.id.isIn(ids))).get())
        row.id: row,
    };
    final bases = <String, String>{};
    for (final fact
        in await (_db.select(_db.nutritionFoodNutrientFacts)..where(
              (fact) =>
                  fact.foodId.isIn(ids) &
                  fact.nutrientId.equals('energy') &
                  fact.preparationId.isNull() &
                  fact.isCurrent.equals(true),
            ))
            .get()) {
      bases[fact.foodId] = fact.basis;
    }
    final conversions = <String, List<NutritionQuantityConversion>>{};
    for (final row
        in await (_db.select(_db.nutritionQuantityConversions)..where(
              (row) =>
                  row.foodId.isIn(ids) &
                  row.preparationId.isNull() &
                  row.sourceUnit.equals('serving'),
            ))
            .get()) {
      (conversions[row.foodId] ??= []).add(row);
    }
    final result = <String, CatalogueFoodMeasure>{};
    for (final id in ids) {
      final basis = bases[id];
      final food = foods[id];
      if (basis == null || food == null) continue;
      QuantityAmount? factor(String target) {
        final rows = conversions[id] ?? const [];
        // A user's own conversion (a calibrated katori) wins over the pack's.
        final row =
            rows
                .where((r) => r.targetUnit == target && r.ownerScope == 'user')
                .firstOrNull ??
            rows.where((r) => r.targetUnit == target).firstOrNull;
        return row == null ? null : QuantityAmount.fromNum(row.factor);
      }

      final household = (conversions[id] ?? const [])
          .map((row) => row.targetUnit)
          .where(
            (target) =>
                target != 'gram' && target != 'millilitre' && target != 'ml',
          )
          .firstOrNull;
      result[id] = CatalogueFoodMeasure(
        foodId: id,
        displayName: food.displayName,
        basis: basis,
        unit: household,
        unitsPerServing: household == null ? null : factor(household),
        gramsPerServing: factor('gram'),
        millilitresPerServing: factor('millilitre'),
      );
    }
    return result;
  }
}
