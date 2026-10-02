import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/nutrition_ai/natural_language_meal_service.dart';

/// Answers the meal-decompose call with a fixed AI response.
Dio _dioReturning(Map<String, dynamic> body) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(requestOptions: options, statusCode: 200, data: body),
      ),
    ),
  );
  return dio;
}

Map<String, dynamic> _item(String name, double amount, String unit) => {
  'raw_segment': '$amount $unit $name',
  'food_name': name,
  'quantity_amount': amount,
  'quantity_unit': unit,
  'estimated_calories': 100,
  'estimated_protein': 3.0,
  'estimated_carbs': 15.0,
  'estimated_fat': 2.0,
  'confidence': 'medium',
};

void main() {
  // The database seeds the food catalogue from assets via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NutritionFoodCatalogRepository catalog;
  late NutritionFoodLoggingCoordinator coordinator;

  setUp(() {
    db = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    catalog = NutritionFoodCatalogRepository(db: db, registry: registry);
    coordinator = NutritionFoodLoggingCoordinator(
      db: db,
      registry: registry,
      catalog: catalog,
      calculator: const NutritionCalculationService(),
      consumption: NutritionConsumptionRepository(db: db, registry: registry),
      transformations: NutritionTransformationRepository(db: db),
    );
  });

  tearDown(() => db.close());

  NaturalLanguageMealService serviceReturning(
    List<Map<String, dynamic>> items,
  ) => NaturalLanguageMealService(
    dio: _dioReturning({
      'query': 'test',
      'items': items,
      'total_calories': 100 * items.length,
      'is_fallback': false,
    }),
    catalog: catalog,
    policy: () => const PrivacyPolicy(
      isOfflineOnly: false,
      isTelemetryEnabled: false,
      connectedAiEnabled: true,
    ),
    baseUrl: 'http://ai.test',
  );

  test('an exact catalogue name resolves to that food', () async {
    final result = await serviceReturning([
      _item('Bajra Roti (Millet)', 2, 'piece'),
    ]).decomposeMeal(text: '2 bajra roti');

    final item = result.items.single;
    expect(item.isCatalogVerified, isTrue);
    expect(item.matchedCatalogOption!.displayName, 'Bajra Roti (Millet)');
    expect(item.needsCatalogChoice, isFalse);
  });

  test('a vague name asks the user instead of taking the first hit', () async {
    final result = await serviceReturning([
      _item('Dal', 1, 'katori'),
    ]).decomposeMeal(text: '1 katori dal');

    final item = result.items.single;
    expect(item.isCatalogVerified, isFalse);
    expect(item.needsCatalogChoice, isTrue);
    expect(item.catalogChoices.length, inInclusiveRange(2, 3));
    for (final choice in item.catalogChoices) {
      expect(choice.displayName.toLowerCase(), contains('dal'));
    }
  });

  test('a close-but-different dish is offered, not auto-picked', () async {
    final result = await serviceReturning([
      _item('Quinoa avocado bowl', 1, 'bowl'),
    ]).decomposeMeal(text: 'quinoa avocado bowl');

    final item = result.items.single;
    expect(item.isCatalogVerified, isFalse);
    expect(item.needsCatalogChoice, isTrue);
    expect(
      item.catalogChoices.map((f) => f.displayName),
      contains('Quinoa Veg Bowl'),
    );
  });

  test('a food the catalogue lacks stays an AI estimate', () async {
    final result = await serviceReturning([
      _item('Sushi platter', 1, 'plate'),
    ]).decomposeMeal(text: 'sushi platter');

    final item = result.items.single;
    expect(item.isCatalogVerified, isFalse);
    expect(item.needsCatalogChoice, isFalse);
    expect(item.estimatedCalories, 100);
  });

  group('catalogue binding', () {
    Future<double> loggedKcal(DecomposedFoodItem item) async {
      final preview = await coordinator.preview(
        option: item.matchedCatalogOption!,
        quantity: catalogLogQuantity(item),
      );
      return preview.facts['energy']!.point!.value.asDouble;
    }

    test('verified items show catalogue nutrition, not the AI guess', () async {
      final result = await serviceReturning([
        _item('Bajra Roti (Millet)', 2, 'roti'),
      ]).decomposeMeal(text: '2 bajra roti');

      final item = result.items.single;
      final perPiece = item.matchedCatalogOption!.facts['energy']!.point!;
      expect(item.estimatedCalories, (perPiece.value.asDouble * 2).round());
      expect(item.estimatedCalories, isNot(100)); // the AI's figure
      expect(item.quantityAmount, 2);
      expect(item.portionNote, isNull);
    });

    test('what is logged equals what the card shows', () async {
      final result = await serviceReturning([
        _item('Bajra Roti (Millet)', 3, 'piece'),
      ]).decomposeMeal(text: '3 bajra roti');

      final item = result.items.single;
      expect((await loggedKcal(item)).round(), item.estimatedCalories);
    });

    test('an unconvertible unit resets to one serving with a note', () async {
      final result = await serviceReturning([
        _item('Dal Makhani', 2, 'bowl'),
      ]).decomposeMeal(text: '2 bowls dal makhani');

      final item = result.items.single;
      expect(item.isCatalogVerified, isTrue);
      expect(item.quantityAmount, 1);
      expect(item.quantityUnit, 'katori');
      expect(item.portionNote, contains('2 bowl'));
      // Not "2 katori" logged silently, and not the AI's 100 kcal.
      expect((await loggedKcal(item)).round(), item.estimatedCalories);
    });

    test('picking a choice binds the item to that food', () async {
      final result = await serviceReturning([
        _item('Dal', 2, 'katori'),
      ]).decomposeMeal(text: '2 katori dal');

      final item = result.items.single;
      expect(item.needsCatalogChoice, isTrue);
      final katoriDal = item.catalogChoices.firstWhere(
        (choice) => choice.servingUnitLabel == 'katori',
      );
      final bound = bindToCatalog(item, katoriDal);
      expect(bound.needsCatalogChoice, isFalse);
      expect(bound.quantityAmount, 2);
      expect((await loggedKcal(bound)).round(), bound.estimatedCalories);
    });
  });
}
