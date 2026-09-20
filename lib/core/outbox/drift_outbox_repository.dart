import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import 'outbox_operation.dart';
import 'outbox_repository.dart';
import 'outbox_retry_policy.dart';

/// SQLite-backed [OutboxRepository] on the `outbox_entries` table (schema v21).
///
/// Device-local spool: rows are never synced and never enter backup payloads
/// (backup specs are explicit allowlists). Survives process death, unlike
/// [InMemoryOutboxRepository] which remains the choice for unit tests.
class DriftOutboxRepository implements OutboxRepository {
  DriftOutboxRepository(
    this._db, {
    OutboxRetryPolicy? retryPolicy,
  }) : _retryPolicy = retryPolicy ?? const OutboxRetryPolicy();

  final AppDatabase _db;
  final OutboxRetryPolicy _retryPolicy;

  OutboxOperation _toDomain(OutboxEntry row) {
    OutboxDomain? domain;
    for (final d in OutboxDomain.values) {
      if (d.name == row.domain) domain = d;
    }
    if (domain == null) {
      throw FormatException(
        'Unknown OutboxDomain "${row.domain}" in outbox row ${row.operationId}.',
      );
    }
    OutboxState? state;
    for (final s in OutboxState.values) {
      if (s.name == row.state) state = s;
    }
    if (state == null) {
      throw FormatException(
        'Unknown OutboxState "${row.state}" in outbox row ${row.operationId}.',
      );
    }
    final payloadRaw = jsonDecode(row.payloadJson);
    if (payloadRaw is! Map) {
      throw FormatException(
        'Malformed outbox payload in row ${row.operationId}.',
      );
    }
    return OutboxOperation(
      operationId: row.operationId,
      idempotencyKey: row.idempotencyKey,
      domain: domain,
      action: row.action,
      entityId: row.entityId,
      payload: Map<String, dynamic>.from(payloadRaw),
      createdAtUtc: row.createdAtUtc,
      scheduledAtUtc: row.scheduledAtUtc,
      state: state,
      attemptCount: row.attemptCount,
      lastAttemptUtc: row.lastAttemptUtc,
      lastError: row.lastError,
    );
  }

  @override
  Future<void> enqueue(OutboxOperation operation) async {
    // Idempotent on operationId: never silently overwrite an existing row.
    final existing = await ( _db.select(_db.outboxEntries)
          ..where((t) => t.operationId.equals(operation.operationId)))
        .getSingleOrNull();
    if (existing != null) return;

    // Deduplicate by idempotency key only while an operation is still active.
    final activeDup = await (_db.select(_db.outboxEntries)
          ..where((t) => t.idempotencyKey.equals(operation.idempotencyKey))
          ..where(
            (t) =>
                t.state.equals(OutboxState.pending.name) |
                t.state.equals(OutboxState.inFlight.name) |
                t.state.equals(OutboxState.transientFailure.name),
          ))
        .getSingleOrNull();
    if (activeDup != null) return;

    await _db.into(_db.outboxEntries).insert(
          OutboxEntriesCompanion.insert(
            operationId: operation.operationId,
            idempotencyKey: operation.idempotencyKey,
            domain: operation.domain.name,
            action: operation.action,
            entityId: operation.entityId,
            payloadJson: jsonEncode(operation.payload),
            createdAtUtc: operation.createdAtUtc,
            scheduledAtUtc: operation.scheduledAtUtc,
            state: operation.state.name,
            attemptCount: Value(operation.attemptCount),
            lastAttemptUtc: Value(operation.lastAttemptUtc),
            lastError: Value(operation.lastError),
          ),
        );
  }

  @override
  Future<List<OutboxOperation>> getPendingOperations({int limit = 50}) async {
    final now = DateTime.now().toUtc();
    final leaseCutoff =
        now.subtract(OutboxRepository.stuckInFlightLease);
    final rows = await (_db.select(_db.outboxEntries)
          ..where(
            (t) =>
                ((t.state.equals(OutboxState.pending.name) |
                            t.state.equals(
                                OutboxState.transientFailure.name)) &
                        t.scheduledAtUtc.isSmallerOrEqualValue(now)) |
                    // Stale-lease recovery (see contract): a pre-crash
                    // dispatch left inFlight becomes redeliverable.
                    (t.state.equals(OutboxState.inFlight.name) &
                        t.lastAttemptUtc.isSmallerThanValue(leaseCutoff)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.scheduledAtUtc)])
          ..limit(limit))
        .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> markInFlight(String operationId) async {
    final op = await getOperationById(operationId);
    if (op == null) return;
    await (_db.update(_db.outboxEntries)
          ..where((t) => t.operationId.equals(operationId)))
        .write(
      OutboxEntriesCompanion(
        state: Value(OutboxState.inFlight.name),
        attemptCount: Value(op.attemptCount + 1),
        lastAttemptUtc: Value(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> markSucceeded(String operationId) async {
    await (_db.update(_db.outboxEntries)
          ..where((t) => t.operationId.equals(operationId)))
        .write(
      OutboxEntriesCompanion(
        state: Value(OutboxState.succeeded.name),
        lastAttemptUtc: Value(DateTime.now().toUtc()),
        lastError: const Value(null),
      ),
    );
  }

  @override
  Future<void> markFailed(
    String operationId, {
    required String error,
    required bool isRetryable,
  }) async {
    final op = await getOperationById(operationId);
    if (op == null) return;
    final now = DateTime.now().toUtc();
    if (isRetryable && op.attemptCount < _retryPolicy.maxAttempts) {
      final next = _retryPolicy.calculateNextSchedule(op.attemptCount, fromUtc: now);
      await (_db.update(_db.outboxEntries)
            ..where((t) => t.operationId.equals(operationId)))
          .write(
        OutboxEntriesCompanion(
          state: Value(OutboxState.transientFailure.name),
          scheduledAtUtc: Value(next),
          lastAttemptUtc: Value(now),
          lastError: Value(error),
        ),
      );
    } else {
      await (_db.update(_db.outboxEntries)
            ..where((t) => t.operationId.equals(operationId)))
          .write(
        OutboxEntriesCompanion(
          state: Value(OutboxState.permanentFailure.name),
          lastAttemptUtc: Value(now),
          lastError: Value(error),
        ),
      );
    }
  }

  @override
  Future<void> cancel(String operationId) async {
    await (_db.update(_db.outboxEntries)
          ..where((t) => t.operationId.equals(operationId)))
        .write(OutboxEntriesCompanion(state: Value(OutboxState.cancelled.name)));
  }

  @override
  Future<int> pruneCompleted({Duration olderThan = const Duration(days: 7)}) async {
    final cutoff = DateTime.now().toUtc().subtract(olderThan);
    // Terminal rows whose completion (or creation, if never attempted) predates
    // the cutoff. Rows are small; fetch candidates then delete by id.
    final rows = await (_db.select(_db.outboxEntries)
          ..where(
            (t) =>
                t.state.equals(OutboxState.succeeded.name) |
                t.state.equals(OutboxState.permanentFailure.name) |
                t.state.equals(OutboxState.cancelled.name),
          ))
        .get();
    var removed = 0;
    for (final row in rows) {
      final completedAt = row.lastAttemptUtc ?? row.createdAtUtc;
      if (completedAt.isBefore(cutoff)) {
        await (_db.delete(_db.outboxEntries)
              ..where((t) => t.operationId.equals(row.operationId)))
            .go();
        removed++;
      }
    }
    return removed;
  }

  Future<int> _pendingCount() async {
    final rows = await _db.select(_db.outboxEntries).get();
    return rows
        .where(
          (r) =>
              r.state == OutboxState.pending.name ||
              r.state == OutboxState.inFlight.name ||
              r.state == OutboxState.transientFailure.name,
        )
        .length;
  }

  @override
  Stream<int> watchPendingCount() async* {
    yield await _pendingCount();
    yield* _db
        .select(_db.outboxEntries)
        .watch()
        .map(
          (rows) => rows
              .where(
                (r) =>
                    r.state == OutboxState.pending.name ||
                    r.state == OutboxState.inFlight.name ||
                    r.state == OutboxState.transientFailure.name,
              )
              .length,
        )
        .distinct();
  }

  @override
  Future<OutboxOperation?> getOperationById(String operationId) async {
    final row = await (_db.select(_db.outboxEntries)
          ..where((t) => t.operationId.equals(operationId)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }
}
