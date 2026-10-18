import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/services/food_dish_group_loader.dart';
import 'package:indifit/data/services/food_dish_groups.dart';
import 'package:indifit/data/services/food_search_pipeline.dart';
import 'package:indifit/features/food_log/food_diary_screen.dart';
import 'package:indifit/features/food_log/widgets/food_portion_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'food_search_everyday_queries_test.dart' show everydayFirstResult;
import 'support/indifit_test_harness.dart';
import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

const _poha = 'Poha (Flattened Rice)';
const _pohaDouble = 'Poha (Flattened Rice) (Double healthy bowl)';

/// Searches that name a variant, and the variant they lead with.
const _namedVariants = {
  'double poha': _pohaDouble,
  'poha double': _pohaDouble,
  'dhaba jeera aloo': 'Jeera Aloo (Dhaba Style (High oil))',
  'low oil jeera aloo': 'Jeera Aloo (Low Oil cooking)',
  'mini aloo paratha': 'Aloo Paratha (Mini)',
  'jumbo aloo paratha': 'Aloo Paratha (Jumbo / Large)',
};

/// UR-05 / UF-4: one search row per dish; size and oil are chips in the
/// portion sheet, and each chip logs its own food.
void main() {
  group('one row per dish', () {
    initializeIndiFitTestHarness();

    late RealCatalogue catalogue;
    late FoodSearchPipeline pipeline;

    setUpAll(() async {
      catalogue = await RealCatalogue.open();
      pipeline = FoodSearchPipeline(
        FoodRepository(catalogue.db),
        optionFor: catalogue.catalog.getOption,
      );
    });
    tearDownAll(() => catalogue.close());

    test('no search lists two rows of one dish', () async {
      final queries = {
        ...everydayFirstResult.keys,
        ..._namedVariants.keys,
        'paratha',
        'dal',
        'chai',
        'rice',
        'paneer',
      };
      for (final query in queries) {
        final (_, ranked) = await pipeline.search(query);
        final dishes = <String>{};
        for (final result in ranked) {
          final candidate = result.candidate;
          final dish =
              candidate.variantOfFoodId ?? candidate.canonicalIdentityId;
          if (dish == null) continue;
          expect(
            dishes.add(dish),
            isTrue,
            reason: '"$query" lists ${candidate.displayName} twice',
          );
        }
      }
    });

    test('a plain search shows the dish, not a variant', () async {
      for (final query in [
        'poha',
        'jeera aloo',
        'aloo paratha',
        'dal makhani',
      ]) {
        final (_, ranked) = await pipeline.search(query);
        expect(ranked.first.candidate.variantOfFoodId, isNull, reason: query);
      }
    });

    test('a search that names a variant shows that variant', () async {
      for (final MapEntry(key: query, value: name) in _namedVariants.entries) {
        final (_, ranked) = await pipeline.search(query);
        expect(ranked.first.candidate.displayName, name, reason: query);
      }
    });

    test('the dish group has only the chips that exist', () async {
      final loader = FoodDishGroupLoader(catalogue.db, catalogue.catalog);
      final paratha = (await loader.load(
        await catalogue.foodId('Aloo Paratha'),
      ))!;
      expect(
        [for (final choice in paratha.sizes) choice.chip.label],
        ['Mini', 'Regular', 'Double', 'Jumbo'],
      );
      final aloo = (await loader.load(await catalogue.foodId('Jeera Aloo')))!;
      expect(aloo.sizes, isEmpty);
      expect(
        [for (final choice in aloo.oils) choice.chip.label],
        ['Low oil', 'Home', 'Dhaba / extra ghee'],
      );
      // A variant opens the same group, with itself selected.
      final dhaba = await catalogue.foodId(
        'Jeera Aloo (Dhaba Style (High oil))',
      );
      final fromVariant = (await loader.load(dhaba))!;
      expect(fromVariant.base.displayName, 'Jeera Aloo');
      expect(
        fromVariant.selectionFor(dhaba).oil?.chip.label,
        'Dhaba / extra ghee',
      );
      // Most foods have no variants.
      expect(await loader.load(await catalogue.foodId('Banana')), isNull);
    });

    test('labels map to chips', () {
      expect(FoodDishGroups.labelOf(_pohaDouble, _poha), 'Double healthy bowl');
      expect(FoodDishGroups.chipFor('Double healthy bowl')?.label, 'Double');
      expect(
        FoodDishGroups.chipFor('Diet prep (Low oil / breast only)')?.label,
        'Low oil',
      );
      expect(
        FoodDishGroups.chipFor('Premium ghee / extra oil')?.axis,
        DishVariantAxis.oil,
      );
      expect(FoodDishGroups.labelOf('Poha', _poha), isNull);
    });
  });

  group('portion sheet chips', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUp(() => SharedPreferences.setMockInitialValues({}));

    late RealCatalogue catalogue;

    Future<void> openSheet(WidgetTester tester, String food) async {
      tester.view.physicalSize = const Size(402, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      catalogue = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, catalogue.db));
      final option = (await tester.runAsync(
        () async => catalogue.catalog.getOption(await catalogue.foodId(food)),
      ))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: loggedRecordsOverrides(catalogue),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => FoodPortionBottomSheet.show(
                    context,
                    ref: ref,
                    option: option,
                    mealType: 'breakfast',
                    targetDate: DateTime(2026, 10, 8),
                    ensureMealContext: () async => 'breakfast',
                  ),
                  child: const Text('Open sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sheet'));
      await settleLoggedRecords(tester, rounds: 10);
    }

    Future<NutritionConsumptionSnapshot> lastLog(WidgetTester tester) async {
      final all = (await tester.runAsync(
        () => catalogue.consumption.listAllForUser(
          userId: kLocalNutritionUserScopeId,
        ),
      ))!;
      return (all.toList()
            ..sort((a, b) => a.createdAtUtc.compareTo(b.createdAtUtc)))
          .last;
    }

    double kcal(NutritionConsumptionSnapshot snapshot) =>
        snapshot.totals.facts['energy']!.point!.value.asDouble;

    Future<void> chooseAndLog(WidgetTester tester, String chip) async {
      await tester.tap(find.byKey(ValueKey('dish-chip-$chip')));
      await settleLoggedRecords(tester, rounds: 10);
      await tester.tap(find.text('Add to Breakfast'));
      await settleLoggedRecords(tester, rounds: 10);
    }

    testWidgets('each size chip logs its own food and kcal', (tester) async {
      await openSheet(tester, _poha);
      expect(find.byKey(const ValueKey('dish-chip-Regular')), findsOneWidget);
      expect(find.byKey(const ValueKey('dish-chip-Jumbo')), findsNothing);
      await chooseAndLog(tester, 'Double');

      final logged = await lastLog(tester);
      final double = (await tester.runAsync(
        () => catalogue.foodId(_pohaDouble),
      ))!;
      expect(logged.items.single.foodId, double);
      expect(kcal(logged), 460);
      expect(find.textContaining('Double healthy bowl'), findsWidgets);
    });

    testWidgets('an oil chip logs the oil variant', (tester) async {
      await openSheet(tester, 'Jeera Aloo');
      await chooseAndLog(tester, 'Dhaba / extra ghee');
      final logged = await lastLog(tester);
      final dhaba = (await tester.runAsync(
        () => catalogue.foodId('Jeera Aloo (Dhaba Style (High oil))'),
      ))!;
      expect(logged.items.single.foodId, dhaba);
      expect(kcal(logged), 224);
    });

    testWidgets('going back to the dish chip logs the dish', (tester) async {
      await openSheet(tester, _poha);
      await tester.tap(find.byKey(const ValueKey('dish-chip-Double')));
      await settleLoggedRecords(tester, rounds: 10);
      await chooseAndLog(tester, 'Regular');
      final logged = await lastLog(tester);
      final poha = (await tester.runAsync(() => catalogue.foodId(_poha)))!;
      expect(logged.items.single.foodId, poha);
      expect(kcal(logged), 230);
    });
  });

  group('old variant logs', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('a logged variant still shows, even once retired', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final catalogue = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, catalogue.db));
      await tester.runAsync(() async {
        final foods = LoggedRecords.coordinatorFor(catalogue);
        final id = await catalogue.foodId(_pohaDouble);
        final option = (await catalogue.catalog.getOption(id))!;
        await foods.finalize(
          userId: kLocalNutritionUserScopeId,
          preview: await foods.preview(
            option: option,
            quantity: option.defaultLoggingQuantity,
          ),
          mealCategory: 'breakfast',
          loggedAt: DateTime.utc(2026, 10, 8, 3),
          localDate: loggedRecordsDate,
          timezoneId: loggedRecordsTimezone,
          commandId: 'old-variant-log',
          consumptionId: 'old-variant-log',
        );
        // As if a later pack retired it (UR-07 style).
        await catalogue.db.customStatement(
          "UPDATE nutrition_foods SET lifecycle = 'deprecated' WHERE id = ?",
          [id],
        );
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: loggedRecordsOverrides(catalogue),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: FoodDiaryScreen(
              selectedDate: DateTime(2026, 10, 8),
              today: DateTime(2026, 10, 8),
            ),
          ),
        ),
      );
      await settleLoggedRecords(tester);
      expect(find.textContaining('Poha'), findsWidgets);
      expect(find.textContaining('460'), findsWidgets);
    });
  });
}
