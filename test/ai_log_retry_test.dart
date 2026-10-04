import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/privacy/nutrition_estimate_privacy.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/data/database/app_database.dart' show AppDatabase;
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/nutrition_ai/natural_language_meal_service.dart';
import 'package:indifit/features/nutrition_ai/nutrition_ai_controllers.dart';
import 'package:indifit/features/nutrition_ai/nutrition_label_ocr_service.dart';

/// Commits each log, then throws once on [failOnCall]: the write landed but
/// the app never heard, the worst case for a retry.
class _LostReplyCoordinator extends NutritionFoodLoggingCoordinator {
  _LostReplyCoordinator({
    required super.db,
    required super.registry,
    required super.catalog,
    required super.calculator,
    required super.consumption,
    required super.transformations,
  });

  int calls = 0;
  int? failOnCall;

  @override
  Future<NutritionConsumptionSnapshot> finalize({
    required String userId,
    required NutritionFoodLogPreview preview,
    required String mealCategory,
    required DateTime loggedAt,
    required String localDate,
    required String timezoneId,
    String? mealGroupId,
    String? consumptionId,
    String? commandId,
    String? supersedesSnapshotId,
    String? correctionId,
    String? correctionReason,
  }) async {
    final snapshot = await super.finalize(
      userId: userId,
      preview: preview,
      mealCategory: mealCategory,
      loggedAt: loggedAt,
      localDate: localDate,
      timezoneId: timezoneId,
      mealGroupId: mealGroupId,
      consumptionId: consumptionId,
      commandId: commandId,
      supersedesSnapshotId: supersedesSnapshotId,
      correctionId: correctionId,
      correctionReason: correctionReason,
    );
    calls++;
    if (calls == failOnCall) throw StateError('reply lost');
    return snapshot;
  }
}

const _aiAllowed = PrivacyPolicy(
  isOfflineOnly: false,
  isTelemetryEnabled: false,
  connectedAiEnabled: true,
);

/// Unmatched items, so each one also creates a custom food.
const _roti = DecomposedFoodItem(
  rawSegment: '2 rotis',
  foodName: 'Ghar ki roti',
  quantityAmount: 2,
  quantityUnit: 'roti',
  estimatedCalories: 160,
  estimatedProtein: 5,
  estimatedCarbs: 30,
  estimatedFat: 1.6,
);
const _dal = DecomposedFoodItem(
  rawSegment: '1 katori dal',
  foodName: 'Ghar ki dal',
  quantityAmount: 1,
  quantityUnit: 'katori',
  estimatedCalories: 150,
  estimatedProtein: 7.5,
  estimatedCarbs: 21,
  estimatedFat: 4.2,
);
const _sabzi = DecomposedFoodItem(
  rawSegment: '1 katori sabzi',
  foodName: 'Ghar ki sabzi',
  quantityAmount: 1,
  quantityUnit: 'katori',
  estimatedCalories: 120,
  estimatedProtein: 3,
  estimatedCarbs: 12,
  estimatedFat: 6,
);

void main() {
  // The database seeds the food catalogue from assets via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutrientRegistry registry;
  late NutritionFoodCatalogRepository catalog;
  late _LostReplyCoordinator coordinator;
  final date = DateTime.utc(2026, 10, 4);

  /// Fails the save of the [n]th item inside its transaction, so it rolls
  /// back, like a database error part-way through a meal.
  var failSaveNumber = 0;
  var saves = 0;

  setUp(() {
    db = AppDatabase.memory();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    catalog = NutritionFoodCatalogRepository(db: db, registry: registry);
    failSaveNumber = 0;
    saves = 0;
    coordinator = _LostReplyCoordinator(
      db: db,
      registry: registry,
      catalog: catalog,
      calculator: const NutritionCalculationService(),
      consumption: NutritionConsumptionRepository(
        db: db,
        registry: registry,
        failureInjector: (stage) {
          if (stage != 'after_header') return;
          saves++;
          if (saves == failSaveNumber) throw StateError('disk full');
        },
      ),
      transformations: NutritionTransformationRepository(db: db),
    );
  });

  tearDown(() => db.close());

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('c');
  Future<int> diaryEntries() =>
      count('SELECT COUNT(*) AS c FROM nutrition_consumption_snapshots');
  Future<int> customFoods() => count(
    "SELECT COUNT(*) AS c FROM nutrition_foods WHERE id LIKE 'user-food::%'",
  );
  Future<int> mealGroups() => count(
    'SELECT COUNT(DISTINCT meal_group_id) AS c '
    'FROM nutrition_consumption_snapshots',
  );

  NaturalLanguageMealService mealService() => NaturalLanguageMealService(
    dio: Dio(),
    catalog: catalog,
    policy: () => _aiAllowed,
  );

  group('Describe a meal', () {
    NaturalLanguageMealController controller() => NaturalLanguageMealController(
      mealService: () async => mealService(),
      catalogRepository: () async => catalog,
      loggingCoordinator: () async => coordinator,
      userId: 'test-user',
      timezoneId: () async => 'Asia/Kolkata',
    );

    test('a retry after a part-way failure logs only the rest', () async {
      final meal = controller();
      meal.state = meal.state.copyWith(
        status: NaturalLanguageMealStatus.ready,
        editableItems: [_roti, _dal, _sabzi],
      );

      failSaveNumber = 2; // dal fails
      expect(await meal.logAllToDiary(mealType: 'lunch', date: date), isFalse);
      expect(await diaryEntries(), 1);
      expect(meal.state.editableItems, [_dal, _sabzi]);
      expect(meal.state.errorMessage, startsWith('Logged 1 of 3 items.'));

      expect(await meal.logAllToDiary(mealType: 'lunch', date: date), isTrue);
      expect(await diaryEntries(), 3);
      expect(await customFoods(), 3, reason: "dal's food is reused");
      expect(await mealGroups(), 1, reason: 'still one meal');
    });

    test('a retry after a lost reply replays instead of duplicating', () async {
      final meal = controller();
      meal.state = meal.state.copyWith(
        status: NaturalLanguageMealStatus.ready,
        editableItems: [_roti, _dal],
      );

      coordinator.failOnCall = 2; // dal was saved, but the reply was lost
      expect(await meal.logAllToDiary(mealType: 'lunch', date: date), isFalse);
      expect(await diaryEntries(), 2);
      expect(meal.state.editableItems, [_dal]);

      expect(await meal.logAllToDiary(mealType: 'lunch', date: date), isTrue);
      expect(await diaryEntries(), 2);
      expect(await customFoods(), 2);
    });

    test('an edited item is logged with its new values', () async {
      final meal = controller();
      meal.state = meal.state.copyWith(
        status: NaturalLanguageMealStatus.ready,
        editableItems: [_roti, _dal],
      );

      failSaveNumber = 2;
      await meal.logAllToDiary(mealType: 'lunch', date: date);
      meal.updateItemQuantity(0, 2, 'katori'); // dal: 1 -> 2 katori

      expect(await meal.logAllToDiary(mealType: 'lunch', date: date), isTrue);
      expect(await diaryEntries(), 2);
    });
  });

  group('Meal photo', () {
    test('a failed log returns to the review, keeping the rest', () async {
      final photo = PhotoMealController(
        mealService: () async => mealService(),
        catalogRepository: () async => catalog,
        loggingCoordinator: () async => coordinator,
        userId: 'test-user',
        timezoneId: () async => 'Asia/Kolkata',
      );
      photo.state = photo.state.copyWith(
        status: PhotoMealStatus.ready,
        editableItems: [_roti, _dal],
      );

      failSaveNumber = 2;
      expect(
        await photo.logAllToDiary(mealType: 'dinner', date: date),
        isFalse,
      );
      expect(photo.state.status, PhotoMealStatus.ready);
      expect(photo.state.editableItems, [_dal]);
      expect(photo.state.errorMessage, startsWith('Logged 1 of 2 items.'));

      expect(await photo.logAllToDiary(mealType: 'dinner', date: date), isTrue);
      expect(await diaryEntries(), 2);
      expect(await customFoods(), 2);
    });
  });

  group('Nutrition label', () {
    NutritionLabelOcrController controller() => NutritionLabelOcrController(
      ocrService: NutritionLabelOcrService(
        dio: Dio(),
        privacyService: NutritionEstimatePrivacyService(),
        policy: () => _aiAllowed,
      ),
      catalogRepository: () async => catalog,
      loggingCoordinator: () async => coordinator,
      userId: 'test-user',
      timezoneId: () async => 'Asia/Kolkata',
    );

    void fillLabel(NutritionLabelOcrController label) {
      label
        ..updateProductName('High Protein Muesli')
        ..updateBasis('per_100g')
        ..updateNutrient('calories', 380)
        ..updateNutrient('protein', 18)
        ..updateNutrient('carbs', 60)
        ..updateNutrient('fat', 6);
    }

    test('a retry reuses the custom food and logs once', () async {
      final label = controller();
      fillLabel(label);

      failSaveNumber = 1;
      expect(
        await label.logToDiary(mealType: 'breakfast', date: date),
        isFalse,
      );
      expect(label.state.status, NutritionLabelOcrStatus.ready);
      expect(label.state.errorMessage, isNotNull);

      expect(await label.logToDiary(mealType: 'breakfast', date: date), isTrue);
      expect(await diaryEntries(), 1);
      expect(await customFoods(), 1);
    });

    test('a retry after a lost reply does not log twice', () async {
      final label = controller();
      fillLabel(label);

      coordinator.failOnCall = 1;
      expect(
        await label.logToDiary(mealType: 'breakfast', date: date),
        isFalse,
      );
      expect(await label.logToDiary(mealType: 'breakfast', date: date), isTrue);
      expect(await diaryEntries(), 1);
    });

    test('changed values after a failure log as a new food', () async {
      final label = controller();
      fillLabel(label);

      failSaveNumber = 1;
      await label.logToDiary(mealType: 'breakfast', date: date);
      label.updateNutrient('calories', 390);

      expect(await label.logToDiary(mealType: 'breakfast', date: date), isTrue);
      expect(await diaryEntries(), 1);
      expect(await customFoods(), 2);
    });
  });
}
