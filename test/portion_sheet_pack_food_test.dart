import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/data/catalog/catalog_pack_importer.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';

import 'support/real_catalogue.dart';

/// Opening the portion sheet for a bundled food reads its transformations
/// first. The catalogue pack stores plain serving conversions in the same
/// table, and reading them as transformations threw, so every tap on a
/// catalogue food showed "This food is unavailable" (smoke pass 2026-10-08).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RealCatalogue real;
  late NutritionTransformationRepository transformations;
  late NutritionFoodLoggingCoordinator coordinator;

  setUp(() async {
    real = await RealCatalogue.open();
    transformations = NutritionTransformationRepository(db: real.db);
    coordinator = NutritionFoodLoggingCoordinator(
      db: real.db,
      registry: real.registry,
      catalog: real.catalog,
      calculator: const NutritionCalculationService(),
      consumption: real.consumption,
      transformations: transformations,
    );
  });

  tearDown(() => real.close());

  test('the bundled pack stores serving conversions for roti', () async {
    final rotiId = await real.foodId('Whole Wheat Roti / Chapati');
    final packRows =
        await (real.db.select(real.db.nutritionQuantityConversions)..where(
              (row) =>
                  row.foodId.equals(rotiId) &
                  row.ruleVersion.equals(kCatalogPackConversionRule),
            ))
            .get();
    // Without these rows the tests below would pass on today's bug too.
    expect(packRows, isNotEmpty);
  });

  test('the portion sheet can read transformations for a pack food', () async {
    final rotiId = await real.foodId('Whole Wheat Roti / Chapati');
    final option = await real.catalog.getOption(rotiId);
    expect(option, isNotNull);

    final found = await coordinator.transformationsFor(option!);
    expect(found, isEmpty);

    final preview = await coordinator.preview(
      option: option,
      quantity: option.baseQuantity,
      transformation: null,
    );
    expect(preview, isNotNull);
  });

  test(
    'pack serving conversions are never returned as transformations',
    () async {
      final rotiId = await real.foodId('Whole Wheat Roti / Chapati');
      expect(
        await transformations.findForSource(sourceFoodId: rotiId),
        isEmpty,
      );
      expect(
        await transformations.getById('catalog-pack:$rotiId:serving:piece'),
        isNull,
      );
    },
  );

  test('every bundled food can open the portion sheet', () async {
    final foods = await real.db.select(real.db.nutritionFoods).get();
    final failures = <String>[];
    for (final food in foods) {
      try {
        await transformations.findForFood(sourceFoodId: food.id);
      } on Object catch (error) {
        failures.add('${food.displayName}: $error');
      }
    }
    expect(failures, isEmpty);
  });
}
