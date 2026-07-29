import 'package:indifit/core/backup/backup_schema.dart';

/// Deterministic Backup v5 payload fixtures for testing backup prevalidation and restore transactions.
class BackupV5Fixtures {
  /// Returns a valid Backup v5 JSON payload map (schema_version 14, version 4/5).
  static Map<String, dynamic> validBackupV5Map() {
    return {
      'version': 4,
      'timestamp': DateTime.now().toIso8601String(),
      'schema_version': 14,
      'user_settings': [],
      'user_preferences': {
        'water_logged': 6,
        'user_streak_count': 10,
        'equipment_profile': 'dumbbells',
      },
      'custom_food_items': [
        {
          'id': 101,
          'name': 'Home Made Whey Shake',
          'calories': 180,
          'protein_g': 30.0,
          'carbs_g': 4.0,
          'fat_g': 2.5,
          'serving_size': 300.0,
          'serving_unit': 'ml',
          'category': 'custom',
          'is_custom': true,
        },
      ],
      'food_logs': [],
      'meal_templates': [],
      'meal_template_items': [],
      'custom_exercises': [
        {
          'id': 1,
          'name': 'Pike Push-ups',
          'muscle_groups': 'Shoulders',
          'equipment': 'Bodyweight',
          'difficulty': 'Intermediate',
          'form_cues': 'Keep hips high in V position',
          'common_mistakes': 'Flaring elbows outward',
          'is_custom': true,
        },
      ],
      'workout_sessions': [
        {
          'id': 1,
          'name': 'Push Session',
          'total_volume': 1600.0,
          'duration_seconds': 1800,
          'estimated_calories': 200,
          'completed_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
      ],
      'workout_sets': [
        {
          'id': 1,
          'session_id': 1,
          'exercise_name': 'Flat Barbell Bench Press',
          'weight': 80.0,
          'reps': 10,
          'set_number': 1,
          'is_pr': true,
          'is_warm_up': false,
          'set_type': 'working',
          'set_notes': 'Felt good!',
        },
      ],
      'workout_routines': [
        {
          'id': 1,
          'name': 'Upper Body Split',
          'goal': 'Hypertrophy',
          'description': 'Upper focus',
          'target_gender': 'unisex',
          'created_at': DateTime.now().toIso8601String(),
        },
      ],
      'routine_days': [
        {'id': 1, 'routine_id': 1, 'day_of_week': 1, 'name': 'Upper Day 1'},
      ],
      'routine_exercises': [
        {
          'id': 1,
          'day_id': 1,
          'exercise_name': 'Flat Barbell Bench Press',
          'sets': 4,
          'reps_range': '8',
          'order_index': 0,
        },
      ],
      'workout_drafts': [],
      'body_measurements': [],
      'daily_hydrations': [],
      'health_provenances': [],
      'achievement_unlocks': [],
    };
  }

  /// Returns a valid BackupData object constructed from validBackupV5Map.
  static BackupData validBackupV5Object() {
    return BackupData.fromJson(validBackupV5Map());
  }

  /// Returns an invalid Backup v5 payload containing orphaned workout sets referencing missing session ID 999.
  static Map<String, dynamic> orphanedSetsBackupV5Map() {
    final map = validBackupV5Map();
    map['workout_sessions'] = []; // Clear sessions
    map['workout_sets'] = [
      {
        'id': 1,
        'session_id': 999, // Non-existent session
        'exercise_name': 'Orphaned Bench Press',
        'weight': 80.0,
        'reps': 8,
        'set_number': 1,
        'is_pr': false,
        'is_warm_up': false,
        'set_type': 'normal',
      },
    ];
    return map;
  }

  /// Returns an unsupported backup version payload (e.g. version 99).
  static Map<String, dynamic> unsupportedVersionBackupMap() {
    final map = validBackupV5Map();
    map['version'] = 99;
    return map;
  }

  /// Returns a corrupt JSON payload map (missing required schema_version or invalid types).
  static Map<String, dynamic> corruptSchemaBackupMap() {
    return {
      'version': 4,
      'schema_version': 'not_an_int',
      'user_preferences': 'corrupt_string_instead_of_map',
    };
  }
}
