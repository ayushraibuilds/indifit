import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../data/database/app_database.dart';

/// Canonical Versioned Backup Schema (Version 6).
///
/// Provides a unified, production-safe DTO and serializer for all user-owned
/// database records and persisted application preferences.
/// Shared identically by manual backup/export and automated background backups.
class BackupData {
  static const int currentVersion = 6;

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
  final List<DailyHydration> dailyHydrations;
  final List<HealthProvenance> healthProvenances;
  final List<AchievementUnlock> achievementUnlocks;

  // B01 durable training-plan graph. These are deliberately individual typed
  // collections instead of a JSON blob so the restore path can validate every
  // FK, enum, civil date and timezone before it mutates the database.
  final List<Program> programs;
  final List<ProgramVersion> programVersions;
  final List<ProgramBlock> programBlocks;
  final List<ProgramWeek> programWeeks;
  final List<SessionTemplate> sessionTemplates;
  final List<ExercisePrescription> exercisePrescriptions;
  final List<ScheduledSessionOccurrence> scheduledSessionOccurrences;
  final List<OccurrenceEvent> occurrenceEvents;
  final TrainingPlanSetting? trainingPlanSettings;
  final List<EquipmentProfile> equipmentProfiles;
  final List<EquipmentProfileItem> equipmentProfileItems;
  final List<TravelContext> travelContexts;
  final List<TravelContextOccurrence> travelContextOccurrences;
  final List<ExerciseUserPreference> exerciseUserPreferences;
  final List<ExerciseSetupValue> exerciseSetupValues;
  final List<ExercisePersonalCue> exercisePersonalCues;
  final List<LegacyRoutineProgramMapping> legacyRoutineProgramMappings;

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
    required this.dailyHydrations,
    required this.healthProvenances,
    required this.achievementUnlocks,
    this.programs = const [],
    this.programVersions = const [],
    this.programBlocks = const [],
    this.programWeeks = const [],
    this.sessionTemplates = const [],
    this.exercisePrescriptions = const [],
    this.scheduledSessionOccurrences = const [],
    this.occurrenceEvents = const [],
    this.trainingPlanSettings,
    this.equipmentProfiles = const [],
    this.equipmentProfileItems = const [],
    this.travelContexts = const [],
    this.travelContextOccurrences = const [],
    this.exerciseUserPreferences = const [],
    this.exerciseSetupValues = const [],
    this.exercisePersonalCues = const [],
    this.legacyRoutineProgramMappings = const [],
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
    final dailyHydrations = await db.select(db.dailyHydrations).get();
    final healthProvenances = await db.select(db.healthProvenances).get();
    final achievementUnlocks = await db.select(db.achievementUnlocks).get();
    final programs = await db.select(db.programs).get();
    final programVersions = await db.select(db.programVersions).get();
    final programBlocks = await db.select(db.programBlocks).get();
    final programWeeks = await db.select(db.programWeeks).get();
    final sessionTemplates = await db.select(db.sessionTemplates).get();
    final exercisePrescriptions = await db
        .select(db.exercisePrescriptions)
        .get();
    final scheduledSessionOccurrences = await db
        .select(db.scheduledSessionOccurrences)
        .get();
    final occurrenceEvents = await db.select(db.occurrenceEvents).get();
    final trainingPlanSettings = await db
        .select(db.trainingPlanSettings)
        .getSingleOrNull();
    final equipmentProfiles = await db.select(db.equipmentProfiles).get();
    final equipmentProfileItems = await db
        .select(db.equipmentProfileItems)
        .get();
    final travelContexts = await db.select(db.travelContexts).get();
    final travelContextOccurrences = await db
        .select(db.travelContextOccurrences)
        .get();
    final exerciseUserPreferences = await db
        .select(db.exerciseUserPreferences)
        .get();
    final exerciseSetupValues = await db.select(db.exerciseSetupValues).get();
    final exercisePersonalCues = await db.select(db.exercisePersonalCues).get();
    final legacyRoutineProgramMappings = await db
        .select(db.legacyRoutineProgramMappings)
        .get();

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
        'pref_remind_workout',
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
      dailyHydrations: dailyHydrations,
      healthProvenances: healthProvenances,
      achievementUnlocks: achievementUnlocks,
      programs: programs,
      programVersions: programVersions,
      programBlocks: programBlocks,
      programWeeks: programWeeks,
      sessionTemplates: sessionTemplates,
      exercisePrescriptions: exercisePrescriptions,
      scheduledSessionOccurrences: scheduledSessionOccurrences,
      occurrenceEvents: occurrenceEvents,
      trainingPlanSettings: trainingPlanSettings,
      equipmentProfiles: equipmentProfiles,
      equipmentProfileItems: equipmentProfileItems,
      travelContexts: travelContexts,
      travelContextOccurrences: travelContextOccurrences,
      exerciseUserPreferences: exerciseUserPreferences,
      exerciseSetupValues: exerciseSetupValues,
      exercisePersonalCues: exercisePersonalCues,
      legacyRoutineProgramMappings: legacyRoutineProgramMappings,
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
          'name': userProfile!.name,
          'equipment_access': userProfile!.equipmentAccess,
          'injuries_limitations': userProfile!.injuriesLimitations,
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
              'stable_id': e.stableId,
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
              'scheduled_occurrence_id': s.scheduledOccurrenceId,
              'execution_snapshot_json': s.executionSnapshotJson,
              'execution_timezone_id': s.executionTimezoneId,
              'completion_kind': s.completionKind,
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
              'exercise_id': s.exerciseId,
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
              'scheduled_occurrence_id': d.scheduledOccurrenceId,
              'execution_snapshot_json': d.executionSnapshotJson,
              'draft_schema_version': d.draftSchemaVersion,
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
      'daily_hydrations': dailyHydrations
          .map(
            (h) => {
              'id': h.id,
              'date_string': h.dateString,
              'total_ml': h.totalMl,
              'goal_ml': h.goalMl,
              'updated_at': h.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'health_provenances': healthProvenances
          .map(
            (p) => {
              'id': p.id,
              'provider': p.provider,
              'external_id': p.externalId,
              'source_name': p.sourceName,
              'imported_at': p.importedAt.toIso8601String(),
              'local_session_id': p.localSessionId,
              'fingerprint': p.fingerprint,
            },
          )
          .toList(),
      'achievement_unlocks': achievementUnlocks
          .map(
            (a) => {
              'id': a.id,
              'achievement_id': a.achievementId,
              'unlocked_at': a.unlockedAt.toIso8601String(),
            },
          )
          .toList(),
      'programs': programs.map((item) => item.toJson()).toList(),
      'program_versions': programVersions.map((item) => item.toJson()).toList(),
      'program_blocks': programBlocks.map((item) => item.toJson()).toList(),
      'program_weeks': programWeeks.map((item) => item.toJson()).toList(),
      'session_templates': sessionTemplates
          .map((item) => item.toJson())
          .toList(),
      'exercise_prescriptions': exercisePrescriptions
          .map((item) => item.toJson())
          .toList(),
      'scheduled_session_occurrences': scheduledSessionOccurrences
          .map((item) => item.toJson())
          .toList(),
      'occurrence_events': occurrenceEvents
          .map((item) => item.toJson())
          .toList(),
      'training_plan_settings': trainingPlanSettings == null
          ? const <Map<String, dynamic>>[]
          : [trainingPlanSettings!.toJson()],
      'equipment_profiles': equipmentProfiles
          .map((item) => item.toJson())
          .toList(),
      'equipment_profile_items': equipmentProfileItems
          .map((item) => item.toJson())
          .toList(),
      'travel_contexts': travelContexts.map((item) => item.toJson()).toList(),
      'travel_context_occurrences': travelContextOccurrences
          .map((item) => item.toJson())
          .toList(),
      'exercise_user_preferences': exerciseUserPreferences
          .map((item) => item.toJson())
          .toList(),
      'exercise_setup_values': exerciseSetupValues
          .map((item) => item.toJson())
          .toList(),
      'exercise_personal_cues': exercisePersonalCues
          .map((item) => item.toJson())
          .toList(),
      'legacy_routine_program_mappings': legacyRoutineProgramMappings
          .map((item) => item.toJson())
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
    final isB01Payload = rawVersion >= 6;

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
        name: p['name'] as String? ?? '',
        equipmentAccess: p['equipment_access'] as String? ?? 'full_gym',
        injuriesLimitations: p['injuries_limitations'] as String? ?? '',
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
      userPreferences.addAll(
        Map<String, dynamic>.from(json['user_preferences'] as Map),
      );
      // v5 exported the historical camel-case key while the notification
      // service now reads the snake-case key. Keep the legacy key intact for
      // round-trip fidelity and restore its canonical equivalent as well.
      if (userPreferences.containsKey('prefRemindWorkout') &&
          !userPreferences.containsKey('pref_remind_workout')) {
        userPreferences['pref_remind_workout'] =
            userPreferences['prefRemindWorkout'];
      }
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
            stableId: e['stable_id'] as String?,
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
            scheduledOccurrenceId: s['scheduled_occurrence_id'] as String?,
            executionSnapshotJson: s['execution_snapshot_json'] as String?,
            executionTimezoneId: s['execution_timezone_id'] as String?,
            completionKind: s['completion_kind'] as String?,
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
            exerciseId: s['exercise_id'] as String?,
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
            scheduledOccurrenceId: d['scheduled_occurrence_id'] as String?,
            executionSnapshotJson: d['execution_snapshot_json'] as String?,
            draftSchemaVersion:
                (d['draft_schema_version'] as num?)?.toInt() ?? 1,
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

    // Daily Hydrations
    final dailyHydrations = <DailyHydration>[];
    if (json['daily_hydrations'] != null) {
      for (final raw in json['daily_hydrations'] as List) {
        final h = raw as Map<String, dynamic>;
        dailyHydrations.add(
          DailyHydration(
            id: (h['id'] as num?)?.toInt() ?? 0,
            dateString: h['date_string'] as String,
            totalMl: (h['total_ml'] as num).toInt(),
            goalMl: (h['goal_ml'] as num).toInt(),
            updatedAt: h['updated_at'] != null
                ? DateTime.parse(h['updated_at'] as String)
                : DateTime.now(),
          ),
        );
      }
    }

    // Health Provenances
    final healthProvenances = <HealthProvenance>[];
    if (json['health_provenances'] != null) {
      for (final raw in json['health_provenances'] as List) {
        final p = raw as Map<String, dynamic>;
        healthProvenances.add(
          HealthProvenance(
            id: (p['id'] as num?)?.toInt() ?? 0,
            provider: p['provider'] as String,
            externalId: p['external_id'] as String?,
            sourceName: p['source_name'] as String? ?? 'External Provider',
            importedAt: p['imported_at'] != null
                ? DateTime.parse(p['imported_at'] as String)
                : DateTime.now(),
            localSessionId: (p['local_session_id'] as num?)?.toInt(),
            fingerprint: p['fingerprint'] as String,
          ),
        );
      }
    }

    // Achievement Unlocks
    final achievementUnlocks = <AchievementUnlock>[];
    if (json['achievement_unlocks'] != null) {
      for (final raw in json['achievement_unlocks'] as List) {
        final a = raw as Map<String, dynamic>;
        achievementUnlocks.add(
          AchievementUnlock(
            id: (a['id'] as num?)?.toInt() ?? 0,
            achievementId: a['achievement_id'] as String,
            unlockedAt: a['unlocked_at'] != null
                ? DateTime.parse(a['unlocked_at'] as String)
                : DateTime.now(),
          ),
        );
      }
    }

    final programs = isB01Payload
        ? _readB01List(json, 'programs', Program.fromJson)
        : const <Program>[];
    final programVersions = isB01Payload
        ? _readB01List(json, 'program_versions', ProgramVersion.fromJson)
        : const <ProgramVersion>[];
    final programBlocks = isB01Payload
        ? _readB01List(json, 'program_blocks', ProgramBlock.fromJson)
        : const <ProgramBlock>[];
    final programWeeks = isB01Payload
        ? _readB01List(json, 'program_weeks', ProgramWeek.fromJson)
        : const <ProgramWeek>[];
    final sessionTemplates = isB01Payload
        ? _readB01List(json, 'session_templates', SessionTemplate.fromJson)
        : const <SessionTemplate>[];
    final exercisePrescriptions = isB01Payload
        ? _readB01List(
            json,
            'exercise_prescriptions',
            ExercisePrescription.fromJson,
          )
        : const <ExercisePrescription>[];
    final scheduledSessionOccurrences = isB01Payload
        ? _readB01List(
            json,
            'scheduled_session_occurrences',
            ScheduledSessionOccurrence.fromJson,
          )
        : const <ScheduledSessionOccurrence>[];
    final occurrenceEvents = isB01Payload
        ? _readB01List(json, 'occurrence_events', OccurrenceEvent.fromJson)
        : const <OccurrenceEvent>[];
    final settings = isB01Payload
        ? _readB01List(
            json,
            'training_plan_settings',
            TrainingPlanSetting.fromJson,
          )
        : const <TrainingPlanSetting>[];
    if (settings.length > 1) {
      throw const FormatException(
        'Backup validation failed: multiple training-plan settings rows.',
      );
    }
    final equipmentProfiles = isB01Payload
        ? _readB01List(json, 'equipment_profiles', EquipmentProfile.fromJson)
        : const <EquipmentProfile>[];
    final equipmentProfileItems = isB01Payload
        ? _readB01List(
            json,
            'equipment_profile_items',
            EquipmentProfileItem.fromJson,
          )
        : const <EquipmentProfileItem>[];
    final travelContexts = isB01Payload
        ? _readB01List(json, 'travel_contexts', TravelContext.fromJson)
        : const <TravelContext>[];
    final travelContextOccurrences = isB01Payload
        ? _readB01List(
            json,
            'travel_context_occurrences',
            TravelContextOccurrence.fromJson,
          )
        : const <TravelContextOccurrence>[];
    final exerciseUserPreferences = isB01Payload
        ? _readB01List(
            json,
            'exercise_user_preferences',
            ExerciseUserPreference.fromJson,
          )
        : const <ExerciseUserPreference>[];
    final exerciseSetupValues = isB01Payload
        ? _readB01List(
            json,
            'exercise_setup_values',
            ExerciseSetupValue.fromJson,
          )
        : const <ExerciseSetupValue>[];
    final exercisePersonalCues = isB01Payload
        ? _readB01List(
            json,
            'exercise_personal_cues',
            ExercisePersonalCue.fromJson,
          )
        : const <ExercisePersonalCue>[];
    final legacyRoutineProgramMappings = isB01Payload
        ? _readB01List(
            json,
            'legacy_routine_program_mappings',
            LegacyRoutineProgramMapping.fromJson,
          )
        : const <LegacyRoutineProgramMapping>[];
    if (isB01Payload && settings.isEmpty) {
      throw const FormatException(
        'Backup validation failed: missing training-plan settings row.',
      );
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
      dailyHydrations: dailyHydrations,
      healthProvenances: healthProvenances,
      achievementUnlocks: achievementUnlocks,
      programs: programs,
      programVersions: programVersions,
      programBlocks: programBlocks,
      programWeeks: programWeeks,
      sessionTemplates: sessionTemplates,
      exercisePrescriptions: exercisePrescriptions,
      scheduledSessionOccurrences: scheduledSessionOccurrences,
      occurrenceEvents: occurrenceEvents,
      trainingPlanSettings: settings.isEmpty ? null : settings.single,
      equipmentProfiles: equipmentProfiles,
      equipmentProfileItems: equipmentProfileItems,
      travelContexts: travelContexts,
      travelContextOccurrences: travelContextOccurrences,
      exerciseUserPreferences: exerciseUserPreferences,
      exerciseSetupValues: exerciseSetupValues,
      exercisePersonalCues: exercisePersonalCues,
      legacyRoutineProgramMappings: legacyRoutineProgramMappings,
    );
  }

  static List<T> _readB01List<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) decoder,
  ) {
    final raw = json[key];
    if (raw == null) return List<T>.empty(growable: false);
    if (raw is! List) {
      throw FormatException(
        'Invalid B01 backup field "$key": expected a list.',
      );
    }
    try {
      return raw
          .map(
            (entry) =>
                decoder(Map<String, dynamic>.from(_requireMap(entry, key))),
          )
          .toList(growable: false);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid B01 backup field "$key": $error');
    }
  }

  static Map<dynamic, dynamic> _requireMap(Object? value, String key) {
    if (value is Map) return value;
    throw FormatException(
      'Invalid B01 backup field "$key": expected an object.',
    );
  }

  void _validateB01Graph(Set<String> seededExerciseStableIds) {
    if (version < 6) return;

    final customStableIds = <String>{};
    for (final exercise in customExercises) {
      final stableId = exercise.stableId;
      if (stableId == null || stableId.trim().isEmpty) {
        throw FormatException(
          'Backup validation failed: custom exercise ${exercise.id} has no stable ID.',
        );
      }
      if (!customStableIds.add(stableId)) {
        throw FormatException(
          'Backup validation failed: duplicate custom exercise stable ID "$stableId".',
        );
      }
      if (seededExerciseStableIds.contains(stableId)) {
        throw FormatException(
          'Backup validation failed: custom exercise stable ID "$stableId" conflicts with the bundled catalogue.',
        );
      }
    }
    final knownExerciseIds = {...seededExerciseStableIds, ...customStableIds};

    final programIds = _uniqueIds('program', programs, (row) => row.id);
    final versionIds = _uniqueIds(
      'program version',
      programVersions,
      (row) => row.id,
    );
    _uniqueIds('program block', programBlocks, (row) => row.id);
    final weekIds = _uniqueIds('program week', programWeeks, (row) => row.id);
    final templateIds = _uniqueIds(
      'session template',
      sessionTemplates,
      (row) => row.id,
    );
    _uniqueIds('exercise prescription', exercisePrescriptions, (row) => row.id);
    final occurrenceIds = _uniqueIds(
      'scheduled occurrence',
      scheduledSessionOccurrences,
      (row) => row.id,
    );
    _uniqueIds('occurrence event', occurrenceEvents, (row) => row.id);
    final profileIds = _uniqueIds(
      'equipment profile',
      equipmentProfiles,
      (row) => row.id,
    );
    _uniqueIds(
      'equipment profile item',
      equipmentProfileItems,
      (row) => row.id,
    );
    final travelIds = _uniqueIds(
      'travel context',
      travelContexts,
      (row) => row.id,
    );
    final preferenceIds = _uniqueIds(
      'exercise user preference',
      exerciseUserPreferences,
      (row) => row.id,
    );
    _uniqueIds('exercise setup value', exerciseSetupValues, (row) => row.id);
    _uniqueIds('exercise personal cue', exercisePersonalCues, (row) => row.id);

    final versionsById = {for (final row in programVersions) row.id: row};
    for (final row in programVersions) {
      _require(
        programIds.contains(row.programId),
        'program version ${row.id} references missing program ${row.programId}',
      );
      _require(
        const {'draft', 'published', 'archived'}.contains(row.status),
        'program version ${row.id} has invalid status ${row.status}',
      );
      _require(
        const {'user', 'legacyImport'}.contains(row.origin),
        'program version ${row.id} has invalid origin ${row.origin}',
      );
      if (row.sourceVersionId != null) {
        _require(
          versionIds.contains(row.sourceVersionId),
          'program version ${row.id} references missing source version ${row.sourceVersionId}',
        );
        _require(
          row.sourceVersionId != row.id,
          'program version ${row.id} cannot source itself',
        );
      }
    }
    _assertAcyclic(
      versionsById.keys,
      (id) => versionsById[id]!.sourceVersionId,
      'program-version source',
    );
    _uniqueKeys(
      'program version number',
      programVersions,
      (row) => '${row.programId}\u0000${row.versionNumber}',
    );

    final blocksById = {for (final row in programBlocks) row.id: row};
    for (final row in programBlocks) {
      _require(
        versionIds.contains(row.programVersionId),
        'program block ${row.id} references missing version ${row.programVersionId}',
      );
    }
    _uniqueKeys(
      'program block ordinal',
      programBlocks,
      (row) => '${row.programVersionId}\u0000${row.ordinal}',
    );

    final weeksById = {for (final row in programWeeks) row.id: row};
    for (final row in programWeeks) {
      final block = blocksById[row.programBlockId];
      _require(
        block != null,
        'program week ${row.id} references missing block ${row.programBlockId}',
      );
      _require(
        block!.programVersionId == row.programVersionId,
        'program week ${row.id} does not belong to its declared version',
      );
    }
    _uniqueKeys(
      'program week block ordinal',
      programWeeks,
      (row) => '${row.programBlockId}\u0000${row.ordinalInBlock}',
    );
    _uniqueKeys(
      'program week ordinal',
      programWeeks,
      (row) => '${row.programVersionId}\u0000${row.programWeekOrdinal}',
    );

    final templatesById = {for (final row in sessionTemplates) row.id: row};
    for (final row in sessionTemplates) {
      _require(
        weekIds.contains(row.programWeekId),
        'session template ${row.id} references missing week ${row.programWeekId}',
      );
      _require(
        row.plannedWeekday >= 1 && row.plannedWeekday <= 7,
        'session template ${row.id} has invalid planned weekday',
      );
      _require(
        row.plannedStartMinute == null ||
            (row.plannedStartMinute! >= 0 && row.plannedStartMinute! <= 1439),
        'session template ${row.id} has invalid planned start minute',
      );
    }
    _uniqueKeys(
      'session template ordinal',
      sessionTemplates,
      (row) => '${row.programWeekId}\u0000${row.ordinal}',
    );

    for (final row in exercisePrescriptions) {
      _require(
        templateIds.contains(row.sessionTemplateId),
        'exercise prescription ${row.id} references missing template ${row.sessionTemplateId}',
      );
      _validateExerciseReference(
        row.exerciseId,
        knownExerciseIds,
        'exercise prescription ${row.id}',
      );
    }
    _uniqueKeys(
      'exercise prescription ordinal',
      exercisePrescriptions,
      (row) => '${row.sessionTemplateId}\u0000${row.ordinal}',
    );

    final occurrencesById = {
      for (final row in scheduledSessionOccurrences) row.id: row,
    };
    for (final row in scheduledSessionOccurrences) {
      final template = templatesById[row.sessionTemplateId];
      _require(
        versionIds.contains(row.programVersionId),
        'occurrence ${row.id} references missing version ${row.programVersionId}',
      );
      _require(
        template != null,
        'occurrence ${row.id} references missing template ${row.sessionTemplateId}',
      );
      final week = template == null ? null : weeksById[template.programWeekId];
      _require(
        week != null && week.programVersionId == row.programVersionId,
        'occurrence ${row.id} template does not belong to its declared version',
      );
      _require(
        week != null && week.programWeekOrdinal == row.programWeekOrdinal,
        'occurrence ${row.id} has an inconsistent program week ordinal',
      );
      _require(
        week != null &&
            blocksById[week.programBlockId]!.ordinal == row.programBlockOrdinal,
        'occurrence ${row.id} has an inconsistent program block ordinal',
      );
      _require(
        template != null && template.ordinal == row.sessionOrdinal,
        'occurrence ${row.id} has an inconsistent session ordinal',
      );
      _require(
        const {
          'planned',
          'rescheduled',
          'inProgress',
          'completed',
          'partiallyCompleted',
          'skipped',
          'cancelled',
        }.contains(row.status),
        'occurrence ${row.id} has invalid status ${row.status}',
      );
      _require(
        const {
          'pending',
          'satisfied',
          'bypassed',
        }.contains(row.progressionDisposition),
        'occurrence ${row.id} has invalid progression disposition',
      );
      _require(
        row.skipMode == null ||
            const {'keepPending', 'advance'}.contains(row.skipMode),
        'occurrence ${row.id} has invalid skip mode',
      );
      _require(
        row.repeatPurpose == null ||
            const {'makeUp', 'extra'}.contains(row.repeatPurpose),
        'occurrence ${row.id} has invalid repeat purpose',
      );
      _validateLocalDateTimezone(
        row.originalLocalDate,
        row.originalTimezoneId,
        'occurrence ${row.id} original placement',
      );
      _validateLocalDateTimezone(
        row.effectiveLocalDate,
        row.effectiveTimezoneId,
        'occurrence ${row.id} effective placement',
      );
      if (row.repeatedFromOccurrenceId != null) {
        _require(
          occurrenceIds.contains(row.repeatedFromOccurrenceId),
          'occurrence ${row.id} references missing repeated occurrence ${row.repeatedFromOccurrenceId}',
        );
        _require(
          row.repeatedFromOccurrenceId != row.id,
          'occurrence ${row.id} cannot repeat itself',
        );
      }
    }
    _assertAcyclic(
      occurrencesById.keys,
      (id) => occurrencesById[id]!.repeatedFromOccurrenceId,
      'repeated-occurrence',
    );
    _uniqueKeys(
      'occurrence repeat ordinal',
      scheduledSessionOccurrences,
      (row) =>
          '${row.programVersionId}\u0000${row.programWeekOrdinal}\u0000${row.sessionTemplateId}\u0000${row.repeatOrdinal}',
    );

    _uniqueKeys(
      'occurrence event command',
      occurrenceEvents,
      (row) => '${row.occurrenceId}\u0000${row.commandId}',
    );
    for (final row in occurrenceEvents) {
      _require(
        occurrenceIds.contains(row.occurrenceId),
        'occurrence event ${row.id} references missing occurrence ${row.occurrenceId}',
      );
      _require(
        row.commandId.trim().isNotEmpty,
        'occurrence event ${row.id} has an empty command ID',
      );
      _validateOptionalOccurrenceStatus(
        row.fromStatus,
        'event ${row.id} from status',
      );
      _validateOptionalOccurrenceStatus(
        row.toStatus,
        'event ${row.id} to status',
      );
      _validateOptionalLocalDateTimezone(
        row.beforeLocalDate,
        row.beforeTimezoneId,
        'event ${row.id} before placement',
      );
      _validateOptionalLocalDateTimezone(
        row.afterLocalDate,
        row.afterTimezoneId,
        'event ${row.id} after placement',
      );
    }

    for (final row in equipmentProfileItems) {
      _require(
        profileIds.contains(row.equipmentProfileId),
        'equipment profile item ${row.id} references missing profile ${row.equipmentProfileId}',
      );
    }
    _uniqueKeys(
      'equipment profile item code',
      equipmentProfileItems,
      (row) => '${row.equipmentProfileId}\u0000${row.equipmentCode}',
    );

    for (final row in travelContexts) {
      _require(
        profileIds.contains(row.equipmentProfileId),
        'travel context ${row.id} references missing profile ${row.equipmentProfileId}',
      );
      _require(
        const {'active', 'cancelled', 'ended'}.contains(row.status),
        'travel context ${row.id} has invalid status ${row.status}',
      );
      _validateLocalDateTimezone(
        row.startLocalDate,
        row.timezoneId,
        'travel context ${row.id} start',
      );
      _validateLocalDateTimezone(
        row.endLocalDate,
        row.timezoneId,
        'travel context ${row.id} end',
      );
      _require(
        row.startLocalDate.compareTo(row.endLocalDate) <= 0,
        'travel context ${row.id} ends before it starts',
      );
    }
    final travelMemberships = <String>{};
    for (final row in travelContextOccurrences) {
      _require(
        travelIds.contains(row.travelContextId),
        'travel membership references missing travel context ${row.travelContextId}',
      );
      _require(
        occurrenceIds.contains(row.occurrenceId),
        'travel membership references missing occurrence ${row.occurrenceId}',
      );
      _require(
        travelMemberships.add(
          '${row.travelContextId}\u0000${row.occurrenceId}',
        ),
        'duplicate travel membership for ${row.travelContextId}/${row.occurrenceId}',
      );
    }

    _uniqueKeys(
      'exercise preference identity key',
      exerciseUserPreferences,
      (row) => row.identityKey,
    );
    for (final row in exerciseUserPreferences) {
      _validateExerciseReference(
        row.exerciseId,
        knownExerciseIds,
        'exercise preference ${row.id}',
      );
    }
    for (final row in exerciseSetupValues) {
      _require(
        preferenceIds.contains(row.exerciseUserPreferenceId),
        'exercise setup ${row.id} references missing preference ${row.exerciseUserPreferenceId}',
      );
    }
    _uniqueKeys(
      'exercise setup ordinal',
      exerciseSetupValues,
      (row) => '${row.exerciseUserPreferenceId}\u0000${row.ordinal}',
    );
    for (final row in exercisePersonalCues) {
      _require(
        preferenceIds.contains(row.exerciseUserPreferenceId),
        'personal cue ${row.id} references missing preference ${row.exerciseUserPreferenceId}',
      );
    }
    _uniqueKeys(
      'personal cue ordinal',
      exercisePersonalCues,
      (row) => '${row.exerciseUserPreferenceId}\u0000${row.ordinal}',
    );

    final settings = trainingPlanSettings;
    if (settings != null) {
      _require(settings.id == 1, 'training-plan settings must have ID 1');
      if (settings.activeProgramVersionId != null) {
        final active = versionsById[settings.activeProgramVersionId];
        _require(
          active != null && active.status == 'published',
          'active training-plan setting must reference a published version',
        );
      }
      if (settings.defaultEquipmentProfileId != null) {
        _require(
          profileIds.contains(settings.defaultEquipmentProfileId),
          'training-plan settings references missing default equipment profile',
        );
      }
      _validateOptionalLocalDateTimezone(
        settings.activeSinceLocalDate,
        settings.activeSinceTimezoneId,
        'training-plan activation',
      );
    }

    final routineIds = workoutRoutines.map((row) => row.id).toSet();
    final mappedPrograms = <String>{};
    final mappedVersions = <String>{};
    final mappedRoutines = <int>{};
    for (final row in legacyRoutineProgramMappings) {
      _require(
        routineIds.contains(row.legacyRoutineId),
        'legacy mapping references missing routine ${row.legacyRoutineId}',
      );
      _require(
        programIds.contains(row.programId),
        'legacy mapping references missing program ${row.programId}',
      );
      _require(
        versionIds.contains(row.programVersionId),
        'legacy mapping references missing version ${row.programVersionId}',
      );
      final version = versionsById[row.programVersionId]!;
      _require(
        version.programId == row.programId && version.origin == 'legacyImport',
        'legacy mapping must reference its own legacy-import program version',
      );
      _require(
        mappedRoutines.add(row.legacyRoutineId),
        'duplicate legacy mapping for routine ${row.legacyRoutineId}',
      );
      _require(
        mappedPrograms.add(row.programId),
        'duplicate legacy mapping program ${row.programId}',
      );
      _require(
        mappedVersions.add(row.programVersionId),
        'duplicate legacy mapping version ${row.programVersionId}',
      );
    }
    for (final routineId in routineIds) {
      _require(
        mappedRoutines.contains(routineId),
        'legacy routine $routineId has no compatibility mapping in v6 backup',
      );
    }

    final sessionIds = workoutSessions.map((row) => row.id).toSet();
    _uniqueKeys(
      'workout-session occurrence',
      workoutSessions,
      (row) => row.scheduledOccurrenceId == null
          ? 'none:${row.id}'
          : row.scheduledOccurrenceId!,
    );
    for (final row in workoutSessions) {
      if (row.scheduledOccurrenceId != null) {
        final occurrence = occurrencesById[row.scheduledOccurrenceId];
        _require(
          occurrence != null &&
              const {
                'completed',
                'partiallyCompleted',
              }.contains(occurrence.status),
          'workout session ${row.id} references a non-terminal occurrence',
        );
      }
      if (row.executionTimezoneId != null) {
        _validateTimezone(
          row.executionTimezoneId!,
          'workout session ${row.id} execution timezone',
        );
      }
      _require(
        row.completionKind == null ||
            const {'full', 'partial'}.contains(row.completionKind),
        'workout session ${row.id} has invalid completion kind',
      );
    }
    for (final row in workoutSets) {
      _require(
        sessionIds.contains(row.sessionId),
        'workout set ${row.id} references missing session ${row.sessionId}',
      );
      _validateExerciseReference(
        row.exerciseId,
        knownExerciseIds,
        'workout set ${row.id}',
      );
    }
    for (final row in workoutDrafts) {
      if (row.scheduledOccurrenceId == null) continue;
      final occurrence = occurrencesById[row.scheduledOccurrenceId];
      _require(
        occurrence != null && occurrence.status == 'inProgress',
        'scheduled draft ${row.id} must reference an in-progress occurrence',
      );
      _require(
        row.executionSnapshotJson != null &&
            row.executionSnapshotJson == occurrence?.executionSnapshotJson,
        'scheduled draft ${row.id} has no matching frozen execution snapshot',
      );
    }
  }

  static Set<String> _uniqueIds<T>(
    String entity,
    Iterable<T> rows,
    String Function(T) id,
  ) {
    final ids = <String>{};
    for (final row in rows) {
      final value = id(row);
      _require(value.trim().isNotEmpty, '$entity has an empty ID');
      _require(ids.add(value), 'duplicate $entity ID "$value"');
    }
    return ids;
  }

  static void _uniqueKeys<T>(
    String entity,
    Iterable<T> rows,
    String Function(T) key,
  ) {
    final keys = <String>{};
    for (final row in rows) {
      final value = key(row);
      _require(keys.add(value), 'duplicate $entity "$value"');
    }
  }

  static void _assertAcyclic(
    Iterable<String> ids,
    String? Function(String id) parentOf,
    String entity,
  ) {
    final visiting = <String>{};
    final visited = <String>{};
    void visit(String id) {
      if (visited.contains(id)) return;
      if (!visiting.add(id)) {
        throw FormatException(
          'Backup validation failed: $entity graph contains a cycle at $id',
        );
      }
      final parent = parentOf(id);
      if (parent != null) visit(parent);
      visiting.remove(id);
      visited.add(id);
    }

    for (final id in ids) {
      visit(id);
    }
  }

  static void _validateExerciseReference(
    String? stableId,
    Set<String> knownIds,
    String owner,
  ) {
    if (stableId == null) return;
    _require(
      knownIds.contains(stableId),
      '$owner references unknown exercise stable ID $stableId',
    );
  }

  static void _validateOptionalOccurrenceStatus(String? status, String owner) {
    if (status == null) return;
    _require(
      const {
        'planned',
        'rescheduled',
        'inProgress',
        'completed',
        'partiallyCompleted',
        'skipped',
        'cancelled',
      }.contains(status),
      '$owner has invalid occurrence status $status',
    );
  }

  static void _validateLocalDateTimezone(
    String localDate,
    String timezoneId,
    String owner,
  ) {
    try {
      final dates = LocalScheduleDateService();
      dates.normalizeLocalDate(localDate);
      dates.validateTimezone(timezoneId);
    } catch (_) {
      throw FormatException(
        'Backup validation failed: $owner has invalid local date or IANA timezone',
      );
    }
  }

  static void _validateOptionalLocalDateTimezone(
    String? localDate,
    String? timezoneId,
    String owner,
  ) {
    _require(
      (localDate == null) == (timezoneId == null),
      '$owner must provide both local date and timezone or neither',
    );
    if (localDate != null) {
      _validateLocalDateTimezone(localDate, timezoneId!, owner);
    }
  }

  static void _validateTimezone(String timezoneId, String owner) {
    try {
      LocalScheduleDateService().validateTimezone(timezoneId);
    } catch (_) {
      throw FormatException(
        'Backup validation failed: $owner is not an IANA timezone',
      );
    }
  }

  static void _require(bool condition, String message) {
    if (!condition) {
      throw FormatException('Backup validation failed: $message');
    }
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

    if (version >= 6) {
      final seededExerciseStableIds = (await db.select(db.exercises).get())
          .where((exercise) => !exercise.isCustom)
          .map((exercise) => exercise.stableId)
          .whereType<String>()
          .toSet();
      _validateB01Graph(seededExerciseStableIds);
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
        // Delete the v15 graph in child-first order. Legacy routine/history
        // rows remain separate compatibility data and are cleared below.
        await db.delete(db.travelContextOccurrences).go();
        await db.delete(db.occurrenceEvents).go();
        await db.delete(db.exercisePersonalCues).go();
        await db.delete(db.exerciseSetupValues).go();
        await db.delete(db.exerciseUserPreferences).go();
        await db.delete(db.legacyRoutineProgramMappings).go();
        await db.delete(db.trainingPlanSettings).go();
        await db.delete(db.equipmentProfileItems).go();
        await db.delete(db.travelContexts).go();
        await db.delete(db.workoutDrafts).go();
        await db.delete(db.healthProvenances).go();
        await db.delete(db.workoutSets).go();
        await db.delete(db.workoutSessions).go();
        await db.customStatement(
          'UPDATE scheduled_session_occurrences SET repeated_from_occurrence_id = NULL',
        );
        await db.delete(db.scheduledSessionOccurrences).go();
        await db.delete(db.exercisePrescriptions).go();
        await db.delete(db.sessionTemplates).go();
        await db.delete(db.programWeeks).go();
        await db.delete(db.programBlocks).go();
        await db.customStatement(
          'UPDATE program_versions SET source_version_id = NULL',
        );
        await db.delete(db.programVersions).go();
        await db.delete(db.programs).go();
        await db.delete(db.equipmentProfiles).go();

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
        await db.delete(db.dailyHydrations).go();
        await db.delete(db.healthProvenances).go();
        await db.delete(db.achievementUnlocks).go();
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
                  name: Value(userProfile!.name),
                  equipmentAccess: Value(userProfile!.equipmentAccess),
                  injuriesLimitations: Value(userProfile!.injuriesLimitations),
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
                  stableId: Value(e.stableId),
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

        if (version >= 6) {
          await _insertB01Graph(db, routineIdMap);
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
                  scheduledOccurrenceId: Value(s.scheduledOccurrenceId),
                  executionSnapshotJson: Value(s.executionSnapshotJson),
                  executionTimezoneId: Value(s.executionTimezoneId),
                  completionKind: Value(s.completionKind),
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
                  exerciseId: Value(s.exerciseId),
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
                  scheduledOccurrenceId: Value(d.scheduledOccurrenceId),
                  executionSnapshotJson: Value(d.executionSnapshotJson),
                  draftSchemaVersion: Value(d.draftSchemaVersion),
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

        for (final h in dailyHydrations) {
          await db
              .into(db.dailyHydrations)
              .insert(
                DailyHydrationsCompanion.insert(
                  dateString: h.dateString,
                  totalMl: h.totalMl,
                  goalMl: h.goalMl,
                  updatedAt: Value(h.updatedAt),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        for (final p in healthProvenances) {
          int? targetLocalSessionId = p.localSessionId;
          if (targetLocalSessionId != null &&
              sessionIdMap.containsKey(targetLocalSessionId)) {
            targetLocalSessionId = sessionIdMap[targetLocalSessionId];
          }
          await db
              .into(db.healthProvenances)
              .insert(
                HealthProvenancesCompanion.insert(
                  provider: p.provider,
                  externalId: Value(p.externalId),
                  sourceName: p.sourceName,
                  importedAt: Value(p.importedAt),
                  localSessionId: Value(targetLocalSessionId),
                  fingerprint: p.fingerprint,
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        for (final a in achievementUnlocks) {
          await db
              .into(db.achievementUnlocks)
              .insert(
                AchievementUnlocksCompanion.insert(
                  achievementId: a.achievementId,
                  unlockedAt: Value(a.unlockedAt),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        if (version < 6) {
          // v3-v5 payloads deliberately contain no B01 graph. Build only the
          // inactive, deterministic compatibility snapshots from their
          // restored legacy routines, history, and equipment string in this
          // same transaction; never activate or schedule anything.
          await db.importLegacyCompatibilityDataForRestore();
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

  Future<void> _insertB01Graph(
    AppDatabase db,
    Map<int, int> routineIdMap,
  ) async {
    for (final row in programs) {
      await db.into(db.programs).insert(row);
    }
    for (final row in _parentFirstProgramVersions()) {
      await db.into(db.programVersions).insert(row);
    }
    for (final row in programBlocks) {
      await db.into(db.programBlocks).insert(row);
    }
    for (final row in programWeeks) {
      await db.into(db.programWeeks).insert(row);
    }
    for (final row in sessionTemplates) {
      await db.into(db.sessionTemplates).insert(row);
    }
    for (final row in exercisePrescriptions) {
      await db.into(db.exercisePrescriptions).insert(row);
    }

    for (final row in equipmentProfiles) {
      await db.into(db.equipmentProfiles).insert(row);
    }
    for (final row in equipmentProfileItems) {
      await db.into(db.equipmentProfileItems).insert(row);
    }

    for (final row in _parentFirstOccurrences()) {
      await db.into(db.scheduledSessionOccurrences).insert(row);
    }
    for (final row in occurrenceEvents) {
      await db.into(db.occurrenceEvents).insert(row);
    }

    if (trainingPlanSettings != null) {
      await db.into(db.trainingPlanSettings).insert(trainingPlanSettings!);
    }
    for (final row in travelContexts) {
      await db.into(db.travelContexts).insert(row);
    }
    for (final row in travelContextOccurrences) {
      await db.into(db.travelContextOccurrences).insert(row);
    }

    for (final row in exerciseUserPreferences) {
      await db.into(db.exerciseUserPreferences).insert(row);
    }
    for (final row in exerciseSetupValues) {
      await db.into(db.exerciseSetupValues).insert(row);
    }
    for (final row in exercisePersonalCues) {
      await db.into(db.exercisePersonalCues).insert(row);
    }
    for (final row in legacyRoutineProgramMappings) {
      await db
          .into(db.legacyRoutineProgramMappings)
          .insert(
            LegacyRoutineProgramMappingsCompanion.insert(
              legacyRoutineId: Value(
                routineIdMap[row.legacyRoutineId] ?? row.legacyRoutineId,
              ),
              programId: row.programId,
              programVersionId: row.programVersionId,
              importedAtUtc: row.importedAtUtc,
            ),
          );
    }
  }

  List<ProgramVersion> _parentFirstProgramVersions() {
    final byId = {for (final row in programVersions) row.id: row};
    final inserted = <String>{};
    final ordered = <ProgramVersion>[];
    void visit(ProgramVersion row) {
      if (!inserted.add(row.id)) return;
      final sourceId = row.sourceVersionId;
      if (sourceId != null) visit(byId[sourceId]!);
      ordered.add(row);
    }

    for (final row in programVersions) {
      visit(row);
    }
    return ordered;
  }

  List<ScheduledSessionOccurrence> _parentFirstOccurrences() {
    final byId = {for (final row in scheduledSessionOccurrences) row.id: row};
    final inserted = <String>{};
    final ordered = <ScheduledSessionOccurrence>[];
    void visit(ScheduledSessionOccurrence row) {
      if (!inserted.add(row.id)) return;
      final sourceId = row.repeatedFromOccurrenceId;
      if (sourceId != null) visit(byId[sourceId]!);
      ordered.add(row);
    }

    for (final row in scheduledSessionOccurrences) {
      visit(row);
    }
    return ordered;
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

class BackupEnvelope {
  final String formatIdentifier;
  final int version;
  final int schemaVersion;
  final String timestamp;
  final bool isEncrypted;
  final String checksum;
  final String profileName;
  final Map<String, int> tableCounts;
  final String payload;

  BackupEnvelope({
    this.formatIdentifier = 'INDIFIT_BACKUP_ENVELOPE',
    required this.version,
    required this.schemaVersion,
    required this.timestamp,
    required this.isEncrypted,
    required this.checksum,
    required this.profileName,
    required this.tableCounts,
    required this.payload,
  });

  static BackupEnvelope create({
    required BackupData data,
    required String payloadText,
    required bool isEncrypted,
  }) {
    final checksum = sha256.convert(utf8.encode(payloadText)).toString();
    final counts = <String, int>{
      'food_logs': data.foodLogs.length,
      'workout_sessions': data.workoutSessions.length,
      'workout_sets': data.workoutSets.length,
      'body_measurements': data.bodyMeasurements.length,
      'daily_hydrations': data.dailyHydrations.length,
      'achievement_unlocks': data.achievementUnlocks.length,
      'programs': data.programs.length,
      'program_versions': data.programVersions.length,
      'program_blocks': data.programBlocks.length,
      'program_weeks': data.programWeeks.length,
      'session_templates': data.sessionTemplates.length,
      'exercise_prescriptions': data.exercisePrescriptions.length,
      'scheduled_session_occurrences': data.scheduledSessionOccurrences.length,
      'occurrence_events': data.occurrenceEvents.length,
      'training_plan_settings': data.trainingPlanSettings == null ? 0 : 1,
      'equipment_profiles': data.equipmentProfiles.length,
      'equipment_profile_items': data.equipmentProfileItems.length,
      'travel_contexts': data.travelContexts.length,
      'travel_context_occurrences': data.travelContextOccurrences.length,
      'exercise_user_preferences': data.exerciseUserPreferences.length,
      'exercise_setup_values': data.exerciseSetupValues.length,
      'exercise_personal_cues': data.exercisePersonalCues.length,
      'legacy_routine_program_mappings':
          data.legacyRoutineProgramMappings.length,
    };

    return BackupEnvelope(
      formatIdentifier: 'INDIFIT_BACKUP_ENVELOPE',
      version: data.version,
      schemaVersion: data.schemaVersion,
      timestamp: data.timestamp,
      isEncrypted: isEncrypted,
      checksum: checksum,
      profileName: data.userProfile?.name ?? 'User Profile',
      tableCounts: counts,
      payload: payloadText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'format_identifier': formatIdentifier,
      'version': version,
      'schema_version': schemaVersion,
      'timestamp': timestamp,
      'is_encrypted': isEncrypted,
      'checksum': checksum,
      'profile_name': profileName,
      'table_counts': tableCounts,
      'payload': payload,
    };
  }

  static BackupEnvelope fromJson(Map<String, dynamic> json) {
    final format = json['format_identifier'] as String?;
    if (format != 'INDIFIT_BACKUP_ENVELOPE') {
      throw const FormatException('Invalid backup envelope header identifier.');
    }

    final version = (json['version'] as num?)?.toInt();
    if (version == null || version < 3 || version > BackupData.currentVersion) {
      throw FormatException(
        'Unsupported backup envelope version ${json['version']} (latest supported is ${BackupData.currentVersion}).',
      );
    }

    final rawPayload = json['payload'] as String?;
    if (rawPayload == null || rawPayload.isEmpty) {
      throw const FormatException('Empty payload string in backup envelope.');
    }

    final expectedChecksum = json['checksum'] as String?;
    if (expectedChecksum != null) {
      final actualChecksum = sha256.convert(utf8.encode(rawPayload)).toString();
      if (actualChecksum != expectedChecksum) {
        throw const FormatException(
          'Backup file checksum mismatch: File is corrupt or truncated.',
        );
      }
    }

    final rawCounts = json['table_counts'] as Map<String, dynamic>? ?? {};
    final counts = rawCounts.map((k, v) => MapEntry(k, (v as num).toInt()));

    return BackupEnvelope(
      formatIdentifier: format ?? 'INDIFIT_BACKUP_ENVELOPE',
      version: version,
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 13,
      timestamp:
          json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      isEncrypted: json['is_encrypted'] as bool? ?? false,
      checksum: expectedChecksum ?? '',
      profileName: json['profile_name'] as String? ?? 'User Profile',
      tableCounts: counts,
      payload: rawPayload,
    );
  }
}
