import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/features/food_log/copy_meal.dart';
import 'package:indifit/features/food_log/repeat_meal.dart';
import 'package:indifit/features/food_log/widgets/food_diary_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// UF-6: copy a meal or a whole day to another day.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const source = loggedRecordsDate; // 2026-10-08
  const target = '2026-10-10';
  final targetDay = DateTime(2026, 10, 10);

  late RealCatalogue c;
  late NutritionReadModelRepository readModels;
  late WidgetRef ref;

  Future<void> setUpCatalogue(WidgetTester tester) async {
    c = (await tester.runAsync(RealCatalogue.open))!;
    addTearDown(() => closeWidgetTestDatabase(tester, c.db));
    readModels = NutritionReadModelRepository(
      db: c.db,
      registry: c.registry,
      canonicalRepository: c.consumption,
    );
  }

  List<Override> overrides() => [
    ...loggedRecordsOverrides(c),
    nutritionThaliRepositoryProvider.overrideWith((ref) async => c.thali),
    nutritionRecipeLogCoordinatorProvider.overrideWith(
      (ref) async => c.recipeLogging,
    ),
  ];

  Future<void> pumpRef(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: overrides(),
      child: MaterialApp(
        home: Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            return const SizedBox();
          },
        ),
      ),
    ),
  );

  Future<List<NutritionHistoricalReadRecord>> recordsOn(
    WidgetTester tester,
    String localDate,
  ) async => (await tester.runAsync(
    () => readModels.dailyTotals(
      userId: kLocalNutritionUserScopeId,
      localDate: localDate,
    ),
  ))!.records;

  NutritionConsumptionSnapshot snapshotOf(NutritionHistoricalReadRecord r) =>
      (r as NutritionCanonicalSnapshotReadModel).snapshot;

  testWidgets('a meal copies whole: thali and recipe as themselves, the '
      'estimate with its tag', (tester) async {
    await setUpCatalogue(tester);
    final logged = (await tester.runAsync(() => LoggedRecords.log(c)))!;
    await pumpRef(tester);
    final lunch = recordsForMeal(await recordsOn(tester, source), 'lunch');

    final outcome = (await tester.runAsync(
      () => copyMealRecords(
        ref,
        records: lunch,
        targetDay: targetDay,
        mealType: 'lunch',
      ),
    ))!;
    expect(outcome.skipped, 0);
    expect(outcome.logged, lunch.length);

    final copied = (await recordsOn(tester, target)).map(snapshotOf).toList();
    expect(copied, hasLength(lunch.length));
    expect(copied.every((s) => s.mealCategory == 'lunch'), isTrue);
    expect(
      copied.map((s) => s.sourceType),
      unorderedEquals(lunch.map((r) => snapshotOf(r).sourceType)),
    );
    final thali = copied.singleWhere((s) => s.sourceType == 'thali');
    expect(thali.thaliId, logged.bySource['thali']!.thaliId);
    final recipe = copied.singleWhere((s) => s.sourceType == 'recipe');
    expect(recipe.recipeVersionId, logged.bySource['recipe']!.recipeVersionId);
    final estimate = copied.singleWhere((s) => s.sourceType == 'estimate');
    // The estimate tag: the same source type and fact provenance.
    expect(NutritionCanonicalSnapshotReadModel(estimate).isEstimate, isTrue);
    expect(
      estimate.items.single.facts['energy']!.source,
      logged.bySource['estimate']!.items.single.facts['energy']!.source,
    );
    expect(
      estimate.totals.facts['energy']!.point!.value.asDouble,
      logged
          .bySource['estimate']!
          .totals
          .facts['energy']!
          .point!
          .value
          .asDouble,
    );
    // The source day is untouched.
    expect(
      recordsForMeal(await recordsOn(tester, source), 'lunch'),
      hasLength(lunch.length),
    );
  });

  testWidgets('a single meal can land in another meal', (tester) async {
    await setUpCatalogue(tester);
    await tester.runAsync(() => LoggedRecords.log(c, only: {'direct_food'}));
    await pumpRef(tester);
    await tester.runAsync(
      () async => copyMealRecords(
        ref,
        records: await readModels
            .dailyTotals(userId: kLocalNutritionUserScopeId, localDate: source)
            .then((d) => d.records),
        targetDay: targetDay,
        mealType: 'dinner',
      ),
    );
    final copied = await recordsOn(tester, target);
    expect(copied.single.mealCategory, 'dinner');
  });

  testWidgets('a day copy keeps each meal, and adds to what is there', (
    tester,
  ) async {
    await setUpCatalogue(tester);
    await tester.runAsync(
      () => LoggedRecords.log(c, meal: 'breakfast', only: {'direct_food'}),
    );
    await tester.runAsync(
      () => LoggedRecords.log(c, only: {'thali', 'quick_add'}),
    );
    await pumpRef(tester);
    // The target day already has a dinner.
    final dinner = (await tester.runAsync(
      () => copyMealRecords(
        ref,
        records: [],
        targetDay: targetDay,
        mealType: 'dinner',
      ),
    ))!;
    expect(dinner.logged, 0);
    final day = await recordsOn(tester, source);
    await tester.runAsync(
      () => copyMealRecords(
        ref,
        records: day.where((r) => r.mealCategory == 'breakfast'),
        targetDay: targetDay,
        mealType: 'dinner',
      ),
    );
    expect(await recordsOn(tester, target), hasLength(1));

    final outcome = (await tester.runAsync(
      () => copyMealRecords(ref, records: day, targetDay: targetDay),
    ))!;
    expect(outcome.logged, day.length);
    final after = await recordsOn(tester, target);
    expect(after, hasLength(1 + day.length));
    expect(
      after.map((r) => r.mealCategory),
      unorderedEquals(['dinner', ...day.map((r) => r.mealCategory)]),
    );
  });

  test('the confirmation names the meal, count, kcal and day', () {
    expect(
      copiedMessage(
        what: 'Lunch',
        outcome: const RepeatOutcome(foods: 3),
        targetLocalDate: '2026-10-23',
      ),
      'Copied Lunch (3 items · 0 kcal) to Fri, 23 Oct',
    );
    expect(
      copiedMessage(
        what: 'Lunch',
        outcome: const RepeatOutcome(foods: 1, skipped: 1),
        targetLocalDate: '2026-10-23',
      ),
      'Copied Lunch (1 item · 0 kcal) to Fri, 23 Oct. 1 changed since and '
      'was not copied',
    );
  });

  testWidgets('the meal page copies with one confirmation, and Undo removes '
      'every copy', (tester) async {
    tester.view.physicalSize = const Size(402, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await setUpCatalogue(tester);
    await tester.runAsync(
      () => LoggedRecords.log(c, only: {'direct_food', 'estimate'}),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: FoodMealDetailScreen(
            mealType: 'lunch',
            selectedDate: DateTime(2026, 10, 8),
          ),
        ),
      ),
    );
    await settleLoggedRecords(tester);
    await tester.tap(find.byKey(const ValueKey('meal_page_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy to another day'));
    await tester.pumpAndSettle();
    expect(find.text('Copy Lunch to'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('indifit_month_day_$target')));
    await tester.pumpAndSettle();
    // The meal is kept unless another is picked.
    await tester.tap(find.byKey(const Key('copy_meal_confirm')));
    await settleLoggedRecords(tester, rounds: 10);

    final copied = await recordsOn(tester, target);
    expect(copied, hasLength(2));
    final kcal = copied
        .map((r) => r.totals.facts['energy']!.point!.value.asDouble)
        .reduce((a, b) => a + b);
    expect(
      find.text('Copied Lunch (2 items · ${kcal.round()} kcal) to Sat, 10 Oct'),
      findsOneWidget,
    );

    await tester.tap(find.text('Undo'));
    await settleLoggedRecords(tester, rounds: 10);
    expect(await recordsOn(tester, target), isEmpty);
    expect(await recordsOn(tester, source), hasLength(2));
  });
}
