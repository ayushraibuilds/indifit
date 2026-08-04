import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'nutrients.dart';
import 'typed_quantities.dart';

/// Version of the provider-neutral estimate envelope stored in the existing
/// schema-v17 `assumptions` column.
const int kNutritionEstimateContractVersion = 1;

/// Version of the strict provider response shape understood by B03-14.
const int kNutritionEstimateResponseContractVersion = 1;

sealed class NutritionEstimateError implements Exception {
  final String message;

  const NutritionEstimateError(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class NutritionEstimateValidationError extends NutritionEstimateError {
  final String code;

  const NutritionEstimateValidationError(this.code, super.message);
}

class NutritionEstimateConflictError extends NutritionEstimateError {
  final String code;

  const NutritionEstimateConflictError(this.code, super.message);
}

class NutritionEstimatePersistenceError extends NutritionEstimateError {
  final String code;
  final Object? cause;

  const NutritionEstimatePersistenceError(
    this.code,
    super.message, {
    this.cause,
  });

  @override
  String toString() => '$runtimeType($code): $message';
}

class NutritionEstimatePrivacyError extends NutritionEstimateValidationError {
  const NutritionEstimatePrivacyError(super.code, super.message);
}

enum NutritionEstimateReviewState {
  unreviewed,
  accepted,
  corrected,
  rejected,
  superseded,
}

extension NutritionEstimateReviewStateContract on NutritionEstimateReviewState {
  String get stableId => name;

  static NutritionEstimateReviewState fromStableId(String value) {
    return NutritionEstimateReviewState.values.firstWhere(
      (state) => state.stableId == value,
      orElse: () => throw NutritionEstimateValidationError(
        'unsupported_review_state',
        'Unsupported nutrition estimate review state: $value.',
      ),
    );
  }
}

enum NutritionEstimateInputModality { text, photo, manual, imported, unknown }

extension NutritionEstimateInputModalityContract
    on NutritionEstimateInputModality {
  String get stableId => name;

  static NutritionEstimateInputModality fromStableId(String value) {
    return NutritionEstimateInputModality.values.firstWhere(
      (modality) => modality.stableId == value,
      orElse: () => throw NutritionEstimateValidationError(
        'unsupported_input_modality',
        'Unsupported nutrition estimate input modality: $value.',
      ),
    );
  }
}

/// Only privacy-safe evidence is durable. This intentionally has no field for
/// prompt text, raw provider responses, image bytes, device paths, or secrets.
class NutritionEstimateEvidence {
  static const _allowedKeys = <String>{
    'provider_category',
    'input_modality',
    'user_description',
    'selected_candidate',
    'selected_candidate_id',
    'provider_request_id',
    'provider_response_id',
    'processing_status',
    'assumptions',
    'missing_evidence',
    'temporary_image_retained',
    'image_cleanup_status',
    'image_retention_notice',
    'captured_at_utc',
    'metadata',
  };

  static const _sensitiveFragments = <String>{
    'prompt',
    'response',
    'raw',
    'image',
    'photo',
    'path',
    'token',
    'secret',
    'password',
    'authorization',
    'api_key',
    'bytes',
  };

  final Map<String, dynamic> _data;

  NutritionEstimateEvidence._(Map<String, dynamic> data)
    : _data = Map.unmodifiable(data);

  factory NutritionEstimateEvidence({
    String? providerCategory,
    NutritionEstimateInputModality? inputModality,
    String? userDescription,
    String? selectedCandidate,
    String? selectedCandidateId,
    String? providerRequestId,
    String? providerResponseId,
    String? processingStatus,
    Iterable<String> assumptions = const <String>[],
    Iterable<String> missingEvidence = const <String>[],
    bool temporaryImageRetained = false,
    String? imageCleanupStatus,
    String? imageRetentionNotice,
    DateTime? capturedAtUtc,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    if (temporaryImageRetained) {
      throw const NutritionEstimatePrivacyError(
        'durable_image_forbidden',
        'Temporary estimate images are not durable evidence in B03-14.',
      );
    }
    final data = <String, dynamic>{
      'provider_category': ?providerCategory,
      'input_modality': ?inputModality?.stableId,
      'user_description': ?userDescription,
      'selected_candidate': ?selectedCandidate,
      'selected_candidate_id': ?selectedCandidateId,
      'provider_request_id': ?providerRequestId,
      'provider_response_id': ?providerResponseId,
      'processing_status': ?processingStatus,
      if (assumptions.isNotEmpty) 'assumptions': assumptions.toList(),
      if (missingEvidence.isNotEmpty)
        'missing_evidence': missingEvidence.toList(),
      'temporary_image_retained': false,
      'image_cleanup_status': ?imageCleanupStatus,
      'image_retention_notice': ?imageRetentionNotice,
      'captured_at_utc': ?capturedAtUtc?.toUtc().toIso8601String(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
    return NutritionEstimateEvidence._(_sanitize(data));
  }

  factory NutritionEstimateEvidence.fromJson(Object? raw) {
    if (raw is! Map || raw['contract_version'] != 1) {
      throw const NutritionEstimateValidationError(
        'unsupported_evidence_version',
        'Nutrition estimate evidence is malformed or unsupported.',
      );
    }
    final data = <String, dynamic>{
      for (final entry in raw.entries)
        if (entry.key != 'contract_version') entry.key.toString(): entry.value,
    };
    return NutritionEstimateEvidence._(_sanitize(data));
  }

  Map<String, dynamic> toJson() => {
    'contract_version': kNutritionEstimateContractVersion,
    ..._deepCopy(_data),
  };

  String? get inputModality => _data['input_modality'] as String?;
  String? get providerCategory => _data['provider_category'] as String?;
  bool get temporaryImageRetained => _data['temporary_image_retained'] == true;
  String? get imageCleanupStatus => _data['image_cleanup_status'] as String?;

  static Map<String, dynamic> _sanitize(Map<String, dynamic> value) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || !_allowedKeys.contains(key)) {
        throw NutritionEstimatePrivacyError(
          'unsupported_evidence_field',
          'Evidence field "$key" is not approved for durable storage.',
        );
      }
      final raw = entry.value;
      if (key == 'temporary_image_retained') {
        if (raw != false) {
          throw const NutritionEstimatePrivacyError(
            'durable_image_forbidden',
            'Temporary estimate images cannot be retained.',
          );
        }
        result[key] = false;
        continue;
      }
      if (key == 'assumptions' || key == 'missing_evidence') {
        if (raw is! List || raw.any((item) => item is! String)) {
          throw NutritionEstimatePrivacyError(
            'invalid_evidence_list',
            'Evidence field "$key" must contain strings.',
          );
        }
        result[key] = [
          for (final item in raw)
            _safeString(key, item as String, maxLength: 512),
        ];
        continue;
      }
      if (key == 'metadata') {
        if (raw is! Map) {
          throw const NutritionEstimatePrivacyError(
            'invalid_evidence_metadata',
            'Evidence metadata must be an object.',
          );
        }
        final metadata = <String, dynamic>{};
        for (final item in raw.entries) {
          if (item.key is! String || item.value is! String) {
            throw const NutritionEstimatePrivacyError(
              'invalid_evidence_metadata',
              'Evidence metadata must contain string keys and values.',
            );
          }
          final metadataKey = item.key as String;
          _rejectSensitiveKey(metadataKey);
          metadata[metadataKey] = _safeString(
            metadataKey,
            item.value as String,
            maxLength: 512,
          );
        }
        result[key] = metadata;
        continue;
      }
      if (key == 'input_modality') {
        if (raw is! String) {
          throw const NutritionEstimatePrivacyError(
            'invalid_input_modality',
            'Evidence input modality must be a supported stable value.',
          );
        }
        final modality = raw.trim();
        NutritionEstimateInputModalityContract.fromStableId(modality);
        result[key] = modality;
        continue;
      }
      if (raw is String) {
        result[key] = _safeString(key, raw, maxLength: 1000);
      } else if (raw is bool && key == 'temporary_image_retained') {
        result[key] = raw;
      } else {
        throw NutritionEstimatePrivacyError(
          'invalid_evidence_value',
          'Evidence field "$key" has an unsupported value.',
        );
      }
    }
    result['temporary_image_retained'] = false;
    return result;
  }

  static void _rejectSensitiveKey(String key) {
    if (_allowedKeys.contains(key)) return;
    final lowerKey = key.toLowerCase();
    if (_sensitiveFragments.any(lowerKey.contains)) {
      throw NutritionEstimatePrivacyError(
        'sensitive_evidence_field',
        'Evidence field "$key" is excluded by the privacy contract.',
      );
    }
  }

  static String _safeString(
    String key,
    String value, {
    required int maxLength,
  }) {
    _rejectSensitiveKey(key);
    final trimmed = value.trim();
    if (trimmed.length > maxLength) {
      throw NutritionEstimatePrivacyError(
        'evidence_too_large',
        'Evidence field "$key" exceeds the privacy-safe size limit.',
      );
    }
    return trimmed;
  }
}

/// A parsed, provider-neutral estimate waiting for a durable portable ID and
/// user scope. Provider response IDs can remain inside evidence, but never
/// become this object's identity.
class NutritionEstimateDraft {
  final String? subjectId;
  final String subjectType;
  final String displayLabel;
  final NutrientSourceType source;
  final String? provider;
  final String? model;
  final String? ruleVersion;
  final String? inputHash;
  final NutritionEstimateEvidence evidence;
  final NutrientConfidence confidence;
  final Quantity? quantity;
  final Map<String, NutrientFact> facts;
  final Set<String> requestedNutrientIds;
  final NutritionEstimateInputModality inputModality;

  NutritionEstimateDraft({
    required this.subjectId,
    required this.subjectType,
    required this.displayLabel,
    required this.source,
    required this.provider,
    required this.model,
    required this.ruleVersion,
    required this.inputHash,
    required this.evidence,
    required this.confidence,
    required this.quantity,
    required Map<String, NutrientFact> facts,
    required Iterable<String> requestedNutrientIds,
    required this.inputModality,
    required NutrientRegistry registry,
  }) : facts = Map.unmodifiable(facts),
       requestedNutrientIds = Set.unmodifiable(requestedNutrientIds.toSet()) {
    _validateCommon(
      registry: registry,
      subjectId: subjectId,
      subjectType: subjectType,
      displayLabel: displayLabel,
      facts: this.facts,
      requestedNutrientIds: this.requestedNutrientIds,
    );
    _validateEstimateMetadata(
      provider: provider,
      model: model,
      ruleVersion: ruleVersion,
      inputHash: inputHash,
    );
    if (quantity != null) {
      try {
        NutritionQuantityService.validatePositiveUserEnteredPortion(quantity!);
      } on QuantityError catch (error) {
        throw NutritionEstimateValidationError(
          'invalid_estimate_quantity',
          error.message,
        );
      }
    }
  }

  NutritionEstimate toEstimate({
    required String id,
    required String userId,
    DateTime? createdAtUtc,
    NutritionEstimateReviewState reviewState =
        NutritionEstimateReviewState.unreviewed,
    String? supersedesId,
    String? commandId,
    double? confidenceScore,
    NutrientRegistry? registry,
  }) {
    return NutritionEstimate(
      id: id,
      userId: userId,
      subjectId: subjectId,
      subjectType: subjectType,
      displayLabel: displayLabel,
      createdAtUtc: createdAtUtc ?? DateTime.now().toUtc(),
      source: source,
      provider: provider,
      model: model,
      ruleVersion: ruleVersion,
      inputHash: inputHash,
      evidence: evidence,
      confidence: confidence,
      confidenceScore: confidenceScore,
      reviewState: reviewState,
      recordStatus: recordStatusForFacts(facts),
      supersedesId: supersedesId,
      commandId: commandId,
      quantity: quantity,
      facts: facts,
      requestedNutrientIds: requestedNutrientIds,
      registry: registry,
    );
  }
}

enum NutritionEstimateRecordStatus { known, estimated, missing, superseded }

extension NutritionEstimateRecordStatusContract
    on NutritionEstimateRecordStatus {
  String get stableId => name;

  static NutritionEstimateRecordStatus fromStableId(String value) {
    return NutritionEstimateRecordStatus.values.firstWhere(
      (status) => status.stableId == value,
      orElse: () => throw NutritionEstimateValidationError(
        'unsupported_estimate_status',
        'Unsupported nutrition estimate status: $value.',
      ),
    );
  }
}

/// Immutable estimate identity plus all uncertainty and ancestry needed to
/// reconstruct a historical read without consulting a mutable provider.
class NutritionEstimate {
  final String id;
  final String userId;
  final String? subjectId;
  final String subjectType;
  final String displayLabel;
  final DateTime createdAtUtc;
  final NutrientSourceType source;
  final String? provider;
  final String? model;
  final String? ruleVersion;
  final String? inputHash;
  final NutritionEstimateEvidence evidence;
  final NutrientConfidence confidence;
  final double? confidenceScore;
  final NutritionEstimateReviewState reviewState;
  final NutritionEstimateRecordStatus recordStatus;
  final String? supersedesId;
  final String? ancestryRootId;
  final String? commandId;
  final Quantity? quantity;
  final Map<String, NutrientFact> facts;
  final Set<String> requestedNutrientIds;
  final NutrientCompleteness completeness;
  final String estimateVersion;
  final NutrientRegistry? registry;

  NutritionEstimate({
    required String id,
    required String userId,
    required this.subjectId,
    required String subjectType,
    required String displayLabel,
    required DateTime createdAtUtc,
    required this.source,
    required this.provider,
    required this.model,
    required this.ruleVersion,
    required this.inputHash,
    required this.evidence,
    required this.confidence,
    required this.confidenceScore,
    required this.reviewState,
    required this.recordStatus,
    required this.supersedesId,
    this.ancestryRootId,
    required this.commandId,
    required this.quantity,
    required Map<String, NutrientFact> facts,
    required Iterable<String> requestedNutrientIds,
    required this.registry,
    this.estimateVersion = '1',
  }) : id = id.trim(),
       userId = userId.trim(),
       subjectType = subjectType.trim(),
       displayLabel = displayLabel.trim(),
       createdAtUtc = createdAtUtc.toUtc(),
       facts = Map.unmodifiable(facts),
       requestedNutrientIds = Set.unmodifiable(requestedNutrientIds.toSet()),
       completeness = registry == null
           ? _fallbackCompleteness(facts, requestedNutrientIds)
           : NutrientCompletenessEvaluator.evaluate(
               registry: registry,
               facts: facts,
               requestedNutrientIds: requestedNutrientIds.toSet(),
             ) {
    _validateEstimate(
      id: this.id,
      userId: this.userId,
      subjectId: subjectId,
      subjectType: this.subjectType,
      displayLabel: this.displayLabel,
      provider: provider,
      model: model,
      ruleVersion: ruleVersion,
      inputHash: inputHash,
      confidenceScore: confidenceScore,
      supersedesId: supersedesId,
      ancestryRootId: ancestryRootId,
      quantity: quantity,
      estimateVersion: estimateVersion,
      facts: this.facts,
      requestedNutrientIds: this.requestedNutrientIds,
      registry: registry,
    );
  }

  bool get isRejected => reviewState == NutritionEstimateReviewState.rejected;
  bool get isSuperseded =>
      reviewState == NutritionEstimateReviewState.superseded ||
      recordStatus == NutritionEstimateRecordStatus.superseded;

  String get calculationFingerprint => _sha256({
    'estimate_version': estimateVersion,
    'source': source.stableId,
    'provider': provider,
    'model': model,
    'rule_version': ruleVersion,
    'input_hash': inputHash,
    'quantity': quantity?.toJson(),
    'requested': requestedNutrientIds.toList()..sort(),
    'facts': {
      for (final id in facts.keys.toList()..sort()) id: facts[id]!.toJson(),
    },
  });

  String get rootId => ancestryRootId ?? supersedesId ?? id;

  Map<String, dynamic> toPersistenceEnvelope({
    String? overrideReviewState,
    String? overrideCommandId,
    Map<String, dynamic>? correction,
  }) => {
    'contract_version': kNutritionEstimateContractVersion,
    'estimate_version': estimateVersion,
    'subject': {
      'type': subjectType,
      if (subjectId != null) 'id': subjectId,
      'label': displayLabel,
    },
    'review_state': overrideReviewState ?? reviewState.stableId,
    'confidence': confidence.stableId,
    'requested_nutrients': requestedNutrientIds.toList()..sort(),
    if (quantity != null) 'quantity': quantity!.toJson(),
    if (supersedesId != null)
      'correction_ancestry': {'supersedes_id': supersedesId, 'root_id': rootId},
    'evidence': evidence.toJson(),
    'facts': {
      for (final id in facts.keys.toList()..sort()) id: facts[id]!.toJson(),
    },
    'completeness': completeness.toJson(),
    'calculation_fingerprint': calculationFingerprint,
    if ((overrideCommandId ?? commandId) != null)
      'command_id': overrideCommandId ?? commandId,
    'correction': ?correction,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'source': source.stableId,
    if (provider != null) 'provider': provider,
    if (model != null) 'model': model,
    if (ruleVersion != null) 'rule_version': ruleVersion,
    if (inputHash != null) 'input_hash': inputHash,
    'assumptions': toPersistenceEnvelope(),
    'confidence': confidence.stableId,
    'status': recordStatus.stableId,
    if (supersedesId != null) 'supersedes_id': supersedesId,
    'created_at': createdAtUtc.toIso8601String(),
    'updated_at': createdAtUtc.toIso8601String(),
  };

  NutritionEstimate copyWith({
    NutritionEstimateReviewState? reviewState,
    NutritionEstimateRecordStatus? recordStatus,
    String? commandId,
  }) {
    return NutritionEstimate(
      id: id,
      userId: userId,
      subjectId: subjectId,
      subjectType: subjectType,
      displayLabel: displayLabel,
      createdAtUtc: createdAtUtc,
      source: source,
      provider: provider,
      model: model,
      ruleVersion: ruleVersion,
      inputHash: inputHash,
      evidence: evidence,
      confidence: confidence,
      confidenceScore: confidenceScore,
      reviewState: reviewState ?? this.reviewState,
      recordStatus: recordStatus ?? this.recordStatus,
      supersedesId: supersedesId,
      ancestryRootId: ancestryRootId,
      commandId: commandId ?? this.commandId,
      quantity: quantity,
      facts: facts,
      requestedNutrientIds: requestedNutrientIds,
      registry: registry,
      estimateVersion: estimateVersion,
    );
  }
}

/// A correction appends a new estimate record. Omitted nutrient IDs retain the
/// original fact and its evidence; they are never replaced by zero.
class NutritionEstimateCorrection {
  final String commandId;
  final String reason;
  final Map<String, NutrientFact> nutrientReplacements;
  final String? subjectId;
  final String? subjectType;
  final String? displayLabel;
  final Quantity? quantity;
  final bool replaceQuantity;
  final Map<String, dynamic> fieldUpdates;

  NutritionEstimateCorrection({
    required String commandId,
    required String reason,
    Map<String, NutrientFact> nutrientReplacements =
        const <String, NutrientFact>{},
    this.subjectId,
    this.subjectType,
    this.displayLabel,
    this.quantity,
    this.replaceQuantity = false,
    Map<String, dynamic> fieldUpdates = const <String, dynamic>{},
  }) : commandId = commandId.trim(),
       reason = reason.trim(),
       nutrientReplacements = Map.unmodifiable(nutrientReplacements),
       fieldUpdates = Map.unmodifiable(fieldUpdates) {
    if (this.commandId.isEmpty || this.reason.isEmpty) {
      throw const NutritionEstimateValidationError(
        'invalid_correction_command',
        'A correction requires a command ID and reason.',
      );
    }
  }
}

/// Strict parser for a provider-neutral estimate payload. It accepts no
/// network/provider behavior; callers decide how to obtain the raw object.
class NutritionEstimateResponseParser {
  const NutritionEstimateResponseParser();

  static NutritionEstimateDraft parse(
    Object? raw, {
    required NutrientRegistry registry,
  }) {
    if (raw is! Map) {
      throw const NutritionEstimateValidationError(
        'malformed_estimate_response',
        'Nutrition estimate response must be an object.',
      );
    }
    final json = Map<String, dynamic>.from(raw);
    final version = json['contract_version'];
    if (version != null &&
        version != kNutritionEstimateResponseContractVersion) {
      throw NutritionEstimateValidationError(
        'unsupported_estimate_response_version',
        'Unsupported nutrition estimate response version: $version.',
      );
    }
    final subject = json['subject'];
    if (subject is! Map) {
      throw const NutritionEstimateValidationError(
        'missing_estimate_subject',
        'Nutrition estimate response must identify its subject separately from its label.',
      );
    }
    final subjectMap = Map<String, dynamic>.from(subject);
    final subjectType = _requiredString(subjectMap, 'type');
    final displayLabel = _requiredString(subjectMap, 'label');
    final subjectId = _optionalString(subjectMap, 'id');

    final provenance = json['provenance'];
    if (provenance is! Map) {
      throw const NutritionEstimateValidationError(
        'missing_estimate_provenance',
        'Nutrition estimate response must include typed provenance.',
      );
    }
    final provenanceMap = Map<String, dynamic>.from(provenance);
    final source = _parseSource(_requiredString(provenanceMap, 'source'));
    final provider = _optionalString(provenanceMap, 'provider');
    final model = _optionalString(provenanceMap, 'model');
    final ruleVersion = _optionalString(provenanceMap, 'rule_version');
    final inputHash = _optionalString(provenanceMap, 'input_hash');
    final modalityValue =
        _optionalString(provenanceMap, 'input_modality') ?? 'unknown';
    final modality = NutritionEstimateInputModalityContract.fromStableId(
      modalityValue,
    );
    final confidence = NutrientConfidenceContract.fromStableId(
      _optionalString(provenanceMap, 'confidence') ?? 'unknown',
    );
    final evidence = NutritionEstimateEvidence(
      providerCategory: _optionalString(provenanceMap, 'provider_category'),
      inputModality: modality,
      userDescription: _optionalString(provenanceMap, 'user_description'),
      selectedCandidate: _optionalString(provenanceMap, 'selected_candidate'),
      selectedCandidateId: _optionalString(
        provenanceMap,
        'selected_candidate_id',
      ),
      providerRequestId: _optionalString(provenanceMap, 'provider_request_id'),
      providerResponseId: _optionalString(
        provenanceMap,
        'provider_response_id',
      ),
      processingStatus: _optionalString(provenanceMap, 'processing_status'),
      assumptions: _stringList(provenanceMap, 'assumptions'),
      missingEvidence: _stringList(provenanceMap, 'missing_evidence'),
      imageCleanupStatus: _optionalString(
        provenanceMap,
        'image_cleanup_status',
      ),
      imageRetentionNotice: _optionalString(
        provenanceMap,
        'image_retention_notice',
      ),
      capturedAtUtc: _optionalDate(provenanceMap, 'captured_at_utc'),
      metadata: _stringMetadata(provenanceMap['metadata']),
    );

    final rawNutrients = json['nutrients'];
    if (rawNutrients is! List || rawNutrients.isEmpty) {
      throw const NutritionEstimateValidationError(
        'missing_estimate_nutrients',
        'Nutrition estimate response must include at least one nutrient fact.',
      );
    }
    final facts = <String, NutrientFact>{};
    for (final rawNutrient in rawNutrients) {
      if (rawNutrient is! Map) {
        throw const NutritionEstimateValidationError(
          'malformed_estimate_nutrient',
          'Every nutrition estimate nutrient must be an object.',
        );
      }
      final nutrient = Map<String, dynamic>.from(rawNutrient);
      final nutrientId =
          _optionalString(nutrient, 'nutrient_id') ??
          _requiredString(nutrient, 'id');
      if (facts.containsKey(nutrientId)) {
        throw NutritionEstimateValidationError(
          'duplicate_estimate_nutrient',
          'Nutrient $nutrientId appears more than once.',
        );
      }
      final definition = registry.definitionFor(nutrientId);
      final unit = NutrientUnitContract.fromStableId(
        _optionalString(nutrient, 'unit') ?? definition.unit.stableId,
      );
      if (unit != definition.unit) {
        throw NutritionEstimateValidationError(
          'nutrient_unit_mismatch',
          'Nutrient $nutrientId uses an incompatible unit.',
        );
      }
      final point = _amount(nutrient['point'], unit);
      final lower = _amount(nutrient['lower'], unit);
      final upper = _amount(nutrient['upper'], unit);
      final inferredStatus = point == null && lower == null && upper == null
          ? NutrientFactStatus.missing
          : NutrientFactStatus.estimated;
      final status = nutrient['status'] is String
          ? NutrientFactStatusContract.fromStableId(
              nutrient['status'] as String,
            )
          : inferredStatus;
      if ((status == NutrientFactStatus.known ||
              status == NutrientFactStatus.knownZero) &&
          (source == NutrientSourceType.aiEstimate ||
              source == NutrientSourceType.importedProvider ||
              source == NutrientSourceType.heuristic ||
              source == NutrientSourceType.unknown)) {
        throw const NutritionEstimateValidationError(
          'unsubstantiated_exact_estimate',
          'Provider and heuristic estimates must remain visibly estimated.',
        );
      }
      final basis = _basis(nutrient['basis']);
      final fact = NutrientFact(
        nutrientId: nutrientId,
        unit: unit,
        status: status,
        point: point,
        lower: lower,
        upper: upper,
        basis: basis,
        source: _parseSource(
          _optionalString(nutrient, 'source') ?? source.stableId,
        ),
        sourceReference: _optionalString(nutrient, 'source_reference'),
        confidence: nutrient['confidence'] is String
            ? NutrientConfidenceContract.fromStableId(
                nutrient['confidence'] as String,
              )
            : confidence,
        factVersion:
            _optionalString(nutrient, 'fact_version') ??
            (ruleVersion ?? 'estimate-v1'),
        coverageIncomplete: nutrient['coverage_incomplete'] == true,
      );
      fact.validateAgainst(registry);
      facts[nutrientId] = fact;
    }

    final requested = _requested(json['requested_nutrients'], registry);
    final quantity = _quantity(json['quantity']);
    return NutritionEstimateDraft(
      subjectId: subjectId,
      subjectType: subjectType,
      displayLabel: displayLabel,
      source: source,
      provider: provider,
      model: model,
      ruleVersion: ruleVersion,
      inputHash: inputHash,
      evidence: evidence,
      confidence: confidence,
      quantity: quantity,
      facts: facts,
      requestedNutrientIds: requested,
      inputModality: modality,
      registry: registry,
    );
  }

  static NutritionEstimateDraft parseJson(
    String raw, {
    required NutrientRegistry registry,
  }) {
    try {
      return parse(jsonDecode(raw), registry: registry);
    } on NutritionEstimateError {
      rethrow;
    } catch (_) {
      throw NutritionEstimateValidationError(
        'malformed_estimate_json',
        'Nutrition estimate JSON could not be parsed.',
      );
    }
  }

  static NutrientSourceType _parseSource(String value) {
    return NutrientSourceContract.fromStableId(value);
  }

  static NutrientAmount? _amount(Object? raw, NutrientUnit unit) {
    if (raw == null) return null;
    try {
      final amount = raw is String
          ? QuantityAmount.fromString(raw)
          : raw is num
          ? QuantityAmount.fromNum(raw)
          : throw const InvalidQuantityAmountError(
              'Estimate nutrient values must be numeric.',
            );
      return NutrientAmount(value: amount, unit: unit);
    } on QuantityError catch (error) {
      throw NutritionEstimateValidationError(
        'invalid_estimate_value',
        error.message,
      );
    }
  }

  static NutrientBasis _basis(Object? raw) {
    if (raw == null) return NutrientBasis(NutrientBasisKind.absolute);
    if (raw is String) {
      return NutrientBasis(NutrientBasisContract.fromStableId(raw));
    }
    try {
      return NutrientBasis.fromJson(raw);
    } on NutrientError catch (error) {
      throw NutritionEstimateValidationError(
        'invalid_estimate_basis',
        error.message,
      );
    }
  }

  static Set<String> _requested(Object? raw, NutrientRegistry registry) {
    if (raw == null) return registry.definitions.map((item) => item.id).toSet();
    if (raw is! List || raw.any((value) => value is! String)) {
      throw const NutritionEstimateValidationError(
        'invalid_requested_nutrients',
        'requested_nutrients must contain nutrient IDs.',
      );
    }
    final ids = raw.cast<String>().toSet();
    for (final id in ids) {
      registry.definitionFor(id);
    }
    if (ids.isEmpty) {
      throw const NutritionEstimateValidationError(
        'invalid_requested_nutrients',
        'At least one requested nutrient is required.',
      );
    }
    return ids;
  }

  static Quantity? _quantity(Object? raw) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw const NutritionEstimateValidationError(
        'invalid_estimate_quantity',
        'Estimate quantity must be a typed quantity object.',
      );
    }
    try {
      return Quantity.fromJson(Map<String, dynamic>.from(raw));
    } catch (error) {
      throw NutritionEstimateValidationError(
        'invalid_estimate_quantity',
        'Estimate quantity is invalid: $error.',
      );
    }
  }
}

/// Short name retained for callers that describe the boundary as a parser.
class NutritionEstimateParser {
  const NutritionEstimateParser();

  static NutritionEstimateDraft parse(
    Object? raw, {
    required NutrientRegistry registry,
  }) => NutritionEstimateResponseParser.parse(raw, registry: registry);

  static NutritionEstimateDraft parseJson(
    String raw, {
    required NutrientRegistry registry,
  }) => NutritionEstimateResponseParser.parseJson(raw, registry: registry);
}

/// Compatibility adapter for the already-shipped AI screen response. It
/// converts the old flat point payload into typed `estimated` facts without
/// treating a provider candidate or display name as a durable identity.
class NutritionEstimateLegacyResponseAdapter {
  const NutritionEstimateLegacyResponseAdapter();

  static NutritionEstimateDraft fromResponse(
    Object? raw, {
    required NutrientRegistry registry,
    required NutritionEstimateInputModality inputModality,
    required String inputHash,
    String? userDescription,
  }) {
    if (raw is! Map) {
      throw const NutritionEstimateValidationError(
        'malformed_estimate_response',
        'The existing estimate response is not an object.',
      );
    }
    final json = Map<String, dynamic>.from(raw);
    final label = json['name'];
    if (label is! String || label.trim().isEmpty) {
      throw const NutritionEstimateValidationError(
        'missing_estimate_subject',
        'The existing estimate response has no display label.',
      );
    }
    final fallback = json['is_fallback'] == true;
    final confidence = fallback
        ? NutrientConfidence.unknown
        : NutrientConfidence.medium;
    final values = <String, Object?>{
      'energy': json['calories'],
      'protein': json['protein'],
      'carbohydrate': json['carbs'] ?? json['carbohydrate'],
      'fat': json['fat'],
    };
    final facts = <String, NutrientFact>{};
    for (final definition in registry.definitions) {
      final rawValue = values[definition.id];
      final source = NutrientSourceType.aiEstimate;
      if (rawValue == null) {
        facts[definition.id] = NutrientFact.missing(
          nutrientId: definition.id,
          unit: definition.unit,
          basis: NutrientBasis(NutrientBasisKind.absolute),
          source: source,
          sourceReference: 'legacy-ai-response-v1',
          confidence: confidence,
          factVersion: 'legacy-ai-response-v1',
        );
        continue;
      }
      final amount = rawValue is num
          ? rawValue
          : rawValue is String
          ? num.tryParse(rawValue)
          : null;
      if (amount == null || !amount.isFinite || amount < 0) {
        throw NutritionEstimateValidationError(
          'invalid_estimate_value',
          'The existing estimate has an invalid value for ${definition.id}.',
        );
      }
      facts[definition.id] = NutrientFact.estimated(
        nutrientId: definition.id,
        point: NutrientAmount(
          value: QuantityAmount.fromNum(amount),
          unit: definition.unit,
        ),
        basis: NutrientBasis(NutrientBasisKind.absolute),
        source: source,
        sourceReference: 'legacy-ai-response-v1',
        confidence: confidence,
        factVersion: 'legacy-ai-response-v1',
      );
    }
    final selectedCandidate = json['matched_food_id'];
    final evidence = NutritionEstimateEvidence(
      providerCategory: 'existing_ai_boundary',
      inputModality: inputModality,
      userDescription: userDescription,
      selectedCandidateId: selectedCandidate is String
          ? selectedCandidate
          : null,
      processingStatus: fallback ? 'fallback' : 'completed',
      assumptions: const [
        'The existing flat response has no defensible nutrient bounds.',
        'Provider candidate IDs are provenance only and are not food identity.',
      ],
      missingEvidence: const [
        'nutrient_bounds',
        'complete_micronutrient_coverage',
      ],
      imageRetentionNotice:
          inputModality == NutritionEstimateInputModality.photo
          ? 'Temporary photo is deleted after processing and is not backed up.'
          : null,
    );
    Quantity? quantity;
    final size = json['serving_size'];
    if (size is num && size.isFinite && size > 0) {
      quantity = Quantity.serving(
        amount: size.toString(),
        definition: const ServingDefinitionReference(
          id: 'legacy-ai-serving-v1',
          revision: '1',
        ),
        source: 'legacy-ai-response-v1',
        approximate: true,
      );
    }
    return NutritionEstimateDraft(
      subjectId: null,
      subjectType: 'meal_estimate',
      displayLabel: label.trim(),
      source: NutrientSourceType.aiEstimate,
      provider: 'existing_ai_boundary',
      model: json['model'] is String ? json['model'] as String : null,
      ruleVersion: 'legacy-ai-response-v1',
      inputHash: inputHash,
      evidence: evidence,
      confidence: confidence,
      quantity: quantity,
      facts: facts,
      requestedNutrientIds: registry.definitions.map((item) => item.id),
      inputModality: inputModality,
      registry: registry,
    );
  }
}

String nutritionEstimateInputHash(String value) =>
    sha256.convert(utf8.encode(value)).toString();

void _validateCommon({
  required NutrientRegistry registry,
  required String? subjectId,
  required String subjectType,
  required String displayLabel,
  required Map<String, NutrientFact> facts,
  required Set<String> requestedNutrientIds,
}) {
  if (subjectId != null && subjectId.trim().isEmpty) {
    throw const NutritionEstimateValidationError(
      'invalid_estimate_subject',
      'Estimate subject IDs cannot be blank.',
    );
  }
  if (subjectType.trim().isEmpty || displayLabel.trim().isEmpty) {
    throw const NutritionEstimateValidationError(
      'invalid_estimate_subject',
      'Estimate subject type and display label are required.',
    );
  }
  if (requestedNutrientIds.isEmpty) {
    throw const NutritionEstimateValidationError(
      'invalid_requested_nutrients',
      'At least one requested nutrient is required.',
    );
  }
  for (final id in requestedNutrientIds) {
    registry.definitionFor(id);
  }
  for (final entry in facts.entries) {
    if (entry.key != entry.value.nutrientId) {
      throw const NutritionEstimateValidationError(
        'nutrient_identity_mismatch',
        'Estimate nutrient map keys must match nutrient identities.',
      );
    }
    entry.value.validateAgainst(registry);
  }
}

void _validateEstimate({
  required String id,
  required String userId,
  required String? subjectId,
  required String subjectType,
  required String displayLabel,
  required String? provider,
  required String? model,
  required String? ruleVersion,
  required String? inputHash,
  required double? confidenceScore,
  required String? supersedesId,
  required String? ancestryRootId,
  required Quantity? quantity,
  required String estimateVersion,
  required Map<String, NutrientFact> facts,
  required Set<String> requestedNutrientIds,
  required NutrientRegistry? registry,
}) {
  if (id.isEmpty || userId.isEmpty) {
    throw const NutritionEstimateValidationError(
      'missing_estimate_identity',
      'Estimate and user IDs are required.',
    );
  }
  if (quantity != null) {
    try {
      NutritionQuantityService.validatePositiveUserEnteredPortion(quantity);
    } on QuantityError catch (error) {
      throw NutritionEstimateValidationError(
        'invalid_estimate_quantity',
        error.message,
      );
    }
  }
  if (subjectType.isEmpty || displayLabel.isEmpty) {
    throw const NutritionEstimateValidationError(
      'invalid_estimate_subject',
      'Estimate subject type and display label are required.',
    );
  }
  if (subjectId != null && subjectId.trim().isEmpty) {
    throw const NutritionEstimateValidationError(
      'invalid_estimate_subject',
      'Estimate subject IDs cannot be blank.',
    );
  }
  if (estimateVersion != '1') {
    throw NutritionEstimateValidationError(
      'unsupported_estimate_version',
      'Unsupported nutrition estimate version: $estimateVersion.',
    );
  }
  if (provider != null && provider.trim().isEmpty ||
      model != null && model.trim().isEmpty ||
      ruleVersion != null && ruleVersion.trim().isEmpty ||
      inputHash != null && inputHash.trim().isEmpty) {
    throw const NutritionEstimateValidationError(
      'invalid_estimate_metadata',
      'Estimate metadata cannot contain blank values.',
    );
  }
  _validateEstimateMetadata(
    provider: provider,
    model: model,
    ruleVersion: ruleVersion,
    inputHash: inputHash,
  );
  if (confidenceScore != null &&
      (!confidenceScore.isFinite ||
          confidenceScore < 0 ||
          confidenceScore > 1)) {
    throw const NutritionEstimateValidationError(
      'invalid_confidence',
      'Estimate confidence score must be finite and between zero and one.',
    );
  }
  if (supersedesId != null &&
      (supersedesId.trim().isEmpty || supersedesId == id)) {
    throw const NutritionEstimateValidationError(
      'invalid_estimate_ancestry',
      'An estimate cannot supersede itself or a blank ID.',
    );
  }
  if (ancestryRootId != null &&
      (supersedesId == null ||
          ancestryRootId.trim().isEmpty ||
          ancestryRootId == id)) {
    throw const NutritionEstimateValidationError(
      'invalid_estimate_ancestry',
      'An ancestry root requires a distinct superseded estimate.',
    );
  }
  if (registry != null) {
    _validateCommon(
      registry: registry,
      subjectId: subjectId,
      subjectType: subjectType,
      displayLabel: displayLabel,
      facts: facts,
      requestedNutrientIds: requestedNutrientIds,
    );
  }
}

void _validateEstimateMetadata({
  required String? provider,
  required String? model,
  required String? ruleVersion,
  required String? inputHash,
}) {
  const sensitiveMarkers = <String>{
    'prompt',
    'raw_response',
    'rawresponse',
    'access_token',
    'api_key',
    'image_path',
    'photo_path',
    'image_bytes',
    'authorization',
    'password',
    'secret',
    'token=',
  };
  final values = <String, String?>{
    'provider': provider,
    'model': model,
    'rule version': ruleVersion,
    'input hash': inputHash,
  };
  for (final entry in values.entries) {
    final value = entry.value?.trim();
    if (value == null) continue;
    if (value.length > 256) {
      throw NutritionEstimatePrivacyError(
        'estimate_metadata_too_large',
        'Estimate ${entry.key} metadata exceeds the privacy-safe size limit.',
      );
    }
    final lower = value.toLowerCase();
    if (sensitiveMarkers.any(lower.contains)) {
      throw NutritionEstimatePrivacyError(
        'sensitive_estimate_metadata',
        'Estimate ${entry.key} metadata contains excluded sensitive content.',
      );
    }
  }
}

NutritionEstimateRecordStatus recordStatusForFacts(
  Map<String, NutrientFact> facts,
) {
  if (facts.values.any((fact) => fact.status == NutrientFactStatus.estimated)) {
    return NutritionEstimateRecordStatus.estimated;
  }
  if (facts.values.any((fact) => fact.isAvailable)) {
    return NutritionEstimateRecordStatus.known;
  }
  return NutritionEstimateRecordStatus.missing;
}

NutrientCompleteness _fallbackCompleteness(
  Map<String, NutrientFact> facts,
  Iterable<String> requested,
) {
  final requestedIds = requested.toSet();
  final available = <String>{};
  final missing = <String>{};
  final estimated = <String>{};
  final notApplicable = <String>{};
  for (final id in requestedIds) {
    final fact = facts[id];
    if (fact == null || fact.status == NutrientFactStatus.missing) {
      missing.add(id);
    } else if (fact.status == NutrientFactStatus.notApplicable) {
      notApplicable.add(id);
    } else if (fact.isAvailable) {
      available.add(id);
      if (fact.status == NutrientFactStatus.estimated) estimated.add(id);
    } else {
      missing.add(id);
    }
  }
  return NutrientCompleteness(
    state: available.isEmpty
        ? NutrientCompletenessState.unknown
        : missing.isNotEmpty
        ? NutrientCompletenessState.partial
        : NutrientCompletenessState.complete,
    requestedNutrientIds: requestedIds,
    availableNutrientIds: available,
    missingNutrientIds: missing,
    estimatedNutrientIds: estimated,
    notApplicableNutrientIds: notApplicable,
    partiallyKnownNutrientIds: const {},
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw NutritionEstimateValidationError(
      'missing_estimate_field',
      'Estimate field "$key" must be a non-empty string.',
    );
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw NutritionEstimateValidationError(
      'invalid_estimate_field',
      'Estimate field "$key" must be a non-empty string when present.',
    );
  }
  return value.trim();
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const <String>[];
  if (value is! List || value.any((item) => item is! String)) {
    throw NutritionEstimateValidationError(
      'invalid_estimate_field',
      'Estimate field "$key" must contain strings.',
    );
  }
  return value.cast<String>();
}

Map<String, String> _stringMetadata(Object? raw) {
  if (raw == null) return const <String, String>{};
  if (raw is! Map || raw.entries.any((entry) => entry.value is! String)) {
    throw const NutritionEstimateValidationError(
      'invalid_estimate_metadata',
      'Estimate metadata must contain string values.',
    );
  }
  return {
    for (final entry in raw.entries)
      entry.key.toString(): entry.value as String,
  };
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  try {
    return DateTime.parse(value).toUtc();
  } catch (_) {
    throw NutritionEstimateValidationError(
      'invalid_estimate_timestamp',
      'Estimate field "$key" is not an ISO timestamp.',
    );
  }
}

Map<String, dynamic> _deepCopy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

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
