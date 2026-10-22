import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/food_log/nutrition_thali_controller.dart';
import 'package:indifit/features/food_log/thali/thali_component_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/real_catalogue.dart';

/// N14-11, U-5: the thali dish picker searches like Food search.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RealCatalogue catalogue;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    catalogue = await RealCatalogue.open();
  });

  tearDown(() => catalogue.close());

  Future<List<String>> names(String query) async => [
    for (final option in await catalogue.thali.searchFoods(query: query))
      option.displayName,
  ];

  test('"dal" ranks dal dishes, not the alphabet', () async {
    final found = await names('dal');
    expect(found, isNotEmpty);
    expect(found.take(6).every((name) => name.contains('Dal')), isTrue);
    expect(found, contains('Toor Dal / Yellow Dal Tadka'));
  });

  test('"3 roti" searches roti', () async {
    final found = await names('3 roti');
    expect(found.first, 'Whole Wheat Roti / Chapati');
    expect(found.every((name) => name.toLowerCase().contains('roti')), isTrue);
  });

  test('a typo still finds the dish', () async {
    expect(await names('rotti'), contains('Butter Roti / Chapati'));
  });

  test('a spelling variant finds the same dishes', () async {
    final sabzi = await names('sabzi');
    expect(sabzi, contains('Beetroot Sabji'));
    expect(
      (await names('subzi')).toSet().intersection(sabzi.toSet()),
      isNotEmpty,
    );
  });

  test('one row per dish: a size variant does not repeat its dish', () async {
    final options = await catalogue.thali.searchFoods(query: 'roti');
    final ids = options.map((option) => option.id).toSet();
    final variants = await (catalogue.db.select(
      catalogue.db.nutritionFoods,
    )..where((food) => food.variantOfFoodId.isIn(ids))).get();
    expect(variants.map((food) => food.id).where(ids.contains), isEmpty);
  });

  test('foods without nutrition are left out', () async {
    Future<void> food(String id, String name) => catalogue.db
        .into(catalogue.db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: id,
            kind: 'canonical',
            displayName: name,
            locale: 'en-IN',
            sourceType: 'fixture',
            lifecycle: 'active',
          ),
        );
    await food('probe-no-facts', 'Zqprobe Khichdi');
    await food('probe-with-facts', 'Zqprobe Pulao');
    await catalogue.db
        .into(catalogue.db.nutritionFoodNutrientFacts)
        .insert(
          NutritionFoodNutrientFactsCompanion.insert(
            id: 'probe-with-facts-energy-v1',
            foodId: 'probe-with-facts',
            nutrientId: 'energy',
            status: 'known',
            source: 'reviewed_catalogue',
            factVersion: 1,
            basis: 'per_100_grams',
            basisQuantity: const Value(100),
            basisUnit: const Value('gram'),
            amount: const Value(150),
            isCurrent: const Value(true),
          ),
        );
    expect(await names('zqprobe'), ['Zqprobe Pulao']);
  });

  testWidgets('no match offers the same "Can\'t find" row as Food search', (
    tester,
  ) async {
    final controller = NutritionThaliController(
      repository: Future.value(catalogue.thali),
      userId: 'local-user-v1',
      mealCategory: 'lunch',
    );
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ThaliComponentPickerSheet(
              controller: controller,
              state: controller.state,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('thali_search_input')),
      'qqzz xyzzy',
    );
    await tester.runAsync(() => controller.search('qqzz xyzzy'));
    await tester.pump();

    expect(find.text('No matching dishes found.'), findsOneWidget);
    expect(find.text('Can\'t find "qqzz xyzzy"?'), findsOneWidget);
    await tester.tap(find.text('Add to my list'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.textContaining('Added to your list'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
