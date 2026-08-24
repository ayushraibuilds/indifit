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

  /// Applies a direct-food correction to one exact item in an immutable
  /// snapshot.
  ///
  /// B03 history is append-only: the predecessor remains intact and the
  /// successor contains the unchanged items plus the edited replacement. The
  /// item ID supplied by the caller is an exact persisted identity; display
  /// names, quantities, and list positions are never used to select it.
  /// Passing a null [replacement] removes only that item. If it is the last
  /// item, the canonical retraction path is used instead.
  Future<NutritionConsumptionSnapshot> correctDirectFoodItem({
    required String userId,
    required String snapshotId,
    required String itemId,
    required String expectedMealCategory,
    required String mealCategory,
    required String localDate,
    required String timezoneId,
    required DateTime loggedAtUtc,
    required String commandId,
    required String correctionReason,
    NutritionFoodLogPreview? replacement,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedSnapshotId = snapshotId.trim();
    final normalizedItemId = itemId.trim();
    final normalizedExpectedMeal = expectedMealCategory.trim().toLowerCase();
    final normalizedMeal = mealCategory.trim().toLowerCase();
    final normalizedLocalDate = localDate.trim();
    final normalizedTimezone = timezoneId.trim();
    final normalizedCommand = commandId.trim();
    final normalizedReason = correctionReason.trim();
    const supportedMeals = {'breakfast', 'lunch', 'dinner', 'snack'};
    if (normalizedUserId.isEmpty ||
        normalizedSnapshotId.isEmpty ||
        normalizedItemId.isEmpty ||
        normalizedExpectedMeal.isEmpty ||
        normalizedMeal.isEmpty ||
        normalizedLocalDate.isEmpty ||
        normalizedTimezone.isEmpty ||
        normalizedCommand.isEmpty ||
        normalizedReason.isEmpty) {
      throw const NutritionFoodLoggingError(
        'invalid_food_correction',
        'A food correction needs an exact entry, meal, date, timezone, and command.',
      );
    }
    if (!supportedMeals.contains(normalizedExpectedMeal) ||
        !supportedMeals.contains(normalizedMeal)) {
      throw const NutritionFoodLoggingError(
        'unsupported_food_correction_meal',
        'Choose Breakfast, Lunch, Dinner, or Snack for this food.',
      );
    }

    final predecessor = await _consumption.getSnapshot(
      userId: normalizedUserId,
      consumptionId: normalizedSnapshotId,
    );
    if (predecessor == null) {
      throw const NutritionFoodLoggingError(
        'missing_food_correction_predecessor',
        'This logged food is no longer available. Refresh and try again.',
      );
    }
    if (predecessor.sourceType != 'direct_food' || predecessor.isRetraction) {
      throw const NutritionFoodLoggingError(
        'unsupported_food_correction_source',
        'Only a directly logged food can be edited here.',
      );
    }
    if (predecessor.localDate != normalizedLocalDate ||
        predecessor.mealCategory.trim().toLowerCase() !=
            normalizedExpectedMeal ||
        predecessor.timezoneId != normalizedTimezone ||
        !predecessor.loggedAtUtc.toUtc().isAtSameMomentAs(
          loggedAtUtc.toUtc(),
        )) {
      throw const NutritionFoodLoggingError(
        'food_correction_context_mismatch',
        'This food moved or changed before the edit was saved. Refresh and try again.',
      );
    }
    if (predecessor.constraintEvaluation != null ||
        predecessor.constraintAcknowledgement != null) {
      throw const NutritionFoodLoggingError(
        'unsupported_food_correction_constraints',
        'This logged food needs a constraint-aware correction path.',
      );
    }
    final target = predecessor.items
        .where((item) => item.id == normalizedItemId)
        .firstOrNull;
    if (target == null ||
        target.sourceType != 'direct_food' ||
        target.foodId == null) {
      throw const NutritionFoodLoggingError(
        'missing_food_correction_item',
        'The selected food entry is no longer available. Refresh and try again.',
      );
    }
    if (predecessor.items.any(
      (item) => item.sourceType != 'direct_food' || item.foodId == null,
    )) {
      throw const NutritionFoodLoggingError(
        'unsupported_mixed_food_correction',
        'This meal contains a composition that cannot be edited one food at a time.',
      );
    }
    if (replacement != null &&
        replacement.calculation.calculationRuleVersion !=
            predecessor.calculatorVersion) {
      throw const NutritionFoodLoggingError(
        'food_correction_calculation_version',
        'This food uses an older nutrition calculation and cannot be safely edited here.',
      );
    }

    final digest = sha256
        .convert(
          utf8.encode(
            '$normalizedUserId\u0000$normalizedSnapshotId\u0000$normalizedItemId\u0000$normalizedCommand',
          ),
        )
        .toString();
    final correctionId = 'direct-food-correction::$digest';
    final successorId = 'direct-food-successor::$digest';

    if (replacement == null && predecessor.items.length == 1) {
      try {
        return await _consumption.retractConsumption(
          userId: normalizedUserId,
          snapshotId: normalizedSnapshotId,
          expectedLocalDate: normalizedLocalDate,
          expectedMealCategory: normalizedExpectedMeal,
          commandId: normalizedCommand,
          reason: normalizedReason,
        );
      } on NutritionConsumptionError catch (error) {
        throw NutritionFoodLoggingError(
          error.code,
          error.message,
          cause: error,
        );
      }
    }

    final requestedNutrients = predecessor.completeness.requestedNutrientIds;
    final items = <NutritionConsumptionItemInput>[];
    var successorPosition = 0;
    for (var position = 0; position < predecessor.items.length; position++) {
      final item = predecessor.items[position];
      if (replacement == null && item.id == normalizedItemId) continue;

      final isTarget = item.id == normalizedItemId;
      final itemIdForSuccessor = '$successorId::item::$successorPosition';
      final calculation = isTarget && replacement != null
          ? NutritionConsumptionCalculationSnapshot.fromFacts(
              facts: replacement.facts,
              registry: _registry,
              requestedNutrientIds: requestedNutrients,
              calculatorVersion: predecessor.calculatorVersion,
              calculationFingerprint:
                  'direct-food-edit::$normalizedSnapshotId::$normalizedItemId::${replacement.calculationSnapshot.calculationFingerprint}',
              lineage: {
                'replacement_item_id': normalizedItemId,
                'replacement_calculation': replacement.calculationSnapshot
                    .toJson(),
              },
            )
          : NutritionConsumptionCalculationSnapshot.fromFacts(
              facts: item.facts,
              registry: _registry,
              requestedNutrientIds: requestedNutrients,
              calculatorVersion: predecessor.calculatorVersion,
              calculationFingerprint:
                  'direct-food-preserved::$normalizedSnapshotId::${item.id}::${predecessor.lineage.contentFingerprint}',
              lineage: {'preserved_item_id': item.id},
            );
      final quantity = isTarget && replacement != null
          ? replacement.quantity
          : item.quantity;
      final foodId = isTarget && replacement != null
          ? replacement.effectiveFood.id
          : item.foodId!;
      final preparationId = isTarget && replacement != null
          ? replacement.preparationId
          : item.preparationId;
      final sourceReference = isTarget && replacement != null
          ? replacement.effectiveFood.sourceReference
          : item.sourceReference;
      final displayLabel = isTarget && replacement != null
          ? replacement.effectiveFood.displayName
          : item.displayLabel;
      items.add(
        NutritionConsumptionItemInput(
          id: itemIdForSuccessor,
          position: successorPosition,
          sourceType: 'direct_food',
          foodId: foodId,
          preparationId: preparationId,
          sourceReference: sourceReference,
          displayLabel: displayLabel,
          quantity: quantity,
          calculation: calculation,
          evidence: {
            'correction_item_id': item.id,
            if (isTarget && replacement != null)
              'operation': 'update'
            else
              'operation': 'preserve',
          },
        ),
      );
      successorPosition++;
    }
    if (items.isEmpty) {
      throw const NutritionFoodLoggingError(
        'empty_food_correction',
        'A meal must retain at least one logged food.',
      );
    }

    try {
      return await _consumption.finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: normalizedUserId,
          consumptionId: successorId,
          commandId: normalizedCommand,
          loggedAtUtc: loggedAtUtc,
          mealCategory: normalizedMeal,
          mealGroupId: predecessor.mealGroupId,
          sourceType: 'direct_food',
          localDate: normalizedLocalDate,
          timezoneId: normalizedTimezone,
          calculatorVersion: predecessor.calculatorVersion,
          evidence: {
            'direct_food_correction': {
              'operation': replacement == null ? 'delete_item' : 'update_item',
              'predecessor_snapshot_id': normalizedSnapshotId,
              'predecessor_item_id': normalizedItemId,
              'expected_meal_category': normalizedExpectedMeal,
              'meal_category': normalizedMeal,
              'local_date': normalizedLocalDate,
            },
          },
          items: items,
          supersedesSnapshotId: normalizedSnapshotId,
          correctionId: correctionId,
          correctionReason: normalizedReason,
        ),
      );
    } on NutritionConsumptionError catch (error) {
      throw NutritionFoodLoggingError(error.code, error.message, cause: error);
    }
  }

  /// Finalizes several direct foods as one immutable meal snapshot.
  ///
  /// The snapshot item graph is already the B03 unit of atomicity. Keeping a
  /// multi-select commit in one request means a retry cannot leave half of a
  /// selected meal in history, while each line still retains its own food
  /// identity, typed quantity, source reference, and frozen facts.
  Future<NutritionConsumptionSnapshot> finalizeBatch({
    required String userId,
    required Iterable<NutritionFoodLogPreview> previews,
    required String mealCategory,
    required DateTime loggedAt,
    required String localDate,
    required String timezoneId,
    String? mealGroupId,
    String? consumptionId,
    String? commandId,
  }) async {
    final entries = previews.toList(growable: false);
    if (entries.isEmpty) {
      throw const NutritionFoodLoggingError(
        'empty_batch',
        'Select at least one food before adding the meal.',
      );
    }
    final normalizedCommand = commandId?.trim().isNotEmpty == true
        ? commandId!.trim()
        : 'direct-food-batch-command::${_uuid.v4()}';
    final normalizedConsumption = consumptionId?.trim().isNotEmpty == true
        ? consumptionId!.trim()
        : 'direct-food-batch-consumption::${_uuid.v4()}';
    final evidenceItems = <Map<String, dynamic>>[];
    final items = <NutritionConsumptionItemInput>[];
    for (var index = 0; index < entries.length; index++) {
      final preview = entries[index];
      final evidence = _previewEvidence(preview);
      evidenceItems.add(evidence);
      items.add(
        NutritionConsumptionItemInput(
          id: '$normalizedConsumption::food::$index',
          position: index,
          sourceType: 'direct_food',
          foodId: preview.effectiveFood.id,
          preparationId: preview.preparationId,
          sourceReference: preview.effectiveFood.sourceReference,
          displayLabel: preview.effectiveFood.displayName,
          quantity: preview.quantity,
          calculation: preview.calculationSnapshot,
          evidence: evidence,
        ),
      );
    }
    final calculatorVersions = entries
        .map((preview) => preview.calculation.calculationRuleVersion)
        .toSet();
    try {
      return await _consumption.finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: userId,
          consumptionId: normalizedConsumption,
          commandId: normalizedCommand,
          loggedAtUtc: loggedAt,
          mealCategory: mealCategory,
          mealGroupId: mealGroupId,
          sourceType: 'direct_food',
          localDate: localDate,
          timezoneId: timezoneId,
          calculatorVersion: calculatorVersions.join('|'),
          evidence: {
            'batch': true,
            'item_count': items.length,
            'items': evidenceItems,
          },
          items: items,
        ),
      );
    } on NutritionConsumptionError catch (error) {
      throw NutritionFoodLoggingError(error.code, error.message, cause: error);
    }
  }

  Map<String, dynamic> _previewEvidence(NutritionFoodLogPreview preview) {
    final transformation = preview.transformation;
    return {
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
