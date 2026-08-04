import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrients.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/typed_quantities.dart';
import '../database/app_database.dart'
    hide
        NutritionConsumptionSnapshot,
        NutritionUserConstraint,
        NutritionConstraintDefinition;

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
    final id = _resolvedConsumptionId(request);
    final requestFingerprint = request.contentFingerprint;

    try {
      return await _db.transaction(() async {
        final existingById = await _findById(id);
        if (existingById != null) {
          return _reuseOrConflict(existingById, request, requestFingerprint);
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
              requestFingerprint,
            );
          }
        }

        if (request.correctionId != null) {
          final existingByCorrection = await _findByCorrectionId(
            request.userId,
            request.correctionId!,
          );
          if (existingByCorrection != null) {
            return _reuseOrConflict(
              existingByCorrection,
              request,
              requestFingerprint,
            );
          }
        }

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
        final now = _nowUtc().toUtc();

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

        if (request.supersedesSnapshotId == null) {
          if (request.correctionId != null ||
              request.correctionReason != null) {
            throw const NutritionConsumptionValidationError(
              'incomplete_correction',
              'Correction metadata requires a predecessor snapshot.',
            );
          }
        } else {
          if (request.correctionId == null ||
              request.correctionReason == null ||
              request.correctionId!.trim().isEmpty ||
              request.correctionReason!.trim().isEmpty) {
            throw const NutritionConsumptionValidationError(
              'incomplete_correction',
              'Corrections require a non-blank ID and reason.',
            );
          }
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
          if (await _hasSuccessor(request.userId, predecessor.id)) {
            throw const NutritionConsumptionValidationError(
              'correction_predecessor_already_superseded',
              'A finalized event can have only one correction successor.',
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
                  quantityContextId: Value(
                    _quantityContextId(item.input.quantity),
                  ),
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
        await _persistConstraintEvaluation(
          snapshotId: id,
          evaluation: prepared.constraintEvaluation,
          acknowledgement: prepared.constraintAcknowledgement,
          items: prepared.items,
          evaluatedAt: now,
        );
        _inject('after_constraints');
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

  /// Looks up a committed command without resolving any mutable source data.
  ///
  /// Integration callers use this only to preserve the B03-11A idempotency
  /// path when acknowledgement is retried after the source object changes.
  Future<NutritionConsumptionSnapshot?> findByCommandId({
    required String userId,
    required String commandId,
  }) {
    final normalizedUserId = userId.trim();
    final normalizedCommandId = commandId.trim();
    if (normalizedUserId.isEmpty || normalizedCommandId.isEmpty) {
      return Future.value(null);
    }
    return _findByCommand(normalizedUserId, normalizedCommandId);
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

  /// Returns all canonical snapshots in deterministic historical order.
  ///
  /// This is a read-only primitive for the unified B03-11B read boundary. It
  /// deliberately returns immutable snapshots and never consults mutable food,
  /// recipe, conversion, or calibration tables.
  Future<List<NutritionConsumptionSnapshot>> listAllForUser({
    required String userId,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) async {
    final rows =
        await (_db.select(_db.nutritionConsumptionSnapshots)
              ..where((table) {
                final predicates = <Expression<bool>>[
                  table.userId.equals(userId),
                ];
                if (fromUtc != null) {
                  predicates.add(
                    table.loggedAt.isBiggerOrEqualValue(fromUtc.toUtc()),
                  );
                }
                if (toUtc != null) {
                  predicates.add(
                    table.loggedAt.isSmallerThanValue(toUtc.toUtc()),
                  );
                }
                var result = predicates.first;
                for (final predicate in predicates.skip(1)) {
                  result = result & predicate;
                }
                return result;
              })
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
    // A correction may be finalized on a different local date than the
    // original event. Resolve supersession across the user's full immutable
    // snapshot history before selecting the day's active events.
    final allRows = await (_db.select(
      _db.nutritionConsumptionSnapshots,
    )..where((table) => table.userId.equals(userId))).get();
    final superseded = <String>{};
    for (final row in allRows) {
      final raw = row.lineage;
      if (raw == null) continue;
      final lineage = _parsePersistedLineage(raw);
      final predecessor = lineage.supersedesSnapshotId;
      if (predecessor != null) superseded.add(predecessor);
    }
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
    if (request.evidence.containsKey('constraint_evaluation') ||
        request.evidence.containsKey('constraint_acknowledgement')) {
      _invalid(
        'reserved_constraint_evidence_key',
        'Dietary evaluation lineage must be supplied through its typed fields.',
      );
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
        _asDouble(item.quantity.amount);
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
      if (item.sourceType.isEmpty) {
        _invalid(
          'missing_item_source_type',
          'Each item requires a source type.',
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
      for (final entry in item.calculation.facts.entries) {
        if (entry.key != entry.value.nutrientId) {
          _invalid(
            'invalid_calculation_result',
            'Nutrient fact map keys must match nutrient identities.',
          );
        }
      }
      requested.addAll(item.calculation.completeness.requestedNutrientIds);
      late final Map<String, NutrientFact> facts;
      try {
        facts = _effectiveFacts(item.calculation);
      } on NutrientError catch (error) {
        _invalid('invalid_calculation_result', error.message, error);
      }
      final calculationCompleteness = NutrientCompletenessEvaluator.evaluate(
        registry: _registry,
        facts: facts,
        requestedNutrientIds: item.calculation.completeness.requestedNutrientIds
            .toSet(),
      );
      if (!_sameCompleteness(
        item.calculation.completeness,
        calculationCompleteness,
      )) {
        _invalid(
          'invalid_calculation_result',
          'Calculation completeness does not match its nutrient facts.',
        );
      }
      for (final fact in facts.values) {
        try {
          fact.validateAgainst(_registry);
          _asNullableDouble(fact.point);
          _asNullableDouble(fact.lower);
          _asNullableDouble(fact.upper);
        } catch (error) {
          if (error is NutritionConsumptionError) rethrow;
          _invalid(
            'invalid_nutrient_fact',
            'Snapshot nutrient evidence is invalid.',
            error,
          );
        }
      }
      preparedItems.add(
        _PreparedItem(
          input: item,
          facts: facts,
          calculationLineage: _normalizedCalculationLineage(
            item.calculation,
            facts,
            calculationCompleteness,
          ),
        ),
      );
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
    if (request.thaliId != null) {
      await _validateThaliOwnership(request.thaliId!, request.userId);
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
    final constraintEvaluation = request.constraintEvaluation;
    final constraintAcknowledgement = request.constraintAcknowledgement;
    if (constraintAcknowledgement != null && constraintEvaluation == null) {
      _invalid(
        'orphan_constraint_acknowledgement',
        'A constraint acknowledgement requires its immutable evaluation.',
      );
    }
    if (constraintEvaluation != null) {
      await _validateConstraintEvaluation(
        request: request,
        evaluation: constraintEvaluation,
        items: items,
        recipeVersionId: recipeVersionId,
        acknowledgement: constraintAcknowledgement,
      );
    }
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
      'items': {
        for (final item in preparedItems) item.input.id: item.toLineageJson(),
      },
      'request_evidence': request.evidence,
      if (constraintEvaluation != null)
        'constraint_evaluation': constraintEvaluation.toJson(),
      if (constraintAcknowledgement != null)
        'constraint_acknowledgement': constraintAcknowledgement.toJson(),
    };
    return _PreparedConsumption(
      items: preparedItems,
      totals: totals,
      recipeVersionId: recipeVersionId,
      contentFingerprint: contentFingerprint,
      lineageEvidence: lineageEvidence,
      constraintEvaluation: constraintEvaluation,
      constraintAcknowledgement: constraintAcknowledgement,
    );
  }

  Future<void> _validateConstraintEvaluation({
    required NutritionConsumptionFinalizeRequest request,
    required NutritionConstraintEvaluationResult evaluation,
    required Iterable<NutritionConsumptionItemInput> items,
    required String? recipeVersionId,
    required NutritionConstraintAcknowledgement? acknowledgement,
  }) async {
    if (evaluation.userId != request.userId) {
      _invalid(
        'constraint_evaluation_ownership',
        'Constraint evaluation belongs to another user.',
      );
    }
    if (recipeVersionId != null) {
      if (evaluation.recipeVersionId != recipeVersionId ||
          evaluation.foodId != null ||
          evaluation.subjectId != recipeVersionId) {
        _invalid(
          'constraint_evaluation_subject_mismatch',
          'Recipe constraint evaluation must reference the selected immutable version.',
        );
      }
    } else {
      final foodIds = items
          .map((item) => item.foodId)
          .whereType<String>()
          .toSet();
      if (evaluation.foodId == null ||
          evaluation.recipeVersionId != null ||
          evaluation.subjectId != evaluation.foodId ||
          !foodIds.contains(evaluation.foodId)) {
        _invalid(
          'constraint_evaluation_subject_mismatch',
          'Direct-food constraint evaluation must reference a consumed food.',
        );
      }
    }
    final evaluations = evaluation.evaluations;
    final constraintIds = evaluations.map((item) => item.constraintId).toList();
    if (constraintIds.toSet().length != constraintIds.length) {
      _invalid(
        'duplicate_constraint_evaluation',
        'A snapshot cannot contain duplicate constraint evaluations.',
      );
    }
    if (constraintIds.isNotEmpty) {
      final rows = await (_db.select(
        _db.nutritionUserConstraints,
      )..where((table) => table.id.isIn(constraintIds))).get();
      final byId = {for (final row in rows) row.id: row};
      if (byId.length != constraintIds.length) {
        _invalid(
          'missing_constraint',
          'Constraint evaluation references a missing user constraint.',
        );
      }
      for (final item in evaluations) {
        final row = byId[item.constraintId]!;
        if (row.userId != request.userId) {
          _invalid(
            'constraint_evaluation_ownership',
            'Constraint evaluation references another user\'s constraint.',
          );
        }
        late final NutritionConstraintDefinition definition;
        late final NutritionConstraintTarget target;
        try {
          definition = NutritionConstraintTaxonomy.definitionForId(
            row.definitionId,
          );
          final decoded = jsonDecode(row.value);
          if (decoded is! Map || decoded['target'] is! Map) {
            throw const FormatException('missing target envelope');
          }
          target = NutritionConstraintTarget.fromJson(decoded['target']);
        } catch (error) {
          _invalid(
            'invalid_constraint_persistence',
            'The persisted user constraint is malformed.',
            error,
          );
        }
        if (item.type != definition.type ||
            item.targetKey != target.stableKey) {
          _invalid(
            'constraint_evaluation_mismatch',
            'Constraint evaluation evidence does not match its user constraint.',
          );
        }
        NutritionConstraintTarget.fromStableKey(item.targetKey);
      }
    }
    if (acknowledgement != null) {
      if (acknowledgement.userId != request.userId ||
          acknowledgement.evaluationFingerprint != evaluation.fingerprint ||
          !constraintIds.contains(acknowledgement.constraintId)) {
        _invalid(
          'invalid_constraint_acknowledgement',
          'Constraint acknowledgement does not match the evaluated result.',
        );
      }
    }
    final acknowledgedIds = evaluations
        .where((item) => item.acknowledged)
        .map((item) => item.constraintId)
        .toSet();
    if (acknowledgedIds.isNotEmpty && acknowledgement == null) {
      _invalid(
        'invalid_constraint_acknowledgement',
        'An acknowledged constraint requires an explicit acknowledgement command.',
      );
    }
    if (acknowledgement != null &&
        !acknowledgedIds.contains(acknowledgement.constraintId)) {
      _invalid(
        'invalid_constraint_acknowledgement',
        'The acknowledgement command is not reflected in the evaluation result.',
      );
    }
  }

  Future<void> _persistConstraintEvaluation({
    required String snapshotId,
    required NutritionConstraintEvaluationResult? evaluation,
    required NutritionConstraintAcknowledgement? acknowledgement,
    required List<_PreparedItem> items,
    required DateTime evaluatedAt,
  }) async {
    if (evaluation == null) return;
    final ids = evaluation.evaluations
        .map((item) => item.constraintId)
        .toList();
    final rows = <dynamic>[];
    if (ids.isNotEmpty) {
      rows.addAll(
        await (_db.select(
          _db.nutritionUserConstraints,
        )..where((table) => table.id.isIn(ids))).get(),
      );
    }
    final crossContactById = {for (final row in rows) row.id: row.crossContact};
    final recipeItems = items
        .where((item) => item.input.recipeVersionId != null)
        .toList(growable: false);
    final recipeItemId = recipeItems.isEmpty
        ? null
        : recipeItems.first.input.id;
    for (final item in evaluation.evaluations) {
      final resultId = '$snapshotId::constraint::${item.constraintId}';
      await _db
          .into(_db.nutritionSnapshotConstraintResults)
          .insert(
            NutritionSnapshotConstraintResultsCompanion.insert(
              id: resultId,
              snapshotId: snapshotId,
              constraintId: item.constraintId,
              result: item.outcome.stableId,
              ruleVersion: evaluation.ruleVersion,
              evaluatedAt: evaluation.evaluatedAtUtc,
              createdAt: Value(evaluatedAt),
              updatedAt: Value(evaluatedAt),
            ),
          );
      for (var index = 0; index < item.evidence.length; index++) {
        final reference = item.evidence[index];
        final isRecipe = evaluation.recipeVersionId != null;
        final foodId = isRecipe ? null : reference.foodId ?? evaluation.foodId;
        final snapshotItemId = isRecipe ? recipeItemId : null;
        if (foodId == null && snapshotItemId == null) {
          throw const NutritionConsumptionPersistenceError(
            'constraint_evidence_owner',
            'Constraint evidence cannot be attached to a snapshot item.',
          );
        }
        final evidenceKind = crossContactById[item.constraintId] == true
            ? 'cross_contact'
            : isRecipe
            ? 'ingredient'
            : 'food';
        await _db
            .into(_db.nutritionSnapshotConstraintResultEvidence)
            .insert(
              NutritionSnapshotConstraintResultEvidenceCompanion.insert(
                id: '$resultId::evidence::$index::${reference.evidenceId}',
                resultId: resultId,
                foodId: Value(foodId),
                snapshotItemId: Value(snapshotItemId),
                evidenceKind: evidenceKind,
                status: reference.status.stableId,
                source: reference.source.stableId,
                version: reference.version.toString(),
                createdAt: Value(evaluatedAt),
              ),
            );
      }
      if (acknowledgement != null &&
          acknowledgement.constraintId == item.constraintId) {
        final itemId = items.isEmpty ? null : items.first.input.id;
        if (itemId == null) {
          throw const NutritionConsumptionPersistenceError(
            'constraint_acknowledgement_owner',
            'Constraint acknowledgement cannot be attached to an empty snapshot.',
          );
        }
        await _db
            .into(_db.nutritionSnapshotConstraintResultEvidence)
            .insert(
              NutritionSnapshotConstraintResultEvidenceCompanion.insert(
                id: '$resultId::acknowledgement::${acknowledgement.commandId}',
                resultId: resultId,
                snapshotItemId: Value(itemId),
                evidenceKind: 'user_override',
                status: 'unknown',
                source: 'user_entered',
                version: evaluation.ruleVersion,
                createdAt: Value(evaluatedAt),
              ),
            );
      }
    }
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

  Map<String, dynamic> _normalizedCalculationLineage(
    NutritionConsumptionCalculationSnapshot calculation,
    Map<String, NutrientFact> facts,
    NutrientCompleteness completeness,
  ) {
    final json = calculation.toJson();
    return {
      ...json,
      'facts': {
        for (final id in facts.keys.toList()..sort()) id: facts[id]!.toJson(),
      },
      'completeness': completeness.toJson(),
    };
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
    if (version.status == 'draft') {
      _invalid(
        'mutable_recipe_version',
        'Consumption snapshots require a published or archived recipe version.',
      );
    }
  }

  Future<void> _validateThaliOwnership(String thaliId, String userId) async {
    final thali = await (_db.select(
      _db.nutritionThalis,
    )..where((table) => table.id.equals(thaliId))).getSingleOrNull();
    if (thali == null) {
      _invalid('missing_thali', 'Thali $thaliId was not found.');
    }
    if (thali.userId != userId) {
      _invalid('thali_ownership', 'Thali is not owned by the requesting user.');
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
      if (item.evidence.containsKey('measure')) {
        final rawMeasure = item.evidence['measure'];
        if (rawMeasure is! Map) {
          _invalid(
            'invalid_measure_evidence',
            'Measure evidence must be a structured object.',
          );
        }
        final measure = Map<String, dynamic>.from(rawMeasure);
        final measureId = measure['measure_id'] ?? measure['id'];
        if (measureId != null) {
          if (measureId is! String || measureId.trim().isEmpty) {
            _invalid(
              'invalid_measure_evidence',
              'A measure identity must be a non-blank portable ID.',
            );
          }
          final row = await (_db.select(
            _db.nutritionHouseholdMeasures,
          )..where((table) => table.id.equals(measureId))).getSingleOrNull();
          if (row == null) {
            _invalid(
              'missing_measure_definition',
              'Measure $measureId was not found.',
            );
          }
          final definitionVersion = measure['definition_version'];
          if (definitionVersion != null &&
              (definitionVersion is! int || definitionVersion != row.version)) {
            _invalid(
              'measure_definition_version_mismatch',
              'Snapshot measure evidence does not match the stored definition version.',
            );
          }
        }
        final calibrationId = measure['calibration_id'];
        if (calibrationId != null) {
          if (calibrationId is! String || calibrationId.trim().isEmpty) {
            _invalid(
              'invalid_measure_evidence',
              'A calibration identity must be a non-blank portable ID.',
            );
          }
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
          if (expectedVersion is! int ||
              expectedVersion != calibration.version) {
            _invalid(
              'calibration_version_mismatch',
              'Snapshot calibration evidence does not match the stored version.',
            );
          }
        }
      }
      if (item.evidence.containsKey('transformation')) {
        final rawTransformation = item.evidence['transformation'];
        if (rawTransformation is! Map) {
          _invalid(
            'invalid_transformation_evidence',
            'Transformation evidence must be a structured object.',
          );
        }
        final transformation = Map<String, dynamic>.from(rawTransformation);
        final transformationId = transformation['id'];
        if (transformationId != null &&
            (transformationId is! String || transformationId.trim().isEmpty)) {
          _invalid(
            'invalid_transformation_evidence',
            'A transformation identity must be a non-blank portable ID.',
          );
        }
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
          if (row.foodId != item.foodId ||
              row.preparationId != item.preparationId) {
            _invalid(
              'transformation_identity_mismatch',
              'Transformation evidence does not belong to the consumed food and preparation.',
            );
          }
          final expectedVersion =
              transformation['rule_version'] ?? transformation['version'];
          if (expectedVersion is! String ||
              expectedVersion.trim().isEmpty ||
              expectedVersion != row.ruleVersion) {
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

  Future<NutritionConsumptionSnapshot?> _findByCorrectionId(
    String userId,
    String correctionId,
  ) async {
    final rows = await (_db.select(
      _db.nutritionConsumptionSnapshots,
    )..where((table) => table.userId.equals(userId))).get();
    for (final row in rows) {
      final raw = row.lineage;
      if (raw == null) continue;
      final lineage = _parsePersistedLineage(raw);
      if (lineage.correctionId == correctionId) {
        return _readSnapshot(row.id, userId);
      }
    }
    return null;
  }

  Future<bool> _hasSuccessor(String userId, String predecessorId) async {
    final rows = await (_db.select(
      _db.nutritionConsumptionSnapshots,
    )..where((table) => table.userId.equals(userId))).get();
    for (final row in rows) {
      final raw = row.lineage;
      if (raw == null) continue;
      final lineage = _parsePersistedLineage(raw);
      if (lineage.supersedesSnapshotId == predecessorId) return true;
    }
    return false;
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
      final lineage = _parsePersistedLineage(raw);
      if (lineage.commandId == commandId) {
        return _readSnapshot(row.id, userId);
      }
    }
    return null;
  }

  NutritionConsumptionLineage _parsePersistedLineage(String raw) {
    try {
      return NutritionConsumptionLineage.fromJson(jsonDecode(raw));
    } catch (error) {
      throw NutritionConsumptionPersistenceError(
        'invalid_persisted_lineage',
        'A persisted snapshot lineage envelope is malformed.',
        cause: error,
      );
    }
  }

  dynamic _readPersistedJson(String raw, String kind, String ownerId) {
    try {
      return jsonDecode(raw);
    } catch (error) {
      throw NutritionConsumptionPersistenceError(
        'invalid_${kind}_lineage',
        'Persisted $kind lineage for $ownerId is not valid JSON.',
        cause: error,
      );
    }
  }

  NutrientFact _readPersistedFact(Object? raw, String itemId) {
    try {
      return NutrientFact.fromJson(raw, _registry);
    } catch (error) {
      throw NutritionConsumptionPersistenceError(
        'invalid_nutrient_lineage',
        'Persisted nutrient evidence for item $itemId is malformed.',
        cause: error,
      );
    }
  }

  Quantity _readPersistedQuantity(Object? raw, String itemId) {
    try {
      if (raw is! Map) {
        throw const FormatException('quantity must be an object');
      }
      return Quantity.fromJson(Map<String, dynamic>.from(raw));
    } catch (error) {
      throw NutritionConsumptionPersistenceError(
        'invalid_snapshot_quantity',
        'Persisted quantity evidence for item $itemId is malformed.',
        cause: error,
      );
    }
  }

  String? _optionalLineageString(Map raw, String key) {
    final value = raw[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw NutritionConsumptionPersistenceError(
        'invalid_snapshot_lineage',
        'Persisted snapshot lineage field $key is malformed.',
      );
    }
    return value;
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
    final lineage = _parsePersistedLineage(lineageRaw);
    final constraintEvaluation = _readPersistedConstraintEvaluation(lineage);
    final constraintAcknowledgement = _readPersistedConstraintAcknowledgement(
      lineage,
    );
    if (lineage.evidence['totals'] is! Map) {
      throw const NutritionConsumptionPersistenceError(
        'missing_snapshot_totals',
        'Snapshot lineage must preserve the calculated result evidence.',
      );
    }
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
    final itemIds = itemRows.map((row) => row.id).toSet();
    if (itemIds.length != itemRows.length) {
      throw const NutritionConsumptionPersistenceError(
        'duplicate_consumed_item_id',
        'Persisted snapshot item IDs must be unique.',
      );
    }
    final positions = itemRows.map((row) => row.position).toList()..sort();
    if (!_sameInts(positions, List<int>.generate(itemRows.length, (i) => i))) {
      throw const NutritionConsumptionPersistenceError(
        'invalid_item_position',
        'Persisted snapshot item positions must be contiguous from zero.',
      );
    }
    final evidenceItemKeys = evidenceItems.keys.toList(growable: false);
    if (evidenceItemKeys.any((key) => key is! String) ||
        evidenceItemKeys.length != itemIds.length ||
        !itemIds.containsAll(evidenceItemKeys.cast<String>())) {
      throw const NutritionConsumptionPersistenceError(
        'snapshot_item_lineage_mismatch',
        'Snapshot item lineage contains a different item set than the graph.',
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
    final calculationFingerprintByItem = <String, String>{};
    for (final row in nutrientRows) {
      final itemId = row.itemId;
      if (itemId == null) {
        throw const NutritionConsumptionPersistenceError(
          'invalid_nutrient_owner',
          'Snapshot nutrient rows must belong to an item.',
        );
      }
      if (!itemIds.contains(itemId)) {
        throw const NutritionConsumptionPersistenceError(
          'cross_snapshot_nutrient_owner',
          'Snapshot nutrient rows must belong to an item in this snapshot.',
        );
      }
      final raw = row.lineage;
      if (raw == null) {
        throw const NutritionConsumptionPersistenceError(
          'missing_nutrient_lineage',
          'Snapshot nutrient rows must preserve exact nutrient facts.',
        );
      }
      final factEnvelope = _readPersistedJson(raw, 'nutrient', itemId);
      if (factEnvelope is! Map ||
          factEnvelope['fact'] == null ||
          factEnvelope['item_id'] != itemId ||
          factEnvelope['calculation_fingerprint'] is! String ||
          (factEnvelope['calculation_fingerprint'] as String).trim().isEmpty) {
        throw const NutritionConsumptionPersistenceError(
          'invalid_nutrient_lineage',
          'Snapshot nutrient lineage is malformed.',
        );
      }
      final fact = _readPersistedFact(factEnvelope['fact'], itemId);
      if (row.nutrientId != fact.nutrientId ||
          row.status != fact.status.stableId ||
          row.unit != fact.unit.stableId ||
          row.factVersion != fact.factVersion ||
          row.basis != fact.basis.kind.stableId ||
          !_persistedAmountMatches(fact.point, row.amount) ||
          !_persistedAmountMatches(fact.lower, row.lower) ||
          !_persistedAmountMatches(fact.upper, row.upper)) {
        throw const NutritionConsumptionPersistenceError(
          'nutrient_row_mismatch',
          'Snapshot nutrient projection disagrees with its immutable fact.',
        );
      }
      final itemFacts = factsByItem.putIfAbsent(itemId, () => {});
      if (itemFacts.containsKey(fact.nutrientId)) {
        throw const NutritionConsumptionPersistenceError(
          'duplicate_snapshot_nutrient',
          'A snapshot item cannot contain duplicate nutrient rows.',
        );
      }
      itemFacts[fact.nutrientId] = fact;
      final fingerprint = factEnvelope['calculation_fingerprint'] as String;
      final previousFingerprint = calculationFingerprintByItem[itemId];
      if (previousFingerprint != null && previousFingerprint != fingerprint) {
        throw const NutritionConsumptionPersistenceError(
          'calculation_lineage_mismatch',
          'Snapshot nutrient rows disagree about the item calculation fingerprint.',
        );
      }
      calculationFingerprintByItem[itemId] = fingerprint;
    }
    for (final itemId in itemIds) {
      if ((factsByItem[itemId] ?? const {}).isEmpty) {
        throw const NutritionConsumptionPersistenceError(
          'missing_snapshot_nutrients',
          'Every persisted snapshot item must preserve nutrient rows.',
        );
      }
    }
    final snapshotItems = <NutritionConsumptionSnapshotItem>[];
    for (final row in itemRows) {
      final raw = evidenceItems[row.id];
      if (raw is! Map ||
          raw['id'] != row.id ||
          raw['position'] != row.position ||
          raw['quantity'] is! Map ||
          raw['calculation'] is! Map ||
          raw['evidence'] is! Map) {
        throw NutritionConsumptionPersistenceError(
          'missing_item_lineage',
          'Snapshot item ${row.id} has incomplete immutable evidence.',
        );
      }
      final quantity = _readPersistedQuantity(raw['quantity'], row.id);
      final calculationFingerprint = _validatePersistedCalculation(
        raw['calculation'],
        itemId: row.id,
        headerCalculatorVersion: header.calculatorVersion,
        persistedFacts: factsByItem[row.id]!,
      );
      if (calculationFingerprintByItem[row.id] != calculationFingerprint) {
        throw NutritionConsumptionPersistenceError(
          'calculation_lineage_mismatch',
          'Snapshot item ${row.id} has inconsistent calculation lineage.',
        );
      }
      if (row.quantityValue != _quantityProjection(quantity.amount) ||
          row.quantityDimension != _dimensionId(quantity.dimension) ||
          row.quantityUnit != _databaseUnitId(quantity.unit) ||
          row.quantityContextId != _quantityContextId(quantity) ||
          row.basis != 'absolute' ||
          row.calculationVersion != header.calculatorVersion ||
          row.foodId != _optionalLineageString(raw, 'food_id') ||
          row.recipeVersionId !=
              _optionalLineageString(raw, 'recipe_version_id') ||
          row.preparationId != _optionalLineageString(raw, 'preparation_id') ||
          row.sourceRef != _optionalLineageString(raw, 'source_reference')) {
        throw NutritionConsumptionPersistenceError(
          'snapshot_projection_mismatch',
          'Snapshot item projection disagrees with its immutable lineage.',
        );
      }
      snapshotItems.add(
        NutritionConsumptionSnapshotItem(
          id: row.id,
          position: row.position,
          sourceType:
              _optionalLineageString(raw, 'source_type') ?? header.sourceType,
          foodId: row.foodId,
          recipeVersionId: row.recipeVersionId,
          preparationId: row.preparationId,
          sourceReference: _optionalLineageString(raw, 'source_reference'),
          displayLabel: _optionalLineageString(raw, 'display_label'),
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
    final expectedCompleteness = _readCompleteness(lineage);
    if (!_sameCompleteness(expectedCompleteness, totals.completeness) ||
        header.completeness != totals.completeness.state.name ||
        header.estimateStatus != _estimateStatus(totals.facts) ||
        lineage.evidence['calculator_version'] != header.calculatorVersion ||
        lineage.evidence['nutrient_registry_version'] != _registry.version) {
      throw const NutritionConsumptionPersistenceError(
        'snapshot_result_mismatch',
        'Snapshot header, lineage, and nutrient rows disagree.',
      );
    }
    _validatePersistedTotals(lineage.evidence['totals'], totals);
    final itemRecipeIds = itemRows
        .map((row) => row.recipeVersionId)
        .whereType<String>()
        .toSet();
    final derivedRecipeId = itemRecipeIds.length == 1
        ? itemRecipeIds.single
        : null;
    if (itemRecipeIds.length > 1 || header.recipeVersionId != derivedRecipeId) {
      throw const NutritionConsumptionPersistenceError(
        'recipe_version_mismatch',
        'Snapshot header and item recipe ancestry disagree.',
      );
    }
    await _validatePersistedConstraintRows(
      snapshotId: id,
      userId: userId,
      evaluation: constraintEvaluation,
      acknowledgement: constraintAcknowledgement,
      itemRows: itemRows,
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
      constraintEvaluation: constraintEvaluation,
      constraintAcknowledgement: constraintAcknowledgement,
    );
  }

  NutritionConstraintEvaluationResult? _readPersistedConstraintEvaluation(
    NutritionConsumptionLineage lineage,
  ) {
    final raw = lineage.evidence['constraint_evaluation'];
    if (raw == null) return null;
    try {
      return NutritionConstraintEvaluationResult.fromJson(raw);
    } catch (error) {
      throw NutritionConsumptionPersistenceError(
        'invalid_constraint_evaluation_lineage',
        'Persisted dietary evaluation lineage is malformed.',
        cause: error,
      );
    }
  }

  NutritionConstraintAcknowledgement? _readPersistedConstraintAcknowledgement(
    NutritionConsumptionLineage lineage,
  ) {
    final raw = lineage.evidence['constraint_acknowledgement'];
    if (raw == null) return null;
    try {
      return NutritionConstraintAcknowledgement.fromJson(raw);
    } catch (error) {
      throw NutritionConsumptionPersistenceError(
        'invalid_constraint_acknowledgement_lineage',
        'Persisted dietary acknowledgement lineage is malformed.',
        cause: error,
      );
    }
  }

  Future<void> _validatePersistedConstraintRows({
    required String snapshotId,
    required String userId,
    required NutritionConstraintEvaluationResult? evaluation,
    required NutritionConstraintAcknowledgement? acknowledgement,
    required List<NutritionSnapshotItem> itemRows,
  }) async {
    final resultRows = await (_db.select(
      _db.nutritionSnapshotConstraintResults,
    )..where((table) => table.snapshotId.equals(snapshotId))).get();
    final evidenceRows = resultRows.isEmpty
        ? <NutritionSnapshotConstraintResultEvidenceData>[]
        : await (_db.select(_db.nutritionSnapshotConstraintResultEvidence)
                ..where(
                  (table) => table.resultId.isIn(
                    resultRows.map((row) => row.id).toList(),
                  ),
                ))
              .get();
    if (evaluation == null) {
      if (resultRows.isNotEmpty || evidenceRows.isNotEmpty) {
        throw const NutritionConsumptionPersistenceError(
          'orphan_constraint_graph',
          'Snapshot constraint rows exist without their immutable evaluation lineage.',
        );
      }
      return;
    }
    final expected = {
      for (final item in evaluation.evaluations) item.constraintId: item,
    };
    if (resultRows.length != expected.length ||
        resultRows.any((row) => !expected.containsKey(row.constraintId))) {
      throw const NutritionConsumptionPersistenceError(
        'constraint_result_mismatch',
        'Snapshot constraint result rows disagree with their immutable lineage.',
      );
    }
    final itemIds = itemRows.map((row) => row.id).toSet();
    final evidenceById = {for (final row in evidenceRows) row.id: row};
    for (final row in resultRows) {
      final item = expected[row.constraintId]!;
      if (row.result != item.outcome.stableId ||
          row.ruleVersion != evaluation.ruleVersion ||
          row.evaluatedAt.toUtc() != evaluation.evaluatedAtUtc) {
        throw const NutritionConsumptionPersistenceError(
          'constraint_result_mismatch',
          'Snapshot constraint result projection disagrees with its lineage.',
        );
      }
      final owner = await (_db.select(
        _db.nutritionUserConstraints,
      )..where((table) => table.id.equals(row.constraintId))).getSingleOrNull();
      if (owner == null || owner.userId != userId) {
        throw const NutritionConsumptionPersistenceError(
          'constraint_result_owner',
          'Snapshot constraint result is not owned by the snapshot user.',
        );
      }
      final expectedEvidence = <String, NutritionConstraintEvidenceReference>{
        for (final reference in item.evidence)
          '${row.id}::evidence::${item.evidence.indexOf(reference)}::${reference.evidenceId}':
              reference,
      };
      for (final entry in expectedEvidence.entries) {
        final persisted = evidenceById[entry.key];
        final reference = entry.value;
        final isRecipe = evaluation.recipeVersionId != null;
        final expectedFoodId = reference.foodId ?? evaluation.foodId;
        if (persisted == null ||
            persisted.status != reference.status.stableId ||
            persisted.source != reference.source.stableId ||
            persisted.version != reference.version.toString() ||
            (isRecipe
                ? persisted.foodId != null ||
                      persisted.snapshotItemId == null ||
                      !itemIds.contains(persisted.snapshotItemId)
                : persisted.foodId != expectedFoodId ||
                      persisted.snapshotItemId != null)) {
          throw const NutritionConsumptionPersistenceError(
            'constraint_evidence_mismatch',
            'Snapshot constraint evidence does not match its immutable lineage.',
          );
        }
      }
      if (acknowledgement != null &&
          acknowledgement.constraintId == row.constraintId) {
        final ackId =
            '${row.id}::acknowledgement::${acknowledgement.commandId}';
        final persisted = evidenceById[ackId];
        if (persisted == null ||
            persisted.evidenceKind != 'user_override' ||
            persisted.snapshotItemId == null ||
            !itemIds.contains(persisted.snapshotItemId)) {
          throw const NutritionConsumptionPersistenceError(
            'constraint_acknowledgement_mismatch',
            'Snapshot constraint acknowledgement does not match its lineage.',
          );
        }
      }
    }
    final expectedEvidenceCount = evaluation.evaluations.fold<int>(
      0,
      (count, item) =>
          count +
          item.evidence.length +
          (acknowledgement?.constraintId == item.constraintId ? 1 : 0),
    );
    if (evidenceRows.length != expectedEvidenceCount) {
      throw const NutritionConsumptionPersistenceError(
        'constraint_evidence_mismatch',
        'Snapshot constraint evidence contains extra or missing rows.',
      );
    }
  }

  NutrientCompleteness _readCompleteness(NutritionConsumptionLineage lineage) {
    final raw = lineage.evidence['completeness'];
    if (raw is! Map) {
      throw const NutritionConsumptionPersistenceError(
        'missing_completeness',
        'Snapshot completeness evidence is missing.',
      );
    }
    try {
      return NutrientCompleteness.fromJson(raw);
    } catch (error) {
      throw NutritionConsumptionPersistenceError(
        'invalid_completeness',
        'Snapshot completeness evidence is malformed.',
        cause: error,
      );
    }
  }

  String _validatePersistedCalculation(
    Object? raw, {
    required String itemId,
    required String headerCalculatorVersion,
    required Map<String, NutrientFact> persistedFacts,
  }) {
    if (raw is! Map ||
        raw['calculator_version'] is! String ||
        (raw['calculator_version'] as String).trim().isEmpty ||
        raw['nutrient_registry_version'] is! int ||
        raw['calculation_fingerprint'] is! String ||
        (raw['calculation_fingerprint'] as String).trim().isEmpty ||
        raw['facts'] is! Map ||
        raw['completeness'] is! Map ||
        raw['lineage'] is! Map) {
      throw NutritionConsumptionPersistenceError(
        'invalid_calculation_lineage',
        'Persisted calculation evidence for item $itemId is malformed.',
      );
    }
    final calculatorVersion = raw['calculator_version'] as String;
    if (calculatorVersion != headerCalculatorVersion ||
        raw['nutrient_registry_version'] != _registry.version) {
      throw NutritionConsumptionPersistenceError(
        'invalid_calculation_lineage',
        'Persisted calculation evidence for item $itemId uses an unsupported version.',
      );
    }
    try {
      NutrientCompleteness.fromJson(raw['completeness']);
    } catch (error) {
      throw NutritionConsumptionPersistenceError(
        'invalid_calculation_lineage',
        'Persisted completeness evidence for item $itemId is malformed.',
        cause: error,
      );
    }
    final rawFacts = raw['facts'] as Map;
    final rawFactKeys = rawFacts.keys.toList(growable: false);
    if (rawFactKeys.any((key) => key is! String)) {
      throw NutritionConsumptionPersistenceError(
        'invalid_calculation_lineage',
        'Persisted calculation facts for item $itemId have invalid IDs.',
      );
    }
    final rawFactKeySet = rawFactKeys.cast<String>().toSet();
    final persistedFactKeySet = persistedFacts.keys.toSet();
    if (rawFactKeySet.length != persistedFactKeySet.length ||
        !rawFactKeySet.containsAll(persistedFactKeySet)) {
      throw NutritionConsumptionPersistenceError(
        'calculation_lineage_mismatch',
        'Persisted calculation facts for item $itemId do not match its nutrient rows.',
      );
    }
    late final NutrientCompleteness calculationCompleteness;
    for (final key in rawFactKeys.cast<String>()) {
      final fact = _readPersistedFact(rawFacts[key], itemId);
      if (fact.nutrientId != key ||
          fact.basis.kind != NutrientBasisKind.absolute ||
          !_sameFact(fact, persistedFacts[key])) {
        throw NutritionConsumptionPersistenceError(
          'calculation_lineage_mismatch',
          'Persisted calculation facts for item $itemId disagree with nutrient rows.',
        );
      }
    }
    try {
      calculationCompleteness = NutrientCompleteness.fromJson(
        raw['completeness'],
      );
    } catch (error) {
      throw NutritionConsumptionPersistenceError(
        'invalid_calculation_lineage',
        'Persisted completeness evidence for item $itemId is malformed.',
        cause: error,
      );
    }
    final expectedCompleteness = NutrientCompletenessEvaluator.evaluate(
      registry: _registry,
      facts: persistedFacts,
      requestedNutrientIds: calculationCompleteness.requestedNutrientIds
          .toSet(),
    );
    if (!_sameCompleteness(calculationCompleteness, expectedCompleteness)) {
      throw NutritionConsumptionPersistenceError(
        'calculation_lineage_mismatch',
        'Persisted completeness evidence for item $itemId disagrees with its nutrient facts.',
      );
    }
    return raw['calculation_fingerprint'] as String;
  }

  void _validatePersistedTotals(
    Object? raw,
    NutrientAggregationResult expected,
  ) {
    if (raw is! Map || raw['facts'] is! Map) {
      throw const NutritionConsumptionPersistenceError(
        'invalid_snapshot_totals',
        'Persisted snapshot totals are malformed.',
      );
    }
    final rawFacts = raw['facts'] as Map;
    final keys = rawFacts.keys.toList(growable: false);
    if (keys.any((key) => key is! String) ||
        keys.length != expected.facts.length ||
        !expected.facts.keys.toSet().containsAll(keys.cast<String>())) {
      throw const NutritionConsumptionPersistenceError(
        'snapshot_result_mismatch',
        'Persisted snapshot totals contain a different nutrient set.',
      );
    }
    for (final key in keys.cast<String>()) {
      final fact = _readPersistedFact(rawFacts[key], 'totals');
      if (fact.basis.kind != NutrientBasisKind.absolute ||
          !_sameFact(fact, expected.facts[key])) {
        throw const NutritionConsumptionPersistenceError(
          'snapshot_result_mismatch',
          'Persisted snapshot totals disagree with nutrient rows.',
        );
      }
    }
  }

  static bool _sameCompleteness(
    NutrientCompleteness left,
    NutrientCompleteness right,
  ) =>
      left.state == right.state &&
      _sameStrings(left.requestedNutrientIds, right.requestedNutrientIds) &&
      _sameStrings(left.availableNutrientIds, right.availableNutrientIds) &&
      _sameStrings(left.missingNutrientIds, right.missingNutrientIds) &&
      _sameStrings(left.estimatedNutrientIds, right.estimatedNutrientIds) &&
      _sameStrings(
        left.notApplicableNutrientIds,
        right.notApplicableNutrientIds,
      ) &&
      _sameStrings(
        left.partiallyKnownNutrientIds,
        right.partiallyKnownNutrientIds,
      );

  static bool _sameStrings(Iterable<String> left, Iterable<String> right) {
    final leftList = left.toList();
    final rightList = right.toList();
    if (leftList.length != rightList.length) return false;
    for (var index = 0; index < leftList.length; index++) {
      if (leftList[index] != rightList[index]) return false;
    }
    return true;
  }

  static bool _sameFact(NutrientFact? left, NutrientFact? right) {
    if (left == null || right == null) return left == right;
    return jsonEncode(_canonicalSnapshotJson(left.toJson())) ==
        jsonEncode(_canonicalSnapshotJson(right.toJson()));
  }

  static bool _persistedAmountMatches(
    NutrientAmount? amount,
    double? persisted,
  ) {
    if (amount == null) return persisted == null;
    if (persisted == null || !persisted.isFinite) return false;
    return double.parse(amount.value.toString()) == persisted;
  }

  static double _quantityProjection(QuantityAmount amount) =>
      double.parse(amount.toString());

  String _resolvedConsumptionId(NutritionConsumptionFinalizeRequest request) {
    final supplied = request.consumptionId?.trim();
    if (supplied != null && supplied.isNotEmpty) return supplied;
    final command = request.commandId?.trim();
    if (command != null && command.isNotEmpty) {
      final key = jsonEncode([request.userId.trim(), command]);
      final digest = sha256.convert(utf8.encode(key)).toString();
      return 'consumption-${digest.substring(0, 32)}';
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

  static double _asDouble(QuantityAmount amount) {
    final value = double.parse(amount.toString());
    if (!value.isFinite || !_roundTripsExactly(amount, value)) {
      throw const NutritionConsumptionValidationError(
        'precision_overflow',
        'A persisted quantity cannot be represented exactly by the database numeric projection.',
      );
    }
    return value;
  }

  static double? _asNullableDouble(NutrientAmount? amount) {
    if (amount == null) return null;
    final value = double.parse(amount.value.toString());
    if (!value.isFinite || !_roundTripsExactly(amount.value, value)) {
      throw const NutritionConsumptionValidationError(
        'precision_overflow',
        'A persisted nutrient value cannot be represented exactly by the database numeric projection.',
      );
    }
    return value;
  }

  static bool _roundTripsExactly(QuantityAmount amount, double value) {
    try {
      return QuantityAmount.fromNum(value) == amount;
    } on QuantityError {
      return false;
    }
  }

  static String? _quantityContextId(Quantity quantity) {
    final context = quantity.context;
    return context.householdMeasure?.calibrationId ??
        context.conversion?.vesselCalibrationId ??
        context.conversion?.yieldTransformationId ??
        context.conversion?.servingDefinitionId ??
        context.servingDefinition?.id;
  }

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
  final Map<String, dynamic> calculationLineage;

  const _PreparedItem({
    required this.input,
    required this.facts,
    required this.calculationLineage,
  });

  Map<String, dynamic> toLineageJson() => {
    ...input.toLineageJson(),
    'calculation': calculationLineage,
  };
}

class _PreparedConsumption {
  final List<_PreparedItem> items;
  final NutrientAggregationResult totals;
  final String? recipeVersionId;
  final String contentFingerprint;
  final Map<String, dynamic> lineageEvidence;
  final NutritionConstraintEvaluationResult? constraintEvaluation;
  final NutritionConstraintAcknowledgement? constraintAcknowledgement;

  const _PreparedConsumption({
    required this.items,
    required this.totals,
    required this.recipeVersionId,
    required this.contentFingerprint,
    required this.lineageEvidence,
    required this.constraintEvaluation,
    required this.constraintAcknowledgement,
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

dynamic _canonicalSnapshotJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalSnapshotJson(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalSnapshotJson).toList(growable: false);
  }
  return value;
}
