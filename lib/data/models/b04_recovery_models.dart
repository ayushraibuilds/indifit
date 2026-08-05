import 'dart:convert';

import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';

const String kB04ReadinessCalculationVersion = 'B04-06-READINESS-V1';

enum RecoveryObservationStatus { known, estimated, missing, unknown, invalid }

extension RecoveryObservationStatusId on RecoveryObservationStatus {
  String get stableId => name;

  static RecoveryObservationStatus parse(String value) => switch (value) {
    'known' => RecoveryObservationStatus.known,
    'estimated' => RecoveryObservationStatus.estimated,
    'missing' => RecoveryObservationStatus.missing,
    'unknown' => RecoveryObservationStatus.unknown,
    'invalid' => RecoveryObservationStatus.invalid,
    _ => throw const B04RecoveryValidationError(
      'invalid_observation_status',
      'Recovery observation status is not supported.',
    ),
  };
}

enum RecoveryFreshness { fresh, stale, unknown }

extension RecoveryFreshnessId on RecoveryFreshness {
  String get stableId => name;

  static RecoveryFreshness parse(String value) => switch (value) {
    'fresh' => RecoveryFreshness.fresh,
    'stale' => RecoveryFreshness.stale,
    'unknown' => RecoveryFreshness.unknown,
    _ => throw const B04RecoveryValidationError(
      'invalid_observation_freshness',
      'Recovery observation freshness is not supported.',
    ),
  };
}

/// Permission is kept separate from the observation status. A denied provider
/// is a visible unavailable input, never a numeric measurement.
enum RecoveryPermissionState {
  granted,
  denied,
  unavailable,
  unknown,
  notApplicable,
}

extension RecoveryPermissionStateId on RecoveryPermissionState {
  String get stableId => switch (this) {
    RecoveryPermissionState.granted => 'granted',
    RecoveryPermissionState.denied => 'denied',
    RecoveryPermissionState.unavailable => 'unavailable',
    RecoveryPermissionState.unknown => 'unknown',
    RecoveryPermissionState.notApplicable => 'not_applicable',
  };

  static RecoveryPermissionState parse(String value) => switch (value) {
    'granted' => RecoveryPermissionState.granted,
    'denied' => RecoveryPermissionState.denied,
    'unavailable' => RecoveryPermissionState.unavailable,
    'unknown' => RecoveryPermissionState.unknown,
    'not_applicable' => RecoveryPermissionState.notApplicable,
    _ => throw const B04RecoveryValidationError(
      'invalid_permission_state',
      'Recovery permission state is not supported.',
    ),
  };
}

enum ReadinessCompleteness { complete, incomplete, unknown }

extension ReadinessCompletenessId on ReadinessCompleteness {
  String get stableId => name;

  static ReadinessCompleteness parse(String value) => switch (value) {
    'complete' => ReadinessCompleteness.complete,
    'incomplete' => ReadinessCompleteness.incomplete,
    'unknown' => ReadinessCompleteness.unknown,
    _ => throw const B04RecoveryValidationError(
      'invalid_readiness_completeness',
      'Readiness completeness is not supported.',
    ),
  };
}

enum ReadinessStatus { available, cautious, unavailable }

extension ReadinessStatusId on ReadinessStatus {
  String get stableId => name;

  static ReadinessStatus parse(String value) => switch (value) {
    'available' => ReadinessStatus.available,
    'cautious' => ReadinessStatus.cautious,
    'unavailable' => ReadinessStatus.unavailable,
    _ => throw const B04RecoveryValidationError(
      'invalid_readiness_status',
      'Readiness status is not supported.',
    ),
  };
}

enum ReadinessBand { ready, cautious, unknown }

extension ReadinessBandId on ReadinessBand {
  String get stableId => name;

  static ReadinessBand parse(String value) => switch (value) {
    'ready' => ReadinessBand.ready,
    'cautious' => ReadinessBand.cautious,
    'unknown' => ReadinessBand.unknown,
    _ => throw const B04RecoveryValidationError(
      'invalid_readiness_band',
      'Readiness band is not supported.',
    ),
  };
}

/// A small, portable provenance envelope. It intentionally contains no raw
/// provider payload, prompt, image or health record body.
class RecoveryProvenance {
  static const int contractVersion = 1;

  final String reference;
  final RecoveryPermissionState permission;
  final String? providerExternalId;
  final String? sourceVersion;
  final String? correctionOfObservationId;

  const RecoveryProvenance({
    required this.reference,
    required this.permission,
    required this.providerExternalId,
    required this.sourceVersion,
    this.correctionOfObservationId,
  });

  Map<String, dynamic> toJson() => {
    'contract_version': contractVersion,
    'permission': permission.stableId,
    'reference': reference,
    if (providerExternalId != null) 'provider_external_id': providerExternalId,
    if (sourceVersion != null) 'source_version': sourceVersion,
    if (correctionOfObservationId != null)
      'correction_of_observation_id': correctionOfObservationId,
  };

  String encode() => jsonEncode(toJson());

  /// Provider provenance is an opaque reference, not a serialized provider
  /// response. Structured JSON is rejected at the B04 import boundary so raw
  /// health payloads cannot be persisted inside the reference field.
  static void validateReference(String value) {
    final reference = value.trim();
    if (reference.isEmpty) {
      throw const B04RecoveryValidationError(
        'missing_provenance_reference',
        'Recovery provenance requires an opaque source reference.',
      );
    }
    try {
      final decoded = jsonDecode(reference);
      if (decoded is! String) {
        throw const B04RecoveryValidationError(
          'provenance_payload_not_allowed',
          'Recovery provenance must be an opaque reference, not a provider payload.',
        );
      }
    } on B04RecoveryValidationError {
      rethrow;
    } on FormatException {
      // Ordinary opaque identifiers are not JSON and are accepted.
    }
  }

  factory RecoveryProvenance.decode(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) throw const FormatException();
      final json = Map<String, dynamic>.from(decoded);
      const allowedKeys = {
        'contract_version',
        'permission',
        'reference',
        'provider_external_id',
        'source_version',
        'correction_of_observation_id',
      };
      if (json['contract_version'] != contractVersion ||
          json['reference'] is! String ||
          (json['reference'] as String).trim().isEmpty ||
          json['permission'] is! String ||
          json.keys.any((key) => !allowedKeys.contains(key))) {
        throw const FormatException();
      }
      return RecoveryProvenance(
        reference: (json['reference'] as String).trim(),
        permission: RecoveryPermissionStateId.parse(
          json['permission'] as String,
        ),
        providerExternalId: _optionalString(json['provider_external_id']),
        sourceVersion: _optionalString(json['source_version']),
        correctionOfObservationId: _optionalString(
          json['correction_of_observation_id'],
        ),
      );
    } on B04RecoveryValidationError {
      rethrow;
    } catch (_) {
      throw const B04RecoveryValidationError(
        'invalid_provenance_envelope',
        'Recovery provenance is not a supported typed envelope.',
      );
    }
  }

  static RecoveryProvenance fromStored({
    required String encoded,
    required RecoveryPermissionState fallbackPermission,
    required String? providerExternalId,
    required String? sourceVersion,
  }) {
    try {
      return RecoveryProvenance.decode(encoded);
    } on B04RecoveryValidationError {
      // v18/v9 accepted fixtures can contain an opaque provenance reference.
      // Preserve it while making permission visible as unknown/fallback.
      validateReference(encoded);
      return RecoveryProvenance(
        reference: encoded,
        permission: fallbackPermission,
        providerExternalId: providerExternalId,
        sourceVersion: sourceVersion,
        correctionOfObservationId: null,
      );
    }
  }

  static String? _optionalString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }
}

class RecoveryObservationInput {
  final String? id;
  final String userId;
  final String kind;
  final DateTime observedAtUtc;
  final String timezoneId;
  final RecoveryObservationStatus status;
  final String unit;
  final double? value;
  final double? lower;
  final double? upper;
  final String source;
  final String provenance;
  final RecoveryPermissionState permission;
  final RecoveryFreshness freshness;
  final String? providerExternalId;
  final String? sourceVersion;
  final String? correctionOfObservationId;
  final DateTime? evidenceTimestampUtc;

  const RecoveryObservationInput({
    this.id,
    required this.userId,
    required this.kind,
    required this.observedAtUtc,
    required this.timezoneId,
    required this.status,
    required this.unit,
    this.value,
    this.lower,
    this.upper,
    required this.source,
    required this.provenance,
    required this.permission,
    required this.freshness,
    this.providerExternalId,
    this.sourceVersion,
    this.correctionOfObservationId,
    this.evidenceTimestampUtc,
  });

  RecoveryObservationInput copyWith({
    String? id,
    String? userId,
    String? kind,
    DateTime? observedAtUtc,
    String? timezoneId,
    RecoveryObservationStatus? status,
    String? unit,
    double? value,
    double? lower,
    double? upper,
    String? source,
    String? provenance,
    RecoveryPermissionState? permission,
    RecoveryFreshness? freshness,
    String? providerExternalId,
    String? sourceVersion,
    String? correctionOfObservationId,
    DateTime? evidenceTimestampUtc,
  }) => RecoveryObservationInput(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    kind: kind ?? this.kind,
    observedAtUtc: observedAtUtc ?? this.observedAtUtc,
    timezoneId: timezoneId ?? this.timezoneId,
    status: status ?? this.status,
    unit: unit ?? this.unit,
    value: value ?? this.value,
    lower: lower ?? this.lower,
    upper: upper ?? this.upper,
    source: source ?? this.source,
    provenance: provenance ?? this.provenance,
    permission: permission ?? this.permission,
    freshness: freshness ?? this.freshness,
    providerExternalId: providerExternalId ?? this.providerExternalId,
    sourceVersion: sourceVersion ?? this.sourceVersion,
    correctionOfObservationId:
        correctionOfObservationId ?? this.correctionOfObservationId,
    evidenceTimestampUtc: evidenceTimestampUtc ?? this.evidenceTimestampUtc,
  );
}

class RecoveryObservationReadModel {
  final String id;
  final String userId;
  final String kind;
  final DateTime observedAtUtc;
  final String localDate;
  final String timezoneId;
  final RecoveryObservationStatus status;
  final String unit;
  final double? value;
  final double? lower;
  final double? upper;
  final String source;
  final String provenance;
  final RecoveryProvenance provenanceEnvelope;
  final RecoveryPermissionState permission;
  final RecoveryFreshness freshness;
  final String? providerExternalId;
  final String? sourceVersion;
  final String? correctionOfObservationId;
  final DateTime? evidenceTimestampUtc;
  final DateTime createdAtUtc;

  const RecoveryObservationReadModel({
    required this.id,
    required this.userId,
    required this.kind,
    required this.observedAtUtc,
    required this.localDate,
    required this.timezoneId,
    required this.status,
    required this.unit,
    required this.value,
    required this.lower,
    required this.upper,
    required this.source,
    required this.provenance,
    required this.provenanceEnvelope,
    required this.permission,
    required this.freshness,
    required this.providerExternalId,
    required this.sourceVersion,
    required this.correctionOfObservationId,
    required this.evidenceTimestampUtc,
    required this.createdAtUtc,
  });

  bool get hasRange => lower != null || upper != null;

  bool get hasNumericEvidence =>
      value != null || lower != null || upper != null;

  String get contentFingerprint => _stableFingerprint([
    userId,
    kind,
    observedAtUtc.toUtc().toIso8601String(),
    localDate,
    timezoneId,
    status.stableId,
    unit,
    _number(value),
    _number(lower),
    _number(upper),
    source,
    provenance,
    permission.stableId,
    freshness.stableId,
    providerExternalId ?? '',
    sourceVersion ?? '',
    correctionOfObservationId ?? '',
    evidenceTimestampUtc?.toUtc().toIso8601String() ?? '',
  ]);
}

String b04RecoveryEvidenceFingerprint(
  Iterable<RecoveryObservationReadModel> observations,
) {
  final ordered = observations.toList()..sort((a, b) => a.id.compareTo(b.id));
  return _stableFingerprint([
    for (final observation in ordered) observation.id,
    for (final observation in ordered) observation.contentFingerprint,
  ]);
}

String b04ReadinessEvaluationFingerprint(
  Iterable<RecoveryObservationReadModel> observations,
  Iterable<String> requiredKinds,
) {
  final kinds =
      requiredKinds
          .map((kind) => kind.trim())
          .where((kind) => kind.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return _stableFingerprint([
    'readiness-evaluation-v1',
    b04RecoveryEvidenceFingerprint(observations),
    ...kinds,
  ]);
}

class ReadinessSnapshotEvidenceReadModel {
  final String id;
  final String readinessSnapshotId;
  final String observationId;
  final String evidenceKind;
  final RecoveryObservationStatus status;
  final double? value;
  final double? lower;
  final double? upper;
  final String? unit;
  final String? sourceVersion;

  const ReadinessSnapshotEvidenceReadModel({
    required this.id,
    required this.readinessSnapshotId,
    required this.observationId,
    required this.evidenceKind,
    required this.status,
    required this.value,
    required this.lower,
    required this.upper,
    required this.unit,
    required this.sourceVersion,
  });
}

class ReadinessSnapshotReadModel {
  final String id;
  final String userId;
  final String localDate;
  final String timezoneId;
  final ReadinessCompleteness completeness;
  final ReadinessStatus status;
  final ReadinessBand? band;
  final double? confidence;
  final String calculationVersion;
  final String policyVersion;
  final String? unavailableReason;
  final String? evidenceFingerprint;
  final DateTime createdAtUtc;
  final DateTime? supersededAtUtc;
  final String? supersedesSnapshotId;
  final List<ReadinessSnapshotEvidenceReadModel> evidence;

  const ReadinessSnapshotReadModel({
    required this.id,
    required this.userId,
    required this.localDate,
    required this.timezoneId,
    required this.completeness,
    required this.status,
    required this.band,
    required this.confidence,
    required this.calculationVersion,
    required this.policyVersion,
    required this.unavailableReason,
    required this.evidenceFingerprint,
    required this.createdAtUtc,
    required this.supersededAtUtc,
    required this.supersedesSnapshotId,
    this.evidence = const [],
  });

  List<String> get evidenceObservationIds =>
      List.unmodifiable(evidence.map((item) => item.observationId));
}

class ReadinessNumericalEffect {
  final int calorieDeltaKcal;
  final int trainingLoadDeltaPercent;
  final int trainingIntensityDeltaPercent;
  final int scheduleDurationDelta;
  final bool numericalProposalAllowed;
  final bool descriptiveCoachingAllowed;

  const ReadinessNumericalEffect._({
    required this.calorieDeltaKcal,
    required this.trainingLoadDeltaPercent,
    required this.trainingIntensityDeltaPercent,
    required this.scheduleDurationDelta,
    required this.numericalProposalAllowed,
    required this.descriptiveCoachingAllowed,
  });

  static const hold = ReadinessNumericalEffect._(
    calorieDeltaKcal: 0,
    trainingLoadDeltaPercent: 0,
    trainingIntensityDeltaPercent: 0,
    scheduleDurationDelta: 0,
    numericalProposalAllowed: false,
    descriptiveCoachingAllowed: true,
  );
}

class ReadinessEvaluationRequest {
  final String snapshotId;
  final String userId;
  final String localDate;
  final String timezoneId;
  final List<String> requiredKinds;
  final List<RecoveryObservationReadModel> observations;
  final String calculationVersion;
  final String policyVersion;
  final String? supersedesSnapshotId;
  final DateTime createdAtUtc;

  const ReadinessEvaluationRequest({
    required this.snapshotId,
    required this.userId,
    required this.localDate,
    required this.timezoneId,
    required this.requiredKinds,
    required this.observations,
    this.calculationVersion = kB04ReadinessCalculationVersion,
    this.policyVersion = kB04ReadinessHoldPolicyVersion,
    this.supersedesSnapshotId,
    required this.createdAtUtc,
  });

  ReadinessEvaluationRequest copyWith({
    String? snapshotId,
    String? userId,
    String? localDate,
    String? timezoneId,
    List<String>? requiredKinds,
    List<RecoveryObservationReadModel>? observations,
    String? calculationVersion,
    String? policyVersion,
    String? supersedesSnapshotId,
    DateTime? createdAtUtc,
  }) => ReadinessEvaluationRequest(
    snapshotId: snapshotId ?? this.snapshotId,
    userId: userId ?? this.userId,
    localDate: localDate ?? this.localDate,
    timezoneId: timezoneId ?? this.timezoneId,
    requiredKinds: requiredKinds ?? this.requiredKinds,
    observations: observations ?? this.observations,
    calculationVersion: calculationVersion ?? this.calculationVersion,
    policyVersion: policyVersion ?? this.policyVersion,
    supersedesSnapshotId: supersedesSnapshotId ?? this.supersedesSnapshotId,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
}

class ReadinessEvaluationResult {
  final ReadinessSnapshotReadModel snapshot;
  final ReadinessNumericalEffect numericalEffect;

  const ReadinessEvaluationResult({
    required this.snapshot,
    required this.numericalEffect,
  });

  bool get descriptiveCoachingAllowed =>
      numericalEffect.descriptiveCoachingAllowed;
}

class B04RecoveryValidationError implements Exception {
  final String code;
  final String message;

  const B04RecoveryValidationError(this.code, this.message);

  @override
  String toString() => 'B04RecoveryValidationError($code): $message';
}

class B04RecoveryConflictError extends B04RecoveryValidationError {
  const B04RecoveryConflictError(super.code, super.message);
}

class B04NoReadinessEvidenceError extends B04RecoveryValidationError {
  const B04NoReadinessEvidenceError()
    : super(
        'no_readiness_evidence',
        'Readiness cannot be backfilled without at least one observation.',
      );
}

String _number(double? value) => value?.toString() ?? '';

String _stableFingerprint(Iterable<String> values) {
  // This is a deterministic, local identity rather than a provider payload.
  final joined = values.join('\u001f');
  var hash = 2166136261;
  for (final unit in utf8.encode(joined)) {
    hash ^= unit;
    hash = (hash * 16777619) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
