import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart' as db;
import '../models/b04_recovery_models.dart';

/// Sole B04 owner for normalized recovery observations.
///
/// B02 remains the source authority for health/activity provenance and
/// history. This repository stores only the typed, privacy-minimized B04
/// observation envelope and never updates a B02 row.
class RecoveryObservationRepository {
  final db.AppDatabase _db;
  final Uuid _uuid;
  final LocalScheduleDateService _dates;
  final DateTime Function() _nowUtc;

  RecoveryObservationRepository({
    required db.AppDatabase database,
    Uuid? uuid,
    LocalScheduleDateService? dates,
    DateTime Function()? nowUtc,
  }) : _db = database,
       _uuid = uuid ?? const Uuid(),
       _dates = dates ?? LocalScheduleDateService(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  Future<RecoveryObservationReadModel> importObservation(
    RecoveryObservationInput input,
  ) async {
    _validateInput(input);
    final id = input.id?.trim().isNotEmpty == true
        ? input.id!.trim()
        : _uuid.v4();
    final owner = input.userId.trim();
    final source = input.source.trim();
    final provenance = input.provenance.trim();
    final providerExternalId = _optional(input.providerExternalId);
    final sourceVersion = _optional(input.sourceVersion);
    final correctionOfObservationId = _optional(
      input.correctionOfObservationId,
    );
    final localDate = _dates.localDateFor(
      input.observedAtUtc.toUtc(),
      input.timezoneId,
    );
    final envelope = RecoveryProvenance(
      reference: provenance,
      permission: input.permission,
      providerExternalId: providerExternalId,
      sourceVersion: sourceVersion,
      correctionOfObservationId: correctionOfObservationId,
    );

    return _db.transaction(() async {
      final byId = await (_db.select(
        _db.recoveryObservations,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (byId != null) {
        _assertSame(byId, input, localDate: localDate, provenance: envelope);
        return _fromRow(byId);
      }

      if (correctionOfObservationId != null) {
        final parent =
            await (_db.select(_db.recoveryObservations)
                  ..where((row) => row.id.equals(correctionOfObservationId)))
                .getSingleOrNull();
        if (parent == null) {
          throw const B04RecoveryConflictError(
            'missing_correction_parent',
            'A correction must reference an existing recovery observation.',
          );
        }
        if (parent.userId != owner ||
            parent.source != source ||
            parent.kind != input.kind.trim()) {
          throw const B04RecoveryConflictError(
            'correction_owner_conflict',
            'A recovery correction must remain within the original user/source/kind authority.',
          );
        }
      }

      if (providerExternalId != null) {
        final existing =
            await (_db.select(_db.recoveryObservations)..where(
                  (row) =>
                      row.userId.equals(owner) &
                      row.source.equals(source) &
                      row.providerExternalId.equals(providerExternalId),
                ))
                .getSingleOrNull();
        if (existing != null) {
          if (_sameContent(
            existing,
            input,
            localDate: localDate,
            provenance: envelope,
          )) {
            return _fromRow(existing);
          }
          throw const B04RecoveryConflictError(
            'observation_provider_id_conflict',
            'A provider observation ID is already used for different content; corrections must append a new observation.',
          );
        }
      }

      final equivalent = await _findEquivalent(
        input,
        owner: owner,
        source: source,
        localDate: localDate,
        provenance: envelope,
      );
      if (equivalent != null) return _fromRow(equivalent);

      await _db
          .into(_db.recoveryObservations)
          .insert(
            db.RecoveryObservationsCompanion.insert(
              id: id,
              userId: owner,
              kind: input.kind.trim(),
              observedAtUtc: input.observedAtUtc.toUtc(),
              localDate: localDate,
              timezoneId: input.timezoneId.trim(),
              status: input.status.stableId,
              unit: input.unit.trim(),
              value: Value(input.value),
              lower: Value(input.lower),
              upper: Value(input.upper),
              source: source,
              provenance: envelope.encode(),
              freshness: input.freshness.stableId,
              providerExternalId: Value(providerExternalId),
              sourceVersion: Value(sourceVersion),
              // Correction ancestry is stored in the typed provenance envelope
              // because the accepted v18 schema intentionally has no second
              // mutable correction table.
              evidenceTimestampUtc: Value(input.evidenceTimestampUtc?.toUtc()),
              createdAtUtc: Value(_nowUtc().toUtc()),
            ),
          );
      final row = await (_db.select(
        _db.recoveryObservations,
      )..where((item) => item.id.equals(id))).getSingleOrNull();
      if (row == null) {
        throw const B04RecoveryConflictError(
          'observation_not_persisted',
          'The recovery observation was not persisted.',
        );
      }
      return _fromRow(row);
    });
  }

  Future<RecoveryObservationReadModel?> byId(String id) async {
    final key = id.trim();
    if (key.isEmpty) return null;
    final row = await (_db.select(
      _db.recoveryObservations,
    )..where((item) => item.id.equals(key))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<RecoveryObservationReadModel>> listForLocalDate({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) async {
    final owner = _owner(userId);
    if (owner.isEmpty) {
      throw const B04RecoveryValidationError(
        'missing_user_id',
        'A recovery observation query requires a user ID.',
      );
    }
    final date = _dates.normalizeLocalDate(localDate);
    _dates.validateTimezone(timezoneId);
    final rows =
        await (_db.select(_db.recoveryObservations)
              ..where((row) => row.userId.equals(owner))
              ..orderBy([
                (row) => OrderingTerm(expression: row.observedAtUtc),
                (row) => OrderingTerm(expression: row.id),
              ]))
            .get();
    final superseded = <String>{};
    for (final row in rows) {
      final parentId = RecoveryProvenance.fromStored(
        encoded: row.provenance,
        fallbackPermission: RecoveryPermissionState.unknown,
        providerExternalId: row.providerExternalId,
        sourceVersion: row.sourceVersion,
      ).correctionOfObservationId;
      if (parentId != null) superseded.add(parentId);
    }
    return List.unmodifiable([
      for (final row in rows)
        if (row.localDate == date &&
            row.timezoneId == timezoneId.trim() &&
            !superseded.contains(row.id))
          _fromRow(row),
    ]);
  }

  Future<List<RecoveryObservationReadModel>> listForUser({
    required String userId,
  }) async {
    final owner = _owner(userId);
    if (owner.isEmpty) {
      throw const B04RecoveryValidationError(
        'missing_user_id',
        'A recovery observation query requires a user ID.',
      );
    }
    final rows =
        await (_db.select(_db.recoveryObservations)
              ..where((row) => row.userId.equals(owner))
              ..orderBy([
                (row) => OrderingTerm(expression: row.observedAtUtc),
                (row) => OrderingTerm(expression: row.id),
              ]))
            .get();
    return List.unmodifiable(rows.map(_fromRow));
  }

  Future<db.RecoveryObservation?> rawById(String id) => (_db.select(
    _db.recoveryObservations,
  )..where((row) => row.id.equals(id.trim()))).getSingleOrNull();

  Future<db.RecoveryObservation?> _findEquivalent(
    RecoveryObservationInput input, {
    required String owner,
    required String source,
    required String localDate,
    required RecoveryProvenance provenance,
  }) async {
    final rows =
        await (_db.select(_db.recoveryObservations)..where(
              (row) =>
                  row.userId.equals(owner) &
                  row.kind.equals(input.kind.trim()) &
                  row.source.equals(source) &
                  row.observedAtUtc.equals(input.observedAtUtc.toUtc()),
            ))
            .get();
    for (final row in rows) {
      if (_sameContent(
        row,
        input,
        localDate: localDate,
        provenance: provenance,
      )) {
        return row;
      }
    }
    return null;
  }

  void _validateInput(RecoveryObservationInput input) {
    final owner = _owner(input.userId);
    if (owner.isEmpty) {
      throw const B04RecoveryValidationError(
        'missing_user_id',
        'A recovery observation requires a user ID.',
      );
    }
    if (input.kind.trim().isEmpty ||
        input.unit.trim().isEmpty ||
        input.source.trim().isEmpty ||
        input.provenance.trim().isEmpty) {
      throw const B04RecoveryValidationError(
        'missing_observation_metadata',
        'Recovery observations require kind, unit, source and provenance.',
      );
    }
    RecoveryProvenance.validateReference(input.provenance);
    if (!input.observedAtUtc.isUtc) {
      throw const B04RecoveryValidationError(
        'observation_timestamp_not_utc',
        'Recovery observation timestamps must be explicit UTC instants.',
      );
    }
    if (input.evidenceTimestampUtc != null &&
        !input.evidenceTimestampUtc!.isUtc) {
      throw const B04RecoveryValidationError(
        'evidence_timestamp_not_utc',
        'Recovery evidence timestamps must be explicit UTC instants.',
      );
    }
    _dates.validateTimezone(input.timezoneId);

    for (final value in [input.value, input.lower, input.upper]) {
      if (value != null && (!value.isFinite || value < 0)) {
        throw const B04RecoveryValidationError(
          'invalid_observation_range',
          'Recovery values and bounds must be finite and non-negative.',
        );
      }
    }
    if (input.lower != null &&
        input.upper != null &&
        input.lower! > input.upper!) {
      throw const B04RecoveryValidationError(
        'invalid_observation_range',
        'Recovery lower bound cannot exceed the upper bound.',
      );
    }
    if (input.value != null &&
        input.lower != null &&
        input.value! < input.lower!) {
      throw const B04RecoveryValidationError(
        'invalid_observation_range',
        'Recovery point value must be inside its lower bound.',
      );
    }
    if (input.value != null &&
        input.upper != null &&
        input.value! > input.upper!) {
      throw const B04RecoveryValidationError(
        'invalid_observation_range',
        'Recovery point value must be inside its upper bound.',
      );
    }

    final hasNumericEvidence =
        input.value != null || input.lower != null || input.upper != null;
    switch (input.status) {
      case RecoveryObservationStatus.known:
        if (input.value == null) {
          throw const B04RecoveryValidationError(
            'known_observation_requires_value',
            'Known recovery evidence requires a point value.',
          );
        }
      case RecoveryObservationStatus.estimated:
        if (!hasNumericEvidence) {
          throw const B04RecoveryValidationError(
            'estimated_observation_requires_evidence',
            'Estimated recovery evidence requires a point or at least one bound.',
          );
        }
      case RecoveryObservationStatus.missing:
      case RecoveryObservationStatus.unknown:
      case RecoveryObservationStatus.invalid:
        if (hasNumericEvidence) {
          throw const B04RecoveryValidationError(
            'non_numeric_unavailable_observation',
            'Missing, unknown and invalid recovery states cannot carry numeric evidence.',
          );
        }
    }

    if (input.permission != RecoveryPermissionState.granted &&
        input.permission != RecoveryPermissionState.notApplicable) {
      if (hasNumericEvidence ||
          (input.status != RecoveryObservationStatus.missing &&
              input.status != RecoveryObservationStatus.unknown &&
              input.status != RecoveryObservationStatus.invalid)) {
        throw const B04RecoveryValidationError(
          'permission_state_not_measurement',
          'Denied or unavailable health permission cannot carry a measurement.',
        );
      }
    }
  }

  bool _sameContent(
    db.RecoveryObservation row,
    RecoveryObservationInput input, {
    required String localDate,
    required RecoveryProvenance provenance,
  }) {
    final stored = RecoveryProvenance.fromStored(
      encoded: row.provenance,
      fallbackPermission: RecoveryPermissionState.unknown,
      providerExternalId: row.providerExternalId,
      sourceVersion: row.sourceVersion,
    );
    return row.userId == _owner(input.userId) &&
        row.kind == input.kind.trim() &&
        row.observedAtUtc.toUtc() == input.observedAtUtc.toUtc() &&
        row.localDate == localDate &&
        row.timezoneId == input.timezoneId.trim() &&
        row.status == input.status.stableId &&
        row.unit == input.unit.trim() &&
        row.value == input.value &&
        row.lower == input.lower &&
        row.upper == input.upper &&
        row.source == input.source.trim() &&
        stored.reference == provenance.reference &&
        stored.permission == provenance.permission &&
        row.freshness == input.freshness.stableId &&
        row.providerExternalId == provenance.providerExternalId &&
        row.sourceVersion == provenance.sourceVersion &&
        stored.correctionOfObservationId ==
            provenance.correctionOfObservationId &&
        row.evidenceTimestampUtc?.toUtc() ==
            input.evidenceTimestampUtc?.toUtc();
  }

  void _assertSame(
    db.RecoveryObservation row,
    RecoveryObservationInput input, {
    required String localDate,
    required RecoveryProvenance provenance,
  }) {
    if (!_sameContent(
      row,
      input,
      localDate: localDate,
      provenance: provenance,
    )) {
      throw const B04RecoveryConflictError(
        'observation_id_conflict',
        'The observation ID is already used for different content; history is immutable.',
      );
    }
  }

  RecoveryObservationReadModel _fromRow(db.RecoveryObservation row) {
    final envelope = RecoveryProvenance.fromStored(
      encoded: row.provenance,
      fallbackPermission: RecoveryPermissionState.unknown,
      providerExternalId: row.providerExternalId,
      sourceVersion: row.sourceVersion,
    );
    return RecoveryObservationReadModel(
      id: row.id,
      userId: row.userId,
      kind: row.kind,
      observedAtUtc: row.observedAtUtc.toUtc(),
      localDate: row.localDate,
      timezoneId: row.timezoneId,
      status: RecoveryObservationStatusId.parse(row.status),
      unit: row.unit,
      value: row.value,
      lower: row.lower,
      upper: row.upper,
      source: row.source,
      provenance: envelope.reference,
      provenanceEnvelope: envelope,
      permission: envelope.permission,
      freshness: RecoveryFreshnessId.parse(row.freshness),
      providerExternalId: row.providerExternalId,
      sourceVersion: row.sourceVersion,
      correctionOfObservationId: envelope.correctionOfObservationId,
      evidenceTimestampUtc: row.evidenceTimestampUtc?.toUtc(),
      createdAtUtc: row.createdAtUtc.toUtc(),
    );
  }

  static String _owner(String value) => value.trim();

  static String? _optional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
