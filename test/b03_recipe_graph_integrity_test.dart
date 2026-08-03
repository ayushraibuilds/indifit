import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cross-recipe versions cannot be published through another head',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedFoods(db, const ['graph-food']);
      final repository = NutritionRecipeRepository(db: db);
      final first = await repository.createRecipe(
        userId: 'graph-user',
        recipeId: 'graph-recipe-a',
        versionId: 'graph-a-v1',
        name: 'Graph A',
        ingredients: [_ingredient('graph-a-line', 'graph-food')],
      );
      await repository.createRecipe(
        userId: 'graph-user',
        recipeId: 'graph-recipe-b',
        versionId: 'graph-b-v1',
        name: 'Graph B',
        ingredients: [_ingredient('graph-b-line', 'graph-food')],
      );

      expect(
        () => repository.publishDraft(
          recipeId: 'graph-recipe-b',
          draftVersionId: first.version.id,
        ),
        throwsA(
          isA<NutritionRecipeValidationError>().having(
            (error) => error.code,
            'code',
            'cross_recipe_version_reference',
          ),
        ),
      );
      expect(
        (await repository.getRecipe('graph-recipe-b'))!.currentVersionId,
        isNull,
      );
    },
  );

  test(
    'gapped, duplicate, and cyclic ingredient/version graphs fail closed',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedFoods(db, const ['graph-food']);
      final repository = NutritionRecipeRepository(db: db);

      expect(
        () => repository.createRecipe(
          userId: 'graph-user',
          recipeId: 'gapped-recipe',
          versionId: 'gapped-v1',
          name: 'Gapped recipe',
          ingredients: [
            _ingredient('gapped-line-a', 'graph-food', position: 0),
            _ingredient('gapped-line-b', 'graph-food', position: 2),
          ],
        ),
        throwsA(
          isA<NutritionRecipeValidationError>().having(
            (error) => error.code,
            'code',
            'invalid_ingredient_order',
          ),
        ),
      );
      expect(await repository.getRecipe('gapped-recipe'), isNull);

      final draft = await repository.createRecipe(
        userId: 'graph-user',
        recipeId: 'cycle-recipe',
        versionId: 'cycle-v1',
        name: 'Cycle recipe',
        ingredients: [_ingredient('cycle-line', 'graph-food')],
      );
      await repository.publishDraft(
        recipeId: draft.recipe.id,
        draftVersionId: draft.version.id,
      );
      final successor = await repository.createSuccessorDraft(
        recipeId: draft.recipe.id,
        versionId: 'cycle-v2',
      );
      await (db.update(
        db.nutritionRecipeVersions,
      )..where((row) => row.id.equals(successor.version.id))).write(
        NutritionRecipeVersionsCompanion(
          source: Value(
            NutritionRecipeSource(parentVersionId: 'cycle-v2').encode(),
          ),
        ),
      );
      expect(
        () => repository.getRecipe(draft.recipe.id),
        throwsA(
          isA<NutritionRecipeValidationError>().having(
            (error) => error.code,
            'code',
            'invalid_version_ancestry',
          ),
        ),
      );
    },
  );

  test(
    'initial version ancestry is validated before any rows are committed',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      expect(
        () => NutritionRecipeRepository(db: db).createRecipe(
          userId: 'graph-user',
          recipeId: 'invalid-parent-recipe',
          versionId: 'invalid-parent-v1',
          name: 'Invalid parent recipe',
          source: const NutritionRecipeSource(parentVersionId: 'missing-v1'),
        ),
        throwsA(
          isA<NutritionRecipeValidationError>().having(
            (error) => error.code,
            'code',
            'invalid_version_ancestry',
          ),
        ),
      );
      expect(await db.select(db.nutritionRecipes).get(), isEmpty);
      expect(await db.select(db.nutritionRecipeVersions).get(), isEmpty);
    },
  );

  test(
    'imported source and serving context remain typed domain metadata',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedFoods(db, const ['imported-food']);
      final repository = NutritionRecipeRepository(db: db);
      final draft = await repository.createRecipe(
        userId: 'graph-user',
        recipeId: 'imported-recipe',
        versionId: 'imported-v1',
        name: 'Imported recipe',
        source: const NutritionRecipeSource(
          kind: NutritionRecipeSourceKind.imported,
          externalReference: 'provider:recipe-42',
        ),
        servingDefinition: NutritionRecipeServingDefinition(
          id: 'imported-serving',
          revision: 'label-v2',
          count: QuantityAmount.fromString('3'),
          source: 'manufacturer_label',
        ),
        ingredients: [_ingredient('imported-line', 'imported-food')],
      );
      final loaded = await repository.getDraft(draft.version.id);

      expect(loaded!.version.source.kind, NutritionRecipeSourceKind.imported);
      expect(loaded.version.source.externalReference, 'provider:recipe-42');
      expect(loaded.version.servingDefinition!.id, 'imported-serving');
      expect(loaded.version.servingDefinition!.revision, 'label-v2');
      expect(
        loaded.version.servingDefinition!.source,
        'manufacturer_label',
      );
    },
  );
}

NutritionRecipeIngredientInput _ingredient(
  String id,
  String foodId, {
  int? position,
}) => NutritionRecipeIngredientInput.directFood(
  id: id,
  foodId: foodId,
  quantity: Quantity.fromDecimal(amount: '1', unit: QuantityUnit.gram),
  position: position,
);

Future<void> _seedFoods(AppDatabase db, Iterable<String> ids) async {
  for (final id in ids) {
    await db
        .into(db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: id,
            kind: 'userCreated',
            displayName: id,
            locale: 'en-IN',
            sourceType: 'user',
            lifecycle: 'active',
          ),
        );
  }
}
