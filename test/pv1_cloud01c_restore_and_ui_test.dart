import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/cloud_backup_api_client.dart';
import 'package:indifit/core/backup/cloud_backup_api_contract.dart';
import 'package:indifit/core/backup/cloud_backup_service.dart';
import 'package:indifit/core/capabilities/capabilities_registry.dart';
import 'package:indifit/core/outbox/outbox.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/features/settings/widgets/cloud_backup_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/indifit_test_harness.dart';

class _FakeAccount implements AccountCapability {
  @override
  Future<bool> get isAuthenticated async => true;

  @override
  Future<String?> get currentUserId async => 'user-apple-sub-12345';

  @override
  Future<String> get deviceId async => 'iPhone-15-Pro';

  @override
  Stream<AccountSession?> get onSessionChanged => Stream.value(
        const AccountSession(
          userId: 'user-apple-sub-12345',
          deviceId: 'iPhone-15-Pro',
          displayName: 'Test User',
        ),
      );

  @override
  Future<void> signOut() async {}

  @override
  Future<void> requestAccountDeletion() async {}
}

class _MockCloudBackupCapability implements CloudBackupCapability {
  bool backupCalled = false;
  ConnectedStatusState status = const ConnectedStatusState.neverConfigured();

  @override
  Future<ConnectedStatusState> getStatus() async => status;

  @override
  Future<bool> createAndUploadSnapshot({
    bool isManual = false,
    bool isWeeklyMilestone = false,
  }) async {
    backupCalled = true;
    status = const ConnectedStatusState.synced();
    return true;
  }

  @override
  Future<List<RemoteBackupSnapshotMetadata>> listRemoteSnapshots() async => [];

  @override
  Future<void> restoreCloudSnapshot(String snapshotId) async {}

  @override
  Future<void> deleteAllRemoteSnapshots() async {}

  @override
  Future<List<int>?> downloadSnapshot(String snapshotId) async => null;

  @override
  Future<void> deleteRemoteSnapshot(String snapshotId) async {}

  @override
  Future<bool> uploadSnapshot({
    required String snapshotId,
    required List<int> encryptedBytes,
    required Map<String, dynamic> metadata,
  }) async =>
      true;
}

void main() {
  initializeIndiFitTestHarness();

  group('PV1-CLOUD-01C: Restore Operations & Settings UI', () {
    late SharedPreferences prefs;

    setUp(() async {
      setIndiFitTestPreferences({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Transactional restore replaces local database with cloud snapshot', () async {
      final scope = registerTestDatabaseScope();
      final db = scope.create();
      final foodRepo = FoodRepository(db);

      // 1. Seed initial data
      await foodRepo.logFoodEntry(
        name: 'Original Cloud Paneer',
        calories: 300,
        proteinG: 18.0,
        carbsG: 6.0,
        fatG: 22.0,
        servingLogged: 1,
        servingUnit: 'piece',
        mealType: 'lunch',
      );

      final apiClient = InMemoryCloudBackupApiClient();
      final network = TestableNetworkCapability(initialConnected: true);
      final outbox = InMemoryOutboxRepository();
      const kmsSecret = 'test-kms-secret-user-123';

      final service = CloudBackupService(
        db: db,
        prefs: prefs,
        account: _FakeAccount(),
        network: network,
        outbox: outbox,
        apiClient: apiClient,
        kmsSecret: kmsSecret,
      );

      // 2. Upload snapshot to cloud
      await service.createAndUploadSnapshot(isManual: true);
      final remoteList = await apiClient.listSnapshots();
      expect(remoteList.totalCount, 1);
      final snapshotId = remoteList.snapshots.first.snapshotId;

      // 3. Mutate local database with temporary data
      await foodRepo.logFoodEntry(
        name: 'Temporary Unbacked Food',
        calories: 50,
        proteinG: 1.0,
        carbsG: 10.0,
        fatG: 0.0,
        servingLogged: 1,
        servingUnit: 'piece',
        mealType: 'snack',
      );
      var currentLogs = await db.select(db.foodLogs).get();
      expect(currentLogs, hasLength(2));

      // 4. Execute transactional cloud restore
      await service.restoreCloudSnapshot(snapshotId);

      // 5. Verify local database has reverted to exact original snapshot
      currentLogs = await db.select(db.foodLogs).get();
      expect(currentLogs, hasLength(1));
      expect(currentLogs.first.name, 'Original Cloud Paneer');
    });

    test('Corrupted or tampered cloud snapshot throws and aborts without mutating local database', () async {
      final scope = registerTestDatabaseScope();
      final db = scope.create();
      final foodRepo = FoodRepository(db);

      // Seed local data
      await foodRepo.logFoodEntry(
        name: 'Safe Untouched Roti',
        calories: 120,
        proteinG: 3.5,
        carbsG: 22.0,
        fatG: 1.0,
        servingLogged: 1,
        servingUnit: 'piece',
        mealType: 'dinner',
      );

      final apiClient = InMemoryCloudBackupApiClient();
      final network = TestableNetworkCapability(initialConnected: true);
      final outbox = InMemoryOutboxRepository();

      final service = CloudBackupService(
        db: db,
        prefs: prefs,
        account: _FakeAccount(),
        network: network,
        outbox: outbox,
        apiClient: apiClient,
        kmsSecret: 'secret-key',
      );

      // Upload a corrupt envelope manually into API client
      const corruptSnapshotId = 'snap-corrupted';
      await apiClient.uploadSnapshot(
        CloudBackupSnapshotUploadRequest(
          snapshotId: corruptSnapshotId,
          ciphertextBase64: base64.encode(Uint8List.fromList([1, 2, 3, 4, 5])),
          wrappedKeyBase64: base64.encode(Uint8List.fromList([6, 7, 8, 9, 0])),
          sha256Checksum: 'invalid-checksum',
          byteSize: 5,
          schemaVersion: 20,
          backupFormatVersion: 10,
          deviceName: 'Attacker Phone',
        ),
      );

      // Attempt restore
      expect(
        () => service.restoreCloudSnapshot(corruptSnapshotId),
        throwsA(isA<FormatException>()),
      );

      // Verify local database remains 100% intact
      final logs = await db.select(db.foodLogs).get();
      expect(logs, hasLength(1));
      expect(logs.first.name, 'Safe Untouched Roti');
    });

    test('Delete all cloud backups purges remote snapshots and clears local metadata', () async {
      final scope = registerTestDatabaseScope();
      final db = scope.create();

      final apiClient = InMemoryCloudBackupApiClient();
      final network = TestableNetworkCapability(initialConnected: true);
      final outbox = InMemoryOutboxRepository();

      final service = CloudBackupService(
        db: db,
        prefs: prefs,
        account: _FakeAccount(),
        network: network,
        outbox: outbox,
        apiClient: apiClient,
      );

      await service.createAndUploadSnapshot(isManual: true);
      expect((await apiClient.listSnapshots()).totalCount, 1);
      expect(service.lastSuccessUtc, isNotNull);

      // Delete all
      await service.deleteAllRemoteSnapshots();
      expect((await apiClient.listSnapshots()).totalCount, 0);
      expect(service.lastSuccessUtc, isNull);
      expect(service.lastFingerprint, isNull);
    });

    testWidgets('CloudBackupCard renders live status and triggers manual backup', (tester) async {
      final mockCapability = _MockCloudBackupCapability();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cloudBackupCapabilityProvider.overrideWithValue(mockCapability),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CloudBackupCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify title & initial button states
      expect(find.text('Encrypted cloud backup'), findsOneWidget);
      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Cloud history'), findsOneWidget);

      // Tap "Back up now"
      await tester.tap(find.text('Back up now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify backup was called
      expect(mockCapability.backupCalled, isTrue);
    });
  });
}
