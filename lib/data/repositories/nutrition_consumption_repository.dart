import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrients.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/typed_quantities.dart';
import '../database/app_database.dart' hide NutritionConsumptionSnapshot;

typedef NutritionConsumptionFailureInjector = void Function(String stage);

/// Authoritative owner for the immutable B03-11A snapshot graph.
///
/// This repository accepts resolved typed inputs and evidence. It never
/// resolves mutable food labels or recalculates historical nutrition facts.
class NutritionConsumptionRepository {
  final AppDatabase _db;
  final NutrientRegistry _registry;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;
  final NutritionConsumptionFailureInjector? _failureInjector;

  NutritionConsumptionRepository({
    required AppDatabase db,
    required NutrientRegistry registry,
    Uuid? uuid,
    DateTime Function()? nowUtc,
    NutritionConsumptionFailureInjector? failureInjector,
  }) : _db = db,
       _registry = registry,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _failureInjector = failureInjector;

  Future<NutritionConsumptionSnapshot> finalizeConsumption(
    NutritionConsumptionFinalizeRequest request,
  ) async {
    late final _PreparedConsumption prepared;
    try {
      prepared = await _prepare(request);
    } on NutritionConsumptionError {
      rethrow;
    } on QuantityError catch (error) {
      throw NutritionConsumptionValidationError(
        'invalid_quantity',
        error.message,
        cause: error,
      );
    } on NutrientError catch (error) {
      throw NutritionConsumptionValidationError(
        'invalid_calculation_result',
        error.message,
        cause: error,
      );
    }
    final id = _resolvedConsumptionId(request);
    final now = _nowUtc().toUtc();

    try {
      return await _db.transaction(() async {
        final existingById = await _findById(id);
        if (existingById != null) {
          return _reuseOrConflict(
            existingById,
            request,
            prepared.contentFingerprint,
          );
        }

        if (request.commandId != null) {
          final existingByCommand = await _findByCommand(
            request.userId,
            request.commandId!,
          );
          if (existingByCommand != null) {
            return _reuseOrConflict(
              existingByCommand,
              request,
              prepared.contentFingerprint,
            );
          }
        }

        final existingItemRows =
            await (_db.select(_db.nutritionSnapshotItems)..where(
                  (table) => table.id.isIn(
                    prepared.items.map((item) => item.input.id).toSet(),
                  ),
                ))
                .get();
        if (existingItemRows.isNotEmpty) {
          throw const NutritionConsumptionConflictError(
            'duplicate_consumed_item_id',
            'A consumed-item ID is already attached to another snapshot.',
          );
        }

        if (request.supersedesSnapshotId != null) {
          final predecessor = await _findById(request.supersedesSnapshotId!);
          if (predecessor == null || predecessor.userId != request.userId) {
            throw const NutritionConsumptionValidationError(
              'invalid_correction_predecessor',
              'A correction must reference an existing event owned by the user.',
            );
          }
          if (predecessor.id == id) {
            throw const NutritionConsumptionValidationError(
              'invalid_correction_predecessor',
              'A consumption event cannot supersede itself.',
            );
          }
          if (request.correctionId == null ||
              request.correctionReason == null) {
            throw const NutritionConsumptionValidationError(
              'incomplete_correction',
              'Corrections require an ID and reason.',
            );
          }
        }

        final lineage = NutritionConsumptionLineage(
          commandId: request.commandId,
          contentFingerprint: prepared.contentFingerprint,
          supersedesSnapshotId: request.supersedesSnapshotId,
          correctionId: request.correctionId,
          correctionReason: request.correctionReason,
          evidence: prepared.lineageEvidence,
        );

        await _db
            .into(_db.nutritionConsumptionSnapshots)
            .insert(
              NutritionConsumptionSnapshotsCompanion.insert(
                id: id,
                userId: request.userId.trim(),
                loggedAt: request.loggedAtUtc,
                mealCategory: request.mealCategory.trim(),
                mealGroupId: Value(request.mealGroupId),
                sourceType: request.sourceType.trim(),
                recipeVersionId: Value(prepared.recipeVersionId),
                thaliId: Value(request.thaliId),
                calculatorVersion: request.calculatorVersion.trim(),
                completeness: prepared.totals.completeness.state.name,
                estimateStatus: _estimateStatus(prepared.totals.facts),
                localDate: Value(request.localDate),
                timezoneId: Value(request.timezoneId),
                lineage: Value(lineage.canonicalJson),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        _inject('after_header');

        for (final item in prepared.items) {
          await _db
              .into(_db.nutritionSnapshotItems)
              .insert(
                NutritionSnapshotItemsCompanion.insert(
                  id: item.input.id,
                  snapshotId: id,
                  position: item.input.position,
                  foodId: Value(item.input.foodId),
                  preparationId: Value(item.input.preparationId),
                  recipeVersionId: Value(item.input.recipeVersionId),
                  quantityValue: _asDouble(item.input.quantity.amount),
                  quantityDimension: _dimensionId(
                    item.input.quantity.dimension,
                  ),
                  quantityUnit: _databaseUnitId(item.input.quantity.unit),
                  quantityContextId: Value(item.input.id),
                  sourceRef: Value(item.input.sourceReference),
                  basis: const Value('absolute'),
                  calculationVersion: Value(
                    item.input.calculation.calculatorVersion,
                  ),
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        }
        _inject('after_items');

        for (final item in prepared.items) {
          for (final nutrientId in item.facts.keys.toList()..sort()) {
            final fact = item.facts[nutrientId]!;
            await _db
                .into(_db.nutritionSnapshotNutrients)
                .insert(
                  NutritionSnapshotNutrientsCompanion.insert(
                    id: '$id::${item.input.id}::$nutrientId',
                    snapshotId: id,
                    itemId: Value(item.input.id),
                    nutrientId: nutrientId,
                    amount: Value(_asNullableDouble(fact.point)),
                    lower: Value(_asNullableDouble(fact.lower)),
                    upper: Value(_asNullableDouble(fact.upper)),
                    status: fact.status.stableId,
                    unit: fact.unit.stableId,
                    sourceVersion: fact.source.stableId,
                    basis: Value(fact.basis.kind.stableId),
                    factVersion: Value(fact.factVersion),
                    lineage: Value(
                      jsonEncode({
                        'fact': fact.toJson(),
                        'item_id': item.input.id,
                        'calculation_fingerprint':
                            item.input.calculation.calculationFingerprint,
                      }),
                    ),
                    createdAt: Value(now),
                    updatedAt: Value(now),
                  ),
                );
          }
        }
        _inject('after_nutrients');
        return _readSnapshot(id, request.userId);
      });
    } on NutritionConsumptionError {
      rethrow;
    } catch (error) {
      throw NutritionConsumptionPersistenceError(
        'finalization_failed',
        'The immutable consumption snapshot transaction failed.',
        cause: error,
      );
    }
  }

  Future<NutritionConsumptionSnapshot?> getSnapshot({
    required String userId,
    required String consumptionId,
  }) async {
    final row =
        await (_db.select(_db.nutritionConsumptionSnapshots)..where(
              (table) =>
                  table.id.equals(consumptionId) & table.userId.equals(userId),
            ))
            .getSingleOrNull();
    return row == null ? null : _readSnapshot(row.id, userId);
  }

  Future<List<NutritionConsumptionSnapshot>> listForLocalDate({
    required String userId,
    required String localDate,
  }) async {
    final rows =
        await (_db.select(_db.nutritionConsumptionSnapshots)
              ..where(
                (table) =>
                    table.userId.equals(userId) &
                    table.localDate.equals(localDate),
              )
              ..orderBy([
                (table) => OrderingTerm(expression: table.loggedAt),
                (table) => OrderingTerm(expression: table.id),
              ]))
            .get();
    return Future.wait(rows.map((row) => _readSnapshot(row.id, userId)));
  }

  /// Aggregates only active immutable snapshots. It never consults current
  /// foods, recipes, transformations, or vessel calibrations.
  Future<NutritionDailySnapshotTotals> dailyTotals({
    required String userId,
    required String localDate,
  }) async {
    final snapshots = await listForLocalDate(
      userId: userId,
      localDate: localDate,
    );
    final superseded = snapshots
        .map((snapshot) => snapshot.lineage.supersedesSnapshotId)
        .whereType<String>()
        .toSet();
    final active = snapshots
        .where((snapshot) => !superseded.contains(snapshot.id))
        .toList(growable: false);
    final requested = <String>{};
    final contributions = <NutrientContribution>[];
    for (final snapshot in active) {
      requested.addAll(snapshot.completeness.requestedNutrientIds);
      for (final item in snapshot.items) {
        for (final fact in item.facts.values) {
          contributions.add(NutrientContribution(fact: fact));
        }
      }
    }
    final totals = NutrientAggregationService.aggregate(
      registry: _registry,
      contributions: contributions,
      requestedNutrientIds: requested,
    );
    return NutritionDailySnapshotTotals(
      userId: userId,
      localDate: localDate,
      snapshotIds: active
          .map((snapshot) => snapshot.id)
          .toList(growable: false),
      totals: totals,
    );
  }

  Future<_PreparedConsumption> _prepare(
    NutritionConsumptionFinalizeRequest request,
  ) async {
    final userId = request.userId.trim();
    final mealCategory = request.mealCategory.trim();
    final sourceType = request.sourceType.trim();
    final calculatorVersion = request.calculatorVersion.trim();
    if (userId.isEmpty) _invalid('missing_user_id', 'User ID is required.');
    if (mealCategory.isEmpty) {
      _invalid('missing_meal_category', 'Meal category is required.');
    }
    if (sourceType.isEmpty) {
      _invalid('missing_source_type', 'Source type is required.');
    }
    if (calculatorVersion.isEmpty) {
      _invalid('missing_calculator_version', 'Calculator version is required.');
    }
    if ((request.localDate == null) != (request.timezoneId == null)) {
      _invalid(
        'incomplete_local_time_context',
        'Local date and timezone must be supplied together.',
      );
    }
    if (request.commandId != null && request.commandId!.trim().isEmpty) {
      _invalid('invalid_command_id', 'A command ID cannot be blank.');
    }
    final items = request.items.toList(growable: false);
    if (items.isEmpty) {
      _invalid('empty_snapshot', 'A snapshot needs at least one item.');
    }
    final ids = <String>{};
    final positions = <int>{};
    final requested = <String>{};
    final preparedItems = <_PreparedItem>[];
    final recipeIds = <String>{};

    for (final item in items) {
      if (item.id.trim().isEmpty || !ids.add(item.id)) {
        _invalid(
          'duplicate_consumed_item_id',
          'Consumed-item IDs must be unique.',
        );
      }
      if (!positions.add(item.position) || item.position < 0) {
        _invalid(
          'invalid_item_position',
          'Consumed-item positions must be unique.',
        );
      }
      try {
        NutritionQuantityService.validatePositiveConsumedQuantity(
          item.quantity,
        );
      } on QuantityError catch (error) {
        _invalid('invalid_quantity', error.message, error);
      }
      final hasFood = item.foodId != null && item.foodId!.trim().isNotEmpty;
      final hasRecipe =
          item.recipeVersionId != null &&
          item.recipeVersionId!.trim().isNotEmpty;
      if (hasFood == hasRecipe) {
        _invalid(
          'invalid_consumed_item_identity',
          'Each item must identify exactly one food or recipe version.',
        );
      }
      if (hasRecipe) recipeIds.add(item.recipeVersionId!);
      if (item.calculation.nutrientRegistryVersion != _registry.version) {
        _invalid(
          'unsupported_nutrient_registry_version',
          'Snapshot evidence uses an unsupported nutrient registry version.',
        );
      }
      if (item.calculation.calculatorVersion != calculatorVersion) {
        _invalid(
          'calculation_version_mismatch',
          'Item calculation versions must match the snapshot calculator version.',
        );
      }
      requested.addAll(item.calculation.completeness.requestedNutrientIds);
      late final Map<String, NutrientFact> facts;
      try {
        facts = _effectiveFacts(item.calculation);
      } on NutrientError catch (error) {
        _invalid('invalid_calculation_result', error.message, error);
      }
      for (final fact in facts.values) {
        try {
          fact.validateAgainst(_registry);
        } catch (error) {
          _invalid(
            'invalid_nutrient_fact',
            'Snapshot nutrient evidence is invalid.',
            error,
          );
        }
      }
      preparedItems.add(_PreparedItem(input: item, facts: facts));
    }
    final expectedPositions = List<int>.generate(
      items.length,
      (index) => index,
    );
    final actualPositions = items.map((item) => item.position).toList()..sort();
    if (actualPositions.length != expectedPositions.length ||
        !_sameInts(actualPositions, expectedPositions)) {
      _invalid(
        'invalid_item_position',
        'Item positions must be contiguous from zero.',
      );
    }
    if (recipeIds.length > 1) {
      _invalid(
        'multiple_recipe_versions',
        'One consumption event cannot point to multiple recipe versions.',
      );
    }
    await _validateFoodReferences(items);
    await _validateItemEvidence(items, request.userId);
    final derivedRecipeId = recipeIds.singleOrNull;
    if (request.recipeVersionId != null &&
        derivedRecipeId != null &&
        request.recipeVersionId != derivedRecipeId) {
      _invalid(
        'recipe_version_mismatch',
        'Header and item recipe versions differ.',
      );
    }
    final recipeVersionId = request.recipeVersionId ?? derivedRecipeId;
    if (recipeVersionId != null) {
      await _validateRecipeOwnership(recipeVersionId, request.userId);
      if (!recipeIds.contains(recipeVersionId)) {
        _invalid(
          'recipe_version_mismatch',
          'A recipe-version snapshot must include the referenced recipe item.',
        );
      }
    }
    if (request.thaliId != null && recipeVersionId != null) {
      _invalid(
        'ambiguous_snapshot_source',
        'A snapshot cannot point to both a recipe version and a thali.',
      );
    }
    if (requested.isEmpty) {
      _invalid(
        'invalid_calculation_result',
        'Calculation completeness must identify requested nutrients.',
      );
    }
    final totals = NutrientAggregationService.aggregate(
      registry: _registry,
      contributions: preparedItems.expand(
        (item) =>
            item.facts.values.map((fact) => NutrientContribution(fact: fact)),
      ),
      requestedNutrientIds: requested,
    );
    final contentFingerprint = request.contentFingerprint;
    final lineageEvidence = {
      'calculator_version': calculatorVersion,
      'nutrient_registry_version': _registry.version,
      'completeness': totals.completeness.toJson(),
      'totals': {
        'facts': {
          for (final id in totals.facts.keys.toList()..sort())
            id: totals.facts[id]!.toJson(),
        },
        'source_lineage': {
          for (final id in totals.sourceLineage.keys.toList()..sort())
            id: totals.sourceLineage[id]!
                .map((source) => source.stableId)
                .toList(),
        },
        'fact_version_lineage': totals.factVersionLineage,
      },
      'items': {for (final item in items) item.id: item.toLineageJson()},
      'request_evidence': request.evidence,
    };
    return _PreparedConsumption(
      items: preparedItems,
      totals: totals,
      recipeVersionId: recipeVersionId,
      contentFingerprint: contentFingerprint,
      lineageEvidence: lineageEvidence,
    );
  }

  Map<String, NutrientFact> _effectiveFacts(
    NutritionConsumptionCalculationSnapshot calculation,
  ) {
    final result = <String, NutrientFact>{...calculation.facts};
    for (final nutrientId in calculation.completeness.requestedNutrientIds) {
      if (result.containsKey(nutrientId)) continue;
      final status =
          calculation.completeness.notApplicableNutrientIds.contains(nutrientId)
          ? NutrientFactStatus.notApplicable
          : NutrientFactStatus.missing;
      final definition = _registry.definitionFor(nutrientId);
      result[nutrientId] = NutrientFact(
        nutrientId: nutrientId,
        unit: definition.unit,
        status: status,
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: NutrientSourceType.unknown,
        factVersion: calculation.calculatorVersion,
      );
    }
    return result;
  }

  Future<void> _validateRecipeOwnership(
    String recipeVersionId,
    String userId,
  ) async {
    final version = await (_db.select(
      _db.nutritionRecipeVersions,
    )..where((table) => table.id.equals(recipeVersionId))).getSingleOrNull();
    if (version == null) {
      _invalid(
        'missing_recipe_version',
        'Recipe version $recipeVersionId was not found.',
      );
    }
    final recipe = await (_db.select(
      _db.nutritionRecipes,
    )..where((table) => table.id.equals(version.recipeId))).getSingleOrNull();
    if (recipe == null || recipe.userId != userId) {
      _invalid(
        'recipe_version_ownership',
        'Recipe version is not owned by the requesting user.',
      );
    }
  }

  Future<void> _validateFoodReferences(
    Iterable<NutritionConsumptionItemInput> items,
  ) async {
    final foodIds = items
        .map((item) => item.foodId)
        .whereType<String>()
        .toSet();
    for (final foodId in foodIds) {
      final food = await (_db.select(
        _db.nutritionFoods,
      )..where((table) => table.id.equals(foodId))).getSingleOrNull();
      if (food == null) {
        _invalid(
          'missing_food_identity',
          'Food identity $foodId was not found.',
        );
      }
    }
    for (final item in items) {
      final preparationId = item.preparationId;
      if (preparationId == null) continue;
      final preparation = await (_db.select(
        _db.nutritionFoodPreparations,
      )..where((table) => table.id.equals(preparationId))).getSingleOrNull();
      if (preparation == null || preparation.foodId != item.foodId) {
        _invalid(
          'invalid_preparation_identity',
          'Preparation identity is missing or belongs to another food.',
        );
      }
    }
  }

  Future<void> _validateItemEvidence(
    Iterable<NutritionConsumptionItemInput> items,
    String userId,
  ) async {
    for (final item in items) {
      final measure = item.evidence['measure'];
      if (measure is Map) {
        final measureId = measure['measure_id'];
        if (measureId is String) {
          final row = await (_db.select(
            _db.nutritionHouseholdMeasures,
          )..where((table) => table.id.equals(measureId))).getSingleOrNull();
          if (row == null) {
            _invalid(
              'missing_measure_definition',
              'Measure $measureId was not found.',
            );
          }
        }
        final calibrationId = measure['calibration_id'];
        if (calibrationId is String) {
          final calibration =
              await (_db.select(_db.nutritionVesselCalibrations)
                    ..where((table) => table.id.equals(calibrationId)))
                  .getSingleOrNull();
          if (calibration == null) {
            _invalid(
              'missing_calibration',
              'Calibration $calibrationId was not found.',
            );
          }
          final vessel =
              await (_db.select(_db.nutritionPersonalVessels)
                    ..where((table) => table.id.equals(calibration.vesselId)))
                  .getSingleOrNull();
          if (vessel == null || vessel.userId != userId) {
            _invalid('missing_vessel', 'Calibration vessel is missing.');
          }
          final expectedVersion = measure['calibration_version'];
          if (expectedVersion is int &&
              expectedVersion != calibration.version) {
            _invalid(
              'calibration_version_mismatch',
              'Snapshot calibration evidence does not match the stored version.',
            );
          }
        }
      }
      final transformation = item.evidence['transformation'];
      if (transformation is Map) {
        final transformationId = transformation['id'];
        if (transformationId is String && transformationId != 'none') {
          final row =
              await (_db.select(_db.nutritionQuantityConversions)
                    ..where((table) => table.id.equals(transformationId)))
                  .getSingleOrNull();
          if (row == null) {
            _invalid(
              'missing_transformation',
              'Transformation $transformationId was not found.',
            );
          }
          final expectedVersion =
              transformation['rule_version'] ?? transformation['version'];
          if (expectedVersion is String && expectedVersion != row.ruleVersion) {
            _invalid(
              'transformation_version_mismatch',
              'Snapshot transformation evidence does not match the stored version.',
            );
          }
        }
      }
    }
  }

  Future<NutritionConsumptionSnapshot?> _findById(String id) async {
    final row = await (_db.select(
      _db.nutritionConsumptionSnapshots,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _readSnapshot(row.id, row.userId);
  }

  Future<NutritionConsumptionSnapshot?> _findByCommand(
    String userId,
    String commandId,
  ) async {
    final rows = await (_db.select(
      _db.nutritionConsumptionSnapshots,
    )..where((table) => table.userId.equals(userId))).get();
    for (final row in rows) {
      final raw = row.lineage;
      if (raw == null) continue;
      try {
        final lineage = NutritionConsumptionLineage.fromJson(jsonDecode(raw));
        if (lineage.commandId == commandId) {
          return _readSnapshot(row.id, userId);
        }
      } on NutritionConsumptionError {
        rethrow;
      } catch (error) {
        throw NutritionConsumptionPersistenceError(
          'invalid_persisted_lineage',
          'A persisted snapshot lineage envelope is malformed.',
          cause: error,
        );
      }
    }
    return null;
  }

  NutritionConsumptionSnapshot _reuseOrConflict(
    NutritionConsumptionSnapshot existing,
    NutritionConsumptionFinalizeRequest request,
    String fingerprint,
  ) {
    if (existing.userId != request.userId ||
        existing.lineage.contentFingerprint != fingerprint) {
      throw const NutritionConsumptionConflictError(
        'idempotency_conflict',
        'The identity or command was already used with a different payload.',
      );
    }
    return existing;
  }

  Future<NutritionConsumptionSnapshot> _readSnapshot(
    String id,
    String userId,
  ) async {
    final header =
        await (_db.select(_db.nutritionConsumptionSnapshots)..where(
              (table) => table.id.equals(id) & table.userId.equals(userId),
            ))
            .getSingleOrNull();
    if (header == null) {
      throw const NutritionConsumptionPersistenceError(
        'missing_snapshot',
        'The immutable consumption snapshot was not found.',
      );
    }
    final lineageRaw = header.lineage;
    if (lineageRaw == null) {
      throw const NutritionConsumptionPersistenceError(
        'missing_lineage',
        'A finalized snapshot must have a lineage envelope.',
      );
    }
    final lineage = NutritionConsumptionLineage.fromJson(
      jsonDecode(lineageRaw),
    );
    final evidenceItems = lineage.evidence['items'];
    if (evidenceItems is! Map) {
      throw const NutritionConsumptionPersistenceError(
        'missing_item_lineage',
        'Snapshot item lineage is missing.',
      );
    }
    final itemRows =
        await (_db.select(_db.nutritionSnapshotItems)
              ..where((table) => table.snapshotId.equals(id))
              ..orderBy([(table) => OrderingTerm(expression: table.position)]))
            .get();
    if (itemRows.isEmpty) {
      throw const NutritionConsumptionPersistenceError(
        'empty_snapshot',
        'A persisted snapshot cannot be read without items.',
      );
    }
    final nutrientRows =
        await (_db.select(_db.nutritionSnapshotNutrients)
              ..where((table) => table.snapshotId.equals(id))
              ..orderBy([
                (table) => OrderingTerm(expression: table.itemId),
                (table) => OrderingTerm(expression: table.nutrientId),
              ]))
            .get();
    final factsByItem = <String, Map<String, NutrientFact>>{};
    for (final row in nutrientRows) {
      final itemId = row.itemId;
      if (itemId == null) {
        throw const NutritionConsumptionPersistenceError(
          'invalid_nutrient_owner',
          'Snapshot nutrient rows must belong to an item.',
        );
      }
      final raw = row.lineage;
      if (raw == null) {
        throw const NutritionConsumptionPersistenceError(
          'missing_nutrient_lineage',
          'Snapshot nutrient rows must preserve exact nutrient facts.',
        );
      }
      final factEnvelope = jsonDecode(raw);
      if (factEnvelope is! Map || factEnvelope['fact'] == null) {
        throw const NutritionConsumptionPersistenceError(
          'invalid_nutrient_lineage',
          'Snapshot nutrient lineage is malformed.',
        );
      }
      final fact = NutrientFact.fromJson(factEnvelope['fact'], _registry);
      if (row.nutrientId != fact.nutrientId ||
          row.status != fact.status.stableId ||
          row.unit != fact.unit.stableId ||
          row.factVersion != fact.factVersion) {
        throw const NutritionConsumptionPersistenceError(
          'nutrient_row_mismatch',
          'Snapshot nutrient projection disagrees with its immutable fact.',
        );
      }
      factsByItem.putIfAbsent(itemId, () => {})[fact.nutrientId] = fact;
    }
    final snapshotItems = <NutritionConsumptionSnapshotItem>[];
    for (final row in itemRows) {
      final raw = evidenceItems[row.id];
      if (raw is! Map || raw['quantity'] is! Map) {
        throw NutritionConsumptionPersistenceError(
          'missing_item_lineage',
          'Snapshot item ${row.id} has no typed quantity evidence.',
        );
      }
      final quantity = Quantity.fromJson(
        Map<String, dynamic>.from(raw['quantity'] as Map),
      );
      snapshotItems.add(
        NutritionConsumptionSnapshotItem(
          id: row.id,
          position: row.position,
          sourceType: raw['source_type'] as String? ?? header.sourceType,
          foodId: row.foodId,
          recipeVersionId: row.recipeVersionId,
          preparationId: row.preparationId,
          sourceReference: raw['source_reference'] as String?,
          displayLabel: raw['display_label'] as String?,
          quantity: quantity,
          facts: Map.unmodifiable(factsByItem[row.id] ?? const {}),
        ),
      );
    }
    final requested = _readCompleteness(lineage).requestedNutrientIds;
    final totals = NutrientAggregationService.aggregate(
      registry: _registry,
      contributions: factsByItem.values.expand(
        (facts) => facts.values.map((fact) => NutrientContribution(fact: fact)),
      ),
      requestedNutrientIds: requested.toSet(),
    );
    return NutritionConsumptionSnapshot(
      id: header.id,
      userId: header.userId,
      loggedAtUtc: header.loggedAt.toUtc(),
      mealCategory: header.mealCategory,
      mealGroupId: header.mealGroupId,
      sourceType: header.sourceType,
      recipeVersionId: header.recipeVersionId,
      thaliId: header.thaliId,
      calculatorVersion: header.calculatorVersion,
      completeness: totals.completeness,
      totals: totals,
      localDate: header.localDate,
      timezoneId: header.timezoneId,
      createdAtUtc: header.createdAt.toUtc(),
      lineage: lineage,
      items: List.unmodifiable(snapshotItems),
    );
  }

  NutrientCompleteness _readCompleteness(NutritionConsumptionLineage lineage) {
    final raw = lineage.evidence['completeness'];
    if (raw is! Map) {
      throw const NutritionConsumptionPersistenceError(
        'missing_completeness',
        'Snapshot completeness evidence is missing.',
      );
    }
    return NutrientCompleteness.fromJson(raw);
  }

  String _resolvedConsumptionId(NutritionConsumptionFinalizeRequest request) {
    final supplied = request.consumptionId?.trim();
    if (supplied != null && supplied.isNotEmpty) return supplied;
    final command = request.commandId?.trim();
    if (command != null && command.isNotEmpty) {
      return 'consumption-${request.contentFingerprint.substring(0, 32)}';
    }
    return _uuid.v4();
  }

  void _inject(String stage) {
    _failureInjector?.call(stage);
  }

  static String _estimateStatus(Map<String, NutrientFact> facts) {
    final estimated = facts.values.any(
      (fact) => fact.status == NutrientFactStatus.estimated,
    );
    final available = facts.values.any((fact) => fact.isAvailable);
    if (!estimated) return 'none';
    return available &&
            facts.values.any(
              (fact) =>
                  fact.status != NutrientFactStatus.estimated &&
                  fact.isAvailable,
            )
        ? 'mixed'
        : 'estimated';
  }

  static double _asDouble(QuantityAmount amount) =>
      double.parse(amount.toString());

  static double? _asNullableDouble(NutrientAmount? amount) =>
      amount == null ? null : double.parse(amount.value.toString());

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
    QuantityUnit.legacy => throw const NutritionConsumptionValidationError(
      'unsupported_quantity_unit',
      'Unknown and legacy units cannot be persisted in a snapshot.',
    ),
  };

  static bool _sameInts(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  Never _invalid(String code, String message, [Object? cause]) =>
      throw NutritionConsumptionValidationError(code, message, cause: cause);
}

class _PreparedItem {
  final NutritionConsumptionItemInput input;
  final Map<String, NutrientFact> facts;

  const _PreparedItem({required this.input, required this.facts});
}

class _PreparedConsumption {
  final List<_PreparedItem> items;
  final NutrientAggregationResult totals;
  final String? recipeVersionId;
  final String contentFingerprint;
  final Map<String, dynamic> lineageEvidence;

  const _PreparedConsumption({
    required this.items,
    required this.totals,
    required this.recipeVersionId,
    required this.contentFingerprint,
    required this.lineageEvidence,
  });
}

extension<T> on Iterable<T> {
  T? get singleOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    final value = iterator.current;
    if (iterator.moveNext()) {
      throw StateError('Expected zero or one element.');
    }
    return value;
  }
}
