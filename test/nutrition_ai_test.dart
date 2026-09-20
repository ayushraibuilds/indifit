import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/privacy/nutrition_estimate_privacy.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/nutrition_ai/natural_language_meal_service.dart';
import 'package:indifit/features/nutrition_ai/nutrition_ai_controllers.dart';
import 'package:indifit/features/nutrition_ai/nutrition_label_ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutrientRegistry registry;
  late NutritionFoodCatalogRepository catalog;
  late NutritionConsumptionRepository consumption;
  late NutritionFoodLoggingCoordinator coordinator;

  setUp(() async {
    db = AppDatabase.memory();
    registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    catalog = NutritionFoodCatalogRepository(db: db, registry: registry);
    consumption = NutritionConsumptionRepository(db: db, registry: registry);
    coordinator = NutritionFoodLoggingCoordinator(
      db: db,
      registry: registry,
      catalog: catalog,
      calculator: const NutritionCalculationService(),
      consumption: consumption,
      transformations: NutritionTransformationRepository(db: db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('NutritionLabelOcrResult model & dual-basis calculations', () {
    test('parses Indian FSSAI per-100g label with field confidence', () {
      final json = {
        'product_name': 'True Elements Rolled Oats',
        'brand_name': 'True Elements',
        'serving_size_amount': 40.0,
        'serving_size_unit': 'g',
        'serving_description': '1/2 cup (40g)',
        'servings_per_container': 12.5,
        'basis': 'per_100g',
        'nutrients': {
          'calories': {
            'value': 389.0,
            'unit': 'kcal',
            'confidence': 'high',
            'notes': 'Energy',
          },
          'protein': {
            'value': 13.5,
            'unit': 'g',
            'confidence': 'high',
            'notes': 'Protein',
          },
          'carbs': {
            'value': 66.3,
            'unit': 'g',
            'confidence': 'medium',
            'notes': 'Total Carbohydrate',
          },
          'fat': {
            'value': 6.9,
            'unit': 'g',
            'confidence': 'low',
            'notes': 'Total Fat',
          },
        },
        'raw_text': 'Energy 389 kcal, Protein 13.5g',
        'is_fallback': false,
      };

      final result = NutritionLabelOcrResult.fromJson(json);

      expect(result.productName, 'True Elements Rolled Oats');
      expect(result.brandName, 'True Elements');
      expect(result.isPer100g, isTrue);
      expect(result.energyKcal, 389.0);
      expect(result.proteinG, 13.5);
      expect(result.carbsG, 66.3);
      expect(result.fatG, 6.9);
      expect(result.nutrients['protein']?.isHighConfidence, isTrue);
      expect(result.nutrients['carbs']?.confidence, 'medium');
      expect(result.nutrients['fat']?.isLowConfidence, isTrue);
    });

    test('parses per-serving label format', () {
      final json = {
        'product_name': 'Protein Bar',
        'serving_size_amount': 60.0,
        'serving_size_unit': 'g',
        'basis': 'per_serving',
        'nutrients': {
          'calories': {'value': 220.0, 'unit': 'kcal', 'confidence': 'high'},
          'protein': {'value': 20.0, 'unit': 'g', 'confidence': 'high'},
        },
      };

      final result = NutritionLabelOcrResult.fromJson(json);

      expect(result.isPerServing, isTrue);
      expect(result.servingSizeAmount, 60.0);
      expect(result.energyKcal, 220.0);
      expect(result.proteinG, 20.0);
    });
  });

  group('NutritionLabelOcrService ephemeral image cleanup invariant', () {
    test('enforces ephemeral cleanup in finally block even on network error', () async {
      final tempDir = await Directory.systemTemp.createTemp('indifit_ocr_test');
      final testFile = File('${tempDir.path}/test_label.jpg');
      await testFile.writeAsBytes([1, 2, 3, 4]);

      expect(await testFile.exists(), isTrue);

      String? deletedPath;

      final privacyService = NutritionEstimatePrivacyService(
        delete: (path) async {
          deletedPath = path;
          final f = File(path);
          if (await f.exists()) await f.delete();
        },
      );

      // Create Dio that throws a network error
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Network failure',
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );

      final service = NutritionLabelOcrService(
        dio: dio,
        privacyService: privacyService,
        policy: () => const PrivacyPolicy(
          isOfflineOnly: false,
          isTelemetryEnabled: false,
          connectedAiEnabled: true,
        ),
      );

      await expectLater(
        () => service.processLabelImage(imagePath: testFile.path),
        throwsA(isA<DioException>()),
      );

      // Verify privacy service was invoked and file is deleted
      expect(deletedPath, testFile.path);
      expect(await testFile.exists(), isFalse);

      await tempDir.delete(recursive: true);
    });
  });

  group('NaturalLanguageMealService model & decomposition', () {
    test('DecomposedFoodItem calculates proportional macros when quantity changes', () {
      const item = DecomposedFoodItem(
        rawSegment: '2 rotis',
        foodName: 'Whole Wheat Roti',
        quantityAmount: 2.0,
        quantityUnit: 'roti',
        estimatedCalories: 160,
        estimatedProtein: 5.0,
        estimatedCarbs: 30.0,
        estimatedFat: 1.6,
        confidence: 'high',
      );

      expect(item.estimatedCalories, 160);
      expect(item.estimatedProtein, 5.0);

      // Test copyWith
      final scaled = item.copyWith(
        quantityAmount: 3.0,
        estimatedCalories: 240,
        estimatedProtein: 7.5,
      );

      expect(scaled.quantityAmount, 3.0);
      expect(scaled.estimatedCalories, 240);
      expect(scaled.estimatedProtein, 7.5);
    });

    test('MealDecompositionResult calculates aggregate macros across all items', () {
      const result = MealDecompositionResult(
        query: '2 rotis and 1 bowl dal tadka',
        items: [
          DecomposedFoodItem(
            rawSegment: '2 rotis',
            foodName: 'Whole Wheat Roti',
            quantityAmount: 2.0,
            quantityUnit: 'roti',
            estimatedCalories: 160,
            estimatedProtein: 5.0,
            estimatedCarbs: 30.0,
            estimatedFat: 1.6,
          ),
          DecomposedFoodItem(
            rawSegment: '1 bowl dal tadka',
            foodName: 'Yellow Dal Tadka',
            quantityAmount: 1.0,
            quantityUnit: 'bowl',
            estimatedCalories: 150,
            estimatedProtein: 7.5,
            estimatedCarbs: 21.0,
            estimatedFat: 4.2,
          ),
        ],
        totalCalories: 310,
      );

      expect(result.totalCalories, 310);
      expect(result.totalProtein, closeTo(12.5, 0.01));
      expect(result.totalCarbs, closeTo(51.0, 0.01));
      expect(result.totalFat, closeTo(5.8, 0.01));
    });
  });

  group('NutritionLabelOcrController integration', () {
    test('creates custom food and logs to diary', () async {
      final ocrService = NutritionLabelOcrService(
        dio: Dio(),
        privacyService: NutritionEstimatePrivacyService(),
        policy: () => const PrivacyPolicy(
          isOfflineOnly: false,
          isTelemetryEnabled: false,
          connectedAiEnabled: true,
        ),
      );

      final controller = NutritionLabelOcrController(
        ocrService: ocrService,
        catalogRepository: () async => catalog,
        loggingCoordinator: () async => coordinator,
        userId: 'test-user',
        timezoneId: () async => 'Asia/Kolkata',
      );

      // Manually set ready state
      controller.updateProductName('High Protein Muesli');
      controller.updateBasis('per_100g');
      controller.updateNutrient('calories', 380.0);
      controller.updateNutrient('protein', 18.0);
      controller.updateNutrient('carbs', 60.0);
      controller.updateNutrient('fat', 6.0);

      // Save as custom food
      final customOption = await controller.saveAsCustomFood();
      expect(customOption, isNotNull);
      expect(customOption!.displayName, 'High Protein Muesli');
      expect(controller.state.isSaved, isTrue);

      // Log to diary
      final logged = await controller.logToDiary(
        mealType: 'breakfast',
        date: DateTime.utc(2026, 9, 13),
      );
      expect(logged, isTrue);
      expect(controller.state.isLogged, isTrue);
    });
  });

  group('NaturalLanguageMealController atomic batch finalization', () {
    test('logs multiple decomposed items under one shared mealGroupId', () async {
      final mealService = NaturalLanguageMealService(
        dio: Dio(),
        catalog: catalog,
        policy: () => const PrivacyPolicy(
          isOfflineOnly: false,
          isTelemetryEnabled: false,
          connectedAiEnabled: true,
        ),
      );

      final controller = NaturalLanguageMealController(
        mealService: () async => mealService,
        catalogRepository: () async => catalog,
        loggingCoordinator: () async => coordinator,
        userId: 'test-user',
        timezoneId: () async => 'Asia/Kolkata',
      );

      // Set items
      final item1 = const DecomposedFoodItem(
        rawSegment: '2 rotis',
        foodName: 'Roti',
        quantityAmount: 2.0,
        quantityUnit: 'roti',
        estimatedCalories: 160,
        estimatedProtein: 5.0,
        estimatedCarbs: 30.0,
        estimatedFat: 1.6,
      );
      final item2 = const DecomposedFoodItem(
        rawSegment: '1 bowl dal',
        foodName: 'Dal',
        quantityAmount: 1.0,
        quantityUnit: 'bowl',
        estimatedCalories: 150,
        estimatedProtein: 7.5,
        estimatedCarbs: 21.0,
        estimatedFat: 4.2,
      );

      controller.state = controller.state.copyWith(
        status: NaturalLanguageMealStatus.ready,
        editableItems: [item1, item2],
      );

      expect(controller.state.totalCalories, 310);

      final logged = await controller.logAllToDiary(
        mealType: 'lunch',
        date: DateTime.utc(2026, 9, 13),
      );

      expect(logged, isTrue);
      expect(controller.state.isLogged, isTrue);
    });
  });
}
