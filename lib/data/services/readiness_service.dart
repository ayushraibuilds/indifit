import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../models/b04_recovery_models.dart';

/// Pure B04-06 readiness evaluator.
///
/// This service evaluates only explicitly supplied recovery observations. It
/// has no schedule/activity input and therefore cannot infer readiness from a
/// workout calendar or performed activity. It does not calculate a clinical
/// score or an adaptive target.
class ReadinessService {
  final LocalScheduleDateService _dates;

  ReadinessService({LocalScheduleDateService? dates})
    : _dates = dates ?? LocalScheduleDateService();

  ReadinessEvaluationResult evaluate(ReadinessEvaluationRequest request) {
    _validateRequest(request);
    final observations = [...request.observations]
      ..sort((a, b) {
        final byKind = a.kind.compareTo(b.kind);
        if (byKind != 0) return byKind;
        final byTime = a.observedAtUtc.compareTo(b.observedAtUtc);
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      });
    final evidence = [
      for (final observation in observations)
        ReadinessSnapshotEvidenceReadModel(
          id: '${request.snapshotId}:evidence:${observation.id}',
          readinessSnapshotId: request.snapshotId,
          observationId: observation.id,
          evidenceKind: observation.kind,
          status: observation.status,
          value: observation.value,
          lower: observation.lower,
          upper: observation.upper,
          unit: observation.unit,
          sourceVersion: observation.sourceVersion,
        ),
    ];
    final fingerprint = b04RecoveryEvidenceFingerprint(observations);
    final groups = <String, List<RecoveryObservationReadModel>>{};
    for (final observation in observations) {
      groups.putIfAbsent(observation.kind, () => []).add(observation);
    }

    final requiredKinds = request.requiredKinds
        .map((kind) => kind.trim())
        .toSet();
    final missing =
        requiredKinds.where((kind) => !groups.containsKey(kind)).toList()
          ..sort();
    final conflicting = requiredKinds.where((kind) {
      final candidates = groups[kind];
      if (candidates == null || candidates.length < 2) return false;
      return candidates.map((item) => item.contentFingerprint).toSet().length >
          1;
    }).toList()..sort();

    ReadinessCompleteness completeness;
    ReadinessStatus status;
    ReadinessBand band;
    double? confidence;
    String? unavailableReason;

    if (observations.isEmpty) {
      completeness = ReadinessCompleteness.unknown;
      status = ReadinessStatus.unavailable;
      band = ReadinessBand.unknown;
      confidence = null;
      unavailableReason = 'no_recovery_evidence';
    } else if (conflicting.isNotEmpty) {
      completeness = ReadinessCompleteness.unknown;
      status = ReadinessStatus.unavailable;
      band = ReadinessBand.unknown;
      confidence = null;
      unavailableReason = 'conflicting_evidence:${conflicting.join(',')}';
    } else if (missing.isNotEmpty) {
      completeness = ReadinessCompleteness.incomplete;
      status = ReadinessStatus.unavailable;
      band = ReadinessBand.unknown;
      confidence = null;
      unavailableReason = 'missing_required_evidence:${missing.join(',')}';
    } else {
      final required = [for (final kind in requiredKinds) groups[kind]!.first];
      final permissionDenied = required.where(
        (item) => item.permission == RecoveryPermissionState.denied,
      );
      final permissionUnavailable = required.where(
        (item) => item.permission == RecoveryPermissionState.unavailable,
      );
      final permissionUnknown = required.where(
        (item) => item.permission == RecoveryPermissionState.unknown,
      );
      final stale = required.where(
        (item) => item.freshness == RecoveryFreshness.stale,
      );
      final freshnessUnknown = required.where(
        (item) => item.freshness == RecoveryFreshness.unknown,
      );
      final invalid = required.where(
        (item) => item.status == RecoveryObservationStatus.invalid,
      );
      final missingStatus = required.where(
        (item) =>
            item.status == RecoveryObservationStatus.missing ||
            item.status == RecoveryObservationStatus.unknown,
      );

      if (permissionDenied.isNotEmpty) {
        completeness = ReadinessCompleteness.unknown;
        status = ReadinessStatus.unavailable;
        band = ReadinessBand.unknown;
        confidence = null;
        unavailableReason = 'permission_denied';
      } else if (permissionUnavailable.isNotEmpty) {
        completeness = ReadinessCompleteness.unknown;
        status = ReadinessStatus.unavailable;
        band = ReadinessBand.unknown;
        confidence = null;
        unavailableReason = 'provider_unavailable';
      } else if (permissionUnknown.isNotEmpty) {
        completeness = ReadinessCompleteness.unknown;
        status = ReadinessStatus.unavailable;
        band = ReadinessBand.unknown;
        confidence = null;
        unavailableReason = 'permission_unknown';
      } else if (stale.isNotEmpty) {
        completeness = ReadinessCompleteness.incomplete;
        status = ReadinessStatus.unavailable;
        band = ReadinessBand.unknown;
        confidence = null;
        unavailableReason = 'stale_evidence';
      } else if (freshnessUnknown.isNotEmpty) {
        completeness = ReadinessCompleteness.incomplete;
        status = ReadinessStatus.unavailable;
        band = ReadinessBand.unknown;
        confidence = null;
        unavailableReason = 'freshness_unknown';
      } else if (invalid.isNotEmpty) {
        completeness = ReadinessCompleteness.unknown;
        status = ReadinessStatus.unavailable;
        band = ReadinessBand.unknown;
        confidence = null;
        unavailableReason = 'invalid_evidence';
      } else if (missingStatus.isNotEmpty) {
        completeness = ReadinessCompleteness.incomplete;
        status = ReadinessStatus.unavailable;
        band = ReadinessBand.unknown;
        confidence = null;
        unavailableReason = 'missing_or_unknown_evidence';
      } else {
        final cautious = required.any(
          (item) =>
              item.status == RecoveryObservationStatus.estimated ||
              item.hasRange,
        );
        completeness = ReadinessCompleteness.complete;
        status = cautious
            ? ReadinessStatus.cautious
            : ReadinessStatus.available;
        band = cautious ? ReadinessBand.cautious : ReadinessBand.ready;
        // This is confidence in evidence completeness, not a health score.
        confidence = cautious ? 0.5 : 1.0;
        unavailableReason = null;
      }
    }

    return ReadinessEvaluationResult(
      snapshot: ReadinessSnapshotReadModel(
        id: request.snapshotId,
        userId: request.userId.trim(),
        localDate: _dates.normalizeLocalDate(request.localDate),
        timezoneId: request.timezoneId.trim(),
        completeness: completeness,
        status: status,
        band: band,
        confidence: confidence,
        calculationVersion: request.calculationVersion.trim(),
        policyVersion: request.policyVersion.trim(),
        unavailableReason: unavailableReason,
        evidenceFingerprint: observations.isEmpty ? null : fingerprint,
        createdAtUtc: request.createdAtUtc.toUtc(),
        supersededAtUtc: null,
        supersedesSnapshotId: request.supersedesSnapshotId,
        evidence: List.unmodifiable(evidence),
      ),
      // D04-READINESS-HOLD-1 is enforced independently of completeness and
      // status. Even a complete observation set has no numerical effect.
      numericalEffect: ReadinessNumericalEffect.hold,
    );
  }

  void _validateRequest(ReadinessEvaluationRequest request) {
    if (request.snapshotId.trim().isEmpty || request.userId.trim().isEmpty) {
      throw const B04RecoveryValidationError(
        'missing_readiness_identity',
        'A readiness snapshot requires a portable ID and user owner.',
      );
    }
    if (request.policyVersion != kB04ReadinessHoldPolicyVersion) {
      throw const B04RecoveryValidationError(
        'readiness_policy_hold_required',
        'Readiness numerical behavior remains under READINESS-HOLD-1.',
      );
    }
    if (request.calculationVersion.trim().isEmpty) {
      throw const B04RecoveryValidationError(
        'missing_readiness_calculation_version',
        'Readiness snapshots require a calculation version.',
      );
    }
    if (!request.createdAtUtc.isUtc) {
      throw const B04RecoveryValidationError(
        'readiness_timestamp_not_utc',
        'Readiness snapshot timestamps must be explicit UTC instants.',
      );
    }
    _dates.normalizeLocalDate(request.localDate);
    _dates.validateTimezone(request.timezoneId);
    final required = request.requiredKinds
        .map((kind) => kind.trim())
        .where((kind) => kind.isNotEmpty)
        .toList();
    if (required.isEmpty || required.toSet().length != required.length) {
      throw const B04RecoveryValidationError(
        'invalid_required_readiness_inputs',
        'Readiness requires a non-empty, unique set of input kinds.',
      );
    }
    final owner = request.userId.trim();
    final localDate = _dates.normalizeLocalDate(request.localDate);
    final timezone = request.timezoneId.trim();
    for (final observation in request.observations) {
      if (observation.userId != owner ||
          observation.localDate != localDate ||
          observation.timezoneId != timezone) {
        throw const B04RecoveryValidationError(
          'readiness_evidence_context_mismatch',
          'Readiness evidence must retain its recorded user, local date and IANA timezone.',
        );
      }
    }
  }
}
