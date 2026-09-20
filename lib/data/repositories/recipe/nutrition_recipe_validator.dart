import '../../../core/typed_quantities.dart';
import '../../database/app_database.dart';
import '../nutrition_recipe_repository.dart';

/// Extracted validator for recipe inputs, graphs, and version ancestry.
class NutritionRecipeValidator {
  final AppDatabase _db;

  const NutritionRecipeValidator(this._db);

  Future<List<NutritionRecipeIngredientInput>> validateIngredientInputs({
    required String recipeVersionId,
    required List<NutritionRecipeIngredientInput> inputs,
  }) async {
    final positions = <int>{};
    final ids = <String>{};
    final result = <NutritionRecipeIngredientInput>[];
    for (var index = 0; index < inputs.length; index++) {
      final input = inputs[index];
      if (input.id.trim().isEmpty || !ids.add(input.id)) {
        throw const NutritionRecipeValidationError(
          'duplicate_ingredient_id',
          'Ingredient line IDs must be unique and non-empty.',
        );
      }
      if (input.nestedRecipeVersionId != null) {
        throw const NutritionRecipeNestedReferenceError(
          'Nested recipe ingredients are deferred from B03-07.',
        );
      }
      final position = input.position ?? index;
      if (position < 0 || !positions.add(position)) {
        throw const NutritionRecipeValidationError(
          'invalid_ingredient_order',
          'Ingredient positions must be unique non-negative values.',
        );
      }
      NutritionQuantityService.validatePositiveRecipeIngredientQuantity(
        input.quantity,
      );
      validatePersistableQuantity(input.quantity, input.measureId);
      if (input.lower != null &&
              input.lower!.compareTo(input.quantity.amount) > 0 ||
          input.upper != null &&
              input.upper!.compareTo(input.quantity.amount) < 0 ||
          input.lower != null &&
              input.upper != null &&
              input.lower!.compareTo(input.upper!) > 0) {
        throw const NutritionRecipeValidationError(
          'invalid_ingredient_range',
          'Ingredient quantity bounds must contain the quantity.',
        );
      }
      final foodId = input.foodId;
      if (foodId == null || foodId.trim().isEmpty) {
        throw const NutritionRecipeValidationError(
          'missing_food_identity',
          'Every direct ingredient requires an explicit portable food identity.',
        );
      }
      final food = await (_db.select(
        _db.nutritionFoods,
      )..where((row) => row.id.equals(foodId))).getSingleOrNull();
      if (food == null) {
        throw NutritionRecipeValidationError(
          'missing_food_identity',
          'Ingredient references unknown food identity $foodId.',
        );
      }
      if (input.preparationId != null) {
        final preparation =
            await (_db.select(_db.nutritionFoodPreparations)
                  ..where((row) => row.id.equals(input.preparationId!)))
                .getSingleOrNull();
        if (preparation == null || preparation.foodId != food.id) {
          throw const NutritionRecipeValidationError(
            'invalid_preparation_reference',
            'Ingredient preparation must belong to its food identity.',
          );
        }
      }
      if (input.measureId != null) {
        final measure = await (_db.select(
          _db.nutritionHouseholdMeasures,
        )..where((row) => row.id.equals(input.measureId!))).getSingleOrNull();
        if (measure == null ||
            input.quantity.dimension != QuantityDimension.householdReference) {
          throw const NutritionRecipeValidationError(
            'invalid_quantity_context',
            'A measure reference is valid only for a known household quantity.',
          );
        }
      }
      if (input.quantity.dimension == QuantityDimension.householdReference &&
          input.measureId == null) {
        throw const NutritionRecipeValidationError(
          'missing_quantity_context',
          'Household recipe quantities require an explicit measure reference.',
        );
      }
      if (input.substitutedFromFoodId != null) {
        if (input.substitutedFromFoodId == food.id) {
          throw const NutritionRecipeValidationError(
            'invalid_substitution',
            'A substitution must identify a different prior food.',
          );
        }
        final prior =
            await (_db.select(_db.nutritionFoods)
                  ..where((row) => row.id.equals(input.substitutedFromFoodId!)))
                .getSingleOrNull();
        if (prior == null) {
          throw NutritionRecipeValidationError(
            'missing_substitution_identity',
            'Substitution provenance references unknown food ${input.substitutedFromFoodId}.',
          );
        }
      }
      result.add(
        NutritionRecipeIngredientInput.directFood(
          id: input.id.trim(),
          foodId: food.id,
          quantity: input.quantity,
          position: position,
          preparationId: input.preparationId,
          measureId: input.measureId,
          lower: input.lower,
          upper: input.upper,
          notes: input.notes,
          substitutedFromFoodId: input.substitutedFromFoodId,
          provenanceSource: input.provenanceSource,
        ),
      );
    }
    final expected = List<int>.generate(
      inputs.length,
      (index) => index,
    ).toSet();
    if (!positions.containsAll(expected) ||
        positions.length != expected.length) {
      throw const NutritionRecipeValidationError(
        'invalid_ingredient_order',
        'Ingredient positions must form a contiguous ordered sequence.',
      );
    }
    result.sort((a, b) => a.position!.compareTo(b.position!));
    return result;
  }

  Future<void> validateStoredIngredients(
    String recipeVersionId,
    List<NutritionRecipeIngredient> rows,
  ) async {
    final positions = rows.map((row) => row.position).toSet();
    final expected = List<int>.generate(rows.length, (index) => index).toSet();
    if (positions.length != rows.length ||
        !positions.containsAll(expected) ||
        rows.any(
          (row) =>
              row.recipeVersionId != recipeVersionId ||
              row.quantityValue <= 0 ||
              row.foodId.trim().isEmpty,
        )) {
      throw const NutritionRecipeValidationError(
        'invalid_ingredient_graph',
        'Stored ingredient graph is malformed.',
      );
    }
    for (final row in rows) {
      final food = await (_db.select(
        _db.nutritionFoods,
      )..where((food) => food.id.equals(row.foodId))).getSingleOrNull();
      if (food == null) {
        throw const NutritionRecipeValidationError(
          'missing_food_identity',
          'Stored ingredient graph references a missing food.',
        );
      }
    }
  }

  void validatePersistableQuantity(Quantity quantity, String? measureId) {
    if (quantity.unit == QuantityUnit.unknown ||
        quantity.unit == QuantityUnit.legacy ||
        quantity.dimension == QuantityDimension.unknown ||
        quantity.dimension == QuantityDimension.legacy) {
      throw const NutritionRecipeValidationError(
        'unsupported_quantity',
        'Legacy and unknown quantities cannot be recipe ingredients.',
      );
    }
    if (quantity.dimension == QuantityDimension.serving &&
        quantity.context.servingDefinition == null) {
      throw const NutritionRecipeValidationError(
        'missing_quantity_context',
        'Serving recipe quantities require a serving definition.',
      );
    }
    if (quantity.dimension == QuantityDimension.householdReference &&
        quantity.context.householdMeasure == null &&
        measureId == null) {
      throw const NutritionRecipeValidationError(
        'missing_quantity_context',
        'Household recipe quantities require a typed measure context.',
      );
    }
  }

  void validateVersionInputs({
    required Quantity? yieldQuantity,
    required NutritionRecipeServingDefinition? servingDefinition,
    required String calculationRuleVersion,
    required NutritionRecipeSource source,
  }) {
    if (yieldQuantity != null) {
      NutritionQuantityService.validatePositiveUserEnteredPortion(
        yieldQuantity,
      );
      if ({
        QuantityDimension.serving,
        QuantityDimension.householdReference,
        QuantityDimension.unknown,
        QuantityDimension.legacy,
      }.contains(yieldQuantity.dimension)) {
        throw const NutritionRecipeValidationError(
          'invalid_yield_quantity',
          'Recipe yield requires a canonical mass, volume, or count quantity.',
        );
      }
    }
    servingDefinition?.validate();
    requireText(calculationRuleVersion, 'calculationRuleVersion');
    if (source.parentVersionId != null &&
        source.parentVersionId!.trim().isEmpty) {
      throw const NutritionRecipeValidationError(
        'invalid_version_ancestry',
        'A recipe version parent ID cannot be empty.',
      );
    }
    if (source.copiedFromVersionId != null &&
        source.copiedFromVersionId!.trim().isEmpty) {
      throw const NutritionRecipeValidationError(
        'invalid_copy_provenance',
        'A copied-from recipe version ID cannot be empty.',
      );
    }
  }

  void assertOwnedDraft(
    NutritionRecipe recipe,
    NutritionRecipeVersion version, {
    bool allowPublished = false,
  }) {
    if (version.recipeId != recipe.id) {
      throw const NutritionRecipeValidationError(
        'cross_recipe_version_reference',
        'Recipe version belongs to another recipe.',
      );
    }
    if (!allowPublished && version.status != 'draft') {
      throw const NutritionRecipeImmutableError(
        'Published recipe versions cannot be edited.',
      );
    }
  }

  Future<void> validateRecipeGraph(NutritionRecipe recipe) async {
    final versions = await (_db.select(
      _db.nutritionRecipeVersions,
    )..where((row) => row.recipeId.equals(recipe.id))).get();
    validateVersionAncestry(recipe, versions);
    if (recipe.currentVersionId != null) {
      final current = versions
          .where((row) => row.id == recipe.currentVersionId)
          .toList();
      if (current.length != 1 || current.single.status != 'published') {
        throw const NutritionRecipeValidationError(
          'invalid_current_version',
          'Recipe current head must reference one of its published versions.',
        );
      }
    }
    final drafts = versions.where((row) => row.status == 'draft');
    if (drafts.length > 1) {
      throw const NutritionRecipeValidationError(
        'multiple_drafts',
        'A recipe cannot have multiple editable drafts.',
      );
    }
    for (final version in versions) {
      final ingredients = await (_db.select(
        _db.nutritionRecipeIngredients,
      )..where((row) => row.recipeVersionId.equals(version.id))).get();
      await validateStoredIngredients(version.id, ingredients);
      if (version.status != 'draft' && ingredients.isEmpty) {
        throw const NutritionRecipeValidationError(
          'empty_immutable_recipe',
          'Published or archived versions must retain their ingredient graph.',
        );
      }
    }
  }

  void validateVersionAncestry(
    NutritionRecipe recipe,
    List<NutritionRecipeVersion> versions,
  ) {
    final byId = {for (final version in versions) version.id: version};
    for (final version in versions) {
      final source = NutritionRecipeSource.decode(version.source);
      final parentId = source.parentVersionId;
      if (parentId == null) continue;
      final parent = byId[parentId];
      if (parent == null ||
          parent.recipeId != recipe.id ||
          parent.versionNumber >= version.versionNumber) {
        throw const NutritionRecipeValidationError(
          'invalid_version_ancestry',
          'Recipe version ancestry must point to an earlier version of the same recipe.',
        );
      }
      final seen = <String>{version.id};
      var cursor = parent;
      while (true) {
        if (!seen.add(cursor.id)) {
          throw const NutritionRecipeValidationError(
            'version_ancestry_cycle',
            'Recipe version ancestry contains a cycle.',
          );
        }
        final nextId = NutritionRecipeSource.decode(
          cursor.source,
        ).parentVersionId;
        if (nextId == null) break;
        final next = byId[nextId];
        if (next == null || next.recipeId != recipe.id) {
          throw const NutritionRecipeValidationError(
            'invalid_version_ancestry',
            'Recipe version ancestry references a missing parent.',
          );
        }
        cursor = next;
      }
    }
  }

  void requireText(String value, String label) {
    if (value.trim().isEmpty) {
      throw NutritionRecipeValidationError(
        'invalid_$label',
        '$label must not be empty.',
      );
    }
  }
}
