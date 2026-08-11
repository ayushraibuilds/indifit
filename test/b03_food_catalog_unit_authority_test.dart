import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late NutritionFoodCatalogRepository catalog;

  setUp(() {
    database = AppDatabase.memory();
    catalog = NutritionFoodCatalogRepository(
      db: database,
      registry: NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      ),
    );
  });

  tearDown(() => database.close());

  test(
    'abstract local servings stay honest and retain their source label',
    () async {
      for (final food in const [
        FoodItem(
          id: 101,
          name: 'Poha (Flattened Rice)',
          calories: 230,
          proteinG: 3.8,
          carbsG: 42,
          fatG: 5,
          servingSize: 1,
          servingUnit: 'katori',
          category: 'Breakfast',
          isCustom: false,
        ),
        FoodItem(
          id: 102,
          name: 'Basmati White Rice (Cooked)',
          calories: 130,
          proteinG: 2.7,
          carbsG: 28,
          fatG: 0.3,
          servingSize: 1,
          servingUnit: 'katori',
          category: 'Rice',
          isCustom: false,
        ),
        FoodItem(
          id: 103,
          name: 'Toned Milk',
          calories: 120,
          proteinG: 6.8,
          carbsG: 9.6,
          fatG: 6,
          servingSize: 1,
          servingUnit: 'glass',
          category: 'Drink',
          isCustom: false,
        ),
        FoodItem(
          id: 104,
          name: 'Whole Wheat Roti / Chapati',
          calories: 120,
          proteinG: 4,
          carbsG: 20,
          fatG: 2,
          servingSize: 1,
          servingUnit: 'piece',
          category: 'Bread',
          isCustom: false,
        ),
      ]) {
        final option = await catalog.ensureLegacyFood(food);
        expect(
          option.baseQuantity.unit,
          QuantityUnit.serving,
          reason: food.name,
        );
        expect(option.servingUnitLabel, food.servingUnit, reason: food.name);
        expect(
          option.facts['energy']!.basis.kind,
          NutrientBasisKind.perServing,
          reason: food.name,
        );
      }
    },
  );

  test(
    'legacy gram and volume metadata becomes canonical dimensional facts',
    () async {
      final mass = await catalog.ensureLegacyFood(
        const FoodItem(
          id: 201,
          name: 'Paneer cubes',
          calories: 300,
          proteinG: 24,
          carbsG: 6,
          fatG: 21,
          servingSize: 150,
          servingUnit: 'g',
          category: 'Protein',
          isCustom: false,
        ),
      );
      final volume = await catalog.ensureLegacyFood(
        const FoodItem(
          id: 202,
          name: 'Measured milk',
          calories: 150,
          proteinG: 7.5,
          carbsG: 12,
          fatG: 6,
          servingSize: 250,
          servingUnit: 'mL',
          category: 'Drink',
          isCustom: false,
        ),
      );

      expect(mass.baseQuantity.unit, QuantityUnit.gram);
      expect(mass.baseQuantity.amount.toString(), '100');
      expect(mass.facts['energy']!.basis.kind, NutrientBasisKind.per100Grams);
      expect(mass.facts['energy']!.point!.value.toString(), '200');
      expect(
        mass.facts['energy']!
            .scaleBy(
              Quantity.fromDecimal(amount: '0.2', unit: QuantityUnit.kilogram),
            )
            .point!
            .value
            .toString(),
        '400',
      );

      expect(volume.baseQuantity.unit, QuantityUnit.millilitre);
      expect(volume.baseQuantity.amount.toString(), '100');
      expect(
        volume.facts['energy']!.basis.kind,
        NutrientBasisKind.per100Millilitres,
      );
      expect(volume.facts['energy']!.point!.value.toString(), '60');
      expect(
        volume.facts['energy']!
            .scaleBy(
              Quantity.fromDecimal(amount: '0.5', unit: QuantityUnit.litre),
            )
            .point!
            .value
            .toString(),
        '300',
      );
    },
  );

  test(
    'existing serving adaptation is superseded when a mass basis appears',
    () async {
      const id = 301;
      await catalog.ensureLegacyFood(
        const FoodItem(
          id: id,
          name: 'Reviewed food',
          calories: 100,
          proteinG: 5,
          carbsG: 10,
          fatG: 4,
          servingSize: 1,
          servingUnit: 'serving',
          category: 'Fixture',
          isCustom: false,
        ),
      );
      final upgraded = await catalog.ensureLegacyFood(
        const FoodItem(
          id: id,
          name: 'Reviewed food',
          calories: 100,
          proteinG: 5,
          carbsG: 10,
          fatG: 4,
          servingSize: 100,
          servingUnit: 'g',
          category: 'Fixture',
          isCustom: false,
        ),
      );

      expect(upgraded.baseQuantity.unit, QuantityUnit.gram);
      final rows = await (database.select(
        database.nutritionFoodNutrientFacts,
      )..where((row) => row.foodId.equals(upgraded.id))).get();
      expect(rows.map((row) => row.factVersion).toSet(), {1, 2});
      expect(
        rows
            .where((row) => row.isCurrent)
            .every((row) => row.basis == 'per_100_grams'),
        isTrue,
      );
    },
  );

  test(
    'Open Food Facts values retain their documented per-100-gram basis',
    () async {
      final option = await catalog.ensureProviderFood(
        displayName: 'Protein shake',
        sourceReference: 'open-food-facts:fixture:protein-shake',
        servingSize: 330,
        servingUnit: 'g',
        energyKcal: 75,
        proteinG: 12,
        carbohydrateG: 5,
        fatG: 1,
      );

      expect(option.baseQuantity.unit, QuantityUnit.gram);
      expect(option.baseQuantity.amount.toString(), '100');
      expect(
        option.facts['protein']!.basis.kind,
        NutrientBasisKind.per100Grams,
      );
      expect(
        option.facts['protein']!
            .scaleBy(
              Quantity.fromDecimal(amount: '200', unit: QuantityUnit.gram),
            )
            .point!
            .value
            .toString(),
        '24',
      );
    },
  );
}
