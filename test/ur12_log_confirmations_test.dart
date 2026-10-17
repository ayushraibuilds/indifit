import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/catalog/catalogue_quantity_resolver.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/food_log/food_diary_screen.dart';
import 'package:indifit/features/food_log/log_confirmation.dart';
import 'package:indifit/features/food_log/widgets/food_diary_widgets.dart';
import 'package:indifit/features/food_log/widgets/food_portion_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// UR-12, UR-15, UR-16, UR-17: say what was logged, offer Undo, and show
/// the amount and the foods as the user picked them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the amount as picked (UR-16)', () {
    const katoriFood = CatalogueFoodMeasure(
      foodId: 'food-dal',
      displayName: 'Dal',
      basis: 'per_serving',
      unit: 'katori',
      unitsPerServing: null,
      gramsPerServing: null,
      millilitresPerServing: null,
    );
    final dal = CatalogueFoodMeasure(
      foodId: 'food-dal',
      displayName: 'Dal',
      basis: 'per_serving',
      unit: 'katori',
      unitsPerServing: QuantityAmount.one,
      gramsPerServing: QuantityAmount.fromNum(150),
      millilitresPerServing: null,
    );
    final eggs = CatalogueFoodMeasure(
      foodId: 'food-eggs',
      displayName: 'Boiled Eggs (2 pieces)',
      basis: 'per_serving',
      unit: 'piece',
      unitsPerServing: QuantityAmount.fromNum(2),
      gramsPerServing: null,
      millilitresPerServing: null,
    );
    Quantity serving(String foodId, num amount) => Quantity(
      amount: QuantityAmount.fromNum(amount),
      unit: QuantityUnit.serving,
      context: QuantityContext(
        servingDefinition: ServingDefinitionReference(
          id: 'food-serving::$foodId',
          revision: 'b03-food-entry-v1',
          source: 'catalogue',
        ),
      ),
    );

    test('a serving reads as its household amount with grams', () {
      expect(dal.pickedAmountLabel(serving('food-dal', 1)), '1 katori (150 g)');
      expect(
        dal.pickedAmountLabel(serving('food-dal', 1.5)),
        '1.5 katori (225 g)',
      );
      expect(
        dal.pickedAmountLabel(
          Quantity.fromNum(amount: 300, unit: QuantityUnit.gram),
        ),
        '2 katori (300 g)',
      );
      expect(eggs.pickedAmountLabel(serving('food-eggs', 1)), '2 pieces');
    });

    test('an odd amount, or a food without a household unit, falls back', () {
      expect(
        dal.pickedAmountLabel(
          Quantity.fromNum(amount: 110, unit: QuantityUnit.gram),
        ),
        isNull,
      );
      expect(katoriFood.pickedAmountLabel(serving('food-dal', 1)), isNull);
    });
  });

  group('logged rows and confirmations', () {
    late RealCatalogue catalogue;
    late LoggedRecords logged;

    Future<void> pump(
      WidgetTester tester,
      Widget home, {
      bool realRecents = false,
    }) async {
      tester.view.physicalSize = const Size(402, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      catalogue = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, catalogue.db));
      logged = (await tester.runAsync(() => LoggedRecords.log(catalogue)))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: loggedRecordsOverrides(
            catalogue,
            realRecents: realRecents,
          ),
          child: MaterialApp(theme: AppTheme.lightTheme, home: home),
        ),
      );
      await settleLoggedRecords(tester);
    }

    Future<List<NutritionHistoricalReadRecord>> records() async =>
        (await NutritionReadModelRepository(
              db: catalogue.db,
              registry: catalogue.registry,
              canonicalRepository: catalogue.consumption,
              legacyUserId: kLocalNutritionUserScopeId,
            ).dailyTotals(
              userId: kLocalNutritionUserScopeId,
              localDate: loggedRecordsDate,
            ))
            .records;

    testWidgets('the message names the amount, food, kcal and meal', (
      tester,
    ) async {
      await pump(tester, const SizedBox());
      final direct = logged.bySource['direct_food']!;
      final kcal = direct.totals.facts['energy']!.point!.value.format(
        decimalPlaces: 0,
      );
      expect(
        loggedConfirmationMessage(direct, amount: '1 katori (150 g)'),
        'Added 1 katori (150 g) $loggedRecordsDal · $kcal kcal to Lunch',
      );
      expect(
        loggedConfirmationMessage(logged.bySource['thali']!),
        startsWith('Added $loggedRecordsRoti, $loggedRecordsDal · '),
      );
      expect(
        loggedConfirmationMessage(direct, again: true),
        startsWith('Added again: 1 serving $loggedRecordsDal'),
      );
      expect(loggedMealLabel('snack'), 'Snacks');
    });

    testWidgets('the meal page shows the amount as picked', (tester) async {
      await pump(
        tester,
        FoodMealDetailScreen(
          mealType: 'lunch',
          selectedDate: DateTime(2026, 10, 8),
        ),
      );
      expect(find.textContaining('1 katori (150 g)'), findsWidgets);
      expect(find.textContaining('1 serving'), findsNothing);
    });

    testWidgets('the portion sheet confirms with Undo, and Undo removes it', (
      tester,
    ) async {
      await pump(
        tester,
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final option = (await catalogue.catalog.getOption(
                    await catalogue.foodId(loggedRecordsDal),
                  ))!;
                  if (!context.mounted) return;
                  await FoodPortionBottomSheet.show(
                    context,
                    ref: ref,
                    option: option,
                    mealType: 'snack',
                    targetDate: DateTime(2026, 10, 8),
                    ensureMealContext: () async => 'snack',
                  );
                },
                child: const Text('Open sheet'),
              ),
            ),
          ),
        ),
      );
      final before = (await tester.runAsync(records))!.length;
      await tester.tap(find.text('Open sheet'));
      await settleLoggedRecords(tester, rounds: 10);
      await tester.tap(find.text('Add to Snacks'));
      await settleLoggedRecords(tester, rounds: 10);

      expect(
        find.textContaining(
          RegExp(
            r'^Added 1 katori \(150 g\) Toor Dal / Yellow Dal Tadka · \d+ kcal to Snacks$',
          ),
        ),
        findsOneWidget,
      );
      expect((await tester.runAsync(records))!.length, before + 1);
      await tester.tap(find.text('Undo'));
      await settleLoggedRecords(tester, rounds: 10);
      expect((await tester.runAsync(records))!.length, before);
    });

    testWidgets('a repeat chip says it logs again, and offers Undo', (
      tester,
    ) async {
      await pump(
        tester,
        FoodDiaryScreen(
          selectedDate: DateTime(2026, 10, 8),
          today: DateTime(2026, 10, 8),
        ),
        realRecents: true,
      );
      expect(find.text('Again?'), findsWidgets);
      final chip = find.byType(ActionChip).first;
      final before = (await tester.runAsync(records))!.length;
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await settleLoggedRecords(tester, rounds: 10);
      expect(find.textContaining('Added again: '), findsOneWidget);
      expect((await tester.runAsync(records))!.length, before + 1);
      await tester.tap(find.text('Undo'));
      await settleLoggedRecords(tester, rounds: 10);
      expect((await tester.runAsync(records))!.length, before);
    });
  });

  group("Today's meal rows name the food (UR-17)", () {
    late RealCatalogue catalogue;
    setUp(() async => catalogue = await RealCatalogue.open());
    tearDown(() => catalogue.close());

    test('one food, two foods, many foods, and none', () async {
      await LoggedRecords.log(catalogue, only: {'direct_food', 'thali'});
      final daily =
          await NutritionReadModelRepository(
            db: catalogue.db,
            registry: catalogue.registry,
            canonicalRepository: catalogue.consumption,
            legacyUserId: kLocalNutritionUserScopeId,
          ).dailyTotals(
            userId: kLocalNutritionUserScopeId,
            localDate: loggedRecordsDate,
          );
      final meals = TodayNutritionPresentation.from(
        TodayDomainRead.available(daily),
        loading: false,
      ).meals;
      final lunch = meals.firstWhere((meal) => meal.mealType == 'lunch');
      // Three foods: the dal, and the thali's roti and dal.
      expect(lunch.detail, matches(RegExp(r'^[^,]+, [^,]+ \+1$')));
      expect(lunch.detail, contains(loggedRecordsRoti));
      final dinner = meals.firstWhere((meal) => meal.mealType == 'dinner');
      expect(dinner.detail, 'Nothing yet');
      expect(dinner.calorieLabel, isEmpty);
    });
  });
}
