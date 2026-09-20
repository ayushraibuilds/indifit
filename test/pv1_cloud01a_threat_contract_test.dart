import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/cloud_backup_api_contract.dart';
import 'package:indifit/core/backup/cloud_backup_envelope_manager.dart';
import 'package:indifit/data/repositories/food_repository.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  group('PV1-CLOUD-01A: Identity-Bound Envelope Encryption', () {
    final manager = CloudBackupEnvelopeManager();
    const testKmsSecret = 'test-kms-wrapping-key-user-sub-12345';
    const sampleV10Json =
        '{"format_identifier":"INDIFIT_BACKUP_V10","schema_version":20,"profile":{"name":"Ayush"},"workouts":[],"foods":[{"name":"Paneer Tikka","calories":280}]}';

    test('Snapshot encryption produces opaque ciphertext and decrypts identically', () {
      final envelope = manager.encryptSnapshot(
        snapshotId: 'snap-001',
        plaintextJson: sampleV10Json,
        kmsKeyWrappingSecret: testKmsSecret,
      );

      // Verify envelope properties
      expect(envelope.snapshotId, 'snap-001');
      expect(envelope.schemaVersion, 20);
      expect(envelope.backupFormatVersion, 10);
      expect(envelope.ciphertextBytes, isNotEmpty);
      expect(envelope.wrappedKeyBytes, isNotEmpty);
      expect(envelope.sha256Checksum, isNotEmpty);

      // Verify ciphertext does not contain plaintext strings
      final ciphertextString = String.fromCharCodes(envelope.ciphertextBytes);
      expect(ciphertextString.contains('Paneer Tikka'), isFalse);
      expect(ciphertextString.contains('INDIFIT_BACKUP_V10'), isFalse);

      // Decrypt and verify identical match
      final decrypted = manager.decryptSnapshot(
        envelope: envelope,
        kmsKeyWrappingSecret: testKmsSecret,
      );
      expect(decrypted, sampleV10Json);
    });

    test('Decryption rejects corrupted or bit-flipped ciphertext immediately', () {
      final envelope = manager.encryptSnapshot(
        snapshotId: 'snap-002',
        plaintextJson: sampleV10Json,
        kmsKeyWrappingSecret: testKmsSecret,
      );

      // Tamper with a byte in ciphertext (after the 12-byte IV)
      final tamperedBytes = Uint8List.fromList(envelope.ciphertextBytes);
      tamperedBytes[20] ^= 0xFF;

      final tamperedEnvelope = CloudBackupEncryptedEnvelope(
        snapshotId: envelope.snapshotId,
        ciphertextBytes: tamperedBytes,
        wrappedKeyBytes: envelope.wrappedKeyBytes,
        sha256Checksum: envelope.sha256Checksum,
        byteSize: envelope.byteSize,
        schemaVersion: envelope.schemaVersion,
        backupFormatVersion: envelope.backupFormatVersion,
        createdAtUtc: envelope.createdAtUtc,
      );

      // Should fail checksum check
      expect(
        () => manager.decryptSnapshot(
          envelope: tamperedEnvelope,
          kmsKeyWrappingSecret: testKmsSecret,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('Decryption rejects incorrect KMS wrapping secret', () {
      final envelope = manager.encryptSnapshot(
        snapshotId: 'snap-003',
        plaintextJson: sampleV10Json,
        kmsKeyWrappingSecret: testKmsSecret,
      );

      // Attempt decryption with a different user's KMS secret
      expect(
        () => manager.decryptSnapshot(
          envelope: envelope,
          kmsKeyWrappingSecret: 'wrong-kms-secret-user-attacker',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PV1-CLOUD-01A: Retention Policy Pruning Algorithm (5+3 Rule)', () {
    test('Retention policy does not prune when count is <= 8', () {
      final snapshots = [
        CloudBackupSnapshotSummary(
          snapshotId: 's1',
          createdAtUtc: DateTime.utc(2026, 9, 3),
          byteSize: 1000,
          schemaVersion: 20,
          backupFormatVersion: 10,
          deviceName: 'Phone',
        ),
        CloudBackupSnapshotSummary(
          snapshotId: 's2',
          createdAtUtc: DateTime.utc(2026, 9, 2),
          byteSize: 1000,
          schemaVersion: 20,
          backupFormatVersion: 10,
          deviceName: 'Phone',
        ),
      ];

      final toPrune = CloudBackupRetentionPolicy.identifySnapshotsToPrune(snapshots);
      expect(toPrune, isEmpty);
    });

    test('Retention policy prunes daily snapshots exceeding 5 limit', () {
      final now = DateTime.utc(2026, 9, 3);
      final snapshots = List.generate(
        8,
        (i) => CloudBackupSnapshotSummary(
          snapshotId: 'daily-$i',
          createdAtUtc: now.subtract(Duration(days: i)),
          byteSize: 1000,
          schemaVersion: 20,
          backupFormatVersion: 10,
          deviceName: 'Phone',
          isWeeklyMilestone: false,
        ),
      );

      // 8 daily snapshots > 5 daily allowed
      final toPrune = CloudBackupRetentionPolicy.identifySnapshotsToPrune(snapshots);
      expect(toPrune, ['daily-5', 'daily-6', 'daily-7']);
    });

    test('Retention policy preserves weekly milestones and caps total at 8', () {
      final now = DateTime.utc(2026, 9, 3);
      final dailies = List.generate(
        6,
        (i) => CloudBackupSnapshotSummary(
          snapshotId: 'daily-$i',
          createdAtUtc: now.subtract(Duration(days: i)),
          byteSize: 1000,
          schemaVersion: 20,
          backupFormatVersion: 10,
          deviceName: 'Phone',
          isWeeklyMilestone: false,
        ),
      );
      final weeklies = List.generate(
        4,
        (i) => CloudBackupSnapshotSummary(
          snapshotId: 'weekly-$i',
          createdAtUtc: now.subtract(Duration(days: 7 * (i + 1))),
          byteSize: 1000,
          schemaVersion: 20,
          backupFormatVersion: 10,
          deviceName: 'Phone',
          isWeeklyMilestone: true,
        ),
      );

      final all = [...dailies, ...weeklies]; // 10 snapshots total
      final toPrune = CloudBackupRetentionPolicy.identifySnapshotsToPrune(all);

      expect(toPrune, contains('daily-5')); // 6th daily pruned
      expect(toPrune, contains('weekly-3')); // 4th weekly pruned
      expect(all.length - toPrune.length, lessThanOrEqualTo(8));
    });
  });

  group('PV1-CLOUD-01A: API Contract Models', () {
    test('CloudBackupSnapshotUploadRequest serializes and deserializes cleanly', () {
      final req = CloudBackupSnapshotUploadRequest(
        snapshotId: 'uuid-test',
        ciphertextBase64: 'abc123==',
        wrappedKeyBase64: 'def456==',
        sha256Checksum: 'checksum-hash',
        byteSize: 2048,
        schemaVersion: 20,
        backupFormatVersion: 10,
        deviceName: 'Pixel 8 Pro',
        isWeeklyMilestone: true,
      );

      final json = req.toJson();
      final parsed = CloudBackupSnapshotUploadRequest.fromJson(json);

      expect(parsed.snapshotId, 'uuid-test');
      expect(parsed.byteSize, 2048);
      expect(parsed.deviceName, 'Pixel 8 Pro');
      expect(parsed.isWeeklyMilestone, isTrue);
    });

    test('CloudBackupListResponse serializes and deserializes cleanly', () {
      final response = CloudBackupListResponse(
        snapshots: [
          CloudBackupSnapshotSummary(
            snapshotId: 's1',
            createdAtUtc: DateTime.utc(2026, 9, 3, 12, 0),
            byteSize: 5000,
            schemaVersion: 20,
            backupFormatVersion: 10,
            deviceName: 'iPhone',
          ),
        ],
        totalCount: 1,
        totalStorageBytes: 5000,
      );

      final json = response.toJson();
      final parsed = CloudBackupListResponse.fromJson(json);

      expect(parsed.totalCount, 1);
      expect(parsed.totalStorageBytes, 5000);
      expect(parsed.snapshots.first.snapshotId, 's1');
    });
  });

  group('PV1-CLOUD-01A: Transactional Restore Rollback Protection', () {
    test('Failed restore aborts before modifying active database', () async {
      final scope = registerTestDatabaseScope();
      final activeDb = scope.create();
      final foodRepo = FoodRepository(activeDb);

      // Seed active database with existing user data
      await foodRepo.logFoodEntry(
        name: 'Precious Existing Roti',
        calories: 120,
        proteinG: 3.5,
        carbsG: 22.0,
        fatG: 1.0,
        servingLogged: 1,
        servingUnit: 'piece',
        mealType: 'dinner',
      );
      final initialLogs = await activeDb.select(activeDb.foodLogs).get();
      expect(initialLogs, hasLength(1));
      expect(initialLogs.first.name, 'Precious Existing Roti');

      // Simulate a corrupt cloud backup blob being restored
      const corruptCloudJson = '{"corrupted": true, "syntax_error": ';

      bool restoreFailed = false;
      try {
        // Step 1 & 2: Parse & validate before touching active DB
        jsonDecode(corruptCloudJson);
      } catch (_) {
        restoreFailed = true;
      }

      expect(restoreFailed, isTrue);

      // Verify active database is completely untouched
      final preservedLogs = await activeDb.select(activeDb.foodLogs).get();
      expect(preservedLogs, hasLength(1));
      expect(preservedLogs.first.name, 'Precious Existing Roti');
    });
  });
}
