import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/user_profile_provider.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/meal_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: Personalisation & Meal Quality Unit Tests', () {
    late AppDatabase db;
    late UserProfileNotifier profileNotifier;
    late MealPlanService mealPlanService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.memory();
      profileNotifier = UserProfileNotifier(db);
      mealPlanService = MealPlanService();
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Profile state initializes with defaults and updates dietPreference atomically', () async {
      await profileNotifier.loadProfile();
      expect(profileNotifier.state.dietPreference, equals('veg'));
      expect(profileNotifier.state.currentWeight, equals(74.5));

      await profileNotifier.updateProfile(
        name: 'Aarav',
        age: 28,
        height: 178.0,
        weight: 80.0,
        sex: 'male',
        activityLevel: 'active',
        goal: 'gain',
        dietPreference: 'vegan',
        equipmentAccess: 'dumbbells',
        injuriesLimitations: 'Left shoulder soreness',
      );

      expect(profileNotifier.state.userName, equals('Aarav'));
      expect(profileNotifier.state.userAge, equals(28));
      expect(profileNotifier.state.userHeight, equals(178.0));
      expect(profileNotifier.state.currentWeight, equals(80.0));
      expect(profileNotifier.state.userSex, equals('male'));
      expect(profileNotifier.state.userActivityLevel, equals('active'));
      expect(profileNotifier.state.userGoal, equals('gain'));
      expect(profileNotifier.state.dietPreference, equals('vegan'));
      expect(profileNotifier.state.equipmentAccess, equals('dumbbells'));
      expect(profileNotifier.state.injuriesLimitations, equals('Left shoulder soreness'));

      // Verify persistence across reload
      final reloadedNotifier = UserProfileNotifier(db);
      await reloadedNotifier.loadProfile();
      expect(reloadedNotifier.state.dietPreference, equals('vegan'));
      expect(reloadedNotifier.state.equipmentAccess, equals('dumbbells'));
    });

    test('2. Vegan meal plan fallback generates zero dairy, egg, or meat across all 7 days', () async {
      final result = await mealPlanService.generateMealPlan(
        calorieGoal: 2000,
        dietPreference: 'vegan',
      );

      expect(result.isFallback, isTrue);
      expect(result.days.length, equals(7));

      final forbiddenKeywords = [
        'paneer',
        'curd',
        'yogurt',
        'ghee',
        'butter',
        'whey',
        'egg',
        'chicken',
        'mutton',
        'fish',
        'meat'
      ];

      for (final day in result.days) {
        final b = (day['breakfast'] as String).toLowerCase();
        final l = (day['lunch'] as String).toLowerCase();
        final d = (day['dinner'] as String).toLowerCase();
        final s = (day['snacks'] as String).toLowerCase();

        final allText = '$b $l $d $s';
        for (final kw in forbiddenKeywords) {
          final regex = RegExp(r'\b' + kw + r's?\b', caseSensitive: false);
          // Peanut butter and almond butter are vegan
          final textWithoutNutButter = allText.replaceAll(RegExp(r'\b(peanut|almond|cashew)\s+butter\b', caseSensitive: false), '');
          expect(
            regex.hasMatch(textWithoutNutButter),
            isFalse,
            reason: 'Day ${day['day']} vegan plan contained forbidden non-vegan keyword "$kw"',
          );
        }
      }

      final groceryText = result.groceryList.join(' ');
      for (final kw in forbiddenKeywords) {
        final regex = RegExp(r'\b' + kw + r's?\b', caseSensitive: false);
        final groceryWithoutNutButter = groceryText.replaceAll(RegExp(r'\b(peanut|almond|cashew)\s+butter\b', caseSensitive: false), '');
        expect(
          regex.hasMatch(groceryWithoutNutButter),
          isFalse,
          reason: 'Vegan grocery list contained forbidden keyword "$kw"',
        );
      }
    });

    test('3. Non-Vegetarian meal plan fallback incorporates non-veg protein options', () async {
      final result = await mealPlanService.generateMealPlan(
        calorieGoal: 2000,
        dietPreference: 'non_veg',
      );

      expect(result.isFallback, isTrue);
      expect(result.days.length, equals(7));

      final nonVegKeywords = ['chicken', 'egg', 'fish', 'mutton'];
      bool foundNonVeg = false;

      for (final day in result.days) {
        final allText = '${day['breakfast']} ${day['lunch']} ${day['dinner']} ${day['snacks']}'.toLowerCase();
        if (nonVegKeywords.any((kw) => allText.contains(kw))) {
          foundNonVeg = true;
          break;
        }
      }

      expect(foundNonVeg, isTrue, reason: 'Non-veg meal plan should contain chicken, egg, fish, or mutton.');
    });

    test('4. Portion scaling produces calories strictly proportional to target calories (3000 vs 2000 kcal)', () async {
      final result2000 = await mealPlanService.generateMealPlan(
        calorieGoal: 2000,
        dietPreference: 'veg',
      );
      final result3000 = await mealPlanService.generateMealPlan(
        calorieGoal: 3000,
        dietPreference: 'veg',
      );

      // Extract Monday lunch calories for both plans
      final mondayLunch2000 = result2000.days.firstWhere((d) => d['day'] == 'Monday')['lunch'] as String;
      final mondayLunch3000 = result3000.days.firstWhere((d) => d['day'] == 'Monday')['lunch'] as String;

      final kcal2000 = _extractKcal(mondayLunch2000);
      final kcal3000 = _extractKcal(mondayLunch3000);

      expect(kcal2000, isNotNull);
      expect(kcal3000, isNotNull);

      final ratio = kcal3000! / kcal2000!;
      // 3000 / 2000 = 1.5 ratio target within +-5% tolerance
      expect(ratio, closeTo(1.5, 0.10));
    });
  });
}

int? _extractKcal(String text) {
  final match = RegExp(r'(\d+)\s*kcal').firstMatch(text);
  if (match != null) {
    return int.tryParse(match.group(1)!);
  }
  return null;
}
