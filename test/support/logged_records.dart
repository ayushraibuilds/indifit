import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot, NutritionThaliItem;
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:indifit/features/food_log/repeat_meal.dart';

import 'real_catalogue.dart';

const loggedRecordsTimezone = 'Asia/Kolkata';
const loggedRecordsDate = '2026-10-08';
const loggedRecordsRoti = 'Whole Wheat Roti / Chapati';
const loggedRecordsDal = 'Toor Dal / Yellow Dal Tadka';

Quantity katori(num amount) => Quantity(
  amount: QuantityAmount.fromNum(amount),
  unit: QuantityUnit.householdReference,
  context: const QuantityContext(
    householdMeasure: HouseholdMeasureReference(
      measureType: 'household_measure_katori_v1',
    ),
  ),
);

/// One logged record of every source type the meal page can show (UR-10,
/// UR-11): a household-unit direct food, a quick add, a thali, a recipe and
/// an AI estimate, all in one meal on [loggedRecordsDate].
class LoggedRecords {
  final RealCatalogue catalogue;
  final NutritionFoodLoggingCoordinator foods;
  final Map<String, NutritionConsumptionSnapshot> bySource;

  LoggedRecords._(this.catalogue, this.foods, this.bySource);

  static NutritionFoodLoggingCoordinator coordinatorFor(RealCatalogue c) =>
      NutritionFoodLoggingCoordinator(
        db: c.db,
        registry: c.registry,
        catalog: c.catalog,
        calculator: const NutritionCalculationService(),
        consumption: c.consumption,
        transformations: NutritionTransformationRepository(db: c.db),
      );

  static Future<LoggedRecords> log(
    RealCatalogue c, {
    String meal = 'lunch',
    Set<String> only = const {},
  }) async {
    final foods = coordinatorFor(c);
    final roti = await c.foodId(loggedRecordsRoti);
    final dal = await c.foodId(loggedRecordsDal);
    final loggedAt = DateTime.utc(2026, 10, 8, 7);
    final bySource = <String, NutritionConsumptionSnapshot>{};
    bool wants(String source) => only.isEmpty || only.contains(source);

    if (wants('direct_food')) {
      final option = (await c.catalog.getOption(dal))!;
      bySource['direct_food'] = await foods.finalize(
        userId: kLocalNutritionUserScopeId,
        preview: await foods.preview(
          option: option,
          quantity: option.defaultLoggingQuantity,
        ),
        mealCategory: meal,
        loggedAt: loggedAt,
        localDate: loggedRecordsDate,
        timezoneId: loggedRecordsTimezone,
        commandId: 'fixture-direct',
        consumptionId: 'fixture-direct',
      );
    }

    if (wants('thali')) {
      final draft = await c.thali.saveDraft(
        c.thali.newDraft(
          userId: kLocalNutritionUserScopeId,
          name: 'Weekday thali',
          items: [
            NutritionThaliItem(
              id: 'fixture-thali-roti',
              position: 0,
              source: NutritionThaliItemSource.food,
              foodId: roti,
              recipeVersionId: null,
              quantity: Quantity.fromNum(amount: 2, unit: QuantityUnit.piece),
            ),
            NutritionThaliItem(
              id: 'fixture-thali-dal',
              position: 1,
              source: NutritionThaliItemSource.food,
              foodId: dal,
              recipeVersionId: null,
              quantity: katori(1),
              measureId: 'household_measure_katori_v1',
            ),
          ],
        ),
      );
      bySource['thali'] = await c.thali.finalize(
        preview: await c.thali.preview(draft: draft),
        mealCategory: meal,
        loggedAt: loggedAt,
        commandId: 'fixture-thali',
        localDate: loggedRecordsDate,
        timezoneId: loggedRecordsTimezone,
        allowPartial: true,
      );
    }

    if (wants('recipe')) {
      final draft = await c.recipes.createRecipe(
        userId: kLocalNutritionUserScopeId,
        recipeId: 'fixture-recipe',
        versionId: 'fixture-recipe-v1',
        name: 'Home dal',
        ingredients: [
          NutritionRecipeIngredientInput.directFood(
            id: 'fixture-recipe-line',
            foodId: await _per100g(c, 'fixture-moong', 'Moong dal', 116),
            quantity: Quantity.fromNum(amount: 300, unit: QuantityUnit.gram),
            position: 0,
          ),
        ],
        yieldQuantity: Quantity.fromNum(amount: 300, unit: QuantityUnit.gram),
      );
      await c.recipes.publishDraft(
        recipeId: 'fixture-recipe',
        draftVersionId: draft.version.id,
      );
      bySource['recipe'] = await c.recipeLogging.finalize(
        userId: kLocalNutritionUserScopeId,
        preview: await c.recipeLogging.preview(
          userId: kLocalNutritionUserScopeId,
          recipeId: 'fixture-recipe',
          amount: NutritionRecipeLogAmount.wholeRecipe(),
        ),
        mealCategory: meal,
        loggedAt: loggedAt,
        localDate: loggedRecordsDate,
        timezoneId: loggedRecordsTimezone,
        commandId: 'fixture-recipe',
        allowPartial: true,
      );
    }

    for (final (source, label) in [
      ('quick_add', 'Office samosa'),
      ('estimate', 'Rajma chawal'),
    ]) {
      if (!wants(source)) continue;
      bySource[source] = await _absolute(c, source, label, meal, loggedAt);
    }
    if (wants('repeat') && bySource['thali'] != null) {
      final outcome = await logRepeatPlan(
        plan: planRepeat([
          NutritionCanonicalSnapshotReadModel(bySource['thali']!),
        ]),
        foods: foods,
        catalog: c.catalog,
        thalis: c.thali,
        recipes: c.recipeLogging,
        userId: kLocalNutritionUserScopeId,
        mealCategory: 'dinner',
        loggedAtUtc: DateTime.utc(2026, 10, 8, 14),
        localDate: loggedRecordsDate,
        timezoneId: loggedRecordsTimezone,
      );
      expect(outcome.thalis, 1);
      final dinner = (await c.consumption.listAllForUser(
        userId: kLocalNutritionUserScopeId,
      )).where((snapshot) => snapshot.mealCategory == 'dinner');
      bySource['repeat'] = dinner.single;
    }
    return LoggedRecords._(c, foods, bySource);
  }

  static Future<String> _per100g(
    RealCatalogue c,
    String id,
    String name,
    double kcal,
  ) async {
    await c.db
        .into(c.db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: id,
            kind: 'canonical',
            displayName: name,
            locale: 'en-IN',
            sourceType: 'fixture',
            lifecycle: 'active',
          ),
        );
    await c.db
        .into(c.db.nutritionFoodNutrientFacts)
        .insert(
          NutritionFoodNutrientFactsCompanion.insert(
            id: '$id-energy',
            foodId: id,
            nutrientId: 'energy',
            status: 'known',
            source: 'reviewed_catalogue',
            factVersion: 1,
            basis: 'per_100_grams',
            basisQuantity: const Value(100),
            basisUnit: const Value('gram'),
            amount: Value(kcal),
            isCurrent: const Value(true),
          ),
        );
    return id;
  }

  /// A record whose energy the user (quick add) or the AI (estimate) gave.
  static Future<NutritionConsumptionSnapshot> _absolute(
    RealCatalogue c,
    String source,
    String label,
    String meal,
    DateTime loggedAt,
  ) async {
    final foodId = 'food::fixture::$source';
    await c.db
        .into(c.db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: foodId,
            kind: 'userCreated',
            displayName: label,
            locale: 'en-IN',
            sourceType: 'user',
            lifecycle: 'active',
          ),
        );
    final facts = <String, NutrientFact>{
      for (final definition in c.registry.definitions)
        definition.id: definition.id == 'energy'
            ? NutrientFact.known(
                nutrientId: 'energy',
                point: NutrientAmount(
                  value: QuantityAmount.fromNum(250),
                  unit: NutrientUnit.kilocalorie,
                ),
                basis: NutrientBasis(NutrientBasisKind.absolute),
                source: NutrientSourceType.userEntered,
                sourceReference: source,
                factVersion: '1',
              )
            : NutrientFact.missing(
                nutrientId: definition.id,
                unit: definition.unit,
                basis: NutrientBasis(NutrientBasisKind.absolute),
                source: NutrientSourceType.userEntered,
                sourceReference: source,
                factVersion: '1',
              ),
    };
    return c.consumption.finalizeConsumption(
      NutritionConsumptionFinalizeRequest(
        userId: kLocalNutritionUserScopeId,
        consumptionId: 'fixture-$source',
        commandId: 'fixture-$source',
        loggedAtUtc: loggedAt,
        localDate: loggedRecordsDate,
        timezoneId: loggedRecordsTimezone,
        mealCategory: meal,
        sourceType: source,
        calculatorVersion: '${source}_fixture_v1',
        items: [
          NutritionConsumptionItemInput(
            id: 'fixture-$source::item::0',
            position: 0,
            sourceType: source,
            foodId: foodId,
            displayLabel: label,
            quantity: Quantity.fromDecimal(
              amount: '1',
              unit: QuantityUnit.piece,
            ),
            calculation: NutritionConsumptionCalculationSnapshot.fromFacts(
              facts: facts,
              registry: c.registry,
              requestedNutrientIds: const ['energy', 'protein'],
              calculatorVersion: '${source}_fixture_v1',
              calculationFingerprint: 'fixture-$source',
            ),
          ),
        ],
      ),
    );
  }
}

/// The provider overrides that point the food screens at [c].
List<Override> loggedRecordsOverrides(RealCatalogue c) {
  final readModels = NutritionReadModelRepository(
    db: c.db,
    registry: c.registry,
    canonicalRepository: c.consumption,
    legacyUserId: kLocalNutritionUserScopeId,
  );
  return [
    databaseProvider.overrideWithValue(c.db),
    localTimezoneServiceProvider.overrideWithValue(
      LocalTimezoneService(read: () async => loggedRecordsTimezone),
    ),
    nutritionRegistryProvider.overrideWith((ref) async => c.registry),
    nutritionFoodCatalogRepositoryProvider.overrideWith(
      (ref) async => c.catalog,
    ),
    nutritionConsumptionRepositoryProvider.overrideWith(
      (ref) async => c.consumption,
    ),
    nutritionReadModelRepositoryProvider.overrideWith(
      (ref) async => readModels,
    ),
    nutritionFoodLoggingCoordinatorProvider.overrideWith(
      (ref) async => LoggedRecords.coordinatorFor(c),
    ),
    canonicalRecentFoodsProvider.overrideWith((ref) async => const []),
  ];
}

/// Lets the database futures run, then pumps frames.
Future<void> settleLoggedRecords(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
