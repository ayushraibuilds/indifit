import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/features/dashboard/protein_nudge.dart';
import 'package:indifit/features/dashboard/what_can_i_eat.dart';
import 'package:indifit/features/dashboard/widgets/what_can_i_eat_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// TF-2 A: "What can I eat?" — what is left today and foods that fit it,
/// on the protein nudge's rules.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProteinSuggestion food(
    String name,
    double protein,
    double kcal, {
    String? category = 'Vegetables & Sabjis',
    bool history = false,
  }) => ProteinSuggestion(
    foodId: name,
    name: name,
    quantity: Quantity.fromNum(amount: 1, unit: QuantityUnit.piece),
    amountLabel: '1 katori',
    proteinGrams: protein,
    kcal: kcal,
    fromHistory: history,
    category: category,
  );

  ProteinCandidates found(
    List<ProteinSuggestion> foods, {
    String diet = 'veg',
  }) => (candidates: foods, conflicts: <String>{}, diet: diet);

  WhatCanIEatPlan plan({
    double? kcalTarget = 2000,
    double kcalEaten = 900,
    double? proteinTarget = 120,
    double proteinEaten = 60,
  }) => WhatCanIEat.plan(
    kcalTarget: kcalTarget,
    kcalEaten: kcalEaten,
    proteinTarget: proteinTarget,
    proteinEaten: proteinEaten,
  );

  group('the plan', () {
    test('says what is left', () {
      expect(plan().status, WhatCanIEatStatus.open);
      expect(plan().headline, '1,100 kcal · 60 g protein left');
      expect(plan(proteinTarget: null).headline, '1,100 kcal left');
      expect(plan(proteinEaten: 130).headline, '1,100 kcal · 0 g protein left');
    });

    test('needs a calorie target', () {
      final none = plan(kcalTarget: null);
      expect(none.status, WhatCanIEatStatus.noTargets);
      expect(none.headline, 'Set targets to see suggestions');
      expect(none.kcalCap, isNull);
      expect(WhatCanIEat.pick(found([food('Dal', 18, 200)]), none), isEmpty);
    });

    test('over target offers only foods of 150 kcal or less', () {
      final over = plan(kcalEaten: 2100);
      expect(over.status, WhatCanIEatStatus.over);
      expect(over.headline, "You're over today; lighter options:");
      expect(over.kcalCap, WhatCanIEat.lighterKcal);
      final picked = WhatCanIEat.pick(
        found([food('Moong Dal', 12, 140), food('Paneer Bhurji', 16, 290)]),
        over,
      );
      expect(picked.map((s) => s.name), ['Moong Dal']);
      expect(
        WhatCanIEat.pick(found([food('Paneer Bhurji', 16, 290)]), over),
        isEmpty,
      );
    });
  });

  group('picking', () {
    test('fits the calories left', () {
      final picked = WhatCanIEat.pick(
        found([food('Small', 10, 120), food('Big', 40, 600)]),
        plan(kcalEaten: 1500), // 500 left
      );
      expect(picked.map((s) => s.name), ['Small']);
    });

    test('recents first, then staples, at most five', () {
      final picked = WhatCanIEat.pick(
        found([
          for (var i = 0; i < 4; i++) food('Staple $i', 20, 150),
          food('Mine', 10, 160, history: true),
          food('Mine 2', 9, 140, history: true),
        ]),
        plan(),
      );
      expect(picked, hasLength(WhatCanIEat.maxSuggestions));
      expect(
        picked.take(2).map((s) => s.name),
        unorderedEquals(['Mine', 'Mine 2']),
      );
    });

    test('keeps the protein-density floor', () {
      expect(
        WhatCanIEat.pick(found([food('Biscuits', 3, 300)]), plan()),
        isEmpty,
      );
    });

    test('vegetarian, Jain and vegan filters', () {
      final foods = [
        food('Chicken Curry', 25, 300, category: 'Non-Veg'),
        food('Egg Bhurji', 14, 200, category: 'Healthy & Salads'),
        food('Paneer Tikka', 18, 250, category: 'Paneer & Dairy'),
        food('Aloo Chana', 12, 200, category: 'Dals & Legumes'),
        food('Moong Dal', 12, 180, category: 'Dals & Legumes'),
      ];
      List<String> names(String diet) => WhatCanIEat.pick(
        found(foods, diet: diet),
        plan(),
      ).map((s) => s.name).toList();
      expect(names('veg'), isNot(contains('Chicken Curry')));
      expect(names('veg'), isNot(contains('Egg Bhurji')));
      expect(names('veg'), contains('Paneer Tikka'));
      expect(names('jain'), isNot(contains('Aloo Chana')));
      expect(names('jain'), contains('Moong Dal'));
      expect(names('vegan'), unorderedEquals(['Aloo Chana', 'Moong Dal']));
    });

    test('skips foods with a constraint conflict', () {
      final candidates = (
        candidates: [food('Moong Dal', 12, 180)],
        conflicts: {'Moong Dal'},
        diet: 'veg',
      );
      expect(WhatCanIEat.pick(candidates, plan()), isEmpty);
    });
  });

  group('the sheet', () {
    Future<void> open(
      WidgetTester tester,
      WhatCanIEatPlan plan,
      List<ProteinSuggestion> suggestions, {
      List<Override> overrides = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            whatCanIEatSuggestionsProvider.overrideWith(
              (ref, plan) async => suggestions,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showWhatCanIEatSheet(
                    context,
                    plan: plan,
                    day: DateTime.now(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists suggestions with amount, kcal, protein and Add', (
      tester,
    ) async {
      await open(tester, plan(), [food('Moong Dal', 12, 180)]);
      expect(find.text('1,100 kcal · 60 g protein left'), findsOneWidget);
      expect(find.text('Moong Dal'), findsOneWidget);
      expect(find.text('1 katori · 180 kcal · 12 g protein'), findsOneWidget);
      expect(find.text('+ Add'), findsOneWidget);
    });

    testWidgets('with no targets asks for them', (tester) async {
      await open(tester, plan(kcalTarget: null), [food('Moong Dal', 12, 180)]);
      expect(find.text('Set targets to see suggestions'), findsOneWidget);
      expect(find.text('+ Add'), findsNothing);
    });

    testWidgets('over target with nothing light shows nothing', (tester) async {
      await open(tester, plan(kcalEaten: 2100), const []);
      expect(find.text("You're over today."), findsOneWidget);
      expect(find.text('+ Add'), findsNothing);
    });

    testWidgets('Add logs the food, closes the sheet and offers Undo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, c.db));
      const name = 'Moong Dal Chilka (Cooked)';
      final foodId = (await tester.runAsync(() => c.foodId(name)))!;
      final option = (await tester.runAsync(
        () => c.catalog.getOption(foodId),
      ))!;
      final suggestion = ProteinSuggestion(
        foodId: foodId,
        name: name,
        quantity: option.defaultLoggingQuantity,
        amountLabel: '1 katori',
        proteinGrams: 12,
        kcal: 180,
        fromHistory: false,
      );
      final readModels = NutritionReadModelRepository(
        db: c.db,
        registry: c.registry,
        canonicalRepository: c.consumption,
      );
      // The add logs on today's date in the logging timezone (IST), which
      // on a UTC runner after 18:30 is not the runner's date.
      final localDate = LocalScheduleDateService().localDateFor(
        DateTime.now(),
        loggedRecordsTimezone,
      );
      Future<int> loggedToday() async => (await readModels.dailyTotals(
        userId: kLocalNutritionUserScopeId,
        localDate: localDate,
      )).records.length;

      await open(tester, plan(), [
        suggestion,
      ], overrides: loggedRecordsOverrides(c));
      await tester.tap(find.text('+ Add'));
      await settleLoggedRecords(tester, rounds: 10);
      expect(find.byKey(const Key('what_can_i_eat_sheet')), findsNothing);
      expect(find.text('Undo'), findsOneWidget);
      expect((await tester.runAsync(loggedToday))!, 1);

      await tester.tap(find.text('Undo'));
      await settleLoggedRecords(tester, rounds: 10);
      expect((await tester.runAsync(loggedToday))!, 0);
    });
  });
}
