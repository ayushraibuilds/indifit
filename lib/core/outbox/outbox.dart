/// Durable background-job and outbox primitives for IndiFit.
///
/// Invariant: All user actions commit immediately to local SQLite.
/// Outbox operations represent background synchronization, telemetry,
/// or upload tasks dispatched asynchronously without blocking the user.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'outbox_repository.dart';

export 'outbox_operation.dart';
export 'outbox_repository.dart';
export 'outbox_retry_policy.dart';

/// Provider for the durable outbox repository.
///
/// Defaults to an in-memory repository for isolated execution and tests;
/// replaced with a persistent SQLite table in subsequent cloud packages.
final outboxRepositoryProvider = Provider<OutboxRepository>((ref) {
  final repo = InMemoryOutboxRepository();
  ref.onDispose(repo.dispose);
  return repo;
});
