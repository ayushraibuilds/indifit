/// Durable background-job and outbox primitives for IndiFit.
///
/// Invariant: All user actions commit immediately to local SQLite.
/// Outbox operations represent background synchronization, telemetry,
/// or upload tasks dispatched asynchronously without blocking the user.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import 'drift_outbox_repository.dart';
import 'outbox_repository.dart';

export 'drift_outbox_repository.dart';
export 'outbox_operation.dart';
export 'outbox_repository.dart';
export 'outbox_retry_policy.dart';

/// Provider for the durable outbox repository.
///
/// Defaults to the SQLite-backed [DriftOutboxRepository] (schema v21), which
/// survives process death. Tests construct [InMemoryOutboxRepository] directly
/// for isolation.
final outboxRepositoryProvider = Provider<OutboxRepository>((ref) {
  return DriftOutboxRepository(ref.watch(databaseProvider));
});
