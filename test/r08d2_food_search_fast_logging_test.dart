import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/food_api_service.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/data/services/nutrition_food_search_ranking.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R08D.2 food discovery', () {
    test(
      'local retrieval includes existing brand and regional metadata',
      () async {
        final database = AppDatabase.memory();
        addTearDown(database.close);
        final repository = FoodRepository(database);
        await repository.insertCustomFood(
          FoodItemsCompanion.insert(
            name: 'Fresh Paneer',
            calories: 265,
            proteinG: 18,
            carbsG: 6,
            fatG: 20,
            servingSize: 200,
            servingUnit: 'g',
            category: 'Dairy',
            brand: const Value('Amul'),
            regionPack: const Value('west-india'),
          ),
        );

        expect(
          (await repository.searchFoodLocal('amul')).map((food) => food.name),
          contains('Fresh Paneer'),
        );
        expect(
          (await repository.searchFoodLocal('dairy')).map((food) => food.name),
          contains('Fresh Paneer'),
        );
        expect(
          (await repository.searchFoodLocal(
            'west-india',
          )).map((food) => food.name),
          contains('Fresh Paneer'),
        );
      },
    );

    test(
      'exact and partial matches remain deterministic across input order',
      () {
        final candidates = [
          _legacyFood('Paneer bhurji', 2),
          _legacyFood('Paneer', 1, brand: 'Local dairy'),
          _remoteFood('Protein snack', providerId: 'remote-1'),
        ];

        final forward = NutritionFoodSearchRanking.rank(
          query: 'paneer',
          candidates: candidates,
        ).map((result) => result.candidate.deterministicKey).toList();
        final reverse = NutritionFoodSearchRanking.rank(
          query: 'paneer',
          candidates: candidates.reversed,
        ).map((result) => result.candidate.deterministicKey).toList();

        expect(forward, reverse);
        expect(
          NutritionFoodSearchRanking.rank(
            query: 'paneer',
            candidates: candidates,
          ).first.candidate.displayName,
          'Paneer',
        );
      },
    );

    test(
      'provider result without a stable product identity stays untrusted',
      () {
        final candidate = NutritionFoodSearchCandidate.remote(
          FoodApiResult(
            name: 'Unidentified provider food',
            calories: 120,
            protein: 8,
            carbs: 12,
            fat: 4,
            servingSize: 100,
            servingUnit: 'g',
          ),
        );

        expect(candidate.trustedIdentityKey, isNull);
        expect(
          NutritionFoodSearchRanking.rank(
            query: 'unidentified',
            candidates: [candidate],
          ),
          hasLength(1),
        );
      },
    );

    test('conflicting provider identity fields fail closed', () {
      final remote = FoodApiResult(
        name: 'Malformed provider food',
        calories: 120,
        protein: 8,
        carbs: 12,
        fat: 4,
        servingSize: 100,
        servingUnit: 'g',
        barcode: 'barcode-a',
        providerId: 'product-b',
      );
      final candidate = NutritionFoodSearchCandidate.remote(remote);

      expect(NutritionFoodProviderIdentity.sourceReference(remote), isNull);
      expect(candidate.trustedIdentityKey, isNull);
    });

    test('duplicate provider identity is deduplicated deterministically', () {
      final first = _remoteFood(
        'Rice product',
        providerId: 'provider-rice',
        calories: 110,
      );
      final second = _remoteFood(
        'Rice product',
        providerId: 'provider-rice',
        calories: 120,
      );

      final forward = NutritionFoodSearchRanking.rank(
        query: 'rice',
        candidates: [first, second],
      );
      final reverse = NutritionFoodSearchRanking.rank(
        query: 'rice',
        candidates: [second, first],
      );

      expect(forward, hasLength(1));
      expect(reverse, hasLength(1));
      expect(
        forward.single.candidate.deterministicKey,
        reverse.single.candidate.deterministicKey,
      );
    });

    test('usage history does not introduce popularity ranking', () {
      final exact = _legacyFood('Rice', 1);
      final prefix = _legacyFood('Rice flakes', 2);
      final baseline = NutritionFoodSearchRanking.rank(
        query: 'rice',
        candidates: [prefix, exact],
      );
      final withHistory = NutritionFoodSearchRanking.rank(
        query: 'rice',
        candidates: [prefix, exact],
        history: const NutritionFoodSearchHistory(
          frequencyByIdentity: {'canonical::legacy-food-item::2': 999},
          recentIdentities: {'canonical::legacy-food-item::2'},
        ),
      );

      expect(
        withHistory.map((result) => result.candidate.deterministicKey),
        baseline.map((result) => result.candidate.deterministicKey),
      );
      expect(withHistory.first.candidate.displayName, 'Rice');
    });
  });

  group('R08D.2 canonical fast logging boundary', () {
    test(
      'preserves exact food identity, quantity, meal, and local date',
      () async {
        final harness = await _LoggingHarness.create();
        addTearDown(harness.close);
        final option = await harness.catalog.createUserFood(
          displayName: 'Exact logged food',
          servingSize: 1,
          servingUnit: 'bowl',
          energyKcal: 220,
          proteinG: 10,
          carbohydrateG: 24,
          fatG: 8,
        );
        final definition = option.baseQuantity.context.servingDefinition!;
        final quantity = Quantity.serving(
          amount: '2',
          definition: definition,
          source: 'r08d2-test',
        );
        final preview = await harness.logger.preview(
          option: option,
          quantity: quantity,
        );

        final saved = await harness.logger.finalize(
          userId: harness.userId,
          preview: preview,
          mealCategory: 'lunch',
          loggedAt: DateTime.utc(2026, 8, 24, 6, 30),
          localDate: '2026-08-24',
          timezoneId: 'Asia/Kolkata',
          commandId: 'r08d2-command-1',
          consumptionId: 'r08d2-consumption-1',
        );

        expect(saved.items.single.foodId, option.id);
        expect(saved.items.single.quantity.amount.toString(), '2');
        expect(saved.items.single.quantity.unit, QuantityUnit.serving);
        expect(saved.mealCategory, 'lunch');
        expect(saved.localDate, '2026-08-24');
        expect(saved.timezoneId, 'Asia/Kolkata');
      },
    );

    test('repeating the same command is one canonical snapshot', () async {
      final harness = await _LoggingHarness.create();
      addTearDown(harness.close);
      final option = await harness.catalog.createUserFood(
        displayName: 'Idempotent food',
        servingSize: 1,
        servingUnit: 'serving',
        energyKcal: 100,
        proteinG: 5,
        carbohydrateG: 10,
        fatG: 2,
      );
      final preview = await harness.logger.preview(
        option: option,
        quantity: option.baseQuantity,
      );
      final args = _FinalizeArgs(
        userId: harness.userId,
        preview: preview,
        mealCategory: 'breakfast',
        loggedAt: DateTime.utc(2026, 8, 24, 2),
        localDate: '2026-08-24',
        timezoneId: 'Asia/Kolkata',
        commandId: 'r08d2-command-retry',
        consumptionId: 'r08d2-consumption-retry',
      );

      final first = await harness.logger.finalize(
        userId: args.userId,
        preview: args.preview,
        mealCategory: args.mealCategory,
        loggedAt: args.loggedAt,
        localDate: args.localDate,
        timezoneId: args.timezoneId,
        commandId: args.commandId,
        consumptionId: args.consumptionId,
      );
      final retry = await harness.logger.finalize(
        userId: args.userId,
        preview: args.preview,
        mealCategory: args.mealCategory,
        loggedAt: args.loggedAt,
        localDate: args.localDate,
        timezoneId: args.timezoneId,
        commandId: args.commandId,
        consumptionId: args.consumptionId,
      );

      expect(retry.id, first.id);
      expect(
        await harness.consumption.listAllForUser(userId: harness.userId),
        hasLength(1),
      );
    });

    test(
      'unsupported unit conversion and malformed save fail closed',
      () async {
        final definition = const ServingDefinitionReference(
          id: 'r08d2-serving',
          revision: '1',
          source: 'test',
        );
        final serving = Quantity.serving(amount: '1', definition: definition);
        expect(
          () => serving.convertTo(QuantityUnit.gram),
          throwsA(isA<QuantityError>()),
        );
        expect(
          () => Quantity.fromDecimal(
            amount: 'not-a-number',
            unit: QuantityUnit.gram,
          ),
          throwsA(isA<QuantityError>()),
        );

        final harness = await _LoggingHarness.create();
        addTearDown(harness.close);
        final option = await harness.catalog.createUserFood(
          displayName: 'Recoverable save failure',
          servingSize: 1,
          servingUnit: 'serving',
          energyKcal: 100,
          proteinG: 5,
          carbohydrateG: 10,
          fatG: 2,
        );
        final preview = await harness.logger.preview(
          option: option,
          quantity: option.baseQuantity,
        );

        await expectLater(
          harness.logger.finalize(
            userId: harness.userId,
            preview: preview,
            mealCategory: 'dinner',
            loggedAt: DateTime.utc(2026, 8, 24, 18),
            localDate: 'not-a-date',
            timezoneId: 'Asia/Kolkata',
            commandId: 'r08d2-invalid-date',
            consumptionId: 'r08d2-invalid-date-consumption',
          ),
          throwsA(isA<NutritionFoodLoggingError>()),
        );
        expect(
          await harness.consumption.listAllForUser(userId: harness.userId),
          isEmpty,
        );
      },
    );
  });
}

NutritionFoodSearchCandidate _legacyFood(
  String name,
  int id, {
  String? brand,
}) => NutritionFoodSearchCandidate.legacy(
  FoodItem(
    id: id,
    name: name,
    calories: 220,
    proteinG: 10,
    carbsG: 20,
    fatG: 8,
    fiberG: 2,
    servingSize: 1,
    servingUnit: 'serving',
    category: 'Indian',
    isCustom: false,
    brand: brand,
  ),
);

NutritionFoodSearchCandidate _remoteFood(
  String name, {
  required String providerId,
  double calories = 120,
}) => NutritionFoodSearchCandidate.remote(
  FoodApiResult(
    name: name,
    calories: calories,
    protein: 5,
    carbs: 20,
    fat: 3,
    servingSize: 100,
    servingUnit: 'g',
    providerId: providerId,
    barcode: providerId,
  ),
);

class _FinalizeArgs {
  const _FinalizeArgs({
    required this.userId,
    required this.preview,
    required this.mealCategory,
    required this.loggedAt,
    required this.localDate,
    required this.timezoneId,
    required this.commandId,
    required this.consumptionId,
  });

  final String userId;
  final NutritionFoodLogPreview preview;
  final String mealCategory;
  final DateTime loggedAt;
  final String localDate;
  final String timezoneId;
  final String commandId;
  final String consumptionId;
}

class _LoggingHarness {
  _LoggingHarness({
    required this.database,
    required this.registry,
    required this.catalog,
    required this.consumption,
    required this.logger,
  });

  static const _userId = 'r08d2-test-user';

  final AppDatabase database;
  final NutrientRegistry registry;
  final NutritionFoodCatalogRepository catalog;
  final NutritionConsumptionRepository consumption;
  final NutritionFoodLoggingCoordinator logger;

  String get userId => _userId;

  static Future<_LoggingHarness> create() async {
    final database = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    final catalog = NutritionFoodCatalogRepository(
      db: database,
      registry: registry,
    );
    final consumption = NutritionConsumptionRepository(
      db: database,
      registry: registry,
    );
    final logger = NutritionFoodLoggingCoordinator(
      db: database,
      registry: registry,
      catalog: catalog,
      calculator: const NutritionCalculationService(),
      consumption: consumption,
      transformations: NutritionTransformationRepository(db: database),
    );
    return _LoggingHarness(
      database: database,
      registry: registry,
      catalog: catalog,
      consumption: consumption,
      logger: logger,
    );
  }

  Future<void> close() => database.close();
}
