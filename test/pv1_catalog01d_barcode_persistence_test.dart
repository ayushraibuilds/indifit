import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
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

  group('PV1-CATALOG-01D: Custom food barcode persistence (P1-5)', () {
    test('created food embeds barcode and rescan resolves it', () async {
      final created = await catalog.createUserFood(
        displayName: 'Test Protein Bar',
        servingSize: 1,
        servingUnit: 'bar',
        energyKcal: 250,
        proteinG: 20,
        carbohydrateG: 22,
        fatG: 8,
        barcode: '8901030383704',
      );
      expect(created.sourceReference, contains('|barcode=8901030383704'));

      final found = await catalog.findUserFoodByBarcode('8901030383704');
      expect(found, isNotNull);
      expect(found!.id, created.id);
      expect(found.displayName, 'Test Protein Bar');
    });

    test('unknown barcode returns null', () async {
      await catalog.createUserFood(
        displayName: 'Test Protein Bar',
        servingSize: 1,
        servingUnit: 'bar',
        energyKcal: 250,
        proteinG: 20,
        carbohydrateG: 22,
        fatG: 8,
        barcode: '8901030383704',
      );

      expect(await catalog.findUserFoodByBarcode('9999999999999'), isNull);
    });

    test('short code does not collide with longer stored code', () async {
      await catalog.createUserFood(
        displayName: 'Long Code Food',
        servingSize: 1,
        servingUnit: 'pack',
        energyKcal: 100,
        proteinG: 2,
        carbohydrateG: 20,
        fatG: 1,
        barcode: '8901030383704',
      );

      // Prefix of the stored code must not match.
      expect(await catalog.findUserFoodByBarcode('8901030383'), isNull);
      expect(await catalog.findUserFoodByBarcode(' 8901030383704 '), isNotNull);
    });

    test('food created without barcode is invisible to barcode lookup', () async {
      await catalog.createUserFood(
        displayName: 'No Barcode Food',
        servingSize: 1,
        servingUnit: 'bowl',
        energyKcal: 100,
        proteinG: 2,
        carbohydrateG: 20,
        fatG: 1,
      );

      expect(await catalog.findUserFoodByBarcode('8901030383704'), isNull);
      expect(await catalog.findUserFoodByBarcode(''), isNull);
    });
  });
}
