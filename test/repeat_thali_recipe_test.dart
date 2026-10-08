import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_calculation_service.dart';
import 'package:indifit/core/nutrition_consumption_snapshots.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/nutrition_thali.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    hide
        NutritionConsumptionSnapshot,
        NutritionThaliItem,
        NutritionUserConstraint;
import 'package:indifit/data/repositories/nutrition_constraint_repository.dart';
import 'package:indifit/data/repositories/nutrition_consumption_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_catalog_repository.dart';
import 'package:indifit/data/repositories/nutrition_food_logging_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_household_measure_repository.dart';
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/data/repositories/nutrition_thali_repository.dart';
import 'package:indifit/data/repositories/nutrition_transformation_repository.dart';
import 'package:indifit/features/dashboard/widgets/today_usual_thali_card.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/food_log/repeat_meal.dart';
import 'package:indifit/features/food_log/usual_thali.dart';

const _user = 'repeat-user';
const _tz = 'Asia/Kolkata';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Harness h;
  setUp(() async => h = await _Harness.create());
  tearDown(() => h.db.close());

  test('a thali logged yesterday is repeated as the same thali', () async {
    final yesterday = await h.logThaliYesterday();

    final plan = planRepeat([NutritionCanonicalSnapshotReadModel(yesterday)]);
    expect(plan.isEmpty, isFalse);
    expect(plan.thalis.single.thaliId, yesterday.thaliId);
    expect(plan.names, ['Rice', 'Dal']);

    final outcome = await h.repeat(plan);
    expect(outcome.thalis, 1);
    expect(outcome.skipped, 0);
    expect(outcome.loggedLabel, '1 thali');

    final today = await h.loggedOn('2026-10-05');
    expect(today, hasLength(1));
    expect(today.single.sourceType, 'thali');
    expect(today.single.mealCategory, 'lunch');
    // The same saved thali, logged again.
    expect(today.single.thaliId, yesterday.thaliId);
    expect(
      today.single.items.map((item) => (item.foodId, item.displayLabel)),
      yesterday.items.map((item) => (item.foodId, item.displayLabel)),
    );
    expect(
      today.single.totals.facts['energy']?.point?.value.toString(),
      yesterday.totals.facts['energy']?.point?.value.toString(),
    );
    // Repeating adds no saved meals.
    final saved = await h.thalis.listDrafts(userId: _user);
    expect(saved.map((draft) => draft.id), [yesterday.thaliId]);
  });

  test('a repeated thali can be repeated again the next day', () async {
    final yesterday = await h.logThaliYesterday();
    await h.repeat(
      planRepeat([NutritionCanonicalSnapshotReadModel(yesterday)]),
    );
    final today = (await h.loggedOn('2026-10-05')).single;

    final outcome = await h.repeat(
      planRepeat([NutritionCanonicalSnapshotReadModel(today)]),
      localDate: '2026-10-06',
    );
    expect(outcome.thalis, 1);
    expect(await h.loggedOn('2026-10-06'), hasLength(1));
  });

  test('a thali edited since yesterday is skipped, not approximated', () async {
    final yesterday = await h.logThaliYesterday();
    final draft = (await h.thalis.getDraft(
      userId: _user,
      thaliId: yesterday.thaliId!,
    ))!;
    await h.thalis.saveDraft(draft.copyWith(items: [draft.items.first]));

    final outcome = await h.repeat(
      planRepeat([NutritionCanonicalSnapshotReadModel(yesterday)]),
    );
    expect(outcome.logged, 0);
    expect(outcome.skipped, 1);
    expect(
      outcome.skippedNote,
      '1 changed since yesterday and was not repeated',
    );
    expect(await h.loggedOn('2026-10-05'), isEmpty);
  });

  group('usual thali on Today', () {
    Future<List<NutritionCanonicalSnapshotReadModel>> history() async => [
      for (final snapshot in await h.consumption.listAllForUser(userId: _user))
        NutritionCanonicalSnapshotReadModel(snapshot),
    ];

    test('a plate logged twice is the usual one, and logs again', () async {
      final yesterday = await h.logThaliYesterday();
      await h.repeat(
        planRepeat([NutritionCanonicalSnapshotReadModel(yesterday)]),
      );

      final usual = UsualThaliFinder.find(await history())!;
      expect(usual.timesLogged, 2);
      expect(usual.itemLabels, ['Rice', 'Dal']);
      // The newest log is the one repeated.
      expect(usual.record.localDate, '2026-10-05');

      final outcome = await h.repeat(
        planRepeat([usual.record]),
        localDate: '2026-10-06',
      );
      expect(outcome.thalis, 1);
      expect(await h.loggedOn('2026-10-06'), hasLength(1));
    });

    testWidgets('Today offers it for the meal at this time of day', (
      tester,
    ) async {
      final usual = (await tester.runAsync(() async {
        final yesterday = await h.logThaliYesterday();
        await h.repeat(
          planRepeat([NutritionCanonicalSnapshotReadModel(yesterday)]),
        );
        return UsualThaliFinder.find(await history());
      }))!;

      Future<void> pump(List<NutritionHistoricalReadRecord> today) async {
        await tester.pumpWidget(
          ProviderScope(
            // A new scope each time, so the overrides apply afresh.
            key: UniqueKey(),
            overrides: [
              usualThaliProvider.overrideWith((ref) async => usual),
              canonicalFoodRecordsForDayProvider.overrideWith(
                (ref, day) async => today,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: TodayUsualThaliCard(
                  now: () => DateTime(2026, 10, 6, 13, 10),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      await pump(const []);
      expect(find.textContaining('Your usual thali'), findsOneWidget);
      expect(find.text('Rice, Dal'), findsOneWidget);
      expect(find.text('Log to lunch'), findsOneWidget);

      // Already in today's lunch: nothing to offer.
      await pump([usual.record]);
      expect(find.byKey(const Key('today_usual_thali')), findsNothing);
    });

    test('a plate logged once is not usual yet', () async {
      await h.logThaliYesterday();
      expect(UsualThaliFinder.find(await history()), isNull);
    });

    test(
      'separately built thalis with the same plate count together',
      () async {
        Future<void> logRiceOnly(String day, String command) async {
          final draft = await h.thalis.saveDraft(
            h.thalis.newDraft(
              userId: _user,
              name: 'Rice only $command',
              items: [h._item('item-rice-$command', 'food-rice', 0, 'Rice')],
            ),
          );
          await h.thalis.finalize(
            preview: await h.thalis.preview(draft: draft),
            mealCategory: 'dinner',
            loggedAt: DateTime.parse('${day}T14:00:00Z'),
            commandId: command,
            localDate: day,
            timezoneId: _tz,
            allowPartial: true,
          );
        }

        await h.logThaliYesterday(); // rice and dal, once
        await logRiceOnly('2026-10-02', 'a');
        await logRiceOnly('2026-10-03', 'b');

        final usual = UsualThaliFinder.find(await history())!;
        expect(usual.timesLogged, 2);
        expect(usual.itemLabels, ['Rice']);
        expect(usual.record.localDate, '2026-10-03');
      },
    );
  });

  test('a recipe logged yesterday is repeated with the same amount', () async {
    final yesterday = await h.logRecipeYesterday(
      NutritionRecipeLogAmount.fraction('0.5'),
    );

    final plan = planRepeat([NutritionCanonicalSnapshotReadModel(yesterday)]);
    expect(plan.recipes.single.recipeId, 'recipe-dal');
    expect(plan.names, ['Dal recipe']);

    final outcome = await h.repeat(plan);
    expect(outcome.recipes, 1);
    expect(outcome.loggedLabel, '1 recipe');

    final today = await h.loggedOn('2026-10-05');
    expect(today.single.sourceType, 'recipe');
    expect(today.single.recipeVersionId, yesterday.recipeVersionId);
    expect(
      today.single.totals.facts['energy']?.point?.value.toString(),
      yesterday.totals.facts['energy']?.point?.value.toString(),
    );
  });

  test('an archived recipe is skipped', () async {
    final yesterday = await h.logRecipeYesterday(
      NutritionRecipeLogAmount.wholeRecipe(),
    );
    await h.recipes.archiveRecipe('recipe-dal');

    final outcome = await h.repeat(
      planRepeat([NutritionCanonicalSnapshotReadModel(yesterday)]),
    );
    expect(outcome.logged, 0);
    expect(outcome.skipped, 1);
  });

  test('the outcome names what was logged', () {
    expect(
      const RepeatOutcome(foods: 2, thalis: 1, recipes: 1).loggedLabel,
      '2 foods, 1 thali and 1 recipe',
    );
    expect(const RepeatOutcome(foods: 1).loggedLabel, '1 food');
    expect(const RepeatOutcome(skipped: 2).skippedNote, contains('were'));
    expect(const RepeatOutcome(foods: 1).skippedNote, isNull);
  });
}

class _Harness {
  final AppDatabase db;
  final NutritionRecipeRepository recipes;
  final NutritionConsumptionRepository consumption;
  final NutritionThaliRepository thalis;
  final NutritionRecipeLogCoordinator recipeLog;
  final NutritionFoodLoggingCoordinator foods;
  final NutritionFoodCatalogRepository catalog;

  _Harness._(
    this.db,
    this.recipes,
    this.consumption,
    this.thalis,
    this.recipeLog,
    this.foods,
    this.catalog,
  );

  static Future<_Harness> create() async {
    final db = AppDatabase.memory();
    final registry = NutrientRegistry.fromAssetFileSync(
      'assets/data/nutrient_registry.json',
    );
    await _insertFood(db, 'food-rice', 130, 'Rice');
    await _insertFood(db, 'food-dal', 116, 'Dal');
    final recipes = NutritionRecipeRepository(db: db);
    final consumption = NutritionConsumptionRepository(
      db: db,
      registry: registry,
    );
    final recipeLog = NutritionRecipeLogCoordinator(
      db: db,
      recipes: recipes,
      calculator: const NutritionCalculationService(),
      consumption: consumption,
      registry: registry,
    );
    final catalog = NutritionFoodCatalogRepository(db: db, registry: registry);
    return _Harness._(
      db,
      recipes,
      consumption,
      NutritionThaliRepository(
        db: db,
        registry: registry,
        recipes: recipes,
        recipeLogging: recipeLog,
        measures: NutritionHouseholdMeasureRepository(db: db),
        constraints: NutritionConstraintRepository(database: db),
        consumption: consumption,
      ),
      recipeLog,
      NutritionFoodLoggingCoordinator(
        db: db,
        registry: registry,
        catalog: catalog,
        calculator: const NutritionCalculationService(),
        consumption: consumption,
        transformations: NutritionTransformationRepository(db: db),
      ),
      catalog,
    );
  }

  NutritionThaliItem _item(String id, String foodId, int position, String l) =>
      NutritionThaliItem(
        id: id,
        position: position,
        source: NutritionThaliItemSource.food,
        foodId: foodId,
        recipeVersionId: null,
        quantity: Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
        displayLabel: l,
      );

  Future<NutritionConsumptionSnapshot> logThaliYesterday() async {
    final draft = await thalis.saveDraft(
      thalis.newDraft(
        userId: _user,
        name: 'Weekday lunch',
        items: [
          _item('item-rice', 'food-rice', 0, 'Rice'),
          _item('item-dal', 'food-dal', 1, 'Dal'),
        ],
      ),
    );
    final preview = await thalis.preview(draft: draft);
    return thalis.finalize(
      preview: preview,
      mealCategory: 'lunch',
      loggedAt: DateTime.utc(2026, 10, 4, 7),
      commandId: 'yesterday-thali',
      localDate: '2026-10-04',
      timezoneId: _tz,
      allowPartial: true,
    );
  }

  Future<NutritionConsumptionSnapshot> logRecipeYesterday(
    NutritionRecipeLogAmount amount,
  ) async {
    final draft = await recipes.createRecipe(
      userId: _user,
      recipeId: 'recipe-dal',
      versionId: 'recipe-dal-v1',
      name: 'Dal recipe',
      ingredients: [
        NutritionRecipeIngredientInput.directFood(
          id: 'line-dal',
          foodId: 'food-dal',
          quantity: Quantity.fromNum(amount: 400, unit: QuantityUnit.gram),
          position: 0,
        ),
      ],
      yieldQuantity: Quantity.fromNum(amount: 800, unit: QuantityUnit.gram),
    );
    await recipes.publishDraft(
      recipeId: 'recipe-dal',
      draftVersionId: draft.version.id,
    );
    final preview = await recipeLog.preview(
      userId: _user,
      recipeId: 'recipe-dal',
      amount: amount,
    );
    return recipeLog.finalize(
      userId: _user,
      preview: preview,
      mealCategory: 'lunch',
      loggedAt: DateTime.utc(2026, 10, 4, 7),
      localDate: '2026-10-04',
      timezoneId: _tz,
      commandId: 'yesterday-recipe',
      allowPartial: true,
    );
  }

  Future<RepeatOutcome> repeat(
    RepeatPlan plan, {
    String localDate = '2026-10-05',
  }) => logRepeatPlan(
    plan: plan,
    foods: foods,
    catalog: catalog,
    thalis: thalis,
    recipes: recipeLog,
    userId: _user,
    mealCategory: 'lunch',
    loggedAtUtc: DateTime.parse('${localDate}T07:00:00Z'),
    localDate: localDate,
    timezoneId: _tz,
  );

  Future<List<NutritionConsumptionSnapshot>> loggedOn(String localDate) async =>
      (await consumption.listAllForUser(
        userId: _user,
      )).where((snapshot) => snapshot.localDate == localDate).toList();
}

Future<void> _insertFood(
  AppDatabase db,
  String id,
  double energy,
  String displayName,
) async {
  await db
      .into(db.nutritionFoods)
      .insert(
        NutritionFoodsCompanion.insert(
          id: id,
          kind: 'canonical',
          displayName: displayName,
          locale: 'en-IN',
          sourceType: 'fixture',
          lifecycle: 'active',
        ),
      );
  await db
      .into(db.nutritionFoodNutrientFacts)
      .insert(
        NutritionFoodNutrientFactsCompanion.insert(
          id: '$id-energy-v1',
          foodId: id,
          nutrientId: 'energy',
          status: 'known',
          source: 'reviewed_catalogue',
          factVersion: 1,
          basis: 'per_100_grams',
          basisQuantity: const Value(100),
          basisUnit: const Value('gram'),
          amount: Value(energy),
          isCurrent: const Value(true),
        ),
      );
}
