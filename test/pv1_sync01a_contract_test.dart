import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/capabilities/sync_capability.dart';
import 'package:indifit/core/sync/hlc_timestamp.dart';
import 'package:indifit/core/sync/sync_conflict_resolver.dart';
import 'package:indifit/core/sync/sync_mutation.dart';

void main() {
  group('PV1-SYNC-01A: Multi-Device Sync Specification & Contracts', () {
    group('Hybrid Logical Clocks (HLC)', () {
      test('HlcTimestamp implements strict total ordering', () {
        const t1 = HlcTimestamp(millis: 1000, counter: 0, nodeId: 'device-A');
        const t2 = HlcTimestamp(millis: 1000, counter: 1, nodeId: 'device-A');
        const t3 = HlcTimestamp(millis: 1000, counter: 1, nodeId: 'device-B');
        const t4 = HlcTimestamp(millis: 2000, counter: 0, nodeId: 'device-A');

        expect(t1 < t2, isTrue);
        expect(t2 < t3, isTrue);
        expect(t3 < t4, isTrue);

        final list = [t4, t2, t1, t3];
        list.sort();
        expect(list, equals([t1, t2, t3, t4]));
      });

      test('HlcTimestamp serializes to canonical string and round-trips exactly', () {
        const original = HlcTimestamp(
          millis: 1725350000000,
          counter: 42,
          nodeId: 'iPhone-15-Pro',
        );

        final canonicalString = original.toString();
        final parsed = HlcTimestamp.fromString(canonicalString);

        expect(parsed, equals(original));
        expect(parsed.millis, 1725350000000);
        expect(parsed.counter, 42);
        expect(parsed.nodeId, 'iPhone-15-Pro');
      });

      test('HlcClock maintains monotonicity across backward wall-clock jumps', () {
        final clock = HlcClock(nodeId: 'node-1');

        // Local events at wall time 10000
        final t1 = clock.send(physicalTimeMillis: 10000);
        final t2 = clock.send(physicalTimeMillis: 10000);
        expect(t1.millis, 10000);
        expect(t1.counter, 0);
        expect(t2.millis, 10000);
        expect(t2.counter, 1);

        // Physical clock jumps backward by 5 seconds (NTP / manual change)
        final t3 = clock.send(physicalTimeMillis: 5000);
        expect(t3.millis, 10000, reason: 'HLC millis must never decrease');
        expect(t3.counter, 2);

        // Physical clock advances past previous logical time
        final t4 = clock.send(physicalTimeMillis: 12000);
        expect(t4.millis, 12000);
        expect(t4.counter, 0, reason: 'Counter resets to 0 when physical time advances');
      });

      test('HlcClock assimilates remote timestamp and jumps forward', () {
        final localClock = HlcClock(nodeId: 'device-A', initialMillis: 1000);

        // Remote timestamp from device-B with higher physical time
        const remoteT = HlcTimestamp(millis: 5000, counter: 3, nodeId: 'device-B');

        final updatedLocal = localClock.receive(remoteT, physicalTimeMillis: 2000);

        expect(updatedLocal.millis, 5000);
        expect(updatedLocal.counter, 4);
        expect(updatedLocal > remoteT, isTrue);
      });
    });

    group('Deterministic Conflict Resolution & Anti-Resurrection', () {
      const resolver = SyncConflictResolver();
      const entityId = 'food-log-12345';
      const domain = SyncDomain.nutritionLogs;

      test('Last-Write-Wins (LWW) strictly resolves concurrent edits commutatively', () {
        const mutationA = SyncMutation(
          entityId: entityId,
          domain: domain,
          type: SyncMutationType.update,
          hlc: HlcTimestamp(millis: 2000, counter: 1, nodeId: 'device-A'),
          payload: {'food_name': 'Roti', 'quantity': 2},
        );

        const mutationB = SyncMutation(
          entityId: entityId,
          domain: domain,
          type: SyncMutationType.update,
          hlc: HlcTimestamp(millis: 2000, counter: 2, nodeId: 'device-B'),
          payload: {'food_name': 'Roti', 'quantity': 3},
        );

        // Reconciling A against B
        final result1 = resolver.reconcile(local: mutationA, incoming: mutationB);
        expect(result1.winner, equals(mutationB));
        expect(result1.wasLocalOverwritten, isTrue);

        // Reconciling B against A (Commutativity)
        final result2 = resolver.reconcile(local: mutationB, incoming: mutationA);
        expect(result2.winner, equals(mutationB));
        expect(result2.wasLocalOverwritten, isFalse);
      });

      test('Tombstone dominance prevents resurrection from older or concurrent writes', () {
        const olderWrite = SyncMutation(
          entityId: entityId,
          domain: domain,
          type: SyncMutationType.update,
          hlc: HlcTimestamp(millis: 3000, counter: 0, nodeId: 'device-A'),
          payload: {'quantity': 5},
        );

        const newerTombstone = SyncMutation(
          entityId: entityId,
          domain: domain,
          type: SyncMutationType.delete,
          hlc: HlcTimestamp(millis: 3500, counter: 0, nodeId: 'device-B'),
        );

        // Arriving after local write
        final res1 = resolver.reconcile(local: olderWrite, incoming: newerTombstone);
        expect(res1.winner, equals(newerTombstone));
        expect(res1.isTombstoneDominant, isTrue);

        // Delayed write arriving after local tombstone
        final res2 = resolver.reconcile(local: newerTombstone, incoming: olderWrite);
        expect(res2.winner, equals(newerTombstone));
        expect(res2.isTombstoneDominant, isTrue);
        expect(res2.wasLocalOverwritten, isFalse);
      });

      test('Legitimate write created strictly after tombstone succeeds', () {
        const tombstone = SyncMutation(
          entityId: entityId,
          domain: domain,
          type: SyncMutationType.delete,
          hlc: HlcTimestamp(millis: 4000, counter: 0, nodeId: 'device-A'),
        );

        const recreatedWrite = SyncMutation(
          entityId: entityId,
          domain: domain,
          type: SyncMutationType.insert,
          hlc: HlcTimestamp(millis: 5000, counter: 0, nodeId: 'device-B'),
          payload: {'quantity': 1},
        );

        final result = resolver.reconcile(local: tombstone, incoming: recreatedWrite);
        expect(result.winner, equals(recreatedWrite));
        expect(result.wasLocalOverwritten, isTrue);
        expect(result.isTombstoneDominant, isFalse);
      });
    });

    group('Entity Inventory & Boundary Enforcement', () {
      test('Identifies core fitness records as synchronized tables', () {
        expect(SyncConflictResolver.isTableSynced('workout_sessions'), isTrue);
        expect(SyncConflictResolver.isTableSynced('workout_sets'), isTrue);
        expect(SyncConflictResolver.isTableSynced('food_logs'), isTrue);
        expect(SyncConflictResolver.isTableSynced('body_weights'), isTrue);
        expect(SyncConflictResolver.isTableSynced('recipes'), isTrue);
      });

      test('Identifies internal queues, alarms, and caches as strictly local-only', () {
        expect(SyncConflictResolver.isTableSynced('outbox_operations'), isFalse);
        expect(SyncConflictResolver.isTableSynced('notification_schedules'), isFalse);
        expect(SyncConflictResolver.isTableSynced('remote_catalog_cache'), isFalse);
        expect(SyncConflictResolver.isTableSynced('barcode_cache'), isFalse);
      });

      test('Correctly classifies append-only historical evidence domains', () {
        expect(SyncConflictResolver.isAppendOnlyEvidence(SyncDomain.workouts), isTrue);
        expect(SyncConflictResolver.isAppendOnlyEvidence(SyncDomain.weights), isTrue);
        expect(SyncConflictResolver.isAppendOnlyEvidence(SyncDomain.nutritionLogs), isFalse);
        expect(SyncConflictResolver.isAppendOnlyEvidence(SyncDomain.preferences), isFalse);
      });

      test('SyncTombstone enforces 30-day retention before expiration', () {
        final now = DateTime.utc(2026, 9, 3, 12, 0);
        final freshTombstone = SyncTombstone(
          entityId: 'item-1',
          domain: SyncDomain.workouts,
          deletedAtHlc: const HlcTimestamp(millis: 100, counter: 0, nodeId: 'A'),
          createdAtUtc: now.subtract(const Duration(days: 10)),
        );
        expect(freshTombstone.isExpired(now: now), isFalse);

        final oldTombstone = SyncTombstone(
          entityId: 'item-2',
          domain: SyncDomain.workouts,
          deletedAtHlc: const HlcTimestamp(millis: 100, counter: 0, nodeId: 'A'),
          createdAtUtc: now.subtract(const Duration(days: 35)),
        );
        expect(oldTombstone.isExpired(now: now), isTrue);
      });
    });
  });
}
