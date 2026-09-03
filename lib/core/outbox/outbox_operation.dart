/// Target domain of an outbox operation.
enum OutboxDomain {
  workout,
  food,
  weight,
  plan,
  backup,
  setting,
  profile,
}

/// Lifecycle state machine for outbox operations.
enum OutboxState {
  /// Waiting to be picked up by the background sync worker.
  pending,

  /// Currently being executed/transmitted by a network worker.
  inFlight,

  /// Confirmed successfully acknowledged by remote service.
  succeeded,

  /// Failed due to a retryable error (timeout, network down, 503); backoff scheduled.
  transientFailure,

  /// Failed due to a non-retryable error (malformed, 400 Bad Request, auth revoked).
  permanentFailure,

  /// Cancelled by user or superseded by a newer local state.
  cancelled,
}

/// Immutable record of a durable background operation queued for remote delivery.
///
/// Invariant: Local transactions commit to SQLite FIRST. The outbox operation is
/// an asynchronous artifact used strictly for remote convergence and backups.
class OutboxOperation {
  const OutboxOperation({
    required this.operationId,
    required this.idempotencyKey,
    required this.domain,
    required this.action,
    required this.entityId,
    required this.payload,
    required this.createdAtUtc,
    required this.scheduledAtUtc,
    this.state = OutboxState.pending,
    this.attemptCount = 0,
    this.lastAttemptUtc,
    this.lastError,
  });

  factory OutboxOperation.fromJson(Map<String, dynamic> json) {
    return OutboxOperation(
      operationId: json['operationId'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      domain: OutboxDomain.values.firstWhere(
        (d) => d.name == json['domain'],
        orElse: () => OutboxDomain.setting,
      ),
      action: json['action'] as String,
      entityId: json['entityId'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      scheduledAtUtc: DateTime.parse(json['scheduledAtUtc'] as String),
      state: OutboxState.values.firstWhere(
        (s) => s.name == json['state'],
        orElse: () => OutboxState.pending,
      ),
      attemptCount: json['attemptCount'] as int? ?? 0,
      lastAttemptUtc: json['lastAttemptUtc'] != null
          ? DateTime.parse(json['lastAttemptUtc'] as String)
          : null,
      lastError: json['lastError'] as String?,
    );
  }

  /// Unique stable identifier for this specific operation attempt.
  final String operationId;

  /// Idempotency key ensuring the server deduplicates repeated deliveries.
  final String idempotencyKey;

  /// Domain area owning the mutated record.
  final OutboxDomain domain;

  /// Semantic action name (e.g. 'log_food', 'finalize_workout', 'record_weight').
  final String action;

  /// Primary canonical ID of the affected local record.
  final String entityId;

  /// Serialized parameters required for remote execution.
  final Map<String, dynamic> payload;

  /// When the local change was originally committed.
  final DateTime createdAtUtc;

  /// Earliest time this operation may be dispatched (supports backoff).
  final DateTime scheduledAtUtc;

  /// Current lifecycle state.
  final OutboxState state;

  /// Total transmission attempts executed so far.
  final int attemptCount;

  /// Timestamp of the most recent transmission attempt.
  final DateTime? lastAttemptUtc;

  /// Human-readable description of the most recent error, if any.
  final String? lastError;

  bool get isTerminal =>
      state == OutboxState.succeeded ||
      state == OutboxState.permanentFailure ||
      state == OutboxState.cancelled;

  bool get isReadyForDispatch {
    if (state != OutboxState.pending && state != OutboxState.transientFailure) {
      return false;
    }
    return DateTime.now().toUtc().isAfter(scheduledAtUtc);
  }

  OutboxOperation copyWith({
    String? operationId,
    String? idempotencyKey,
    OutboxDomain? domain,
    String? action,
    String? entityId,
    Map<String, dynamic>? payload,
    DateTime? createdAtUtc,
    DateTime? scheduledAtUtc,
    OutboxState? state,
    int? attemptCount,
    DateTime? lastAttemptUtc,
    String? lastError,
  }) {
    return OutboxOperation(
      operationId: operationId ?? this.operationId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      domain: domain ?? this.domain,
      action: action ?? this.action,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      scheduledAtUtc: scheduledAtUtc ?? this.scheduledAtUtc,
      state: state ?? this.state,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptUtc: lastAttemptUtc ?? this.lastAttemptUtc,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'operationId': operationId,
        'idempotencyKey': idempotencyKey,
        'domain': domain.name,
        'action': action,
        'entityId': entityId,
        'payload': payload,
        'createdAtUtc': createdAtUtc.toIso8601String(),
        'scheduledAtUtc': scheduledAtUtc.toIso8601String(),
        'state': state.name,
        'attemptCount': attemptCount,
        'lastAttemptUtc': lastAttemptUtc?.toIso8601String(),
        'lastError': lastError,
      };

  @override
  String toString() =>
      'OutboxOperation(id: $operationId, domain: ${domain.name}, action: $action, state: ${state.name}, attempts: $attemptCount)';
}
