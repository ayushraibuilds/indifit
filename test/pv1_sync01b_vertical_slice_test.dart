import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/capabilities/account_capability.dart';
import 'package:indifit/core/capabilities/network_capability.dart';
import 'package:indifit/core/capabilities/sync_capability.dart';
import 'package:indifit/core/outbox/outbox.dart';
import 'package:indifit/core/sync/hlc_timestamp.dart';
import 'package:indifit/core/sync/sync_api_client.dart';
import 'package:indifit/core/sync/sync_mutation.dart';
import 'package:indifit/core/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/indifit_test_harness.dart';

class _FakeAccount implements AccountCapability {
  _FakeAccount({required this.nodeId});

  final String nodeId;

  @override
  Future<bool> get isAuthenticated async => true;

  @override
  Future<String?> get currentUserId async => 'sync-user-42';

  @override
  Future<String> get deviceId async => nodeId;

  @override
  Stream<AccountSession?> get onSessionChanged => Stream.value(
        AccountSession(
          userId: 'sync-user-42',
          deviceId: nodeId,
          displayName: 'Sync User',
        ),
      );

  @override
  Future<void> signOut() async {}

  @override
  Future<void> requestAccountDeletion() async {}
}

void main() {
  initializeIndiFitTestHarness();

  group('PV1-SYNC-01B: Multi-Device Sync Vertical Slice', () {
    late SharedPreferences prefsA;
    late SharedPreferences prefsB;

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      setIndiFitTestPreferences({});
      prefsA = await SharedPreferences.getInstance();
      prefsB = await SharedPreferences.getInstance();
    });

    test('Two devices converge across push and pull deltas', () async {
      final sharedRelay = InMemorySyncApiClient();

      // Device A setup
      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final networkA = TestableNetworkCapability(initialConnected: true);
      final outboxA = InMemoryOutboxRepository();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: networkA,
        outbox: outboxA,
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      // Device B setup
      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final networkB = TestableNetworkCapability(initialConnected: true);
      final outboxB = InMemoryOutboxRepository();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: networkB,
        outbox: outboxB,
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // 1. Device A records a weight measurement locally
      const weightHlc = HlcTimestamp(millis: 1000, counter: 0, nodeId: 'device-A');
      const mutationA = SyncMutation(
        entityId: '101',
        domain: SyncDomain.weights,
        type: SyncMutationType.insert,
        hlc: weightHlc,
        payload: {'weight_kg': 72.5, 'date': '2026-09-03'},
      );

      await serviceA.recordLocalMutation(mutationA);

      // Device A syncs (pushes to relay)
      final resultsA = await serviceA.triggerSync();
      expect(resultsA.every((r) => r.success), isTrue);
      expect(sharedRelay.totalStoredCount, 1);

      // 2. Device B has no weight yet
      var weightsB = await dbB.select(dbB.bodyMeasurements).get();
      expect(weightsB, isEmpty);

      // Device B syncs (pulls from relay)
      final resultsB = await serviceB.triggerSync();
      expect(resultsB.every((r) => r.success), isTrue);

      // 3. Verify Device B applied the record into local SQLite.
      // Global entity identity is opaque (UUID); local autoincrement ids are
      // never coerced from remote ids (that caused cross-device collisions).
      weightsB = await dbB.select(dbB.bodyMeasurements).get();
      expect(weightsB, hasLength(1));
      expect(weightsB.first.weight, 72.5);
    });

    test('Offline queueing survives until network reconnection', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scope = registerTestDatabaseScope();
      final db = scope.create();
      final network = TestableNetworkCapability(initialConnected: false); // OFFLINE
      final outbox = InMemoryOutboxRepository();

      final service = SyncService(
        db: db,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'offline-device'),
        network: network,
        outbox: outbox,
        apiClient: sharedRelay,
      );

      // Record while offline
      const hlc = HlcTimestamp(millis: 2000, counter: 0, nodeId: 'offline-device');
      const mutation = SyncMutation(
        entityId: '201',
        domain: SyncDomain.weights,
        type: SyncMutationType.insert,
        hlc: hlc,
        payload: {'weight_kg': 80.0, 'date': '2026-09-03'},
      );
      await service.recordLocalMutation(mutation);

      // Status reflects offline pending operations
      final statusOffline = await service.getStatus();
      expect(statusOffline.status.name, 'offline');
      expect(statusOffline.pendingOperationsCount, 1);

      // Trigger sync while offline fails safely
      final offlineResults = await service.triggerSync();
      expect(offlineResults.first.success, isFalse);
      expect(offlineResults.first.errorMessage, 'Device is offline.');
      expect(sharedRelay.totalStoredCount, 0);

      // Reconnect network
      network.setConnected(true);

      // Trigger sync online
      final onlineResults = await service.triggerSync();
      expect(onlineResults.every((r) => r.success), isTrue);
      expect(sharedRelay.totalStoredCount, 1);

      // Status transitions to synced
      final statusOnline = await service.getStatus();
      expect(statusOnline.status.name, 'synced');
    });

    test('Tombstone deletion propagates and removes record from peer device', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // 1. Create and sync initial workout session
      const createHlc = HlcTimestamp(millis: 3000, counter: 0, nodeId: 'device-A');
      const createMutation = SyncMutation(
        entityId: '301',
        domain: SyncDomain.workouts,
        type: SyncMutationType.insert,
        hlc: createHlc,
        payload: {'name': 'Morning Chest Day', 'completed_at': '2026-09-03T07:00:00Z'},
      );
      await serviceA.recordLocalMutation(createMutation);
      await serviceA.triggerSync();

      // Device B receives the workout
      await serviceB.triggerSync();
      var sessionsB = await dbB.select(dbB.workoutSessions).get();
      expect(sessionsB, hasLength(1));
      expect(sessionsB.first.name, 'Morning Chest Day');

      // 2. Device A deletes the workout (tombstone)
      const deleteHlc = HlcTimestamp(millis: 4000, counter: 0, nodeId: 'device-A');
      const deleteMutation = SyncMutation(
        entityId: '301',
        domain: SyncDomain.workouts,
        type: SyncMutationType.delete,
        hlc: deleteHlc,
      );
      await serviceA.recordLocalMutation(deleteMutation);
      await serviceA.triggerSync();

      // Device B pulls tombstone
      await serviceB.triggerSync();

      // 3. Verify record is extinguished on Device B
      sessionsB = await dbB.select(dbB.workoutSessions).get();
      expect(sessionsB, isEmpty);
    });
  });
}
