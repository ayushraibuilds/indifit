import 'dart:convert';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_file_adapter.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/services/notification_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5: Health Data, Backup Files, & Reminders Unit Tests', () {
    late AppDatabase db;
    late HealthService healthService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (MethodCall methodCall) async {
              return true;
            },
          );
      db = AppDatabase.memory();
      healthService = HealthService();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      '1. HealthService supports granular category states and provenance-based duplicate skipping',
      () async {
        // 1. Verify category states defaults to true
        final categoryStates = await healthService.getAllCategoryStates();
        expect(categoryStates[HealthCategory.steps], isTrue);
        expect(categoryStates[HealthCategory.sleep], isTrue);

        // 2. Toggle sleep category to false
        await healthService.setCategoryState(HealthCategory.sleep, false);
        final updatedStates = await healthService.getAllCategoryStates();
        expect(updatedStates[HealthCategory.sleep], isFalse);
        expect(updatedStates[HealthCategory.steps], isTrue);

        // 3. Insert existing HealthProvenance into DB
        final fingerprint = '2026-07-28T10:00:00.000_running_250_30';
        await db
            .into(db.healthProvenances)
            .insert(
              HealthProvenancesCompanion.insert(
                provider: 'apple_health',
                sourceName: 'Apple Watch',
                importedAt: Value(DateTime.now()),
                fingerprint: fingerprint,
              ),
            );

        final provs = await db.select(db.healthProvenances).get();
        expect(provs.length, equals(1));
        expect(provs.first.fingerprint, equals(fingerprint));
      },
    );

    test(
      '1b. Persisting the same external activity twice creates one local session',
      () async {
        final firstSessionId = await healthService.persistOutdoorActivity(
          db: db,
          provider: 'googleHealthConnect',
          externalId: 'googleHealthConnect:external-run-42',
          sourceName: 'Pixel Watch',
          fingerprint: 'googleHealthConnect:run-42',
          title: 'Outdoor Run (Health)',
          durationMinutes: 30,
          calories: 250,
          completedAt: DateTime(2026, 7, 28, 7),
        );
        final duplicateSessionId = await healthService.persistOutdoorActivity(
          db: db,
          provider: 'googleHealthConnect',
          externalId: 'googleHealthConnect:external-run-42',
          sourceName: 'Pixel Watch',
          fingerprint: 'googleHealthConnect:run-42',
          title: 'Outdoor Run (Health)',
          durationMinutes: 30,
          calories: 250,
          completedAt: DateTime(2026, 7, 28, 7),
        );

        expect(firstSessionId, isNotNull);
        expect(duplicateSessionId, isNull);
        expect(await db.select(db.workoutSessions).get(), hasLength(1));
        expect(await db.select(db.healthProvenances).get(), hasLength(1));
      },
    );

    test(
      '2. BackupEnvelope creates valid checksum and detects corrupt or tampered payloads',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final backupData = await BackupData.createFromDatabase(db, prefs);

        final envelopeJson = BackupFileAdapter.exportToEnvelopeJson(
          data: backupData,
          password: null,
        );

        expect(envelopeJson, contains('INDIFIT_BACKUP_ENVELOPE'));

        final inspection = await BackupFileAdapter.inspectBackupContent(
          envelopeJson,
        );
        expect(inspection.isEncrypted, isFalse);
        // BackupData is the legacy v7 payload.  B05's portable B05 graph is
        // carried by BackupV10Data; the legacy schema marker remains capped at
        // v18 for compatibility with the pre-B05 format.
        expect(inspection.schemaVersion, equals(18));

        // Test checksum tampering detection
        final envMap = jsonDecode(envelopeJson) as Map<String, dynamic>;
        envMap['payload'] = jsonEncode({'tampered': 'data'});

        expect(
          () => BackupEnvelope.fromJson(envMap),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      '3. BackupEnvelope encrypted payload requires password and decrypts cleanly',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final backupData = await BackupData.createFromDatabase(db, prefs);

        const password = 'SecretPassword123!';
        final encryptedEnvelopeJson = BackupFileAdapter.exportToEnvelopeJson(
          data: backupData,
          password: password,
        );

        // Attempting inspection without password should throw FormatException
        expect(
          () => BackupFileAdapter.inspectBackupContent(encryptedEnvelopeJson),
          throwsA(isA<FormatException>()),
        );

        // Attempting inspection with wrong password should throw FormatException
        expect(
          () => BackupFileAdapter.inspectBackupContent(
            encryptedEnvelopeJson,
            password: 'WrongPassword',
          ),
          throwsA(isA<FormatException>()),
        );

        // Valid password inspects cleanly
        final result = await BackupFileAdapter.inspectBackupContent(
          encryptedEnvelopeJson,
          password: password,
        );
        expect(result.isEncrypted, isTrue);
        expect(result.backupData.version, equals(BackupData.currentVersion));
      },
    );

    test(
      '4. NotificationService detects timezone/offset change and triggers reschedule',
      () async {
        await NotificationService.initialize();

        final prefs = await SharedPreferences.getInstance();
        // Set previous timezone ID to a different string
        await prefs.setString(
          NotificationService.prefLastScheduledTimezoneId,
          'America/Los_Angeles',
        );

        final rescheduled =
            await NotificationService.checkAndUpdateTimezoneAndReschedule(db);
        expect(rescheduled, isTrue);

        final updatedTzId = prefs.getString(
          NotificationService.prefLastScheduledTimezoneId,
        );
        expect(updatedTzId, isNotNull);
        expect(updatedTzId, isNot(equals('America/Los_Angeles')));

        // Subsequent call without timezone change should return false
        final rescheduledAgain =
            await NotificationService.checkAndUpdateTimezoneAndReschedule(db);
        expect(rescheduledAgain, isFalse);
      },
    );
  });
}
