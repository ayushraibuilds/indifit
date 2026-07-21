import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/utils/household_measures.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FoodRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    repo = FoodRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Data Quality Gap 1 & Schema v11 Tests', () {
    test('AppDatabase initializes with schema version 11', () {
      expect(db.schemaVersion, equals(11));
    });
  });

  group('Data Quality Gap 2 — Household Measures Engine Tests', () {
    test('HouseholdMeasure finds units correctly and provides gram equivalents', () {
      final katori = HouseholdMeasure.findByKey('katori');
      expect(katori.gramEquivalent, equals(150.0));
      expect(katori.label, contains('Katori'));

      final tbspGhee = HouseholdMeasure.findByKey('tbsp_ghee');
      expect(tbspGhee.gramEquivalent, equals(15.0));

      final mediumRoti = HouseholdMeasure.findByKey('medium_roti');
      expect(mediumRoti.gramEquivalent, equals(45.0));
    });

    test('getScaleMultiplier calculates accurate ratios between measures', () {
      // 1 katori (150g) -> 1 full katori (200g) => multiplier 200/150 = 1.333...
      final mult = HouseholdMeasure.getScaleMultiplier(
        baseUnit: 'katori',
        baseAmount: 1.0,
        targetUnit: 'katori_full',
        targetAmount: 1.0,
      );
      expect(mult, closeTo(1.333, 0.001));

      // 2 small rotis (60g total) -> 1 large roti (60g total) => multiplier 1.0
      final rotiMult = HouseholdMeasure.getScaleMultiplier(
        baseUnit: 'small_roti',
        baseAmount: 2.0,
        targetUnit: 'large_roti',
        targetAmount: 1.0,
      );
      expect(rotiMult, closeTo(1.0, 0.001));
    });
  });

  group('Data Quality Gap 4 — Meal Templates Repository API Tests', () {
    test('createMealTemplate inserts template and items, getMealTemplates retrieves them', () async {
      final templateId = await repo.createMealTemplate(
        name: 'My Usual Indian Breakfast',
        defaultMealType: 'breakfast',
        items: const [
          MealTemplateItemInput(
            name: 'Poha with Peanuts',
            calories: 250,
            proteinG: 5.5,
            carbsG: 42.0,
            fatG: 7.0,
            servingLogged: 1.0,
            servingUnit: 'katori',
          ),
          MealTemplateItemInput(
            name: 'Masala Chai',
            calories: 80,
            proteinG: 2.0,
            carbsG: 10.0,
            fatG: 3.0,
            servingLogged: 1.0,
            servingUnit: 'cup',
          ),
        ],
      );

      expect(templateId, greaterThan(0));

      final templates = await repo.getMealTemplates();
      expect(templates.length, equals(1));
      expect(templates.first.template.name, equals('My Usual Indian Breakfast'));
      expect(templates.first.items.length, equals(2));
      expect(templates.first.totalCalories, equals(330));
    });

    test('logMealTemplate batch logs all template items to food logs', () async {
      final templateId = await repo.createMealTemplate(
        name: 'Office Thali Lunch',
        defaultMealType: 'lunch',
        items: const [
          MealTemplateItemInput(
            name: '2 Roti',
            calories: 170,
            proteinG: 6.0,
            carbsG: 36.0,
            fatG: 1.0,
            servingLogged: 2.0,
            servingUnit: 'piece',
          ),
          MealTemplateItemInput(
            name: 'Yellow Dal Tadka',
            calories: 170,
            proteinG: 8.5,
            carbsG: 22.0,
            fatG: 5.5,
            servingLogged: 1.0,
            servingUnit: 'katori',
          ),
        ],
      );

      final loggedIds = await repo.logMealTemplate(
        templateId: templateId,
        targetMealType: 'lunch',
      );

      expect(loggedIds.length, equals(2));

      final logs = await repo.getUnsyncedLogs(); // or select all food logs
      expect(logs.length, greaterThanOrEqualTo(2));
    });

    test('deleteMealTemplate deletes template and its items', () async {
      final templateId = await repo.createMealTemplate(
        name: 'Temporary Meal Combo',
        defaultMealType: 'snack',
        items: const [
          MealTemplateItemInput(
            name: 'Apple',
            calories: 95,
            proteinG: 0.5,
            carbsG: 25.0,
            fatG: 0.3,
            servingLogged: 1.0,
            servingUnit: 'piece',
          ),
        ],
      );

      await repo.deleteMealTemplate(templateId);
      final templates = await repo.getMealTemplates();
      expect(templates.isEmpty, isTrue);
    });
  });
}
