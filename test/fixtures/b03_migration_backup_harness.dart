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
  static const String completeFixturePath =
      'test/fixtures/data/b03_v16_complete_graph.db';
  static const String checksum =
      '27516799c7cfa9dba53a408c13a638fdb2be8bae32ee887fee2bf9f7ce147eb5';
  static const String completeChecksum =
      'cee818f3502273e507d02670e3ecf084a3dd0528828e68e40d15cd88c645e550';

  static final DateTime timestamp = DateTime.utc(2026, 1, 15, 8, 30);

  static Future<File> copyTo(Directory directory, {String? filename}) async {
    final source = File(fixturePath);
    if (!source.existsSync()) {
      throw StateError('Missing checked-in B03 v16 fixture: $fixturePath');
    }
    return source.copy('${directory.path}/${filename ?? 'b03-v16-fixture.db'}');
  }

  static Future<File> copyCompleteTo(
    Directory directory, {
    String? filename,
  }) async {
    final source = File(completeFixturePath);
    if (!source.existsSync()) {
      throw StateError(
        'Missing checked-in complete B03 v16 fixture: $completeFixturePath',
      );
    }
    return source.copy(
      '${directory.path}/${filename ?? 'b03-v16-complete-graph.db'}',
    );
  }

  static AppDatabase open(File file) => AppDatabase.executor(
    NativeDatabase(file),
    schemaVersionOverride: schemaVersion,
  );

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

    await _seedCompleteB01B02Graph(
      db,
      primaryExerciseId: seededExercise.stableId!,
      primaryExerciseName: seededExercise.name,
    );
  }

  /// Adds one complete, synthetic B01/B02 graph to the immutable baseline.
  ///
  /// This is deliberately fixture-owned data rather than production seed
  /// data.  Every supported relational collection gets at least one durable
  /// row so a later migration or Backup-v8 test proves preservation of actual
  /// relationships instead of only proving that empty tables exist.
  static Future<void> _seedCompleteB01B02Graph(
    AppDatabase db, {
    required String primaryExerciseId,
    required String primaryExerciseName,
  }) async {
    String sqlValue(Object? value) {
      if (value == null) return 'NULL';
      if (value is num) return value.toString();
      if (value is bool) return value ? '1' : '0';
      return "'${value.toString().replaceAll("'", "''")}'";
    }

    final at = timestamp.millisecondsSinceEpoch;
    final programId = 'fixture-program-v16';
    final versionId = 'fixture-program-version-v16';
    final blockId = 'fixture-program-block-v16';
    final weekId = 'fixture-program-week-v16';
    final templateId = 'fixture-session-template-v16';
    final prescriptionId = 'fixture-exercise-prescription-v16';
    final secondPrescriptionId = 'fixture-exercise-prescription-v16-2';
    final groupId = 'fixture-exercise-group-v16';
    final occurrenceId = 'fixture-occurrence-v16';
    final routineId = 5101;
    final routineDayId = 5102;

    await db.customStatement('''
      INSERT INTO programs
        (id, name, goal, notes, created_at_utc)
      VALUES
        (${sqlValue(programId)}, 'Fixture B02 Program', 'strength',
         'Complete immutable B01/B02 baseline graph', $at)
    ''');
    await db.customStatement('''
      INSERT INTO program_versions
        (id, program_id, version_number, status, origin, created_at_utc,
         published_at_utc)
      VALUES
        (${sqlValue(versionId)}, ${sqlValue(programId)}, 1, 'published',
         'legacyImport', $at, $at)
    ''');
    await db.customStatement('''
      INSERT INTO program_blocks
        (id, program_version_id, ordinal, name, description)
      VALUES
        (${sqlValue(blockId)}, ${sqlValue(versionId)}, 0, 'Fixture Block',
         'One reviewed block for migration and restore coverage')
    ''');
    await db.customStatement('''
      INSERT INTO program_weeks
        (id, program_version_id, program_block_id, ordinal_in_block,
         program_week_ordinal, name, is_deload)
      VALUES
        (${sqlValue(weekId)}, ${sqlValue(versionId)}, ${sqlValue(blockId)},
         0, 1, 'Fixture Week 1', 0)
    ''');
    await db.customStatement('''
      INSERT INTO session_templates
        (id, program_week_id, ordinal, name, planned_weekday,
         planned_start_minute, notes, activity_type, default_rest_seconds)
      VALUES
        (${sqlValue(templateId)}, ${sqlValue(weekId)}, 0, 'Fixture Push Session',
         1, 480, 'Synthetic B02 execution source', 'strength', 120)
    ''');
    await db.customStatement('''
      INSERT INTO exercise_prescriptions
        (id, session_template_id, ordinal, exercise_id,
         exercise_name_snapshot, planned_sets, reps_range)
      VALUES
        (${sqlValue(prescriptionId)}, ${sqlValue(templateId)}, 0,
         ${sqlValue(primaryExerciseId)}, ${sqlValue(primaryExerciseName)}, 3,
         '8-10')
    ''');
    await db.customStatement('''
      INSERT INTO exercise_prescriptions
        (id, session_template_id, ordinal, exercise_id,
         exercise_name_snapshot, planned_sets, reps_range)
      VALUES
        (${sqlValue(secondPrescriptionId)}, ${sqlValue(templateId)}, 1,
         ${sqlValue(primaryExerciseId)}, ${sqlValue(primaryExerciseName)}, 3,
         '10-12')
    ''');
    await db.customStatement('''
      INSERT INTO strength_set_prescriptions
        (id, exercise_prescription_id, ordinal, target_load_kg, load_basis,
         target_reps_min, target_reps_max, target_rpe, rest_seconds,
         effort_mode, tempo_eccentric_seconds, tempo_bottom_pause_seconds,
         tempo_concentric_seconds, tempo_lockout_pause_seconds,
         paused_rep_position, paused_rep_seconds, technique_plan_json)
      VALUES
        ('fixture-strength-prescription-v16', ${sqlValue(prescriptionId)}, 0,
         60, 'totalExternal', 8, 10, 8, 120, 'standard', 3, 1, 1, 0,
         'bottom', 1, '{"technique":"standard"}')
    ''');
    await db.customStatement('''
      INSERT INTO strength_set_prescriptions
        (id, exercise_prescription_id, ordinal, target_load_kg, load_basis,
         target_reps_min, target_reps_max, target_rpe, rest_seconds,
         effort_mode, assistance_mode, assistance_kg)
      VALUES
        ('fixture-strength-prescription-v16-2',
         ${sqlValue(secondPrescriptionId)}, 0, 50, 'totalExternal', 10, 12,
         7, 90, 'standard', NULL, NULL)
    ''');
    await db.customStatement('''
      INSERT INTO exercise_groups
        (id, session_template_id, ordinal, group_type, round_count,
         rest_after_round_seconds, label)
      VALUES
        (${sqlValue(groupId)}, ${sqlValue(templateId)}, 0, 'superset', 2, 90,
         'Fixture Superset')
    ''');
    await db.customStatement('''
      INSERT INTO exercise_group_members
        (id, exercise_group_id, exercise_prescription_id, ordinal,
         transition_rest_seconds)
      VALUES
        ('fixture-group-member-v16-1', ${sqlValue(groupId)},
         ${sqlValue(prescriptionId)}, 0, 15),
        ('fixture-group-member-v16-2', ${sqlValue(groupId)},
         ${sqlValue(secondPrescriptionId)}, 1, 15)
    ''');
    await db.customStatement('''
      INSERT INTO scheduled_session_occurrences
        (id, program_version_id, session_template_id, program_block_ordinal,
         program_week_ordinal, session_ordinal, original_local_date,
         original_timezone_id, effective_local_date, effective_timezone_id,
         status, progression_disposition, execution_snapshot_json,
         started_at_utc, terminal_at_utc, created_at_utc)
      VALUES
        (${sqlValue(occurrenceId)}, ${sqlValue(versionId)},
         ${sqlValue(templateId)}, 0, 1, 0, '2026-01-15', 'Asia/Kolkata',
         '2026-01-15', 'Asia/Kolkata', 'completed', 'satisfied',
         '{"source":"fixture","session":"fixture-workout-session-4101"}',
         $at, ${at + 1800000000}, $at)
    ''');
    await db.customStatement('''
      INSERT INTO occurrence_events
        (id, occurrence_id, command_id, event_type, from_status, to_status,
         after_local_date, after_timezone_id, reason, metadata_json,
         occurred_at_utc)
      VALUES
        ('fixture-occurrence-event-v16', ${sqlValue(occurrenceId)},
         'fixture-command-v16', 'complete', 'inProgress', 'completed',
         '2026-01-15', 'Asia/Kolkata', 'fixture completion',
         '{"fixture":true}', ${at + 1800000000})
    ''');
    await db.customStatement('''
      INSERT INTO equipment_profiles
        (id, name, default_weight_increment_kg, legacy_access_code, note,
         created_at_utc, updated_at_utc)
      VALUES
        ('fixture-equipment-profile-v16', 'Fixture Home Gym', 2.5,
         'fixture-home-gym', 'Synthetic equipment profile', $at, $at)
    ''');
    await db.customStatement('''
      INSERT INTO equipment_profile_items
        (id, equipment_profile_id, equipment_code, is_available,
         weight_increment_kg)
      VALUES
        ('fixture-equipment-item-v16', 'fixture-equipment-profile-v16',
         'barbell', 1, 2.5)
    ''');
    await db.customStatement('''
      INSERT OR REPLACE INTO training_plan_settings
        (id, active_program_version_id, active_since_local_date,
         active_since_timezone_id, default_equipment_profile_id,
         updated_at_utc)
      VALUES
        (1, ${sqlValue(versionId)}, '2026-01-15', 'Asia/Kolkata',
         'fixture-equipment-profile-v16', $at)
    ''');
    await db.customStatement('''
      INSERT INTO travel_contexts
        (id, start_local_date, end_local_date, timezone_id,
         equipment_profile_id, status, note, created_at_utc)
      VALUES
        ('fixture-travel-context-v16', '2026-01-16', '2026-01-17',
         'Asia/Kolkata', 'fixture-equipment-profile-v16', 'active',
         'Fixture travel override', $at)
    ''');
    await db.customStatement('''
      INSERT INTO travel_context_occurrences
        (travel_context_id, occurrence_id, confirmed_at_utc)
      VALUES
        ('fixture-travel-context-v16', ${sqlValue(occurrenceId)}, ${at + 1})
    ''');
    await db.customStatement('''
      INSERT INTO exercise_user_preferences
        (id, identity_key, exercise_id, exercise_name_fallback, general_note,
         warmup_preference, warmup_set_count, custom_rest_seconds,
         created_at_utc, updated_at_utc)
      VALUES
        ('fixture-exercise-preference-v16', ${sqlValue(primaryExerciseId)},
         ${sqlValue(primaryExerciseId)}, ${sqlValue(primaryExerciseName)},
         'Fixture preference', 'automatic', 2, 150, $at, $at)
    ''');
    await db.customStatement('''
      INSERT INTO exercise_setup_values
        (id, exercise_user_preference_id, ordinal, label, value)
      VALUES
        ('fixture-setup-value-v16', 'fixture-exercise-preference-v16', 0,
         'bench_angle', '30')
    ''');
    await db.customStatement('''
      INSERT INTO exercise_personal_cues
        (id, exercise_user_preference_id, ordinal, cue_text)
      VALUES
        ('fixture-personal-cue-v16', 'fixture-exercise-preference-v16', 0,
         'Fixture controlled eccentric')
    ''');
    await db.customStatement('''
      INSERT INTO workout_routines
        (id, name, goal, notes, created_at)
      VALUES
        ($routineId, 'Fixture Legacy Routine', 'strength',
         'Local-ID remapping source', $at)
    ''');
    await db.customStatement('''
      INSERT INTO routine_days
        (id, routine_id, day_of_week, name, is_rest_day)
      VALUES
        ($routineDayId, $routineId, 1, 'Fixture Day 1', 0)
    ''');
    await db.customStatement('''
      INSERT INTO routine_exercises
        (id, day_id, exercise_name, sets, reps_range, order_index)
      VALUES
        (5103, $routineDayId, ${sqlValue(primaryExerciseName)}, 3, '8-10', 0)
    ''');
    await db.customStatement('''
      INSERT INTO legacy_routine_program_mappings
        (legacy_routine_id, program_id, program_version_id, imported_at_utc)
      VALUES
        ($routineId, ${sqlValue(programId)}, ${sqlValue(versionId)}, $at)
    ''');
    await db.customStatement('''
      INSERT INTO achievement_unlocks (id, achievement_id, unlocked_at)
      VALUES (5201, 'fixture-achievement-v16', $at)
    ''');
    await db.customStatement('''
      INSERT INTO daily_hydrations
        (id, date_string, total_ml, goal_ml, updated_at)
      VALUES (5202, '2026-01-15', 1800, 2500, $at)
    ''');
    await db.customStatement('''
      INSERT INTO body_measurements
        (id, weight, waist, chest, arms, recorded_at, is_synced)
      VALUES (5203, 76.5, 82, 100, 34, $at, 0)
    ''');
    await db.customStatement('''
      INSERT INTO cardio_intervals
        (id, cardio_session_id, ordinal, segment_type, duration_seconds,
         distance_metres, target_pace_seconds_per_km, actual_pace_seconds_per_km,
         target_intensity, actual_intensity, average_heart_rate)
      VALUES
        ('fixture-cardio-interval-v16', 4102, 0, 'work', 600, 2000, 300, 295,
         'steady', 'steady', 150)
    ''');
    await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            id: const Value(4103),
            name: 'Fixture Mobility Session',
            totalVolume: 0,
            durationSeconds: 900,
            estimatedCalories: 45,
            completedAt: Value(timestamp.add(const Duration(days: 4))),
            uuid: const Value('fixture-workout-session-mobility-v16'),
            activityType: const Value('mobility'),
          ),
        );
    await db.customStatement('''
      INSERT INTO mobility_session_details
        (session_id, practice_type, style, intensity, focus_note,
         average_heart_rate)
      VALUES (4103, 'mobility', 'joint-flow', 'low', 'Fixture hip mobility', 92)
    ''');
    await db.customStatement('''
      INSERT INTO performed_exercise_groups
        (id, session_id, source_exercise_group_id, group_type_snapshot,
         label_snapshot, ordinal, planned_rounds, completed_rounds, status)
      VALUES
        ('fixture-performed-group-v16', 4101, ${sqlValue(groupId)}, 'superset',
         'Fixture Superset', 0, 2, 2, 'completed')
    ''');
    await db.customStatement('''
      INSERT INTO performed_exercises
        (id, session_id, performed_exercise_group_id,
         source_exercise_prescription_id, group_member_ordinal,
         group_round_ordinal, ordinal, expected_exercise_id,
         expected_exercise_name_snapshot, actual_exercise_id,
         actual_exercise_name_snapshot, status)
      VALUES
        ('fixture-performed-exercise-v16', 4101, 'fixture-performed-group-v16',
         ${sqlValue(prescriptionId)}, 0, 0, 0, ${sqlValue(primaryExerciseId)},
         ${sqlValue(primaryExerciseName)}, ${sqlValue(primaryExerciseId)},
         ${sqlValue(primaryExerciseName)}, 'completed')
    ''');
    await db.customStatement('''
      INSERT INTO exercise_target_recommendations
        (id, performed_exercise_id, rule_version, confidence, completeness_json,
         recommended_load_kg, load_basis, target_reps_min, target_reps_max,
         target_rpe, increment_kg, evidence_cutoff_utc, comparator_count,
         rationale_codes_json, was_overridden)
      VALUES
        ('fixture-recommendation-v16', 'fixture-performed-exercise-v16',
         'fixture-rule-v1', 'medium', '{"load":true}', 62.5,
         'totalExternal', 8, 10, 8, 2.5, $at, 1, '["fixture"]', 0)
    ''');
    await db.customStatement('''
      INSERT INTO performed_sets
        (id, performed_exercise_id, ordinal, role, target_load_kg,
         target_load_basis, target_reps_min, target_reps_max, target_rpe,
         actual_load_kg, actual_load_basis, actual_reps, actual_rpe,
         effort_mode, ended_at_failure, tempo_eccentric_seconds,
         tempo_bottom_pause_seconds, tempo_concentric_seconds,
         tempo_lockout_pause_seconds, paused_rep_position, paused_rep_seconds,
         notes)
      VALUES
        ('fixture-performed-set-v16', 'fixture-performed-exercise-v16', 0,
         'working', 60, 'totalExternal', 8, 10, 8, 60, 'totalExternal', 8, 8,
         'standard', 0, 3, 1, 1, 0, 'bottom', 1, 'Fixture performed set')
    ''');
    await db.customStatement('''
      INSERT INTO performed_set_segments
        (id, performed_set_id, ordinal, reps, external_load_kg, load_basis,
         assistance_kg, rest_before_seconds)
      VALUES
        ('fixture-performed-segment-v16', 'fixture-performed-set-v16', 0, 8,
         60, 'totalExternal', NULL, 120)
    ''');
    await db.customStatement('''
      INSERT INTO performed_rest_periods
        (id, session_id, performed_set_id, performed_exercise_group_id, scope,
         recommended_seconds, selected_seconds, actual_seconds, source,
         started_at_utc, ended_at_utc, end_reason)
      VALUES
        ('fixture-rest-period-v16', 4101, 'fixture-performed-set-v16',
         'fixture-performed-group-v16', 'exerciseSet', 120, 120, 118,
         'prescription', ${at + 1000000}, ${at + 119000000}, 'elapsed')
    ''');
  }
}

class B03BackupV7Fixture {
  static const int version = 7;
  static const int schemaVersion = 16;
  static const String fixtureId = 'b03-backup-v7-legacy-baseline-01';
  static const String fixturePath =
      'test/fixtures/data/b03_backup_v7_legacy_baseline.json';
  static const String completeFixturePath =
      'test/fixtures/data/b03_backup_v7_complete_graph.json';
  static const String checksum =
      '16e486faf0abba0f4b075a928eab25f3fe9e651e68687a6f66da14b944daa3ae';
  static const String completeChecksum =
      '02dc06612a6798ceec21efdc3bc9617a58e9e99af87b765ce11992b1aa51890a';
  static const String timestamp = '2026-01-15T08:30:00.000Z';

  static BackupData load() {
    return loadFromFile(File(fixturePath), fixturePath);
  }

  static BackupData loadComplete() {
    return loadFromFile(File(completeFixturePath), completeFixturePath);
  }

  static BackupData loadFromFile(File file, String path) {
    if (!file.existsSync()) {
      throw StateError('Missing checked-in B03 Backup-v7 fixture: $path');
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      throw const FormatException('B03 Backup-v7 fixture must be an object.');
    }
    final backup = BackupData.fromJson(Map<String, dynamic>.from(decoded));
    if (backup.version != version || backup.schemaVersion != schemaVersion) {
      throw StateError('B03 Backup-v7 fixture version drifted: $path');
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

  Future<void> onNutritionMigrationStage(V17MigrationFailureStage stage) async {
    final mapped = switch (stage) {
      V17MigrationFailureStage.validation =>
        B03FailureStage.migrationValidation,
      V17MigrationFailureStage.ddlAndDataMutation =>
        B03FailureStage.migrationDdlAndDataMutation,
      V17MigrationFailureStage.beforeTransactionCommit =>
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
      schemaVersionOverride: B03V16Fixture.schemaVersion,
    );
  }

  Future<void> restore(
    BackupData backup,
    AppDatabase db, [
    SharedPreferences? prefs,
  ]) async {
    // Preference restoration is only reachable while compensating for a
    // database failure. The trigger is a deterministic setup fault; the
    // selected typed failure is still the preference-restore boundary. The
    // production compensation path must restore the complete captured set
    // before rethrowing this injected failure.
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

  AppDatabase openNutritionMigrating(File source) {
    return AppDatabase.executor(
      NativeDatabase(source),
      v17MigrationFailureStageInjector: onNutritionMigrationStage,
    );
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
    'achievement_unlocks',
    'daily_hydrations',
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
    'training_plan_settings',
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
    'programs': ['id', 'created_at_utc'],
    'program_versions': ['id', 'version_number'],
    'program_blocks': ['program_version_id', 'ordinal', 'id'],
    'program_weeks': ['program_version_id', 'program_week_ordinal', 'id'],
    'session_templates': ['program_week_id', 'ordinal', 'id'],
    'scheduled_session_occurrences': [
      'effective_local_date',
      'program_week_ordinal',
      'session_ordinal',
      'id',
    ],
    'occurrence_events': ['occurrence_id', 'occurred_at_utc', 'id'],
    'exercise_groups': ['session_template_id', 'ordinal', 'id'],
    'exercise_group_members': ['exercise_group_id', 'ordinal', 'id'],
    'performed_exercise_groups': ['session_id', 'ordinal', 'id'],
    'performed_exercises': ['session_id', 'ordinal', 'id'],
    'performed_sets': ['performed_exercise_id', 'ordinal', 'id'],
    'performed_set_segments': ['performed_set_id', 'ordinal', 'id'],
    'performed_rest_periods': ['session_id', 'started_at_utc', 'id'],
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
    'exercise_user_preference_id': 'exercise_user_preferences',
    'muscle_id': 'muscles',
    'cardio_session_id': 'cardio_session_details',
    'performed_exercise_group_id': 'performed_exercise_groups',
    'performed_exercise_id': 'performed_exercises',
    'performed_set_id': 'performed_sets',
    'active_program_version_id': 'program_versions',
    'legacy_routine_id': 'workout_routines',
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
      final target =
          _foreignKeyTargets[entry.key] ??
          ((table == 'cardio_session_details' ||
                      table == 'mobility_session_details') &&
                  entry.key == 'session_id'
              ? 'workout_sessions'
              : null);
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
