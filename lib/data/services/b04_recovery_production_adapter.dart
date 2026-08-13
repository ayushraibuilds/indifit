import 'package:crypto/crypto.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/services/local_schedule_date_service.dart';
import '../models/b02_progress_read_models.dart';
import '../models/b04_recovery_models.dart';
import '../repositories/b02_progress_read_repository.dart';
import '../repositories/health_service.dart';
import '../repositories/readiness_snapshot_repository.dart';
import '../repositories/recovery_observation_repository.dart';

const List<String> kB04ProductionReadinessKinds = [
  'sleep_duration',
  'workload',
  'soreness',
  'resting_heart_rate',
];

/// A provider-neutral, typed read from a canonical B02 source.
///
/// B04 receives this envelope and owns only its normalized observation and
/// readiness projection. Raw health payloads are not representable here.
class B04RecoveryInput {
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

  const B04RecoveryInput({
    this.id,
    required this.userId,
    required this.kind,
    required this.observedAtUtc,
    required this.timezoneId,
    required this.status,
    required this.unit,
    required this.value,
    required this.lower,
    required this.upper,
    required this.source,
    required this.provenance,
    required this.permission,
    required this.freshness,
    required this.providerExternalId,
    required this.sourceVersion,
    required this.correctionOfObservationId,
    required this.evidenceTimestampUtc,
  });
}

abstract interface class B04RecoveryEvidenceSource {
  Future<List<B04RecoveryInput>> read({
    required String userId,
    required String localDate,
    required String timezoneId,
    required DateTime nowUtc,
    required List<String> requiredKinds,
  });
}

/// Production source adapter for the existing B02 health and progress
/// authorities. It translates supported source reads into typed B04 inputs;
/// it never writes B02 rows and never invents a health measurement.
class B04CanonicalRecoveryEvidenceSource implements B04RecoveryEvidenceSource {
  final HealthService _health;
  final B02ProgressReadRepository _progress;
  final LocalScheduleDateService _dates;

  B04CanonicalRecoveryEvidenceSource({
    required HealthService health,
    required B02ProgressReadRepository progress,
    LocalScheduleDateService? dates,
  }) : _health = health,
       _progress = progress,
       _dates = dates ?? LocalScheduleDateService();

  @override
  Future<List<B04RecoveryInput>> read({
    required String userId,
    required String localDate,
    required String timezoneId,
    required DateTime nowUtc,
    required List<String> requiredKinds,
  }) async {
    final owner = userId.trim();
    final date = _dates.normalizeLocalDate(localDate);
    final zone = timezoneId.trim();
    _dates.validateTimezone(zone);
    final anchor = _localDateAnchor(date, zone);
    final healthMetrics = await _health.readRecoveryMetrics(
      startUtc: nowUtc.toUtc().subtract(const Duration(hours: 48)),
      endUtc: nowUtc.toUtc(),
    );
    final inputs = <B04RecoveryInput>[
      for (final metric in healthMetrics)
        _fromHealthMetric(
          metric,
          userId: owner,
          localDate: date,
          timezoneId: zone,
          anchor: anchor,
        ),
    ];

    if (requiredKinds.contains('workload')) {
      inputs.add(
        await _readWorkload(
          userId: owner,
          localDate: date,
          timezoneId: zone,
          anchor: anchor,
        ),
      );
    }
    if (requiredKinds.contains('soreness')) {
      // No canonical B02 soreness source exists on this branch. Keep the
      // required input explicitly missing rather than deriving it from
      // training history or a profile field.
      inputs.add(
        B04RecoveryInput(
          id: 'b04-soreness:$date:$zone',
          userId: owner,
          kind: 'soreness',
          observedAtUtc: anchor,
          timezoneId: zone,
          status: RecoveryObservationStatus.missing,
          unit: 'score',
          value: null,
          lower: null,
          upper: null,
          source: 'b04_manual_recovery',
          provenance: 'manual:soreness:not_recorded',
          permission: RecoveryPermissionState.notApplicable,
          freshness: RecoveryFreshness.unknown,
          providerExternalId: 'soreness:$date:$zone',
          sourceVersion: 'B04-RECOVERY-INPUT-V1',
          correctionOfObservationId: null,
          evidenceTimestampUtc: anchor,
        ),
      );
    }
    return List.unmodifiable(inputs);
  }

  B04RecoveryInput _fromHealthMetric(
    HealthRecoveryMetricRead metric, {
    required String userId,
    required String localDate,
    required String timezoneId,
    required DateTime anchor,
  }) {
    final providerId = metric.providerExternalId;
    final contentKey = _contentKey(
      kind: metric.kind,
      observedAtUtc: metric.observedAtUtc ?? anchor,
      status: metric.status.name,
      value: metric.value,
      source: metric.source,
      provenance: metric.provenance,
    );
    return B04RecoveryInput(
      id: 'health-recovery:$contentKey',
      userId: userId,
      kind: metric.kind,
      observedAtUtc: metric.observedAtUtc ?? anchor,
      timezoneId: timezoneId,
      status: _status(metric.status),
      unit: metric.unit,
      value: metric.value,
      lower: null,
      upper: null,
      source: metric.source,
      provenance: metric.provenance,
      permission: _permission(metric.permission),
      freshness: _freshness(metric.freshness),
      providerExternalId: 'health-recovery:$contentKey:${providerId ?? 'none'}',
      sourceVersion: metric.sourceVersion,
      correctionOfObservationId: null,
      evidenceTimestampUtc: metric.evidenceTimestampUtc ?? anchor,
    );
  }

  Future<B04RecoveryInput> _readWorkload({
    required String userId,
    required String localDate,
    required String timezoneId,
    required DateTime anchor,
  }) async {
    final start = _dates.addCalendarDays(localDate, timezoneId, -6);
    try {
      final progress = await _progress.read(
        B02ProgressQuery(
          startLocalDate: start,
          endLocalDate: localDate,
          timezoneId: timezoneId,
          historyLimit: 500,
        ),
      );
      final records =
          progress.activityHistory ?? const <B02ProgressActivityRecord>[];
      final minutes = records.fold<double>(
        0,
        (total, item) => total + item.durationSeconds / 60,
      );
      final hasEvidence = records.isNotEmpty;
      return B04RecoveryInput(
        id: 'b02-workload:${hasEvidence ? start : 'missing'}:$localDate:$timezoneId',
        userId: userId,
        kind: 'workload',
        observedAtUtc: anchor,
        timezoneId: timezoneId,
        status: hasEvidence
            ? RecoveryObservationStatus.known
            : RecoveryObservationStatus.missing,
        unit: 'minutes',
        value: hasEvidence ? minutes : null,
        lower: null,
        upper: null,
        source: 'b02_progress',
        provenance: hasEvidence
            ? 'b02:progress:$start:$localDate:$timezoneId'
            : 'b02:progress:missing:$start:$localDate:$timezoneId',
        permission: RecoveryPermissionState.notApplicable,
        freshness: hasEvidence
            ? RecoveryFreshness.fresh
            : RecoveryFreshness.unknown,
        providerExternalId: hasEvidence
            ? 'b02-workload:$start:$localDate:$timezoneId:${minutes.toString()}'
            : 'b02-workload-missing:$start:$localDate:$timezoneId',
        sourceVersion: 'B02-PROGRESS-READ-V1',
        correctionOfObservationId: null,
        evidenceTimestampUtc: anchor,
      );
    } catch (_) {
      return B04RecoveryInput(
        id: 'b02-workload-unavailable:$start:$localDate:$timezoneId',
        userId: userId,
        kind: 'workload',
        observedAtUtc: anchor,
        timezoneId: timezoneId,
        status: RecoveryObservationStatus.unknown,
        unit: 'minutes',
        value: null,
        lower: null,
        upper: null,
        source: 'b02_progress',
        provenance: 'b02:progress:unavailable:$start:$localDate:$timezoneId',
        permission: RecoveryPermissionState.unavailable,
        freshness: RecoveryFreshness.unknown,
        providerExternalId:
            'b02-workload-unavailable:$start:$localDate:$timezoneId',
        sourceVersion: 'B02-PROGRESS-READ-V1',
        correctionOfObservationId: null,
        evidenceTimestampUtc: anchor,
      );
    }
  }

  DateTime _localDateAnchor(String localDate, String timezoneId) {
    final year = int.parse(localDate.substring(0, 4));
    final month = int.parse(localDate.substring(5, 7));
    final day = int.parse(localDate.substring(8, 10));
    return tz.TZDateTime(
      _dates.locationFor(timezoneId),
      year,
      month,
      day,
      12,
    ).toUtc();
  }

  static RecoveryObservationStatus _status(HealthRecoveryMetricStatus value) =>
      switch (value) {
        HealthRecoveryMetricStatus.known => RecoveryObservationStatus.known,
        HealthRecoveryMetricStatus.missing => RecoveryObservationStatus.missing,
        HealthRecoveryMetricStatus.unknown => RecoveryObservationStatus.unknown,
        HealthRecoveryMetricStatus.invalid => RecoveryObservationStatus.invalid,
      };

  static RecoveryPermissionState _permission(
    HealthRecoveryMetricPermission value,
  ) => switch (value) {
    HealthRecoveryMetricPermission.granted => RecoveryPermissionState.granted,
    HealthRecoveryMetricPermission.denied => RecoveryPermissionState.denied,
    HealthRecoveryMetricPermission.unavailable =>
      RecoveryPermissionState.unavailable,
    HealthRecoveryMetricPermission.unknown => RecoveryPermissionState.unknown,
  };

  static RecoveryFreshness _freshness(HealthRecoveryMetricFreshness value) =>
      switch (value) {
        HealthRecoveryMetricFreshness.fresh => RecoveryFreshness.fresh,
        HealthRecoveryMetricFreshness.stale => RecoveryFreshness.stale,
        HealthRecoveryMetricFreshness.unknown => RecoveryFreshness.unknown,
      };
}

/// Production command boundary: import typed B02 evidence, then evaluate the
/// immutable B04 readiness snapshot. The adapter is safe to call repeatedly;
/// repository fingerprints and correction ancestry prevent duplicate active
/// observations and snapshots.
class B04RecoveryProductionAdapter {
  final RecoveryObservationRepository _observations;
  final ReadinessSnapshotRepository _snapshots;
  final B04RecoveryEvidenceSource _source;
  final LocalScheduleDateService _dates;
  final DateTime Function() _nowUtc;
  final Map<String, Future<ReadinessEvaluationResult?>> _runs = {};

  B04RecoveryProductionAdapter({
    required RecoveryObservationRepository observations,
    required ReadinessSnapshotRepository snapshots,
    required B04RecoveryEvidenceSource source,
    LocalScheduleDateService? dates,
    DateTime Function()? nowUtc,
  }) : _observations = observations,
       _snapshots = snapshots,
       _source = source,
       _dates = dates ?? LocalScheduleDateService(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  Future<ReadinessEvaluationResult?> syncAndEvaluate({
    required String userId,
    required String localDate,
    required String timezoneId,
    List<String> requiredKinds = kB04ProductionReadinessKinds,
  }) async {
    final owner = userId.trim();
    final date = _dates.normalizeLocalDate(localDate);
    final zone = timezoneId.trim();
    _dates.validateTimezone(zone);
    final kinds = _normalizedKinds(requiredKinds);
    final key = '$owner:$date:$zone:${kinds.join(',')}';
    final active = _runs[key];
    if (active != null) return active;
    final future = _syncAndEvaluate(
      userId: owner,
      localDate: date,
      timezoneId: zone,
      requiredKinds: kinds,
    );
    _runs[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_runs[key], future)) {
        final removed = _runs.remove(key);
        assert(removed == null || identical(removed, future));
      }
    }
  }

  Future<ReadinessEvaluationResult?> _syncAndEvaluate({
    required String userId,
    required String localDate,
    required String timezoneId,
    required List<String> requiredKinds,
  }) async {
    final now = _nowUtc().toUtc();
    List<B04RecoveryInput> inputs;
    try {
      inputs = await _source.read(
        userId: userId,
        localDate: localDate,
        timezoneId: timezoneId,
        nowUtc: now,
        requiredKinds: requiredKinds,
      );
    } catch (_) {
      inputs = [
        for (final kind in requiredKinds)
          B04RecoveryInput(
            id: 'b04-recovery-adapter-unavailable:$kind:$localDate:$timezoneId',
            userId: userId,
            kind: kind,
            observedAtUtc: _localDateAnchor(localDate, timezoneId),
            timezoneId: timezoneId,
            status: RecoveryObservationStatus.unknown,
            unit: 'unknown',
            value: null,
            lower: null,
            upper: null,
            source: 'b04_recovery_adapter',
            provenance: 'b04:recovery:source-unavailable:$kind',
            permission: RecoveryPermissionState.unavailable,
            freshness: RecoveryFreshness.unknown,
            providerExternalId:
                'b04-recovery-adapter-unavailable:$kind:$localDate:$timezoneId',
            sourceVersion: 'B04-RECOVERY-ADAPTER-V1',
            correctionOfObservationId: null,
            evidenceTimestampUtc: _localDateAnchor(localDate, timezoneId),
          ),
      ];
    }

    final suppliedKinds = inputs.map((input) => input.kind).toSet();
    final anchor = _localDateAnchor(localDate, timezoneId);
    for (final kind in requiredKinds) {
      if (suppliedKinds.contains(kind)) continue;
      inputs.add(
        B04RecoveryInput(
          id: 'b04-recovery-missing:$kind:$localDate:$timezoneId',
          userId: userId,
          kind: kind,
          observedAtUtc: anchor,
          timezoneId: timezoneId,
          status: RecoveryObservationStatus.unknown,
          unit: 'unknown',
          value: null,
          lower: null,
          upper: null,
          source: 'b04_recovery_adapter',
          provenance: 'b04:recovery:missing-source:$kind',
          permission: RecoveryPermissionState.unavailable,
          freshness: RecoveryFreshness.unknown,
          providerExternalId:
              'b04-recovery-missing:$kind:$localDate:$timezoneId',
          sourceVersion: 'B04-RECOVERY-ADAPTER-V1',
          correctionOfObservationId: null,
          evidenceTimestampUtc: anchor,
        ),
      );
    }

    final existing = await _observations.listForLocalDate(
      userId: userId,
      localDate: localDate,
      timezoneId: timezoneId,
    );
    final activeByKind = <String, RecoveryObservationReadModel>{};
    for (final observation in existing) {
      activeByKind[observation.kind] = observation;
    }
    for (final input in inputs) {
      final prior = activeByKind[input.kind];
      if (prior != null && _sameContent(prior, input)) {
        // A correction has a durable ID and ancestry that are not present in
        // the fresh provider envelope. Reusing the active row avoids trying
        // to reinsert the original input ID on every sync.
        continue;
      }
      final normalized = _withCorrectionIfNeeded(input, prior);
      final stored = await _observations.importObservation(
        RecoveryObservationInput(
          id: normalized.id,
          userId: normalized.userId,
          kind: normalized.kind,
          observedAtUtc: normalized.observedAtUtc,
          timezoneId: normalized.timezoneId,
          status: normalized.status,
          unit: normalized.unit,
          value: normalized.value,
          lower: normalized.lower,
          upper: normalized.upper,
          source: normalized.source,
          provenance: normalized.provenance,
          permission: normalized.permission,
          freshness: normalized.freshness,
          providerExternalId: normalized.providerExternalId,
          sourceVersion: normalized.sourceVersion,
          correctionOfObservationId: normalized.correctionOfObservationId,
          evidenceTimestampUtc: normalized.evidenceTimestampUtc,
        ),
      );
      activeByKind[stored.kind] = stored;
    }
    return _snapshots.evaluateAndStoreForLocalDate(
      userId: userId,
      localDate: localDate,
      timezoneId: timezoneId,
      requiredKinds: requiredKinds,
      createdAtUtc: now,
    );
  }

  B04RecoveryInput _withCorrectionIfNeeded(
    B04RecoveryInput input,
    RecoveryObservationReadModel? prior,
  ) {
    if (prior == null || _sameContent(prior, input)) return input;
    final correctionKey = _contentKey(
      kind: input.kind,
      observedAtUtc: input.observedAtUtc,
      status: input.status.stableId,
      value: input.value,
      source: input.source,
      provenance: input.provenance,
    );
    return B04RecoveryInput(
      id: '${input.id ?? 'recovery'}:correction:$correctionKey',
      userId: input.userId,
      kind: input.kind,
      observedAtUtc: input.observedAtUtc,
      timezoneId: input.timezoneId,
      status: input.status,
      unit: input.unit,
      value: input.value,
      lower: input.lower,
      upper: input.upper,
      source: input.source,
      provenance: input.provenance,
      permission: input.permission,
      freshness: input.freshness,
      providerExternalId:
          '${input.providerExternalId ?? 'none'}:correction:$correctionKey',
      sourceVersion: input.sourceVersion,
      correctionOfObservationId: prior.id,
      evidenceTimestampUtc: input.evidenceTimestampUtc,
    );
  }

  bool _sameContent(
    RecoveryObservationReadModel prior,
    B04RecoveryInput input,
  ) {
    final localDate = _dates.localDateFor(
      input.observedAtUtc,
      input.timezoneId,
    );
    return prior.userId == input.userId.trim() &&
        prior.kind == input.kind.trim() &&
        prior.observedAtUtc.toUtc() == input.observedAtUtc.toUtc() &&
        prior.localDate == localDate &&
        prior.timezoneId == input.timezoneId.trim() &&
        prior.status == input.status &&
        prior.unit == input.unit.trim() &&
        prior.value == input.value &&
        prior.lower == input.lower &&
        prior.upper == input.upper &&
        prior.source == input.source.trim() &&
        prior.provenanceEnvelope.reference == input.provenance.trim() &&
        prior.permission == input.permission &&
        prior.freshness == input.freshness &&
        _providerBase(prior.providerExternalId) ==
            _providerBase(input.providerExternalId) &&
        prior.sourceVersion == input.sourceVersion &&
        (input.correctionOfObservationId == null ||
            prior.correctionOfObservationId ==
                input.correctionOfObservationId) &&
        prior.evidenceTimestampUtc?.toUtc() ==
            input.evidenceTimestampUtc?.toUtc();
  }

  static String? _providerBase(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    final marker = normalized.lastIndexOf(':correction:');
    return marker < 0 ? normalized : normalized.substring(0, marker);
  }

  DateTime _localDateAnchor(String localDate, String timezoneId) {
    final year = int.parse(localDate.substring(0, 4));
    final month = int.parse(localDate.substring(5, 7));
    final day = int.parse(localDate.substring(8, 10));
    return tz.TZDateTime(
      _dates.locationFor(timezoneId),
      year,
      month,
      day,
      12,
    ).toUtc();
  }

  static List<String> _normalizedKinds(Iterable<String> kinds) {
    final result = kinds.map((kind) => kind.trim()).toSet().toList()..sort();
    if (result.isEmpty) {
      throw ArgumentError('Readiness requires at least one input kind.');
    }
    return List.unmodifiable(result);
  }
}

String _contentKey({
  required String kind,
  required DateTime observedAtUtc,
  required String status,
  required double? value,
  required String source,
  required String provenance,
}) {
  final raw = [
    kind,
    observedAtUtc.toUtc().toIso8601String(),
    status,
    value?.toString() ?? '',
    source,
    provenance,
  ].join('|');
  return sha256.convert(raw.codeUnits).toString().substring(0, 24);
}
