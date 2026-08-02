import 'dart:io';

import 'package:drift/native.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// Builds a real, on-disk B01 v15-shaped database for B02 migration tests.
///
/// The fixture starts from the application's B01-compatible base tables, then
/// explicitly rebuilds only the four B02-amended B01 tables to their v15
/// layouts. That keeps the source independent of the v16 columns while
/// retaining genuine B01 program, occurrence, draft, session, set and health
/// provenance relationships.
class V15DbFixtures {
  static const int schemaVersion = 15;
  static const int _timestampMillis = 1704067200000;

  static Future<File> createSourceDatabase(
    Directory directory,
    String filename,
  ) async {
    final file = File('${directory.path}/$filename');
    final initial = AppDatabase.executor(NativeDatabase(file));
    try {
      await initial.customSelect('SELECT 1').get();
    } finally {
      await initial.close();
    }

    final database = sqlite.sqlite3.open(file.path);
    try {
      database.execute('PRAGMA foreign_keys = OFF;');
      database.execute('BEGIN;');
      _dropB02Tables(database);
      _rebuildV15AmendedTables(database);
      _seedB01Graph(database);
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

  static AppDatabase openCurrentDatabase(
    File file, {
    Future<void> Function()? v16MigrationFailureInjector,
  }) {
    return AppDatabase.executor(
      NativeDatabase(file),
      v16MigrationFailureInjector: v16MigrationFailureInjector,
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

  static void _dropB02Tables(sqlite.Database database) {
    const tables = [
      'performed_rest_periods',
      'performed_set_segments',
      'performed_sets',
      'exercise_target_recommendations',
      'performed_exercises',
      'performed_exercise_groups',
      'cardio_intervals',
      'cardio_session_details',
      'mobility_session_details',
      'exercise_group_members',
      'strength_set_prescriptions',
      'exercise_groups',
      'exercise_muscle_mappings',
      'muscles',
    ];
    for (final table in tables) {
      database.execute('DROP TABLE IF EXISTS $table;');
    }
  }

  static void _rebuildV15AmendedTables(sqlite.Database database) {
    // Rebuild rather than ALTER DROP COLUMN because the fresh v16 declarations
    // contain CHECK constraints for these columns. Foreign keys are disabled
    // for the fixture construction only; the recreated tables retain B01 FKs.
    database.execute('''
      CREATE TABLE workout_sessions_v15 (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        total_volume REAL NOT NULL,
        duration_seconds INTEGER NOT NULL,
        estimated_calories INTEGER NOT NULL,
        completed_at INTEGER NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        uuid TEXT NULL,
        scheduled_occurrence_id TEXT NULL REFERENCES scheduled_session_occurrences(id),
        execution_snapshot_json TEXT NULL,
        execution_timezone_id TEXT NULL,
        completion_kind TEXT NULL
      );
    ''');
    database.execute('''
      INSERT INTO workout_sessions_v15
      SELECT id, name, total_volume, duration_seconds, estimated_calories,
        completed_at, is_synced, uuid, scheduled_occurrence_id,
        execution_snapshot_json, execution_timezone_id, completion_kind
      FROM workout_sessions;
    ''');
    database.execute('DROP TABLE workout_sessions;');
    database.execute(
      'ALTER TABLE workout_sessions_v15 RENAME TO workout_sessions;',
    );

    database.execute('''
      CREATE TABLE workout_drafts_v15 (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        routine_name TEXT NOT NULL,
        current_exercise_index INTEGER NOT NULL,
        current_set_index INTEGER NOT NULL,
        elapsed_seconds INTEGER NOT NULL,
        logged_sets_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        scheduled_occurrence_id TEXT NULL REFERENCES scheduled_session_occurrences(id),
        execution_snapshot_json TEXT NULL,
        draft_schema_version INTEGER NOT NULL DEFAULT 1
      );
    ''');
    database.execute('''
      INSERT INTO workout_drafts_v15
      SELECT id, routine_name, current_exercise_index, current_set_index,
        elapsed_seconds, logged_sets_json, updated_at, scheduled_occurrence_id,
        execution_snapshot_json, draft_schema_version
      FROM workout_drafts;
    ''');
    database.execute('DROP TABLE workout_drafts;');
    database.execute(
      'ALTER TABLE workout_drafts_v15 RENAME TO workout_drafts;',
    );

    database.execute('''
      CREATE TABLE session_templates_v15 (
        id TEXT NOT NULL PRIMARY KEY,
        program_week_id TEXT NOT NULL REFERENCES program_weeks(id),
        ordinal INTEGER NOT NULL,
        name TEXT NOT NULL,
        planned_weekday INTEGER NOT NULL,
        planned_start_minute INTEGER NULL,
        notes TEXT NULL,
        UNIQUE (program_week_id, ordinal),
        UNIQUE (program_week_id, planned_weekday, ordinal),
        CHECK (planned_weekday BETWEEN 1 AND 7),
        CHECK (planned_start_minute IS NULL OR planned_start_minute BETWEEN 0 AND 1439)
      );
    ''');
    database.execute('''
      INSERT INTO session_templates_v15
      SELECT id, program_week_id, ordinal, name, planned_weekday,
        planned_start_minute, notes
      FROM session_templates;
    ''');
    database.execute('DROP TABLE session_templates;');
    database.execute(
      'ALTER TABLE session_templates_v15 RENAME TO session_templates;',
    );

    database.execute('''
      CREATE TABLE exercise_user_preferences_v15 (
        id TEXT NOT NULL PRIMARY KEY,
        identity_key TEXT NOT NULL UNIQUE,
        exercise_id TEXT NULL REFERENCES exercises(stable_id),
        exercise_name_fallback TEXT NULL,
        general_note TEXT NULL,
        created_at_utc INTEGER NOT NULL,
        updated_at_utc INTEGER NOT NULL
      );
    ''');
    database.execute('''
      INSERT INTO exercise_user_preferences_v15
      SELECT id, identity_key, exercise_id, exercise_name_fallback, general_note,
        created_at_utc, updated_at_utc
      FROM exercise_user_preferences;
    ''');
    database.execute('DROP TABLE exercise_user_preferences;');
    database.execute(
      'ALTER TABLE exercise_user_preferences_v15 RENAME TO exercise_user_preferences;',
    );

    const indexes = [
      'CREATE UNIQUE INDEX idx_workout_sessions_occurrence ON workout_sessions(scheduled_occurrence_id)',
      'CREATE INDEX idx_workout_drafts_occurrence ON workout_drafts(scheduled_occurrence_id)',
      'CREATE INDEX idx_session_templates_week_weekday ON session_templates(program_week_id, planned_weekday)',
      'CREATE INDEX idx_exercise_preferences_exercise ON exercise_user_preferences(exercise_id)',
    ];
    for (final index in indexes) {
      database.execute(index);
    }
  }

  static void _seedB01Graph(sqlite.Database database) {
    database.execute('''
      INSERT INTO exercises
        (id, stable_id, name, muscle_groups, equipment, difficulty, form_cues, common_mistakes, youtube_id, is_custom)
      VALUES
        (9001, 'legacy-custom-v15-identity', 'Fixture Custom Exercise', 'Unknown', 'Bodyweight', 'Beginner', '', '', NULL, 1);
    ''');
    database.execute('''
      INSERT INTO programs (id, name, goal, notes, created_at_utc, archived_at_utc)
      VALUES ('program-v15', 'V15 Program', 'strength', NULL, $_timestampMillis, NULL);
    ''');
    database.execute('''
      INSERT INTO program_versions
        (id, program_id, version_number, status, origin, source_version_id, created_at_utc, published_at_utc, archived_at_utc)
      VALUES ('version-v15', 'program-v15', 1, 'published', 'user', NULL, $_timestampMillis, $_timestampMillis, NULL);
    ''');
    database.execute('''
      INSERT INTO program_blocks (id, program_version_id, ordinal, name, description)
      VALUES ('block-v15', 'version-v15', 1, 'Block', NULL);
    ''');
    database.execute('''
      INSERT INTO program_weeks
        (id, program_version_id, program_block_id, ordinal_in_block, program_week_ordinal, name, is_deload)
      VALUES ('week-v15', 'version-v15', 'block-v15', 1, 1, NULL, 0);
    ''');
    database.execute('''
      INSERT INTO session_templates
        (id, program_week_id, ordinal, name, planned_weekday, planned_start_minute, notes)
      VALUES ('template-v15', 'week-v15', 1, 'Strength Template', 1, 480, NULL);
    ''');
    database.execute('''
      INSERT INTO exercise_prescriptions
        (id, session_template_id, ordinal, exercise_id, exercise_name_snapshot, planned_sets, reps_range)
      VALUES ('prescription-v15', 'template-v15', 1, NULL, 'Unresolved Fixture Movement', 3, '8-10');
    ''');
    database.execute('''
      INSERT INTO scheduled_session_occurrences
        (id, program_version_id, session_template_id, program_block_ordinal,
         program_week_ordinal, session_ordinal, repeat_ordinal,
         original_local_date, original_timezone_id, effective_local_date,
         effective_timezone_id, status, progression_disposition, skip_mode,
         repeat_purpose, repeated_from_occurrence_id, execution_snapshot_json,
         started_at_utc, terminal_at_utc, created_at_utc)
      VALUES ('occurrence-v15', 'version-v15', 'template-v15', 1, 1, 1, 0,
        '2024-01-01', 'Asia/Kolkata', '2024-01-01', 'Asia/Kolkata',
        'inProgress', 'pending', NULL, NULL, NULL, '{"schemaVersion":1}',
        $_timestampMillis, NULL, $_timestampMillis);
    ''');
    database.execute('''
      INSERT INTO occurrence_events
        (id, occurrence_id, command_id, event_type, from_status, to_status,
         before_local_date, before_timezone_id, after_local_date,
         after_timezone_id, reason, metadata_json, occurred_at_utc)
      VALUES ('event-v15', 'occurrence-v15', 'start-command-v15', 'started',
        'planned', 'inProgress', NULL, NULL, NULL, NULL, NULL, NULL,
        $_timestampMillis);
    ''');
    database.execute('''
      INSERT INTO workout_sessions
        (id, name, total_volume, duration_seconds, estimated_calories,
         completed_at, is_synced, uuid, scheduled_occurrence_id,
         execution_snapshot_json, execution_timezone_id, completion_kind)
      VALUES (41, 'Legacy Treadmill Label Must Not Classify', 1250.0, 1800,
        240, $_timestampMillis, 0, 'session-v15', 'occurrence-v15',
        '{"schemaVersion":1}', 'Asia/Kolkata', 'full');
    ''');
    database.execute('''
      INSERT INTO workout_sets
        (id, session_id, exercise_name, weight, reps, set_number, is_pr, rpe,
         is_warm_up, set_notes, uuid, set_type, duration_seconds, distance_km,
         incline_percentage, exercise_id)
      VALUES (51, 41, 'Unresolved Treadmill Named Exercise', 0.0, 0, 1, 0,
        NULL, 0, 'must remain legacy', 'set-v15', 'working', 1200, 3.2, 2.0,
        NULL);
    ''');
    database.execute('''
      INSERT INTO workout_drafts
        (id, routine_name, current_exercise_index, current_set_index,
         elapsed_seconds, logged_sets_json, updated_at,
         scheduled_occurrence_id, execution_snapshot_json, draft_schema_version)
      VALUES (61, 'V15 active draft', 1, 0, 600,
        '[{"sessionId":0,"exerciseName":"Unresolved Fixture Movement","weight":0.0,"reps":0,"setNumber":1,"isPr":false,"isWarmUp":false,"setType":"working"}]',
        $_timestampMillis, 'occurrence-v15', '{"schemaVersion":1}', 1);
    ''');
    database.execute('''
      INSERT INTO exercise_user_preferences
        (id, identity_key, exercise_id, exercise_name_fallback, general_note,
         created_at_utc, updated_at_utc)
      VALUES ('pref-v15', 'raw:unresolved-fixture', NULL,
        'Unresolved Fixture Movement', 'Legacy preference', $_timestampMillis,
        $_timestampMillis);
    ''');
    database.execute('''
      INSERT INTO health_provenances
        (id, provider, external_id, source_name, imported_at, local_session_id, fingerprint)
      VALUES (71, 'health_connect', 'provider-v15-id', 'Provider V15',
        $_timestampMillis, 41, 'provider-v15-fingerprint');
    ''');
  }
}
