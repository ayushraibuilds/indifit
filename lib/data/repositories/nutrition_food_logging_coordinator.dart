import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrients.dart';
import '../../core/nutrition_calculation_service.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/raw_cooked_transformations.dart';
import '../../core/typed_quantities.dart';
import '../database/app_database.dart' hide NutritionConsumptionSnapshot;
import 'nutrition_consumption_repository.dart';
import 'nutrition_food_catalog_repository.dart';
import 'nutrition_transformation_repository.dart';

class NutritionFoodLoggingError implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const NutritionFoodLoggingError(this.code, this.message, {this.cause});

  @override
  String toString() => 'NutritionFoodLoggingError($code): $message';
}

/// Immutable preview passed from the feature layer to canonical finalization.
class NutritionFoodLogPreview {
  final NutritionFoodOption source;
  final NutritionFoodOption effectiveFood;
  final Quantity quantity;
  final String? sourcePreparationId;
  final String? preparationId;
  final NutritionCalculationResult calculation;
  final NutritionConsumptionCalculationSnapshot calculationSnapshot;
  final NutritionTransformationApplied? transformation;

  const NutritionFoodLogPreview({
    required this.source,
    required this.effectiveFood,
    required this.quantity,
    required this.sourcePreparationId,
    required this.preparationId,
    required this.calculation,
    required this.calculationSnapshot,
    required this.transformation,
  });

  bool get isPartial =>
      calculationSnapshot.completeness.state ==
      NutrientCompletenessState.partial;

  bool get isUnknown =>
      calculationSnapshot.completeness.state ==
      NutrientCompletenessState.unknown;

  Map<String, NutrientFact> get facts => calculationSnapshot.facts;
}

/// Production integration boundary for ordinary direct-food logging.
///
/// It is intentionally parallel to [NutritionRecipeLogCoordinator]: source
/// facts are resolved once, the shared B03 calculator produces immutable
/// evidence, and exactly one command is submitted to
/// [NutritionConsumptionRepository]. No legacy FoodLogs row is written here.
class NutritionFoodLoggingCoordinator {
  final NutrientRegistry _registry;
  final NutritionFoodCatalogRepository _catalog;
  final NutritionCalculationService _calculator;
  final NutritionConsumptionRepository _consumption;
  final NutritionTransformationRepository _transformations;
  final Uuid _uuid;

  NutritionFoodLoggingCoordinator({
    required AppDatabase db,
    required NutrientRegistry registry,
    required NutritionFoodCatalogRepository catalog,
    required NutritionCalculationService calculator,
    required NutritionConsumptionRepository consumption,
    required NutritionTransformationRepository transformations,
    Uuid? uuid,
  }) : _registry = registry,
       _catalog = catalog,
       _calculator = calculator,
       _consumption = consumption,
       _transformations = transformations,
       _uuid = uuid ?? const Uuid();

  Future<List<NutritionTransformation>> transformationsFor(
    NutritionFoodOption option,
  ) => option.preparationId == null
      ? _transformations.findForFood(sourceFoodId: option.id)
      : _transformations.findForSource(
          sourceFoodId: option.id,
          sourcePreparationId: option.preparationId,
        );

  Future<NutritionFoodLogPreview> preview({
    required NutritionFoodOption option,
    required Quantity quantity,
    NutritionTransformation? transformation,
  }) async {
    try {
      NutritionQuantityService.validatePositiveConsumedQuantity(quantity);
    } on QuantityError catch (error) {
      throw NutritionFoodLoggingError(
        'invalid_quantity',
        error.message,
        cause: error,
      );
    }

    var effectiveFood = option;
    var effectiveQuantity = quantity;
    var sourcePreparationId = option.preparationId;
    String? preparationId = option.preparationId;
    NutritionTransformationApplied? applied;
    if (transformation != null) {
      NutritionTransformationResult result;
      try {
        result = NutritionTransformationService.apply(
          transformation: transformation,
          sourceFoodId: option.id,
          sourcePreparationId:
              option.preparationId ?? transformation.sourcePreparationId,
          input: quantity,
          direction: transformation.direction,
        );
      } on NutritionTransformationError catch (error) {
        throw NutritionFoodLoggingError(
          'transformation_unavailable',
          error.toString(),
          cause: error,
        );
      } on QuantityError catch (error) {
        throw NutritionFoodLoggingError(
          'transformation_invalid_quantity',
          error.message,
          cause: error,
        );
      }
      if (result is NutritionTransformationUnresolved) {
        throw NutritionFoodLoggingError(result.code, result.message);
      }
      applied = result as NutritionTransformationApplied;
      if (applied.point == null &&
          (applied.lower == null || applied.upper == null)) {
        throw const NutritionFoodLoggingError(
          'range_only_transformation',
          'This conversion does not provide both bounds required for a range snapshot.',
        );
      }
      final target = await _catalog.getOption(transformation.targetFoodId);
      if (target == null) {
        throw const NutritionFoodLoggingError(
          'missing_transformed_food',
          'The transformed food identity is unavailable.',
        );
      }
      effectiveFood = target;
      effectiveQuantity = applied.point ?? applied.lower!;
      sourcePreparationId =
          option.preparationId ?? transformation.sourcePreparationId;
      preparationId = transformation.targetPreparationId;
    }

    final calculation = _calculate(
      food: effectiveFood,
      quantity: effectiveQuantity,
      preparationId: preparationId,
    );
    final snapshot =
        applied == null || applied.lower == null || applied.upper == null
        ? NutritionConsumptionCalculationSnapshot.fromRecipeResult(calculation)
        : _rangeSnapshot(
            source: option,
            effectiveFood: effectiveFood,
            preparationId: preparationId,
            applied: applied,
            lower: _calculate(
              food: effectiveFood,
              quantity: applied.lower!,
              preparationId: preparationId,
            ),
            upper: _calculate(
              food: effectiveFood,
              quantity: applied.upper!,
              preparationId: preparationId,
            ),
          );
    return NutritionFoodLogPreview(
      source: option,
      effectiveFood: effectiveFood,
      quantity: effectiveQuantity,
      sourcePreparationId: sourcePreparationId,
      preparationId: preparationId,
      calculation: calculation,
      calculationSnapshot: snapshot,
      transformation: applied,
    );
  }

  Future<NutritionConsumptionSnapshot> finalize({
    required String userId,
    required NutritionFoodLogPreview preview,
    required String mealCategory,
    required DateTime loggedAt,
    required String localDate,
    required String timezoneId,
    String? mealGroupId,
    String? consumptionId,
    String? commandId,
    String? supersedesSnapshotId,
    String? correctionId,
    String? correctionReason,
  }) async {
    final normalizedCommand = commandId?.trim().isNotEmpty == true
        ? commandId!.trim()
        : 'direct-food-command::${_uuid.v4()}';
    final transformation = preview.transformation;
    final evidence = <String, dynamic>{
      'food_id': preview.effectiveFood.id,
      'source_food_id': preview.source.id,
      'source_type': preview.effectiveFood.sourceType,
      'source_reference': preview.effectiveFood.sourceReference,
      'calculation_rule_version': preview.calculation.calculationRuleVersion,
      if (transformation != null)
        'transformation': {
          'id': transformation.lineage.transformationId,
          'source_food_id': preview.source.id,
          'source_preparation_id': preview.sourcePreparationId,
          'target_food_id': preview.effectiveFood.id,
          'target_preparation_id': preview.preparationId,
          'rule_version': transformation.lineage.ruleVersion,
          'direction': transformation.lineage.direction.name,
          'source': transformation.lineage.source.stableId,
          'review_state': transformation.lineage.reviewState.stableId,
          'yield': transformation.point?.toJson(),
          if (transformation.lower != null)
            'lower': transformation.lower!.toJson(),
          if (transformation.upper != null)
            'upper': transformation.upper!.toJson(),
        },
    };
    final request = NutritionConsumptionFinalizeRequest(
      userId: userId,
      consumptionId: consumptionId,
      commandId: normalizedCommand,
      loggedAtUtc: loggedAt,
      mealCategory: mealCategory,
      mealGroupId: mealGroupId,
      supersedesSnapshotId: supersedesSnapshotId,
      correctionId: correctionId,
      correctionReason: correctionReason,
      sourceType: 'direct_food',
      localDate: localDate,
      timezoneId: timezoneId,
      calculatorVersion: preview.calculation.calculationRuleVersion,
      evidence: evidence,
      items: [
        NutritionConsumptionItemInput(
          id: '${consumptionId ?? normalizedCommand}::food',
          position: 0,
          sourceType: 'direct_food',
          foodId: preview.effectiveFood.id,
          preparationId: preview.preparationId,
          sourceReference: preview.effectiveFood.sourceReference,
          displayLabel: preview.effectiveFood.displayName,
          quantity: preview.quantity,
          calculation: preview.calculationSnapshot,
          evidence: evidence,
        ),
      ],
    );
    try {
      return await _consumption.finalizeConsumption(request);
    } on NutritionConsumptionError catch (error) {
      throw NutritionFoodLoggingError(error.code, error.message, cause: error);
    }
  }

  NutritionCalculationResult _calculate({
    required NutritionFoodOption food,
    required Quantity quantity,
    required String? preparationId,
  }) {
    final ingredients = [
      NutritionCalculationIngredient.directFood(
        id: 'direct-food-line:${food.id}',
        foodId: food.id,
        quantity: quantity,
        position: 0,
        preparationId: preparationId,
        provenanceSource: food.sourceType,
        nutrientFacts: food.facts,
      ),
    ];
    try {
      return _calculator.calculate(
        NutritionCalculationRequest(
          recipeId: 'direct-food:${food.id}',
          recipeVersionId: 'direct-food:${food.id}',
          ingredients: ingredients,
          registry: _registry,
          nutrientRegistryVersion: _registry.version,
          calculationRuleVersion: 'direct-food-b03-18-v1',
          requestedNutrientIds: _registry.definitions
              .map((definition) => definition.id)
              .toSet(),
        ),
      );
    } on NutritionCalculationError catch (error) {
      throw NutritionFoodLoggingError(error.code, error.message, cause: error);
    }
  }

  NutritionConsumptionCalculationSnapshot _rangeSnapshot({
    required NutritionFoodOption source,
    required NutritionFoodOption effectiveFood,
    required String? preparationId,
    required NutritionTransformationApplied applied,
    required NutritionCalculationResult lower,
    required NutritionCalculationResult upper,
  }) {
    final transformationReference =
        'transformation:${applied.lineage.transformationId}:${applied.lineage.ruleVersion}';
    final facts = <String, NutrientFact>{};
    for (final definition in _registry.definitions) {
      final lowerFact = lower.facts[definition.id];
      final upperFact = upper.facts[definition.id];
      final lowerAmount = _numericBound(lowerFact, lower: true);
      final upperAmount = _numericBound(upperFact, lower: false);
      if (lowerAmount == null || upperAmount == null) {
        facts[definition.id] = NutrientFact.missing(
          nutrientId: definition.id,
          unit: definition.unit,
          basis: NutrientBasis(NutrientBasisKind.absolute),
          source:
              lowerFact?.source ??
              effectiveFood.facts[definition.id]?.source ??
              NutrientSourceType.unknown,
          sourceReference:
              lowerFact?.sourceReference ?? effectiveFood.sourceReference,
          factVersion: lowerFact?.factVersion ?? 'unavailable',
        );
        continue;
      }
      facts[definition.id] = NutrientFact(
        nutrientId: definition.id,
        unit: definition.unit,
        status: NutrientFactStatus.estimated,
        lower: NutrientAmount(value: lowerAmount, unit: definition.unit),
        upper: NutrientAmount(value: upperAmount, unit: definition.unit),
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: NutrientSourceType.recipeCalculation,
        sourceReference: transformationReference,
        confidence: NutrientConfidence.low,
        factVersion:
            '${lowerFact?.factVersion ?? 'unknown'}:${upperFact?.factVersion ?? 'unknown'}',
      );
    }
    final lineage = {
      'source_food_id': source.id,
      'effective_food_id': effectiveFood.id,
      'preparation_id': preparationId,
      'transformation': {
        'id': applied.lineage.transformationId,
        'rule_version': applied.lineage.ruleVersion,
        'direction': applied.lineage.direction.name,
        'source': applied.lineage.source.stableId,
        'review_state': applied.lineage.reviewState.stableId,
        'lower': applied.lower?.toJson(),
        'upper': applied.upper?.toJson(),
      },
      'lower_calculation': lower.toJson(),
      'upper_calculation': upper.toJson(),
    };
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(lineage)))
        .toString();
    return NutritionConsumptionCalculationSnapshot.fromFacts(
      facts: facts,
      registry: _registry,
      requestedNutrientIds: _registry.definitions.map((item) => item.id),
      calculatorVersion: 'direct-food-b03-18-v1',
      calculationFingerprint: fingerprint,
      lineage: lineage,
    );
  }

  QuantityAmount? _numericBound(NutrientFact? fact, {required bool lower}) {
    if (fact == null || !fact.isAvailable) return null;
    return lower
        ? fact.lower?.value ?? fact.point?.value
        : fact.upper?.value ?? fact.point?.value;
  }
}
