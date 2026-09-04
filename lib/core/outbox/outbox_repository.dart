import 'dart:async';

import 'outbox_operation.dart';
import 'outbox_retry_policy.dart';

/// Abstract storage contract for persisting, reading, and advancing the
/// lifecycle of background outbox operations.
abstract class OutboxRepository {
  /// Enqueues an operation for background dispatch.
  ///
  /// Invariant: Deduplicates by [operation.idempotencyKey]. If an active or
  /// completed operation already exists with this idempotency key, it will not
  /// insert a duplicate.
  Future<void> enqueue(OutboxOperation operation);

  /// Retrieves up to [limit] operations currently eligible for execution.
  Future<List<OutboxOperation>> getPendingOperations({int limit = 50});

  /// Transitions operation state to [OutboxState.inFlight].
  Future<void> markInFlight(String operationId);

  /// Transitions operation state to [OutboxState.succeeded].
  Future<void> markSucceeded(String operationId);

  /// Records an execution failure, scheduling a retry if [isRetryable] and
  /// within attempt limits, or marking as [OutboxState.permanentFailure].
  Future<void> markFailed(
    String operationId, {
    required String error,
    required bool isRetryable,
  });

  /// Cancels a pending or failing operation.
  Future<void> cancel(String operationId);

  /// Deletes terminal operations older than [olderThan].
  Future<int> pruneCompleted({Duration olderThan = const Duration(days: 7)});

  /// Emits the total number of operations currently pending or in-flight.
  Stream<int> watchPendingCount();

  /// Fetches an operation by its unique operationId.
  Future<OutboxOperation?> getOperationById(String operationId);
}

/// In-memory outbox repository for testing and standalone default runtime.
class InMemoryOutboxRepository implements OutboxRepository {
  InMemoryOutboxRepository({
    OutboxRetryPolicy? retryPolicy,
  }) : _retryPolicy = retryPolicy ?? const OutboxRetryPolicy();

  final OutboxRetryPolicy _retryPolicy;
  final Map<String, OutboxOperation> _operations = {};
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  void _notifyCount() {
    final count = _operations.values
        .where((op) =>
            op.state == OutboxState.pending ||
            op.state == OutboxState.inFlight ||
            op.state == OutboxState.transientFailure)
        .length;
    _pendingCountController.add(count);
  }

  @override
  Future<void> enqueue(OutboxOperation operation) async {
    // Idempotent on operationId: never silently overwrite an existing row.
    if (_operations.containsKey(operation.operationId)) {
      return;
    }
    // Deduplicate by idempotency key only while an operation is still active.
    // Terminal (succeeded/cancelled/permanentFailure) entries must not block
    // legitimate re-enqueue of the same logical key.
    final existing = _operations.values.any(
      (op) =>
          op.idempotencyKey == operation.idempotencyKey &&
          (op.state == OutboxState.pending ||
              op.state == OutboxState.inFlight ||
              op.state == OutboxState.transientFailure),
    );
    if (existing) {
      return; // Deduplicated
    }

    _operations[operation.operationId] = operation;
    _notifyCount();
  }

  @override
  Future<List<OutboxOperation>> getPendingOperations({int limit = 50}) async {
    final now = DateTime.now().toUtc();
    final eligible = _operations.values
        .where((op) =>
            (op.state == OutboxState.pending ||
                op.state == OutboxState.transientFailure) &&
            !op.scheduledAtUtc.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledAtUtc.compareTo(b.scheduledAtUtc));
    if (eligible.length <= limit) return eligible;
    return eligible.sublist(0, limit);
  }

  @override
  Future<void> markInFlight(String operationId) async {
    final op = _operations[operationId];
    if (op == null) return;
    _operations[operationId] = op.copyWith(
      state: OutboxState.inFlight,
      attemptCount: op.attemptCount + 1,
      lastAttemptUtc: DateTime.now().toUtc(),
    );
    _notifyCount();
  }

  @override
  Future<void> markSucceeded(String operationId) async {
    final op = _operations[operationId];
    if (op == null) return;
    _operations[operationId] = op.copyWith(
      state: OutboxState.succeeded,
      lastAttemptUtc: DateTime.now().toUtc(),
      clearLastError: true,
    );
    _notifyCount();
  }

  @override
  Future<void> markFailed(
    String operationId, {
    required String error,
    required bool isRetryable,
  }) async {
    final op = _operations[operationId];
    if (op == null) return;

    final newAttempts = op.attemptCount;
    final now = DateTime.now().toUtc();

    if (isRetryable && newAttempts < _retryPolicy.maxAttempts) {
      final nextSchedule = _retryPolicy.calculateNextSchedule(
        newAttempts,
        fromUtc: now,
      );
      _operations[operationId] = op.copyWith(
        state: OutboxState.transientFailure,
        scheduledAtUtc: nextSchedule,
        lastAttemptUtc: now,
        lastError: error,
      );
    } else {
      _operations[operationId] = op.copyWith(
        state: OutboxState.permanentFailure,
        lastAttemptUtc: now,
        lastError: error,
      );
    }
    _notifyCount();
  }

  @override
  Future<void> cancel(String operationId) async {
    final op = _operations[operationId];
    if (op == null) return;
    _operations[operationId] = op.copyWith(state: OutboxState.cancelled);
    _notifyCount();
  }

  @override
  Future<int> pruneCompleted({
    Duration olderThan = const Duration(days: 7),
  }) async {
    final cutoff = DateTime.now().toUtc().subtract(olderThan);
    final toRemove = _operations.values
        .where((op) {
          if (!op.isTerminal) return false;
          final completedAt = op.lastAttemptUtc ?? op.createdAtUtc;
          return completedAt.isBefore(cutoff);
        })
        .map((op) => op.operationId)
        .toList();

    for (final id in toRemove) {
      _operations.remove(id);
    }
    _notifyCount();
    return toRemove.length;
  }

  @override
  Stream<int> watchPendingCount() async* {
    yield _operations.values
        .where((op) =>
            op.state == OutboxState.pending ||
            op.state == OutboxState.inFlight ||
            op.state == OutboxState.transientFailure)
        .length;
    yield* _pendingCountController.stream;
  }

  @override
  Future<OutboxOperation?> getOperationById(String operationId) async =>
      _operations[operationId];

  void dispose() {
    _pendingCountController.close();
  }
}
