/// Deterministic conflict resolution engine for multi-device record synchronization.
library;

import '../capabilities/sync_capability.dart';
import 'sync_mutation.dart';

/// The result of reconciling a local mutation against an incoming remote mutation.
class SyncConflictResult {
  const SyncConflictResult({
    required this.winner,
    required this.wasLocalOverwritten,
    required this.isTombstoneDominant,
  });

  /// The winning mutation that must be stored in local SQLite.
  final SyncMutation winner;

  /// Whether the local mutation was superseded by the incoming remote mutation.
  final bool wasLocalOverwritten;

  /// Whether a tombstone (deletion) extinguished an earlier or concurrent write.
  final bool isTombstoneDominant;
}

/// Pure deterministic conflict reconciliation engine.
class SyncConflictResolver {
  const SyncConflictResolver();

  /// Synced tables inventory. Any table not in this set is strictly local-only or cache.
  static const Set<String> syncedTables = {
    'workout_sessions',
    'workout_sets',
    'exercises',
    'food_logs',
    'foods',
    'recipes',
    'recipe_ingredients',
    'body_weights',
    'routine_plans',
    'routine_days',
    'routine_exercises',
  };

  /// Strictly excluded local-only and cache tables.
  static const Set<String> localOnlyTables = {
    'outbox_operations',
    'notification_schedules',
    'remote_catalog_cache',
    'barcode_cache',
  };

  /// Returns whether a given table name is registered for multi-device synchronization.
  static bool isTableSynced(String tableName) => syncedTables.contains(tableName);

  /// Returns whether the domain represents immutable append-only evidence (workouts, weights).
  static bool isAppendOnlyEvidence(SyncDomain domain) {
    return domain == SyncDomain.workouts || domain == SyncDomain.weights;
  }

  /// Reconciles two conflicting mutations for the exact same entity.
  ///
  /// Guarantees:
  /// 1. Strict convergence: reconciling A with B produces the exact same winner
  ///    as reconciling B with A (commutativity).
  /// 2. Anti-resurrection: a tombstone with HLC >= write HLC always extinguishes the write.
  /// 3. Determinism: identical HLC timestamps resolve identically across all devices.
  SyncConflictResult reconcile({
    required SyncMutation local,
    required SyncMutation incoming,
  }) {
    if (local.entityId != incoming.entityId) {
      throw ArgumentError(
        'Cannot reconcile mutations with different entity IDs: "${local.entityId}" vs "${incoming.entityId}"',
      );
    }
    if (local.domain != incoming.domain) {
      throw ArgumentError(
        'Cannot reconcile mutations with different domains: "${local.domain.name}" vs "${incoming.domain.name}"',
      );
    }

    // Rule 1: Tombstone Dominance (Anti-Resurrection)
    final localIsDelete = local.isDeleted;
    final incomingIsDelete = incoming.isDeleted;

    if (localIsDelete != incomingIsDelete) {
      final tombstone = localIsDelete ? local : incoming;
      final write = localIsDelete ? incoming : local;

      // If the tombstone is newer or equal to the write, tombstone dominates
      if (tombstone.hlc >= write.hlc) {
        return SyncConflictResult(
          winner: tombstone,
          wasLocalOverwritten: incomingIsDelete,
          isTombstoneDominant: true,
        );
      } else {
        // The write was explicitly created after the deletion
        return SyncConflictResult(
          winner: write,
          wasLocalOverwritten: incoming == write,
          isTombstoneDominant: false,
        );
      }
    }

    // Rule 2: Last-Write-Wins (LWW) ordered strictly by HLC.
    // Commutativity: reconcile(A,B) must equal reconcile(B,A). HLC compareTo
    // already tie-breaks on nodeId, so comparison==0 means identical HLC
    // (same millis+counter+node). In that impossible-but-possible case, break
    // the tie deterministically on payload content (order-independent max)
    // instead of "local wins", which diverges per device.
    final comparison = incoming.hlc.compareTo(local.hlc);

    if (comparison > 0) {
      // Incoming is strictly newer
      return SyncConflictResult(
        winner: incoming,
        wasLocalOverwritten: true,
        isTombstoneDominant: false,
      );
    } else if (comparison < 0) {
      return SyncConflictResult(
        winner: local,
        wasLocalOverwritten: false,
        isTombstoneDominant: false,
      );
    } else {
      final incomingKey = incoming.payload.toString();
      final localKey = local.payload.toString();
      final incomingWins = incomingKey.compareTo(localKey) >= 0;
      return SyncConflictResult(
        winner: incomingWins ? incoming : local,
        wasLocalOverwritten: incomingWins,
        isTombstoneDominant: false,
      );
    }
  }
}
