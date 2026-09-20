import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../capabilities/sync_capability.dart';
import 'hlc_timestamp.dart';
import 'sync_mutation.dart';

/// Persistent tombstone log on `tombstone_entries` (schema v21).
///
/// Closes the anti-resurrection gap: deletions survive process death and
/// reinstall-scoped restores, so a late or replayed write with
/// `writeHlc <= tombstoneHlc` is extinguished instead of resurrecting the row.
/// Tombstones live 30 days ([SyncTombstone.defaultRetention]) so offline peers
/// can catch up before the compactor purges them.
class DriftSyncTombstoneStore {
  DriftSyncTombstoneStore(this._db);

  final AppDatabase _db;

  SyncTombstone _toDomain(TombstoneEntry row) {
    SyncDomain? domain;
    for (final d in SyncDomain.values) {
      if (d.name == row.domain) domain = d;
    }
    if (domain == null) {
      throw FormatException(
        'Unknown SyncDomain "${row.domain}" in tombstone row ${row.entityId}.',
      );
    }
    return SyncTombstone(
      entityId: row.entityId,
      domain: domain,
      deletedAtHlc: HlcTimestamp(
        millis: row.hlcMillis,
        counter: row.hlcCounter,
        nodeId: row.hlcNodeId,
      ),
      createdAtUtc: row.deletedAtUtc,
    );
  }

  /// Records a deletion, keeping the newest HLC on conflicts.
  Future<void> recordTombstone(SyncTombstone tombstone) async {
    final existing = await getTombstone(
      tombstone.entityId,
      tombstone.domain,
    );
    if (existing != null &&
        existing.deletedAtHlc.compareTo(tombstone.deletedAtHlc) >= 0) {
      return; // Stored tombstone already dominates.
    }
    await _db.into(_db.tombstoneEntries).insertOnConflictUpdate(
          TombstoneEntriesCompanion.insert(
            entityId: tombstone.entityId,
            domain: tombstone.domain.name,
            hlcMillis: tombstone.deletedAtHlc.millis,
            hlcCounter: Value(tombstone.deletedAtHlc.counter),
            hlcNodeId: tombstone.deletedAtHlc.nodeId,
            deletedAtUtc: Value(tombstone.createdAtUtc),
          ),
        );
  }

  Future<SyncTombstone?> getTombstone(
    String entityId,
    SyncDomain domain,
  ) async {
    final row = await (_db.select(_db.tombstoneEntries)
          ..where((t) => t.entityId.equals(entityId))
          ..where((t) => t.domain.equals(domain.name)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  /// True when a stored tombstone for [entityId]/[domain] dominates a write
  /// at [writeHlc] (tombstone HLC >= write HLC).
  Future<bool> isExtinguished(
    String entityId,
    SyncDomain domain,
    HlcTimestamp writeHlc,
  ) async {
    final tombstone = await getTombstone(entityId, domain);
    return tombstone != null &&
        tombstone.deletedAtHlc.compareTo(writeHlc) >= 0;
  }

  /// Purges tombstones older than [retention] (default 30 days).
  Future<int> pruneExpired({Duration? retention}) async {
    final cutoff = DateTime.now().toUtc().subtract(
          retention ?? SyncTombstone.defaultRetention,
        );
    return (_db.delete(_db.tombstoneEntries)
          ..where((t) => t.deletedAtUtc.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<int> count() async {
    final row = await (_db.selectOnly(_db.tombstoneEntries)
          ..addColumns([_db.tombstoneEntries.entityId.count()]))
        .getSingle();
    return row.read(_db.tombstoneEntries.entityId.count()) ?? 0;
  }
}
