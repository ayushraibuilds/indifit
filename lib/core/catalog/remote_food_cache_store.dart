import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import 'food_catalog_models.dart';

/// Persistent Tier-1 cache on `cached_remote_foods` (schema v21).
///
/// Device-local, 14-day TTL, never synced. Accepted/reviewed records are
/// copied into the canonical nutrition tables; this store only speeds up
/// repeat barcode lookups and offline reuse. Stale rows fail closed (treated
/// as a miss and evicted on read).
class DriftRemoteFoodCacheStore {
  DriftRemoteFoodCacheStore(this._db);

  final AppDatabase _db;

  /// Tier-1 freshness window (CATALOG01A §3).
  static const Duration ttl = Duration(days: 14);

  bool _isStale(CachedRemoteFood row, DateTime now) =>
      now.difference(row.fetchedAtUtc) > ttl;

  Future<void> putCandidate(
    RemoteFoodCandidate candidate, {
    DateTime? fetchedAtUtc,
  }) async {
    await _db.into(_db.cachedRemoteFoods).insertOnConflictUpdate(
          CachedRemoteFoodsCompanion.insert(
            candidateId: candidate.id,
            barcode: Value(candidate.barcode),
            candidateJson: jsonEncode(candidate.toJson()),
            fetchedAtUtc: Value(fetchedAtUtc ?? DateTime.now().toUtc()),
          ),
        );
  }

  Future<RemoteFoodCandidate?> getCandidate(String candidateId) async {
    final row = await (_db.select(_db.cachedRemoteFoods)
          ..where((t) => t.candidateId.equals(candidateId)))
        .getSingleOrNull();
    if (row == null) return null;
    if (_isStale(row, DateTime.now().toUtc())) {
      await deleteCandidate(candidateId);
      return null;
    }
    try {
      return RemoteFoodCandidate.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.candidateJson) as Map),
      );
    } catch (_) {
      // Corrupt cache row fails closed and is evicted, never resurrected.
      await deleteCandidate(candidateId);
      return null;
    }
  }

  Future<RemoteFoodCandidate?> getByBarcode(String barcode) async {
    final rows = await (_db.select(_db.cachedRemoteFoods)
          ..where((t) => t.barcode.equals(barcode))
          ..orderBy([(t) => OrderingTerm.desc(t.fetchedAtUtc)])
          ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    return getCandidate(rows.first.candidateId);
  }

  Future<List<RemoteFoodCandidate>> recentCandidates({int limit = 50}) async {
    final rows = await (_db.select(_db.cachedRemoteFoods)
          ..orderBy([(t) => OrderingTerm.desc(t.fetchedAtUtc)])
          ..limit(limit * 2))
        .get();
    final now = DateTime.now().toUtc();
    final out = <RemoteFoodCandidate>[];
    final seen = <String>{};
    for (final row in rows) {
      if (out.length >= limit) break;
      if (!seen.add(row.candidateId)) continue;
      if (_isStale(row, now)) continue;
      try {
        out.add(
          RemoteFoodCandidate.fromJson(
            Map<String, dynamic>.from(jsonDecode(row.candidateJson) as Map),
          ),
        );
      } catch (_) {
        await deleteCandidate(row.candidateId);
      }
    }
    return out;
  }

  Future<void> deleteCandidate(String candidateId) async {
    await (_db.delete(_db.cachedRemoteFoods)
          ..where((t) => t.candidateId.equals(candidateId)))
        .go();
  }

  /// Evicts rows older than [ttl]. Returns the evicted count.
  Future<int> pruneStale({Duration? retention}) async {
    final cutoff =
        DateTime.now().toUtc().subtract(retention ?? ttl);
    return (_db.delete(_db.cachedRemoteFoods)
          ..where((t) => t.fetchedAtUtc.isSmallerThanValue(cutoff)))
        .go();
  }
}
