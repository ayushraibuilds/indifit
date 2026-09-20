import 'package:drift/drift.dart';

/// Durable outbox spool for background connected work (PV1-NET-01).
///
/// Device-local by design: never synced, never backed up. Each device owns
/// its transmission queue; see `OutboxRepository` for the lifecycle contract.
class OutboxEntries extends Table {
  TextColumn get operationId => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get domain => text()();
  TextColumn get action => text()();
  TextColumn get entityId => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get scheduledAtUtc => dateTime()();
  TextColumn get state => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptUtc => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {operationId};
}

/// Tombstone log for synced-entity deletions (PV1-SYNC-01).
///
/// Records deletions that must extinguish concurrent/late writes on peer
/// devices (anti-resurrection). Device-local + backed-up eventually; purged
/// by the 30-day compactor (retention window lets offline peers catch up).
class TombstoneEntries extends Table {
  TextColumn get entityId => text()();
  TextColumn get domain => text()();
  IntColumn get hlcMillis => integer()();
  IntColumn get hlcCounter => integer().withDefault(const Constant(0))();
  TextColumn get hlcNodeId => text()();
  DateTimeColumn get deletedAtUtc =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {entityId, domain};
}

/// Tier-1 cache for normalized remote food candidates (PV1-CATALOG-01).
///
/// Device-local, 14-day TTL, never synced. Accepted/reviewed records are
/// copied into the canonical nutrition tables; this cache only speeds up
/// repeat lookups and offline reuse.
class CachedRemoteFoods extends Table {
  TextColumn get candidateId => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get candidateJson => text()();
  DateTimeColumn get fetchedAtUtc =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {candidateId};
}
