import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/cloud_backup_api_client.dart';
import 'package:indifit/core/backup/cloud_backup_service.dart';
import 'package:indifit/core/capabilities/account_capability.dart';
import 'package:indifit/core/capabilities/connected_status.dart';
import 'package:indifit/core/capabilities/network_capability.dart';
import 'package:indifit/core/outbox/outbox.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/indifit_test_harness.dart';

class _FakeAuthenticatedAccount implements AccountCapability {
  @override
  Future<bool> get isAuthenticated async => true;

  @override
  Future<String?> get currentUserId async => 'user-apple-sub-12345';

  @override
  Future<String> get deviceId async => 'iPhone-15-Pro-Max';

  @override
  Stream<AccountSession?> get onSessionChanged => Stream.value(
        const AccountSession(
          userId: 'user-apple-sub-12345',
          deviceId: 'iPhone-15-Pro-Max',
          displayName: 'Test User',
        ),
      );

  @override
  Future<void> signOut() async {}

  @override
  Future<void> requestAccountDeletion() async {}
}

void main() {
  initializeIndiFitTestHarness();

  group('PV1-CLOUD-01B: Immutable Encrypted Cloud Upload Vertical Slice', () {
    late SharedPreferences prefs;

    setUp(() async {
      setIndiFitTestPreferences({});
      prefs = await SharedPreferences.getInstance();
    });

    test('End-to-end V10 export encrypts and uploads to API client', () async {
      final scope = registerTestDatabaseScope();
      final db = scope.create();
      final foodRepo = FoodRepository(db);

      // Seed local food log
      await foodRepo.logFoodEntry(
        name: 'Dal Makhani',
        calories: 350,
        proteinG: 12.0,
        carbsG: 38.0,
        fatG: 16.0,
        servingLogged: 1,
        servingUnit: 'bowl',
        mealType: 'lunch',
      );

      final apiClient = InMemoryCloudBackupApiClient();
      final network = TestableNetworkCapability(initialConnected: true);
      final outbox = InMemoryOutboxRepository();

      final service = CloudBackupService(
        db: db,
        prefs: prefs,
        account: _FakeAuthenticatedAccount(),
        network: network,
        outbox: outbox,
        apiClient: apiClient,
        kmsSecret: 'kms-wrapping-key-sub-12345',
      );

      // 1. Initial status before backup
      var status = await service.getStatus();
      expect(status.status, ConnectedStatus.neverConfigured);

      // 2. Perform manual cloud backup
      final success = await service.createAndUploadSnapshot(isManual: true);
      expect(success, isTrue);

      // 3. Verify remote API client received snapshot
      final remoteList = await apiClient.listSnapshots();
      expect(remoteList.totalCount, 1);
      expect(remoteList.snapshots.first.deviceName, 'iPhone-15-Pro-Max');
      expect(remoteList.snapshots.first.schemaVersion, 22);
      expect(remoteList.snapshots.first.backupFormatVersion, 10);

      // 4. Verify local SharedPreferences metadata was updated
      expect(service.lastSuccessUtc, isNotNull);
      expect(service.lastFingerprint, isNotNull);

      // 5. Status transitions to synced
      status = await service.getStatus();
      expect(status.status, ConnectedStatus.synced);
      expect(status.lastSuccessUtc, isNotNull);
      expect(status.displayMessage, 'Up to date');
    });

    test('Fingerprint deduplication skips redundant upload when data is unchanged', () async {
      final scope = registerTestDatabaseScope();
      final db = scope.create();

      final apiClient = InMemoryCloudBackupApiClient();
      final network = TestableNetworkCapability(initialConnected: true);
      final outbox = InMemoryOutboxRepository();

      final service = CloudBackupService(
        db: db,
        prefs: prefs,
        account: _FakeAuthenticatedAccount(),
        network: network,
        outbox: outbox,
        apiClient: apiClient,
        kmsSecret: 'kms-wrapping-key-sub-12345',
      );

      // First upload
      await service.createAndUploadSnapshot(isManual: true);
      expect((await apiClient.listSnapshots()).totalCount, 1);

      // Second upload without changing the database
      final secondSuccess = await service.createAndUploadSnapshot(isManual: true);
      expect(secondSuccess, isTrue);

      // Count in API client should still be exactly 1! (Skipped upload)
      expect((await apiClient.listSnapshots()).totalCount, 1);
    });

    test('Background backup queues into Outbox and dispatches asynchronously', () async {
      final scope = registerTestDatabaseScope();
      final db = scope.create();

      final apiClient = InMemoryCloudBackupApiClient();
      final network = TestableNetworkCapability(initialConnected: true);
      final outbox = InMemoryOutboxRepository();
      addTearDown(outbox.dispose);

      final service = CloudBackupService(
        db: db,
        prefs: prefs,
        account: _FakeAuthenticatedAccount(),
        network: network,
        outbox: outbox,
        apiClient: apiClient,
        kmsSecret: 'kms-wrapping-key-sub-12345',
      );

      // Trigger background backup (isManual: false)
      final success = await service.createAndUploadSnapshot(isManual: false);
      expect(success, isTrue);

      // API client has not received it yet
      expect((await apiClient.listSnapshots()).totalCount, 0);

      // Outbox contains 1 pending backup operation
      final pending = await outbox.getPendingOperations();
      expect(pending, hasLength(1));
      expect(pending.first.domain, OutboxDomain.backup);
      expect(pending.first.state, OutboxState.pending);

      // Status reflects pending update
      var status = await service.getStatus();
      expect(status.status, ConnectedStatus.pending);
      expect(status.pendingOperationsCount, 1);
      expect(status.displayMessage, '1 update waiting to sync');

      // Dispatch the outbox operation
      final processed = await service.processOutboxBackup(pending.first);
      expect(processed, isTrue);

      // Outbox operation is now succeeded
      final op = await outbox.getOperationById(pending.first.operationId);
      expect(op!.state, OutboxState.succeeded);

      // API client now has the snapshot
      expect((await apiClient.listSnapshots()).totalCount, 1);

      // Status transitions to synced
      status = await service.getStatus();
      expect(status.status, ConnectedStatus.synced);
    });

    test('Offline state queues in outbox and reports offline status without blocking', () async {
      final scope = registerTestDatabaseScope();
      final db = scope.create();

      final apiClient = InMemoryCloudBackupApiClient();
      final network = TestableNetworkCapability(initialConnected: false); // Disconnected!
      final outbox = InMemoryOutboxRepository();
      addTearDown(outbox.dispose);

      final service = CloudBackupService(
        db: db,
        prefs: prefs,
        account: _FakeAuthenticatedAccount(),
        network: network,
        outbox: outbox,
        apiClient: apiClient,
        kmsSecret: 'kms-wrapping-key-sub-12345',
      );

      await service.createAndUploadSnapshot(isManual: false);

      final status = await service.getStatus();
      expect(status.status, ConnectedStatus.offline);
      expect(status.pendingOperationsCount, 1);
      expect(status.canPerformLocalActions, isTrue);
      expect(status.displayMessage, 'Offline — updates will sync when connected');
    });

    test('Unauthenticated user fails closed gracefully', () async {
      final scope = registerTestDatabaseScope();
      final db = scope.create();

      final apiClient = InMemoryCloudBackupApiClient();
      final network = TestableNetworkCapability(initialConnected: true);
      final outbox = InMemoryOutboxRepository();

      final service = CloudBackupService(
        db: db,
        prefs: prefs,
        account: const NoOpAccountCapability(), // Guest!
        network: network,
        outbox: outbox,
        apiClient: apiClient,
        kmsSecret: 'kms-wrapping-key-sub-12345',
      );

      final status = await service.getStatus();
      expect(status.status, ConnectedStatus.authenticationRequired);
      expect(status.displayMessage, 'Sign in required');

      final success = await service.createAndUploadSnapshot(isManual: true);
      expect(success, isFalse);
      expect(await outbox.getPendingOperations(), isEmpty);
    });

    test('Dispatch respects sign-out and wifi policy without losing queued work', () async {
      final scope = registerTestDatabaseScope();
      final db = scope.create();

      final apiClient = InMemoryCloudBackupApiClient();
      final network = TestableNetworkCapability(initialConnected: true);
      final outbox = InMemoryOutboxRepository();
      addTearDown(outbox.dispose);

      Future<CloudBackupService> buildService({
        required AccountCapability account,
        required NetworkCapability networkCapability,
      }) async =>
          CloudBackupService(
            db: db,
            prefs: prefs,
            account: account,
            network: networkCapability,
            outbox: outbox,
            apiClient: apiClient,
            kmsSecret: 'kms-wrapping-key-sub-12345',
          );

      // Queue one snapshot while authenticated and online.
      final online = await buildService(
        account: _FakeAuthenticatedAccount(),
        networkCapability: network,
      );
      expect(await online.createAndUploadSnapshot(isManual: false), isTrue);
      var pending = await outbox.getPendingOperations();
      expect(pending, hasLength(1));

      // Sign-out after enqueue: dispatch refuses but keeps the op queued
      // (retryable on next sign-in), instead of permanent-failing it.
      final guest = await buildService(
        account: const NoOpAccountCapability(),
        networkCapability: network,
      );
      expect(await guest.processOutboxBackup(pending.first), isFalse);
      pending = await outbox.getPendingOperations();
      expect(pending, hasLength(1));
      expect(pending.first.state, OutboxState.pending);
      expect((await apiClient.listSnapshots()).totalCount, 0);

      // Wifi-only policy on cellular: same leave-queued behavior.
      await prefs.setBool(CloudBackupService.wifiOnlyPrefKey, true);
      network.setConnected(true, NetworkTransportType.cellular);
      expect(await online.processOutboxBackup(pending.first), isFalse);
      expect(await outbox.getPendingOperations(), hasLength(1));

      // Back on wifi: dispatch succeeds and records the content fingerprint.
      network.setConnected(true, NetworkTransportType.wifi);
      expect(await online.processOutboxBackup(pending.first), isTrue);
      expect(await outbox.getPendingOperations(), isEmpty);
      expect((await apiClient.listSnapshots()).totalCount, 1);
      expect(online.lastFingerprint, isNotNull);
      await prefs.remove(CloudBackupService.wifiOnlyPrefKey);
    });
  });
}
