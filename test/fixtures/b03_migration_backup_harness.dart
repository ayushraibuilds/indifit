import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// The checked-in database fixture is generated once by [createGoldenFile].
/// Tests copy it to a temporary path and never rebuild it from production seed
/// logic. This keeps the v16 starting point immutable for future migrations.
class B03V16Fixture {
  static const int schemaVersion = 16;
  static const String fixtureId = 'b03-v16-legacy-baseline-01';
  static const String fixturePath =
      'test/fixtures/data/b03_v16_legacy_baseline.db';
  static const String checksum =
      '27516799c7cfa9dba53a408c13a638fdb2be8bae32ee887fee2bf9f7ce147eb5';

  static final DateTime timestamp = DateTime.utc(2026, 1, 15, 8, 30);

  static Future<File> copyTo(Directory directory, {String? filename}) async {
    final source = File(fixturePath);
    if (!source.existsSync()) {
      throw StateError('Missing checked-in B03 v16 fixture: $fixturePath');
    }
    return source.copy('${directory.path}/${filename ?? 'b03-v16-fixture.db'}');
  }

  static AppDatabase open(File file) =>
      AppDatabase.executor(NativeDatabase(file));

  static int readUserVersion(File file) {
    final db = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    try {
      return db.select('PRAGMA user_version;').single['user_version'] as int;
    } finally {
      db.dispose();
    }
  }

  /// One-time maintenance operation used to create the checked-in fixture.
  /// It is deliberately not called by any test.
  static Future<void> createGoldenFile(File file) async {
    final db = AppDatabase.executor(NativeDatabase(file));
    try {
      await _seedRepresentativeData(db);
    } finally {
      await db.close();
    }
  }

  static Future<void> _seedRepresentativeData(AppDatabase db) async {
    final seededFood = (await db.select(db.foodItems).get()).first;
    final seededExercise = (await db.select(db.exercises).get()).firstWhere(
      (row) => row.stableId != null,
    );

    await db
        .into(db.foodItems)
        .insert(
          FoodItemsCompanion.insert(
            id: const Value(574),
            name: 'Fixture Custom Lentil Bowl',
            nameHindi: const Value('Fixture Dal Bowl'),
            calories: 412,
            proteinG: 21.5,
            carbsG: 54.0,
            fatG: 11.0,
            fiberG: const Value(null),
            servingSize: 1,
            servingUnit: 'bowl',
            category: 'custom',
            isCustom: const Value(true),
            brand: const Value('Fixture Kitchen'),
          ),
        );

    await db
        .into(db.foodLogs)
        .insert(
          FoodLogsCompanion.insert(
            id: const Value(7001),
            foodItemId: const Value(574),
            name: 'Fixture Custom Lentil Bowl',
            calories: 412,
            proteinG: 21.5,
            carbsG: 54.0,
            fatG: 11.0,
            servingLogged: 1,
            servingUnit: 'bowl',
            mealType: 'lunch',
            loggedAt: Value(timestamp),
            isSynced: const Value(false),
            mealGroupId: const Value('fixture-meal-group-lunch'),
            uuid: const Value('fixture-food-log-custom-7001'),
          ),
        );
    await db
        .into(db.foodLogs)
        .insert(
          FoodLogsCompanion.insert(
            id: const Value(7002),
            foodItemId: Value(seededFood.id),
            name: 'Fixture Seeded Breakfast Food',
            calories: 118,
            proteinG: 4.2,
            carbsG: 20.0,
            fatG: 2.1,
            servingLogged: 0.5,
            servingUnit: 'serving',
            mealType: 'breakfast',
            loggedAt: Value(timestamp.add(const Duration(days: 1))),
            isSynced: const Value(true),
            uuid: const Value('fixture-food-log-seeded-7002'),
          ),
        );
    await db
        .into(db.foodLogs)
        .insert(
          FoodLogsCompanion.insert(
            id: const Value(7003),
            foodItemId: const Value(null),
            name: 'Fixture Imported Estimate Without Identity',
            calories: 275,
            proteinG: 12.0,
            carbsG: 31.0,
            fatG: 9.0,
            servingLogged: 1,
            servingUnit: 'unknown portion',
            mealType: 'dinner',
            loggedAt: Value(timestamp.add(const Duration(days: 2))),
            isSynced: const Value(false),
            uuid: const Value('fixture-food-log-imported-7003'),
          ),
        );

    await db
        .into(db.userProfiles)
        .insert(
          UserProfilesCompanion.insert(
            id: const Value(9001),
            age: const Value(31),
            height: const Value(178),
            weight: const Value(76.5),
            sex: const Value('unspecified'),
            activityLevel: const Value('moderate'),
            goal: const Value('maintain'),
            dietPreference: const Value('balanced'),
            calorieGoal: const Value(2350),
            proteinGoal: const Value(150),
            carbsGoal: const Value(260),
            fatGoal: const Value(70),
            name: const Value('Fixture User'),
            updatedAt: Value(timestamp),
          ),
        );
    await db
        .into(db.userSettings)
        .insert(
          UserSettingsCompanion.insert(
            key: 'fixture_nutrition_mode',
            value: 'legacy-compatible',
            updatedAt: Value(timestamp),
          ),
        );

    await db
        .into(db.mealTemplates)
        .insert(
          MealTemplatesCompanion.insert(
            id: const Value(3001),
            name: 'Fixture Two-Day Meal Template',
            defaultMealType: const Value('breakfast'),
            createdAt: Value(timestamp),
          ),
        );
    await db
        .into(db.mealTemplateItems)
        .insert(
          MealTemplateItemsCompanion.insert(
            id: const Value(3002),
            templateId: 3001,
            name: 'Fixture Template Item',
            calories: 300,
            proteinG: 18,
            carbsG: 35,
            fatG: 8,
            servingLogged: 1,
            servingUnit: 'serving',
          ),
        );

    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: const Value(9002),
            stableId: const Value('fixture-custom-exercise-v16'),
            name: 'Fixture Custom Movement',
            muscleGroups: 'Unknown',
            equipment: 'Fixture',
            difficulty: 'Beginner',
            formCues: '',
            commonMistakes: '',
            isCustom: const Value(true),
          ),
        );
    final sessionId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            id: const Value(4101),
            name: 'Fixture Strength Session',
            totalVolume: 1200,
            durationSeconds: 1800,
            estimatedCalories: 180,
            completedAt: Value(timestamp.add(const Duration(hours: 1))),
            uuid: const Value('fixture-workout-session-4101'),
            activityType: const Value('strength'),
          ),
        );
    await db
        .into(db.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            id: const Value(4201),
            sessionId: sessionId,
            exerciseName: seededExercise.name,
            weight: 60,
            reps: 8,
            setNumber: 1,
            isPr: const Value(false),
            rpe: const Value(8),
            uuid: const Value('fixture-workout-set-4201'),
            exerciseId: Value(seededExercise.stableId),
          ),
        );
    final cardioSessionId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            id: const Value(4102),
            name: 'Fixture Imported Run',
            totalVolume: 0,
            durationSeconds: 1500,
            estimatedCalories: 210,
            completedAt: Value(timestamp.add(const Duration(days: 3))),
            isSynced: const Value(true),
            uuid: const Value('fixture-workout-session-4102'),
            activityType: const Value('running'),
          ),
        );
    await db
        .into(db.cardioSessionDetails)
        .insert(
          CardioSessionDetailsCompanion.insert(
            sessionId: Value(cardioSessionId),
            distanceMetres: const Value(5000),
            observedPaceSecondsPerKm: const Value(300),
            averageHeartRate: const Value(148),
            perceivedExertion: const Value(7),
          ),
        );
    await db
        .into(db.healthProvenances)
        .insert(
          HealthProvenancesCompanion.insert(
            id: const Value(4301),
            provider: 'health_connect',
            externalId: const Value('fixture-health-external-4301'),
            sourceName: 'Fixture Health Provider',
            importedAt: Value(timestamp.add(const Duration(days: 3, hours: 1))),
            localSessionId: Value(cardioSessionId),
            fingerprint: 'fixture-health-fingerprint-4301',
          ),
        );
    await db
        .into(db.workoutDrafts)
        .insert(
          WorkoutDraftsCompanion.insert(
            id: const Value(4501),
            routineName: 'Fixture Legacy Routine',
            currentExerciseIndex: 0,
            currentSetIndex: 1,
            elapsedSeconds: 600,
            loggedSetsJson: '[{"exercise":"Fixture Custom Movement","reps":6}]',
            updatedAt: Value(timestamp.add(const Duration(hours: 2))),
            activityType: const Value('legacy'),
          ),
        );
  }
}

class B03BackupV7Fixture {
  static const int version = 7;
  static const int schemaVersion = 16;
  static const String fixtureId = 'b03-backup-v7-legacy-baseline-01';
  static const String fixturePath =
      'test/fixtures/data/b03_backup_v7_legacy_baseline.json';
  static const String checksum =
      '16e486faf0abba0f4b075a928eab25f3fe9e651e68687a6f66da14b944daa3ae';
  static const String timestamp = '2026-01-15T08:30:00.000Z';

  static BackupData load() {
    final file = File(fixturePath);
    if (!file.existsSync()) {
      throw StateError(
        'Missing checked-in B03 Backup-v7 fixture: $fixturePath',
      );
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      throw const FormatException('B03 Backup-v7 fixture must be an object.');
    }
    final backup = BackupData.fromJson(Map<String, dynamic>.from(decoded));
    if (backup.version != version || backup.schemaVersion != schemaVersion) {
      throw StateError('B03 Backup-v7 fixture version drifted.');
    }
    return backup;
  }

  /// One-time maintenance operation used to create the checked-in fixture.
  /// It is deliberately not called by any test.
  static Future<void> createGoldenFile(File file, File databaseFile) async {
    final db = B03V16Fixture.open(databaseFile);
    try {
      SharedPreferences.setMockInitialValues({
        'water_logged': 4,
        'user_streak_count': 12,
        'pref_remind_workout': true,
        'prefQuietHoursEnabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final backup = await BackupData.createFromDatabase(db, prefs);
      final json = backup.toJson()..['timestamp'] = timestamp;
      file
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    } finally {
      await db.close();
    }
  }
}

enum B03FailureStage {
  migrationValidation,
  migrationDdlAndDataMutation,
  migrationFinalTransaction,
  backupRelationshipPrevalidation,
  backupDatabaseMutation,
  preferenceWrite,
  preferenceRestore,
  restoreFinalTransaction,
}

class B03InjectedFailure implements Exception {
  final B03FailureStage stage;

  const B03InjectedFailure(this.stage);

  @override
  String toString() => 'B03 injected failure at ${stage.name}';
}

/// A stage-aware adapter for the production test seams. It records every
/// boundary reached, injects at exactly one selected boundary, and can then be
/// disabled for a retry without rebuilding the fixture.
class B03StageAwareFailureHarness {
  final B03FailureStage selectedStage;
  final List<B03FailureStage> reachedStages = [];
  bool enabled = true;
  bool injected = false;

  B03StageAwareFailureHarness(this.selectedStage);

  void disable() => enabled = false;

  Future<void> onMigrationStage(V16MigrationFailureStage stage) async {
    final mapped = switch (stage) {
      V16MigrationFailureStage.validation =>
        B03FailureStage.migrationValidation,
      V16MigrationFailureStage.ddlAndDataMutation =>
        B03FailureStage.migrationDdlAndDataMutation,
      V16MigrationFailureStage.beforeTransactionCommit =>
        B03FailureStage.migrationFinalTransaction,
    };
    reachedStages.add(mapped);
    if (enabled && mapped == selectedStage) {
      injected = true;
      throw B03InjectedFailure(mapped);
    }
  }

  Future<void> onBackupStage(BackupRestoreFailureStage stage) async {
    final mapped = switch (stage) {
      BackupRestoreFailureStage.relationshipPrevalidation =>
        B03FailureStage.backupRelationshipPrevalidation,
      BackupRestoreFailureStage.preferenceWrite =>
        B03FailureStage.preferenceWrite,
      BackupRestoreFailureStage.databaseMutation =>
        B03FailureStage.backupDatabaseMutation,
      BackupRestoreFailureStage.beforeTransactionCommit =>
        B03FailureStage.restoreFinalTransaction,
      BackupRestoreFailureStage.preferenceRestore =>
        B03FailureStage.preferenceRestore,
    };
    reachedStages.add(mapped);
    if (enabled && mapped == selectedStage) {
      injected = true;
      throw B03InjectedFailure(mapped);
    }
  }

  AppDatabase openMigrating(File source) {
    return AppDatabase.executor(
      NativeDatabase(source),
      v16MigrationFailureStageInjector: onMigrationStage,
    );
  }

  Future<void> restore(
    BackupData backup,
    AppDatabase db, [
    SharedPreferences? prefs,
  ]) async {
    // Preference restoration is only reachable while compensating for a
    // database failure. The trigger is a deterministic setup fault; the
    // selected typed failure is still the preference-restore boundary and is
    // injected after one compensation write, leaving a documented partial
    // compensation state that a retry can safely complete.
    final needsCompensationFailure =
        enabled && selectedStage == B03FailureStage.preferenceRestore;
    if (needsCompensationFailure) {
      await B03RestoreFailureHarness.installDatabaseFailure(db);
    }
    try {
      await backup.restoreToDatabaseWithFailureInjector(
        db,
        prefs: prefs,
        failureInjector: onBackupStage,
      );
    } finally {
      if (needsCompensationFailure) {
        await B03RestoreFailureHarness.removeDatabaseFailure(db);
      }
    }
  }
}

class B03LogicalSnapshot {
  final Map<String, List<Map<String, dynamic>>> tables;

  const B03LogicalSnapshot(this.tables);

  /// Every physical durable table in the accepted schema-v16 graph. The list
  /// is checked against sqlite_master so a missing table cannot silently make
  /// a golden snapshot incomplete.
  static const List<String> v16TableNames = [
    'achievement_unlocks',
    'body_measurements',
    'cardio_intervals',
    'cardio_session_details',
    'daily_hydrations',
    'equipment_profile_items',
    'equipment_profiles',
    'exercise_group_members',
    'exercise_groups',
    'exercise_muscle_mappings',
    'exercise_personal_cues',
    'exercise_prescriptions',
    'exercise_setup_values',
    'exercise_target_recommendations',
    'exercise_user_preferences',
    'exercises',
    'food_items',
    'food_logs',
    'health_provenances',
    'legacy_routine_program_mappings',
    'meal_template_items',
    'meal_templates',
    'mobility_session_details',
    'muscles',
    'occurrence_events',
    'performed_exercise_groups',
    'performed_exercises',
    'performed_rest_periods',
    'performed_set_segments',
    'performed_sets',
    'program_blocks',
    'program_versions',
    'program_weeks',
    'programs',
    'routine_days',
    'routine_exercises',
    'scheduled_session_occurrences',
    'session_templates',
    'strength_set_prescriptions',
    'training_plan_settings',
    'travel_context_occurrences',
    'travel_contexts',
    'user_profiles',
    'user_settings',
    'workout_drafts',
    'workout_routines',
    'workout_sessions',
    'workout_sets',
  ];

  static const Set<String> _localIntegerIdTables = {
    'food_items',
    'food_logs',
    'exercises',
    'workout_sessions',
    'workout_sets',
    'body_measurements',
    'workout_routines',
    'routine_days',
    'routine_exercises',
    'workout_drafts',
    'user_profiles',
    'meal_templates',
    'meal_template_items',
    'health_provenances',
    'cardio_session_details',
    'mobility_session_details',
  };

  static const Map<String, List<String>> _preferredOrder = {
    'food_items': ['stable_id', 'name', 'brand', 'id'],
    'food_logs': ['uuid', 'logged_at', 'meal_type', 'id'],
    'exercises': ['stable_id', 'name', 'id'],
    'workout_sessions': ['uuid', 'completed_at', 'id'],
    'workout_sets': ['uuid', 'session_id', 'set_number', 'id'],
    'health_provenances': ['provider', 'external_id', 'fingerprint', 'id'],
    'muscles': ['id', 'catalog_version', 'display_name'],
    'exercise_muscle_mappings': ['exercise_id', 'muscle_id', 'role', 'id'],
  };

  static const Map<String, String> _foreignKeyTargets = {
    'food_item_id': 'food_items',
    'session_id': 'workout_sessions',
    'local_session_id': 'workout_sessions',
    'routine_id': 'workout_routines',
    'day_id': 'routine_days',
    'template_id': 'meal_templates',
    'program_id': 'programs',
    'program_version_id': 'program_versions',
    'program_block_id': 'program_blocks',
    'program_week_id': 'program_weeks',
    'session_template_id': 'session_templates',
    'exercise_prescription_id': 'exercise_prescriptions',
    'occurrence_id': 'scheduled_session_occurrences',
    'scheduled_occurrence_id': 'scheduled_session_occurrences',
    'repeated_from_occurrence_id': 'scheduled_session_occurrences',
    'equipment_profile_id': 'equipment_profiles',
    'default_equipment_profile_id': 'equipment_profiles',
    'travel_context_id': 'travel_contexts',
    'travel_context_occurrence_id': 'travel_context_occurrences',
    'exercise_group_id': 'exercise_groups',
    'exercise_id': 'exercises',
    'muscle_id': 'muscles',
    'cardio_session_id': 'cardio_session_details',
    'performed_exercise_group_id': 'performed_exercise_groups',
    'performed_exercise_id': 'performed_exercises',
    'performed_set_id': 'performed_sets',
    'active_program_version_id': 'program_versions',
  };

  String get canonicalJson => _encodeTables(tables);

  /// A relationship-aware representation that omits only local integer IDs
  /// and replaces their foreign keys with semantic parent tokens. Portable
  /// UUIDs, stable IDs, source keys, values, timestamps, and unknown fields
  /// remain part of the comparison.
  String get logicalCanonicalJson => _encodeTables(_logicalTables());

  String get checksum => sha256.convert(utf8.encode(canonicalJson)).toString();

  String get logicalChecksum =>
      sha256.convert(utf8.encode(logicalCanonicalJson)).toString();

  bool logicallyEquals(B03LogicalSnapshot other) =>
      logicalCanonicalJson == other.logicalCanonicalJson;

  void assertLogicallyEquals(B03LogicalSnapshot other) {
    if (!logicallyEquals(other)) {
      throw StateError(
        'B03 durable logical snapshots differ: $logicalChecksum != '
        '${other.logicalChecksum}',
      );
    }
  }

  static Future<B03LogicalSnapshot> capture(AppDatabase db) async {
    final physicalRows = await db.customSelect('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
      ORDER BY name
    ''').get();
    final physicalNames = physicalRows
        .map((row) => row.data['name'] as String)
        .toSet();
    final missing = v16TableNames
        .where((table) => !physicalNames.contains(table))
        .toList();
    if (missing.isNotEmpty) {
      throw StateError('Incomplete schema-v16 snapshot; missing $missing.');
    }

    final tables = <String, List<Map<String, dynamic>>>{};
    for (final table in v16TableNames) {
      final quotedTable = _quoteIdentifier(table);
      final columns = await db
          .customSelect('PRAGMA table_info($quotedTable)')
          .get();
      final columnNames = columns
          .map((row) => row.data['name'] as String)
          .toList();
      final orderColumns = _orderColumns(table, columnNames);
      final orderBy = orderColumns
          .map((column) {
            final quoted = _quoteIdentifier(column);
            return '$quoted IS NULL, $quoted';
          })
          .join(', ');
      final rows = await db
          .customSelect('SELECT * FROM $quotedTable ORDER BY $orderBy')
          .get();
      tables[table] = rows
          .map((row) => Map<String, dynamic>.from(row.data))
          .toList();
    }
    return B03LogicalSnapshot(tables);
  }

  static String _encodeTables(Map<String, List<Map<String, dynamic>>> source) {
    return jsonEncode(<String, dynamic>{
      for (final table in source.keys.toList()..sort())
        table:
            (List<Map<String, dynamic>>.from(
                source[table]!,
              )).map(_sortedRow).toList()
              ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b))),
    });
  }

  static Map<String, dynamic> _sortedRow(Map<String, dynamic> row) => {
    for (final key in row.keys.toList()..sort()) key: row[key],
  };

  Map<String, List<Map<String, dynamic>>> _logicalTables() {
    final tokens = <String, Map<Object, String>>{};
    for (final entry in tables.entries) {
      tokens[entry.key] = {
        for (final row in entry.value)
          if (row.containsKey('id') && row['id'] != null)
            row['id']!: _identityToken(entry.key, row),
        for (final row in entry.value)
          if (row['stable_id'] != null)
            row['stable_id']!: _identityToken(entry.key, row),
        for (final row in entry.value)
          if (row['uuid'] != null) row['uuid']!: _identityToken(entry.key, row),
      };
    }

    return {
      for (final entry in tables.entries)
        entry.key: [
          for (final row in entry.value) _logicalRow(entry.key, row, tokens),
        ],
    };
  }

  Map<String, dynamic> _logicalRow(
    String table,
    Map<String, dynamic> row,
    Map<String, Map<Object, String>> tokens,
  ) {
    final normalized = <String, dynamic>{};
    for (final entry in row.entries) {
      if (entry.key == 'id' && _localIntegerIdTables.contains(table)) {
        continue;
      }
      final target = _foreignKeyTargets[entry.key];
      if (target != null && entry.value != null) {
        normalized[entry.key] =
            '@$target:${_referenceToken(target, entry.value, tokens)}';
      } else {
        normalized[entry.key] = entry.value;
      }
    }
    return normalized;
  }

  String _referenceToken(
    String table,
    Object value,
    Map<String, Map<Object, String>> tokens,
  ) {
    if (table == 'cardio_session_details' ||
        table == 'mobility_session_details') {
      final detailExists = tables[table]?.any(
        (row) => row['session_id'] == value,
      );
      if (detailExists == true) {
        return _referenceToken('workout_sessions', value, tokens);
      }
    }
    final token = tokens[table]?[value];
    if (token != null) return token;
    return 'unresolved:$value';
  }

  static String _identityToken(String table, Map<String, dynamic> row) {
    for (final key in const [
      'stable_id',
      'uuid',
      'external_id',
      'fingerprint',
    ]) {
      final value = row[key];
      if (value != null && value.toString().isNotEmpty) {
        return '$table:$key:$value';
      }
    }
    final identity = {
      for (final entry in row.entries)
        if (entry.key != 'id' && !entry.key.endsWith('_id'))
          entry.key: entry.value,
    };
    return '$table:${jsonEncode(_sortedRow(identity))}';
  }

  static List<String> _orderColumns(String table, List<String> columns) {
    final preferred = _preferredOrder[table] ?? const <String>[];
    final selected = <String>[
      for (final column in preferred)
        if (columns.contains(column)) column,
      for (final column in columns)
        if (!preferred.contains(column) && column != 'id') column,
      if (columns.contains('id')) 'id',
    ];
    return selected.toSet().toList();
  }

  static String _quoteIdentifier(String value) =>
      '"${value.replaceAll('"', '""')}"';
}

class B03RestoreFailureHarness {
  static Future<void> installDatabaseFailure(
    AppDatabase db, {
    String table = 'food_items',
    String triggerName = 'b03_fail_restore',
  }) async {
    await db.customStatement('''
      CREATE TRIGGER $triggerName
      BEFORE INSERT ON $table
      BEGIN
        SELECT RAISE(ABORT, 'B03 injected restore failure');
      END;
    ''');
  }

  static Future<void> removeDatabaseFailure(
    AppDatabase db, {
    String triggerName = 'b03_fail_restore',
  }) async {
    await db.customStatement('DROP TRIGGER IF EXISTS $triggerName');
  }

  static Future<Map<String, Object?>> preferenceSnapshot(
    SharedPreferences prefs,
    Iterable<String> keys,
  ) async {
    return {
      for (final key in keys)
        key: prefs.getKeys().contains(key) ? prefs.get(key) : null,
    };
  }
}
