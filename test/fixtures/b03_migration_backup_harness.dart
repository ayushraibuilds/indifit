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

class B03LogicalSnapshot {
  final Map<String, List<Map<String, dynamic>>> tables;

  const B03LogicalSnapshot(this.tables);

  String get canonicalJson => jsonEncode(<String, dynamic>{
    for (final table in tables.keys.toList()..sort())
      table: tables[table]!
          .map(
            (row) => <String, dynamic>{
              for (final key in row.keys.toList()..sort()) key: row[key],
            },
          )
          .toList(),
  });

  String get checksum => sha256.convert(utf8.encode(canonicalJson)).toString();

  static Future<B03LogicalSnapshot> capture(AppDatabase db) async {
    const tableNames = [
      'food_items',
      'food_logs',
      'meal_templates',
      'meal_template_items',
      'user_profiles',
      'user_settings',
      'exercises',
      'workout_sessions',
      'workout_sets',
      'cardio_session_details',
      'health_provenances',
      'workout_routines',
      'routine_days',
      'routine_exercises',
      'workout_drafts',
    ];
    final tables = <String, List<Map<String, dynamic>>>{};
    for (final table in tableNames) {
      final rows = await db
          .customSelect('SELECT * FROM $table ORDER BY rowid')
          .get();
      tables[table] = rows
          .map((row) => Map<String, dynamic>.from(row.data))
          .toList();
    }
    return B03LogicalSnapshot(tables);
  }
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
