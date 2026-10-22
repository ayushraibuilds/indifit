import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionThaliItem;
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/features/dashboard/widgets/today_meal_quick_adds.dart';
import 'package:indifit/features/food_log/my_chai.dart';
import 'package:indifit/features/food_log/my_roti.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// UF-2 My chai and UF-3 the roti counter.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('My chai facts', () {
    late RealCatalogue c;
    late MyChaiRecipe chai;
    setUp(() async {
      c = await RealCatalogue.open();
      chai = MyChaiRecipe(recipes: c.recipes, logging: c.recipeLogging);
    });
    tearDown(() => c.close());

    double fact(Map<String, dynamic> facts, String id) =>
        (facts[id] as dynamic).point.value.asDouble as double;

    test('the catalogue has the pack 6 sugar and milks', () async {
      expect(await c.foodId('Sugar'), kMyChaiSugarFoodId);
      for (final milk in MyChaiMilk.values) {
        expect(await c.catalog.getOption(milk.foodId), isNotNull);
      }
    });

    test('a cup is the milk and sugar, from catalogue facts', () async {
      const toned = MyChaiSettings(
        milk: MyChaiMilk.toned,
        milkShare: MyChaiMilkShare.half,
        sugarTeaspoons: 1,
        cupMillilitres: 150,
      );
      expect(toned.milkMillilitres, 75);
      expect(toned.sugarGrams, closeTo(4.2, 1e-9));
      final preview = await chai.preview(kLocalNutritionUserScopeId, toned);
      final facts = preview.calculation.facts;
      // 75 ml toned milk at 61 kcal/100 ml + 4.2 g sugar at 387 kcal/100 g.
      expect(fact(facts, 'energy'), closeTo(75 * 0.61 + 4.2 * 3.87, 0.01));
      expect(fact(facts, 'protein'), closeTo(75 * 0.0315, 0.01));
      expect(
        fact(facts, 'carbohydrate'),
        closeTo(75 * 0.048 + 4.2 * 0.9998, 0.01),
      );
    });

    test('changing the chai publishes a new version of one recipe', () async {
      const first = MyChaiSettings(
        milk: MyChaiMilk.toned,
        milkShare: MyChaiMilkShare.third,
        sugarTeaspoons: 2,
        cupMillilitres: 150,
      );
      final id = await chai.save(kLocalNutritionUserScopeId, first);
      final changed = first.copyWith(
        milk: MyChaiMilk.fullCream,
        milkShare: MyChaiMilkShare.all,
        cupMillilitres: 200,
      );
      expect(await chai.save(kLocalNutritionUserScopeId, changed), id);
      final facts = (await chai.preview(
        kLocalNutritionUserScopeId,
        changed,
      )).calculation.facts;
      expect(fact(facts, 'energy'), closeTo(200 * 0.97 + 8.4 * 3.87, 0.01));
      final mine = (await c.recipes.listRecipes(
        userId: kLocalNutritionUserScopeId,
      )).where((r) => r.id.startsWith(kMyChaiRecipePrefix));
      expect(mine, hasLength(1));
    });

    test('no sugar logs the milk alone', () async {
      const plain = MyChaiSettings(
        milk: MyChaiMilk.skimmed,
        milkShare: MyChaiMilkShare.half,
        sugarTeaspoons: 0,
        cupMillilitres: 100,
      );
      final facts = (await chai.preview(
        kLocalNutritionUserScopeId,
        plain,
      )).calculation.facts;
      expect(fact(facts, 'energy'), closeTo(50 * 0.34, 0.01));
      expect(plain.recipeLine, contains('no sugar'));
    });

    test('black tea is just the sugar (R-10)', () async {
      const black = MyChaiSettings(
        milk: MyChaiMilk.toned,
        milkShare: MyChaiMilkShare.none,
        sugarTeaspoons: 1,
        cupMillilitres: 150,
      );
      expect(black.milkMillilitres, 0);
      expect(black.hasMilk, isFalse);
      expect(black.recipeLine, 'Black tea, 150 ml, 1 tsp sugar (4.2 g)');
      final facts = (await chai.preview(
        kLocalNutritionUserScopeId,
        black,
      )).calculation.facts;
      expect(fact(facts, 'energy'), closeTo(4.2 * 3.87, 0.01));
      expect(fact(facts, 'protein'), closeTo(0, 0.001));
    });

    test('black tea without sugar is not a saved chai', () async {
      final prefs = await SharedPreferences.getInstance();
      await const MyChaiSettings(
        milk: MyChaiMilk.toned,
        milkShare: MyChaiMilkShare.none,
        sugarTeaspoons: 0,
        cupMillilitres: 150,
      ).write(prefs);
      expect(MyChaiSettings.read(prefs), isNull);
    });

    test('a logged cup is one item whose facts include the sugar', () async {
      const toned = MyChaiSettings(
        milk: MyChaiMilk.toned,
        milkShare: MyChaiMilkShare.half,
        sugarTeaspoons: 1,
        cupMillilitres: 150,
      );
      final snapshot = await chai.log(
        userId: kLocalNutritionUserScopeId,
        chai: toned,
        mealCategory: 'snack',
        loggedAtUtc: DateTime.utc(2026, 10, 8, 10),
        localDate: loggedRecordsDate,
        timezoneId: loggedRecordsTimezone,
      );
      expect(snapshot.items, hasLength(1));
      expect(snapshot.items.single.displayLabel, kMyChaiName);
      expect(
        snapshot.totals.facts['energy']!.point!.value.asDouble,
        closeTo(75 * 0.61 + 4.2 * 3.87, 0.01),
      );
    });
  });

  test('the recipe line says what is in the cup', () {
    expect(
      MyChaiSettings.defaults.recipeLine,
      '75 ml toned milk + 1 tsp sugar (4.2 g), topped up with tea to 150 ml',
    );
    expect(
      MyChaiSettings.defaults
          .copyWith(milkShare: MyChaiMilkShare.all, sugarTeaspoons: 1.5)
          .recipeLine,
      '150 ml toned milk + 1.5 tsp sugar (6.3 g), brewed in the milk',
    );
  });

  group('settings', () {
    test('My chai and My roti read back what was written', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(MyChaiSettings.read(prefs), isNull);
      expect(MyRoti.read(prefs), isNull);
      const chai = MyChaiSettings(
        milk: MyChaiMilk.doubleToned,
        milkShare: MyChaiMilkShare.third,
        sugarTeaspoons: 1.5,
        cupMillilitres: 200,
      );
      await chai.write(prefs);
      await MyRoti.tandoori.write(prefs);
      expect(MyChaiSettings.read(prefs), chai);
      expect(MyRoti.read(prefs), MyRoti.tandoori);
    });

    test('they round-trip through a backup and restore', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final prefs = await SharedPreferences.getInstance();
      const chai = MyChaiSettings(
        milk: MyChaiMilk.fullCream,
        milkShare: MyChaiMilkShare.half,
        sugarTeaspoons: 2,
        cupMillilitres: 150,
      );
      await chai.write(prefs);
      await MyRoti.phulka.write(prefs);

      final backup = await BackupData.createFromDatabase(db, prefs);
      final restored = BackupData.fromJson(backup.toJson());

      SharedPreferences.setMockInitialValues({});
      final fresh = await SharedPreferences.getInstance();
      expect(MyChaiSettings.read(fresh), isNull);
      await restored.restoreToDatabase(db, fresh);
      expect(MyChaiSettings.read(fresh), chai);
      expect(MyRoti.read(fresh), MyRoti.phulka);
    });
  });

  group('+1 roti', () {
    late RealCatalogue c;
    setUp(() async => c = await RealCatalogue.open());
    tearDown(() => c.close());

    Future<void> logFood(String name, String meal) async {
      final foods = LoggedRecords.coordinatorFor(c);
      final option = (await c.catalog.getOption(await c.foodId(name)))!;
      await foods.finalize(
        userId: kLocalNutritionUserScopeId,
        preview: await foods.preview(
          option: option,
          quantity: option.defaultLoggingQuantity,
        ),
        mealCategory: meal,
        loggedAt: DateTime.utc(2026, 10, 8, 7),
        localDate: loggedRecordsDate,
        timezoneId: loggedRecordsTimezone,
        commandId: 'roti-$name-$meal',
        consumptionId: 'roti-$name-$meal',
      );
    }

    Future<List<NutritionHistoricalReadRecord>> records() async =>
        (await NutritionReadModelRepository(
              db: c.db,
              registry: c.registry,
              canonicalRepository: c.consumption,
              legacyUserId: kLocalNutritionUserScopeId,
            ).dailyTotals(
              userId: kLocalNutritionUserScopeId,
              localDate: loggedRecordsDate,
            ))
            .records;

    test('a mixed meal offers its roti', () async {
      await logFood(loggedRecordsDal, 'lunch');
      await logFood(loggedRecordsRoti, 'lunch');
      await logFood(loggedRecordsDal, 'dinner');
      final all = await records();
      expect(rotiInMeal(all, 'lunch')!.displayLabel, loggedRecordsRoti);
      expect(rotiInMeal(all, 'dinner'), isNull);
    });

    test('a thali with roti offers it; a plated thali food does not', () async {
      final rotiId = await c.foodId(loggedRecordsRoti);
      final draft = await c.thali.saveDraft(
        c.thali.newDraft(
          userId: kLocalNutritionUserScopeId,
          name: 'Lunch plate',
          items: [
            NutritionThaliItem(
              id: 'plate-roti',
              position: 0,
              source: NutritionThaliItemSource.food,
              foodId: rotiId,
              recipeVersionId: null,
              quantity: Quantity.fromNum(amount: 2, unit: QuantityUnit.piece),
              displayLabel: loggedRecordsRoti,
            ),
          ],
        ),
      );
      await c.thali.finalize(
        preview: await c.thali.preview(draft: draft),
        mealCategory: 'lunch',
        loggedAt: DateTime.utc(2026, 10, 8, 7),
        commandId: 'plate',
        localDate: loggedRecordsDate,
        timezoneId: loggedRecordsTimezone,
        allowPartial: true,
      );
      await logFood('Home Thali (Veg) — 2 Roti + Dal + Sabji + Curd', 'dinner');
      final all = await records();
      final roti = rotiInMeal(all, 'lunch')!;
      expect(roti.foodId, rotiId);
      expect(rotiInMeal(all, 'dinner'), isNull);
    });

    testWidgets('Today adds one more roti, with Undo', (tester) async {
      final c = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, c.db));
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      final localDate =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      final rotiId = (await tester.runAsync(
        () => c.foodId(loggedRecordsRoti),
      ))!;
      Future<List<NutritionHistoricalReadRecord>> lunch() async =>
          (await NutritionReadModelRepository(
                db: c.db,
                registry: c.registry,
                canonicalRepository: c.consumption,
                legacyUserId: kLocalNutritionUserScopeId,
              ).dailyTotals(
                userId: kLocalNutritionUserScopeId,
                localDate: localDate,
              ))
              .records
              .where((r) => r.mealCategory == 'lunch')
              .toList();
      await tester.runAsync(() async {
        final foods = LoggedRecords.coordinatorFor(c);
        final option = (await c.catalog.getOption(rotiId))!;
        await foods.finalize(
          userId: kLocalNutritionUserScopeId,
          preview: await foods.preview(
            option: option,
            quantity: option.defaultLoggingQuantity,
          ),
          mealCategory: 'lunch',
          loggedAt: DateTime.now().toUtc(),
          localDate: localDate,
          timezoneId: loggedRecordsTimezone,
          commandId: 'first-roti',
          consumptionId: 'first-roti',
        );
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: loggedRecordsOverrides(c),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: TodayMealQuickAdds(mealType: 'lunch', selectedDate: day),
            ),
          ),
        ),
      );
      await settleLoggedRecords(tester);
      expect(find.text('+1 roti'), findsOneWidget);
      expect(find.text('+ Chai'), findsNothing);

      await tester.tap(find.text('+1 roti'));
      await settleLoggedRecords(tester, rounds: 10);
      final after = (await tester.runAsync(lunch))!;
      expect(after, hasLength(2));
      expect(after.every((r) => r.items.single.foodId == rotiId), isTrue);
      expect(find.textContaining('Added again:'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settleLoggedRecords(tester, rounds: 10);
      expect((await tester.runAsync(lunch))!, hasLength(1));
    });

    testWidgets('"+ Chai" shows on the snack row once My chai is set', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
      final c = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, c.db));
      await tester.runAsync(() => MyChaiSettings.defaults.write(prefs));
      final day = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...loggedRecordsOverrides(c),
            sharedPreferencesProvider.overrideWithValue(prefs),
            nutritionRecipeRepositoryProvider.overrideWithValue(c.recipes),
            nutritionRecipeLogCoordinatorProvider.overrideWith(
              (ref) async => c.recipeLogging,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  TodayMealQuickAdds(mealType: 'snack', selectedDate: day),
                  TodayMealQuickAdds(mealType: 'lunch', selectedDate: day),
                ],
              ),
            ),
          ),
        ),
      );
      await settleLoggedRecords(tester);
      expect(find.text('+ Chai'), findsOneWidget);
      await tester.tap(find.text('+ Chai'));
      await settleLoggedRecords(tester, rounds: 12);
      expect(
        find.textContaining(
          RegExp(r'^Added 1 cup My chai · \d+ kcal to Snacks'),
        ),
        findsOneWidget,
      );
    });
  });
}
