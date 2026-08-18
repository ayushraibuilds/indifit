import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrients.dart';
import '../../core/nutrition_calculation_service.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/nutrition_thali.dart';
import '../../core/typed_quantities.dart';
import '../database/app_database.dart' as database;
import 'nutrition_constraint_repository.dart';
import 'nutrition_consumption_repository.dart';
import 'nutrition_household_measure_repository.dart';
import 'nutrition_recipe_log_coordinator.dart';
import 'nutrition_recipe_repository.dart';

typedef NutritionThaliFailureInjector = void Function(String stage);

/// The single persistence, calculation-orchestration, and finalization
/// boundary for free-form B03-13 thalis.
///
/// This repository owns composition and delegates nutrient arithmetic to
/// [NutritionCalculationService] through [NutritionRecipeLogCoordinator],
/// household conversion to [NutritionHouseholdMeasureRepository], dietary
/// evaluation to [NutritionConstraintRepository], and history writes to
/// [NutritionConsumptionRepository].
class NutritionThaliRepository {
  final database.AppDatabase _db;
  final NutrientRegistry _registry;
  final NutritionRecipeRepository _recipes;
  final NutritionRecipeLogCoordinator _recipeLogging;
  final NutritionHouseholdMeasureRepository _measures;
  final NutritionConstraintRepository _constraints;
  final NutritionConsumptionRepository _consumption;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;
  final NutritionThaliFailureInjector? _failureInjector;

  NutritionThaliRepository({
    required database.AppDatabase db,
    required NutrientRegistry registry,
    required NutritionRecipeRepository recipes,
    required NutritionRecipeLogCoordinator recipeLogging,
    required NutritionHouseholdMeasureRepository measures,
    required NutritionConstraintRepository constraints,
    required NutritionConsumptionRepository consumption,
    Uuid? uuid,
    DateTime Function()? nowUtc,
    NutritionThaliFailureInjector? failureInjector,
  }) : _db = db,
       _registry = registry,
       _recipes = recipes,
       _recipeLogging = recipeLogging,
       _measures = measures,
       _constraints = constraints,
       _consumption = consumption,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _failureInjector = failureInjector;

  Future<List<NutritionThaliFoodOption>> searchFoods({
    String query = '',
    int limit = 50,
  }) async {
    if (limit < 1) {
      throw const NutritionThaliValidationError(
        'invalid_search_limit',
        'A food search limit must be positive.',
      );
    }
    final normalized = query.trim().toLowerCase();
    final allRows = await (_db.select(
      _db.nutritionFoods,
    )..where((row) => row.lifecycle.equals('active'))).get();
    final matchingIds = <String>{};
    if (normalized.isNotEmpty) {
      matchingIds.addAll(
        allRows
            .where((row) => row.displayName.toLowerCase().contains(normalized))
            .map((row) => row.id),
      );
      final aliases =
          await (_db.select(_db.nutritionFoodAliases)..where(
                (row) =>
                    row.isActive.equals(true) &
                    row.normalizedAlias.lower().contains(normalized),
              ))
              .get();
      matchingIds.addAll(aliases.map((row) => row.foodId).whereType<String>());
    }
    final rows =
        allRows
            .where((row) => normalized.isEmpty || matchingIds.contains(row.id))
            .toList()
          ..sort((left, right) {
            final byName = left.displayName.compareTo(right.displayName);
            return byName == 0 ? left.id.compareTo(right.id) : byName;
          });
    final limitedRows = rows.take(limit);
    return List.unmodifiable([
      for (final row in limitedRows)
        NutritionThaliFoodOption(
          id: row.id,
          displayName: row.displayName,
          kind: row.kind,
          sourceType: row.sourceType,
          region: row.region,
        ),
    ]);
  }

  Future<List<NutritionThaliRecipeOption>> searchRecipes({
    required String userId,
    String query = '',
  }) async {
    final owner = _requireOwner(userId);
    final normalized = query.trim().toLowerCase();
    final recipes = await _recipes.listRecipes(userId: owner);
    final options = <NutritionThaliRecipeOption>[];
    for (final recipe in recipes) {
      if (recipe.lifecycle != NutritionRecipeLifecycle.active ||
          (normalized.isNotEmpty &&
              !recipe.name.toLowerCase().contains(normalized))) {
        continue;
      }
      final version = await _recipes.getCurrentPublishedVersion(recipe.id);
      if (version == null) continue;
      options.add(
        NutritionThaliRecipeOption(
          recipeId: recipe.id,
          recipeName: recipe.name,
          recipeVersionId: version.id,
          versionNumber: version.versionNumber,
          versionUpdatedAtUtc: version.updatedAt.toUtc(),
        ),
      );
    }
    options.sort((left, right) {
      final name = left.recipeName.compareTo(right.recipeName);
      return name == 0 ? left.recipeId.compareTo(right.recipeId) : name;
    });
    return List.unmodifiable(options);
  }

  Future<List<NutritionHouseholdMeasureDefinition>> listStandardMeasures() =>
      _measures.listStandardMeasures();

  Future<List<NutritionPersonalVessel>> listActiveVessels({
    required String userId,
  }) => _measures.listVessels(userId: _requireOwner(userId));

  NutritionThaliDraft newDraft({
    required String userId,
    String name = 'My Thali',
    String? description,
    Iterable<NutritionThaliItem> items = const [],
  }) {
    final owner = _requireOwner(userId);
    return NutritionThaliDraft(
      id: 'thali-v1-${_uuid.v4()}',
      userId: owner,
      name: name,
      description: description,
      lifecycle: 'active',
      currentVersion: 1,
      createdAtUtc: _nowUtc(),
      updatedAtUtc: _nowUtc(),
      items: items,
    );
  }

  Future<List<NutritionThaliDraft>> listDrafts({
    required String userId,
    bool includeArchived = false,
  }) async {
    final owner = _requireOwner(userId);
    final query = _db.select(_db.nutritionThalis)
      ..where((row) => row.userId.equals(owner));
    if (!includeArchived) {
      query.where((row) => row.lifecycle.equals('active'));
    }
    query.orderBy([
      (row) => OrderingTerm(expression: row.updatedAt, mode: OrderingMode.desc),
      (row) => OrderingTerm(expression: row.id),
    ]);
    final rows = await query.get();
    return Future.wait(rows.map((row) => _readDraft(row, owner)));
  }

  Future<NutritionThaliDraft?> getDraft({
    required String userId,
    required String thaliId,
  }) async {
    final owner = _requireOwner(userId);
    final row =
        await (_db.select(_db.nutritionThalis)..where(
              (table) =>
                  table.id.equals(thaliId.trim()) & table.userId.equals(owner),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return _readDraft(row, owner);
  }

  Future<void> deleteThali({
    required String userId,
    required String thaliId,
  }) async {
    final owner = userId.trim();
    final id = thaliId.trim();
    if (owner.isEmpty || id.isEmpty) {
      throw const NutritionThaliValidationError(
        'missing_identifiers',
        'User ID and thali ID are required to delete a saved meal.',
      );
    }
    final existing =
        await (_db.select(_db.nutritionThalis)
              ..where((row) => row.id.equals(id) & row.userId.equals(owner)))
            .getSingleOrNull();
    if (existing == null) {
      throw const NutritionThaliNotFoundError(
        'thali_not_found',
        'The requested saved meal does not exist.',
      );
    }
    await (_db.update(
      _db.nutritionThalis,
    )..where((row) => row.id.equals(id))).write(
      database.NutritionThalisCompanion(
        lifecycle: const Value('deleted'),
        updatedAt: Value(_nowUtc()),
      ),
    );
  }

  Future<void> archiveThali({
    required String userId,
    required String thaliId,
  }) async {
    final owner = userId.trim();
    final id = thaliId.trim();
    if (owner.isEmpty || id.isEmpty) {
      throw const NutritionThaliValidationError(
        'missing_identifiers',
        'User ID and thali ID are required to archive a saved meal.',
      );
    }
    final existing =
        await (_db.select(_db.nutritionThalis)
              ..where((row) => row.id.equals(id) & row.userId.equals(owner)))
            .getSingleOrNull();
    if (existing == null) {
      throw const NutritionThaliNotFoundError(
        'thali_not_found',
        'The requested saved meal does not exist.',
      );
    }
    await (_db.update(
      _db.nutritionThalis,
    )..where((row) => row.id.equals(id))).write(
      database.NutritionThalisCompanion(
        lifecycle: const Value('archived'),
        updatedAt: Value(_nowUtc()),
      ),
    );
  }

  Future<NutritionThaliDraft> saveDraft(NutritionThaliDraft draft) async {
    _validateDraftOwner(draft);
    if (draft.lifecycle != 'active') {
      throw const NutritionThaliValidationError(
        'inactive_thali',
        'Only an active thali draft can be edited.',
      );
    }
    await _validateItems(draft);
    final existing = await (_db.select(
      _db.nutritionThalis,
    )..where((row) => row.id.equals(draft.id))).getSingleOrNull();
    if (existing == null && draft.currentVersion != 1) {
      throw const NutritionThaliConflictError(
        'invalid_thali_version',
        'A new thali draft must start at version one.',
      );
    }
    if (existing != null) {
      if (existing.userId != draft.userId) {
        throw const NutritionThaliConflictError(
          'thali_ownership',
          'The thali belongs to another user scope.',
        );
      }
      if (existing.lifecycle != 'active') {
        throw const NutritionThaliConflictError(
          'inactive_thali',
          'An archived or deleted thali cannot be edited.',
        );
      }
      if (existing.currentVersion != draft.currentVersion) {
        throw const NutritionThaliConflictError(
          'stale_thali_version',
          'The saved thali changed elsewhere. Reload it before editing.',
        );
      }
    }
    final now = _nowUtc();
    final version = existing == null ? 1 : existing.currentVersion + 1;
    final persistedMeasureIds = await _persistedMeasureIds(draft);
    try {
      await _db.transaction(() async {
        if (existing == null) {
          await _db
              .into(_db.nutritionThalis)
              .insert(
                database.NutritionThalisCompanion.insert(
                  id: draft.id,
                  userId: draft.userId,
                  name: draft.name,
                  description: Value(draft.description),
                  lifecycle: 'active',
                  currentVersion: version,
                  createdAt: Value(draft.createdAtUtc),
                  updatedAt: Value(now),
                ),
              );
        } else {
          await (_db.update(
            _db.nutritionThalis,
          )..where((row) => row.id.equals(draft.id))).write(
            database.NutritionThalisCompanion(
              name: Value(draft.name),
              description: Value(draft.description),
              lifecycle: const Value('active'),
              currentVersion: Value(version),
              updatedAt: Value(now),
            ),
          );
        }
        _inject('after_thali_header');
        await (_db.delete(
          _db.nutritionThaliItems,
        )..where((row) => row.thaliId.equals(draft.id))).go();
        await _db.batch((batch) {
          batch.insertAll(
            _db.nutritionThaliItems,
            draft.items
                .map(
                  (item) => database.NutritionThaliItemsCompanion.insert(
                    id: item.id,
                    thaliId: draft.id,
                    position: item.position,
                    foodId: Value(item.foodId),
                    recipeVersionId: Value(item.recipeVersionId),
                    quantityValue: item.quantity.amount.asDouble,
                    quantityDimension: _dimensionId(item.quantity.dimension),
                    quantityUnit: _databaseUnitId(item.quantity.unit),
                    // This schema projection references reviewed standard
                    // measures only. Personal vessel and unresolved measure
                    // identities remain in the typed quantity envelope.
                    measureId: Value(persistedMeasureIds[item.id]),
                    optional: Value(item.optional),
                    notes: Value(_encodeItemNotes(item)),
                    createdAt: Value(now),
                    updatedAt: Value(now),
                  ),
                )
                .toList(growable: false),
          );
        });
        _inject('after_thali_items');
      });
    } on NutritionThaliError {
      rethrow;
    } catch (error) {
      throw NutritionThaliPersistenceError(
        'save_draft_failed',
        'The thali draft could not be saved transactionally.',
        cause: error,
      );
    }
    return (await getDraft(userId: draft.userId, thaliId: draft.id))!;
  }

  Future<NutritionThaliPreview> preview({
    required NutritionThaliDraft draft,
    DateTime? evaluatedAtUtc,
    Iterable<String> acknowledgedConstraintIds = const [],
  }) async {
    _validateDraftOwner(draft);
    if (draft.lifecycle != 'active') {
      throw const NutritionThaliValidationError(
        'inactive_thali',
        'Only an active thali can be previewed for new logging.',
      );
    }
    if (draft.items.isEmpty) {
      throw const NutritionThaliValidationError(
        'empty_thali',
        'Add at least one item before previewing a thali.',
      );
    }
    final previews = <NutritionThaliItemPreview>[];
    for (final item in draft.items) {
      previews.add(await _previewItem(draft, item));
    }
    final requested = _registry.definitions
        .map((definition) => definition.id)
        .toSet();
    final aggregate = NutrientAggregationService.aggregate(
      registry: _registry,
      contributions: previews.expand(
        (item) => item.calculation.facts.values.map(
          (fact) => NutrientContribution(fact: fact),
        ),
      ),
      requestedNutrientIds: requested,
    );
    final lines = await _constraintLines(previews);
    final evaluation = await _constraints.evaluateThali(
      userId: draft.userId,
      thaliId: draft.id,
      lines: lines,
      // A draft version is the stable preview boundary. This keeps repeated
      // previews equivalent instead of changing only because wall-clock time
      // advanced between rebuilds.
      atUtc: evaluatedAtUtc ?? draft.updatedAtUtc,
      acknowledgedConstraintIds: acknowledgedConstraintIds,
    );
    final itemEvidence = <String, dynamic>{
      for (final item in previews)
        item.item.id: {
          ...item.evidence,
          'resolved_quantity': item.resolvedQuantity.calculationQuantity
              .toJson(),
          'original_quantity': item.resolvedQuantity.original.toJson(),
          'calculation_fingerprint': item.calculation.lineage.fingerprint,
          'calculation_rule_version': item.calculation.calculationRuleVersion,
        },
    };
    return NutritionThaliPreview(
      draft: draft,
      items: previews,
      aggregate: aggregate,
      constraintEvaluation: evaluation,
      calculationVersion: kNutritionThaliCalculationVersion,
      evidence: {
        'contract_version': kNutritionThaliContractVersion,
        'thali_id': draft.id,
        'thali_version': draft.currentVersion,
        'thali_fingerprint': draft.compositionFingerprint,
        'items': itemEvidence,
        'calculation_version': kNutritionThaliCalculationVersion,
        'nutrient_registry_version': _registry.version,
        'constraint_evaluation_fingerprint': evaluation.fingerprint,
      },
    );
  }

  Future<NutritionConsumptionSnapshot> finalize({
    required NutritionThaliPreview preview,
    required String mealCategory,
    required DateTime loggedAt,
    required String commandId,
    String? consumptionId,
    String? mealGroupId,
    required String localDate,
    required String timezoneId,
    bool allowPartial = false,
    NutritionConstraintAcknowledgement? acknowledgement,
    String? supersedesSnapshotId,
    String? correctionId,
    String? correctionReason,
    bool allowCompositionVariation = false,
  }) async {
    if (commandId.trim().isEmpty) {
      throw const NutritionThaliValidationError(
        'missing_command_id',
        'A retryable thali finalization command ID is required.',
      );
    }
    final existing = await _consumption.findByCommandId(
      userId: preview.draft.userId,
      commandId: commandId,
    );
    if (existing != null) return existing;
    if (preview.isPartial || preview.isUnknown || preview.hasUnresolvedInputs) {
      if (!allowPartial) {
        throw const NutritionThaliValidationError(
          'partial_confirmation_required',
          'This thali contains unknown nutrition. Confirm the partial result before logging.',
        );
      }
    }
    await _validatePreviewDependencies(
      preview,
      allowCompositionVariation: allowCompositionVariation,
    );
    final items = [
      for (final item in preview.items) _finalizationItem(preview, item),
    ];
    final evaluation = preview.constraintEvaluation;
    if (acknowledgement != null && evaluation == null) {
      throw const NutritionThaliValidationError(
        'orphan_constraint_acknowledgement',
        'A thali acknowledgement requires an immutable evaluation.',
      );
    }
    try {
      return await _consumption.finalizeConsumption(
        NutritionConsumptionFinalizeRequest(
          userId: preview.draft.userId,
          consumptionId: consumptionId,
          commandId: commandId,
          loggedAtUtc: loggedAt,
          mealCategory: mealCategory,
          mealGroupId: mealGroupId,
          sourceType: 'thali',
          thaliId: preview.draft.id,
          localDate: localDate,
          timezoneId: timezoneId,
          supersedesSnapshotId: supersedesSnapshotId,
          correctionId: correctionId,
          correctionReason: correctionReason,
          calculatorVersion: preview.calculationVersion,
          items: items,
          evidence: {
            ...preview.evidence,
            if (allowCompositionVariation) 'temporary_variation': true,
          },
          constraintEvaluation: evaluation,
          constraintAcknowledgement: acknowledgement,
        ),
      );
    } on NutritionConsumptionError catch (error) {
      throw NutritionThaliError(error.code, error.message, cause: error);
    } catch (error) {
      throw NutritionThaliPersistenceError(
        'finalization_failed',
        'The thali finalization failed without creating a partial snapshot.',
        cause: error,
      );
    }
  }

  Future<NutritionThaliItemPreview> _previewItem(
    NutritionThaliDraft draft,
    NutritionThaliItem item,
  ) async {
    final resolved = await _resolveQuantity(draft.userId, item);
    try {
      late final NutritionCalculationResult calculation;
      late final String label;
      late final Map<String, dynamic> evidence;
      if (item.source == NutritionThaliItemSource.food) {
        final foodId = item.foodId!;
        final row = await (_db.select(
          _db.nutritionFoods,
        )..where((table) => table.id.equals(foodId))).getSingleOrNull();
        if (row == null || row.lifecycle != 'active') {
          throw const NutritionThaliNotFoundError(
            'food_not_found',
            'The selected direct food is unavailable for this thali.',
          );
        }
        label = row.displayName;
        calculation = await _recipeLogging.previewDirectFood(
          foodId: foodId,
          quantity: resolved.calculationQuantity,
          itemId: item.id,
        );
        evidence = {
          'item_id': item.id,
          'source': 'food',
          'food_id': foodId,
          'food_source_type': row.sourceType,
          'food_source_ref': row.sourceRef,
          'quantity': item.quantity.toJson(),
        };
      } else {
        final version = await _recipes.getVersion(item.recipeVersionId!);
        if (version == null ||
            version.status != NutritionRecipeVersionStatus.published) {
          throw const NutritionThaliNotFoundError(
            'unpublished_recipe_version',
            'The selected recipe version is no longer loggable.',
          );
        }
        final recipe = await _recipes.getRecipe(version.recipeId);
        if (recipe == null || recipe.userId != draft.userId) {
          throw const NutritionThaliNotFoundError(
            'recipe_not_found',
            'The selected saved recipe is unavailable for this user.',
          );
        }
        label = recipe.name;
        final amount = _recipeAmount(version, item.quantity);
        final recipePreview = await _recipeLogging.preview(
          userId: draft.userId,
          recipeId: recipe.id,
          recipeVersionId: version.id,
          amount: amount,
        );
        calculation = recipePreview.calculation;
        evidence = {
          'item_id': item.id,
          'source': 'recipe',
          'recipe_id': recipe.id,
          'recipe_version_id': version.id,
          'recipe_version_number': version.versionNumber,
          'recipe_head_version_id': recipe.currentVersionId,
          'recipe_version_updated_at': version.updatedAt
              .toUtc()
              .toIso8601String(),
          'amount': amount.toJson(),
          'quantity': item.quantity.toJson(),
        };
      }
      return NutritionThaliItemPreview(
        item: item,
        displayLabel: item.displayLabel ?? label,
        resolvedQuantity: resolved,
        calculation: calculation,
        evidence: evidence,
      );
    } on NutritionThaliError {
      rethrow;
    } on NutritionRecipeLogError catch (error) {
      throw NutritionThaliError(error.code, error.message, cause: error);
    } on NutritionCalculationError catch (error) {
      throw NutritionThaliError(error.code, error.message, cause: error);
    } on QuantityError catch (error) {
      throw NutritionThaliValidationError(
        'invalid_quantity',
        error.toString(),
        cause: error,
      );
    }
  }

  NutritionRecipeLogAmount _recipeAmount(
    NutritionRecipeVersionModel version,
    Quantity quantity,
  ) {
    if (quantity.unit != QuantityUnit.serving) {
      throw const NutritionThaliValidationError(
        'invalid_recipe_quantity',
        'Saved recipe components accept a recipe fraction or declared serving quantity.',
      );
    }
    final reference = quantity.context.servingDefinition;
    if (reference == null) {
      throw const NutritionThaliValidationError(
        'missing_recipe_serving_context',
        'A saved recipe quantity needs its immutable serving or complete-recipe definition.',
      );
    }
    final completeId = 'recipe-complete:${version.id}';
    if (reference.id == completeId) {
      return NutritionRecipeLogAmount.fraction(quantity.amount);
    }
    final definition = version.servingDefinition;
    if (definition == null ||
        reference.id != definition.id ||
        reference.revision != definition.revision) {
      throw const NutritionThaliValidationError(
        'stale_recipe_serving_context',
        'The selected recipe serving definition is not the immutable version definition.',
      );
    }
    return NutritionRecipeLogAmount.scalar(
      quantity.amount.divide(definition.count),
    );
  }

  Future<NutritionThaliResolvedQuantity> _resolveQuantity(
    String userId,
    NutritionThaliItem item,
  ) async {
    NutritionQuantityService.validatePositiveConsumedQuantity(item.quantity);
    if (item.quantity.unit != QuantityUnit.householdReference) {
      return NutritionThaliResolvedQuantity(
        original: item.quantity,
        calculationQuantity: item.quantity,
        measureId: item.measureId,
        evidence: {'resolution': 'not_required'},
      );
    }
    final measureId = item.measureId?.trim();
    if (measureId == null || measureId.isEmpty) {
      throw const NutritionThaliValidationError(
        'missing_measure_id',
        'A household quantity needs a stable measure or vessel identity.',
      );
    }
    final vessel =
        await (_db.select(_db.nutritionPersonalVessels)..where(
              (row) => row.id.equals(measureId) & row.userId.equals(userId),
            ))
            .getSingleOrNull();
    final selection = vessel == null
        ? NutritionStandardMeasureSelection(measureId)
        : NutritionPersonalVesselSelection(measureId);
    final conversion = await _measures.convertToVolume(
      userId: userId,
      selection: selection,
      count: Quantity(amount: item.quantity.amount, unit: QuantityUnit.piece),
    );
    if (conversion is NutritionMeasureConversionUnresolved) {
      throw NutritionThaliValidationError(conversion.code, conversion.message);
    }
    if (conversion is! NutritionMeasureConversionResolved) {
      throw const NutritionThaliValidationError(
        'unresolved_measure_volume',
        'The selected measure did not resolve to a supported volume.',
      );
    }
    final volume = conversion.volume.normalizedToMillilitres();
    final point = volume.point;
    if (point == null) {
      throw const NutritionThaliValidationError(
        'unresolved_measure_volume',
        'The selected measure has no point volume for calculation.',
      );
    }
    final calculationQuantity = Quantity(
      amount: point,
      unit: QuantityUnit.millilitre,
      context: QuantityContext(
        householdMeasure: item.quantity.context.householdMeasure,
        conversion: QuantityConversionContext(
          foodIdentityId: item.foodId,
          vesselCalibrationId: conversion.calibrationId,
        ),
        source: conversion.source.stableId,
        sourceScope: conversion.calibrationId == null
            ? 'reviewed_measure:${conversion.definitionVersion}'
            : 'calibration:${conversion.calibrationId}:v${conversion.calibrationVersion}',
        approximate: volume.isRange,
      ),
    );
    final originalQuantity = _resolvedOriginalQuantity(
      item.quantity,
      calibrationId: conversion.calibrationId,
      approximate: volume.isRange,
    );
    return NutritionThaliResolvedQuantity(
      original: originalQuantity,
      calculationQuantity: calculationQuantity,
      measureId: measureId,
      evidence: {
        'resolution': 'volume',
        'measure_id': measureId,
        'source': conversion.source.stableId,
        if (conversion.definitionVersion != null)
          'definition_version': conversion.definitionVersion,
        if (conversion.calibrationId != null)
          'calibration_id': conversion.calibrationId,
        if (conversion.calibrationVersion != null)
          'calibration_version': conversion.calibrationVersion,
        'volume': volume.toJson(),
      },
    );
  }

  Future<List<NutritionConstraintSubjectLine>> _constraintLines(
    List<NutritionThaliItemPreview> previews,
  ) async {
    final lines = <NutritionConstraintSubjectLine>[];
    for (final preview in previews) {
      final item = preview.item;
      if (item.source == NutritionThaliItemSource.food) {
        final evidence = await _constraints.listFoodEvidence(item.foodId!);
        lines.add(
          NutritionConstraintSubjectLine(
            id: item.id,
            foodId: item.foodId!,
            evidence: evidence.map((value) => _qualifyEvidence(value, item.id)),
          ),
        );
        continue;
      }
      final version = await _recipes.getVersion(item.recipeVersionId!);
      if (version == null) {
        throw const NutritionThaliNotFoundError(
          'recipe_version_not_found',
          'The immutable recipe version for dietary evaluation is unavailable.',
        );
      }
      for (final ingredient in version.ingredients) {
        final lineId = '${item.id}::${ingredient.id}';
        final evidence = await _constraints.listFoodEvidence(ingredient.foodId);
        lines.add(
          NutritionConstraintSubjectLine(
            id: lineId,
            foodId: ingredient.foodId,
            evidence: evidence.map((value) => _qualifyEvidence(value, lineId)),
          ),
        );
      }
    }
    return List.unmodifiable(lines);
  }

  Future<void> _validatePreviewDependencies(
    NutritionThaliPreview preview, {
    required bool allowCompositionVariation,
  }) async {
    final current = await getDraft(
      userId: preview.draft.userId,
      thaliId: preview.draft.id,
    );
    if (current == null ||
        current.currentVersion != preview.draft.currentVersion ||
        (!allowCompositionVariation &&
            current.compositionFingerprint !=
                preview.draft.compositionFingerprint)) {
      throw const NutritionThaliConflictError(
        'stale_thali_version',
        'The thali changed after preview. Reload the composition before saving.',
      );
    }
    for (final item in preview.items) {
      final refreshed = await _previewItem(current, item.item);
      if (refreshed.calculation.lineage.fingerprint !=
              item.calculation.lineage.fingerprint ||
          !_sameJson(
            refreshed.resolvedQuantity.calculationQuantity.toJson(),
            item.resolvedQuantity.calculationQuantity.toJson(),
          )) {
        throw NutritionThaliConflictError(
          item.item.quantity.context.conversion?.vesselCalibrationId == null
              ? 'stale_dependency'
              : 'stale_calibration',
          'An item dependency changed after preview. Recalculate the thali.',
        );
      }
    }
  }

  Future<void> _validateItems(NutritionThaliDraft draft) async {
    for (final item in draft.items) {
      try {
        NutritionQuantityService.validatePositiveConsumedQuantity(
          item.quantity,
        );
      } on QuantityError catch (error) {
        throw NutritionThaliValidationError(
          'invalid_quantity',
          error.toString(),
          cause: error,
        );
      }
      if (item.source == NutritionThaliItemSource.food) {
        final row = await (_db.select(
          _db.nutritionFoods,
        )..where((table) => table.id.equals(item.foodId!))).getSingleOrNull();
        if (row == null || row.lifecycle != 'active') {
          throw const NutritionThaliValidationError(
            'food_not_found',
            'A thali item must reference an active portable food identity.',
          );
        }
      } else {
        final version = await _recipes.getVersion(item.recipeVersionId!);
        final recipe = version == null
            ? null
            : await _recipes.getRecipe(version.recipeId);
        if (version == null ||
            version.status != NutritionRecipeVersionStatus.published ||
            recipe == null ||
            recipe.userId != draft.userId ||
            recipe.lifecycle != NutritionRecipeLifecycle.active) {
          throw const NutritionThaliValidationError(
            'unpublished_recipe_version',
            'A thali item must reference an active recipe with a published immutable version.',
          );
        }
      }
      if (item.quantity.unit == QuantityUnit.householdReference &&
          (item.measureId == null || item.measureId!.trim().isEmpty)) {
        throw const NutritionThaliValidationError(
          'missing_measure_id',
          'A household quantity must preserve its measure identity.',
        );
      }
    }
  }

  Future<NutritionThaliDraft> _readDraft(
    database.NutritionThali row,
    String userId,
  ) async {
    final itemRows =
        await (_db.select(_db.nutritionThaliItems)
              ..where((item) => item.thaliId.equals(row.id))
              ..orderBy([
                (item) => OrderingTerm(expression: item.position),
                (item) => OrderingTerm(expression: item.id),
              ]))
            .get();
    final items = <NutritionThaliItem>[];
    for (final item in itemRows) {
      items.add(await _readItem(item));
    }
    return NutritionThaliDraft(
      id: row.id,
      userId: userId,
      name: row.name,
      description: row.description,
      lifecycle: row.lifecycle,
      currentVersion: row.currentVersion,
      createdAtUtc: row.createdAt,
      updatedAtUtc: row.updatedAt,
      items: items,
    );
  }

  Future<NutritionThaliItem> _readItem(database.NutritionThaliItem row) async {
    final decoded = _decodeItemNotes(row.notes);
    Quantity? storedQuantity;
    if (decoded.quantity != null) {
      storedQuantity = decoded.quantity;
    }
    final quantity =
        storedQuantity ??
        await _quantityFromColumns(
          amount: row.quantityValue,
          dimension: row.quantityDimension,
          unit: row.quantityUnit,
          measureId: row.measureId,
          recipeVersionId: row.recipeVersionId,
        );
    String? label;
    if (row.foodId != null) {
      final food = await (_db.select(
        _db.nutritionFoods,
      )..where((table) => table.id.equals(row.foodId!))).getSingleOrNull();
      label = food?.displayName;
    } else if (row.recipeVersionId != null) {
      final version = await _recipes.getVersion(row.recipeVersionId!);
      if (version != null) {
        label = (await _recipes.getRecipe(version.recipeId))?.name;
      }
    }
    return NutritionThaliItem(
      id: row.id,
      position: row.position,
      source: row.foodId != null
          ? NutritionThaliItemSource.food
          : NutritionThaliItemSource.recipe,
      foodId: row.foodId,
      recipeVersionId: row.recipeVersionId,
      quantity: quantity,
      measureId:
          row.measureId ??
          storedQuantity?.context.householdMeasure?.measureType,
      optional: row.optional,
      notes: decoded.notes,
      displayLabel: label,
    );
  }

  Future<Quantity> _quantityFromColumns({
    required double amount,
    required String dimension,
    required String unit,
    required String? measureId,
    required String? recipeVersionId,
  }) async {
    final quantityUnit = _quantityUnitFromDatabase(unit);
    final context = switch (quantityUnit) {
      QuantityUnit.householdReference => QuantityContext(
        householdMeasure: HouseholdMeasureReference(
          measureType: measureId ?? 'unresolved',
        ),
      ),
      QuantityUnit.serving => QuantityContext(
        servingDefinition: await _servingReferenceFor(
          recipeVersionId,
          measureId,
        ),
      ),
      _ => const QuantityContext(),
    };
    final result = Quantity.fromNum(
      amount: amount,
      unit: quantityUnit,
      context: context,
    );
    if (_dimensionId(result.dimension) != dimension) {
      throw const NutritionThaliPersistenceError(
        'quantity_projection_mismatch',
        'Persisted thali quantity dimension does not match its unit.',
      );
    }
    return result;
  }

  Future<ServingDefinitionReference> _servingReferenceFor(
    String? recipeVersionId,
    String? measureId,
  ) async {
    if (recipeVersionId != null) {
      final version = await _recipes.getVersion(recipeVersionId);
      final serving = version?.servingDefinition;
      if (serving != null) {
        return ServingDefinitionReference(
          id: serving.id,
          revision: serving.revision,
          source: serving.source,
        );
      }
      return ServingDefinitionReference(
        id: 'recipe-complete:$recipeVersionId',
        revision: version?.calculationRuleVersion ?? 'unknown',
        source: 'recipe_version',
      );
    }
    if (measureId == null || measureId.trim().isEmpty) {
      throw const NutritionThaliPersistenceError(
        'missing_serving_context',
        'Persisted serving quantity has no definition context.',
      );
    }
    return ServingDefinitionReference(
      id: measureId,
      revision: 'unknown',
      source: 'thali',
    );
  }

  String _encodeItemNotes(NutritionThaliItem item) => jsonEncode({
    'contract_version': kNutritionThaliContractVersion,
    if (item.notes != null) 'notes': item.notes,
    'quantity': item.quantity.toJson(),
  });

  Future<Map<String, String?>> _persistedMeasureIds(
    NutritionThaliDraft draft,
  ) async {
    final ids = <String, String?>{};
    for (final item in draft.items) {
      final measureId = item.measureId?.trim();
      if (measureId == null || measureId.isEmpty) {
        ids[item.id] = null;
        continue;
      }
      final standard = await (_db.select(
        _db.nutritionHouseholdMeasures,
      )..where((row) => row.id.equals(measureId))).getSingleOrNull();
      ids[item.id] = standard == null ? null : measureId;
    }
    return ids;
  }

  _DecodedItemNotes _decodeItemNotes(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const _DecodedItemNotes();
    }
    try {
      final value = jsonDecode(raw);
      if (value is Map && value.containsKey('contract_version')) {
        if (value['contract_version'] != kNutritionThaliContractVersion) {
          throw NutritionThaliPersistenceError(
            'unsupported_item_notes_version',
            'The thali item quantity envelope uses an unsupported version.',
          );
        }
        final quantity = value['quantity'];
        try {
          return _DecodedItemNotes(
            notes: value['notes'] is String ? value['notes'] as String : null,
            quantity: quantity is Map
                ? Quantity.fromJson(Map<String, dynamic>.from(quantity))
                : null,
          );
        } catch (error) {
          throw NutritionThaliPersistenceError(
            'malformed_item_quantity',
            'The persisted thali quantity envelope is malformed.',
            cause: error,
          );
        }
      }
    } catch (error) {
      if (error is NutritionThaliPersistenceError) rethrow;
      // Older plain-text notes remain readable as notes.
    }
    return _DecodedItemNotes(notes: raw);
  }

  NutritionConsumptionItemInput _finalizationItem(
    NutritionThaliPreview preview,
    NutritionThaliItemPreview item,
  ) {
    final calculation = preview.snapshotFor(item, _registry);
    final evidence = <String, dynamic>{
      ...item.evidence,
      'resolved_quantity': item.resolvedQuantity.calculationQuantity.toJson(),
      'original_quantity': item.resolvedQuantity.original.toJson(),
      'quantity_evidence': item.resolvedQuantity.evidence,
    };
    final quantityEvidence = item.resolvedQuantity.evidence;
    if (quantityEvidence['resolution'] == 'volume') {
      final measureEvidence = <String, dynamic>{
        'source': quantityEvidence['source'],
        if (quantityEvidence['source'] == 'reviewed_standard' &&
            quantityEvidence['measure_id'] is String)
          'measure_id': quantityEvidence['measure_id'],
        if (quantityEvidence['source'] == 'reviewed_standard' &&
            quantityEvidence['definition_version'] is int)
          'definition_version': quantityEvidence['definition_version'],
        if (quantityEvidence['source'] == 'user_calibration' &&
            quantityEvidence['measure_id'] is String)
          'vessel_id': quantityEvidence['measure_id'],
        if (quantityEvidence['calibration_id'] is String)
          'calibration_id': quantityEvidence['calibration_id'],
        if (quantityEvidence['calibration_version'] is int)
          'calibration_version': quantityEvidence['calibration_version'],
        if (quantityEvidence['volume'] is Map)
          'volume': quantityEvidence['volume'],
      };
      evidence['measure'] = measureEvidence;
    }
    return NutritionConsumptionItemInput(
      id: item.item.id,
      position: item.item.position,
      sourceType: item.item.source.stableId,
      foodId: item.item.foodId,
      recipeVersionId: item.item.recipeVersionId,
      sourceReference: item.item.source == NutritionThaliItemSource.food
          ? item.item.foodId
          : item.item.recipeVersionId,
      displayLabel: item.displayLabel,
      // History must retain the user-selected typed input (for example
      // `1 cup` or `1 calibrated vessel`).  The resolved volume remains in
      // calculation/evidence lineage and is never the historical quantity
      // authority.
      quantity: item.resolvedQuantity.original,
      calculation: calculation,
      evidence: evidence,
    );
  }

  NutritionConstraintEvidence _qualifyEvidence(
    NutritionConstraintEvidence evidence,
    String componentLineage,
  ) => NutritionConstraintEvidence(
    // The same food evidence may legitimately occur more than once in a
    // thali.  Evaluation evidence identity is global to the result, so make
    // the component occurrence part of the deterministic identity while
    // retaining the original evidence ID as the suffix.
    id: '$componentLineage::${evidence.id}',
    subjectId: evidence.subjectId,
    target: evidence.target,
    status: evidence.status,
    source: evidence.source,
    confidence: evidence.confidence,
    notes: evidence.notes,
    sourceReference: evidence.sourceReference,
    ingredientLineage: componentLineage,
    version: evidence.version,
  );

  Quantity _resolvedOriginalQuantity(
    Quantity quantity, {
    required String? calibrationId,
    required bool approximate,
  }) {
    final context = quantity.context;
    final household = context.householdMeasure;
    if (household == null && !approximate) return quantity;
    return Quantity(
      amount: quantity.amount,
      unit: quantity.unit,
      context: QuantityContext(
        servingDefinition: context.servingDefinition,
        householdMeasure: household == null
            ? null
            : HouseholdMeasureReference(
                measureType: household.measureType,
                calibrationId: calibrationId ?? household.calibrationId,
                resolutionState: HouseholdResolutionState.volumeResolved,
              ),
        conversion: context.conversion,
        source: context.source,
        sourceScope: context.sourceScope,
        approximate: context.approximate || approximate,
        legacy: context.legacy,
      ),
    );
  }

  void _validateDraftOwner(NutritionThaliDraft draft) {
    _requireOwner(draft.userId);
    if (draft.id.trim().isEmpty) {
      throw const NutritionThaliValidationError(
        'missing_thali_id',
        'A thali requires a portable identity.',
      );
    }
  }

  String _requireOwner(String userId) {
    final owner = userId.trim();
    if (owner.isEmpty) {
      throw const NutritionThaliValidationError(
        'missing_user_id',
        'A user ownership scope is required.',
      );
    }
    return owner;
  }

  void _inject(String stage) => _failureInjector?.call(stage);

  static String _dimensionId(QuantityDimension dimension) =>
      switch (dimension) {
        QuantityDimension.householdReference => 'household_reference',
        _ => dimension.name,
      };

  static String _databaseUnitId(QuantityUnit unit) => switch (unit) {
    QuantityUnit.milligram => 'milligram',
    QuantityUnit.gram => 'gram',
    QuantityUnit.kilogram => 'kilogram',
    QuantityUnit.millilitre => 'millilitre',
    QuantityUnit.litre => 'litre',
    QuantityUnit.piece => 'piece',
    QuantityUnit.serving => 'serving',
    QuantityUnit.householdReference => 'household_reference',
    QuantityUnit.unknown ||
    QuantityUnit.legacy => throw const NutritionThaliValidationError(
      'unsupported_quantity_unit',
      'Unknown quantity units cannot be stored in a thali.',
    ),
  };

  static QuantityUnit _quantityUnitFromDatabase(String value) =>
      switch (value) {
        'milligram' => QuantityUnit.milligram,
        'gram' => QuantityUnit.gram,
        'kilogram' => QuantityUnit.kilogram,
        'millilitre' => QuantityUnit.millilitre,
        'litre' => QuantityUnit.litre,
        'piece' => QuantityUnit.piece,
        'serving' => QuantityUnit.serving,
        'household_reference' => QuantityUnit.householdReference,
        _ => throw NutritionThaliPersistenceError(
          'unsupported_quantity_unit',
          'Unsupported persisted thali quantity unit: $value.',
        ),
      };

  static bool _sameJson(Object? left, Object? right) =>
      jsonEncode(_canonical(left)) == jsonEncode(_canonical(right));

  static dynamic _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonical(value[key]),
      };
    }
    if (value is Iterable) {
      return value.map(_canonical).toList(growable: false);
    }
    return value;
  }
}

class _DecodedItemNotes {
  final String? notes;
  final Quantity? quantity;

  const _DecodedItemNotes({this.notes, this.quantity});
}
