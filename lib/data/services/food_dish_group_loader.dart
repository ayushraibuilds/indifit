import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../repositories/nutrition_food_catalog_repository.dart';
import 'food_dish_groups.dart';

/// One choice in the portion sheet: a chip and the food it logs.
class FoodDishChoice {
  const FoodDishChoice({required this.chip, required this.option});

  final DishVariantChip chip;

  /// The exact food logged when this chip is chosen, so history, recents
  /// and repeat keep the variant.
  final NutritionFoodOption option;
}

/// A dish with its size and oil variants (UR-05, UF-4).
class FoodDishGroup {
  const FoodDishGroup({
    required this.base,
    required this.sizes,
    required this.oils,
  });

  /// The dish itself: Regular on the size row, Home on the oil row.
  final NutritionFoodOption base;

  /// Mini · Regular · Double · Jumbo, only those the dish has; empty when it
  /// has no size variant.
  final List<FoodDishChoice> sizes;

  /// Low oil · Home · Dhaba / extra ghee, likewise.
  final List<FoodDishChoice> oils;

  /// The chips that log [foodId]: on its own row, plus the other row's
  /// default (a variant changes one thing at a time).
  ({FoodDishChoice? size, FoodDishChoice? oil}) selectionFor(String foodId) {
    FoodDishChoice? find(List<FoodDishChoice> row) =>
        row.where((choice) => choice.option.id == foodId).firstOrNull;
    FoodDishChoice? baseOf(List<FoodDishChoice> row) =>
        row.where((choice) => choice.option.id == base.id).firstOrNull;
    final size = find(sizes);
    final oil = find(oils);
    return (size: size ?? baseOf(sizes), oil: oil ?? baseOf(oils));
  }
}

/// Reads a dish and its active, chip-labelled variants from the catalogue.
class FoodDishGroupLoader {
  FoodDishGroupLoader(this._db, this._catalog);

  final AppDatabase _db;
  final NutritionFoodCatalogRepository _catalog;

  /// The dish [foodId] belongs to, or null when it has no variant with a
  /// chip (most foods).
  Future<FoodDishGroup?> load(String foodId) async {
    final row = await (_db.select(
      _db.nutritionFoods,
    )..where((food) => food.id.equals(foodId))).getSingleOrNull();
    if (row == null) return null;
    final baseId = row.variantOfFoodId ?? row.id;
    final variants =
        await (_db.select(_db.nutritionFoods)
              ..where(
                (food) =>
                    food.variantOfFoodId.equals(baseId) &
                    food.lifecycle.equals('active'),
              )
              ..orderBy([(food) => OrderingTerm.asc(food.id)]))
            .get();
    if (variants.isEmpty) return null;
    final base = await _catalog.getOption(baseId);
    if (base == null) return null;

    final sizes = <FoodDishChoice>[];
    final oils = <FoodDishChoice>[];
    for (final variant in variants) {
      final label = FoodDishGroups.labelOf(
        variant.displayName,
        base.displayName,
      );
      final chip = label == null ? null : FoodDishGroups.chipFor(label);
      if (chip == null) continue;
      final row = chip.axis == DishVariantAxis.size ? sizes : oils;
      // Two labels can mean one chip ("Double", "Double serving"): the
      // first keeps it.
      if (row.any((choice) => choice.chip.label == chip.label)) continue;
      final option = await _catalog.getOption(variant.id);
      if (option != null) row.add(FoodDishChoice(chip: chip, option: option));
    }
    if (sizes.isEmpty && oils.isEmpty) return null;
    if (sizes.isNotEmpty) {
      sizes.add(FoodDishChoice(chip: FoodDishGroups.regular, option: base));
    }
    if (oils.isNotEmpty) {
      oils.add(FoodDishChoice(chip: FoodDishGroups.home, option: base));
    }
    int byOrder(FoodDishChoice a, FoodDishChoice b) =>
        a.chip.order.compareTo(b.chip.order);
    sizes.sort(byOrder);
    oils.sort(byOrder);
    return FoodDishGroup(base: base, sizes: sizes, oils: oils);
  }
}
