import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_file_adapter.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/backup/backup_v10.dart';
import 'package:indifit/core/backup/backup_v9.dart';
import 'package:indifit/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Backup v10 round-trips typed B05 preferences and inspection payload',
    () async {
      final source = AppDatabase.memory();
      final target = AppDatabase.memory();
      addTearDown(source.close);
      addTearDown(target.close);

      await _populateB05(source);
      final backup = await BackupV10Data.createFromDatabase(source);
      final firstJson = jsonEncode(backup.toJson());
      expect(firstJson, jsonEncode(backup.toJson()));
      expect(backup.version, 10);
      expect(backup.schemaVersion, 19);
      expect(backup.b05.tables.keys, containsAll(_b05Tables));
      expect(firstJson, isNot(contains('file_path')));
      expect(firstJson, isNot(contains('availability')));
      expect(firstJson, isNot(contains('downloaded_bytes')));

      final decoded = BackupV10Data.fromJson(
        jsonDecode(firstJson) as Map<String, dynamic>,
      );
      await decoded.restoreToDatabase(target);

      expect(
        await target.select(target.dashboardModulePreferences).get(),
        hasLength(1),
      );
      expect(
        await target.select(target.educationContentProgress).get(),
        hasLength(1),
      );
      expect(
        await target.select(target.mediaPackPreferences).get(),
        hasLength(1),
      );
      expect(
        await target.select(target.workoutPlaylistPreferences).get(),
        hasLength(1),
      );
      expect(
        (await target.select(target.mediaPackPreferences).getSingle())
            .lastKnownInstalledVersion,
        '1.0.0',
      );
      expect(
        (await target.select(target.workoutPlaylistPreferences).getSingle())
            .playlistReference,
        'spotify://playlist/abc',
      );
      expect(
        await target.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );

      final envelope = BackupFileAdapter.exportV10ToEnvelopeJson(data: backup);
      final inspection = await BackupFileAdapter.inspectBackupContent(envelope);
      expect(inspection.envelope.version, 10);
      expect(inspection.backupV10Data, isNotNull);
      expect(inspection.payload['version'], 10);
      expect(inspection.tableCounts['media_pack_preferences'], 1);

      final encrypted = BackupFileAdapter.exportV10ToEnvelopeJson(
        data: backup,
        password: 'b05-v10-test-password',
      );
      await expectLater(
        BackupFileAdapter.inspectBackupContent(encrypted),
        throwsA(isA<FormatException>()),
      );
      final decrypted = await BackupFileAdapter.inspectBackupContent(
        encrypted,
        password: 'b05-v10-test-password',
      );
      expect(decrypted.backupV10Data, isNotNull);
    },
  );

  test(
    'v5-v9 imports restore an empty B05 graph without fabrication',
    () async {
      final source = AppDatabase.memory();
      final target = AppDatabase.memory();
      addTearDown(source.close);
      addTearDown(target.close);
      await _populateB05(target);

      final v9 = await BackupV9Data.createFromDatabase(source);
      final imported = BackupV10Data.fromJson(v9.toJson());
      expect(imported.b05.tables.values.every((rows) => rows.isEmpty), isTrue);
      await imported.restoreToDatabase(target);
      expect(
        await target.select(target.dashboardModulePreferences).get(),
        isEmpty,
      );
      expect(
        await target.select(target.educationContentProgress).get(),
        isEmpty,
      );
      expect(await target.select(target.mediaPackPreferences).get(), isEmpty);
      expect(
        await target.select(target.workoutPlaylistPreferences).get(),
        isEmpty,
      );
    },
  );

  test('v10 restore rolls back B05 rows when the transaction fails', () async {
    final source = AppDatabase.memory();
    final target = AppDatabase.memory();
    addTearDown(source.close);
    addTearDown(target.close);
    await _populateB05(source);
    await target
        .into(target.workoutPlaylistPreferences)
        .insert(
          WorkoutPlaylistPreferencesCompanion.insert(
            id: 'existing-playlist',
            userId: 'user-1',
            providerId: 'spotify',
            playlistReference: 'spotify://playlist/existing',
          ),
        );
    final backup = await BackupV10Data.createFromDatabase(source);
    await expectLater(
      backup.restoreToDatabaseWithFailureInjector(
        target,
        failureInjector: (stage) async {
          if (stage == BackupRestoreFailureStage.beforeTransactionCommit) {
            throw StateError('injected restore failure');
          }
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      (await target.select(target.workoutPlaylistPreferences).getSingle())
          .playlistReference,
      'spotify://playlist/existing',
    );
  });

  test(
    'B05 graph rejects physical availability and malformed typed rows',
    () async {
      final source = AppDatabase.memory();
      addTearDown(source.close);
      await _populateB05(source);
      final payload = (await BackupV10Data.createFromDatabase(source)).toJson();
      final graph = payload['b05_graph'] as Map<String, dynamic>;
      final tables = graph['tables'] as Map<String, dynamic>;
      final playlist =
          (tables['workout_playlist_preferences'] as List).single
              as Map<String, dynamic>;
      playlist.remove('playlist_reference');
      playlist['availability'] = 'installed';
      await expectLater(
        () => BackupV10Data.fromJson(payload),
        throwsA(
          isA<BackupV10ValidationException>().having(
            (error) => error.code,
            'code',
            anyOf('unknown_or_missing_column', 'sensitive_payload'),
          ),
        ),
      );

      final invalid = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      final invalidTables =
          (invalid['b05_graph'] as Map<String, dynamic>)['tables']
              as Map<String, dynamic>;
      final education =
          (invalidTables['education_content_progress'] as List).single
              as Map<String, dynamic>;
      education['state'] = 'unknown';
      await expectLater(
        () => BackupV10Data.fromJson(invalid),
        throwsA(isA<BackupV10ValidationException>()),
      );
    },
  );
}

const _b05Tables = {
  'dashboard_module_preferences',
  'education_content_progress',
  'media_pack_preferences',
  'workout_playlist_preferences',
};

Future<void> _populateB05(AppDatabase db) async {
  await db
      .into(db.dashboardModulePreferences)
      .insert(
        DashboardModulePreferencesCompanion.insert(
          id: 'dashboard-1',
          userId: 'user-1',
          moduleId: 'today.next_action',
          ordinal: 2,
          isVisible: const Value(true),
          isCollapsed: const Value(false),
        ),
      );
  await db
      .into(db.educationContentProgress)
      .insert(
        EducationContentProgressCompanion.insert(
          id: 'lesson-1',
          userId: 'user-1',
          contentId: 'rpe',
          contentVersion: '2026.1',
          state: 'completed',
        ),
      );
  await db
      .into(db.mediaPackPreferences)
      .insert(
        MediaPackPreferencesCompanion.insert(
          id: 'media-1',
          userId: 'user-1',
          packId: 'exercise-top-20',
          manifestIdentity: 'sha256:manifest-1',
          lastKnownInstalledVersion: const Value('1.0.0'),
          downloadPreference: const Value('manual'),
          deletionChoice: const Value('keep'),
          contentAcknowledgement: const Value('ack-v1'),
        ),
      );
  await db
      .into(db.workoutPlaylistPreferences)
      .insert(
        WorkoutPlaylistPreferencesCompanion.insert(
          id: 'playlist-1',
          userId: 'user-1',
          providerId: 'spotify',
          playlistReference: 'spotify://playlist/abc',
          displayLabel: const Value('Training mix'),
        ),
      );
}
