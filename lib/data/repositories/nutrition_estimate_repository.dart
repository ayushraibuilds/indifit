import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrients.dart';
import '../../core/nutrition_consumption_snapshots.dart';
import '../../core/nutrition_estimates.dart';
import '../../core/typed_quantities.dart';
import '../database/app_database.dart' as db;
import 'nutrition_consumption_repository.dart';

typedef NutritionEstimateFailureInjector = void Function(String stage);

/// The single durable owner for provider-neutral estimate records.
///
/// It writes only the existing B03 estimate/correction graph. It never calls a
/// provider, resolves a food name, calculates nutrients, or writes a
/// consumption snapshot directly.
class NutritionEstimateRepository {
  final db.AppDatabase _db;
  final NutrientRegistry _registry;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;
  final NutritionEstimateFailureInjector? _failureInjector;

  NutritionEstimateRepository({
    required db.AppDatabase database,
    required NutrientRegistry registry,
    Uuid? uuid,
    DateTime Function()? nowUtc,
    NutritionEstimateFailureInjector? failureInjector,
  }) : _db = database,
       _registry = registry,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _failureInjector = failureInjector;

  NutrientRegistry get registry => _registry;

  Future<NutritionEstimate> createEstimate(NutritionEstimate estimate) async {
    final normalized = _validateForPersistence(estimate);
    try {
      return await _db.transaction(() async {
        final existingByCommand = normalized.commandId == null
            ? null
            : await _findByCommandInTransaction(
                normalized.userId,
                normalized.commandId!,
              );
        if (existingByCommand != null) {
          if (existingByCommand.calculationFingerprint !=
              normalized.calculationFingerprint) {
            throw const NutritionEstimateConflictError(
              'command_payload_conflict',
              'The estimate command was already used with different content.',
            );
          }
          return existingByCommand;
        }
        final existing = await (_db.select(
          _db.nutritionEstimates,
        )..where((table) => table.id.equals(normalized.id))).getSingleOrNull();
        if (existing != null) {
          throw const NutritionEstimateConflictError(
            'duplicate_estimate_id',
            'An estimate with this portable ID already exists.',
          );
        }
        await _insertEstimate(normalized);
        _inject('after_estimate');
        final result = await _readEstimateById(
          normalized.id,
          normalized.userId,
        );
        if (result == null) {
          throw const NutritionEstimatePersistenceError(
            'missing_created_estimate',
            'The created estimate was not readable after commit.',
          );
        }
        return result;
      });
    } on NutritionEstimateError {
      rethrow;
    } catch (error) {
      throw NutritionEstimatePersistenceError(
        'estimate_create_failed',
        'The estimate transaction failed without committing a partial graph.',
        cause: error,
      );
    }
  }

  Future<NutritionEstimate> createEstimateFromDraft({
    required NutritionEstimateDraft draft,
    required String userId,
    String? estimateId,
    DateTime? createdAtUtc,
    String? commandId,
    double? confidenceScore,
  }) {
    final estimate = draft.toEstimate(
      id: estimateId ?? _uuid.v4(),
      userId: userId,
      createdAtUtc: createdAtUtc ?? _nowUtc(),
      commandId: commandId,
      confidenceScore: confidenceScore,
      registry: _registry,
    );
    return createEstimate(estimate);
  }

  Future<NutritionEstimate?> getEstimate({
    required String userId,
    required String estimateId,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedEstimateId = estimateId.trim();
    if (normalizedUserId.isEmpty || normalizedEstimateId.isEmpty) return null;
    return _readEstimateById(normalizedEstimateId, normalizedUserId);
  }

  Future<List<NutritionEstimate>> listPending({required String userId}) async {
    final rows = await (_db.select(
      _db.nutritionEstimates,
    )..where((table) => table.userId.equals(userId.trim()))).get();
    final estimates = <NutritionEstimate>[];
    for (final row in rows) {
      final estimate = await _readEstimate(row, userId.trim());
      if (estimate.reviewState == NutritionEstimateReviewState.unreviewed) {
        estimates.add(estimate);
      }
    }
    estimates.sort((left, right) {
      final time = left.createdAtUtc.compareTo(right.createdAtUtc);
      return time == 0 ? left.id.compareTo(right.id) : time;
    });
    return List.unmodifiable(estimates);
  }

  Future<List<NutritionEstimate>> listForUser({required String userId}) async {
    final rows = await (_db.select(
      _db.nutritionEstimates,
    )..where((table) => table.userId.equals(userId.trim()))).get();
    final estimates = <NutritionEstimate>[];
    for (final row in rows) {
      estimates.add(await _readEstimate(row, userId.trim()));
    }
    estimates.sort((left, right) {
      final time = left.createdAtUtc.compareTo(right.createdAtUtc);
      return time == 0 ? left.id.compareTo(right.id) : time;
    });
    return List.unmodifiable(estimates);
  }

  Future<NutritionEstimate> acceptEstimate({
    required String userId,
    required String estimateId,
    String? commandId,
  }) => _setReviewState(
    userId: userId,
    estimateId: estimateId,
    state: NutritionEstimateReviewState.accepted,
    commandId: commandId,
  );

  Future<NutritionEstimate> rejectEstimate({
    required String userId,
    required String estimateId,
    String? commandId,
  }) => _setReviewState(
    userId: userId,
    estimateId: estimateId,
    state: NutritionEstimateReviewState.rejected,
    commandId: commandId,
  );

  Future<NutritionEstimate> correctEstimate({
    required String userId,
    required String estimateId,
    required NutritionEstimateCorrection correction,
    String? correctedEstimateId,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedEstimateId = estimateId.trim();
    final original = await getEstimate(
      userId: normalizedUserId,
      estimateId: normalizedEstimateId,
    );
    if (original == null) {
      throw const NutritionEstimateValidationError(
        'missing_estimate',
        'The estimate to correct was not found for this user.',
      );
    }
    final correctionFingerprint = _sha256({
      'target_estimate_id': normalizedEstimateId,
      'command_id': correction.commandId,
      'reason': correction.reason,
      'nutrients': {
        for (final id in correction.nutrientReplacements.keys.toList()..sort())
          id: correction.nutrientReplacements[id]!.toJson(),
      },
      'subject_id': correction.subjectId,
      'subject_type': correction.subjectType,
      'display_label': correction.displayLabel,
      'quantity': correction.replaceQuantity
          ? correction.quantity?.toJson()
          : null,
      'replace_quantity': correction.replaceQuantity,
      'field_updates': correction.fieldUpdates,
    });

    try {
      return await _db.transaction(() async {
        final existingByCommand = await _findByCommandInTransaction(
          normalizedUserId,
          correction.commandId,
        );
        if (existingByCommand != null) {
          final existingFingerprint = await _correctionFingerprintFor(
            existingByCommand.id,
          );
          if (existingByCommand.supersedesId != normalizedEstimateId ||
              existingFingerprint != correctionFingerprint) {
            throw const NutritionEstimateConflictError(
              'command_payload_conflict',
              'The correction command was already used with different content.',
            );
          }
          // The command ID is the idempotency key. A replay returns the
          // already committed child instead of appending another ancestry
          // branch.
          return existingByCommand;
        }

        final current = await _readEstimateById(
          normalizedEstimateId,
          normalizedUserId,
        );
        if (current == null) {
          throw const NutritionEstimateValidationError(
            'missing_estimate',
            'The estimate to correct was not found for this user.',
          );
        }
        if (current.reviewState == NutritionEstimateReviewState.rejected) {
          throw const NutritionEstimateConflictError(
            'rejected_estimate',
            'A rejected estimate cannot be corrected into a consumption candidate.',
          );
        }

        final correctedFacts = <String, NutrientFact>{...current.facts};
        for (final entry in correction.nutrientReplacements.entries) {
          _registry.definitionFor(entry.key);
          final replacement = entry.value;
          replacement.validateAgainst(_registry);
          if (replacement.source != NutrientSourceType.userEntered) {
            throw const NutritionEstimateValidationError(
              'invalid_correction_source',
              'Corrected nutrient facts must be user-entered facts.',
            );
          }
          correctedFacts[entry.key] = replacement;
        }
        final correctedQuantity = correction.replaceQuantity
            ? correction.quantity
            : current.quantity;
        if (correction.replaceQuantity && correctedQuantity == null) {
          throw const NutritionEstimateValidationError(
            'invalid_correction_quantity',
            'A quantity correction must provide a typed quantity.',
          );
        }
        if (correctedQuantity != null) {
          NutritionQuantityService.validatePositiveUserEnteredPortion(
            correctedQuantity,
          );
        }
        _validateCorrectionFields(correction.fieldUpdates);

        final corrected = NutritionEstimate(
          id: correctedEstimateId?.trim().isNotEmpty == true
              ? correctedEstimateId!.trim()
              : _uuid.v4(),
          userId: normalizedUserId,
          subjectId: correction.subjectId ?? current.subjectId,
          subjectType: correction.subjectType ?? current.subjectType,
          displayLabel: correction.displayLabel ?? current.displayLabel,
          createdAtUtc: _nowUtc(),
          source: NutrientSourceType.userEntered,
          provider: current.provider,
          model: current.model,
          ruleVersion: current.ruleVersion,
          inputHash: current.inputHash,
          evidence: current.evidence,
          confidence: NutrientConfidence.unknown,
          confidenceScore: null,
          reviewState: NutritionEstimateReviewState.corrected,
          recordStatus: recordStatusForFacts(correctedFacts),
          supersedesId: current.id,
          ancestryRootId: current.rootId,
          commandId: correction.commandId,
          quantity: correctedQuantity,
          facts: correctedFacts,
          requestedNutrientIds: current.requestedNutrientIds,
          registry: _registry,
        );
        if (corrected.id == current.id) {
          throw const NutritionEstimateValidationError(
            'invalid_estimate_ancestry',
            'A correction must use a new estimate ID.',
          );
        }
        final existingId = await (_db.select(
          _db.nutritionEstimates,
        )..where((table) => table.id.equals(corrected.id))).getSingleOrNull();
        if (existingId != null) {
          throw const NutritionEstimateConflictError(
            'duplicate_estimate_id',
            'The corrected estimate ID already exists.',
          );
        }
        await _insertEstimate(
          corrected,
          correction: {
            'target_estimate_id': current.id,
            'fingerprint': correctionFingerprint,
            'command_id': correction.commandId,
            'reason': correction.reason,
            'fields': correction.fieldUpdates,
            'nutrient_ids': correction.nutrientReplacements.keys.toList()
              ..sort(),
          },
        );
        _inject('after_correction_estimate');

        for (final entry in correction.nutrientReplacements.entries) {
          await _insertCorrectionRow(
            userId: normalizedUserId,
            targetId: corrected.id,
            field: 'nutrient:${entry.key}',
            oldValue: current.facts[entry.key] == null
                ? null
                : jsonEncode(current.facts[entry.key]!.toJson()),
            newValue: jsonEncode(entry.value.toJson()),
            reason: correction.reason,
            commandId: correction.commandId,
          );
        }
        if (correction.replaceQuantity) {
          await _insertCorrectionRow(
            userId: normalizedUserId,
            targetId: corrected.id,
            field: 'quantity',
            oldValue: current.quantity == null
                ? null
                : jsonEncode(current.quantity!.toJson()),
            newValue: correctedQuantity == null
                ? null
                : jsonEncode(correctedQuantity.toJson()),
            reason: correction.reason,
            commandId: correction.commandId,
          );
        }
        if (correction.subjectId != null || correction.displayLabel != null) {
          await _insertCorrectionRow(
            userId: normalizedUserId,
            targetId: corrected.id,
            field: 'food_identity',
            oldValue: jsonEncode({
              'id': current.subjectId,
              'label': current.displayLabel,
            }),
            newValue: jsonEncode({
              'id': corrected.subjectId,
              'label': corrected.displayLabel,
            }),
            reason: correction.reason,
            commandId: correction.commandId,
          );
        }
        for (final entry in correction.fieldUpdates.entries) {
          if (entry.key == 'food_identity' &&
              (correction.subjectId != null ||
                  correction.displayLabel != null)) {
            // The typed food-identity correction above is the authoritative
            // record for this field; do not insert a duplicate row when the
            // bounded UI also supplies a classification marker.
            continue;
          }
          await _insertCorrectionRow(
            userId: normalizedUserId,
            targetId: corrected.id,
            field: entry.key,
            oldValue: null,
            newValue: jsonEncode(entry.value),
            reason: correction.reason,
            commandId: correction.commandId,
          );
        }
        _inject('after_correction_rows');
        await _markSuperseded(current);
        _inject('after_supersede');
        final result = await _readEstimateById(corrected.id, normalizedUserId);
        if (result == null) {
          throw const NutritionEstimatePersistenceError(
            'missing_corrected_estimate',
            'The corrected estimate was not readable after commit.',
          );
        }
        return result;
      });
    } on NutritionEstimateError {
      rethrow;
    } catch (error) {
      throw NutritionEstimatePersistenceError(
        'estimate_correction_failed',
        'The correction transaction failed without committing a partial graph.',
        cause: error,
      );
    }
  }

  /// Returns the user-owned food identity used by schema-v17 snapshots. The
  /// source reference remains the estimate portable ID, so display text is not
  /// used as identity and historical reads remain stable.
  Future<String> ensureFoodIdentity(NutritionEstimate estimate) async {
    final normalized = _validateForPersistence(estimate);
    return _db.transaction(() => _ensureFoodIdentity(normalized));
  }

  Future<List<db.NutritionUserCorrection>> listCorrections({
    required String userId,
    String? targetId,
  }) {
    final query = _db.select(_db.nutritionUserCorrections)
      ..where(
        (table) =>
            table.userId.equals(userId.trim()) &
            (targetId == null
                ? const Constant(true)
                : table.targetId.equals(targetId.trim())),
      )
      ..orderBy([(table) => OrderingTerm(expression: table.createdAt)]);
    return query.get();
  }

  Future<NutritionEstimate> _setReviewState({
    required String userId,
    required String estimateId,
    required NutritionEstimateReviewState state,
    String? commandId,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedEstimateId = estimateId.trim();
    if (commandId != null && commandId.trim().isEmpty) {
      throw const NutritionEstimateValidationError(
        'invalid_command_id',
        'A review command ID cannot be blank.',
      );
    }
    try {
      return await _db.transaction(() async {
        final estimate = await _readEstimateById(
          normalizedEstimateId,
          normalizedUserId,
        );
        if (estimate == null) {
          throw const NutritionEstimateValidationError(
            'missing_estimate',
            'The estimate was not found for this user.',
          );
        }
        if (estimate.reviewState == state) return estimate;
        if (estimate.reviewState == NutritionEstimateReviewState.superseded) {
          throw const NutritionEstimateConflictError(
            'superseded_estimate',
            'A superseded estimate cannot change review state.',
          );
        }
        if (state == NutritionEstimateReviewState.accepted &&
            estimate.reviewState == NutritionEstimateReviewState.rejected) {
          throw const NutritionEstimateConflictError(
            'rejected_estimate',
            'A rejected estimate cannot be accepted.',
          );
        }
        if (state == NutritionEstimateReviewState.rejected &&
            estimate.reviewState == NutritionEstimateReviewState.accepted) {
          throw const NutritionEstimateConflictError(
            'accepted_estimate',
            'An accepted estimate cannot be rejected silently.',
          );
        }
        final envelope = estimate.toPersistenceEnvelope(
          overrideReviewState: state.stableId,
          overrideCommandId: commandId ?? estimate.commandId,
        );
        await (_db.update(_db.nutritionEstimates)..where(
              (table) =>
                  table.id.equals(estimate.id) &
                  table.userId.equals(normalizedUserId),
            ))
            .write(
              db.NutritionEstimatesCompanion(
                assumptions: Value(jsonEncode(envelope)),
                updatedAt: Value(_nowUtc()),
              ),
            );
        final result = await _readEstimateById(estimate.id, normalizedUserId);
        if (result == null) {
          throw const NutritionEstimatePersistenceError(
            'missing_reviewed_estimate',
            'The reviewed estimate was not readable after update.',
          );
        }
        return result;
      });
    } on NutritionEstimateError {
      rethrow;
    } catch (error) {
      throw NutritionEstimatePersistenceError(
        'estimate_review_failed',
        'The estimate review state could not be saved.',
        cause: error,
      );
    }
  }

  Future<void> _insertEstimate(
    NutritionEstimate estimate, {
    Map<String, dynamic>? correction,
  }) async {
    final now = estimate.createdAtUtc;
    await _db
        .into(_db.nutritionEstimates)
        .insert(
          db.NutritionEstimatesCompanion.insert(
            id: estimate.id,
            userId: estimate.userId,
            source: _dbSource(estimate.source),
            provider: Value(estimate.provider),
            model: Value(estimate.model),
            ruleVersion: Value(estimate.ruleVersion),
            inputHash: Value(estimate.inputHash),
            assumptions: Value(
              jsonEncode(
                estimate.toPersistenceEnvelope(correction: correction),
              ),
            ),
            confidence: Value(estimate.confidenceScore),
            status: _dbStatus(estimate.recordStatus),
            supersedesId: Value(estimate.supersedesId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    _inject('after_estimate_header');
    for (final nutrientId in estimate.facts.keys.toList()..sort()) {
      final fact = estimate.facts[nutrientId]!;
      await _db
          .into(_db.nutritionEstimateNutrients)
          .insert(
            db.NutritionEstimateNutrientsCompanion.insert(
              id: '${estimate.id}::$nutrientId',
              estimateId: estimate.id,
              nutrientId: nutrientId,
              amount: Value(_amountDouble(fact.point)),
              lower: Value(_amountDouble(fact.lower)),
              upper: Value(_amountDouble(fact.upper)),
              status: fact.status.stableId,
              unit: fact.unit.stableId,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
    _inject('after_estimate_nutrients');
    await _ensureFoodIdentity(estimate);
    _inject('after_estimate_food_identity');
  }

  Future<String> _ensureFoodIdentity(NutritionEstimate estimate) async {
    final foodId = 'estimate-food::${estimate.id}';
    final sourceType = switch (estimate.source) {
      NutrientSourceType.aiEstimate => 'ai',
      NutrientSourceType.importedProvider => 'import',
      NutrientSourceType.heuristic => 'user',
      NutrientSourceType.userEntered => 'user',
      _ => 'unknown',
    };
    final kind = estimate.source == NutrientSourceType.userEntered
        ? 'userCreated'
        : 'aiEstimate';
    final existing = await (_db.select(
      _db.nutritionFoods,
    )..where((table) => table.id.equals(foodId))).getSingleOrNull();
    if (existing != null) {
      if (existing.sourceRef != estimate.id ||
          existing.sourceVersion != 'estimate-v1') {
        throw const NutritionEstimateConflictError(
          'food_identity_collision',
          'The estimate food identity is owned by a different source.',
        );
      }
      return foodId;
    }
    await _db
        .into(_db.nutritionFoods)
        .insert(
          db.NutritionFoodsCompanion.insert(
            id: foodId,
            kind: kind,
            displayName: estimate.displayLabel,
            locale: 'en',
            sourceType: sourceType,
            sourceRef: Value(estimate.id),
            sourceVersion: const Value('estimate-v1'),
            lifecycle: 'active',
            createdAt: Value(estimate.createdAtUtc),
            updatedAt: Value(_nowUtc()),
          ),
        );
    return foodId;
  }

  Future<void> _insertCorrectionRow({
    required String userId,
    required String targetId,
    required String field,
    required String? oldValue,
    required String? newValue,
    required String reason,
    required String commandId,
  }) async {
    await _db
        .into(_db.nutritionUserCorrections)
        .insert(
          db.NutritionUserCorrectionsCompanion.insert(
            id: '$commandId::$field',
            userId: userId,
            targetType: 'nutrition_estimate',
            targetId: targetId,
            field: field,
            oldValue: Value(oldValue),
            newValue: Value(newValue),
            reason: reason,
            source: NutrientSourceType.userEntered.stableId,
            createdAt: Value(_nowUtc()),
          ),
        );
  }

  Future<void> _markSuperseded(NutritionEstimate estimate) async {
    final envelope = estimate.toPersistenceEnvelope(
      overrideReviewState: NutritionEstimateReviewState.superseded.stableId,
      overrideCommandId: estimate.commandId,
    );
    await (_db.update(_db.nutritionEstimates)..where(
          (table) =>
              table.id.equals(estimate.id) &
              table.userId.equals(estimate.userId),
        ))
        .write(
          db.NutritionEstimatesCompanion(
            assumptions: Value(jsonEncode(envelope)),
            status: const Value('superseded'),
            updatedAt: Value(_nowUtc()),
          ),
        );
  }

  Future<NutritionEstimate?> _findByCommandInTransaction(
    String userId,
    String commandId,
  ) async {
    final rows = await (_db.select(
      _db.nutritionEstimates,
    )..where((table) => table.userId.equals(userId))).get();
    for (final row in rows) {
      final estimate = await _readEstimate(row, userId);
      if (estimate.commandId == commandId) return estimate;
    }
    return null;
  }

  Future<String?> _correctionFingerprintFor(String estimateId) async {
    final row = await (_db.select(
      _db.nutritionEstimates,
    )..where((table) => table.id.equals(estimateId))).getSingleOrNull();
    if (row?.assumptions == null) return null;
    try {
      final decoded = jsonDecode(row!.assumptions!);
      if (decoded is! Map || decoded['correction'] is! Map) return null;
      final correction = Map<String, dynamic>.from(decoded['correction']);
      return correction['fingerprint'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<NutritionEstimate?> _readEstimateById(
    String estimateId,
    String userId,
  ) async {
    final row =
        await (_db.select(_db.nutritionEstimates)..where(
              (table) =>
                  table.id.equals(estimateId) & table.userId.equals(userId),
            ))
            .getSingleOrNull();
    return row == null ? null : _readEstimate(row, userId);
  }

  Future<NutritionEstimate> _readEstimate(
    db.NutritionEstimate row,
    String userId,
  ) async {
    if (row.userId != userId) {
      throw const NutritionEstimateValidationError(
        'estimate_ownership',
        'Estimate does not belong to the requesting user.',
      );
    }
    final nutrientRows = await (_db.select(
      _db.nutritionEstimateNutrients,
    )..where((table) => table.estimateId.equals(row.id))).get();
    Map<String, dynamic>? envelope;
    if (row.assumptions != null) {
      try {
        final raw = jsonDecode(row.assumptions!);
        if (raw is! Map) throw const FormatException('not an object');
        envelope = Map<String, dynamic>.from(raw);
      } catch (error) {
        throw NutritionEstimatePersistenceError(
          'invalid_estimate_envelope',
          'Estimate ${row.id} has malformed durable evidence.',
          cause: error,
        );
      }
    }
    if (envelope != null &&
        envelope['contract_version'] != kNutritionEstimateContractVersion) {
      throw const NutritionEstimatePersistenceError(
        'unsupported_estimate_version',
        'Estimate durable evidence uses an unsupported contract version.',
      );
    }
    final facts = <String, NutrientFact>{};
    if (envelope?['facts'] is Map) {
      final rawFacts = envelope!['facts'] as Map;
      for (final entry in rawFacts.entries) {
        if (entry.key is! String) {
          throw const NutritionEstimatePersistenceError(
            'invalid_estimate_facts',
            'Estimate nutrient IDs must be strings.',
          );
        }
        final fact = NutrientFact.fromJson(entry.value, _registry);
        facts[entry.key as String] = fact;
      }
    } else if (envelope != null && envelope.containsKey('facts')) {
      throw const NutritionEstimatePersistenceError(
        'invalid_estimate_facts',
        'Estimate nutrient evidence must be an object.',
      );
    } else {
      for (final nutrientRow in nutrientRows) {
        final definition = _registry.definitionFor(nutrientRow.nutrientId);
        final status = NutrientFactStatusContract.fromStableId(
          nutrientRow.status,
        );
        facts[nutrientRow.nutrientId] = NutrientFact(
          nutrientId: nutrientRow.nutrientId,
          unit: NutrientUnitContract.fromStableId(nutrientRow.unit),
          status: status,
          point: _amountFromDouble(nutrientRow.amount, definition.unit),
          lower: _amountFromDouble(nutrientRow.lower, definition.unit),
          upper: _amountFromDouble(nutrientRow.upper, definition.unit),
          basis: NutrientBasis(NutrientBasisKind.absolute),
          source: NutrientSourceContract.fromStableId(row.source),
          confidence: NutrientConfidence.notProvided,
          factVersion: row.ruleVersion ?? 'db-v8',
        );
      }
    }
    _verifyNutrientProjection(facts, nutrientRows, row.id);
    final subject = envelope?['subject'];
    final subjectMap = subject is Map
        ? Map<String, dynamic>.from(subject)
        : const <String, dynamic>{};
    final evidence = envelope?['evidence'] == null
        ? NutritionEstimateEvidence()
        : NutritionEstimateEvidence.fromJson(envelope!['evidence']);
    final reviewState = envelope?['review_state'] is String
        ? NutritionEstimateReviewStateContract.fromStableId(
            envelope!['review_state'] as String,
          )
        : row.status == 'superseded'
        ? NutritionEstimateReviewState.superseded
        : NutritionEstimateReviewState.unreviewed;
    final requested = envelope?['requested_nutrients'] is List
        ? (envelope!['requested_nutrients'] as List).cast<String>().toSet()
        : nutrientRows.map((item) => item.nutrientId).toSet();
    final quantityRaw = envelope?['quantity'];
    final quantity = quantityRaw is Map
        ? Quantity.fromJson(Map<String, dynamic>.from(quantityRaw))
        : null;
    final ancestry = envelope?['correction_ancestry'];
    if (row.supersedesId != null && ancestry != null && ancestry is! Map) {
      throw const NutritionEstimatePersistenceError(
        'invalid_estimate_ancestry',
        'Estimate correction ancestry must be an object.',
      );
    }
    final ancestryMap = ancestry is Map
        ? Map<String, dynamic>.from(ancestry)
        : const <String, dynamic>{};
    if (ancestryMap['root_id'] != null && ancestryMap['root_id'] is! String) {
      throw const NutritionEstimatePersistenceError(
        'invalid_estimate_ancestry',
        'Estimate correction ancestry root IDs must be strings.',
      );
    }
    final confidence = envelope?['confidence'] is String
        ? NutrientConfidenceContract.fromStableId(
            envelope!['confidence'] as String,
          )
        : NutrientConfidence.unknown;
    final estimate = NutritionEstimate(
      id: row.id,
      userId: row.userId,
      subjectId: subjectMap['id'] as String?,
      subjectType: subjectMap['type'] as String? ?? 'estimate',
      displayLabel: subjectMap['label'] as String? ?? 'Estimated item',
      createdAtUtc: row.createdAt.toUtc(),
      source: NutrientSourceContract.fromStableId(row.source),
      provider: row.provider,
      model: row.model,
      ruleVersion: row.ruleVersion,
      inputHash: row.inputHash,
      evidence: evidence,
      confidence: confidence,
      confidenceScore: row.confidence,
      reviewState: reviewState,
      recordStatus: NutritionEstimateRecordStatusContract.fromStableId(
        row.status,
      ),
      supersedesId: row.supersedesId,
      ancestryRootId: ancestryMap['root_id'] as String?,
      commandId: envelope?['command_id'] as String?,
      quantity: quantity,
      facts: facts,
      requestedNutrientIds: requested,
      registry: _registry,
      estimateVersion: envelope?['estimate_version'] as String? ?? '1',
    );
    if ((reviewState == NutritionEstimateReviewState.superseded) !=
        (estimate.recordStatus == NutritionEstimateRecordStatus.superseded)) {
      throw const NutritionEstimatePersistenceError(
        'estimate_status_mismatch',
        'Superseded estimate review state disagrees with its status.',
      );
    }
    return estimate;
  }

  NutritionEstimate _validateForPersistence(NutritionEstimate estimate) {
    if (estimate.registry != null && estimate.registry != _registry) {
      // Registry instances are immutable but may be separately constructed.
      // Revalidate against this repository's authoritative version below.
    }
    for (final id in estimate.requestedNutrientIds) {
      _registry.definitionFor(id);
    }
    for (final fact in estimate.facts.values) {
      fact.validateAgainst(_registry);
    }
    if ((estimate.reviewState == NutritionEstimateReviewState.superseded) !=
        (estimate.recordStatus == NutritionEstimateRecordStatus.superseded)) {
      throw const NutritionEstimateValidationError(
        'estimate_status_mismatch',
        'Superseded estimates must carry the superseded record status.',
      );
    }
    if (estimate.source == NutrientSourceType.bundledCatalogue ||
        estimate.source == NutrientSourceType.regionalCatalogue ||
        estimate.source == NutrientSourceType.recipeCalculation) {
      throw const NutritionEstimateValidationError(
        'unsupported_estimate_source',
        'Catalogue and recipe facts must use their authoritative fact owner, not an estimate record.',
      );
    }
    final envelope = estimate.toPersistenceEnvelope();
    NutritionEstimateEvidence.fromJson(envelope['evidence']);
    if (estimate.facts.isEmpty && estimate.requestedNutrientIds.isEmpty) {
      throw const NutritionEstimateValidationError(
        'empty_estimate',
        'An estimate must identify requested nutrients.',
      );
    }
    return estimate;
  }

  void _verifyNutrientProjection(
    Map<String, NutrientFact> facts,
    List<db.NutritionEstimateNutrient> rows,
    String estimateId,
  ) {
    final byId = {for (final row in rows) row.nutrientId: row};
    if (byId.length != facts.length ||
        facts.keys.any((nutrientId) => !byId.containsKey(nutrientId))) {
      throw NutritionEstimatePersistenceError(
        'estimate_projection_mismatch',
        'Estimate $estimateId has extra or missing nutrient projections.',
      );
    }
    for (final entry in facts.entries) {
      final row = byId[entry.key];
      if (row == null) {
        throw NutritionEstimatePersistenceError(
          'missing_estimate_nutrient_row',
          'Estimate $estimateId is missing its nutrient projection.',
        );
      }
      final fact = entry.value;
      if (row.status != fact.status.stableId ||
          row.unit != fact.unit.stableId ||
          !_sameDouble(row.amount, _amountDouble(fact.point)) ||
          !_sameDouble(row.lower, _amountDouble(fact.lower)) ||
          !_sameDouble(row.upper, _amountDouble(fact.upper))) {
        throw NutritionEstimatePersistenceError(
          'estimate_projection_mismatch',
          'Estimate $estimateId has inconsistent nutrient evidence.',
        );
      }
    }
  }

  void _validateCorrectionFields(Map<String, dynamic> fields) {
    const allowed = {
      'food_identity',
      'meal_category',
      'notes',
      'source_classification',
    };
    for (final entry in fields.entries) {
      final key = entry.key.trim();
      if (!(allowed.contains(key) || key.startsWith('nutrient:'))) {
        throw NutritionEstimateValidationError(
          'invalid_correction_field',
          'Correction field "$key" is not supported.',
        );
      }
      if (entry.value is Map || entry.value is List) {
        throw const NutritionEstimateValidationError(
          'invalid_correction_field',
          'Correction fields cannot carry nested private payloads.',
        );
      }
      if (entry.value is String && (entry.value as String).length > 512) {
        throw const NutritionEstimateValidationError(
          'invalid_correction_field',
          'Correction field values exceed the durable size limit.',
        );
      }
    }
  }

  String _dbSource(NutrientSourceType source) {
    final value = source.stableId;
    const allowed = {
      'reviewed_catalogue',
      'manufacturer_label',
      'user_entered',
      'imported_provider',
      'recipe_calculation',
      'ai_estimate',
      'heuristic',
      'legacy',
      'unknown',
    };
    if (!allowed.contains(value)) {
      throw NutritionEstimateValidationError(
        'unsupported_estimate_source',
        'Estimate source $value is not supported by schema-v17.',
      );
    }
    return value;
  }

  String _dbStatus(NutritionEstimateRecordStatus status) => status.stableId;

  void _inject(String stage) => _failureInjector?.call(stage);
}

/// Adapter that submits estimate facts through the one canonical B03-11A
/// finalization writer. It does not insert or update snapshot rows itself.
class NutritionEstimateFinalizationService {
  final NutritionEstimateRepository _estimates;
  final NutritionConsumptionRepository _consumption;
  final NutrientRegistry _registry;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  NutritionEstimateFinalizationService({
    required NutritionEstimateRepository estimates,
    required NutritionConsumptionRepository consumption,
    required NutrientRegistry registry,
    Uuid? uuid,
    DateTime Function()? nowUtc,
  }) : _estimates = estimates,
       _consumption = consumption,
       _registry = registry,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  Future<NutritionConsumptionSnapshot> finalizeEstimate({
    required String userId,
    required String estimateId,
    required String mealCategory,
    Quantity? quantity,
    DateTime? loggedAtUtc,
    String? localDate,
    String? timezoneId,
    String? commandId,
    String? consumptionId,
    String? displayLabel,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedEstimateId = estimateId.trim();
    final normalizedCommandId = commandId?.trim();
    if (normalizedCommandId != null && normalizedCommandId.isEmpty) {
      throw const NutritionEstimateValidationError(
        'invalid_command_id',
        'A finalization command ID cannot be blank.',
      );
    }
    if (normalizedCommandId != null) {
      final existing = await _consumption.findByCommandId(
        userId: normalizedUserId,
        commandId: normalizedCommandId,
      );
      if (existing != null) {
        final existingItem = existing.items.length == 1
            ? existing.items.single
            : null;
        final sameEstimate =
            existing.sourceType == 'estimate' &&
            existingItem?.sourceType == 'estimate' &&
            existingItem?.sourceReference == normalizedEstimateId;
        final sameConsumption =
            consumptionId == null || consumptionId.trim() == existing.id;
        final sameMeal = existing.mealCategory == mealCategory.trim();
        final sameQuantity =
            quantity == null ||
            (existingItem != null &&
                jsonEncode(existingItem.quantity.toJson()) ==
                    jsonEncode(quantity.toJson()));
        final sameLoggedAt =
            loggedAtUtc == null ||
            existing.loggedAtUtc.isAtSameMomentAs(loggedAtUtc.toUtc());
        final sameLocalDate =
            localDate == null || existing.localDate == localDate.trim();
        final sameTimezone =
            timezoneId == null || existing.timezoneId == timezoneId.trim();
        final sameLabel =
            displayLabel == null || existingItem?.displayLabel == displayLabel;
        if (!sameEstimate ||
            !sameConsumption ||
            !sameMeal ||
            !sameQuantity ||
            !sameLoggedAt ||
            !sameLocalDate ||
            !sameTimezone ||
            !sameLabel) {
          throw const NutritionEstimateConflictError(
            'command_payload_conflict',
            'The finalization command was already used with different content.',
          );
        }
        return existing;
      }
    }
    final estimate = await _estimates.getEstimate(
      userId: normalizedUserId,
      estimateId: normalizedEstimateId,
    );
    if (estimate == null) {
      throw const NutritionEstimateValidationError(
        'missing_estimate',
        'The estimate was not found for this user.',
      );
    }
    if (estimate.reviewState == NutritionEstimateReviewState.rejected) {
      throw const NutritionEstimateConflictError(
        'rejected_estimate',
        'A rejected estimate cannot be logged.',
      );
    }
    if (estimate.reviewState == NutritionEstimateReviewState.superseded) {
      throw const NutritionEstimateConflictError(
        'stale_estimate',
        'This estimate has a correction successor; select the newer estimate before logging.',
      );
    }
    final resolvedQuantity = quantity ?? estimate.quantity;
    if (resolvedQuantity == null) {
      throw const NutritionEstimateValidationError(
        'missing_estimate_quantity',
        'A positive typed quantity is required before an estimate can be logged.',
      );
    }
    try {
      NutritionQuantityService.validatePositiveConsumedQuantity(
        resolvedQuantity,
      );
    } on QuantityError catch (error) {
      throw NutritionEstimateValidationError(
        'invalid_estimate_quantity',
        error.message,
      );
    }
    final predecessor = estimate.supersedesId == null
        ? null
        : await _estimates.getEstimate(
            userId: normalizedUserId,
            estimateId: estimate.supersedesId!,
          );
    if (estimate.supersedesId != null && predecessor == null) {
      throw const NutritionEstimatePersistenceError(
        'missing_correction_ancestor',
        'The estimate correction ancestor is unavailable for finalization.',
      );
    }
    final originalRange = _factsJson(predecessor?.facts ?? estimate.facts);
    final correctedRange = predecessor == null
        ? null
        : _factsJson(estimate.facts);
    final facts = <String, NutrientFact>{};
    try {
      for (final entry in estimate.facts.entries) {
        facts[entry.key] = entry.value.basis.kind == NutrientBasisKind.absolute
            ? entry.value
            : entry.value.scaleBy(resolvedQuantity);
      }
    } on NutrientError catch (error) {
      throw NutritionEstimateValidationError(
        'unresolved_estimate_quantity_context',
        error.message,
      );
    }
    final calculation = NutritionConsumptionCalculationSnapshot.fromFacts(
      facts: facts,
      registry: _registry,
      requestedNutrientIds: estimate.requestedNutrientIds,
      calculatorVersion: 'estimate-${estimate.estimateVersion}',
      calculationFingerprint: estimate.calculationFingerprint,
      lineage: {
        'estimate_id': estimate.id,
        'estimate_version': estimate.estimateVersion,
        'estimate_calculation_fingerprint': estimate.calculationFingerprint,
        'estimate_range': _factsJson(estimate.facts),
        'original_range': originalRange,
        'corrected_range': ?correctedRange,
        'correction_ancestry': {
          'supersedes_id': estimate.supersedesId,
          'root_id': estimate.rootId,
        },
      },
    );
    final foodId = await _estimates.ensureFoodIdentity(estimate);
    final item = NutritionConsumptionItemInput(
      id: 'estimate-item::$normalizedEstimateId',
      position: 0,
      sourceType: 'estimate',
      foodId: foodId,
      sourceReference: estimate.id,
      displayLabel: displayLabel ?? estimate.displayLabel,
      quantity: resolvedQuantity,
      calculation: calculation,
      evidence: {
        'estimate_id': estimate.id,
        'estimate_version': estimate.estimateVersion,
        'estimate_source': estimate.source.stableId,
        'estimate_provider': estimate.provider,
        'estimate_model': estimate.model,
        'estimate_rule_version': estimate.ruleVersion,
        'estimate_input_hash': estimate.inputHash,
        'estimate_review_state': estimate.reviewState.stableId,
        'estimate_provenance': estimate.evidence.toJson(),
        'correction_ancestry': {
          'supersedes_id': estimate.supersedesId,
          'root_id': estimate.rootId,
        },
        'temporary_image_retained': false,
      },
    );
    return _consumption.finalizeConsumption(
      NutritionConsumptionFinalizeRequest(
        userId: normalizedUserId,
        consumptionId: consumptionId,
        commandId: normalizedCommandId ?? 'estimate-command::${_uuid.v4()}',
        loggedAtUtc: (loggedAtUtc ?? _nowUtc()).toUtc(),
        mealCategory: mealCategory,
        sourceType: 'estimate',
        localDate: localDate,
        timezoneId: timezoneId,
        calculatorVersion: calculation.calculatorVersion,
        items: [item],
        evidence: {
          'estimate_id': estimate.id,
          'estimate_version': estimate.estimateVersion,
          'estimate_calculation_fingerprint': estimate.calculationFingerprint,
          'estimate_range': _factsJson(estimate.facts),
          'original_range': originalRange,
          'corrected_range': ?correctedRange,
          'estimate_correction_ancestry': {
            'supersedes_id': estimate.supersedesId,
            'root_id': estimate.rootId,
          },
          'estimate_provenance': estimate.evidence.toJson(),
          'review_state': estimate.reviewState.stableId,
          'temporary_image_retained': false,
        },
      ),
    );
  }
}

Map<String, dynamic> _factsJson(Map<String, NutrientFact> facts) => {
  for (final id in facts.keys.toList()..sort()) id: facts[id]!.toJson(),
};

NutrientAmount? _amountFromDouble(double? value, NutrientUnit unit) {
  if (value == null) return null;
  return NutrientAmount(value: QuantityAmount.fromNum(value), unit: unit);
}

double? _amountDouble(NutrientAmount? value) => value?.value.asDouble;

bool _sameDouble(double? left, double? right) {
  if (left == null || right == null) return left == right;
  return (left - right).abs() < 0.0000001;
}

String _sha256(Map<String, dynamic> value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();

dynamic _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
