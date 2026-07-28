import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/app_database.dart';

/// Canonical Versioned Backup Schema (Version 4).
///
/// Provides a unified, production-safe DTO and serializer for all user-owned
/// database records and persisted application preferences.
/// Shared identically by manual backup/export and automated background backups.
class BackupData {
  static const int currentVersion = 4;

  final int version;
  final String timestamp;
  final int schemaVersion;

  final UserProfile? userProfile;
  final List<UserSetting> userSettings;
  final Map<String, dynamic> userPreferences;

  final List<FoodItem> customFoodItems;
  final List<FoodLog> foodLogs;

  final List<MealTemplate> mealTemplates;
  final List<MealTemplateItem> mealTemplateItems;

  final List<Exercise> customExercises;
  final List<WorkoutSession> workoutSessions;
  final List<WorkoutSet> workoutSets;

  final List<WorkoutRoutine> workoutRoutines;
  final List<RoutineDay> routineDays;
  final List<RoutineExercise> routineExercises;

  final List<WorkoutDraft> workoutDrafts;
  final List<BodyMeasurement> bodyMeasurements;

  BackupData({
    required this.version,
    required this.timestamp,
    required this.schemaVersion,
    this.userProfile,
    required this.userSettings,
    required this.userPreferences,
    required this.customFoodItems,
    required this.foodLogs,
    required this.mealTemplates,
    required this.mealTemplateItems,
    required this.customExercises,
    required this.workoutSessions,
    required this.workoutSets,
    required this.workoutRoutines,
    required this.routineDays,
    required this.routineExercises,
    required this.workoutDrafts,
    required this.bodyMeasurements,
  });

  /// Constructs a [BackupData] payload directly from the database and optional [SharedPreferences].
  static Future<BackupData> createFromDatabase(
    AppDatabase db, [
    SharedPreferences? prefs,
  ]) async {
    final userProfile = await db.select(db.userProfiles).getSingleOrNull();
    final userSettings = await db.select(db.userSettings).get();

    final allFoodItems = await db.select(db.foodItems).get();
    final customFoodItems = allFoodItems.where((f) => f.isCustom).toList();
    final foodLogs = await db.select(db.foodLogs).get();

    final mealTemplates = await db.select(db.mealTemplates).get();
    final mealTemplateItems = await db.select(db.mealTemplateItems).get();

    final allExercises = await db.select(db.exercises).get();
    final customExercises = allExercises.where((e) => e.isCustom).toList();

    final workoutSessions = await db.select(db.workoutSessions).get();
    final workoutSets = await db.select(db.workoutSets).get();

    final workoutRoutines = await db.select(db.workoutRoutines).get();
    final routineDays = await db.select(db.routineDays).get();
    final routineExercises = await db.select(db.routineExercises).get();

    final workoutDrafts = await db.select(db.workoutDrafts).get();
    final bodyMeasurements = await db.select(db.bodyMeasurements).get();

    final userPreferences = <String, dynamic>{};
    if (prefs != null) {
      const keys = [
        'pref_crash_reporting_enabled',
        'pref_offline_only',
        'offline_only',
        'onboarding_completed',
        'water_logged',
        'water_goal',
        'water_glass_size',
        'water_last_logged_date',
        'streak_freezes_count',
        'pref_streak_freeze_count',
        'user_streak_count',
        'last_streak_date',
        'last_freeze_claimed_at',
        'auto_sync_health_on_open',
        'health_last_sync_time',
        'user_name',
        'user_age',
        'user_height',
        'user_weight',
        'current_weight',
        'user_target_weight',
        'user_sex',
        'user_activity_level',
        'user_goal',
        'user_diet_preference',
        'calorie_goal',
        'protein_goal',
        'carbs_goal',
        'fat_goal',
        'pref_achievements_json',
        'prefRemindWorkout',
        'prefRemindMeals',
        'prefRemindWater',
        'prefRemindEvening',
        'prefRemindWeekly',
        'prefQuietHoursEnabled',
        'prefQuietHoursStart',
        'prefQuietHoursEnd',
        'weekly_action_type',
        'weekly_action_text',
        'weekly_action_target',
        'weekly_action_target_date',
      ];
      for (final key in keys) {
        final val = prefs.get(key);
        if (val != null) {
          userPreferences[key] = val;
        }
      }
      final stringListKeys = [
        'installed_food_packs',
        'unlocked_achievement_ids',
      ];
      for (final key in stringListKeys) {
        final listVal = prefs.getStringList(key);
        if (listVal != null) {
          userPreferences[key] = listVal;
        }
      }
    }

    return BackupData(
      version: currentVersion,
      timestamp: DateTime.now().toIso8601String(),
      schemaVersion: db.schemaVersion,
      userProfile: userProfile,
      userSettings: userSettings,
      userPreferences: userPreferences,
      customFoodItems: customFoodItems,
      foodLogs: foodLogs,
      mealTemplates: mealTemplates,
      mealTemplateItems: mealTemplateItems,
      customExercises: customExercises,
      workoutSessions: workoutSessions,
      workoutSets: workoutSets,
      workoutRoutines: workoutRoutines,
      routineDays: routineDays,
      routineExercises: routineExercises,
      workoutDrafts: workoutDrafts,
      bodyMeasurements: bodyMeasurements,
    );
  }

  /// Serializes the canonical backup payload to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'timestamp': timestamp,
      'schema_version': schemaVersion,
      if (userProfile != null)
        'user_profile': {
          'id': userProfile!.id,
          'age': userProfile!.age,
          'height': userProfile!.height,
          'weight': userProfile!.weight,
          'sex': userProfile!.sex,
          'activity_level': userProfile!.activityLevel,
          'goal': userProfile!.goal,
          'diet_preference': userProfile!.dietPreference,
          'calorie_goal': userProfile!.calorieGoal,
          'protein_goal': userProfile!.proteinGoal,
          'carbs_goal': userProfile!.carbsGoal,
          'fat_goal': userProfile!.fatGoal,
          'updated_at': userProfile!.updatedAt.toIso8601String(),
        },
      'user_settings': userSettings
          .map(
            (s) => {
              'key': s.key,
              'value': s.value,
              'updated_at': s.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'user_preferences': userPreferences,
      'food_items': customFoodItems
          .map(
            (f) => {
              'id': f.id,
              'name': f.name,
              'name_hindi': f.nameHindi,
              'calories': f.calories,
              'protein_g': f.proteinG,
              'carbs_g': f.carbsG,
              'fat_g': f.fatG,
              'fiber_g': f.fiberG,
              'serving_size': f.servingSize,
              'serving_unit': f.servingUnit,
              'category': f.category,
              'is_custom': f.isCustom,
              'brand': f.brand,
              'region_pack': f.regionPack,
            },
          )
          .toList(),
      'food_logs': foodLogs
          .map(
            (f) => {
              'id': f.id,
              'food_item_id': f.foodItemId,
              'name': f.name,
              'calories': f.calories,
              'protein_g': f.proteinG,
              'carbs_g': f.carbsG,
              'fat_g': f.fatG,
              'serving_logged': f.servingLogged,
              'serving_unit': f.servingUnit,
              'meal_type': f.mealType,
              'logged_at': f.loggedAt.toIso8601String(),
              'is_synced': f.isSynced,
              'meal_group_id': f.mealGroupId,
              'uuid': f.uuid,
            },
          )
          .toList(),
      'meal_templates': mealTemplates
          .map(
            (t) => {
              'id': t.id,
              'name': t.name,
              'default_meal_type': t.defaultMealType,
              'created_at': t.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'meal_template_items': mealTemplateItems
          .map(
            (i) => {
              'id': i.id,
              'template_id': i.templateId,
              'name': i.name,
              'calories': i.calories,
              'protein_g': i.proteinG,
              'carbs_g': i.carbsG,
              'fat_g': i.fatG,
              'serving_logged': i.servingLogged,
              'serving_unit': i.servingUnit,
            },
          )
          .toList(),
      'custom_exercises': customExercises
          .map(
            (e) => {
              'id': e.id,
              'name': e.name,
              'muscle_groups': e.muscleGroups,
              'equipment': e.equipment,
              'difficulty': e.difficulty,
              'form_cues': e.formCues,
              'common_mistakes': e.commonMistakes,
              'youtube_id': e.youtubeId,
              'is_custom': e.isCustom,
            },
          )
          .toList(),
      'workout_sessions': workoutSessions
          .map(
            (s) => {
              'id': s.id,
              'name': s.name,
              'total_volume': s.totalVolume,
              'duration_seconds': s.durationSeconds,
              'estimated_calories': s.estimatedCalories,
              'completed_at': s.completedAt.toIso8601String(),
              'is_synced': s.isSynced,
              'uuid': s.uuid,
            },
          )
          .toList(),
      'workout_sets': workoutSets
          .map(
            (s) => {
              'id': s.id,
              'session_id': s.sessionId,
              'exercise_name': s.exerciseName,
              'weight': s.weight,
              'reps': s.reps,
              'set_number': s.setNumber,
              'is_pr': s.isPr,
              'rpe': s.rpe,
              'is_warmup': s.isWarmUp,
              'set_notes': s.setNotes,
              'uuid': s.uuid,
              'set_type': s.setType,
              'duration_seconds': s.durationSeconds,
              'distance_km': s.distanceKm,
              'incline_percentage': s.inclinePercentage,
            },
          )
          .toList(),
      'workout_routines': workoutRoutines
          .map(
            (r) => {
              'id': r.id,
              'name': r.name,
              'goal': r.goal,
              'notes': r.notes,
              'created_at': r.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'routine_days': routineDays
          .map(
            (d) => {
              'id': d.id,
              'routine_id': d.routineId,
              'day_of_week': d.dayOfWeek,
              'name': d.name,
              'is_rest_day': d.isRestDay,
            },
          )
          .toList(),
      'routine_exercises': routineExercises
          .map(
            (e) => {
              'id': e.id,
              'day_id': e.dayId,
              'exercise_name': e.exerciseName,
              'sets': e.sets,
              'reps_range': e.repsRange,
              'order_index': e.orderIndex,
            },
          )
          .toList(),
      'workout_drafts': workoutDrafts
          .map(
            (d) => {
              'id': d.id,
              'routine_name': d.routineName,
              'current_exercise_index': d.currentExerciseIndex,
              'current_set_index': d.currentSetIndex,
              'elapsed_seconds': d.elapsedSeconds,
              'logged_sets_json': d.loggedSetsJson,
              'updated_at': d.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'body_measurements': bodyMeasurements
          .map(
            (m) => {
              'id': m.id,
              'weight': m.weight,
              'waist': m.waist,
              'chest': m.chest,
              'arms': m.arms,
              'recorded_at': m.recordedAt.toIso8601String(),
              'is_synced': m.isSynced,
            },
          )
          .toList(),
    };
  }

  /// Deserializes a raw JSON map into a validated [BackupData] payload.
  /// Throws a [FormatException] if the backup version is unsupported or malformed.
  static BackupData fromJson(Map<String, dynamic> json) {
    final rawVersion = json['version'];
    if (rawVersion == null || rawVersion is! int) {
      throw const FormatException(
        'Invalid backup format: missing numeric "version" identifier.',
      );
    }

    if (rawVersion > currentVersion) {
      throw FormatException(
        'Unsupported backup format version $rawVersion (latest supported is $currentVersion).',
      );
    }

    if (rawVersion < 3) {
      throw FormatException(
        'Unsupported legacy backup format version $rawVersion.',
      );
    }

    final timestamp =
        json['timestamp'] as String? ?? DateTime.now().toIso8601String();
    final schemaVersion = (json['schema_version'] as num?)?.toInt() ?? 13;

    // User Profile
    UserProfile? userProfile;
    if (json['user_profile'] != null) {
      final p = json['user_profile'] as Map<String, dynamic>;
      userProfile = UserProfile(
        id: (p['id'] as num?)?.toInt() ?? 1,
        age: (p['age'] as num?)?.toInt() ?? 25,
        height: (p['height'] as num?)?.toDouble() ?? 170.0,
        weight: (p['weight'] as num?)?.toDouble() ?? 70.0,
        sex: p['sex'] as String? ?? 'male',
        activityLevel: p['activity_level'] as String? ?? 'moderate',
        goal: p['goal'] as String? ?? 'maintain',
        dietPreference: p['diet_preference'] as String? ?? 'balanced',
        calorieGoal: (p['calorie_goal'] as num?)?.toInt() ?? 2000,
        proteinGoal: (p['protein_goal'] as num?)?.toDouble() ?? 140.0,
        carbsGoal: (p['carbs_goal'] as num?)?.toDouble() ?? 220.0,
        fatGoal: (p['fat_goal'] as num?)?.toDouble() ?? 60.0,
        updatedAt: p['updated_at'] != null
            ? DateTime.parse(p['updated_at'] as String)
            : DateTime.now(),
      );
    }

    // User Settings
    final userSettings = <UserSetting>[];
    if (json['user_settings'] != null) {
      for (final raw in json['user_settings'] as List) {
        final s = raw as Map<String, dynamic>;
        userSettings.add(
          UserSetting(
            key: s['key'] as String,
            value: s['value'] as String,
            updatedAt: s['updated_at'] != null
                ? DateTime.parse(s['updated_at'] as String)
                : DateTime.now(),
          ),
        );
      }
    }

    // User Preferences
    final userPreferences = <String, dynamic>{};
    if (json['user_preferences'] != null) {
      userPreferences.addAll(json['user_preferences'] as Map<String, dynamic>);
    }

    // Custom Food Items
    final customFoodItems = <FoodItem>[];
    if (json['food_items'] != null) {
      for (final raw in json['food_items'] as List) {
        final f = raw as Map<String, dynamic>;
        customFoodItems.add(
          FoodItem(
            id: (f['id'] as num?)?.toInt() ?? 0,
            name: f['name'] as String,
            nameHindi: f['name_hindi'] as String?,
            calories: (f['calories'] as num).toInt(),
            proteinG: (f['protein_g'] as num).toDouble(),
            carbsG: (f['carbs_g'] as num).toDouble(),
            fatG: (f['fat_g'] as num).toDouble(),
            fiberG: (f['fiber_g'] as num?)?.toDouble(),
            servingSize: (f['serving_size'] as num?)?.toDouble() ?? 100.0,
            servingUnit: f['serving_unit'] as String? ?? 'g',
            category: f['category'] as String? ?? 'General',
            isCustom: f['is_custom'] as bool? ?? true,
            brand: f['brand'] as String?,
            regionPack: f['region_pack'] as String?,
          ),
        );
      }
    }

    // Food Logs
    final foodLogs = <FoodLog>[];
    if (json['food_logs'] != null) {
      for (final raw in json['food_logs'] as List) {
        final f = raw as Map<String, dynamic>;
        foodLogs.add(
          FoodLog(
            id: (f['id'] as num?)?.toInt() ?? 0,
            foodItemId: (f['food_item_id'] as num?)?.toInt(),
            name: f['name'] as String,
            calories: (f['calories'] as num).toInt(),
            proteinG: (f['protein_g'] as num).toDouble(),
            carbsG: (f['carbs_g'] as num).toDouble(),
            fatG: (f['fat_g'] as num).toDouble(),
            servingLogged: (f['serving_logged'] as num).toDouble(),
            servingUnit: f['serving_unit'] as String,
            mealType: f['meal_type'] as String,
            loggedAt: f['logged_at'] != null
                ? DateTime.parse(f['logged_at'] as String)
                : DateTime.now(),
            isSynced: f['is_synced'] as bool? ?? false,
            mealGroupId: f['meal_group_id'] as String?,
            uuid: f['uuid'] as String?,
          ),
        );
      }
    }

    // Meal Templates
    final mealTemplates = <MealTemplate>[];
    if (json['meal_templates'] != null) {
      for (final raw in json['meal_templates'] as List) {
        final t = raw as Map<String, dynamic>;
        mealTemplates.add(
          MealTemplate(
            id: (t['id'] as num).toInt(),
            name: t['name'] as String,
            defaultMealType: t['default_meal_type'] as String? ?? 'breakfast',
            createdAt: t['created_at'] != null
                ? DateTime.parse(t['created_at'] as String)
                : DateTime.now(),
          ),
        );
      }
    }

    // Meal Template Items
    final mealTemplateItems = <MealTemplateItem>[];
    if (json['meal_template_items'] != null) {
      for (final raw in json['meal_template_items'] as List) {
        final i = raw as Map<String, dynamic>;
        mealTemplateItems.add(
          MealTemplateItem(
            id: (i['id'] as num).toInt(),
            templateId: (i['template_id'] as num).toInt(),
            name: i['name'] as String,
            calories: (i['calories'] as num).toInt(),
            proteinG: (i['protein_g'] as num).toDouble(),
            carbsG: (i['carbs_g'] as num).toDouble(),
            fatG: (i['fat_g'] as num).toDouble(),
            servingLogged: (i['serving_logged'] as num).toDouble(),
            servingUnit: i['serving_unit'] as String,
          ),
        );
      }
    }

    // Custom Exercises
    final customExercises = <Exercise>[];
    if (json['custom_exercises'] != null) {
      for (final raw in json['custom_exercises'] as List) {
        final e = raw as Map<String, dynamic>;
        customExercises.add(
          Exercise(
            id: (e['id'] as num?)?.toInt() ?? 0,
            name: e['name'] as String,
            muscleGroups: e['muscle_groups'] as String,
            equipment: e['equipment'] as String,
            difficulty: e['difficulty'] as String,
            formCues: e['form_cues'] as String,
            commonMistakes: e['common_mistakes'] as String,
            youtubeId: e['youtube_id'] as String?,
            isCustom: e['is_custom'] as bool? ?? true,
          ),
        );
      }
    }

    // Workout Sessions
    final workoutSessions = <WorkoutSession>[];
    if (json['workout_sessions'] != null) {
      for (final raw in json['workout_sessions'] as List) {
        final s = raw as Map<String, dynamic>;
        workoutSessions.add(
          WorkoutSession(
            id: (s['id'] as num).toInt(),
            name: s['name'] as String,
            totalVolume: (s['total_volume'] as num).toDouble(),
            durationSeconds: (s['duration_seconds'] as num).toInt(),
            estimatedCalories: (s['estimated_calories'] as num).toInt(),
            completedAt: s['completed_at'] != null
                ? DateTime.parse(s['completed_at'] as String)
                : DateTime.now(),
            isSynced: s['is_synced'] as bool? ?? false,
            uuid: s['uuid'] as String?,
          ),
        );
      }
    }

    // Workout Sets
    final workoutSets = <WorkoutSet>[];
    if (json['workout_sets'] != null) {
      for (final raw in json['workout_sets'] as List) {
        final s = raw as Map<String, dynamic>;
        workoutSets.add(
          WorkoutSet(
            id: (s['id'] as num?)?.toInt() ?? 0,
            sessionId: (s['session_id'] as num).toInt(),
            exerciseName: s['exercise_name'] as String,
            weight: (s['weight'] as num).toDouble(),
            reps: (s['reps'] as num).toInt(),
            setNumber: (s['set_number'] as num).toInt(),
            isPr: s['is_pr'] as bool? ?? false,
            rpe: (s['rpe'] as num?)?.toInt(),
            isWarmUp: (s['is_warmup'] ?? s['is_warm_up']) as bool? ?? false,
            setNotes: s['set_notes'] as String?,
            uuid: s['uuid'] as String?,
            setType: s['set_type'] as String? ?? 'working',
            durationSeconds: (s['duration_seconds'] as num?)?.toInt(),
            distanceKm: (s['distance_km'] as num?)?.toDouble(),
            inclinePercentage: (s['incline_percentage'] as num?)?.toDouble(),
          ),
        );
      }
    }

    // Workout Routines
    final workoutRoutines = <WorkoutRoutine>[];
    if (json['workout_routines'] != null) {
      for (final raw in json['workout_routines'] as List) {
        final r = raw as Map<String, dynamic>;
        workoutRoutines.add(
          WorkoutRoutine(
            id: (r['id'] as num).toInt(),
            name: r['name'] as String,
            goal: r['goal'] as String,
            notes: r['notes'] as String?,
            createdAt: r['created_at'] != null
                ? DateTime.parse(r['created_at'] as String)
                : DateTime.now(),
          ),
        );
      }
    }

    // Routine Days
    final routineDays = <RoutineDay>[];
    if (json['routine_days'] != null) {
      for (final raw in json['routine_days'] as List) {
        final d = raw as Map<String, dynamic>;
        routineDays.add(
          RoutineDay(
            id: (d['id'] as num).toInt(),
            routineId: (d['routine_id'] as num).toInt(),
            dayOfWeek: (d['day_of_week'] as num).toInt(),
            name: d['name'] as String,
            isRestDay: d['is_rest_day'] as bool? ?? false,
          ),
        );
      }
    }

    // Routine Exercises
    final routineExercises = <RoutineExercise>[];
    if (json['routine_exercises'] != null) {
      for (final raw in json['routine_exercises'] as List) {
        final e = raw as Map<String, dynamic>;
        routineExercises.add(
          RoutineExercise(
            id: (e['id'] as num).toInt(),
            dayId: (e['day_id'] as num).toInt(),
            exerciseName: e['exercise_name'] as String,
            sets: (e['sets'] as num).toInt(),
            repsRange: e['reps_range'] as String,
            orderIndex: (e['order_index'] as num).toInt(),
          ),
        );
      }
    }

    // Workout Drafts
    final workoutDrafts = <WorkoutDraft>[];
    if (json['workout_drafts'] != null) {
      for (final raw in json['workout_drafts'] as List) {
        final d = raw as Map<String, dynamic>;
        workoutDrafts.add(
          WorkoutDraft(
            id: (d['id'] as num).toInt(),
            routineName: d['routine_name'] as String,
            currentExerciseIndex: (d['current_exercise_index'] as num).toInt(),
            currentSetIndex: (d['current_set_index'] as num).toInt(),
            elapsedSeconds: (d['elapsed_seconds'] as num).toInt(),
            loggedSetsJson: d['logged_sets_json'] as String,
            updatedAt: d['updated_at'] != null
                ? DateTime.parse(d['updated_at'] as String)
                : DateTime.now(),
          ),
        );
      }
    }

    // Body Measurements
    final bodyMeasurements = <BodyMeasurement>[];
    if (json['body_measurements'] != null) {
      for (final raw in json['body_measurements'] as List) {
        final m = raw as Map<String, dynamic>;
        bodyMeasurements.add(
          BodyMeasurement(
            id: (m['id'] as num?)?.toInt() ?? 0,
            weight: (m['weight'] as num?)?.toDouble(),
            waist: (m['waist'] as num?)?.toDouble(),
            chest: (m['chest'] as num?)?.toDouble(),
            arms: (m['arms'] as num?)?.toDouble(),
            recordedAt: m['recorded_at'] != null
                ? DateTime.parse(m['recorded_at'] as String)
                : DateTime.now(),
            isSynced: m['is_synced'] as bool? ?? false,
          ),
        );
      }
    }

    return BackupData(
      version: rawVersion,
      timestamp: timestamp,
      schemaVersion: schemaVersion,
      userProfile: userProfile,
      userSettings: userSettings,
      userPreferences: userPreferences,
      customFoodItems: customFoodItems,
      foodLogs: foodLogs,
      mealTemplates: mealTemplates,
      mealTemplateItems: mealTemplateItems,
      customExercises: customExercises,
      workoutSessions: workoutSessions,
      workoutSets: workoutSets,
      workoutRoutines: workoutRoutines,
      routineDays: routineDays,
      routineExercises: routineExercises,
      workoutDrafts: workoutDrafts,
      bodyMeasurements: bodyMeasurements,
    );
  }

  /// Atomically restores all database tables and persisted preferences.
  ///
  /// Pre-validates relationship graph, remaps custom catalog entity IDs to avoid
  /// replacing seeded target records, inserts records within one single [db.transaction],
  /// and updates SharedPreferences with automatic compensation/reversion on any failure.
  Future<void> restoreToDatabase(
    AppDatabase db, [
    SharedPreferences? prefs,
  ]) async {
    // 1. Prevalidation of relationship graph
    final validSessionIds = workoutSessions.map((s) => s.id).toSet();
    for (final s in workoutSets) {
      if (!validSessionIds.contains(s.sessionId)) {
        throw FormatException(
          'Backup validation failed: orphaned workout set (id: ${s.id}) references missing workout session (id: ${s.sessionId})',
        );
      }
    }

    final validRoutineIds = workoutRoutines.map((r) => r.id).toSet();
    for (final d in routineDays) {
      if (!validRoutineIds.contains(d.routineId)) {
        throw FormatException(
          'Backup validation failed: orphaned routine day (id: ${d.id}) references missing routine (id: ${d.routineId})',
        );
      }
    }

    final validDayIds = routineDays.map((d) => d.id).toSet();
    for (final e in routineExercises) {
      if (!validDayIds.contains(e.dayId)) {
        throw FormatException(
          'Backup validation failed: orphaned routine exercise (id: ${e.id}) references missing routine day (id: ${e.dayId})',
        );
      }
    }

    final validTemplateIds = mealTemplates.map((t) => t.id).toSet();
    for (final i in mealTemplateItems) {
      if (!validTemplateIds.contains(i.templateId)) {
        throw FormatException(
          'Backup validation failed: orphaned template item (id: ${i.id}) references missing template (id: ${i.templateId})',
        );
      }
    }

    // Capture previous preference values for compensation on failure.
    // `SharedPreferences` has no transaction API, so preferences are applied
    // before the database transaction and restored if it cannot commit.
    final oldPrefValues = <String, _PreferenceSnapshot>{};
    if (prefs != null && userPreferences.isNotEmpty) {
      for (final key in userPreferences.keys) {
        oldPrefValues[key] = _PreferenceSnapshot(
          existed: prefs.getKeys().contains(key),
          value: prefs.get(key),
        );
      }
      _validatePreferences(userPreferences);
    }

    try {
      // 2. Apply preferences first. A failed write prevents any database mutation.
      if (prefs != null && userPreferences.isNotEmpty) {
        await _applyPreferences(prefs, userPreferences);
      }

      // 3. Perform DB deletion and remapped insertion inside one single transaction.
      await db.transaction(() async {
        await db.delete(db.foodLogs).go();
        await db.delete(db.mealTemplateItems).go();
        await db.delete(db.mealTemplates).go();
        await db.delete(db.workoutSets).go();
        await db.delete(db.workoutSessions).go();
        await db.delete(db.routineExercises).go();
        await db.delete(db.routineDays).go();
        await db.delete(db.workoutRoutines).go();
        await db.delete(db.workoutDrafts).go();
        await db.delete(db.bodyMeasurements).go();
        await db.delete(db.userProfiles).go();
        await db.delete(db.userSettings).go();

        // Delete ONLY custom foods and custom exercises (preserve seeded rows!)
        await (db.delete(
          db.foodItems,
        )..where((f) => f.isCustom.equals(true))).go();
        await (db.delete(
          db.exercises,
        )..where((e) => e.isCustom.equals(true))).go();

        // Insert user profile
        if (userProfile != null) {
          await db
              .into(db.userProfiles)
              .insert(
                UserProfilesCompanion.insert(
                  age: Value(userProfile!.age),
                  height: Value(userProfile!.height),
                  weight: Value(userProfile!.weight),
                  sex: Value(userProfile!.sex),
                  activityLevel: Value(userProfile!.activityLevel),
                  goal: Value(userProfile!.goal),
                  dietPreference: Value(userProfile!.dietPreference),
                  calorieGoal: Value(userProfile!.calorieGoal),
                  proteinGoal: Value(userProfile!.proteinGoal),
                  carbsGoal: Value(userProfile!.carbsGoal),
                  fatGoal: Value(userProfile!.fatGoal),
                  updatedAt: Value(userProfile!.updatedAt),
                ),
              );
        }

        for (final s in userSettings) {
          await db
              .into(db.userSettings)
              .insert(
                UserSettingsCompanion.insert(
                  key: s.key,
                  value: s.value,
                  updatedAt: Value(s.updatedAt),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        // Remap custom foods: assign newly generated IDs without overwriting seeded foods
        final customFoodIdMap = <int, int>{};
        for (final f in customFoodItems) {
          final newId = await db
              .into(db.foodItems)
              .insert(
                FoodItemsCompanion.insert(
                  name: f.name,
                  nameHindi: Value(f.nameHindi),
                  calories: f.calories,
                  proteinG: f.proteinG,
                  carbsG: f.carbsG,
                  fatG: f.fatG,
                  fiberG: Value(f.fiberG),
                  servingSize: f.servingSize,
                  servingUnit: f.servingUnit,
                  category: f.category,
                  isCustom: const Value(true),
                  brand: Value(f.brand),
                  regionPack: Value(f.regionPack),
                ),
              );
          if (f.id > 0) {
            customFoodIdMap[f.id] = newId;
          }
        }

        // Insert food logs with remapped foodItemId
        final existingFoods = await db.select(db.foodItems).get();
        final existingFoodIds = existingFoods.map((f) => f.id).toSet();

        for (final f in foodLogs) {
          int? targetFoodItemId = f.foodItemId;
          if (targetFoodItemId != null) {
            if (customFoodIdMap.containsKey(targetFoodItemId)) {
              targetFoodItemId = customFoodIdMap[targetFoodItemId];
            } else if (!existingFoodIds.contains(targetFoodItemId)) {
              targetFoodItemId = null;
            }
          }

          await db
              .into(db.foodLogs)
              .insert(
                FoodLogsCompanion.insert(
                  foodItemId: Value(targetFoodItemId),
                  name: f.name,
                  calories: f.calories,
                  proteinG: f.proteinG,
                  carbsG: f.carbsG,
                  fatG: f.fatG,
                  servingLogged: f.servingLogged,
                  servingUnit: f.servingUnit,
                  mealType: f.mealType,
                  loggedAt: Value(f.loggedAt),
                  isSynced: Value(f.isSynced),
                  mealGroupId: Value(f.mealGroupId),
                  uuid: Value(f.uuid),
                ),
              );
        }

        // Remap custom exercises
        final customExerciseIdMap = <int, int>{};
        for (final e in customExercises) {
          final newId = await db
              .into(db.exercises)
              .insert(
                ExercisesCompanion.insert(
                  name: e.name,
                  muscleGroups: e.muscleGroups,
                  equipment: e.equipment,
                  difficulty: e.difficulty,
                  formCues: e.formCues,
                  commonMistakes: e.commonMistakes,
                  youtubeId: Value(e.youtubeId),
                  isCustom: const Value(true),
                ),
              );
          if (e.id > 0) {
            customExerciseIdMap[e.id] = newId;
          }
        }

        // Remap meal templates
        final templateIdMap = <int, int>{};
        for (final t in mealTemplates) {
          final newId = await db
              .into(db.mealTemplates)
              .insert(
                MealTemplatesCompanion.insert(
                  name: t.name,
                  defaultMealType: Value(t.defaultMealType),
                  createdAt: Value(t.createdAt),
                ),
              );
          templateIdMap[t.id] = newId;
        }

        for (final i in mealTemplateItems) {
          final targetTemplateId = templateIdMap[i.templateId] ?? i.templateId;
          await db
              .into(db.mealTemplateItems)
              .insert(
                MealTemplateItemsCompanion.insert(
                  templateId: targetTemplateId,
                  name: i.name,
                  calories: i.calories,
                  proteinG: i.proteinG,
                  carbsG: i.carbsG,
                  fatG: i.fatG,
                  servingLogged: i.servingLogged,
                  servingUnit: i.servingUnit,
                ),
              );
        }

        // Remap routines
        final routineIdMap = <int, int>{};
        for (final r in workoutRoutines) {
          final newId = await db
              .into(db.workoutRoutines)
              .insert(
                WorkoutRoutinesCompanion.insert(
                  name: r.name,
                  goal: r.goal,
                  notes: Value(r.notes),
                  createdAt: Value(r.createdAt),
                ),
              );
          routineIdMap[r.id] = newId;
        }

        final dayIdMap = <int, int>{};
        for (final d in routineDays) {
          final targetRoutineId = routineIdMap[d.routineId] ?? d.routineId;
          final newId = await db
              .into(db.routineDays)
              .insert(
                RoutineDaysCompanion.insert(
                  routineId: targetRoutineId,
                  dayOfWeek: d.dayOfWeek,
                  name: d.name,
                  isRestDay: Value(d.isRestDay),
                ),
              );
          dayIdMap[d.id] = newId;
        }

        for (final e in routineExercises) {
          final targetDayId = dayIdMap[e.dayId] ?? e.dayId;
          await db
              .into(db.routineExercises)
              .insert(
                RoutineExercisesCompanion.insert(
                  dayId: targetDayId,
                  exerciseName: e.exerciseName,
                  sets: e.sets,
                  repsRange: e.repsRange,
                  orderIndex: e.orderIndex,
                ),
              );
        }

        // Remap workout sessions and sets
        final sessionIdMap = <int, int>{};
        for (final s in workoutSessions) {
          final newId = await db
              .into(db.workoutSessions)
              .insert(
                WorkoutSessionsCompanion.insert(
                  name: s.name,
                  totalVolume: s.totalVolume,
                  durationSeconds: s.durationSeconds,
                  estimatedCalories: s.estimatedCalories,
                  completedAt: Value(s.completedAt),
                  isSynced: Value(s.isSynced),
                  uuid: Value(s.uuid),
                ),
              );
          sessionIdMap[s.id] = newId;
        }

        for (final s in workoutSets) {
          final targetSessionId = sessionIdMap[s.sessionId] ?? s.sessionId;
          await db
              .into(db.workoutSets)
              .insert(
                WorkoutSetsCompanion.insert(
                  sessionId: targetSessionId,
                  exerciseName: s.exerciseName,
                  weight: s.weight,
                  reps: s.reps,
                  setNumber: s.setNumber,
                  isPr: Value(s.isPr),
                  rpe: Value(s.rpe),
                  isWarmUp: Value(s.isWarmUp),
                  setNotes: Value(s.setNotes),
                  uuid: Value(s.uuid),
                  setType: Value(s.setType),
                  durationSeconds: Value(s.durationSeconds),
                  distanceKm: Value(s.distanceKm),
                  inclinePercentage: Value(s.inclinePercentage),
                ),
              );
        }

        for (final d in workoutDrafts) {
          await db
              .into(db.workoutDrafts)
              .insert(
                WorkoutDraftsCompanion.insert(
                  routineName: d.routineName,
                  currentExerciseIndex: d.currentExerciseIndex,
                  currentSetIndex: d.currentSetIndex,
                  elapsedSeconds: d.elapsedSeconds,
                  loggedSetsJson: d.loggedSetsJson,
                  updatedAt: Value(d.updatedAt),
                ),
              );
        }

        for (final m in bodyMeasurements) {
          await db
              .into(db.bodyMeasurements)
              .insert(
                BodyMeasurementsCompanion.insert(
                  weight: Value(m.weight),
                  waist: Value(m.waist),
                  chest: Value(m.chest),
                  arms: Value(m.arms),
                  recordedAt: Value(m.recordedAt),
                  isSynced: Value(m.isSynced),
                ),
              );
        }
      });
    } catch (e) {
      // Revert every managed preference, including keys created by this restore.
      if (prefs != null && oldPrefValues.isNotEmpty) {
        await _restorePreferences(prefs, oldPrefValues);
      }
      rethrow;
    }
  }

  static void _validatePreferences(Map<String, dynamic> preferences) {
    for (final entry in preferences.entries) {
      final value = entry.value;
      if (value is bool || value is int || value is double || value is String) {
        continue;
      }
      if (value is List && value.every((item) => item is String)) continue;
      throw FormatException(
        'Backup validation failed: unsupported preference value for "${entry.key}".',
      );
    }
  }

  static Future<void> _applyPreferences(
    SharedPreferences prefs,
    Map<String, dynamic> preferences,
  ) async {
    for (final entry in preferences.entries) {
      final wrote = await _writePreference(prefs, entry.key, entry.value);
      if (!wrote) {
        throw StateError('Failed to restore preference "${entry.key}".');
      }
    }
  }

  static Future<void> _restorePreferences(
    SharedPreferences prefs,
    Map<String, _PreferenceSnapshot> snapshots,
  ) async {
    for (final entry in snapshots.entries) {
      final restored = entry.value.existed
          ? await _writePreference(prefs, entry.key, entry.value.value)
          : await prefs.remove(entry.key);
      if (!restored) {
        throw StateError('Failed to roll back preference "${entry.key}".');
      }
    }
  }

  static Future<bool> _writePreference(
    SharedPreferences prefs,
    String key,
    dynamic value,
  ) {
    if (value is bool) return prefs.setBool(key, value);
    if (value is int) return prefs.setInt(key, value);
    if (value is double) return prefs.setDouble(key, value);
    if (value is String) return prefs.setString(key, value);
    if (value is List) return prefs.setStringList(key, value.cast<String>());
    throw StateError('Unsupported preference value for "$key".');
  }
}

class _PreferenceSnapshot {
  final bool existed;
  final dynamic value;

  const _PreferenceSnapshot({required this.existed, required this.value});
}
