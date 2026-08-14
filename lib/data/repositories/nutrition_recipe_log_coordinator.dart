import 'package:drift/drift.dart';

import '../../core/nutrients.dart';
import '../../core/nutrition_calculation_service.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/typed_quantities.dart';
import '../database/app_database.dart' hide NutritionConsumptionSnapshot;
import 'nutrition_consumption_repository.dart';
import 'nutrition_recipe_repository.dart';

/// A typed failure at the saved-recipe logging boundary.
class NutritionRecipeLogError implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const NutritionRecipeLogError(this.code, this.message, {this.cause});

  factory NutritionRecipeLogError.fromCalculation(
    NutritionCalculationError error,
  ) => NutritionRecipeLogError(error.code, error.message, cause: error);

  @override
  String toString() => 'NutritionRecipeLogError($code): $message';
}

enum NutritionRecipeLogAmountKind {
  wholeRecipe,
  fraction,
  declaredServing,
  scalar,
}

extension NutritionRecipeLogAmountKindContract on NutritionRecipeLogAmountKind {
  String get stableId => switch (this) {
    NutritionRecipeLogAmountKind.wholeRecipe => 'whole_recipe',
    NutritionRecipeLogAmountKind.fraction => 'fraction',
    NutritionRecipeLogAmountKind.declaredServing => 'declared_serving',
    NutritionRecipeLogAmountKind.scalar => 'scalar',
  };
}

/// The only amount choices exposed by the B03-12 logging flow.
class NutritionRecipeLogAmount {
  final NutritionRecipeLogAmountKind kind;
  final QuantityAmount value;

  const NutritionRecipeLogAmount._({required this.kind, required this.value});

  NutritionRecipeLogAmount.wholeRecipe()
    : this._(
        kind: NutritionRecipeLogAmountKind.wholeRecipe,
        value: QuantityAmount.one,
      );

  NutritionRecipeLogAmount.declaredServing()
    : this._(
        kind: NutritionRecipeLogAmountKind.declaredServing,
        value: QuantityAmount.one,
      );

  factory NutritionRecipeLogAmount.fraction(Object value) =>
      NutritionRecipeLogAmount._(
        kind: NutritionRecipeLogAmountKind.fraction,
        value: _amount(value),
      );

  factory NutritionRecipeLogAmount.scalar(Object value) =>
      NutritionRecipeLogAmount._(
        kind: NutritionRecipeLogAmountKind.scalar,
        value: _amount(value),
      );

  NutritionScaleRequest get calculationScale => switch (kind) {
    NutritionRecipeLogAmountKind.wholeRecipe =>
      const NutritionScaleRequest.wholeRecipe(),
    NutritionRecipeLogAmountKind.fraction => NutritionScaleRequest.fraction(
      value,
    ),
    NutritionRecipeLogAmountKind.declaredServing =>
      const NutritionScaleRequest.perDeclaredServing(),
    NutritionRecipeLogAmountKind.scalar => NutritionScaleRequest.scalar(value),
  };

  Map<String, dynamic> toJson() => {
    'kind': kind.stableId,
    'value': value.toJsonValue(),
  };

  String get displayLabel => switch (kind) {
    NutritionRecipeLogAmountKind.wholeRecipe => 'Whole recipe',
    NutritionRecipeLogAmountKind.fraction => '${value.toString()} of recipe',
    NutritionRecipeLogAmountKind.declaredServing => '1 declared serving',
    NutritionRecipeLogAmountKind.scalar => '${value.toString()}× recipe',
  };
}

QuantityAmount _amount(Object value) {
  try {
    if (value is QuantityAmount) return value;
    if (value is String) return QuantityAmount.fromString(value);
    if (value is num) return QuantityAmount.fromNum(value);
  } on QuantityError catch (error) {
    throw NutritionRecipeLogError(
      'invalid_amount',
      'Recipe amount is not a finite, non-negative decimal.',
      cause: error,
    );
  }
  throw const NutritionRecipeLogError(
    'invalid_amount',
    'Recipe amount is not a supported decimal value.',
  );
}

class NutritionRecipeLogPreview {
  final NutritionRecipeModel recipe;
  final NutritionRecipeVersionModel version;
  final NutritionRecipeLogAmount amount;
  final NutritionCalculationResult calculation;

  const NutritionRecipeLogPreview({
    required this.recipe,
    required this.version,
    required this.amount,
    required this.calculation,
  });

  bool get isPartial =>
      calculation.completeness.state == NutrientCompletenessState.partial;

  bool get isUnknown =>
      calculation.completeness.state == NutrientCompletenessState.unknown;

  Map<String, dynamic> get evidence => {
    'recipe_id': recipe.id,
    'recipe_name': recipe.name,
    'recipe_version_id': version.id,
    'recipe_version_number': version.versionNumber,
    'recipe_version_updated_at': version.updatedAt.toUtc().toIso8601String(),
    'recipe_head_version_id': recipe.currentVersionId,
    'amount': amount.toJson(),
    'calculation_fingerprint': calculation.lineage.fingerprint,
    'calculation_rule_version': calculation.calculationRuleVersion,
    'nutrient_registry_version': calculation.nutrientRegistryVersion,
  };
}

/// B03-12's integration boundary.
///
/// This coordinator owns no durable nutrition graph and performs no nutrient
/// arithmetic. It resolves immutable recipe inputs, delegates calculation to
/// B03-08, and submits one typed command to B03-11A.
class NutritionRecipeLogCoordinator {
  final AppDatabase _db;
  final NutritionRecipeRepository _recipes;
  final NutritionCalculationService _calculator;
  final NutritionConsumptionRepository _consumption;
  final NutrientRegistry _registry;

  NutritionRecipeLogCoordinator({
    required AppDatabase db,
    required NutritionRecipeRepository recipes,
    required NutritionCalculationService calculator,
    required NutritionConsumptionRepository consumption,
    required NutrientRegistry registry,
  }) : _db = db,
       _recipes = recipes,
       _calculator = calculator,
       _consumption = consumption,
       _registry = registry;

  NutritionRecipeRepository get recipes => _recipes;

  Future<void> archiveRecipe(String recipeId) =>
      _recipes.archiveRecipe(recipeId);

  Future<List<NutritionRecipeModel>> listSavedRecipes({
    required String userId,
    String query = '',
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    final recipes = await _recipes.listRecipes(userId: userId.trim());
    return recipes
        .where(
          (recipe) =>
              recipe.lifecycle == NutritionRecipeLifecycle.active &&
              recipe.currentVersionId != null &&
              (normalizedQuery.isEmpty ||
                  recipe.name.toLowerCase().contains(normalizedQuery)),
        )
        .toList(growable: false);
  }

  /// Drafts are exposed beside saved recipes so the authoring surface can
  /// reopen an incomplete recipe without treating a mutable version as
  /// loggable history.
  Future<List<NutritionRecipeDraftModel>> listDrafts({
    required String userId,
    String query = '',
  }) => _recipes.listDrafts(userId: userId, query: query);

  Future<List<NutritionRecipeVersionModel>> listLoggableVersions({
    required String recipeId,
    required String userId,
  }) async {
    final recipe = await _requireActiveRecipe(recipeId, userId);
    return _recipes.listPublishedVersions(recipe.id);
  }

  Future<NutritionRecipeLogPreview> preview({
    required String userId,
    required String recipeId,
    String? recipeVersionId,
    required NutritionRecipeLogAmount amount,
  }) async {
    final recipe = await _requireActiveRecipe(recipeId, userId);
    final version = await _resolveVersion(
      recipe: recipe,
      recipeVersionId: recipeVersionId,
    );
    final ingredients = <NutritionCalculationIngredient>[];
    for (final ingredient in version.ingredients) {
      ingredients.add(
        NutritionCalculationIngredient.directFood(
          id: ingredient.id,
          foodId: ingredient.foodId,
          quantity: ingredient.quantity,
          position: ingredient.position,
          preparationId: ingredient.preparationId,
          substitutedFromFoodId: ingredient.substitutedFromFoodId,
          provenanceSource: version.source.kind.stableId,
          nutrientFacts: await _readCurrentFacts(
            foodId: ingredient.foodId,
            preparationId: ingredient.preparationId,
          ),
        ),
      );
    }

    final request = NutritionCalculationRequest(
      recipeId: recipe.id,
      recipeVersionId: version.id,
      ingredients: ingredients,
      registry: _registry,
      nutrientRegistryVersion: _registry.version,
      calculationRuleVersion: version.calculationRuleVersion,
      requestedNutrientIds: _registry.definitions
          .map((definition) => definition.id)
          .toSet(),
      declaredYield: version.yieldQuantity,
      servingDefinition: _calculationServing(version.servingDefinition),
      scale: amount.calculationScale,
    );

    late final NutritionCalculationResult calculation;
    try {
      calculation = _calculator.calculate(request);
    } on NutritionCalculationError catch (error) {
      throw NutritionRecipeLogError.fromCalculation(error);
    }
    return NutritionRecipeLogPreview(
      recipe: recipe,
      version: version,
      amount: amount,
      calculation: calculation,
    );
  }

  /// Calculates one already-resolved direct-food component through the same
  /// B03-08 service used by recipe ingredients. The pseudo calculation
  /// identity is lineage-only; the persisted snapshot item remains explicitly
  /// a direct food and never becomes a recipe record.
  Future<NutritionCalculationResult> previewDirectFood({
    required String foodId,
    required Quantity quantity,
    String? preparationId,
    String? itemId,
  }) async {
    final identity = foodId.trim();
    if (identity.isEmpty) {
      throw const NutritionRecipeLogError(
        'missing_food_id',
        'A direct-food calculation requires a portable food identity.',
      );
    }
    try {
      NutritionQuantityService.validatePositiveConsumedQuantity(quantity);
    } on QuantityError catch (error) {
      throw NutritionRecipeLogError(
        'invalid_quantity',
        error.toString(),
        cause: error,
      );
    }
    final food = await (_db.select(
      _db.nutritionFoods,
    )..where((row) => row.id.equals(identity))).getSingleOrNull();
    if (food == null) {
      throw const NutritionRecipeLogError(
        'food_not_found',
        'The selected direct food is no longer available.',
      );
    }
    if (food.lifecycle != 'active') {
      throw const NutritionRecipeLogError(
        'inactive_food',
        'Archived or unresolved foods cannot be used for a new thali.',
      );
    }
    final preparation = preparationId?.trim();
    final calculationIdentity =
        'direct-food:$identity:${preparation == null || preparation.isEmpty ? 'default' : preparation}';
    final ingredients = [
      NutritionCalculationIngredient.directFood(
        id: itemId?.trim().isNotEmpty == true
            ? itemId!.trim()
            : 'direct-food-line:$identity',
        foodId: identity,
        quantity: quantity,
        position: 0,
        preparationId: preparation == null || preparation.isEmpty
            ? null
            : preparation,
        provenanceSource: food.sourceType,
        nutrientFacts: await _readCurrentFacts(
          foodId: identity,
          preparationId: preparation == null || preparation.isEmpty
              ? null
              : preparation,
        ),
      ),
    ];
    try {
      return _calculator.calculate(
        NutritionCalculationRequest(
          recipeId: calculationIdentity,
          recipeVersionId: calculationIdentity,
          ingredients: ingredients,
          registry: _registry,
          nutrientRegistryVersion: _registry.version,
          calculationRuleVersion: 'direct-food-b03-13-v1',
          requestedNutrientIds: _registry.definitions
              .map((definition) => definition.id)
              .toSet(),
        ),
      );
    } on NutritionCalculationError catch (error) {
      throw NutritionRecipeLogError.fromCalculation(error);
    }
  }

  Future<NutritionConsumptionSnapshot> finalize({
    required String userId,
    required NutritionRecipeLogPreview preview,
    required String mealCategory,
    required DateTime loggedAt,
    String? mealGroupId,
    String? localDate,
    String? timezoneId,
    String? consumptionId,
    required String commandId,
    bool allowPartial = false,
    String? supersedesSnapshotId,
    String? correctionId,
    String? correctionReason,
  }) async {
    if (commandId.trim().isEmpty) {
      throw const NutritionRecipeLogError(
        'missing_command_id',
        'A retryable finalization command ID is required.',
      );
    }

    final request = _buildFinalizeRequest(
      userId: userId,
      preview: preview,
      mealCategory: mealCategory,
      loggedAt: loggedAt,
      mealGroupId: mealGroupId,
      localDate: localDate,
      timezoneId: timezoneId,
      consumptionId: consumptionId,
      commandId: commandId,
      supersedesSnapshotId: supersedesSnapshotId,
      correctionId: correctionId,
      correctionReason: correctionReason,
    );

    // Re-acknowledge an already committed command before consulting mutable
    // recipe lifecycle/head state. This is what makes a lost acknowledgement
    // safe after a recipe is archived or a successor is published.
    final existing = consumptionId == null
        ? await _consumption.findByCommandId(
            userId: userId,
            commandId: commandId,
          )
        : await _consumption.getSnapshot(
                userId: userId,
                consumptionId: consumptionId,
              ) ??
              await _consumption.findByCommandId(
                userId: userId,
                commandId: commandId,
              );
    if (existing != null) {
      return _submit(request);
    }

    if ((preview.isPartial || preview.isUnknown) && !allowPartial) {
      throw const NutritionRecipeLogError(
        'partial_confirmation_required',
        'This preview is incomplete. Confirm that unknown nutrients may be logged.',
      );
    }
    final recipe = await _requireActiveRecipe(preview.recipe.id, userId);
    final previewHeadVersionId = preview.evidence['recipe_head_version_id'];
    if (previewHeadVersionId is! String ||
        recipe.currentVersionId != previewHeadVersionId) {
      throw NutritionRecipeLogError(
        'stale_recipe_version',
        'This recipe changed after preview. Review the published version choices before saving.',
      );
    }
    final version = await _recipes.getVersion(preview.version.id);
    if (version == null ||
        version.status != NutritionRecipeVersionStatus.published) {
      throw const NutritionRecipeLogError(
        'unloggable_recipe_version',
        'The selected recipe version is no longer published.',
      );
    }
    if (preview.calculation.recipeVersionId != version.id) {
      throw const NutritionRecipeLogError(
        'preview_version_mismatch',
        'The preview does not belong to the selected immutable recipe version.',
      );
    }
    return _submit(request);
  }

  NutritionConsumptionFinalizeRequest _buildFinalizeRequest({
    required String userId,
    required NutritionRecipeLogPreview preview,
    required String mealCategory,
    required DateTime loggedAt,
    required String? mealGroupId,
    required String? localDate,
    required String? timezoneId,
    required String? consumptionId,
    required String commandId,
    required String? supersedesSnapshotId,
    required String? correctionId,
    required String? correctionReason,
  }) {
    final calculation =
        NutritionConsumptionCalculationSnapshot.fromRecipeResult(
          preview.calculation,
        );
    final itemId = '${consumptionId ?? commandId}::recipe';
    final version = preview.version;
    return NutritionConsumptionFinalizeRequest(
      userId: userId,
      consumptionId: consumptionId,
      commandId: commandId,
      loggedAtUtc: loggedAt,
      mealCategory: mealCategory,
      mealGroupId: mealGroupId,
      sourceType: 'recipe',
      recipeVersionId: version.id,
      localDate: localDate,
      timezoneId: timezoneId,
      supersedesSnapshotId: supersedesSnapshotId,
      correctionId: correctionId,
      correctionReason: correctionReason,
      calculatorVersion: preview.calculation.calculationRuleVersion,
      evidence: {
        ...preview.evidence,
        'recipe_source': version.source.encode(),
        'selected_version_id': version.id,
      },
      items: [
        NutritionConsumptionItemInput(
          id: itemId,
          position: 0,
          sourceType: 'recipe',
          recipeVersionId: version.id,
          sourceReference: preview.recipe.id,
          displayLabel: preview.recipe.name,
          quantity: _snapshotQuantity(version, preview.amount),
          calculation: calculation,
          evidence: preview.evidence,
        ),
      ],
    );
  }

  Future<NutritionConsumptionSnapshot> _submit(
    NutritionConsumptionFinalizeRequest request,
  ) async {
    try {
      return await _consumption.finalizeConsumption(request);
    } on NutritionConsumptionError catch (error) {
      throw NutritionRecipeLogError(error.code, error.message, cause: error);
    }
  }

  Future<NutritionRecipeModel> _requireActiveRecipe(
    String recipeId,
    String userId,
  ) async {
    final recipe = await _recipes.getRecipe(recipeId.trim());
    if (recipe == null || recipe.userId != userId.trim()) {
      throw const NutritionRecipeLogError(
        'recipe_not_found',
        'The saved recipe could not be found for this user.',
      );
    }
    if (recipe.lifecycle != NutritionRecipeLifecycle.active) {
      throw const NutritionRecipeLogError(
        'archived_recipe',
        'Archived recipes are not offered for new logging.',
      );
    }
    return recipe;
  }

  Future<NutritionRecipeVersionModel> _resolveVersion({
    required NutritionRecipeModel recipe,
    required String? recipeVersionId,
  }) async {
    final version = recipeVersionId == null
        ? await _recipes.getCurrentPublishedVersion(recipe.id)
        : await _recipes.getVersion(recipeVersionId);
    if (version == null) {
      throw const NutritionRecipeLogError(
        'unpublished_recipe',
        'The saved recipe has no published version available for logging.',
      );
    }
    if (version.recipeId != recipe.id) {
      throw const NutritionRecipeLogError(
        'recipe_version_mismatch',
        'The selected version does not belong to the selected recipe.',
      );
    }
    if (version.status != NutritionRecipeVersionStatus.published) {
      throw const NutritionRecipeLogError(
        'unpublished_recipe_version',
        'Draft and archived recipe versions cannot be logged.',
      );
    }
    return version;
  }

  Future<Map<String, NutrientFact>> _readCurrentFacts({
    required String foodId,
    required String? preparationId,
  }) async {
    final query = _db.select(_db.nutritionFoodNutrientFacts)
      ..where((row) => row.foodId.equals(foodId) & row.isCurrent.equals(true));
    if (preparationId == null) {
      query.where((row) => row.preparationId.isNull());
    } else {
      query.where((row) => row.preparationId.equals(preparationId));
    }
    final rows =
        await (query..orderBy([
              (row) => OrderingTerm(
                expression: row.factVersion,
                mode: OrderingMode.desc,
              ),
            ]))
            .get();
    final facts = <String, NutrientFact>{};
    for (final row in rows) {
      if (facts.containsKey(row.nutrientId)) continue;
      facts[row.nutrientId] = _factFromRow(row);
    }
    return facts;
  }

  NutrientFact _factFromRow(NutritionFoodNutrientFact row) {
    final definition = _registry.definitionFor(row.nutrientId);
    final source = _sourceFromDatabase(row.source);
    final sourceReference =
        row.sourceRef ??
        'food:${row.foodId}:nutrient:${row.nutrientId}:v${row.factVersion}';
    final factVersion = row.factVersion.toString();
    final status = NutrientFactStatusContract.fromStableId(row.status);
    final basis = _basisFromDatabase(row.basis);
    if (basis == null) {
      return NutrientFact.missing(
        nutrientId: row.nutrientId,
        unit: definition.unit,
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: source,
        sourceReference: sourceReference,
        factVersion: factVersion,
      );
    }
    if (status == NutrientFactStatus.missing ||
        status == NutrientFactStatus.notApplicable) {
      return NutrientFact(
        nutrientId: row.nutrientId,
        unit: definition.unit,
        status: status,
        basis: basis,
        source: source,
        sourceReference: sourceReference,
        factVersion: factVersion,
      );
    }
    final point = row.amount == null
        ? null
        : NutrientAmount(
            value: QuantityAmount.fromNum(row.amount!),
            unit: definition.unit,
          );
    if (point == null && row.lower == null && row.upper == null) {
      return NutrientFact.missing(
        nutrientId: row.nutrientId,
        unit: definition.unit,
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: source,
        sourceReference: sourceReference,
        factVersion: factVersion,
      );
    }
    NutrientAmount? amount(double? value) => value == null
        ? null
        : NutrientAmount(
            value: QuantityAmount.fromNum(value),
            unit: definition.unit,
          );
    return NutrientFact(
      nutrientId: row.nutrientId,
      unit: definition.unit,
      status: status,
      point: point,
      lower: amount(row.lower),
      upper: amount(row.upper),
      basis: basis,
      source: source,
      sourceReference: sourceReference,
      confidence: _confidence(row.confidence, source),
      factVersion: factVersion,
    );
  }

  NutrientBasis? _basisFromDatabase(String value) => switch (value) {
    'per_100_grams' => NutrientBasis(NutrientBasisKind.per100Grams),
    'per_100_millilitres' => NutrientBasis(NutrientBasisKind.per100Millilitres),
    'absolute' => NutrientBasis(NutrientBasisKind.absolute),
    // v17 facts do not carry a portable serving-definition reference. Do not
    // borrow the recipe's serving definition or invent one for a food fact.
    'per_serving' => null,
    _ => null,
  };

  NutrientSourceType _sourceFromDatabase(String value) => switch (value) {
    'bundled_asset' => NutrientSourceType.bundledCatalogue,
    'regional_asset' => NutrientSourceType.regionalCatalogue,
    'reviewed_catalogue' => NutrientSourceType.reviewedCatalogue,
    'manufacturer_label' => NutrientSourceType.manufacturerLabel,
    'user_entered' => NutrientSourceType.userEntered,
    'imported_provider' => NutrientSourceType.importedProvider,
    'recipe_calculation' => NutrientSourceType.recipeCalculation,
    'ai_estimate' => NutrientSourceType.aiEstimate,
    'heuristic' => NutrientSourceType.heuristic,
    'legacy' => NutrientSourceType.legacy,
    _ => NutrientSourceType.unknown,
  };

  NutrientConfidence _confidence(double? value, NutrientSourceType source) {
    if (source == NutrientSourceType.reviewedCatalogue) {
      return NutrientConfidence.reviewed;
    }
    if (value == null) return NutrientConfidence.notProvided;
    if (value >= 0.9) return NutrientConfidence.high;
    if (value >= 0.7) return NutrientConfidence.medium;
    return NutrientConfidence.low;
  }

  NutritionCalculationServingDefinition? _calculationServing(
    NutritionRecipeServingDefinition? definition,
  ) {
    if (definition == null) return null;
    return NutritionCalculationServingDefinition(
      id: definition.id,
      revision: definition.revision,
      count: definition.count,
      source: definition.source,
    );
  }

  Quantity _snapshotQuantity(
    NutritionRecipeVersionModel version,
    NutritionRecipeLogAmount amount,
  ) {
    if (amount.kind == NutritionRecipeLogAmountKind.wholeRecipe &&
        version.yieldQuantity != null) {
      return version.yieldQuantity!;
    }
    final definition =
        amount.kind == NutritionRecipeLogAmountKind.declaredServing
        ? _servingReference(version.servingDefinition!)
        : ServingDefinitionReference(
            id: 'recipe-complete:${version.id}',
            revision: version.calculationRuleVersion,
            source: 'recipe_version',
          );
    final count = amount.kind == NutritionRecipeLogAmountKind.wholeRecipe
        ? QuantityAmount.one
        : amount.value;
    return Quantity.serving(
      amount: count.toString(),
      definition: definition,
      source: amount.kind.stableId,
    );
  }

  ServingDefinitionReference _servingReference(
    NutritionRecipeServingDefinition definition,
  ) => ServingDefinitionReference(
    id: definition.id,
    revision: definition.revision,
    source: definition.source,
  );
}
