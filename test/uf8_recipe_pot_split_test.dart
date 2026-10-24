import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart'
    show NutritionFoodsCompanion, NutritionFoodNutrientFactsCompanion;
import 'package:indifit/data/repositories/nutrition_recipe_log_coordinator.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';
import 'package:indifit/features/food_log/recipe_pot_split.dart';

import 'support/real_catalogue.dart';

const _dal = 'food-uf8-dal';

/// UF-8: "This pot makes 6 katori" → "I ate 1½ katori".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RealCatalogue c;
  setUp(() async {
    c = await RealCatalogue.open();
    // A per-100 g food, so the recipe scales by weight.
    await c.db
        .into(c.db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: _dal,
            kind: 'canonical',
            displayName: 'Dal',
            locale: 'en-IN',
            sourceType: 'fixture',
            lifecycle: 'active',
          ),
        );
    await c.db
        .into(c.db.nutritionFoodNutrientFacts)
        .insert(
          NutritionFoodNutrientFactsCompanion.insert(
            id: '$_dal-energy-v1',
            foodId: _dal,
            nutrientId: 'energy',
            status: 'known',
            source: 'reviewed_catalogue',
            factVersion: 1,
            basis: 'per_100_grams',
            basisQuantity: const Value(100),
            basisUnit: const Value('gram'),
            amount: const Value(116),
            isCurrent: const Value(true),
          ),
        );
  });
  tearDown(() => c.close());

  const user = kLocalNutritionUserScopeId;
  var serial = 0;

  NutritionRecipeServingDefinition serving(num count, {String? unit}) =>
      NutritionRecipeServingDefinition(
        id: 'serving-${serial++}',
        revision: 'test-v1',
        count: QuantityAmount.fromNum(count),
        unit: unit,
      );

  /// A published dal recipe (400 g of a catalogue dal) with this pot.
  Future<NutritionRecipeVersionModel> recipe({
    NutritionRecipeServingDefinition? servingDefinition,
    Quantity? yieldQuantity,
  }) async {
    final id = 'recipe-${serial++}';
    final draft = await c.recipes.createRecipe(
      userId: user,
      recipeId: id,
      versionId: '$id-v1',
      name: 'Dal',
      ingredients: [
        NutritionRecipeIngredientInput.directFood(
          id: '$id-line',
          foodId: _dal,
          quantity: Quantity.fromNum(amount: 400, unit: QuantityUnit.gram),
          position: 0,
        ),
      ],
      servingDefinition: servingDefinition,
      yieldQuantity: yieldQuantity,
    );
    return c.recipes.publishDraft(
      recipeId: id,
      draftVersionId: draft.version.id,
    );
  }

  Future<double> kcal(
    NutritionRecipeVersionModel version,
    NutritionRecipeLogAmount amount,
  ) async {
    final preview = await c.recipeLogging.preview(
      userId: user,
      recipeId: version.recipeId,
      recipeVersionId: version.id,
      amount: amount,
    );
    return preview.calculation.facts['energy']!.point!.value.asDouble;
  }

  group('the maths: total × eaten ÷ pot yield', () {
    Future<void> expectQuarter(
      NutritionRecipeVersionModel version,
      String eaten,
      RecipePotUnit unit,
    ) async {
      final pot = RecipePotYield.of(version)!;
      expect(pot.unit, unit);
      final whole = await kcal(version, NutritionRecipeLogAmount.wholeRecipe());
      final part = await kcal(version, pot.logAmount(parsePotAmount(eaten)!));
      expect(whole, greaterThan(0));
      expect(part, closeTo(whole / 4, 0.01));
    }

    test('katori', () async {
      final version = await recipe(
        servingDefinition: serving(6, unit: 'katori'),
      );
      expect(RecipePotYield.of(version)!.label, '6 katori');
      await expectQuarter(version, '1½', RecipePotUnit.katori);
    });

    test('servings', () async {
      final version = await recipe(servingDefinition: serving(4));
      expect(RecipePotYield.of(version)!.label, '4 servings');
      await expectQuarter(version, '1', RecipePotUnit.servings);
    });

    test('total grams', () async {
      final version = await recipe(
        servingDefinition: serving(1),
        yieldQuantity: Quantity.fromNum(amount: 800, unit: QuantityUnit.gram),
      );
      expect(RecipePotYield.of(version)!.label, '800 g');
      await expectQuarter(version, '200', RecipePotUnit.grams);
    });

    test('the sum is shown as it is worked out', () {
      final pot = RecipePotYield(
        RecipePotUnit.katori,
        QuantityAmount.fromNum(6),
      );
      final eaten = parsePotAmount('1½');
      expect(recipePotSum(pot, eaten), 'Whole pot × 1½ ÷ 6 katori');
      expect(
        recipePotSum(pot, eaten, kcal: 300),
        'Whole pot × 1½ ÷ 6 katori = 300 kcal',
      );
      expect(recipePotSum(pot, null), 'Enter how much you ate.');
      expect(pot.amountLabel(eaten!), '1½ katori');
    });
  });

  test('amounts as people type them', () {
    String? read(String text) => parsePotAmount(text)?.toString();
    expect(read('1½'), '1.5');
    expect(read('1 1/2'), '1.5');
    expect(read('1.5'), '1.5');
    expect(read('1,5'), '1.5');
    expect(read('½'), '0.5');
    expect(read('3/4'), '0.75');
    expect(read('2'), '2');
    expect(read(''), isNull);
    expect(read('0'), isNull);
    expect(read('abc'), isNull);
  });

  test('editing the yield keeps and clears what it should', () async {
    final draft = await c.recipes.createDraft(
      userId: user,
      name: 'Rajma',
      servingDefinition: serving(6, unit: 'katori'),
      ingredients: [
        NutritionRecipeIngredientInput.directFood(
          id: 'rajma-line',
          foodId: _dal,
          quantity: Quantity.fromNum(amount: 300, unit: QuantityUnit.gram),
          position: 0,
        ),
      ],
    );
    var version = (await c.recipes.getDraft(draft.version.id))!.version;
    expect(RecipePotYield.of(version)!.label, '6 katori');

    // Katori → grams.
    await c.recipes.updateDraft(
      recipeId: draft.recipe.id,
      draftVersionId: draft.version.id,
      servingDefinition: serving(1),
      yieldQuantity: Quantity.fromNum(amount: 900, unit: QuantityUnit.gram),
    );
    version = (await c.recipes.getDraft(draft.version.id))!.version;
    expect(RecipePotYield.of(version)!.label, '900 g');
    expect(version.servingDefinition!.unit, isNull);

    // Grams → servings: the yield and the katori are gone.
    await c.recipes.updateDraft(
      recipeId: draft.recipe.id,
      draftVersionId: draft.version.id,
      servingDefinition: serving(4),
      clearYield: true,
    );
    version = (await c.recipes.getDraft(draft.version.id))!.version;
    expect(version.yieldQuantity, isNull);
    expect(RecipePotYield.of(version)!.label, '4 servings');

    // Servings → katori, and the unit survives a successor version.
    await c.recipes.updateDraft(
      recipeId: draft.recipe.id,
      draftVersionId: draft.version.id,
      servingDefinition: serving(5, unit: 'katori'),
    );
    final published = await c.recipes.publishDraft(
      recipeId: draft.recipe.id,
      draftVersionId: draft.version.id,
    );
    final successor = await c.recipes.createSuccessorDraft(
      recipeId: published.recipeId,
    );
    expect(RecipePotYield.of(successor.version)!.label, '5 katori');
  });

  group('older recipes behave as before', () {
    test('no yield → no pot, so only the old amount choices', () async {
      final version = await recipe();
      expect(version.servingDefinition, isNull);
      expect(version.yieldQuantity, isNull);
      expect(RecipePotYield.of(version), isNull);
      final whole = await kcal(version, NutritionRecipeLogAmount.wholeRecipe());
      final half = await kcal(
        version,
        NutritionRecipeLogAmount.fraction('0.5'),
      );
      expect(half, closeTo(whole / 2, 0.01));
    });

    test('a source written before UF-8 reads as plain servings', () {
      final source = NutritionRecipeSource.decode(
        const NutritionRecipeSource(
          servingDefinitionId: 'serving-old',
          servingDefinitionRevision: 'b03-editor-v1',
        ).encode(),
      );
      expect(source.servingDefinitionUnit, isNull);
      expect(source.encode(), isNot(contains('serving_definition_unit')));
    });
  });
}
