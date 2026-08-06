import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fresh schema-v19 exposes the four B05 tables and indexes', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    expect(db.schemaVersion, 19);
    final tableRows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
        )
        .get();
    final names = tableRows.map((row) => row.data['name'] as String).toSet();
    expect(
      names,
      containsAll(const [
        'dashboard_module_preferences',
        'education_content_progress',
        'media_pack_preferences',
        'workout_playlist_preferences',
      ]),
    );
    final indexes = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    final indexNames = indexes.map((row) => row.data['name'] as String).toSet();
    expect(
      indexNames,
      containsAll(const [
        'b05_dashboard_module_preferences_user_ordinal_idx',
        'b05_education_content_progress_user_updated_idx',
        'b05_media_pack_preferences_user_updated_idx',
        'b05_workout_playlist_preferences_user_provider_idx',
      ]),
    );
    expect(await db.select(db.dashboardModulePreferences).get(), isEmpty);
    expect(await db.select(db.educationContentProgress).get(), isEmpty);
    expect(await db.select(db.mediaPackPreferences).get(), isEmpty);
    expect(await db.select(db.workoutPlaylistPreferences).get(), isEmpty);
  });

  test(
    'v18 to v19 migration preserves prior rows and starts B05 empty',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'indifit-b05-v19-',
      );
      final file = File('${directory.path}/v18.db');
      final legacy = AppDatabase.executor(
        NativeDatabase(file),
        schemaVersionOverride: 18,
      );
      await legacy.customSelect('PRAGMA user_version').get();
      await legacy.customStatement('''
      INSERT INTO nutrition_coaching_preferences (id, user_id)
      VALUES ('b05-legacy-preferences', 'b05-user')
    ''');
      await legacy.close();

      final migrated = AppDatabase.executor(NativeDatabase(file));
      try {
        await migrated.customSelect('PRAGMA user_version').get();
        expect(migrated.schemaVersion, 19);
        expect(
          (await migrated.select(migrated.nutritionCoachingPreferences).get())
              .single
              .userId,
          'b05-user',
        );
        expect(
          await migrated.select(migrated.dashboardModulePreferences).get(),
          isEmpty,
        );
        expect(
          await migrated.select(migrated.educationContentProgress).get(),
          isEmpty,
        );
      } finally {
        await migrated.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('v18 to v19 migration boundaries roll back and can retry', () async {
    for (final stage in V19MigrationFailureStage.values) {
      final directory = await Directory.systemTemp.createTemp(
        'indifit-b05-v19-failure-',
      );
      final file = File('${directory.path}/v18.db');
      final legacy = AppDatabase.executor(
        NativeDatabase(file),
        schemaVersionOverride: 18,
      );
      await legacy.customSelect('PRAGMA user_version').get();
      await legacy.close();

      final failing = AppDatabase.executor(
        NativeDatabase(file),
        v19MigrationFailureStageInjector: (actual) async {
          if (actual == stage) throw StateError('injected $stage');
        },
      );
      try {
        await expectLater(
          failing.customSelect('PRAGMA user_version').get(),
          throwsA(isA<StateError>()),
        );
      } finally {
        await failing.close();
      }

      final retry = AppDatabase.executor(NativeDatabase(file));
      try {
        await retry.customSelect('PRAGMA user_version').get();
        expect(await retry.select(retry.mediaPackPreferences).get(), isEmpty);
        expect(retry.schemaVersion, 19);
      } finally {
        await retry.close();
        await directory.delete(recursive: true);
      }
    }
  });

  test('B05 table constraints preserve typed and non-zero semantics', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await db
        .into(db.dashboardModulePreferences)
        .insert(
          DashboardModulePreferencesCompanion.insert(
            id: 'module-1',
            userId: 'user-1',
            moduleId: 'today',
            ordinal: 0,
            isVisible: const Value(false),
            isCollapsed: const Value(false),
          ),
        );
    expect(
      (await db.select(db.dashboardModulePreferences).getSingle()).isVisible,
      isFalse,
    );
    await expectLater(
      db.customStatement('''
        INSERT INTO dashboard_module_preferences
          (id, user_id, module_id, ordinal, is_visible, is_collapsed)
        VALUES ('module-2', 'user-1', 'today', -1, 1, 0)
      '''),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      db.customStatement('''
        INSERT INTO education_content_progress
          (id, user_id, content_id, content_version, state)
        VALUES ('lesson-1', 'user-1', 'rpe', '1', 'unknown')
      '''),
      throwsA(isA<Exception>()),
    );
    await db.customStatement('''
      INSERT INTO education_content_progress
        (id, user_id, content_id, content_version, state)
      VALUES ('lesson-v1', 'user-1', 'rpe', '1', 'completed')
    ''');
    await db.customStatement('''
      INSERT INTO education_content_progress
        (id, user_id, content_id, content_version, state)
      VALUES ('lesson-v2', 'user-1', 'rpe', '2', 'notStarted')
    ''');
    expect(await db.select(db.educationContentProgress).get(), hasLength(2));
    await expectLater(
      db.customStatement('''
        INSERT INTO education_content_progress
          (id, user_id, content_id, content_version, state)
        VALUES ('lesson-v2-duplicate', 'user-1', 'rpe', '2', 'completed')
      '''),
      throwsA(isA<Exception>()),
    );
  });
}
