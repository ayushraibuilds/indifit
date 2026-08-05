import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'nutrients.dart';
import 'typed_quantities.dart';

/// Version of the pure recipe-calculation request/result and lineage contract.
const int kNutritionCalculationContractVersion = 1;

/// Stable error codes exposed by [NutritionCalculationError].
abstract final class NutritionCalculationErrorCode {
  static const missingRecipeVersion = 'missing_recipe_version';
  static const invalidRecipeIdentity = 'invalid_recipe_identity';
  static const invalidIngredientGraph = 'invalid_ingredient_graph';
  static const invalidQuantity = 'invalid_quantity';
  static const incompatibleUnitOrBasis = 'incompatible_unit_or_basis';
  static const missingServingDefinition = 'missing_serving_definition';
  static const missingDensity = 'missing_density';
  static const missingPortionContext = 'missing_portion_context';
  static const missingHouseholdCalibration = 'missing_household_calibration';
  static const missingContextualConversion = 'missing_contextual_conversion';
  static const missingRecipeYield = 'missing_recipe_yield';
  static const unsupportedNestedRecipe = 'unsupported_nested_recipe';
  static const invalidScale = 'invalid_scale';
  static const unsupportedNutrientRegistryVersion =
      'unsupported_nutrient_registry_version';
  static const invalidNutrientFact = 'invalid_nutrient_fact';
  static const precisionOverflow = 'precision_overflow';
  static const rawCookedConversionDeferred = 'raw_cooked_conversion_deferred';
}

/// A typed failure from the authoritative recipe calculation boundary.
class NutritionCalculationError implements Exception {
  final String code;
  final String message;
  final String? missingContext;
  final Object? cause;

  const NutritionCalculationError(
    this.code,
    this.message, {
    this.missingContext,
    this.cause,
  });

  @override
  String toString() => 'NutritionCalculationError($code): $message';
}

class NutritionCalculationInputError extends NutritionCalculationError {
  const NutritionCalculationInputError(
    super.code,
    super.message, {
    super.missingContext,
    super.cause,
  });
}

class NutritionCalculationContextError extends NutritionCalculationError {
  const NutritionCalculationContextError(
    super.code,
    super.message, {
    required String context,
    super.cause,
  }) : super(missingContext: context);
}

class NutritionCalculationPrecisionError extends NutritionCalculationError {
  const NutritionCalculationPrecisionError(String message, {Object? cause})
    : super(
        NutritionCalculationErrorCode.precisionOverflow,
        message,
        cause: cause,
      );
}

enum NutritionScaleKind {
  wholeRecipe,
  scalar,
  requestedFraction,
  perDeclaredServing,
  requestedYield,
}

extension NutritionScaleKindContract on NutritionScaleKind {
  String get stableId => switch (this) {
    NutritionScaleKind.wholeRecipe => 'whole_recipe',
    NutritionScaleKind.scalar => 'scalar',
    NutritionScaleKind.requestedFraction => 'requested_fraction',
    NutritionScaleKind.perDeclaredServing => 'per_declared_serving',
    NutritionScaleKind.requestedYield => 'requested_yield',
  };
}

/// An explicit, positive scaling operation selected by a caller.
///
/// The constructors intentionally preserve zero until calculation so invalid
/// input is reported by the calculator as [invalid_scale], not silently
/// converted to an empty recipe.
class NutritionScaleRequest {
  final NutritionScaleKind kind;
  final QuantityAmount? factor;
  final Quantity? requestedYield;

  const NutritionScaleRequest._({
    required this.kind,
    this.factor,
    this.requestedYield,
  });

  const NutritionScaleRequest.wholeRecipe()
    : this._(kind: NutritionScaleKind.wholeRecipe);

  factory NutritionScaleRequest.scalar(Object value) => NutritionScaleRequest._(
    kind: NutritionScaleKind.scalar,
    factor: _readScaleAmount(value),
  );

  factory NutritionScaleRequest.fraction(Object value) =>
      NutritionScaleRequest._(
        kind: NutritionScaleKind.requestedFraction,
        factor: _readScaleAmount(value),
      );

  const NutritionScaleRequest.perDeclaredServing()
    : this._(kind: NutritionScaleKind.perDeclaredServing);

  const NutritionScaleRequest.requestedYield(Quantity quantity)
    : this._(kind: NutritionScaleKind.requestedYield, requestedYield: quantity);

  Map<String, dynamic> toJson() => {
    'kind': kind.stableId,
    if (factor != null) 'factor': factor!.toJsonValue(),
    if (requestedYield != null) 'requested_yield': requestedYield!.toJson(),
  };
}

QuantityAmount _readScaleAmount(Object value) {
  try {
    if (value is QuantityAmount) return value;
    if (value is String) return QuantityAmount.fromString(value);
    if (value is num) return QuantityAmount.fromNum(value);
  } on QuantityError catch (error) {
    if (error is PrecisionOverflowError) {
      throw NutritionCalculationPrecisionError(
        'Scale exceeds supported decimal precision.',
        cause: error,
      );
    }
    throw NutritionCalculationInputError(
      NutritionCalculationErrorCode.invalidScale,
      'Scale must be a finite, non-negative decimal amount.',
      cause: error,
    );
  }
  throw NutritionCalculationInputError(
    NutritionCalculationErrorCode.invalidScale,
    'Scale must be a decimal quantity amount or number.',
  );
}

/// A recipe-level serving count. It is deliberately not a mass or volume.
class NutritionCalculationServingDefinition {
  final String id;
  final String revision;
  final QuantityAmount count;
  final String? source;

  const NutritionCalculationServingDefinition({
    required this.id,
    required this.revision,
    required this.count,
    this.source,
  });

  void validate() {
    if (id.trim().isEmpty || revision.trim().isEmpty || count.isZero) {
      throw const NutritionCalculationInputError(
        NutritionCalculationErrorCode.missingServingDefinition,
        'A serving definition requires a positive count, ID, and revision.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'revision': revision,
    'count': count.toJsonValue(),
    if (source != null) 'source': source,
  };
}

/// A direct-food line supplied by the already-resolved food/catalogue boundary.
///
/// This is a calculation DTO, not a second recipe graph. It contains stable
/// food/preparation identities and typed facts; it never accepts display names
/// or UI quantity strings.
class NutritionCalculationIngredient {
  final String id;
  final String? foodId;
  final String? nestedRecipeVersionId;
  final int? position;
  final Quantity quantity;
  final String? preparationId;
  final String? substitutedFromFoodId;
  final String? provenanceSource;
  final Map<String, NutrientFact> nutrientFacts;

  NutritionCalculationIngredient._({
    required this.id,
    required this.foodId,
    required this.nestedRecipeVersionId,
    required this.position,
    required this.quantity,
    required this.preparationId,
    required this.substitutedFromFoodId,
    required this.provenanceSource,
    required Map<String, NutrientFact> nutrientFacts,
  }) : nutrientFacts = Map.unmodifiable(nutrientFacts);

  factory NutritionCalculationIngredient.directFood({
    required String id,
    required String foodId,
    required Quantity quantity,
    required Map<String, NutrientFact> nutrientFacts,
    int? position,
    String? preparationId,
    String? substitutedFromFoodId,
    String? provenanceSource,
  }) => NutritionCalculationIngredient._(
    id: id,
    foodId: foodId,
    nestedRecipeVersionId: null,
    position: position,
    quantity: quantity,
    preparationId: preparationId,
    substitutedFromFoodId: substitutedFromFoodId,
    provenanceSource: provenanceSource,
    nutrientFacts: nutrientFacts,
  );

  factory NutritionCalculationIngredient.nestedRecipe({
    required String id,
    required String recipeVersionId,
    required Quantity quantity,
    int? position,
  }) => NutritionCalculationIngredient._(
    id: id,
    foodId: null,
    nestedRecipeVersionId: recipeVersionId,
    position: position,
    quantity: quantity,
    preparationId: null,
    substitutedFromFoodId: null,
    provenanceSource: null,
    nutrientFacts: const {},
  );
}

/// All immutable, already-resolved inputs required for one calculation.
class NutritionCalculationRequest {
  final String recipeId;
  final String recipeVersionId;
  final List<NutritionCalculationIngredient> ingredients;
  final NutrientRegistry registry;
  final int nutrientRegistryVersion;
  final String calculationRuleVersion;
  final Set<String>? requestedNutrientIds;
  final Quantity? declaredYield;
  final NutritionCalculationServingDefinition? servingDefinition;
  final NutritionScaleRequest scale;

  NutritionCalculationRequest({
    required this.recipeId,
    required this.recipeVersionId,
    required Iterable<NutritionCalculationIngredient> ingredients,
    required this.registry,
    required this.nutrientRegistryVersion,
    required this.calculationRuleVersion,
    Set<String>? requestedNutrientIds,
    this.declaredYield,
    this.servingDefinition,
    this.scale = const NutritionScaleRequest.wholeRecipe(),
  }) : ingredients = List.unmodifiable(ingredients),
       requestedNutrientIds = requestedNutrientIds == null
           ? null
           : Set.unmodifiable(requestedNutrientIds);
}

class NutritionCalculationIngredientLineage {
  final String id;
  final int position;
  final String foodId;
  final String? preparationId;
  final String? substitutedFromFoodId;
  final String? provenanceSource;
  final Quantity quantity;
  final Map<String, NutrientFact> nutrientFacts;
  final List<String> unresolvedNutrientIds;

  NutritionCalculationIngredientLineage({
    required this.id,
    required this.position,
    required this.foodId,
    required this.preparationId,
    required this.substitutedFromFoodId,
    required this.provenanceSource,
    required this.quantity,
    required Map<String, NutrientFact> nutrientFacts,
    required Iterable<String> unresolvedNutrientIds,
  }) : nutrientFacts = Map.unmodifiable(nutrientFacts),
       unresolvedNutrientIds = List.unmodifiable(
         unresolvedNutrientIds.toSet().toList()..sort(),
       );

  Map<String, dynamic> toJson() => {
    'id': id,
    'position': position,
    'food_id': foodId,
    if (preparationId != null) 'preparation_id': preparationId,
    if (substitutedFromFoodId != null)
      'substituted_from_food_id': substitutedFromFoodId,
    if (provenanceSource != null) 'provenance_source': provenanceSource,
    'quantity': quantity.toJson(),
    'nutrient_facts': {
      for (final id in nutrientFacts.keys.toList()..sort())
        id: nutrientFacts[id]!.toJson(),
    },
    'unresolved_nutrient_ids': unresolvedNutrientIds,
  };
}

/// Pure calculation lineage ready for a later snapshot owner to persist.
class NutritionCalculationLineage {
  final String recipeId;
  final String recipeVersionId;
  final String calculationRuleVersion;
  final int nutrientRegistryVersion;
  final List<String> requestedNutrientIds;
  final Quantity? declaredYield;
  final NutritionCalculationServingDefinition? servingDefinition;
  final NutritionScaleRequest scale;
  final QuantityAmount resolvedScaleFactor;
  final List<NutritionCalculationIngredientLineage> ingredients;

  NutritionCalculationLineage({
    required this.recipeId,
    required this.recipeVersionId,
    required this.calculationRuleVersion,
    required this.nutrientRegistryVersion,
    required Iterable<String> requestedNutrientIds,
    required this.declaredYield,
    required this.servingDefinition,
    required this.scale,
    required this.resolvedScaleFactor,
    required Iterable<NutritionCalculationIngredientLineage> ingredients,
  }) : requestedNutrientIds = List.unmodifiable(
         requestedNutrientIds.toSet().toList()..sort(),
       ),
       ingredients = List.unmodifiable(ingredients);

  Map<String, dynamic> toJson() => {
    'contract_version': kNutritionCalculationContractVersion,
    'recipe_id': recipeId,
    'recipe_version_id': recipeVersionId,
    'calculation_rule_version': calculationRuleVersion,
    'nutrient_registry_version': nutrientRegistryVersion,
    'requested_nutrient_ids': requestedNutrientIds,
    if (declaredYield != null) 'declared_yield': declaredYield!.toJson(),
    if (servingDefinition != null)
      'serving_definition': servingDefinition!.toJson(),
    'scale': scale.toJson(),
    'resolved_scale_factor': resolvedScaleFactor.toJsonValue(),
    'ingredients': ingredients
        .map((ingredient) => ingredient.toJson())
        .toList(growable: false),
  };

  String get canonicalJson => jsonEncode(toJson());

  /// SHA-256 over exact decimal quantities, fact values, IDs, and versions.
  String get fingerprint =>
      sha256.convert(utf8.encode(canonicalJson)).toString();
}

/// Immutable output for one whole-recipe or explicitly scaled calculation.
class NutritionCalculationResult {
  final String recipeId;
  final String recipeVersionId;
  final String calculationRuleVersion;
  final int nutrientRegistryVersion;
  final int ingredientCount;
  final Map<String, NutrientFact> facts;
  final NutrientCompleteness completeness;
  final List<String> missingNutrientIds;
  final List<NutrientSourceType> sourceTypes;
  final List<String> estimatedNutrientIds;
  final Map<String, List<NutrientSourceType>> sourceLineage;
  final Map<String, List<String>> factVersionLineage;
  final Quantity? declaredYield;
  final NutritionScaleKind scalingBasis;
  final QuantityAmount scalingFactor;
  final List<String> unresolvedInputs;
  final List<String> warnings;
  final NutritionCalculationLineage lineage;

  NutritionCalculationResult({
    required this.recipeId,
    required this.recipeVersionId,
    required this.calculationRuleVersion,
    required this.nutrientRegistryVersion,
    required this.ingredientCount,
    required Map<String, NutrientFact> facts,
    required this.completeness,
    required Iterable<String> missingNutrientIds,
    required Iterable<NutrientSourceType> sourceTypes,
    required Iterable<String> estimatedNutrientIds,
    required Map<String, List<NutrientSourceType>> sourceLineage,
    required Map<String, List<String>> factVersionLineage,
    required this.declaredYield,
    required this.scalingBasis,
    required this.scalingFactor,
    required Iterable<String> unresolvedInputs,
    required Iterable<String> warnings,
    required this.lineage,
  }) : facts = Map.unmodifiable(facts),
       missingNutrientIds = List.unmodifiable(
         missingNutrientIds.toSet().toList()..sort(),
       ),
       sourceTypes = List.unmodifiable(
         sourceTypes.toSet().toList()
           ..sort((a, b) => a.stableId.compareTo(b.stableId)),
       ),
       estimatedNutrientIds = List.unmodifiable(
         estimatedNutrientIds.toSet().toList()..sort(),
       ),
       sourceLineage = Map.unmodifiable({
         for (final entry in sourceLineage.entries)
           entry.key: List<NutrientSourceType>.unmodifiable(entry.value),
       }),
       factVersionLineage = Map.unmodifiable({
         for (final entry in factVersionLineage.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       unresolvedInputs = List.unmodifiable(
         unresolvedInputs.toSet().toList()..sort(),
       ),
       warnings = List.unmodifiable(warnings);

  Map<String, dynamic> toJson() => {
    'contract_version': kNutritionCalculationContractVersion,
    'recipe_id': recipeId,
    'recipe_version_id': recipeVersionId,
    'calculation_rule_version': calculationRuleVersion,
    'nutrient_registry_version': nutrientRegistryVersion,
    'ingredient_count': ingredientCount,
    'facts': {
      for (final id in facts.keys.toList()..sort()) id: facts[id]!.toJson(),
    },
    'completeness': completeness.toJson(),
    'missing_nutrient_ids': missingNutrientIds,
    'source_types': sourceTypes.map((source) => source.stableId).toList(),
    'estimated_nutrient_ids': estimatedNutrientIds,
    'source_lineage': {
      for (final id in sourceLineage.keys.toList()..sort())
        id: sourceLineage[id]!.map((source) => source.stableId).toList(),
    },
    'fact_version_lineage': {
      for (final id in factVersionLineage.keys.toList()..sort())
        id: factVersionLineage[id],
    },
    if (declaredYield != null) 'declared_yield': declaredYield!.toJson(),
    'scaling_basis': scalingBasis.stableId,
    'scaling_factor': scalingFactor.toJsonValue(),
    'unresolved_inputs': unresolvedInputs,
    'warnings': warnings,
    'lineage': lineage.toJson(),
  };
}

class _ResolvedScale {
  final NutritionScaleKind kind;
  final QuantityAmount factor;

  const _ResolvedScale({required this.kind, required this.factor});
}

class _NormalizedIngredient {
  final NutritionCalculationIngredient input;
  final int position;

  const _NormalizedIngredient({required this.input, required this.position});
}

/// The one authoritative, stateless recipe calculation orchestrator.
///
/// It owns request validation, ingredient normalization, scaling orchestration,
/// and lineage construction. Nutrient state arithmetic remains exclusively in
/// [NutrientAggregationService], and typed quantity arithmetic remains in
/// [NutritionQuantityService]/[Quantity].
class NutritionCalculationService {
  const NutritionCalculationService();

  NutritionCalculationResult calculate(NutritionCalculationRequest request) {
    _validateRequest(request);
    final requested = _requestedNutrients(request);
    final ingredients = _normalizeIngredients(
      request.ingredients,
      registry: request.registry,
    );
    final contributions = <NutrientContribution>[];
    final ingredientLineage = <NutritionCalculationIngredientLineage>[];
    final unresolvedInputs = <String>[];

    for (final normalized in ingredients) {
      final ingredient = normalized.input;
      final usedFacts = <String, NutrientFact>{};
      final unresolvedForIngredient = <String>[];
      for (final nutrientId in requested) {
        final fact =
            ingredient.nutrientFacts[nutrientId] ??
            _missingFact(
              nutrientId: nutrientId,
              registry: request.registry,
              ingredientId: ingredient.id,
            );
        usedFacts[nutrientId] = fact;
        if (fact.status == NutrientFactStatus.missing ||
            fact.coverageIncomplete) {
          unresolvedForIngredient.add(nutrientId);
          unresolvedInputs.add('${ingredient.id}:$nutrientId');
        }
        _validateFact(fact, request.registry);
        final aggregationFact = _factForAggregation(fact);
        contributions.add(
          NutrientContribution(
            fact: aggregationFact,
            // An absolute fact explicitly means that the upstream boundary
            // has already normalized it for this ingredient. Non-absolute
            // facts are scaled by the typed ingredient quantity below.
            quantity: aggregationFact.basis.kind == NutrientBasisKind.absolute
                ? null
                : ingredient.quantity,
          ),
        );
      }
      ingredientLineage.add(
        NutritionCalculationIngredientLineage(
          id: ingredient.id,
          position: normalized.position,
          foodId: ingredient.foodId!,
          preparationId: ingredient.preparationId,
          substitutedFromFoodId: ingredient.substitutedFromFoodId,
          provenanceSource: ingredient.provenanceSource,
          quantity: ingredient.quantity,
          nutrientFacts: usedFacts,
          unresolvedNutrientIds: unresolvedForIngredient,
        ),
      );
    }

    final aggregated = _aggregate(
      registry: request.registry,
      contributions: contributions,
      requestedNutrientIds: requested,
    );
    final resolvedScale = _resolveScale(request);
    final facts = <String, NutrientFact>{
      for (final entry in aggregated.facts.entries)
        entry.key: _scaleAbsoluteFact(entry.value, resolvedScale.factor),
    };

    final lineage = NutritionCalculationLineage(
      recipeId: request.recipeId,
      recipeVersionId: request.recipeVersionId,
      calculationRuleVersion: request.calculationRuleVersion,
      nutrientRegistryVersion: request.nutrientRegistryVersion,
      requestedNutrientIds: requested,
      declaredYield: request.declaredYield,
      servingDefinition: request.servingDefinition,
      scale: request.scale,
      resolvedScaleFactor: resolvedScale.factor,
      ingredients: ingredientLineage,
    );

    final sourceTypes = aggregated.sourceLineage.values
        .expand((sources) => sources)
        .toSet();
    final warnings = <String>[];
    if (aggregated.completeness.state == NutrientCompletenessState.partial ||
        aggregated.completeness.state == NutrientCompletenessState.unknown) {
      warnings.add(
        'incomplete_nutrients:${aggregated.completeness.missingNutrientIds.join(',')}',
      );
    }

    return NutritionCalculationResult(
      recipeId: request.recipeId,
      recipeVersionId: request.recipeVersionId,
      calculationRuleVersion: request.calculationRuleVersion,
      nutrientRegistryVersion: request.nutrientRegistryVersion,
      ingredientCount: ingredients.length,
      facts: facts,
      completeness: aggregated.completeness,
      missingNutrientIds: aggregated.completeness.missingNutrientIds,
      sourceTypes: sourceTypes,
      estimatedNutrientIds: aggregated.completeness.estimatedNutrientIds,
      sourceLineage: aggregated.sourceLineage,
      factVersionLineage: aggregated.factVersionLineage,
      declaredYield: request.declaredYield,
      scalingBasis: resolvedScale.kind,
      scalingFactor: resolvedScale.factor,
      unresolvedInputs: unresolvedInputs,
      warnings: warnings,
      lineage: lineage,
    );
  }

  void _validateRequest(NutritionCalculationRequest request) {
    if (request.recipeVersionId.trim().isEmpty) {
      throw const NutritionCalculationInputError(
        NutritionCalculationErrorCode.missingRecipeVersion,
        'An immutable recipe-version ID is required.',
      );
    }
    if (request.recipeId.trim().isEmpty) {
      throw const NutritionCalculationInputError(
        NutritionCalculationErrorCode.invalidRecipeIdentity,
        'A recipe ID is required.',
      );
    }
    if (request.calculationRuleVersion.trim().isEmpty) {
      throw const NutritionCalculationInputError(
        NutritionCalculationErrorCode.invalidRecipeIdentity,
        'A calculation-rule version is required.',
      );
    }
    if (request.nutrientRegistryVersion != request.registry.version ||
        request.registry.version != kNutrientRegistryVersion) {
      throw NutritionCalculationInputError(
        NutritionCalculationErrorCode.unsupportedNutrientRegistryVersion,
        'The requested nutrient registry version is not supported.',
      );
    }
    if (request.declaredYield != null) {
      _validatePositiveQuantity(
        request.declaredYield!,
        label: 'Recipe yield',
        context: NutritionQuantityInputContext.userEnteredPortion,
      );
      if ({
        QuantityDimension.serving,
        QuantityDimension.householdReference,
        QuantityDimension.unknown,
        QuantityDimension.legacy,
      }.contains(request.declaredYield!.dimension)) {
        throw const NutritionCalculationInputError(
          NutritionCalculationErrorCode.incompatibleUnitOrBasis,
          'Recipe yield requires canonical mass, volume, or count.',
        );
      }
    }
    request.servingDefinition?.validate();
    final requested = _requestedNutrients(request);
    if (requested.isEmpty) {
      throw const NutritionCalculationInputError(
        NutritionCalculationErrorCode.invalidNutrientFact,
        'At least one requested nutrient is required.',
      );
    }
    for (final ingredient in request.ingredients) {
      if (ingredient.nestedRecipeVersionId != null) {
        throw const NutritionCalculationInputError(
          NutritionCalculationErrorCode.unsupportedNestedRecipe,
          'Nested recipe calculation is outside B03-08 scope.',
        );
      }
    }
  }

  Set<String> _requestedNutrients(NutritionCalculationRequest request) {
    final requested =
        request.requestedNutrientIds ??
        request.registry.definitions.map((definition) => definition.id).toSet();
    for (final nutrientId in requested) {
      try {
        request.registry.definitionFor(nutrientId);
      } on NutrientError catch (error) {
        throw _fromNutrientError(error);
      }
    }
    return Set.unmodifiable(requested);
  }

  List<_NormalizedIngredient> _normalizeIngredients(
    List<NutritionCalculationIngredient> inputs, {
    required NutrientRegistry registry,
  }) {
    if (inputs.isEmpty) {
      throw const NutritionCalculationInputError(
        NutritionCalculationErrorCode.invalidIngredientGraph,
        'A direct-food recipe requires at least one ingredient.',
      );
    }
    final normalized = <_NormalizedIngredient>[];
    final ids = <String>{};
    final positions = <int>{};
    for (var index = 0; index < inputs.length; index++) {
      final ingredient = inputs[index];
      final id = ingredient.id.trim();
      final foodId = ingredient.foodId?.trim();
      if (id.isEmpty || foodId == null || foodId.isEmpty) {
        throw const NutritionCalculationInputError(
          NutritionCalculationErrorCode.invalidIngredientGraph,
          'Every ingredient requires a stable line ID and food identity ID.',
        );
      }
      if (!ids.add(id)) {
        throw NutritionCalculationInputError(
          NutritionCalculationErrorCode.invalidIngredientGraph,
          'Ingredient line IDs must be unique: $id.',
        );
      }
      final position = ingredient.position ?? index;
      if (position < 0 || !positions.add(position)) {
        throw NutritionCalculationInputError(
          NutritionCalculationErrorCode.invalidIngredientGraph,
          'Ingredient positions must be unique and non-negative: $position.',
        );
      }
      _validatePositiveQuantity(
        ingredient.quantity,
        label: 'Ingredient quantity',
        context: NutritionQuantityInputContext.recipeIngredient,
      );
      for (final entry in ingredient.nutrientFacts.entries) {
        if (entry.key.trim().isEmpty || entry.key != entry.value.nutrientId) {
          throw const NutritionCalculationInputError(
            NutritionCalculationErrorCode.invalidNutrientFact,
            'Nutrient fact map keys must match stable nutrient IDs.',
          );
        }
        _validateFact(entry.value, registry);
      }
      normalized.add(
        _NormalizedIngredient(input: ingredient, position: position),
      );
    }
    normalized.sort((a, b) {
      final position = a.position.compareTo(b.position);
      if (position != 0) return position;
      return a.input.id.compareTo(b.input.id);
    });
    final expectedPositions = List<int>.generate(
      inputs.length,
      (index) => index,
    );
    final actualPositions = normalized
        .map((ingredient) => ingredient.position)
        .toList();
    if (actualPositions.length != expectedPositions.length ||
        !_ListEquality<int>().equals(actualPositions, expectedPositions)) {
      throw const NutritionCalculationInputError(
        NutritionCalculationErrorCode.invalidIngredientGraph,
        'Ingredient positions must form a contiguous ordered graph.',
      );
    }
    return List.unmodifiable(normalized);
  }

  NutrientFact _missingFact({
    required String nutrientId,
    required NutrientRegistry registry,
    required String ingredientId,
  }) => NutrientFact.missing(
    nutrientId: nutrientId,
    unit: registry.definitionFor(nutrientId).unit,
    basis: NutrientBasis(NutrientBasisKind.absolute),
    source: NutrientSourceType.unknown,
    sourceReference: 'unresolved:$ingredientId:$nutrientId',
    factVersion: 'unavailable',
  );

  void _validateFact(NutrientFact fact, NutrientRegistry registry) {
    try {
      fact.validateAgainst(registry);
    } on NutrientError catch (error) {
      throw _fromNutrientError(error);
    }
  }

  /// Missing and not-applicable facts carry no numeric value to scale.
  /// Normalize only their aggregation basis so an unresolved fact remains
  /// incomplete instead of becoming a false unit/basis failure. The original
  /// fact, including its source basis, remains in the lineage above.
  NutrientFact _factForAggregation(NutrientFact fact) {
    if (fact.hasNumericValue ||
        (fact.status != NutrientFactStatus.missing &&
            fact.status != NutrientFactStatus.notApplicable)) {
      return fact;
    }
    return NutrientFact(
      nutrientId: fact.nutrientId,
      unit: fact.unit,
      status: fact.status,
      basis: NutrientBasis(NutrientBasisKind.absolute),
      source: fact.source,
      sourceReference: fact.sourceReference,
      confidence: fact.confidence,
      factVersion: fact.factVersion,
      coverageIncomplete: fact.coverageIncomplete,
    );
  }

  NutrientAggregationResult _aggregate({
    required NutrientRegistry registry,
    required Iterable<NutrientContribution> contributions,
    required Set<String> requestedNutrientIds,
  }) {
    try {
      return NutrientAggregationService.aggregate(
        registry: registry,
        contributions: contributions,
        requestedNutrientIds: requestedNutrientIds,
      );
    } on NutritionCalculationError {
      rethrow;
    } on NutrientError catch (error) {
      throw _fromNutrientError(error);
    } on QuantityError catch (error) {
      throw _fromQuantityError(error);
    }
  }

  _ResolvedScale _resolveScale(NutritionCalculationRequest request) {
    final scale = request.scale;
    switch (scale.kind) {
      case NutritionScaleKind.wholeRecipe:
        return _ResolvedScale(
          kind: NutritionScaleKind.wholeRecipe,
          factor: QuantityAmount.one,
        );
      case NutritionScaleKind.scalar:
      case NutritionScaleKind.requestedFraction:
        final factor = scale.factor;
        if (factor == null || factor.isZero) {
          throw const NutritionCalculationInputError(
            NutritionCalculationErrorCode.invalidScale,
            'A scale factor must be greater than zero.',
          );
        }
        return _ResolvedScale(kind: scale.kind, factor: factor);
      case NutritionScaleKind.perDeclaredServing:
        final serving = request.servingDefinition;
        if (serving == null) {
          throw const NutritionCalculationInputError(
            NutritionCalculationErrorCode.missingServingDefinition,
            'Per-serving calculation requires an explicit serving definition.',
          );
        }
        serving.validate();
        final factor = _safeDivide(QuantityAmount.one, serving.count);
        return _ResolvedScale(kind: scale.kind, factor: factor);
      case NutritionScaleKind.requestedYield:
        final requestedYield = scale.requestedYield;
        if (requestedYield == null) {
          throw const NutritionCalculationInputError(
            NutritionCalculationErrorCode.invalidScale,
            'Requested-yield scaling requires a requested yield quantity.',
          );
        }
        final declaredYield = request.declaredYield;
        if (declaredYield == null) {
          throw const NutritionCalculationInputError(
            NutritionCalculationErrorCode.missingRecipeYield,
            'Requested-yield scaling requires a declared recipe yield.',
          );
        }
        _validatePositiveQuantity(
          requestedYield,
          label: 'Requested yield',
          context: NutritionQuantityInputContext.userEnteredPortion,
        );
        final comparableYield = _convertYield(requestedYield, declaredYield);
        final factor = _safeDivide(
          comparableYield.amount,
          declaredYield.amount,
        );
        return _ResolvedScale(kind: scale.kind, factor: factor);
    }
  }

  Quantity _convertYield(Quantity requested, Quantity declared) {
    try {
      return requested.unit == declared.unit
          ? requested
          : requested.convertTo(declared.unit);
    } on QuantityError catch (error) {
      throw _fromQuantityError(error);
    }
  }

  QuantityAmount _safeDivide(
    QuantityAmount numerator,
    QuantityAmount denominator,
  ) {
    try {
      final factor = numerator.divide(denominator);
      if (factor.isZero) {
        throw const NutritionCalculationPrecisionError(
          'The scale is smaller than the supported exact decimal precision.',
        );
      }
      return factor;
    } on NutritionCalculationError {
      rethrow;
    } on QuantityError catch (error) {
      throw _fromQuantityError(error);
    }
  }

  NutrientFact _scaleAbsoluteFact(NutrientFact fact, QuantityAmount factor) {
    if (fact.basis.kind != NutrientBasisKind.absolute) {
      throw const NutritionCalculationInputError(
        NutritionCalculationErrorCode.incompatibleUnitOrBasis,
        'Aggregated recipe facts must be absolute before recipe scaling.',
      );
    }
    try {
      NutrientAmount? scale(NutrientAmount? amount) => amount?.multiply(factor);
      return NutrientFact(
        nutrientId: fact.nutrientId,
        unit: fact.unit,
        status: fact.status,
        point: scale(fact.point),
        lower: scale(fact.lower),
        upper: scale(fact.upper),
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: fact.source,
        sourceReference: fact.sourceReference,
        confidence: fact.confidence,
        factVersion: fact.factVersion,
        coverageIncomplete: fact.coverageIncomplete,
      );
    } on QuantityError catch (error) {
      throw _fromQuantityError(error);
    } on NutrientError catch (error) {
      throw _fromNutrientError(error);
    }
  }

  void _validatePositiveQuantity(
    Quantity quantity, {
    required String label,
    required NutritionQuantityInputContext context,
  }) {
    try {
      NutritionQuantityService.validatePositive(quantity, context: context);
    } on QuantityError catch (error) {
      throw _fromQuantityError(error, label: label);
    }
  }

  NutritionCalculationError _fromQuantityError(
    QuantityError error, {
    String? label,
  }) {
    if (error is PrecisionOverflowError) {
      return NutritionCalculationPrecisionError(
        '${label ?? 'Calculation'} exceeds supported decimal precision.',
        cause: error,
      );
    }
    if (error is MissingDensityError) {
      return NutritionCalculationContextError(
        NutritionCalculationErrorCode.missingDensity,
        error.message,
        context: 'density',
        cause: error,
      );
    }
    if (error is MissingPortionConversionError) {
      return NutritionCalculationContextError(
        NutritionCalculationErrorCode.missingPortionContext,
        error.message,
        context: 'portion',
        cause: error,
      );
    }
    if (error is UnknownServingDefinitionError) {
      return NutritionCalculationContextError(
        NutritionCalculationErrorCode.missingServingDefinition,
        error.message,
        context: 'serving_definition',
        cause: error,
      );
    }
    if (error is MissingHouseholdCalibrationError) {
      return NutritionCalculationContextError(
        NutritionCalculationErrorCode.missingHouseholdCalibration,
        error.message,
        context: 'household_calibration',
        cause: error,
      );
    }
    if (error is MissingContextualConversionError) {
      return NutritionCalculationContextError(
        NutritionCalculationErrorCode.missingContextualConversion,
        error.message,
        context: 'contextual_conversion',
        cause: error,
      );
    }
    if (error is RawCookedConversionUnavailableError) {
      return NutritionCalculationContextError(
        NutritionCalculationErrorCode.rawCookedConversionDeferred,
        error.message,
        context: 'raw_cooked_yield_rule',
        cause: error,
      );
    }
    if (error is NonPositiveQuantityError ||
        error is InvalidQuantityAmountError) {
      return NutritionCalculationInputError(
        NutritionCalculationErrorCode.invalidQuantity,
        '${label ?? 'Quantity'} is invalid: ${error.message}',
        cause: error,
      );
    }
    if (error is UnsupportedQuantityUnitError ||
        error is IncompatibleQuantityDimensionError ||
        error is IncompatibleQuantityContextError) {
      return NutritionCalculationInputError(
        NutritionCalculationErrorCode.incompatibleUnitOrBasis,
        '${label ?? 'Quantity'} has an incompatible unit or context: ${error.message}',
        cause: error,
      );
    }
    return NutritionCalculationInputError(
      NutritionCalculationErrorCode.invalidQuantity,
      '${label ?? 'Quantity'} is invalid: ${error.message}',
      cause: error,
    );
  }

  NutritionCalculationError _fromNutrientError(NutrientError error) {
    if (error is NutrientRegistryVersionError) {
      return NutritionCalculationInputError(
        NutritionCalculationErrorCode.unsupportedNutrientRegistryVersion,
        error.message,
        cause: error,
      );
    }
    if (error is NutrientBasisMismatchError ||
        error is NutrientUnitMismatchError) {
      return NutritionCalculationInputError(
        NutritionCalculationErrorCode.incompatibleUnitOrBasis,
        error.message,
        cause: error,
      );
    }
    return NutritionCalculationInputError(
      NutritionCalculationErrorCode.invalidNutrientFact,
      error.message,
      cause: error,
    );
  }
}

/// A tiny local equality helper keeps this core file independent of Flutter
/// collection utilities while checking the persisted recipe graph shape.
class _ListEquality<T> {
  const _ListEquality();

  bool equals(List<T> left, List<T> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
