import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'nutrients.dart';
import 'nutrition_calculation_service.dart';
import 'nutrition_constraints.dart';
import 'typed_quantities.dart';

const int kNutritionConsumptionSnapshotContractVersion = 1;

class NutritionConsumptionError implements Exception {
  final String code;
  final String message;
  final Object? cause;

  const NutritionConsumptionError(this.code, this.message, {this.cause});

  @override
  String toString() => 'NutritionConsumptionError($code): $message';
}

class NutritionConsumptionValidationError extends NutritionConsumptionError {
  const NutritionConsumptionValidationError(
    super.code,
    super.message, {
    super.cause,
  });
}

class NutritionConsumptionConflictError extends NutritionConsumptionError {
  const NutritionConsumptionConflictError(
    super.code,
    super.message, {
    super.cause,
  });
}

class NutritionConsumptionPersistenceError extends NutritionConsumptionError {
  const NutritionConsumptionPersistenceError(
    super.code,
    super.message, {
    super.cause,
  });
}

/// Evidence that is frozen into the snapshot header. The schema-v17 lineage
/// column is the durable envelope for command identity and fields that must
/// not be interpreted from mutable catalogue rows later.
class NutritionConsumptionLineage {
  final String? commandId;
  final String contentFingerprint;
  final String? supersedesSnapshotId;
  final String? correctionId;
  final String? correctionReason;
  final Map<String, dynamic> evidence;

  NutritionConsumptionLineage({
    required this.contentFingerprint,
    String? commandId,
    String? supersedesSnapshotId,
    String? correctionId,
    String? correctionReason,
    Map<String, dynamic> evidence = const {},
  }) : commandId = commandId?.trim(),
       supersedesSnapshotId = supersedesSnapshotId?.trim(),
       correctionId = correctionId?.trim(),
       correctionReason = correctionReason?.trim(),
       evidence = _immutableJsonMap(evidence) {
    if (contentFingerprint.trim().isEmpty) {
      throw const NutritionConsumptionValidationError(
        'missing_lineage_fingerprint',
        'A calculation/content fingerprint is required.',
      );
    }
    if (commandId != null && commandId.trim().isEmpty) {
      throw const NutritionConsumptionValidationError(
        'invalid_command_id',
        'A command ID cannot be blank.',
      );
    }
    if (supersedesSnapshotId != null && supersedesSnapshotId.isEmpty) {
      throw const NutritionConsumptionValidationError(
        'invalid_correction_predecessor',
        'A correction predecessor ID cannot be blank.',
      );
    }
    if (correctionId != null && correctionId.isEmpty) {
      throw const NutritionConsumptionValidationError(
        'invalid_correction_id',
        'A correction ID cannot be blank.',
      );
    }
    if (correctionReason != null && correctionReason.isEmpty) {
      throw const NutritionConsumptionValidationError(
        'invalid_correction_reason',
        'A correction reason cannot be blank.',
      );
    }
    for (final entry in this.evidence.entries) {
      if (entry.key.trim().isEmpty) {
        throw const NutritionConsumptionValidationError(
          'invalid_lineage',
          'Lineage evidence keys cannot be blank.',
        );
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'contract_version': kNutritionConsumptionSnapshotContractVersion,
    if (commandId != null) 'command_id': commandId,
    'content_fingerprint': contentFingerprint,
    if (supersedesSnapshotId != null)
      'supersedes_snapshot_id': supersedesSnapshotId,
    if (correctionId != null) 'correction_id': correctionId,
    if (correctionReason != null) 'correction_reason': correctionReason,
    'evidence': evidence,
  };

  String get canonicalJson => jsonEncode(_canonicalizeJson(toJson()));

  factory NutritionConsumptionLineage.fromJson(Object? raw) {
    if (raw is! Map ||
        raw['contract_version'] !=
            kNutritionConsumptionSnapshotContractVersion ||
        raw['content_fingerprint'] is! String ||
        raw['evidence'] is! Map) {
      throw const NutritionConsumptionValidationError(
        'invalid_lineage',
        'Snapshot lineage is malformed or unsupported.',
      );
    }
    String? text(String key) {
      final value = raw[key];
      if (value == null) return null;
      if (value is! String || value.trim().isEmpty) {
        throw NutritionConsumptionValidationError(
          'invalid_lineage',
          'Snapshot lineage field $key is malformed.',
        );
      }
      return value;
    }

    return NutritionConsumptionLineage(
      commandId: text('command_id'),
      contentFingerprint: raw['content_fingerprint'] as String,
      supersedesSnapshotId: text('supersedes_snapshot_id'),
      correctionId: text('correction_id'),
      correctionReason: text('correction_reason'),
      evidence: Map<String, dynamic>.from(raw['evidence'] as Map),
    );
  }
}

/// The calculation result accepted by snapshot finalization. Recipe results
/// are adapted directly from B03-08. Direct-food callers provide already
/// resolved absolute facts; this object deliberately does not calculate them.
class NutritionConsumptionCalculationSnapshot {
  final Map<String, NutrientFact> facts;
  final NutrientCompleteness completeness;
  final String calculatorVersion;
  final int nutrientRegistryVersion;
  final String calculationFingerprint;
  final Map<String, dynamic> lineage;

  NutritionConsumptionCalculationSnapshot({
    required Map<String, NutrientFact> facts,
    required this.completeness,
    required this.calculatorVersion,
    required this.nutrientRegistryVersion,
    required this.calculationFingerprint,
    Map<String, dynamic> lineage = const {},
  }) : facts = Map.unmodifiable({
         for (final id in facts.keys.toList()..sort()) id: facts[id]!,
       }),
       lineage = _immutableJsonMap(lineage) {
    if (calculatorVersion.trim().isEmpty ||
        calculationFingerprint.trim().isEmpty) {
      throw const NutritionConsumptionValidationError(
        'missing_calculation_evidence',
        'Calculator version and fingerprint are required.',
      );
    }
    for (final entry in this.facts.entries) {
      if (entry.key != entry.value.nutrientId) {
        throw const NutritionConsumptionValidationError(
          'invalid_calculation_result',
          'Nutrient fact map keys must match nutrient identities.',
        );
      }
    }
    for (final fact in this.facts.values) {
      if (fact.basis.kind != NutrientBasisKind.absolute) {
        throw const NutritionConsumptionValidationError(
          'non_absolute_snapshot_fact',
          'Consumption snapshots require already-resolved absolute nutrient facts.',
        );
      }
    }
  }

  factory NutritionConsumptionCalculationSnapshot.fromRecipeResult(
    NutritionCalculationResult result,
  ) => NutritionConsumptionCalculationSnapshot(
    facts: result.facts,
    completeness: result.completeness,
    calculatorVersion: result.calculationRuleVersion,
    nutrientRegistryVersion: result.nutrientRegistryVersion,
    calculationFingerprint: result.lineage.fingerprint,
    lineage: result.toJson(),
  );

  factory NutritionConsumptionCalculationSnapshot.fromFacts({
    required Map<String, NutrientFact> facts,
    required NutrientRegistry registry,
    required Iterable<String> requestedNutrientIds,
    required String calculatorVersion,
    required String calculationFingerprint,
    Map<String, dynamic> lineage = const {},
  }) {
    for (final fact in facts.values) {
      fact.validateAgainst(registry);
    }
    final completeness = NutrientCompletenessEvaluator.evaluate(
      registry: registry,
      facts: facts,
      requestedNutrientIds: requestedNutrientIds.toSet(),
    );
    return NutritionConsumptionCalculationSnapshot(
      facts: facts,
      completeness: completeness,
      calculatorVersion: calculatorVersion,
      nutrientRegistryVersion: registry.version,
      calculationFingerprint: calculationFingerprint,
      lineage: lineage,
    );
  }

  Map<String, dynamic> toJson() => {
    'calculator_version': calculatorVersion,
    'nutrient_registry_version': nutrientRegistryVersion,
    'calculation_fingerprint': calculationFingerprint,
    'facts': {
      for (final id in facts.keys.toList()..sort()) id: facts[id]!.toJson(),
    },
    'completeness': completeness.toJson(),
    'lineage': lineage,
  };
}

class NutritionConsumptionItemInput {
  final String id;
  final int position;
  final String sourceType;
  final String? foodId;
  final String? recipeVersionId;
  final String? preparationId;
  final String? sourceReference;
  final String? displayLabel;
  final Quantity quantity;
  final NutritionConsumptionCalculationSnapshot calculation;
  final Map<String, dynamic> evidence;

  NutritionConsumptionItemInput({
    required String id,
    required this.position,
    required String sourceType,
    String? foodId,
    String? recipeVersionId,
    String? preparationId,
    String? sourceReference,
    String? displayLabel,
    required this.quantity,
    required this.calculation,
    Map<String, dynamic> evidence = const {},
  }) : id = id.trim(),
       sourceType = sourceType.trim(),
       foodId = _trimOptional(foodId),
       recipeVersionId = _trimOptional(recipeVersionId),
       preparationId = _trimOptional(preparationId),
       sourceReference = _trimOptional(sourceReference),
       displayLabel = _trimOptional(displayLabel),
       evidence = _immutableJsonMap(evidence);

  Map<String, dynamic> toLineageJson() => {
    'id': id,
    'position': position,
    'source_type': sourceType,
    if (foodId != null) 'food_id': foodId,
    if (recipeVersionId != null) 'recipe_version_id': recipeVersionId,
    if (preparationId != null) 'preparation_id': preparationId,
    if (sourceReference != null) 'source_reference': sourceReference,
    if (displayLabel != null) 'display_label': displayLabel,
    'quantity': quantity.toJson(),
    'calculation': calculation.toJson(),
    'evidence': evidence,
  };
}

class NutritionConsumptionFinalizeRequest {
  final String userId;
  final String? consumptionId;
  final String? commandId;
  final DateTime loggedAtUtc;
  final String mealCategory;
  final String? mealGroupId;
  final String sourceType;
  final String? recipeVersionId;
  final String? thaliId;
  final String? localDate;
  final String? timezoneId;
  final String calculatorVersion;
  final Iterable<NutritionConsumptionItemInput> items;
  final Map<String, dynamic> evidence;
  final NutritionConstraintEvaluationResult? constraintEvaluation;
  final NutritionConstraintAcknowledgement? constraintAcknowledgement;
  final String? supersedesSnapshotId;
  final String? correctionId;
  final String? correctionReason;

  NutritionConsumptionFinalizeRequest({
    required String userId,
    String? consumptionId,
    String? commandId,
    required DateTime loggedAtUtc,
    required String mealCategory,
    String? mealGroupId,
    required String sourceType,
    String? recipeVersionId,
    String? thaliId,
    String? localDate,
    String? timezoneId,
    required String calculatorVersion,
    required Iterable<NutritionConsumptionItemInput> items,
    Map<String, dynamic> evidence = const {},
    this.constraintEvaluation,
    this.constraintAcknowledgement,
    String? supersedesSnapshotId,
    String? correctionId,
    String? correctionReason,
  }) : userId = userId.trim(),
       consumptionId = consumptionId?.trim(),
       commandId = commandId?.trim(),
       loggedAtUtc = loggedAtUtc.toUtc(),
       mealCategory = mealCategory.trim(),
       mealGroupId = _trimOptional(mealGroupId),
       sourceType = sourceType.trim(),
       recipeVersionId = _trimOptional(recipeVersionId),
       thaliId = _trimOptional(thaliId),
       localDate = _trimOptional(localDate),
       timezoneId = _trimOptional(timezoneId),
       calculatorVersion = calculatorVersion.trim(),
       items = List.unmodifiable(items),
       evidence = _immutableJsonMap(evidence),
       supersedesSnapshotId = _trimOptional(supersedesSnapshotId),
       correctionId = correctionId?.trim(),
       correctionReason = correctionReason?.trim();

  Map<String, dynamic> canonicalContentJson() => {
    'user_id': userId,
    'logged_at_utc': loggedAtUtc.toIso8601String(),
    'meal_category': mealCategory,
    if (mealGroupId != null) 'meal_group_id': mealGroupId,
    'source_type': sourceType,
    if (recipeVersionId != null) 'recipe_version_id': recipeVersionId,
    if (thaliId != null) 'thali_id': thaliId,
    if (localDate != null) 'local_date': localDate,
    if (timezoneId != null) 'timezone_id': timezoneId,
    'calculator_version': calculatorVersion,
    'items': items.map((item) => item.toLineageJson()).toList(growable: false),
    'evidence': evidence,
    if (constraintEvaluation != null)
      'constraint_evaluation': constraintEvaluation!.toJson(),
    if (constraintAcknowledgement != null)
      'constraint_acknowledgement': constraintAcknowledgement!.toJson(),
    if (supersedesSnapshotId != null)
      'supersedes_snapshot_id': supersedesSnapshotId,
    if (correctionId != null) 'correction_id': correctionId,
    if (correctionReason != null) 'correction_reason': correctionReason,
  };

  String get contentFingerprint => _sha256(canonicalContentJson());
}

class NutritionConsumptionSnapshotItem {
  final String id;
  final int position;
  final String sourceType;
  final String? foodId;
  final String? recipeVersionId;
  final String? preparationId;
  final String? sourceReference;
  final String? displayLabel;
  final Quantity quantity;
  final Map<String, NutrientFact> facts;

  const NutritionConsumptionSnapshotItem({
    required this.id,
    required this.position,
    required this.sourceType,
    required this.foodId,
    required this.recipeVersionId,
    required this.preparationId,
    required this.sourceReference,
    required this.displayLabel,
    required this.quantity,
    required this.facts,
  });
}

class NutritionConsumptionSnapshot {
  final String id;
  final String userId;
  final DateTime loggedAtUtc;
  final String mealCategory;
  final String? mealGroupId;
  final String sourceType;
  final String? recipeVersionId;
  final String? thaliId;
  final String calculatorVersion;
  final NutrientCompleteness completeness;
  final NutrientAggregationResult totals;
  final String? localDate;
  final String? timezoneId;
  final DateTime createdAtUtc;
  final NutritionConsumptionLineage lineage;
  final List<NutritionConsumptionSnapshotItem> items;
  final NutritionConstraintEvaluationResult? constraintEvaluation;
  final NutritionConstraintAcknowledgement? constraintAcknowledgement;

  const NutritionConsumptionSnapshot({
    required this.id,
    required this.userId,
    required this.loggedAtUtc,
    required this.mealCategory,
    required this.mealGroupId,
    required this.sourceType,
    required this.recipeVersionId,
    required this.thaliId,
    required this.calculatorVersion,
    required this.completeness,
    required this.totals,
    required this.localDate,
    required this.timezoneId,
    required this.createdAtUtc,
    required this.lineage,
    required this.items,
    this.constraintEvaluation,
    this.constraintAcknowledgement,
  });

  bool get isCorrection => lineage.supersedesSnapshotId != null;
}

class NutritionDailySnapshotTotals {
  final String userId;
  final String localDate;
  final List<String> snapshotIds;
  final NutrientAggregationResult totals;

  const NutritionDailySnapshotTotals({
    required this.userId,
    required this.localDate,
    required this.snapshotIds,
    required this.totals,
  });
}

String _sha256(Map<String, dynamic> value) => sha256
    .convert(utf8.encode(jsonEncode(_canonicalizeJson(value))))
    .toString();

dynamic _canonicalizeJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalizeJson(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalizeJson).toList(growable: false);
  }
  return value;
}

Map<String, dynamic> _immutableJsonMap(Map<String, dynamic> value) =>
    _deepImmutableJson(jsonDecode(jsonEncode(value))) as Map<String, dynamic>;

dynamic _deepImmutableJson(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        entry.key.toString(): _deepImmutableJson(entry.value),
    });
  }
  if (value is Iterable) {
    return List.unmodifiable(value.map(_deepImmutableJson));
  }
  return value;
}

String? _trimOptional(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
