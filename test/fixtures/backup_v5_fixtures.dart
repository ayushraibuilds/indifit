import 'package:indifit/core/backup/backup_schema.dart';

/// Deterministic Backup v5 payloads for restore and prevalidation tests.
class BackupV5Fixtures {
  static const String timestamp = '2024-01-01T00:00:00.000Z';

  static Map<String, dynamic> validBackupV5Map() {
    return {
      'version': 5,
      'timestamp': timestamp,
      'schema_version': 14,
      'user_settings': [],
      'user_preferences': {
        'water_logged': 6,
        'user_streak_count': 10,
        'prefRemindWorkout': true,
      },
      'food_items': [
        {
          'id': 101,
          'name': 'Home Made Whey Shake',
          'calories': 180,
          'protein_g': 30.0,
          'carbs_g': 4.0,
          'fat_g': 2.5,
          'fiber_g': 0.0,
          'serving_size': 300.0,
          'serving_unit': 'ml',
          'category': 'custom',
          'is_custom': true,
          'brand': null,
          'region_pack': null,
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
          'youtube_id': null,
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
          'completed_at': '2023-12-31T00:00:00.000Z',
          'is_synced': false,
          'uuid': null,
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
          'rpe': 8,
          'is_warm_up': false,
          'set_type': 'working',
          'set_notes': 'Felt good!',
          'uuid': null,
          'duration_seconds': null,
          'distance_km': null,
          'incline_percentage': null,
        },
      ],
      'workout_routines': [
        {
          'id': 1,
          'name': 'Upper Body Split',
          'goal': 'Hypertrophy',
          'notes': 'Upper focus',
          'created_at': timestamp,
        },
      ],
      'routine_days': [
        {
          'id': 1,
          'routine_id': 1,
          'day_of_week': 1,
          'name': 'Upper Day 1',
          'is_rest_day': false,
        },
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

  static BackupData validBackupV5Object() =>
      BackupData.fromJson(validBackupV5Map());

  static Map<String, dynamic> orphanedSetsBackupV5Map() {
    final map = validBackupV5Map();
    map['workout_sessions'] = [];
    map['workout_sets'] = [
      {
        'id': 1,
        'session_id': 999,
        'exercise_name': 'Orphaned Bench Press',
        'weight': 80.0,
        'reps': 8,
        'set_number': 1,
        'is_pr': false,
        'is_warm_up': false,
        'set_type': 'working',
      },
    ];
    return map;
  }

  static Map<String, dynamic> unsupportedVersionBackupMap() {
    final map = validBackupV5Map();
    map['version'] = 7;
    return map;
  }

  static Map<String, dynamic> corruptSchemaBackupMap() => {
    'version': 5,
    'timestamp': timestamp,
    'schema_version': 'not_an_int',
    'user_preferences': 'corrupt_string_instead_of_map',
  };
}
