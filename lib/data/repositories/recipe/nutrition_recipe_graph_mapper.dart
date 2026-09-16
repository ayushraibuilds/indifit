import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/typed_quantities.dart';
import '../../database/app_database.dart';
import '../nutrition_recipe_repository.dart';
import 'nutrition_recipe_validator.dart';

/// Extracted mapper for recipe versions, ingredients, quantities, and graph projections.
class NutritionRecipeGraphMapper {
  final AppDatabase _db;
  final Uuid _uuid;
  final NutritionRecipeValidator _validator;

  NutritionRecipeGraphMapper(
    this._db,
    this._uuid, {
    NutritionRecipeValidator? validator,
  }) : _validator = validator ?? NutritionRecipeValidator(_db);

  Future<List<NutritionRecipeIngredientInput>> ingredientsAsInputs(
    NutritionRecipeVersion sourceVersion,
  ) async {
    final rows =
        await (_db.select(_db.nutritionRecipeIngredients)
              ..where((row) => row.recipeVersionId.equals(sourceVersion.id))
              ..orderBy([(row) => OrderingTerm(expression: row.position)]))
            .get();
    final corrections = await substitutionCorrections(
      rows.map((row) => row.id),
    );
    return [
      for (final row in rows)
        NutritionRecipeIngredientInput.directFood(
          id: _uuid.v4(),
          foodId: row.foodId,
          quantity: quantityFromStored(
            row.quantityValue,
            row.quantityUnit,
            recipeVersionId: sourceVersion.id,
            calculationRuleVersion: sourceVersion.calcRuleVersion,
            measureId: row.measureId,
          )!,
          position: row.position,
          preparationId: row.preparationId,
          measureId: row.measureId,
          lower: row.lower == null ? null : QuantityAmount.fromNum(row.lower!),
          upper: row.upper == null ? null : QuantityAmount.fromNum(row.upper!),
          notes: row.notes,
          substitutedFromFoodId: corrections[row.id],
        ),
    ];
  }

  Quantity? quantityFromStored(
    double? value,
    String? stableUnit, {
    String? recipeVersionId,
    String? calculationRuleVersion,
    String? measureId,
  }) {
    if (value == null || stableUnit == null) return null;
    final unit = quantityUnitFromDatabase(stableUnit);
    if (unit == QuantityUnit.serving) {
      return Quantity.serving(
        amount: value.toString(),
        definition: ServingDefinitionReference(
          id: recipeVersionId ?? 'recipe-serving',
          revision: calculationRuleVersion ?? 'recipe-graph-v1',
        ),
      );
    }
    if (unit == QuantityUnit.householdReference) {
      return Quantity.householdReference(
        count: value.toString(),
        reference: HouseholdMeasureReference(
          measureType: measureId ?? 'unresolved',
          calibrationId: measureId,
        ),
      );
    }
    return Quantity.fromNum(amount: value, unit: unit);
  }

  String databaseUnitId(QuantityUnit unit) => switch (unit) {
    QuantityUnit.milligram => 'milligram',
    QuantityUnit.gram => 'gram',
    QuantityUnit.kilogram => 'kilogram',
    QuantityUnit.millilitre => 'millilitre',
    QuantityUnit.litre => 'litre',
    QuantityUnit.piece => 'piece',
    QuantityUnit.serving => 'serving',
    QuantityUnit.householdReference => 'household_reference',
    QuantityUnit.unknown ||
    QuantityUnit.legacy => throw const NutritionRecipeValidationError(
      'unsupported_quantity',
      'Unknown and legacy units cannot be persisted in a recipe.',
    ),
  };

  QuantityUnit quantityUnitFromDatabase(String value) => switch (value) {
    'milligram' || 'mass_milligram' => QuantityUnit.milligram,
    'gram' || 'mass_gram' => QuantityUnit.gram,
    'kilogram' || 'mass_kilogram' => QuantityUnit.kilogram,
    'millilitre' || 'volume_millilitre' => QuantityUnit.millilitre,
    'litre' || 'volume_litre' => QuantityUnit.litre,
    'piece' || 'count_piece' => QuantityUnit.piece,
    'serving' => QuantityUnit.serving,
    'household_reference' => QuantityUnit.householdReference,
    _ => throw NutritionRecipeValidationError(
      'unsupported_quantity_unit',
      'Unsupported persisted recipe quantity unit: $value.',
    ),
  };

  Future<NutritionRecipeVersionModel> loadVersionGraph(
    NutritionRecipe recipe,
    NutritionRecipeVersion version,
  ) async {
    final allVersions =
        await (_db.select(_db.nutritionRecipeVersions)
              ..where((row) => row.recipeId.equals(recipe.id))
              ..orderBy([(row) => OrderingTerm(expression: row.versionNumber)]))
            .get();
    _validator.validateVersionAncestry(recipe, allVersions);
    final rows =
        await (_db.select(_db.nutritionRecipeIngredients)
              ..where((row) => row.recipeVersionId.equals(version.id))
              ..orderBy([(row) => OrderingTerm(expression: row.position)]))
            .get();
    await _validator.validateStoredIngredients(version.id, rows);
    final corrections = await substitutionCorrections(
      rows.map((row) => row.id),
    );
    final source = NutritionRecipeSource.decode(version.source);
    final serving = version.servingQuantity == null
        ? null
        : NutritionRecipeServingDefinition(
            id: source.servingDefinitionId ?? 'recipe-serving-${version.id}',
            revision:
                source.servingDefinitionRevision ?? version.calcRuleVersion,
            count: QuantityAmount.fromNum(version.servingQuantity!),
            source: source.servingDefinitionSource,
          );
    return NutritionRecipeVersionModel(
      id: version.id,
      recipeId: version.recipeId,
      versionNumber: version.versionNumber,
      status: versionStatus(version.status),
      yieldQuantity: quantityFromStored(
        version.yieldQuantity,
        version.yieldUnit,
      ),
      servingDefinition: serving,
      calculationRuleVersion: version.calcRuleVersion,
      source: source,
      parentVersionId: source.parentVersionId,
      createdAt: version.createdAt,
      updatedAt: version.updatedAt,
      ingredients: [
        for (final row in rows)
          NutritionRecipeIngredientModel(
            id: row.id,
            recipeVersionId: row.recipeVersionId,
            position: row.position,
            foodId: row.foodId,
            preparationId: row.preparationId,
            quantity: quantityFromStored(
              row.quantityValue,
              row.quantityUnit,
              recipeVersionId: version.id,
              calculationRuleVersion: version.calcRuleVersion,
              measureId: row.measureId,
            )!,
            measureId: row.measureId,
            lower: row.lower == null
                ? null
                : QuantityAmount.fromNum(row.lower!),
            upper: row.upper == null
                ? null
                : QuantityAmount.fromNum(row.upper!),
            notes: row.notes,
            substitutedFromFoodId: corrections[row.id],
          ),
      ],
    );
  }

  Future<Map<String, String>> substitutionCorrections(
    Iterable<String> ingredientIds,
  ) async {
    final ids = ingredientIds.toSet();
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.nutritionUserCorrections)..where(
              (row) =>
                  row.targetType.equals('recipe_ingredient') &
                  row.field.equals('substituted_from_food'),
            ))
            .get();
    return {
      for (final row in rows)
        if (ids.contains(row.targetId) && row.oldValue != null)
          row.targetId: row.oldValue!,
    };
  }

  Future<void> deleteIngredientCorrections(
    Iterable<String> ingredientIds,
  ) async {
    final ids = ingredientIds.toSet();
    if (ids.isEmpty) return;
    final rows =
        await (_db.select(_db.nutritionUserCorrections)..where(
              (row) =>
                  row.targetType.equals('recipe_ingredient') &
                  row.field.equals('substituted_from_food'),
            ))
            .get();
    for (final row in rows) {
      if (ids.contains(row.targetId)) {
        await (_db.delete(
          _db.nutritionUserCorrections,
        )..where((r) => r.id.equals(row.id))).go();
      }
    }
  }

  NutritionRecipeModel recipeModel(NutritionRecipe row) =>
      NutritionRecipeModel(
        id: row.id,
        userId: row.userId,
        name: row.name,
        description: row.description,
        lifecycle: lifecycle(row.lifecycle),
        currentVersionId: row.currentVersionId,
      );

  NutritionRecipeLifecycle lifecycle(String value) => switch (value) {
    'active' => NutritionRecipeLifecycle.active,
    'archived' => NutritionRecipeLifecycle.archived,
    'deleted' => NutritionRecipeLifecycle.deleted,
    _ => throw NutritionRecipeValidationError(
      'invalid_recipe_lifecycle',
      'Unsupported recipe lifecycle: $value.',
    ),
  };

  NutritionRecipeVersionStatus versionStatus(String value) => switch (value) {
    'draft' => NutritionRecipeVersionStatus.draft,
    'published' => NutritionRecipeVersionStatus.published,
    'archived' => NutritionRecipeVersionStatus.archived,
    _ => throw NutritionRecipeValidationError(
      'invalid_recipe_version_status',
      'Unsupported recipe version status: $value.',
    ),
  };
}
