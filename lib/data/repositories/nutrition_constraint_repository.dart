import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrition_constraints.dart';
import '../database/app_database.dart' as db;

/// A display-ready, read-only choice for the dietary-preferences picker.
///
/// The target remains the B03 portable identity. The label is deliberately
/// kept separate so presentation never asks a person to type that identity.
class NutritionConstraintTargetOption {
  const NutritionConstraintTargetOption({
    required this.target,
    required this.displayLabel,
  });

  final NutritionConstraintTarget target;
  final String displayLabel;
}

/// The sole durable owner for B03-16 taxonomy-backed user constraints and
/// food evidence. Evaluation itself is delegated to the pure evaluator and
/// never mutates the database.
class NutritionConstraintRepository {
  final db.AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;
  final NutritionConstraintEvaluator _evaluator;

  NutritionConstraintRepository({
    required db.AppDatabase database,
    Uuid? uuid,
    DateTime Function()? nowUtc,
    NutritionConstraintEvaluator evaluator =
        const NutritionConstraintEvaluator(),
  }) : _db = database,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _evaluator = evaluator;

  Future<List<NutritionConstraintDefinition>> listTaxonomy() async {
    await _ensureTaxonomy();
    final rows =
        await (_db.select(_db.nutritionConstraintDefinitions)..orderBy([
              (table) => OrderingTerm(expression: table.type),
              (table) => OrderingTerm(expression: table.id),
            ]))
            .get();
    return List.unmodifiable([for (final row in rows) _definitionFromRow(row)]);
  }

  Future<NutritionConstraintDefinition> getDefinition(
    String definitionId,
  ) async {
    await _ensureTaxonomy();
    final row = await (_db.select(
      _db.nutritionConstraintDefinitions,
    )..where((table) => table.id.equals(definitionId))).getSingleOrNull();
    if (row == null) {
      throw NutritionConstraintNotFoundError(
        'constraint_definition_not_found',
        'The selected dietary constraint type is not available.',
      );
    }
    return _definitionFromRow(row);
  }

  Future<List<NutritionUserConstraint>> listActiveConstraints({
    required String userId,
    DateTime? atUtc,
  }) async {
    final owner = _requiredOwner(userId);
    await _ensureTaxonomy();
    final rows =
        await (_db.select(_db.nutritionUserConstraints)
              ..where((table) => table.userId.equals(owner))
              ..orderBy([
                (table) => OrderingTerm(expression: table.effectiveFrom),
                (table) => OrderingTerm(expression: table.id),
              ]))
            .get();
    final at = (atUtc ?? _nowUtc()).toUtc();
    return List.unmodifiable([
      for (final row in rows)
        if (_decodeUserConstraint(row).isEffectiveAt(at))
          _decodeUserConstraint(row),
    ]);
  }

  Future<List<NutritionUserConstraint>> listAllConstraints({
    required String userId,
  }) async {
    final owner = _requiredOwner(userId);
    await _ensureTaxonomy();
    final rows =
        await (_db.select(_db.nutritionUserConstraints)
              ..where((table) => table.userId.equals(owner))
              ..orderBy([
                (table) => OrderingTerm(expression: table.updatedAt),
                (table) => OrderingTerm(expression: table.id),
              ]))
            .get();
    return List.unmodifiable([
      for (final row in rows) _decodeUserConstraint(row),
    ]);
  }

  Future<NutritionUserConstraint> createConstraint(
    NutritionUserConstraint constraint,
  ) async {
    constraint.validate();
    await _ensureTaxonomy();
    await _validateDefinitionRow(constraint.definitionId, constraint.type);
    await _validateUserTargetReference(
      type: constraint.type,
      target: constraint.target,
    );
    return _db.transaction(() async {
      final sameId = await (_db.select(
        _db.nutritionUserConstraints,
      )..where((table) => table.id.equals(constraint.id))).getSingleOrNull();
      if (sameId != null) {
        throw const NutritionConstraintConflictError(
          'duplicate_constraint_id',
          'A user constraint with this portable ID already exists.',
        );
      }
      final existing =
          await (_db.select(_db.nutritionUserConstraints)..where(
                (table) =>
                    table.userId.equals(constraint.userId) &
                    table.definitionId.equals(constraint.definitionId),
              ))
              .get();
      for (final row in existing) {
        final decoded = _decodeUserConstraint(row);
        if (decoded.isActive && decoded.targetKey == constraint.targetKey) {
          throw const NutritionConstraintConflictError(
            'duplicate_active_constraint',
            'The same active dietary constraint is already recorded.',
          );
        }
      }
      final now = _nowUtc().toUtc();
      await _db
          .into(_db.nutritionUserConstraints)
          .insert(
            db.NutritionUserConstraintsCompanion.insert(
              id: constraint.id,
              userId: constraint.userId,
              definitionId: constraint.definitionId,
              value: constraint.encodeValue(),
              strictness: constraint.strictness.stableId,
              severity: Value(constraint.severity),
              crossContact: Value(constraint.crossContact),
              effectiveFrom: constraint.effectiveFrom,
              effectiveTo: Value(constraint.effectiveTo),
              source: constraint.source.stableId,
              notes: Value(constraint.notes),
              createdAt: Value(constraint.createdAtUtc),
              updatedAt: Value(now),
            ),
          );
      return constraint.copyWith(updatedAtUtc: now);
    });
  }

  /// Searches only existing, active B03 food or preparation identities for
  /// the consumer picker. This read does not create a food, infer an alias,
  /// or alter dietary rules.
  Future<List<NutritionConstraintTargetOption>> searchTargetOptions({
    required NutritionConstraintTargetType type,
    String query = '',
    int limit = 30,
  }) async {
    if (limit <= 0) return const [];
    final normalized = query.trim().toLowerCase();
    if (type == NutritionConstraintTargetType.food ||
        type == NutritionConstraintTargetType.ingredient) {
      final rows =
          await (_db.select(_db.nutritionFoods)
                ..where(
                  (table) =>
                      table.lifecycle.equals('active') &
                      (normalized.isEmpty
                          ? const Constant(true)
                          : table.displayName.lower().contains(normalized)),
                )
                ..orderBy([
                  (table) => OrderingTerm(expression: table.displayName),
                ])
                ..limit(limit))
              .get();
      return List.unmodifiable(_foodTargetOptions(type: type, rows: rows));
    }
    if (type == NutritionConstraintTargetType.preparation) {
      final foods = await (_db.select(
        _db.nutritionFoods,
      )..where((table) => table.lifecycle.equals('active'))).get();
      final foodById = {for (final food in foods) food.id: food};
      final preparations = await _db
          .select(_db.nutritionFoodPreparations)
          .get();
      final options = <NutritionConstraintTargetOption>[];
      for (final preparation in preparations) {
        final food = foodById[preparation.foodId];
        if (food == null) continue;
        final stateLabel = switch (preparation.state) {
          'raw' => 'Raw',
          'cooked' => 'Cooked',
          _ => 'Prepared',
        };
        final label = '${food.displayName} · $stateLabel';
        if (normalized.isNotEmpty &&
            !label.toLowerCase().contains(normalized)) {
          continue;
        }
        try {
          options.add(
            NutritionConstraintTargetOption(
              target: NutritionConstraintTarget(type: type, id: preparation.id),
              displayLabel: label,
            ),
          );
        } on NutritionConstraintError {
          // Legacy IDs can be intentionally non-portable. They are not safe
          // targets for a new consumer preference, so omit them from choices.
        }
        if (options.length == limit) break;
      }
      options.sort(
        (left, right) => left.displayLabel.toLowerCase().compareTo(
          right.displayLabel.toLowerCase(),
        ),
      );
      return List.unmodifiable(options);
    }
    return const [];
  }

  /// Resolves an existing B03 target to its consumer-facing catalogue label.
  ///
  /// This is intentionally read-only: a missing or legacy identity remains
  /// unresolved rather than being recreated or inferred for presentation.
  Future<String?> targetDisplayLabel(NutritionConstraintTarget target) async {
    if (target.type == NutritionConstraintTargetType.food ||
        target.type == NutritionConstraintTargetType.ingredient) {
      final food = await (_db.select(
        _db.nutritionFoods,
      )..where((table) => table.id.equals(target.id))).getSingleOrNull();
      return food?.displayName;
    }
    if (target.type == NutritionConstraintTargetType.preparation) {
      final preparation = await (_db.select(
        _db.nutritionFoodPreparations,
      )..where((table) => table.id.equals(target.id))).getSingleOrNull();
      if (preparation == null) return null;
      final food =
          await (_db.select(_db.nutritionFoods)
                ..where((table) => table.id.equals(preparation.foodId)))
              .getSingleOrNull();
      if (food == null) return null;
      final stateLabel = switch (preparation.state) {
        'raw' => 'Raw',
        'cooked' => 'Cooked',
        _ => 'Prepared',
      };
      return '${food.displayName} · $stateLabel';
    }
    return null;
  }

  List<NutritionConstraintTargetOption> _foodTargetOptions({
    required NutritionConstraintTargetType type,
    required Iterable<db.NutritionFood> rows,
  }) {
    final options = <NutritionConstraintTargetOption>[];
    for (final row in rows) {
      try {
        options.add(
          NutritionConstraintTargetOption(
            target: NutritionConstraintTarget(type: type, id: row.id),
            displayLabel: row.displayName,
          ),
        );
      } on NutritionConstraintError {
        // See the matching preparation note above.
      }
    }
    return options;
  }

  Future<NutritionUserConstraint> createUserConstraint({
    required String userId,
    required NutritionConstraintType type,
    required NutritionConstraintTarget target,
    NutritionConstraintStrictness strictness =
        NutritionConstraintStrictness.avoid,
    String? severity,
    bool crossContact = false,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    NutritionConstraintSource source = NutritionConstraintSource.userEntered,
    String? notes,
    String? id,
  }) async {
    final definition = NutritionConstraintTaxonomy.definitionForType(type);
    final timestamp = (effectiveFrom ?? _nowUtc()).toUtc();
    return createConstraint(
      NutritionUserConstraint(
        id: id ?? _uuid.v4(),
        userId: userId,
        definitionId: definition.id,
        type: type,
        target: target,
        strictness: strictness,
        severity: severity,
        crossContact: crossContact,
        effectiveFrom: timestamp,
        effectiveTo: effectiveTo,
        source: source,
        notes: notes,
        createdAtUtc: timestamp,
        updatedAtUtc: timestamp,
      ),
    );
  }

  Future<NutritionUserConstraint> updateConstraint(
    NutritionUserConstraint constraint,
  ) async {
    constraint.validate();
    await _ensureTaxonomy();
    await _validateDefinitionRow(constraint.definitionId, constraint.type);
    await _validateUserTargetReference(
      type: constraint.type,
      target: constraint.target,
    );
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.nutritionUserConstraints,
      )..where((table) => table.id.equals(constraint.id))).getSingleOrNull();
      if (existing == null || existing.userId != constraint.userId) {
        throw const NutritionConstraintNotFoundError(
          'constraint_not_found',
          'The dietary constraint is not available for this user.',
        );
      }
      final others =
          await (_db.select(_db.nutritionUserConstraints)..where(
                (table) =>
                    table.userId.equals(constraint.userId) &
                    table.definitionId.equals(constraint.definitionId) &
                    table.id.isNotIn([constraint.id]),
              ))
              .get();
      for (final row in others) {
        final decoded = _decodeUserConstraint(row);
        if (decoded.isActive &&
            constraint.isActive &&
            decoded.targetKey == constraint.targetKey) {
          throw const NutritionConstraintConflictError(
            'duplicate_active_constraint',
            'The same active dietary constraint is already recorded.',
          );
        }
      }
      final now = _nowUtc().toUtc();
      await (_db.update(
        _db.nutritionUserConstraints,
      )..where((table) => table.id.equals(constraint.id))).write(
        db.NutritionUserConstraintsCompanion(
          definitionId: Value(constraint.definitionId),
          value: Value(constraint.encodeValue()),
          strictness: Value(constraint.strictness.stableId),
          severity: Value(constraint.severity),
          crossContact: Value(constraint.crossContact),
          effectiveFrom: Value(constraint.effectiveFrom),
          effectiveTo: Value(constraint.effectiveTo),
          source: Value(constraint.source.stableId),
          notes: Value(constraint.notes),
          updatedAt: Value(now),
        ),
      );
      return constraint.copyWith(updatedAtUtc: now);
    });
  }

  Future<NutritionUserConstraint> archiveConstraint({
    required String userId,
    required String constraintId,
  }) async {
    final owner = _requiredOwner(userId);
    final current = await getConstraint(
      userId: owner,
      constraintId: constraintId,
    );
    if (current == null) {
      throw const NutritionConstraintNotFoundError(
        'constraint_not_found',
        'The dietary constraint does not exist for this user.',
      );
    }
    if (!current.isActive) return current;
    return updateConstraint(current.copyWith(isActive: false));
  }

  Future<NutritionUserConstraint?> getConstraint({
    required String userId,
    required String constraintId,
  }) async {
    final owner = _requiredOwner(userId);
    await _ensureTaxonomy();
    final row =
        await (_db.select(_db.nutritionUserConstraints)..where(
              (table) =>
                  table.userId.equals(owner) & table.id.equals(constraintId),
            ))
            .getSingleOrNull();
    return row == null ? null : _decodeUserConstraint(row);
  }

  Future<NutritionConstraintEvidence> recordFoodEvidence({
    required String foodId,
    required NutritionConstraintEvidence evidence,
  }) async {
    final owner = foodId.trim();
    if (owner.isEmpty || evidence.subjectId != owner) {
      throw const NutritionConstraintValidationError(
        'evidence_subject_mismatch',
        'Food evidence must identify the same portable food ID it is stored against.',
      );
    }
    evidence.validate();
    await _validateEvidenceTargetReference(evidence.target);
    final food = await (_db.select(
      _db.nutritionFoods,
    )..where((table) => table.id.equals(owner))).getSingleOrNull();
    if (food == null) {
      throw const NutritionConstraintNotFoundError(
        'food_not_found',
        'The food identity for this evidence is not available.',
      );
    }
    final sameId = await (_db.select(
      _db.nutritionFoodConstraintEvidence,
    )..where((table) => table.id.equals(evidence.id))).getSingleOrNull();
    if (sameId != null) {
      throw const NutritionConstraintConflictError(
        'duplicate_evidence_id',
        'A dietary evidence record with this portable ID already exists.',
      );
    }
    await _db
        .into(_db.nutritionFoodConstraintEvidence)
        .insert(
          db.NutritionFoodConstraintEvidenceCompanion.insert(
            id: evidence.id,
            foodId: owner,
            constraintKey: evidence.target.stableKey,
            status: evidence.status.stableId,
            evidenceSource: evidence.source.stableId,
            confidence: Value(evidence.confidence),
            notes: Value(evidence.encodeStorageNotes()),
            version: evidence.version,
          ),
        );
    return evidence;
  }

  Future<List<NutritionConstraintEvidence>> listFoodEvidence(
    String foodId,
  ) async {
    final owner = foodId.trim();
    if (owner.isEmpty) {
      throw const NutritionConstraintValidationError(
        'invalid_food_id',
        'Food identity is required to read dietary evidence.',
      );
    }
    final rows =
        await (_db.select(_db.nutritionFoodConstraintEvidence)
              ..where((table) => table.foodId.equals(owner))
              ..orderBy([
                (table) => OrderingTerm(expression: table.constraintKey),
                (table) => OrderingTerm(expression: table.version),
                (table) => OrderingTerm(expression: table.id),
              ]))
            .get();
    return List.unmodifiable([for (final row in rows) _evidenceFromRow(row)]);
  }

  Future<NutritionConstraintEvaluationResult> evaluateFood({
    required String userId,
    required String foodId,
    DateTime? atUtc,
    Iterable<String> acknowledgedConstraintIds = const [],
  }) async {
    final owner = _requiredOwner(userId);
    final identity = foodId.trim();
    if (identity.isEmpty) {
      throw const NutritionConstraintValidationError(
        'invalid_food_id',
        'A portable food identity is required for evaluation.',
      );
    }
    final food = await (_db.select(
      _db.nutritionFoods,
    )..where((table) => table.id.equals(identity))).getSingleOrNull();
    if (food == null) {
      throw const NutritionConstraintNotFoundError(
        'food_not_found',
        'The selected food identity is not available.',
      );
    }
    final evaluatedAt = (atUtc ?? _nowUtc()).toUtc();
    final constraints = await listActiveConstraints(
      userId: owner,
      atUtc: evaluatedAt,
    );
    return _evaluator.evaluate(
      subject: NutritionConstraintEvaluationInput(
        userId: owner,
        subjectId: identity,
        foodId: identity,
        evidence: await listFoodEvidence(identity),
        evaluatedAtUtc: evaluatedAt,
      ),
      constraints: constraints,
      acknowledgedConstraintIds: acknowledgedConstraintIds,
    );
  }

  Future<NutritionConstraintEvaluationResult> evaluateRecipeVersion({
    required String userId,
    required String recipeVersionId,
    DateTime? atUtc,
    Iterable<String> acknowledgedConstraintIds = const [],
  }) async {
    final owner = _requiredOwner(userId);
    final versionId = recipeVersionId.trim();
    if (versionId.isEmpty) {
      throw const NutritionConstraintValidationError(
        'invalid_recipe_version_id',
        'An immutable recipe-version identity is required for evaluation.',
      );
    }
    final version = await (_db.select(
      _db.nutritionRecipeVersions,
    )..where((table) => table.id.equals(versionId))).getSingleOrNull();
    if (version == null) {
      throw const NutritionConstraintNotFoundError(
        'recipe_version_not_found',
        'The selected immutable recipe version is not available.',
      );
    }
    if (version.status == 'draft') {
      throw const NutritionConstraintValidationError(
        'draft_recipe_version',
        'Draft recipe versions cannot be evaluated for logging.',
      );
    }
    final ingredients =
        await (_db.select(_db.nutritionRecipeIngredients)
              ..where((table) => table.recipeVersionId.equals(versionId))
              ..orderBy([
                (table) => OrderingTerm(expression: table.position),
                (table) => OrderingTerm(expression: table.id),
              ]))
            .get();
    final evaluatedAt = (atUtc ?? _nowUtc()).toUtc();
    final constraints = await listActiveConstraints(
      userId: owner,
      atUtc: evaluatedAt,
    );
    return _evaluator.evaluate(
      subject: NutritionConstraintEvaluationInput(
        userId: owner,
        subjectId: versionId,
        recipeVersionId: versionId,
        lines: [
          for (final ingredient in ingredients)
            NutritionConstraintSubjectLine(
              id: ingredient.id,
              foodId: ingredient.foodId,
              evidence: [
                for (final item in await listFoodEvidence(ingredient.foodId))
                  item.copyWith(ingredientLineage: ingredient.id),
              ],
            ),
        ],
        evaluatedAtUtc: evaluatedAt,
      ),
      constraints: constraints,
      acknowledgedConstraintIds: acknowledgedConstraintIds,
    );
  }

  /// Evaluates one persisted thali composition through the same pure B03-16
  /// evaluator used by direct foods and immutable recipes. The caller supplies
  /// stable, evidence-bearing component lines; this method only loads the
  /// user's active constraints and performs the deterministic evaluation.
  Future<NutritionConstraintEvaluationResult> evaluateThali({
    required String userId,
    required String thaliId,
    required Iterable<NutritionConstraintSubjectLine> lines,
    DateTime? atUtc,
    Iterable<String> acknowledgedConstraintIds = const [],
  }) async {
    final owner = _requiredOwner(userId);
    final subjectId = thaliId.trim();
    if (subjectId.isEmpty) {
      throw const NutritionConstraintValidationError(
        'invalid_thali_id',
        'A portable thali identity is required for evaluation.',
      );
    }
    final evaluatedAt = (atUtc ?? _nowUtc()).toUtc();
    final constraints = await listActiveConstraints(
      userId: owner,
      atUtc: evaluatedAt,
    );
    return _evaluator.evaluate(
      subject: NutritionConstraintEvaluationInput(
        userId: owner,
        subjectId: subjectId,
        thaliId: subjectId,
        lines: lines,
        evaluatedAtUtc: evaluatedAt,
      ),
      constraints: constraints,
      acknowledgedConstraintIds: acknowledgedConstraintIds,
    );
  }

  Future<NutritionConstraintAcknowledgement> recordAcknowledgement(
    NutritionConstraintAcknowledgement acknowledgement, {
    required NutritionConstraintEvaluationResult evaluation,
  }) async {
    if (acknowledgement.userId != evaluation.userId ||
        acknowledgement.evaluationFingerprint != evaluation.fingerprint ||
        !evaluation.evaluations.any(
          (item) =>
              item.constraintId == acknowledgement.constraintId &&
              item.acknowledged,
        )) {
      throw const NutritionConstraintValidationError(
        'invalid_constraint_acknowledgement',
        'Acknowledgement must match an explicitly acknowledged evaluation.',
      );
    }
    final constraint = await getConstraint(
      userId: acknowledgement.userId,
      constraintId: acknowledgement.constraintId,
    );
    if (constraint == null) {
      throw const NutritionConstraintNotFoundError(
        'constraint_not_found',
        'The acknowledged constraint is not available for this user.',
      );
    }
    final existing =
        await (_db.select(_db.nutritionUserCorrections)
              ..where((table) => table.id.equals(acknowledgement.commandId)))
            .getSingleOrNull();
    final encoded = jsonEncode(acknowledgement.toJson());
    if (existing != null) {
      if (existing.userId == acknowledgement.userId &&
          existing.newValue == encoded) {
        return acknowledgement;
      }
      throw const NutritionConstraintConflictError(
        'acknowledgement_id_conflict',
        'The acknowledgement command was already used for another payload.',
      );
    }
    await _db.transaction(
      () => _db
          .into(_db.nutritionUserCorrections)
          .insert(
            db.NutritionUserCorrectionsCompanion.insert(
              id: acknowledgement.commandId,
              userId: acknowledgement.userId,
              targetType: 'nutrition_constraint_evaluation',
              targetId: acknowledgement.evaluationFingerprint,
              field: 'acknowledgement',
              newValue: Value(encoded),
              reason: acknowledgement.reason,
              source: 'user_entered',
              createdAt: Value(acknowledgement.acknowledgedAtUtc),
            ),
          ),
    );
    return acknowledgement;
  }

  Future<void> _ensureTaxonomy() async {
    NutritionConstraintTaxonomy.validateRegistry(
      NutritionConstraintTaxonomy.definitions,
    );
    final expected = {
      for (final definition in NutritionConstraintTaxonomy.definitions)
        definition.id: definition,
    };
    final rows = await _db.select(_db.nutritionConstraintDefinitions).get();
    for (final row in rows) {
      final definition = expected[row.id];
      if (definition == null ||
          row.key != definition.key ||
          row.type != definition.type.stableId ||
          row.version != definition.version) {
        throw const NutritionConstraintValidationError(
          'unsupported_taxonomy_version',
          'The local dietary taxonomy does not match the approved version.',
        );
      }
    }
    final missing = expected.values
        .where((item) => !rows.any((row) => row.id == item.id))
        .toList();
    if (missing.isEmpty) return;
    await _db.transaction(() async {
      await _db.batch((batch) {
        batch.insertAll(_db.nutritionConstraintDefinitions, [
          for (final definition in missing)
            db.NutritionConstraintDefinitionsCompanion.insert(
              id: definition.id,
              key: definition.key,
              type: definition.type.stableId,
              displayName: definition.displayName,
              severitySupported: Value(definition.severitySupported),
              crossContactSupported: Value(definition.crossContactSupported),
              version: definition.version,
            ),
        ]);
      });
    });
  }

  Future<void> _validateUserTargetReference({
    required NutritionConstraintType type,
    required NutritionConstraintTarget target,
  }) async {
    NutritionConstraintTargetCatalog.validateForUserConstraint(
      type: type,
      target: target,
    );
    if (target.type == NutritionConstraintTargetType.food ||
        (target.type == NutritionConstraintTargetType.ingredient &&
            !NutritionConstraintTargetCatalog.isFixedTarget(target))) {
      final row = await (_db.select(
        _db.nutritionFoods,
      )..where((table) => table.id.equals(target.id))).getSingleOrNull();
      if (row == null) {
        throw const NutritionConstraintNotFoundError(
          'constraint_target_not_found',
          'The selected dietary target is not a known portable food identity.',
        );
      }
    } else if (target.type == NutritionConstraintTargetType.preparation) {
      final row = await (_db.select(
        _db.nutritionFoodPreparations,
      )..where((table) => table.id.equals(target.id))).getSingleOrNull();
      if (row == null) {
        throw const NutritionConstraintNotFoundError(
          'constraint_target_not_found',
          'The selected preparation identity is not available.',
        );
      }
    }
  }

  Future<void> _validateEvidenceTargetReference(
    NutritionConstraintTarget target,
  ) async {
    if (target.type == NutritionConstraintTargetType.unknownOrUnsupported ||
        NutritionConstraintTargetCatalog.isFixedTarget(target)) {
      return;
    }
    if (target.type == NutritionConstraintTargetType.food ||
        target.type == NutritionConstraintTargetType.ingredient) {
      final row = await (_db.select(
        _db.nutritionFoods,
      )..where((table) => table.id.equals(target.id))).getSingleOrNull();
      if (row == null) {
        throw const NutritionConstraintNotFoundError(
          'constraint_target_not_found',
          'Evidence references an unavailable portable food identity.',
        );
      }
      return;
    }
    if (target.type == NutritionConstraintTargetType.preparation) {
      final row = await (_db.select(
        _db.nutritionFoodPreparations,
      )..where((table) => table.id.equals(target.id))).getSingleOrNull();
      if (row == null) {
        throw const NutritionConstraintNotFoundError(
          'constraint_target_not_found',
          'Evidence references an unavailable preparation identity.',
        );
      }
      return;
    }
    throw const NutritionConstraintValidationError(
      'unsupported_constraint_target',
      'Evidence references an unsupported dietary target.',
    );
  }

  Future<void> _validateDefinitionRow(
    String definitionId,
    NutritionConstraintType type,
  ) async {
    final row = await (_db.select(
      _db.nutritionConstraintDefinitions,
    )..where((table) => table.id.equals(definitionId))).getSingleOrNull();
    if (row == null ||
        row.type != type.stableId ||
        row.version != kNutritionConstraintTaxonomyVersion) {
      throw const NutritionConstraintValidationError(
        'unsupported_taxonomy_version',
        'Constraint definition is missing or not from the approved taxonomy.',
      );
    }
  }

  NutritionConstraintDefinition _definitionFromRow(
    db.NutritionConstraintDefinition row,
  ) {
    final expected = NutritionConstraintTaxonomy.definitionForId(row.id);
    if (row.key != expected.key ||
        row.type != expected.type.stableId ||
        row.version != expected.version) {
      throw const NutritionConstraintValidationError(
        'constraint_definition_mismatch',
        'Persisted taxonomy metadata does not match the approved definition.',
      );
    }
    return expected;
  }

  NutritionUserConstraint _decodeUserConstraint(
    db.NutritionUserConstraint row,
  ) {
    final definition = NutritionConstraintTaxonomy.definitionForId(
      row.definitionId,
    );
    final envelope = _decodeValue(row.value);
    final source = NutritionConstraintSourceContract.fromStableId(row.source);
    return NutritionUserConstraint(
      id: row.id,
      userId: row.userId,
      definitionId: row.definitionId,
      type: definition.type,
      target: NutritionConstraintTarget.fromJson(envelope['target']),
      strictness: NutritionConstraintStrictnessContract.fromStableId(
        row.strictness,
      ),
      severity: row.severity,
      crossContact: row.crossContact,
      effectiveFrom: row.effectiveFrom,
      effectiveTo: row.effectiveTo,
      source: source,
      notes: row.notes,
      isActive: envelope['active'] == true,
      createdAtUtc: row.createdAt,
      updatedAtUtc: row.updatedAt,
    );
  }

  NutritionConstraintEvidence _evidenceFromRow(
    db.NutritionFoodConstraintEvidenceData row,
  ) {
    final metadata = NutritionConstraintEvidence.decodeStorageNotes(row.notes);
    return NutritionConstraintEvidence(
      id: row.id,
      subjectId: row.foodId,
      target: NutritionConstraintTarget.fromStableKey(row.constraintKey),
      status: NutritionConstraintEvidenceStatusContract.fromStableId(
        row.status,
      ),
      source: NutritionConstraintEvidenceSourceContract.fromStableId(
        row.evidenceSource,
      ),
      confidence: row.confidence,
      notes: metadata['notes'] as String?,
      sourceReference: metadata['source_reference'] as String?,
      ingredientLineage: metadata['ingredient_lineage'] as String?,
      version: row.version,
    );
  }

  static Map<String, dynamic> _decodeValue(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded['contract_version'] !=
              kNutritionConstraintValueContractVersion ||
          decoded['target'] is! Map ||
          decoded['active'] is! bool) {
        throw const FormatException('unsupported constraint value envelope');
      }
      return Map<String, dynamic>.from(decoded);
    } catch (error) {
      throw NutritionConstraintValidationError(
        'invalid_constraint_value',
        'Persisted user constraint target metadata is malformed: $error',
      );
    }
  }

  static String _requiredOwner(String value) {
    final owner = value.trim();
    if (owner.isEmpty) {
      throw const NutritionConstraintValidationError(
        'missing_user_id',
        'A user-owned dietary operation requires a user ID.',
      );
    }
    return owner;
  }
}
