/// Standardized user-facing connection, sync, and backup status domain for
/// IndiFit.
///
/// Invariant: Local-first actions always proceed immediately. Status tokens
/// describe the background synchronization/capability state, never gating
/// local workout, nutrition, or weight tracking.
library;

/// High-level operational status of a connected capability.
enum ConnectedStatus {
  /// The capability has never been set up or configured (e.g. cloud backup
  /// disabled, no remote account connected).
  neverConfigured,

  /// Local changes have been persisted and are queued in the outbox waiting
  /// for network connectivity or execution.
  pending,

  /// A background sync, upload, or download operation is currently in flight.
  inFlight,

  /// All local records and remote services are confirmed synchronized.
  synced,

  /// Device currently has no active internet connection; app is operating in
  /// its primary offline-first mode.
  offline,

  /// Remote operation requires user authentication or re-authentication.
  authenticationRequired,

  /// The external service is temporarily unreachable (e.g. HTTP 503, DNS
  /// resolution timeout, provider maintenance).
  providerUnavailable,

  /// A permanent error occurred requiring user action (e.g. storage quota
  /// exceeded, unresolvable conflict).
  permanentError,
}

/// Immutable value object representing current connected capability state.
class ConnectedStatusState {
  const ConnectedStatusState({
    required this.status,
    this.lastSuccessUtc,
    this.pendingOperationsCount = 0,
    this.customMessage,
  });

  /// Factory for unconfigured state.
  const ConnectedStatusState.neverConfigured()
      : status = ConnectedStatus.neverConfigured,
        lastSuccessUtc = null,
        pendingOperationsCount = 0,
        customMessage = null;

  /// Factory for up-to-date state.
  const ConnectedStatusState.synced({this.lastSuccessUtc})
      : status = ConnectedStatus.synced,
        pendingOperationsCount = 0,
        customMessage = null;

  /// Factory for normal offline state.
  const ConnectedStatusState.offline({
    this.lastSuccessUtc,
    int pendingCount = 0,
  })  : status = ConnectedStatus.offline,
        pendingOperationsCount = pendingCount,
        customMessage = null;

  /// Factory for queued pending operations.
  const ConnectedStatusState.pending({
    required int count,
    this.lastSuccessUtc,
  })  : status = ConnectedStatus.pending,
        pendingOperationsCount = count,
        customMessage = null;

  /// Current lifecycle status.
  final ConnectedStatus status;

  /// Timestamp of the last verified successful operation in UTC.
  final DateTime? lastSuccessUtc;

  /// Number of operations currently queued in the local outbox.
  final int pendingOperationsCount;

  /// Optional override message if domain needs explicit copy.
  ///
  /// Caller-owned: must already be consumer copy (no table names, exception
  /// class names, UUIDs, or numeric IDs). The built-in messages are filtered;
  /// custom messages bypass that filter by design, so keep them jargon-free.
  final String? customMessage;

  /// True if the user can continue executing workouts and logging data.
  ///
  /// Invariant: In IndiFit, this is ALWAYS true across all statuses because
  /// local SQLite authority handles all personal truth offline.
  bool get canPerformLocalActions => true;

  /// True if background synchronization is functioning normally without
  /// errors requiring user intervention.
  bool get isHealthy =>
      status == ConnectedStatus.synced ||
      status == ConnectedStatus.pending ||
      status == ConnectedStatus.inFlight ||
      status == ConnectedStatus.neverConfigured ||
      status == ConnectedStatus.offline;

  /// True if user action or attention is required to resume background sync.
  bool get requiresUserAttention =>
      status == ConnectedStatus.authenticationRequired ||
      status == ConnectedStatus.permanentError;

  /// User-facing consumer copy without internal implementation jargon (no
  /// Drift, SQLite, UUID, or exception class names).
  String get displayMessage {
    if (customMessage != null && customMessage!.isNotEmpty) {
      return customMessage!;
    }

    switch (status) {
      case ConnectedStatus.neverConfigured:
        return 'Not configured';
      case ConnectedStatus.pending:
        if (pendingOperationsCount <= 1) {
          return '1 update waiting to sync';
        }
        return '$pendingOperationsCount updates waiting to sync';
      case ConnectedStatus.inFlight:
        return 'Syncing updates…';
      case ConnectedStatus.synced:
        return 'Up to date';
      case ConnectedStatus.offline:
        if (pendingOperationsCount > 0) {
          return 'Offline — updates will sync when connected';
        }
        return 'Offline';
      case ConnectedStatus.authenticationRequired:
        return 'Sign in required';
      case ConnectedStatus.providerUnavailable:
        return 'Service temporarily unavailable';
      case ConnectedStatus.permanentError:
        return 'Sync issue — action needed';
    }
  }

  ConnectedStatusState copyWith({
    ConnectedStatus? status,
    DateTime? lastSuccessUtc,
    int? pendingOperationsCount,
    String? customMessage,
    bool clearCustomMessage = false,
    bool clearLastSuccessUtc = false,
  }) {
    return ConnectedStatusState(
      status: status ?? this.status,
      lastSuccessUtc:
          clearLastSuccessUtc ? null : (lastSuccessUtc ?? this.lastSuccessUtc),
      pendingOperationsCount:
          pendingOperationsCount ?? this.pendingOperationsCount,
      customMessage:
          clearCustomMessage ? null : (customMessage ?? this.customMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectedStatusState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          lastSuccessUtc == other.lastSuccessUtc &&
          pendingOperationsCount == other.pendingOperationsCount &&
          customMessage == other.customMessage;

  @override
  int get hashCode => Object.hash(
        status,
        lastSuccessUtc,
        pendingOperationsCount,
        customMessage,
      );

  @override
  String toString() =>
      'ConnectedStatusState(status: $status, pending: $pendingOperationsCount, message: "$displayMessage")';
}
