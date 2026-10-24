import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/data/catalog/catalog_pack.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/features/food_log/my_chai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/real_catalogue.dart';

/// Pack 7: black tea (SR Legacy 173227), and My chai with no milk.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late RealCatalogue c;
  setUp(() async => c = await RealCatalogue.open());
  tearDown(() => c.close());

  double fact(Map<String, dynamic> facts, String id) =>
      (facts[id] as dynamic).point.value.asDouble as double;

  const blackTea = MyChaiSettings(
    milk: MyChaiMilk.none,
    milkShare: MyChaiMilkShare.half,
    sugarTeaspoons: 0,
    cupMillilitres: 150,
  );

  test('pack 7 is the bundled pack and imports black tea', () async {
    expect(kBundledCatalogPackVersion, 7);
    final option = await c.catalog.getOption(kMyChaiBlackTeaFoodId);
    expect(option, isNotNull);
    expect(option!.displayName, 'Black Tea (no milk, no sugar)');
  });

  test('"black tea" finds it, and so do its aliases', () async {
    final hits = await c.catalog.search(query: 'black tea');
    expect(hits.map((option) => option.id), contains(kMyChaiBlackTeaFoodId));
    // Food search's index holds the aliases too.
    for (final query in ['kali chai', 'tea without milk']) {
      final indexed = await FoodRepository(
        c.db,
      ).searchCatalogueOnlyFoods(query);
      expect(
        indexed.map((hit) => hit.foodId),
        contains(kMyChaiBlackTeaFoodId),
        reason: query,
      );
    }
  });

  test('its facts are SR Legacy 173227 per 100 ml', () async {
    final foods = c.catalog;
    final option = (await foods.getOption(kMyChaiBlackTeaFoodId))!;
    final chai = MyChaiRecipe(recipes: c.recipes, logging: c.recipeLogging);
    final facts = (await chai.preview(
      kLocalNutritionUserScopeId,
      blackTea.copyWith(cupMillilitres: 100),
    )).calculation.facts;
    expect(option.displayName, contains('Black Tea'));
    expect(fact(facts, 'energy'), closeTo(1, 1e-6));
    expect(fact(facts, 'carbohydrate'), closeTo(0.3, 1e-6));
    expect(fact(facts, 'protein'), closeTo(0, 1e-6));
    expect(fact(facts, 'fat'), closeTo(0, 1e-6));
  });

  test('My chai with no milk and no sugar is black tea', () async {
    final chai = MyChaiRecipe(recipes: c.recipes, logging: c.recipeLogging);
    final facts = (await chai.preview(
      kLocalNutritionUserScopeId,
      blackTea,
    )).calculation.facts;
    // 150 ml at 1 kcal and 0.3 g carbohydrate per 100 ml.
    expect(fact(facts, 'energy'), closeTo(1.5, 1e-6));
    expect(fact(facts, 'carbohydrate'), closeTo(0.45, 1e-6));
    expect(blackTea.milkMillilitres, 0);
    expect(blackTea.recipeLine, '150 ml black tea + no sugar');

    // Sugar is still added to it.
    await chai.save(
      kLocalNutritionUserScopeId,
      blackTea.copyWith(sugarTeaspoons: 1),
    );
    final sweet = (await chai.preview(
      kLocalNutritionUserScopeId,
      blackTea.copyWith(sugarTeaspoons: 1),
    )).calculation.facts;
    expect(fact(sweet, 'energy'), closeTo(1.5 + 4.2 * 3.87, 0.01));
  });

  test('a no-milk chai saves and reads back', () async {
    final prefs = await SharedPreferences.getInstance();
    await blackTea.write(prefs);
    expect(
      prefs.getString(AppPreferenceKeys.prefMyChaiMilk),
      MyChaiMilk.none.stableId,
    );
    expect(MyChaiSettings.read(prefs), blackTea);
  });

  group('vegan', () {
    test('sees "+ Chai" only when My chai has no milk', () {
      expect(myChaiFitsDiet('vegan', chai: blackTea), isTrue);
      expect(myChaiFitsDiet('vegan', chai: MyChaiSettings.defaults), isFalse);
      expect(myChaiFitsDiet('vegan'), isFalse);
      expect(myChaiFitsDiet('veg', chai: MyChaiSettings.defaults), isTrue);
    });

    test('the offered chai follows that', () async {
      Future<MyChaiSettings?> offered(MyChaiSettings chai) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await chai.write(prefs);
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            userProfileProvider.overrideWith((ref) => _VeganProfile()),
          ],
        );
        addTearDown(container.dispose);
        return container.read(offeredMyChaiProvider);
      }

      expect(await offered(blackTea), blackTea);
      expect(await offered(MyChaiSettings.defaults), isNull);
    });
  });
}

class _VeganProfile extends UserProfileNotifier {
  _VeganProfile() : super() {
    state = const UserProfileState(
      isLoaded: true,
      hasProfile: true,
      calorieGoal: 2000,
      proteinGoal: 100,
      carbsGoal: 250,
      fatGoal: 60,
      currentWeight: 70,
      dietPreference: 'vegan',
    );
  }
}
