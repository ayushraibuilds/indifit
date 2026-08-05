import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart' as db;
import '../models/b04_recovery_models.dart';
import '../services/readiness_service.dart';
import 'recovery_observation_repository.dart';

/// Durable owner for immutable readiness snapshots and frozen evidence links.
///
/// The repository composes [RecoveryObservationRepository] and the pure
/// [ReadinessService]. It does not own schedule/activity history and does not
/// emit or persist adaptive calorie/training targets.
class ReadinessSnapshotRepository {
  final db.AppDatabase _db;
  final RecoveryObservationRepository _observations;
  final ReadinessService _service;
  final Uuid _uuid;
  final LocalScheduleDateService _dates;
  final DateTime Function() _nowUtc;

  ReadinessSnapshotRepository({
    required db.AppDatabase database,
    RecoveryObservationRepository? observations,
    ReadinessService? service,
    Uuid? uuid,
    LocalScheduleDateService? dates,
    DateTime Function()? nowUtc,
  }) : _db = database,
       _observations =
           observations ?? RecoveryObservationRepository(database: database),
       _service = service ?? ReadinessService(dates: dates),
       _uuid = uuid ?? const Uuid(),
       _dates = dates ?? LocalScheduleDateService(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  /// Evaluates the observations recorded for one immutable local-date/timezone
  /// context. With no observations, this returns null and creates no snapshot:
  /// missing recovery is unknown, not a fabricated historical row.
  Future<ReadinessEvaluationResult?> evaluateAndStoreForLocalDate({
    required String userId,
    required String localDate,
    required String timezoneId,
    required List<String> requiredKinds,
    DateTime? createdAtUtc,
  }) async {
    final date = _dates.normalizeLocalDate(localDate);
    _dates.validateTimezone(timezoneId);
    final observations = await _observations.listForLocalDate(
      userId: userId,
      localDate: date,
      timezoneId: timezoneId,
    );
    if (observations.isEmpty) return null;
    return store(
      ReadinessEvaluationRequest(
        snapshotId: _uuid.v4(),
        userId: userId,
        localDate: date,
        timezoneId: timezoneId,
        requiredKinds: requiredKinds,
        observations: observations,
        createdAtUtc: (createdAtUtc ?? _nowUtc()).toUtc(),
      ),
    );
  }

  /// Stores a caller-supplied observation set after pure evaluation. This is
  /// the explicit command boundary used by import/replay paths.
  Future<ReadinessEvaluationResult> store(
    ReadinessEvaluationRequest request,
  ) async {
    if (request.observations.isEmpty) {
      throw const B04NoReadinessEvidenceError();
    }

    final preview = _service.evaluate(
      request.copyWith(snapshotId: 'readiness-preview'),
    );
    return _db.transaction(() async {
      final existing = await _findByFingerprint(
        userId: request.userId.trim(),
        localDate: _dates.normalizeLocalDate(request.localDate),
        timezoneId: request.timezoneId.trim(),
        fingerprint: preview.snapshot.evidenceFingerprint,
      );
      if (existing != null) {
        return ReadinessEvaluationResult(
          snapshot: existing,
          numericalEffect: ReadinessNumericalEffect.hold,
        );
      }

      final previous = await _latestActive(
        userId: request.userId.trim(),
        localDate: _dates.normalizeLocalDate(request.localDate),
        timezoneId: request.timezoneId.trim(),
      );
      final snapshotId = request.snapshotId.trim().isEmpty
          ? _uuid.v4()
          : request.snapshotId.trim();
      final calculationVersion = await _uniqueCalculationVersion(
        request.calculationVersion.trim(),
        userId: request.userId.trim(),
        localDate: _dates.normalizeLocalDate(request.localDate),
        timezoneId: request.timezoneId.trim(),
        fingerprint: preview.snapshot.evidenceFingerprint,
      );
      final evaluated = _service.evaluate(
        request.copyWith(
          snapshotId: snapshotId,
          calculationVersion: calculationVersion,
          supersedesSnapshotId: previous?.id,
        ),
      );

      await _db
          .into(_db.readinessSnapshots)
          .insert(
            db.ReadinessSnapshotsCompanion.insert(
              id: evaluated.snapshot.id,
              userId: evaluated.snapshot.userId,
              localDate: evaluated.snapshot.localDate,
              timezoneId: evaluated.snapshot.timezoneId,
              completeness: evaluated.snapshot.completeness.stableId,
              status: evaluated.snapshot.status.stableId,
              band: Value(evaluated.snapshot.band?.stableId),
              confidence: Value(evaluated.snapshot.confidence),
              calculationVersion: evaluated.snapshot.calculationVersion,
              policyVersion: Value(evaluated.snapshot.policyVersion),
              unavailableReason: Value(evaluated.snapshot.unavailableReason),
              evidenceFingerprint: Value(
                evaluated.snapshot.evidenceFingerprint,
              ),
              createdAtUtc: Value(evaluated.snapshot.createdAtUtc),
              supersedesSnapshotId: Value(
                evaluated.snapshot.supersedesSnapshotId,
              ),
            ),
          );
      for (final evidence in evaluated.snapshot.evidence) {
        await _db
            .into(_db.readinessSnapshotEvidence)
            .insert(
              db.ReadinessSnapshotEvidenceCompanion.insert(
                id: evidence.id,
                readinessSnapshotId: evidence.readinessSnapshotId,
                observationId: evidence.observationId,
                evidenceKind: evidence.evidenceKind,
                status: evidence.status.stableId,
                value: Value(evidence.value),
                lower: Value(evidence.lower),
                upper: Value(evidence.upper),
                unit: Value(evidence.unit),
                sourceVersion: Value(evidence.sourceVersion),
                createdAtUtc: Value(evaluated.snapshot.createdAtUtc),
              ),
            );
      }
      return evaluated;
    });
  }

  Future<ReadinessSnapshotReadModel?> latestForLocalDate({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) async {
    _dates.validateTimezone(timezoneId);
    final row = await _latestActive(
      userId: userId.trim(),
      localDate: _dates.normalizeLocalDate(localDate),
      timezoneId: timezoneId.trim(),
    );
    return row;
  }

  Future<List<ReadinessSnapshotReadModel>> listForUser({
    required String userId,
  }) async {
    final owner = userId.trim();
    if (owner.isEmpty) {
      throw const B04RecoveryValidationError(
        'missing_user_id',
        'A readiness snapshot query requires a user ID.',
      );
    }
    final rows =
        await (_db.select(_db.readinessSnapshots)
              ..where((row) => row.userId.equals(owner))
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.createdAtUtc,
                  mode: OrderingMode.desc,
                ),
                (row) => OrderingTerm(expression: row.id),
              ]))
            .get();
    return List.unmodifiable([for (final row in rows) await _fromRow(row)]);
  }

  Future<ReadinessSnapshotReadModel?> byId(String id) async {
    final key = id.trim();
    if (key.isEmpty) return null;
    final row = await (_db.select(
      _db.readinessSnapshots,
    )..where((item) => item.id.equals(key))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<ReadinessSnapshotReadModel?> _findByFingerprint({
    required String userId,
    required String localDate,
    required String timezoneId,
    required String? fingerprint,
  }) async {
    if (fingerprint == null) return null;
    final rows =
        await (_db.select(_db.readinessSnapshots)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.localDate.equals(localDate) &
                  row.timezoneId.equals(timezoneId) &
                  row.evidenceFingerprint.equals(fingerprint),
            ))
            .get();
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<ReadinessSnapshotReadModel?> _latestActive({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) async {
    final rows =
        await (_db.select(_db.readinessSnapshots)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.localDate.equals(localDate) &
                    row.timezoneId.equals(timezoneId),
              )
              ..orderBy([
                (row) => OrderingTerm(
                  expression: row.createdAtUtc,
                  mode: OrderingMode.desc,
                ),
                (row) => OrderingTerm(expression: row.id),
              ]))
            .get();
    if (rows.isEmpty) return null;
    final supersededIds = rows
        .map((row) => row.supersedesSnapshotId)
        .whereType<String>()
        .toSet();
    final active = rows
        .where((row) => !supersededIds.contains(row.id))
        .toList(growable: false);
    return active.isEmpty ? null : _fromRow(active.first);
  }

  Future<String> _uniqueCalculationVersion(
    String base, {
    required String userId,
    required String localDate,
    required String timezoneId,
    required String? fingerprint,
  }) async {
    final rows =
        await (_db.select(_db.readinessSnapshots)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.localDate.equals(localDate) &
                  row.timezoneId.equals(timezoneId),
            ))
            .get();
    if (rows.every((row) => row.calculationVersion != base)) return base;
    final suffix = fingerprint ?? 'revision';
    var candidate = '$base:$suffix';
    var counter = 2;
    while (rows.any((row) => row.calculationVersion == candidate)) {
      candidate = '$base:$suffix:$counter';
      counter++;
    }
    return candidate;
  }

  Future<ReadinessSnapshotReadModel> _fromRow(db.ReadinessSnapshot row) async {
    final evidenceRows =
        await (_db.select(_db.readinessSnapshotEvidence)
              ..where((item) => item.readinessSnapshotId.equals(row.id))
              ..orderBy([(item) => OrderingTerm(expression: item.id)]))
            .get();
    return ReadinessSnapshotReadModel(
      id: row.id,
      userId: row.userId,
      localDate: row.localDate,
      timezoneId: row.timezoneId,
      completeness: ReadinessCompletenessId.parse(row.completeness),
      status: ReadinessStatusId.parse(row.status),
      band: row.band == null ? null : ReadinessBandId.parse(row.band!),
      confidence: row.confidence,
      calculationVersion: row.calculationVersion,
      policyVersion:
          row.policyVersion ??
          (throw const B04RecoveryValidationError(
            'missing_readiness_policy_version',
            'A readiness snapshot is missing its policy version.',
          )),
      unavailableReason: row.unavailableReason,
      evidenceFingerprint: row.evidenceFingerprint,
      createdAtUtc: row.createdAtUtc.toUtc(),
      supersededAtUtc: row.supersededAtUtc?.toUtc(),
      supersedesSnapshotId: row.supersedesSnapshotId,
      evidence: [
        for (final evidence in evidenceRows)
          ReadinessSnapshotEvidenceReadModel(
            id: evidence.id,
            readinessSnapshotId: evidence.readinessSnapshotId,
            observationId: evidence.observationId,
            evidenceKind: evidence.evidenceKind,
            status: RecoveryObservationStatusId.parse(evidence.status),
            value: evidence.value,
            lower: evidence.lower,
            upper: evidence.upper,
            unit: evidence.unit,
            sourceVersion: evidence.sourceVersion,
          ),
      ],
    );
  }
}
