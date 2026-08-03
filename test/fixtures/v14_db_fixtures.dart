import 'dart:io';

import 'package:drift/native.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Source-data scenarios represented by the immutable schema-v14 fixture.
enum V14FixtureScenario {
  empty,
  singleRoutine,
  richHistory,
  canonicalIdentity,
  duplicateCanonicalIdentity,
  customAndUnresolved,
  knownEquipment,
  unknownEquipment,
  malformedRelationship,
}

/// Creates deterministic on-disk SQLite sources that are independent from the
/// current Drift schema. These files remain genuine v14 sources after the app
/// moves to v15, so B01-03 can open them through [AppDatabase] to exercise the
/// real upgrade path.
class V14DbFixtures {
  static const int schemaVersion = 14;
  static const int _createdAtMillis = 1704067200000; // 2024-01-01T00:00:00Z
  static const int _sessionOneMillis = 1703894400000;
  static const int _sessionTwoMillis = 1703980800000;

  static File createSourceDatabase(
    Directory directory,
    String filename, {
    required V14FixtureScenario scenario,
  }) {
    final file = File('${directory.path}/$filename');
    final database = sqlite.sqlite3.open(file.path);
    try {
      database.execute('BEGIN;');
      _createV14Schema(database);
      _seedScenario(database, scenario);
      database.execute('PRAGMA user_version = $schemaVersion;');
      database.execute('COMMIT;');
    } catch (_) {
      database.execute('ROLLBACK;');
      rethrow;
    } finally {
      database.dispose();
    }
    return file;
  }

  /// Opens a v14 source using the application's current database class.
  /// Once schema v15 exists, this call executes the production upgrade path.
  static AppDatabase openCurrentDatabase(
    File file, {
    Future<void> Function()? v15MigrationFailureInjector,
  }) {
    return AppDatabase.executor(
      NativeDatabase(file),
      v15MigrationFailureInjector: v15MigrationFailureInjector,
      schemaVersionOverride: 15,
    );
  }

  static int readUserVersion(File file) {
    final database = sqlite.sqlite3.open(
      file.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      return database.select('PRAGMA user_version;').single['user_version']
          as int;
    } finally {
      database.dispose();
    }
  }

  static void _createV14Schema(sqlite.Database database) {
    for (final statement in _v14SchemaStatements) {
      database.execute(statement);
    }
  }

  static void _seedScenario(
    sqlite.Database database,
    V14FixtureScenario scenario,
  ) {
    switch (scenario) {
      case V14FixtureScenario.empty:
        return;
      case V14FixtureScenario.singleRoutine:
        _insertSingleRoutine(database);
      case V14FixtureScenario.richHistory:
        _insertSingleRoutine(database);
        _insertRichHistory(database);
      case V14FixtureScenario.canonicalIdentity:
        _insertCanonicalIdentity(database);
      case V14FixtureScenario.duplicateCanonicalIdentity:
        _insertDuplicateCanonicalIdentity(database);
      case V14FixtureScenario.customAndUnresolved:
        _insertCustomAndUnresolved(database);
      case V14FixtureScenario.knownEquipment:
        _insertEquipmentProfile(database, 'full_gym');
      case V14FixtureScenario.unknownEquipment:
        _insertEquipmentProfile(database, 'mystery_space_station_gym');
      case V14FixtureScenario.malformedRelationship:
        _insertMalformedRelationship(database);
    }
  }

  static void _insertSingleRoutine(sqlite.Database database) {
    database.execute('''
      INSERT INTO workout_routines (id, name, goal, notes, created_at)
      VALUES (1, 'Push Day', 'Hypertrophy', NULL, $_createdAtMillis);
    ''');
    database.execute('''
      INSERT INTO routine_days (id, routine_id, day_of_week, name, is_rest_day)
      VALUES (1, 1, 1, 'Push Primary', 0);
    ''');
    database.execute('''
      INSERT INTO routine_exercises (id, day_id, exercise_name, sets, reps_range, order_index)
      VALUES
        (1, 1, 'Flat Barbell Bench Press', 4, '8', 0),
        (2, 1, 'Seated Dumbbell Shoulder Press', 3, '10', 1);
    ''');
  }

  static void _insertRichHistory(sqlite.Database database) {
    database.execute('''
      INSERT INTO workout_routines (id, name, goal, notes, created_at)
      VALUES (2, 'Pull Day', 'Strength', NULL, $_createdAtMillis);
    ''');
    database.execute('''
      INSERT INTO routine_days (id, routine_id, day_of_week, name, is_rest_day)
      VALUES (2, 2, 3, 'Pull Primary', 0);
    ''');
    database.execute('''
      INSERT INTO routine_exercises (id, day_id, exercise_name, sets, reps_range, order_index)
      VALUES
        (3, 2, 'Barbell Deadlift', 3, '5', 0),
        (4, 2, 'Lat Pulldown', 4, '10', 1);
    ''');
    database.execute('''
      INSERT INTO workout_sessions
        (id, name, total_volume, duration_seconds, estimated_calories, completed_at, is_synced, uuid)
      VALUES
        (1, 'Push Day', 3200.0, 2700, 320, $_sessionOneMillis, 0, NULL),
        (2, 'Cardio & Abs', 0.0, 1800, 200, $_sessionTwoMillis, 0, NULL);
    ''');
    database.execute('''
      INSERT INTO workout_sets
        (id, session_id, exercise_name, weight, reps, set_number, is_pr, rpe, is_warm_up, set_notes, uuid, set_type, duration_seconds, distance_km, incline_percentage)
      VALUES
        (1, 1, 'Flat Barbell Bench Press', 80.0, 8, 1, 1, 8, 0, 'Felt strong, clean form 💪', NULL, 'working', NULL, NULL, NULL),
        (2, 1, 'Seated Dumbbell Shoulder Press', 24.0, 10, 1, 0, 7, 0, NULL, NULL, 'working', NULL, NULL, NULL),
        (3, 2, 'Treadmill Run', 0.0, 0, 1, 0, NULL, 0, NULL, NULL, 'working', 1200, 3.2, 2.0);
    ''');
    database.execute('''
      INSERT INTO workout_drafts
        (id, routine_name, current_exercise_index, current_set_index, elapsed_seconds, logged_sets_json, updated_at)
      VALUES
        (1, 'Push Day', 1, 0, 900,
         '[{"sessionId":0,"exerciseName":"Flat Barbell Bench Press","weight":82.5,"reps":8,"setNumber":1,"isPr":false,"rpe":8,"isWarmUp":false,"setType":"working","setNotes":"Draft note"}]',
         $_sessionTwoMillis);
    ''');
  }

  static void _insertCustomAndUnresolved(sqlite.Database database) {
    database.execute('''
      INSERT INTO exercises
        (id, name, muscle_groups, equipment, difficulty, form_cues, common_mistakes, youtube_id, is_custom)
      VALUES
        (1, 'Pike Push-ups', 'Shoulders, Triceps', 'Bodyweight', 'Intermediate', 'Keep hips high', 'Flaring elbows', NULL, 1),
        (2, 'Superman Lat Pulls', 'Back', 'Bands', 'Beginner', 'Squeeze lats', 'Arching too much', NULL, 1);
    ''');
    database.execute('''
      INSERT INTO workout_sessions
        (id, name, total_volume, duration_seconds, estimated_calories, completed_at, is_synced, uuid)
      VALUES (1, 'Bodyweight Skill Session', 0.0, 1500, 150, $_sessionOneMillis, 0, NULL);
    ''');
    database.execute('''
      INSERT INTO workout_sets
        (id, session_id, exercise_name, weight, reps, set_number, is_pr, rpe, is_warm_up, set_notes, uuid, set_type, duration_seconds, distance_km, incline_percentage)
      VALUES (1, 1, 'Pike Push-ups', 0.0, 12, 1, 0, NULL, 0, NULL, NULL, 'working', NULL, NULL, NULL);
    ''');
    database.execute('''
      INSERT INTO workout_routines (id, name, goal, notes, created_at)
      VALUES (1, 'Unresolved Equipment Routine', 'General Fitness', NULL, $_createdAtMillis);
    ''');
    database.execute('''
      INSERT INTO routine_days (id, routine_id, day_of_week, name, is_rest_day)
      VALUES (1, 1, 1, 'Day 1', 0);
    ''');
    database.execute('''
      INSERT INTO routine_exercises (id, day_id, exercise_name, sets, reps_range, order_index)
      VALUES (1, 1, 'Anti-gravity Chamber Press', 3, '10', 0);
    ''');
  }

  static void _insertCanonicalIdentity(sqlite.Database database) {
    database.execute('''
      INSERT INTO exercises
        (id, name, muscle_groups, equipment, difficulty, form_cues, common_mistakes, youtube_id, is_custom)
      VALUES
        (1, 'Flat Barbell Bench Press', 'Chest, Triceps', 'Barbell', 'Intermediate', 'Press evenly', 'Flaring elbows', NULL, 0),
        (2, 'Seated Dumbbell Shoulder Press', 'Shoulders', 'Dumbbells', 'Intermediate', 'Keep core tight', 'Overarching', NULL, 0),
        (3, 'Dumbbell Hammer Curl', 'Biceps', 'Dumbbells', 'Beginner', 'Keep wrists neutral', 'Swinging', NULL, 0),
        (4, 'Incline Dumbbell Curl', 'Biceps', 'Dumbbells', 'Intermediate', 'Keep shoulders back', 'Rushing', NULL, 0),
        (5, 'Pike Push-ups', 'Shoulders', 'Bodyweight', 'Intermediate', 'Keep hips high', 'Flaring elbows', NULL, 1);
    ''');
    database.execute('''
      INSERT INTO workout_sessions
        (id, name, total_volume, duration_seconds, estimated_calories, completed_at, is_synced, uuid)
      VALUES (1, 'Identity fixture', 1200.0, 1800, 220, $_sessionOneMillis, 0, NULL);
    ''');
    database.execute('''
      INSERT INTO workout_sets
        (id, session_id, exercise_name, weight, reps, set_number, is_pr, rpe, is_warm_up, set_notes, uuid, set_type, duration_seconds, distance_km, incline_percentage)
      VALUES
        (1, 1, '  flat   barbell bench press ', 80.0, 8, 1, 0, 8, 0, NULL, NULL, 'working', NULL, NULL, NULL),
        (2, 1, 'seated dumbbell press', 24.0, 10, 1, 0, 7, 0, NULL, NULL, 'working', NULL, NULL, NULL),
        (3, 1, 'dumbbell curls', 12.0, 10, 1, 0, NULL, 0, NULL, NULL, 'working', NULL, NULL, NULL),
        (4, 1, 'Pike Push-ups', 0.0, 12, 1, 0, NULL, 0, NULL, NULL, 'working', NULL, NULL, NULL);
    ''');
    database.execute('''
      INSERT INTO workout_routines (id, name, goal, notes, created_at)
      VALUES (1, 'Identity Routine', 'Strength', NULL, $_createdAtMillis);
    ''');
    database.execute('''
      INSERT INTO routine_days (id, routine_id, day_of_week, name, is_rest_day)
      VALUES (1, 1, 1, 'Identity day', 0);
    ''');
    database.execute('''
      INSERT INTO routine_exercises (id, day_id, exercise_name, sets, reps_range, order_index)
      VALUES
        (1, 1, 'flat barbell bench press', 4, '8', 0),
        (2, 1, 'seated dumbbell press', 3, '10', 1),
        (3, 1, 'dumbbell curls', 3, '10', 2),
        (4, 1, 'Pike Push-ups', 3, '12', 3);
    ''');
  }

  static void _insertDuplicateCanonicalIdentity(sqlite.Database database) {
    database.execute('''
      INSERT INTO exercises
        (id, name, muscle_groups, equipment, difficulty, form_cues, common_mistakes, youtube_id, is_custom)
      VALUES
        (1, 'Flat Barbell Bench Press', 'Chest', 'Barbell', 'Intermediate', 'Press evenly', 'Flaring elbows', NULL, 0),
        (2, 'flat   barbell bench press', 'Chest', 'Barbell', 'Intermediate', 'Press evenly', 'Flaring elbows', NULL, 0);
    ''');
    database.execute('''
      INSERT INTO workout_sessions
        (id, name, total_volume, duration_seconds, estimated_calories, completed_at, is_synced, uuid)
      VALUES (1, 'Duplicate identity fixture', 800.0, 1200, 150, $_sessionOneMillis, 0, NULL);
    ''');
    database.execute('''
      INSERT INTO workout_sets
        (id, session_id, exercise_name, weight, reps, set_number, is_pr, rpe, is_warm_up, set_notes, uuid, set_type, duration_seconds, distance_km, incline_percentage)
      VALUES (1, 1, 'Flat Barbell Bench Press', 80.0, 8, 1, 0, NULL, 0, NULL, NULL, 'working', NULL, NULL, NULL);
    ''');
  }

  static void _insertEquipmentProfile(
    sqlite.Database database,
    String equipmentAccess,
  ) {
    database.execute('''
      INSERT INTO user_profiles
        (id, age, height, weight, sex, activity_level, goal, diet_preference, calorie_goal, protein_goal, carbs_goal, fat_goal, name, equipment_access, injuries_limitations, updated_at)
      VALUES (1, 30, 175.0, 75.0, 'male', 'moderate', 'maintain', 'balanced', 2400, 140.0, 220.0, 60.0, 'Fixture User', '$equipmentAccess', '', $_createdAtMillis);
    ''');
  }

  static void _insertMalformedRelationship(sqlite.Database database) {
    database.execute('''
      INSERT INTO workout_sets
        (id, session_id, exercise_name, weight, reps, set_number, is_pr, rpe, is_warm_up, set_notes, uuid, set_type, duration_seconds, distance_km, incline_percentage)
      VALUES (1, 999, 'Orphaned Bench Press', 80.0, 8, 1, 0, NULL, 0, NULL, NULL, 'working', NULL, NULL, NULL);
    ''');
  }

  static const List<String> _v14SchemaStatements = [
    '''CREATE TABLE exercises (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      muscle_groups TEXT NOT NULL,
      equipment TEXT NOT NULL,
      difficulty TEXT NOT NULL,
      form_cues TEXT NOT NULL,
      common_mistakes TEXT NOT NULL,
      youtube_id TEXT NULL,
      is_custom INTEGER NOT NULL DEFAULT 0
    );''',
    '''CREATE TABLE workout_sessions (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      total_volume REAL NOT NULL,
      duration_seconds INTEGER NOT NULL,
      estimated_calories INTEGER NOT NULL,
      completed_at INTEGER NOT NULL,
      is_synced INTEGER NOT NULL DEFAULT 0,
      uuid TEXT NULL
    );''',
    '''CREATE TABLE workout_sets (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER NOT NULL REFERENCES workout_sessions(id),
      exercise_name TEXT NOT NULL,
      weight REAL NOT NULL,
      reps INTEGER NOT NULL,
      set_number INTEGER NOT NULL,
      is_pr INTEGER NOT NULL DEFAULT 0,
      rpe INTEGER NULL,
      is_warm_up INTEGER NOT NULL DEFAULT 0,
      set_notes TEXT NULL,
      uuid TEXT NULL,
      set_type TEXT NOT NULL DEFAULT 'working',
      duration_seconds INTEGER NULL,
      distance_km REAL NULL,
      incline_percentage REAL NULL
    );''',
    '''CREATE TABLE workout_routines (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      goal TEXT NOT NULL,
      notes TEXT NULL,
      created_at INTEGER NOT NULL
    );''',
    '''CREATE TABLE routine_days (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      routine_id INTEGER NOT NULL REFERENCES workout_routines(id),
      day_of_week INTEGER NOT NULL,
      name TEXT NOT NULL,
      is_rest_day INTEGER NOT NULL DEFAULT 0
    );''',
    '''CREATE TABLE routine_exercises (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      day_id INTEGER NOT NULL REFERENCES routine_days(id),
      exercise_name TEXT NOT NULL,
      sets INTEGER NOT NULL,
      reps_range TEXT NOT NULL,
      order_index INTEGER NOT NULL
    );''',
    '''CREATE TABLE workout_drafts (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      routine_name TEXT NOT NULL,
      current_exercise_index INTEGER NOT NULL,
      current_set_index INTEGER NOT NULL,
      elapsed_seconds INTEGER NOT NULL,
      logged_sets_json TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    );''',
    '''CREATE TABLE user_profiles (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      age INTEGER NOT NULL DEFAULT 25,
      height REAL NOT NULL DEFAULT 170.0,
      weight REAL NOT NULL DEFAULT 70.0,
      sex TEXT NOT NULL DEFAULT 'male',
      activity_level TEXT NOT NULL DEFAULT 'moderate',
      goal TEXT NOT NULL DEFAULT 'maintain',
      diet_preference TEXT NOT NULL DEFAULT 'balanced',
      calorie_goal INTEGER NOT NULL DEFAULT 2000,
      protein_goal REAL NOT NULL DEFAULT 140.0,
      carbs_goal REAL NOT NULL DEFAULT 220.0,
      fat_goal REAL NOT NULL DEFAULT 60.0,
      name TEXT NOT NULL DEFAULT '',
      equipment_access TEXT NOT NULL DEFAULT 'full_gym',
      injuries_limitations TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL
    );''',
  ];
}
