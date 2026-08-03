import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v8.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/nutrition_recipe_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recipe identity survives cosmetic rename and draft creation', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final repository = NutritionRecipeRepository(db: db);

    final created = await repository.createRecipe(
      userId: 'recipe-user',
      recipeId: 'recipe-stable-id',
      versionId: 'recipe-stable-v1',
      name: 'Original name',
    );
    final renamed = await repository.renameRecipe(
      recipeId: created.recipe.id,
      name: 'Cosmetically renamed',
    );

    expect(renamed.id, 'recipe-stable-id');
    expect(renamed.name, 'Cosmetically renamed');
    expect(renamed.currentVersionId, isNull);
    expect(created.version.id, 'recipe-stable-v1');
  });

  test(
    'direct-food ingredient graph is typed, ordered, and identity-based',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedFoods(db, const ['food-a', 'food-b']);
      final repository = NutritionRecipeRepository(db: db);

      final draft = await repository.createRecipe(
        userId: 'recipe-user',
        recipeId: 'ordered-recipe',
        versionId: 'ordered-draft',
        name: 'Ordered recipe',
        ingredients: [
          _ingredient('line-b', 'food-b', '20', position: 1),
          _ingredient('line-a', 'food-a', '100', position: 0),
        ],
      );

      expect(draft.version.ingredients.map((ingredient) => ingredient.foodId), [
        'food-a',
        'food-b',
      ]);
      expect(
        draft.version.ingredients.map((ingredient) => ingredient.quantity.unit),
        [QuantityUnit.gram, QuantityUnit.gram],
      );
      expect(
        (await db.select(db.nutritionRecipes).get()).map((row) => row.id),
        ['ordered-recipe'],
      );
    },
  );

  test('draft edits update metadata and ingredients atomically', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedFoods(db, const ['food-a', 'food-b']);
    final repository = NutritionRecipeRepository(db: db);
    final draft = await repository.createRecipe(
      userId: 'recipe-user',
      recipeId: 'editable-recipe',
      versionId: 'editable-draft',
      name: 'Editable recipe',
      ingredients: [_ingredient('editable-line-a', 'food-a', '10')],
    );

    final updated = await repository.updateDraft(
      recipeId: draft.recipe.id,
      draftVersionId: draft.version.id,
      name: 'Edited recipe',
      description: 'Updated description',
      yieldQuantity: Quantity.fromDecimal(
        amount: '240',
        unit: QuantityUnit.gram,
      ),
      servingDefinition: NutritionRecipeServingDefinition(
        id: 'editable-serving',
        revision: 'v1',
        count: QuantityAmount.fromString('2'),
      ),
      ingredients: [_ingredient('editable-line-b', 'food-b', '20')],
    );

    expect(updated.recipe.name, 'Edited recipe');
    expect(updated.recipe.description, 'Updated description');
    expect(updated.version.ingredients.single.foodId, 'food-b');
    expect(updated.version.yieldQuantity?.amount.toString(), '240');
    expect(updated.version.servingDefinition?.id, 'editable-serving');
    expect(updated.version.status, NutritionRecipeVersionStatus.draft);
  });

  test(
    'recipe ingredient quantities require the positive-use boundary',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedFoods(db, const ['food-a']);
      final repository = NutritionRecipeRepository(db: db);

      expect(
        () => repository.createRecipe(
          userId: 'recipe-user',
          recipeId: 'zero-recipe',
          versionId: 'zero-draft',
          name: 'Zero recipe',
          ingredients: [_ingredient('line-zero', 'food-a', '0')],
        ),
        throwsA(
          isA<NonPositiveQuantityError>().having(
            (error) => error.context,
            'context',
            NutritionQuantityInputContext.recipeIngredient,
          ),
        ),
      );
      expect(
        () => repository.createRecipe(
          userId: 'recipe-user',
          recipeId: 'negative-recipe',
          versionId: 'negative-draft',
          name: 'Negative recipe',
          ingredients: [_ingredient('line-negative', 'food-a', '-1')],
        ),
        throwsA(isA<InvalidQuantityAmountError>()),
      );
    },
  );

  test('unknown and ambiguous food identities remain explicit', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final repository = NutritionRecipeRepository(db: db);

    expect(
      () => repository.createRecipe(
        userId: 'recipe-user',
        recipeId: 'missing-food-recipe',
        versionId: 'missing-food-draft',
        name: 'Missing food',
        ingredients: [_ingredient('line-missing', 'Dal', '1')],
      ),
      throwsA(
        isA<NutritionRecipeValidationError>().having(
          (error) => error.code,
          'code',
          'missing_food_identity',
        ),
      ),
    );

    await _seedFoods(db, const ['unknown-food']);
    final draft = await repository.createRecipe(
      userId: 'recipe-user',
      recipeId: 'unknown-food-recipe',
      versionId: 'unknown-food-draft',
      name: 'Unknown food remains visible',
      ingredients: [_ingredient('line-unknown', 'unknown-food', '1')],
    );
    expect(draft.version.ingredients.single.foodId, 'unknown-food');
  });

  test('publishing creates an immutable version and idempotent head', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedFoods(db, const ['food-a', 'food-b']);
    final repository = NutritionRecipeRepository(db: db);
    final draft = await repository.createRecipe(
      userId: 'recipe-user',
      recipeId: 'publish-recipe',
      versionId: 'publish-v1',
      name: 'Publish recipe',
      ingredients: [_ingredient('publish-line', 'food-a', '100')],
      yieldQuantity: Quantity.fromDecimal(
        amount: '400',
        unit: QuantityUnit.gram,
      ),
      servingDefinition: NutritionRecipeServingDefinition(
        id: 'publish-serving',
        revision: 'v1',
        count: QuantityAmount.fromString('4'),
      ),
    );

    final published = await repository.publishDraft(
      recipeId: draft.recipe.id,
      draftVersionId: draft.version.id,
    );
    final repeated = await repository.publishDraft(
      recipeId: draft.recipe.id,
      draftVersionId: draft.version.id,
    );

    expect(published.status, NutritionRecipeVersionStatus.published);
    expect(repeated.id, published.id);
    expect(repeated.servingDefinition?.id, 'publish-serving');
    expect(repeated.yieldQuantity?.amount.toString(), '400');
    expect(
      (await repository.getRecipe('publish-recipe'))!.currentVersionId,
      'publish-v1',
    );
    expect(
      () => repository.replaceDraftIngredients(
        recipeId: 'publish-recipe',
        draftVersionId: 'publish-v1',
        ingredients: [_ingredient('new-line', 'food-b', '2')],
      ),
      throwsA(isA<NutritionRecipeImmutableError>()),
    );
  });

  test('empty publication is rejected without changing the draft', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final repository = NutritionRecipeRepository(db: db);
    final draft = await repository.createRecipe(
      userId: 'recipe-user',
      recipeId: 'empty-recipe',
      versionId: 'empty-draft',
      name: 'Empty recipe',
    );

    expect(
      () => repository.publishDraft(
        recipeId: draft.recipe.id,
        draftVersionId: draft.version.id,
      ),
      throwsA(
        isA<NutritionRecipeValidationError>().having(
          (error) => error.code,
          'code',
          'empty_published_recipe',
        ),
      ),
    );
    expect(
      (await repository.getVersion('empty-draft'))!.status,
      NutritionRecipeVersionStatus.draft,
    );
    expect(
      (await repository.getRecipe('empty-recipe'))!.currentVersionId,
      isNull,
    );
  });

  test('successor edits preserve old versions and record ancestry', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedFoods(db, const ['food-a', 'food-b']);
    final repository = NutritionRecipeRepository(db: db);
    final firstDraft = await repository.createRecipe(
      userId: 'recipe-user',
      recipeId: 'history-recipe',
      versionId: 'history-v1',
      name: 'History recipe',
      ingredients: [_ingredient('history-line-v1', 'food-a', '100')],
    );
    final first = await repository.publishDraft(
      recipeId: firstDraft.recipe.id,
      draftVersionId: firstDraft.version.id,
    );

    final successor = await repository.createSuccessorDraft(
      recipeId: 'history-recipe',
      versionId: 'history-v2',
      sourceKind: NutritionRecipeSourceKind.substituted,
    );
    expect(successor.version.parentVersionId, 'history-v1');
    await repository.replaceDraftIngredients(
      recipeId: 'history-recipe',
      draftVersionId: successor.version.id,
      ingredients: [
        _ingredient(
          'history-line-v2',
          'food-b',
          '50',
          substitutedFromFoodId: 'food-a',
          provenanceSource: 'user_recipe_substitution',
        ),
      ],
    );
    final second = await repository.publishDraft(
      recipeId: 'history-recipe',
      draftVersionId: successor.version.id,
    );

    expect(second.parentVersionId, first.id);
    expect(second.status, NutritionRecipeVersionStatus.published);
    expect(
      (await repository.getVersion(first.id))!.ingredients.single.foodId,
      'food-a',
    );
    expect(
      await (db.select(
        db.nutritionUserCorrections,
      )..where((row) => row.targetType.equals('recipe_ingredient'))).get(),
      hasLength(1),
    );
  });

  test(
    'publication rollback leaves no partial status or head and retries',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedFoods(db, const ['food-a']);
      var fail = true;
      final failing = NutritionRecipeRepository(
        db: db,
        failureInjector: (stage) async {
          if (fail &&
              stage == NutritionRecipePublicationStage.versionStatusMutation) {
            throw StateError('injected publication failure');
          }
        },
      );
      final draft = await failing.createRecipe(
        userId: 'recipe-user',
        recipeId: 'rollback-recipe',
        versionId: 'rollback-v1',
        name: 'Rollback recipe',
        ingredients: [_ingredient('rollback-line', 'food-a', '1')],
      );

      expect(
        () => failing.publishDraft(
          recipeId: draft.recipe.id,
          draftVersionId: draft.version.id,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        (await failing.getVersion('rollback-v1'))!.status,
        NutritionRecipeVersionStatus.draft,
      );
      expect(
        (await failing.getRecipe('rollback-recipe'))!.currentVersionId,
        isNull,
      );

      fail = false;
      final published = await failing.publishDraft(
        recipeId: draft.recipe.id,
        draftVersionId: draft.version.id,
      );
      expect(published.status, NutritionRecipeVersionStatus.published);
    },
  );

  test('archive and delete guard preserve published ancestry', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await _seedFoods(db, const ['food-a']);
    final repository = NutritionRecipeRepository(db: db);
    final draft = await repository.createRecipe(
      userId: 'recipe-user',
      recipeId: 'archive-recipe',
      versionId: 'archive-v1',
      name: 'Archive recipe',
      ingredients: [_ingredient('archive-line', 'food-a', '1')],
    );
    await repository.publishDraft(
      recipeId: draft.recipe.id,
      draftVersionId: draft.version.id,
    );
    await repository.deleteRecipe('archive-recipe');

    expect(
      (await repository.getRecipe('archive-recipe'))!.lifecycle,
      NutritionRecipeLifecycle.archived,
    );
    expect(await repository.getVersion('archive-v1'), isNotNull);
    await repository.restoreRecipe('archive-recipe');
    expect(
      (await repository.getRecipe('archive-recipe'))!.lifecycle,
      NutritionRecipeLifecycle.active,
    );
  });

  test(
    'unreferenced draft can be deleted, nested recipes cannot be persisted',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _seedFoods(db, const ['food-a']);
      final repository = NutritionRecipeRepository(db: db);
      final draft = await repository.createRecipe(
        userId: 'recipe-user',
        recipeId: 'draft-delete-recipe',
        versionId: 'draft-delete-v1',
        name: 'Draft delete',
      );
      await repository.deleteRecipe(draft.recipe.id);
      expect(await repository.getRecipe(draft.recipe.id), isNull);
      expect(await repository.getVersion(draft.version.id), isNull);

      expect(
        () => repository.createRecipe(
          userId: 'recipe-user',
          recipeId: 'nested-recipe',
          versionId: 'nested-v1',
          name: 'Nested recipe',
          ingredients: [
            NutritionRecipeIngredientInput.nestedRecipe(
              id: 'nested-line',
              recipeVersionId: 'other-version',
              quantity: Quantity.fromDecimal(
                amount: '1',
                unit: QuantityUnit.serving,
                context: const QuantityContext(
                  servingDefinition: ServingDefinitionReference(
                    id: 'other-serving',
                    revision: 'v1',
                  ),
                ),
              ),
            ),
          ],
        ),
        throwsA(isA<NutritionRecipeNestedReferenceError>()),
      );
    },
  );

  test(
    'Backup v8 round-trip preserves recipe IDs, ancestry, order, and quantities',
    () async {
      final sourceDb = AppDatabase.memory();
      final targetDb = AppDatabase.memory();
      addTearDown(sourceDb.close);
      addTearDown(targetDb.close);
      await _seedFoods(sourceDb, const ['backup-food']);
      final repository = NutritionRecipeRepository(db: sourceDb);
      final draft = await repository.createRecipe(
        userId: 'backup-user',
        recipeId: 'backup-recipe',
        versionId: 'backup-v1',
        name: 'Backup recipe',
        ingredients: [_ingredient('backup-line', 'backup-food', '125')],
      );
      await repository.publishDraft(
        recipeId: draft.recipe.id,
        draftVersionId: draft.version.id,
      );

      final backup = await BackupV8Data.createFromDatabase(sourceDb);
      final decoded = BackupV8Data.fromJson(
        jsonDecode(jsonEncode(backup.toJson())) as Map<String, dynamic>,
      );
      await decoded.restoreToDatabase(targetDb);

      final targetRepository = NutritionRecipeRepository(db: targetDb);
      final restored = await targetRepository.getVersion('backup-v1');
      expect(restored, isNotNull);
      expect(restored!.ingredients.single.foodId, 'backup-food');
      expect(restored.ingredients.single.quantity.amount.toString(), '125');
      expect(
        (await targetRepository.getRecipe('backup-recipe'))!.currentVersionId,
        'backup-v1',
      );
    },
  );
}

NutritionRecipeIngredientInput _ingredient(
  String id,
  String foodId,
  String amount, {
  int? position,
  String? substitutedFromFoodId,
  String? provenanceSource,
}) => NutritionRecipeIngredientInput.directFood(
  id: id,
  foodId: foodId,
  quantity: Quantity.fromDecimal(amount: amount, unit: QuantityUnit.gram),
  position: position,
  substitutedFromFoodId: substitutedFromFoodId,
  provenanceSource: provenanceSource,
);

Future<void> _seedFoods(AppDatabase db, Iterable<String> ids) async {
  for (final id in ids) {
    await db
        .into(db.nutritionFoods)
        .insert(
          NutritionFoodsCompanion.insert(
            id: id,
            kind: id.startsWith('unknown') ? 'unknown' : 'userCreated',
            displayName: id,
            locale: 'en-IN',
            sourceType: 'user',
            lifecycle: id.startsWith('unknown') ? 'unresolved' : 'active',
          ),
        );
  }
}
