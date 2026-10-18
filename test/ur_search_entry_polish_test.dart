import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/catalog/katori_size.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/services/food_search_pipeline.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:indifit/features/food_log/food_staple_suggestions.dart';
import 'package:indifit/features/food_log/katori_size_step.dart';
import 'package:indifit/features/food_log/liquid_servings.dart';
import 'package:indifit/features/food_log/meal_presentation_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/indifit_test_harness.dart';
import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// Step 7 of the 17 Oct user-readiness review: meal-aware starter chips
/// (UR-31), zero-result exits (UR-33), the meal picked by time of day
/// (UR-27) and liquid units with "My glass" (UR-09).
void main() {
  group('starter chips by meal and diet (UR-31)', () {
    test('breakfast', () {
      expect(foodStapleSuggestions(mealType: 'breakfast', diet: 'veg'), [
        'Poha',
        'Idli',
        'Paratha',
        'Upma',
        'Chai',
      ]);
      expect(
        foodStapleSuggestions(mealType: 'breakfast', diet: 'eggetarian'),
        contains('Eggs'),
      );
      expect(
        foodStapleSuggestions(mealType: 'breakfast', diet: 'non-veg'),
        contains('Eggs'),
      );
      expect(
        foodStapleSuggestions(mealType: 'breakfast', diet: 'vegan'),
        isNot(anyOf(contains('Eggs'), contains('Chai'))),
      );
    });

    test('snacks', () {
      for (final meal in ['snack', 'evening_snack', 'morning_snack']) {
        expect(foodStapleSuggestions(mealType: meal, diet: 'veg'), [
          'Chai',
          'Biscuit',
          'Fruit',
          'Namkeen',
          'Chana',
        ]);
      }
    });

    test('lunch and dinner keep the everyday plate', () {
      expect(
        foodStapleSuggestions(mealType: 'lunch', diet: 'veg').first,
        'Roti',
      );
      expect(
        foodStapleSuggestions(mealType: 'dinner', diet: 'non-veg'),
        contains('Chicken'),
      );
      expect(foodStapleSuggestions(), contains('Dal'));
    });

    group('every chip finds a food', () {
      initializeIndiFitTestHarness();
      late RealCatalogue catalogue;
      setUpAll(() async => catalogue = await RealCatalogue.open());
      tearDownAll(() => catalogue.close());

      test('on the shipped catalogue', () async {
        final pipeline = FoodSearchPipeline(
          FoodRepository(catalogue.db),
          optionFor: catalogue.catalog.getOption,
        );
        final chips = {
          for (final meal in ['breakfast', 'lunch', 'snack', 'dinner'])
            for (final diet in ['veg', 'non-veg', 'vegan', 'eggetarian'])
              ...foodStapleSuggestions(mealType: meal, diet: diet),
        };
        for (final chip in chips) {
          final (_, ranked) = await pipeline.search(chip);
          expect(ranked, isNotEmpty, reason: chip);
        }
      });
    });
  });

  group('zero results (UR-33)', () {
    testWidgets('offers quick add and, with AI, describe', (tester) async {
      var quick = 0;
      var describe = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchNoResultsState(
              onCreateCustomFood: () {},
              onQuickAdd: () => quick++,
              onDescribe: () => describe++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Quick add calories'));
      await tester.tap(find.text('Describe it instead'));
      expect((quick, describe), (1, 1));
      expect(find.text('Create a custom food'), findsOneWidget);
    });

    testWidgets('without AI, no describe', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodSearchNoResultsState(
              onCreateCustomFood: () {},
              onQuickAdd: () {},
            ),
          ),
        ),
      );
      expect(find.text('Quick add calories'), findsOneWidget);
      expect(find.text('Describe it instead'), findsNothing);
    });
  });

  group('screens', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUp(
      () => SharedPreferences.setMockInitialValues({
        PrivacyPolicyNotifier.prefOnlineNutritionAllowed: false,
      }),
    );

    late RealCatalogue catalogue;

    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      catalogue = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, catalogue.db));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...loggedRecordsOverrides(catalogue),
            foodRepositoryProvider.overrideWithValue(
              FoodRepository(catalogue.db),
            ),
          ],
          child: MaterialApp(theme: AppTheme.lightTheme, home: home),
        ),
      );
      await settleLoggedRecords(tester);
    }

    testWidgets('a search with no match pre-fills quick add (UR-33)', (
      tester,
    ) async {
      await pump(
        tester,
        FoodSearchScreen(
          mealType: 'lunch',
          selectedDate: DateTime(2026, 10, 8),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'qzxv food');
      await tester.pump(const Duration(milliseconds: 800));
      await settleLoggedRecords(tester, rounds: 20);
      expect(find.text('Describe it instead'), findsNothing); // AI is off
      await tester.tap(find.text('Quick add calories'));
      await settleLoggedRecords(tester, rounds: 8);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(TextField, 'qzxv food'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('breakfast starter chips (UR-31)', (tester) async {
      await pump(
        tester,
        FoodSearchScreen(
          mealType: 'breakfast',
          selectedDate: DateTime(2026, 10, 8),
        ),
      );
      expect(find.widgetWithText(ActionChip, 'Poha'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Roti'), findsNothing);
    });

    testWidgets('Add food picks the meal for now, one tap to change (UR-27)', (
      tester,
    ) async {
      await pump(
        tester,
        FoodDiaryScreen(
          selectedDate: DateTime(2026, 10, 8),
          today: DateTime(2026, 10, 8),
          now: () => DateTime(2026, 10, 8, 13, 5),
        ),
      );
      await tester.tap(find.text('Add food').first);
      await settleLoggedRecords(tester, rounds: 10);
      expect(find.text('Log lunch'), findsOneWidget);
      expect(find.text('Choose a meal'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('food_search_change_meal')));
      await settleLoggedRecords(tester, rounds: 6);
      await tester.tap(find.text('Dinner').last);
      await settleLoggedRecords(tester, rounds: 10);
      expect(find.text('Log dinner'), findsOneWidget);
    });

    testWidgets('the thali builder opens on the meal for now (UR-27)', (
      tester,
    ) async {
      await pump(
        tester,
        FoodDiaryScreen(
          selectedDate: DateTime(2026, 10, 8),
          today: DateTime(2026, 10, 8),
          now: () => DateTime(2026, 10, 8, 8, 30),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Thali builder'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Thali builder'));
      await settleLoggedRecords(tester, rounds: 10);
      expect(find.text('Breakfast Thali'), findsOneWidget);
      expect(find.byKey(const Key('thali_change_meal')), findsOneWidget);
    });

    testWidgets('My glass is saved like My katori (UR-09)', (tester) async {
      await pump(tester, const Scaffold(body: GlassSizeChoice()));
      await tester.tap(find.byKey(const Key('glass_size_300')));
      await settleLoggedRecords(tester, rounds: 6);
      expect(
        await tester.runAsync(() => readMyGlassMillilitres(catalogue.db)),
        300,
      );
      // The katori is a different vessel and stays unset.
      expect(
        await tester.runAsync(() => readMyKatoriMillilitres(catalogue.db)),
        isNull,
      );
    });
  });

  group('liquids offer ml, glass and cup (UR-09)', () {
    initializeIndiFitTestHarness();
    late RealCatalogue catalogue;
    setUpAll(() async => catalogue = await RealCatalogue.open());
    tearDownAll(() => catalogue.close());

    Future<List<String>?> labels(String food, {double? myGlass}) async {
      final option = (await catalogue.catalog.getOption(
        await catalogue.foodId(food),
      ))!;
      return liquidServingChips(
        option,
        myGlassMillilitres: myGlass,
      )?.map((chip) => chip.label).toList();
    }

    test('a drink measured per 100 ml', () async {
      expect(await labels('Banana Shake'), [
        '1 cup · 150 ml',
        '1 glass · 250 ml',
        '100 ml',
      ]);
      expect(
        await labels('Banana Shake', myGlass: 300),
        contains('My glass · 300 ml'),
      );
    });

    test('a drink counted in glasses or cups', () async {
      expect(await labels('Toned Milk (1 Glass)'), [
        '½ glass',
        '1 glass',
        '2 glasses',
      ]);
      expect(await labels('Masala Chai (with milk & sugar)'), [
        '½ cup',
        '1 cup',
        '2 cups',
      ]);
    });

    test('not a drink: no liquid chips', () async {
      expect(await labels('Toor Dal / Yellow Dal Tadka'), isNull);
      expect(await labels('Banana'), isNull);
    });

    test('the meal for a time follows the diary slots (UR-27)', () {
      final slots = MealPresentationRegistry.values;
      String at(int hour, [List<FoodMealPresentation>? only]) =>
          MealPresentationRegistry.forLocalTimeIn(
            DateTime(2026, 10, 8, hour),
            only ?? slots,
          ).stableId;
      expect(at(8), 'breakfast');
      expect(at(13), 'lunch');
      expect(at(17), 'snack');
      expect(at(21), 'dinner');
      final noSnack = [
        for (final slot in slots)
          if (slot.stableId != 'snack') slot,
      ];
      expect(at(17, noSnack), isNot('snack'));
      expect(kStandardGlassMillilitres, 250);
    });
  });
}
