import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/models/b02_rich_set_helpers.dart';
import '../fixtures/b02_execution_draft_codec.dart';

/// Parses an offset-less legacy backup timestamp without consulting the
/// machine's local timezone. Legacy backup timestamps represent instants in
/// UTC; explicit offsets retain their ISO-8601 meaning.
DateTime parseLegacyBackupTimestamp(String value) {
  final trimmed = value.trim();
  final hasExplicitOffset = RegExp(
    r'(?:[zZ]|[+-]\d{2}:?\d{2})$',
  ).hasMatch(trimmed);
  final parsed = DateTime.parse(hasExplicitOffset ? trimmed : '${trimmed}Z');
  return parsed.toUtc();
}

/// Test-only restore boundaries. The production restore path remains
/// transactional; callers leave the injector null.
///
/// [beforeTransactionCommit] is the last supported injectable boundary. The
/// database layer does not expose a post-commit callback, so the harness does
/// not claim coverage after the physical SQLite COMMIT.
enum BackupRestoreFailureStage {
  relationshipPrevalidation,
  preferenceWrite,
  databaseMutation,
  beforeTransactionCommit,
  preferenceRestore,
}

typedef BackupRestoreFailureInjector =
    Future<void> Function(BackupRestoreFailureStage stage);

/// Optional work that a versioned extension can append to the existing
/// restore transaction.  Backup-v8 uses this seam for the schema-v17 graph;
/// it is intentionally not exposed to ordinary callers through a second
/// transaction.
typedef BackupAdditionalMutation = Future<void> Function(AppDatabase db);

/// Canonical Versioned Backup Schema (Version 7).
///
/// Provides a unified, production-safe DTO and serializer for all user-owned
/// database records and persisted application preferences.
/// Shared identically by manual backup/export and automated background backups.
class BackupData {
  static const int currentVersion = 7;

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

  // B02 typed execution, modality, target, and reviewed-catalog rows. These
  // remain relational collections in the backup so the complete graph can be
  // validated before a restore mutates either preferences or the database.
  final List<ExerciseGroup> exerciseGroups;
  final List<ExerciseGroupMember> exerciseGroupMembers;
  final List<StrengthSetPrescription> strengthSetPrescriptions;
  final List<CardioSessionDetail> cardioSessionDetails;
  final List<CardioInterval> cardioIntervals;
  final List<MobilitySessionDetail> mobilitySessionDetails;
  final List<PerformedExerciseGroup> performedExerciseGroups;
  final List<PerformedExercise> performedExercises;
  final List<ExerciseTargetRecommendation> exerciseTargetRecommendations;
  final List<PerformedSet> performedSets;
  final List<PerformedSetSegment> performedSetSegments;
  final List<PerformedRestPeriod> performedRestPeriods;
  final List<Muscle> muscles;
  final List<ExerciseMuscleMapping> exerciseMuscleMappings;

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
    this.exerciseGroups = const [],
    this.exerciseGroupMembers = const [],
    this.strengthSetPrescriptions = const [],
    this.cardioSessionDetails = const [],
    this.cardioIntervals = const [],
    this.mobilitySessionDetails = const [],
    this.performedExerciseGroups = const [],
    this.performedExercises = const [],
    this.exerciseTargetRecommendations = const [],
    this.performedSets = const [],
    this.performedSetSegments = const [],
    this.performedRestPeriods = const [],
    this.muscles = const [],
    this.exerciseMuscleMappings = const [],
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
    final exerciseGroups = await db.select(db.exerciseGroups).get();
    final exerciseGroupMembers = await db.select(db.exerciseGroupMembers).get();
    final strengthSetPrescriptions = await db
        .select(db.strengthSetPrescriptions)
        .get();
    final cardioSessionDetails = await db.select(db.cardioSessionDetails).get();
    final cardioIntervals = await db.select(db.cardioIntervals).get();
    final mobilitySessionDetails = await db
        .select(db.mobilitySessionDetails)
        .get();
    final performedExerciseGroups = await db
        .select(db.performedExerciseGroups)
        .get();
    final performedExercises = await db.select(db.performedExercises).get();
    final exerciseTargetRecommendations = await db
        .select(db.exerciseTargetRecommendations)
        .get();
    final performedSets = await db.select(db.performedSets).get();
    final performedSetSegments = await db.select(db.performedSetSegments).get();
    final performedRestPeriods = await db.select(db.performedRestPeriods).get();
    final muscles = await db.select(db.muscles).get();
    final exerciseMuscleMappings = await db
        .select(db.exerciseMuscleMappings)
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
      timestamp: DateTime.now().toUtc().toIso8601String(),
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
      exerciseGroups: exerciseGroups,
      exerciseGroupMembers: exerciseGroupMembers,
      strengthSetPrescriptions: strengthSetPrescriptions,
      cardioSessionDetails: cardioSessionDetails,
      cardioIntervals: cardioIntervals,
      mobilitySessionDetails: mobilitySessionDetails,
      performedExerciseGroups: performedExerciseGroups,
      performedExercises: performedExercises,
      exerciseTargetRecommendations: exerciseTargetRecommendations,
      performedSets: performedSets,
      performedSetSegments: performedSetSegments,
      performedRestPeriods: performedRestPeriods,
      muscles: muscles,
      exerciseMuscleMappings: exerciseMuscleMappings,
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
          'updated_at': userProfile!.updatedAt.toUtc().toIso8601String(),
        },
      'user_settings': userSettings
          .map(
            (s) => {
              'key': s.key,
              'value': s.value,
              'updated_at': s.updatedAt.toUtc().toIso8601String(),
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
              'logged_at': f.loggedAt.toUtc().toIso8601String(),
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
              'created_at': t.createdAt.toUtc().toIso8601String(),
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
              'completed_at': s.completedAt.toUtc().toIso8601String(),
              'is_synced': s.isSynced,
              'uuid': s.uuid,
              'scheduled_occurrence_id': s.scheduledOccurrenceId,
              'execution_snapshot_json': s.executionSnapshotJson,
              'execution_timezone_id': s.executionTimezoneId,
              'completion_kind': s.completionKind,
              if (version >= 7) 'activity_type': s.activityType,
              if (version >= 7)
                'activity_schema_version': s.activitySchemaVersion,
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
              'created_at': r.createdAt.toUtc().toIso8601String(),
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
              'updated_at': d.updatedAt.toUtc().toIso8601String(),
              'scheduled_occurrence_id': d.scheduledOccurrenceId,
              'execution_snapshot_json': d.executionSnapshotJson,
              'draft_schema_version': d.draftSchemaVersion,
              if (version >= 7) 'activity_type': d.activityType,
              if (version >= 7) 'execution_state_json': d.executionStateJson,
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
              'recorded_at': m.recordedAt.toUtc().toIso8601String(),
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
              'updated_at': h.updatedAt.toUtc().toIso8601String(),
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
              'imported_at': p.importedAt.toUtc().toIso8601String(),
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
              'unlocked_at': a.unlockedAt.toUtc().toIso8601String(),
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
      if (version >= 7) ...{
        'exercise_groups': exerciseGroups.map((item) => item.toJson()).toList(),
        'exercise_group_members': exerciseGroupMembers
            .map((item) => item.toJson())
            .toList(),
        'strength_set_prescriptions': strengthSetPrescriptions
            .map((item) => item.toJson())
            .toList(),
        'cardio_session_details': cardioSessionDetails
            .map((item) => item.toJson())
            .toList(),
        'cardio_intervals': cardioIntervals
            .map((item) => item.toJson())
            .toList(),
        'mobility_session_details': mobilitySessionDetails
            .map((item) => item.toJson())
            .toList(),
        'performed_exercise_groups': performedExerciseGroups
            .map((item) => item.toJson())
            .toList(),
        'performed_exercises': performedExercises
            .map((item) => item.toJson())
            .toList(),
        'exercise_target_recommendations': exerciseTargetRecommendations
            .map((item) => item.toJson())
            .toList(),
        'performed_sets': performedSets.map((item) => item.toJson()).toList(),
        'performed_set_segments': performedSetSegments
            .map((item) => item.toJson())
            .toList(),
        'performed_rest_periods': performedRestPeriods
            .map((item) => item.toJson())
            .toList(),
        'muscles': muscles.map((item) => item.toJson()).toList(),
        'exercise_muscle_mappings': exerciseMuscleMappings
            .map((item) => item.toJson())
            .toList(),
      },
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

    final timestamp = (json['timestamp'] as String?) != null
        ? parseLegacyBackupTimestamp(
            json['timestamp'] as String,
          ).toIso8601String()
        : DateTime.now().toUtc().toIso8601String();
    final schemaVersion = (json['schema_version'] as num?)?.toInt() ?? 13;
    final isB01Payload = rawVersion >= 6;
    final isB02Payload = rawVersion >= 7;

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
            ? parseLegacyBackupTimestamp(p['updated_at'] as String)
            : DateTime.now().toUtc(),
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
                ? parseLegacyBackupTimestamp(s['updated_at'] as String)
                : DateTime.now().toUtc(),
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
                ? parseLegacyBackupTimestamp(f['logged_at'] as String)
                : DateTime.now().toUtc(),
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
                ? parseLegacyBackupTimestamp(t['created_at'] as String)
                : DateTime.now().toUtc(),
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
        if (isB02Payload &&
            (!s.containsKey('activity_type') ||
                !s.containsKey('activity_schema_version'))) {
          throw const FormatException(
            'Backup validation failed: v7 workout session is missing typed activity fields.',
          );
        }
        workoutSessions.add(
          WorkoutSession(
            id: (s['id'] as num).toInt(),
            name: s['name'] as String,
            totalVolume: (s['total_volume'] as num).toDouble(),
            durationSeconds: (s['duration_seconds'] as num).toInt(),
            estimatedCalories: (s['estimated_calories'] as num).toInt(),
            completedAt: s['completed_at'] != null
                ? parseLegacyBackupTimestamp(s['completed_at'] as String)
                : DateTime.now().toUtc(),
            isSynced: s['is_synced'] as bool? ?? false,
            uuid: s['uuid'] as String?,
            scheduledOccurrenceId: s['scheduled_occurrence_id'] as String?,
            executionSnapshotJson: s['execution_snapshot_json'] as String?,
            executionTimezoneId: s['execution_timezone_id'] as String?,
            completionKind: s['completion_kind'] as String?,
            // v5/v6 have no typed B02 activity graph. Retain those sessions
            // as explicit legacy history; v7 carries the exact typed fields.
            activityType: isB02Payload
                ? s['activity_type'] as String? ?? 'legacy'
                : 'legacy',
            activitySchemaVersion: isB02Payload
                ? (s['activity_schema_version'] as num?)?.toInt() ?? 1
                : 1,
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
                ? parseLegacyBackupTimestamp(r['created_at'] as String)
                : DateTime.now().toUtc(),
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
        if (isB02Payload &&
            (!d.containsKey('activity_type') ||
                !d.containsKey('execution_state_json'))) {
          throw const FormatException(
            'Backup validation failed: v7 workout draft is missing typed activity fields.',
          );
        }
        workoutDrafts.add(
          WorkoutDraft(
            id: (d['id'] as num).toInt(),
            routineName: d['routine_name'] as String,
            currentExerciseIndex: (d['current_exercise_index'] as num).toInt(),
            currentSetIndex: (d['current_set_index'] as num).toInt(),
            elapsedSeconds: (d['elapsed_seconds'] as num).toInt(),
            loggedSetsJson: d['logged_sets_json'] as String,
            updatedAt: d['updated_at'] != null
                ? parseLegacyBackupTimestamp(d['updated_at'] as String)
                : DateTime.now().toUtc(),
            scheduledOccurrenceId: d['scheduled_occurrence_id'] as String?,
            executionSnapshotJson: d['execution_snapshot_json'] as String?,
            draftSchemaVersion:
                (d['draft_schema_version'] as num?)?.toInt() ?? 1,
            // v5/v6 draft payloads remain B01-compatible and are never
            // upgraded into a B02 execution-state draft during restore.
            activityType: isB02Payload
                ? d['activity_type'] as String? ?? 'legacy'
                : 'legacy',
            executionStateJson: isB02Payload
                ? d['execution_state_json'] as String?
                : null,
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
                ? parseLegacyBackupTimestamp(m['recorded_at'] as String)
                : DateTime.now().toUtc(),
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
                ? parseLegacyBackupTimestamp(h['updated_at'] as String)
                : DateTime.now().toUtc(),
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
                ? parseLegacyBackupTimestamp(p['imported_at'] as String)
                : DateTime.now().toUtc(),
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
                ? parseLegacyBackupTimestamp(a['unlocked_at'] as String)
                : DateTime.now().toUtc(),
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

    if (isB02Payload) {
      for (final key in _b02BackupKeys) {
        if (!json.containsKey(key)) {
          throw FormatException(
            'Backup validation failed: v7 payload is missing B02 field "$key".',
          );
        }
      }
    }

    final exerciseGroups = isB02Payload
        ? _readTypedList(json, 'exercise_groups', ExerciseGroup.fromJson)
        : const <ExerciseGroup>[];
    final exerciseGroupMembers = isB02Payload
        ? _readTypedList(
            json,
            'exercise_group_members',
            ExerciseGroupMember.fromJson,
          )
        : const <ExerciseGroupMember>[];
    final strengthSetPrescriptions = isB02Payload
        ? _readTypedList(
            json,
            'strength_set_prescriptions',
            StrengthSetPrescription.fromJson,
          )
        : const <StrengthSetPrescription>[];
    final cardioSessionDetails = isB02Payload
        ? _readTypedList(
            json,
            'cardio_session_details',
            CardioSessionDetail.fromJson,
          )
        : const <CardioSessionDetail>[];
    final cardioIntervals = isB02Payload
        ? _readTypedList(json, 'cardio_intervals', CardioInterval.fromJson)
        : const <CardioInterval>[];
    final mobilitySessionDetails = isB02Payload
        ? _readTypedList(
            json,
            'mobility_session_details',
            MobilitySessionDetail.fromJson,
          )
        : const <MobilitySessionDetail>[];
    final performedExerciseGroups = isB02Payload
        ? _readTypedList(
            json,
            'performed_exercise_groups',
            PerformedExerciseGroup.fromJson,
          )
        : const <PerformedExerciseGroup>[];
    final performedExercises = isB02Payload
        ? _readTypedList(
            json,
            'performed_exercises',
            PerformedExercise.fromJson,
          )
        : const <PerformedExercise>[];
    final exerciseTargetRecommendations = isB02Payload
        ? _readTypedList(
            json,
            'exercise_target_recommendations',
            ExerciseTargetRecommendation.fromJson,
          )
        : const <ExerciseTargetRecommendation>[];
    final performedSets = isB02Payload
        ? _readTypedList(json, 'performed_sets', PerformedSet.fromJson)
        : const <PerformedSet>[];
    final performedSetSegments = isB02Payload
        ? _readTypedList(
            json,
            'performed_set_segments',
            PerformedSetSegment.fromJson,
          )
        : const <PerformedSetSegment>[];
    final performedRestPeriods = isB02Payload
        ? _readTypedList(
            json,
            'performed_rest_periods',
            PerformedRestPeriod.fromJson,
          )
        : const <PerformedRestPeriod>[];
    final muscles = isB02Payload
        ? _readTypedList(json, 'muscles', Muscle.fromJson)
        : const <Muscle>[];
    final exerciseMuscleMappings = isB02Payload
        ? _readTypedList(
            json,
            'exercise_muscle_mappings',
            ExerciseMuscleMapping.fromJson,
          )
        : const <ExerciseMuscleMapping>[];

    if (!isB02Payload) {
      for (final key in _b02BackupKeys) {
        final raw = json[key];
        if (raw is List && raw.isNotEmpty) {
          throw FormatException(
            'Backup validation failed: B02 field "$key" requires backup v7.',
          );
        }
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
      exerciseGroups: exerciseGroups,
      exerciseGroupMembers: exerciseGroupMembers,
      strengthSetPrescriptions: strengthSetPrescriptions,
      cardioSessionDetails: cardioSessionDetails,
      cardioIntervals: cardioIntervals,
      mobilitySessionDetails: mobilitySessionDetails,
      performedExerciseGroups: performedExerciseGroups,
      performedExercises: performedExercises,
      exerciseTargetRecommendations: exerciseTargetRecommendations,
      performedSets: performedSets,
      performedSetSegments: performedSetSegments,
      performedRestPeriods: performedRestPeriods,
      muscles: muscles,
      exerciseMuscleMappings: exerciseMuscleMappings,
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

  static List<T> _readTypedList<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>) decoder,
  ) {
    final raw = json[key];
    if (raw == null) return List<T>.empty(growable: false);
    if (raw is! List) {
      throw FormatException(
        'Invalid B02 backup field "$key": expected a list.',
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
      throw FormatException('Invalid B02 backup field "$key": $error');
    }
  }

  static const _b02BackupKeys = [
    'exercise_groups',
    'exercise_group_members',
    'strength_set_prescriptions',
    'cardio_session_details',
    'cardio_intervals',
    'mobility_session_details',
    'performed_exercise_groups',
    'performed_exercises',
    'exercise_target_recommendations',
    'performed_sets',
    'performed_set_segments',
    'performed_rest_periods',
    'muscles',
    'exercise_muscle_mappings',
  ];

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
        'legacy routine $routineId has no compatibility mapping in B01 backup',
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

  /// Validates the complete v7 B02 graph before any restore mutation.  The
  /// validator intentionally works on stored typed columns rather than
  /// display labels; every relation, enum, modality pairing, technique fact,
  /// and reviewed mapping allocation is checked here.
  void _validateB02Graph(Set<String> knownExerciseIds) {
    if (version < 7) return;

    final sessionIds = _uniqueIntIds(
      'workout session',
      workoutSessions,
      (row) => row.id,
    );
    final templateIds = _uniqueIds(
      'session template',
      sessionTemplates,
      (row) => row.id,
    );
    final prescriptionIds = _uniqueIds(
      'exercise prescription',
      exercisePrescriptions,
      (row) => row.id,
    );
    final groupIds = _uniqueIds(
      'exercise group',
      exerciseGroups,
      (row) => row.id,
    );
    _uniqueIds('exercise group member', exerciseGroupMembers, (row) => row.id);
    _uniqueIds(
      'strength set prescription',
      strengthSetPrescriptions,
      (row) => row.id,
    );
    _uniqueIds('cardio interval', cardioIntervals, (row) => row.id);
    _uniqueIds(
      'performed exercise group',
      performedExerciseGroups,
      (row) => row.id,
    );
    final performedExerciseIds = _uniqueIds(
      'performed exercise',
      performedExercises,
      (row) => row.id,
    );
    _uniqueIds(
      'exercise target recommendation',
      exerciseTargetRecommendations,
      (row) => row.id,
    );
    final setIds = _uniqueIds('performed set', performedSets, (row) => row.id);
    _uniqueIds('performed set segment', performedSetSegments, (row) => row.id);
    _uniqueIds('performed rest period', performedRestPeriods, (row) => row.id);
    final muscleIds = _uniqueIds('muscle', muscles, (row) => row.id);
    _uniqueIds(
      'exercise-muscle mapping',
      exerciseMuscleMappings,
      (row) => row.id,
    );
    _uniqueIntIds(
      'cardio session detail',
      cardioSessionDetails,
      (row) => row.sessionId,
    );
    _uniqueIntIds(
      'mobility session detail',
      mobilitySessionDetails,
      (row) => row.sessionId,
    );

    final sessionById = {for (final row in workoutSessions) row.id: row};
    final groupById = {for (final row in exerciseGroups) row.id: row};
    final performedGroupById = {
      for (final row in performedExerciseGroups) row.id: row,
    };
    final performedExerciseById = {
      for (final row in performedExercises) row.id: row,
    };
    final performedSetById = {for (final row in performedSets) row.id: row};

    for (final session in workoutSessions) {
      _parseB02Enum(
        'workout session ${session.id} activity type',
        () => B02ActivityType.parse(session.activityType),
      );
      _require(
        session.activitySchemaVersion >= 1,
        'workout session ${session.id} has an invalid activity schema version',
      );
    }

    for (final group in exerciseGroups) {
      _require(
        templateIds.contains(group.sessionTemplateId),
        'exercise group ${group.id} references missing session template ${group.sessionTemplateId}',
      );
      _parseB02Enum(
        'exercise group ${group.id} type',
        () => B02GroupType.parse(group.groupType),
      );
      _require(
        group.ordinal >= 0,
        'exercise group ${group.id} has invalid ordinal',
      );
      _require(
        group.roundCount >= 1,
        'exercise group ${group.id} has invalid round count',
      );
      _require(
        group.restAfterRoundSeconds == null ||
            group.restAfterRoundSeconds! >= 0,
        'exercise group ${group.id} has invalid rest',
      );
    }
    _uniqueKeys(
      'exercise group ordinal',
      exerciseGroups,
      (row) => '${row.sessionTemplateId}\u0000${row.ordinal}',
    );

    final memberOrdinalsByGroup = <String, List<int>>{};
    final memberPrescriptionsByGroup = <String, Set<String>>{};
    for (final member in exerciseGroupMembers) {
      _require(
        groupIds.contains(member.exerciseGroupId),
        'exercise group member ${member.id} references missing group ${member.exerciseGroupId}',
      );
      _require(
        prescriptionIds.contains(member.exercisePrescriptionId),
        'exercise group member ${member.id} references missing prescription ${member.exercisePrescriptionId}',
      );
      _require(
        member.ordinal >= 0,
        'exercise group member ${member.id} has invalid ordinal',
      );
      _require(
        member.transitionRestSeconds == null ||
            member.transitionRestSeconds! >= 0,
        'exercise group member ${member.id} has invalid transition rest',
      );
      memberOrdinalsByGroup
          .putIfAbsent(member.exerciseGroupId, () => [])
          .add(member.ordinal);
      final prescriptions = memberPrescriptionsByGroup.putIfAbsent(
        member.exerciseGroupId,
        () => <String>{},
      );
      _require(
        prescriptions.add(member.exercisePrescriptionId),
        'exercise group ${member.exerciseGroupId} repeats prescription ${member.exercisePrescriptionId}',
      );
    }
    _uniqueKeys(
      'exercise group member prescription',
      exerciseGroupMembers,
      (row) => row.exercisePrescriptionId,
    );
    for (final entry in memberOrdinalsByGroup.entries) {
      _uniqueIntValues(
        'exercise group ${entry.key} member ordinal',
        entry.value,
      );
      final group = groupById[entry.key]!;
      final groupType = B02GroupType.parse(group.groupType);
      _require(
        groupType.acceptsMemberCount(entry.value.length),
        '${groupType.dbValue} group ${group.id} has an invalid member count',
      );
    }

    for (final row in strengthSetPrescriptions) {
      _require(
        prescriptionIds.contains(row.exercisePrescriptionId),
        'strength set prescription ${row.id} references missing exercise prescription ${row.exercisePrescriptionId}',
      );
      _validateStoredSetValues(
        owner: 'strength set prescription ${row.id}',
        loadBasis: row.loadBasis,
        targetLoadKg: row.targetLoadKg,
        targetRepsMin: row.targetRepsMin,
        targetRepsMax: row.targetRepsMax,
        targetRpe: row.targetRpe,
        effortMode: row.effortMode,
        tempo: [
          row.tempoEccentricSeconds,
          row.tempoBottomPauseSeconds,
          row.tempoConcentricSeconds,
          row.tempoLockoutPauseSeconds,
        ],
        pausedRepPosition: row.pausedRepPosition,
        pausedRepSeconds: row.pausedRepSeconds,
        assistanceMode: row.assistanceMode,
        assistanceKg: row.assistanceKg,
      );
      if (row.techniquePlanJson != null) {
        try {
          final technique = B02TechniqueDraftCodec.decode(
            row.techniquePlanJson!,
          );
          B02RichSetValidator.validateTechnique(technique);
        } on Object catch (error) {
          throw FormatException(
            'Backup validation failed: strength set prescription ${row.id} has invalid technique plan: $error',
          );
        }
      }
    }
    _uniqueKeys(
      'strength set prescription ordinal',
      strengthSetPrescriptions,
      (row) => '${row.exercisePrescriptionId}\u0000${row.ordinal}',
    );

    for (final detail in cardioSessionDetails) {
      final session = sessionById[detail.sessionId];
      _require(
        session != null,
        'cardio detail ${detail.sessionId} references missing session',
      );
      _require(
        session != null &&
            const {
              'running',
              'cycling',
              'walking',
            }.contains(session.activityType),
        'cardio detail ${detail.sessionId} does not match a cardio session',
      );
      _parseB02Enum(
        'cardio detail ${detail.sessionId} input mode',
        () => detail.inputMode == null
            ? null
            : B02InputMode.parse(detail.inputMode),
      );
      _require(
        detail.distanceMetres == null || detail.distanceMetres! > 0,
        'cardio detail ${detail.sessionId} has invalid distance',
      );
      _require(
        detail.observedPaceSecondsPerKm == null ||
            detail.observedPaceSecondsPerKm! > 0,
        'cardio detail ${detail.sessionId} has invalid pace',
      );
      _require(
        detail.observedSpeedKph == null || detail.observedSpeedKph! > 0,
        'cardio detail ${detail.sessionId} has invalid speed',
      );
      _require(
        detail.perceivedExertion == null ||
            (detail.perceivedExertion! >= 1 && detail.perceivedExertion! <= 10),
        'cardio detail ${detail.sessionId} has invalid perceived exertion',
      );
      _require(
        detail.averageHeartRate == null || detail.averageHeartRate! > 0,
        'cardio detail ${detail.sessionId} has invalid average heart rate',
      );
    }
    for (final interval in cardioIntervals) {
      _require(
        cardioSessionDetails.any(
          (row) => row.sessionId == interval.cardioSessionId,
        ),
        'cardio interval ${interval.id} references missing cardio detail',
      );
      _parseB02Enum(
        'cardio interval ${interval.id} segment type',
        () => B02CardioSegmentType.parse(interval.segmentType),
      );
      _require(
        interval.ordinal >= 0,
        'cardio interval ${interval.id} has invalid ordinal',
      );
      _require(
        interval.durationSeconds == null || interval.durationSeconds! > 0,
        'cardio interval ${interval.id} has invalid duration',
      );
      _require(
        interval.distanceMetres == null || interval.distanceMetres! > 0,
        'cardio interval ${interval.id} has invalid distance',
      );
      _require(
        interval.targetPaceSecondsPerKm == null ||
            interval.targetPaceSecondsPerKm! > 0,
        'cardio interval ${interval.id} has invalid target pace',
      );
      _require(
        interval.actualPaceSecondsPerKm == null ||
            interval.actualPaceSecondsPerKm! > 0,
        'cardio interval ${interval.id} has invalid actual pace',
      );
      _require(
        interval.averageHeartRate == null || interval.averageHeartRate! > 0,
        'cardio interval ${interval.id} has invalid average heart rate',
      );
    }
    _uniqueKeys(
      'cardio interval ordinal',
      cardioIntervals,
      (row) => '${row.cardioSessionId}\u0000${row.ordinal}',
    );

    for (final detail in mobilitySessionDetails) {
      final session = sessionById[detail.sessionId];
      _require(
        session != null &&
            const {'yoga', 'mobility'}.contains(session.activityType),
        'mobility detail ${detail.sessionId} does not match a mobility session',
      );
      _require(
        const {'yoga', 'mobility'}.contains(detail.practiceType),
        'mobility detail ${detail.sessionId} has invalid practice type',
      );
      _require(
        session == null || session.activityType == detail.practiceType,
        'mobility detail ${detail.sessionId} practice type does not match activity type',
      );
      _require(
        detail.averageHeartRate == null || detail.averageHeartRate! > 0,
        'mobility detail ${detail.sessionId} has invalid average heart rate',
      );
    }

    for (final row in performedExerciseGroups) {
      final session = sessionById[row.sessionId];
      _require(
        session != null &&
            session.activityType == B02ActivityType.strength.dbValue,
        'performed exercise group ${row.id} does not belong to a strength session',
      );
      if (row.sourceExerciseGroupId != null) {
        _require(
          groupIds.contains(row.sourceExerciseGroupId),
          'performed exercise group ${row.id} references missing source group ${row.sourceExerciseGroupId}',
        );
      }
      _parseB02Enum(
        'performed exercise group ${row.id} type',
        () => B02GroupType.parse(row.groupTypeSnapshot),
      );
      _require(
        row.ordinal >= 0,
        'performed exercise group ${row.id} has invalid ordinal',
      );
      _require(
        row.plannedRounds >= 1,
        'performed exercise group ${row.id} has invalid planned rounds',
      );
      _require(
        row.completedRounds >= 0 && row.completedRounds <= row.plannedRounds,
        'performed exercise group ${row.id} has invalid completed rounds',
      );
      _require(
        const {'inProgress', 'completed', 'partial'}.contains(row.status),
        'performed exercise group ${row.id} has invalid status',
      );
    }
    _uniqueKeys(
      'performed exercise group ordinal',
      performedExerciseGroups,
      (row) => '${row.sessionId}\u0000${row.ordinal}',
    );

    for (final row in performedExercises) {
      final session = sessionById[row.sessionId];
      _require(
        session != null &&
            session.activityType == B02ActivityType.strength.dbValue,
        'performed exercise ${row.id} does not belong to a strength session',
      );
      if (row.performedExerciseGroupId != null) {
        final group = performedGroupById[row.performedExerciseGroupId];
        _require(
          group != null && group.sessionId == row.sessionId,
          'performed exercise ${row.id} references a group from another session',
        );
      }
      if (row.sourceExercisePrescriptionId != null) {
        _require(
          prescriptionIds.contains(row.sourceExercisePrescriptionId),
          'performed exercise ${row.id} references missing source prescription ${row.sourceExercisePrescriptionId}',
        );
      }
      _validateExerciseReference(
        row.expectedExerciseId,
        knownExerciseIds,
        'performed exercise ${row.id} expected exercise',
      );
      _validateExerciseReference(
        row.actualExerciseId,
        knownExerciseIds,
        'performed exercise ${row.id} actual exercise',
      );
      _require(
        row.actualExerciseId.trim().isNotEmpty,
        'performed exercise ${row.id} has an empty actual exercise ID',
      );
      _require(
        row.ordinal >= 0,
        'performed exercise ${row.id} has invalid ordinal',
      );
      _require(
        row.groupMemberOrdinal == null || row.groupMemberOrdinal! >= 0,
        'performed exercise ${row.id} has invalid member ordinal',
      );
      _require(
        row.groupRoundOrdinal == null || row.groupRoundOrdinal! >= 0,
        'performed exercise ${row.id} has invalid round ordinal',
      );
      _require(
        const {
          'inProgress',
          'completed',
          'partial',
          'skipped',
        }.contains(row.status),
        'performed exercise ${row.id} has invalid status',
      );
    }
    _uniqueKeys(
      'performed exercise ordinal',
      performedExercises,
      (row) => '${row.sessionId}\u0000${row.ordinal}',
    );

    for (final row in exerciseTargetRecommendations) {
      _require(
        performedExerciseIds.contains(row.performedExerciseId),
        'target recommendation ${row.id} references missing performed exercise ${row.performedExerciseId}',
      );
      _require(
        row.ruleVersion.trim().isNotEmpty,
        'target recommendation ${row.id} has no rule version',
      );
      _parseB02Enum(
        'target recommendation ${row.id} confidence',
        () => B02Confidence.parse(row.confidence),
      );
      _validateStoredSetValues(
        owner: 'target recommendation ${row.id}',
        loadBasis: row.loadBasis,
        targetLoadKg: row.recommendedLoadKg,
        targetRepsMin: row.targetRepsMin,
        targetRepsMax: row.targetRepsMax,
        targetRpe: row.targetRpe,
        incrementKg: row.incrementKg,
      );
      _require(
        row.comparatorCount >= 0,
        'target recommendation ${row.id} has invalid comparator count',
      );
      try {
        final completeness = jsonDecode(row.completenessJson);
        _require(
          completeness is Map,
          'target recommendation ${row.id} completeness must be an object',
        );
        final rationale = jsonDecode(row.rationaleCodesJson);
        _require(
          rationale is List && rationale.every((value) => value is String),
          'target recommendation ${row.id} rationale codes must be a string array',
        );
      } on FormatException {
        rethrow;
      } on Object catch (error) {
        throw FormatException(
          'Backup validation failed: target recommendation ${row.id} has invalid evidence JSON: $error',
        );
      }
    }
    _uniqueKeys(
      'target recommendation owner',
      exerciseTargetRecommendations,
      (row) => row.performedExerciseId,
    );

    final segmentsBySet = <String, List<PerformedSetSegment>>{};
    for (final row in performedSetSegments) {
      _require(
        setIds.contains(row.performedSetId),
        'performed set segment ${row.id} references missing performed set ${row.performedSetId}',
      );
      _require(
        row.ordinal >= 0,
        'performed set segment ${row.id} has invalid ordinal',
      );
      _require(
        row.reps >= 1,
        'performed set segment ${row.id} has invalid reps',
      );
      _parseB02OptionalEnum(
        'performed set segment ${row.id} load basis',
        row.loadBasis,
        B02LoadBasis.parse,
      );
      _require(
        row.externalLoadKg == null || row.externalLoadKg! >= 0,
        'performed set segment ${row.id} has invalid load',
      );
      _require(
        row.assistanceKg == null || row.assistanceKg! > 0,
        'performed set segment ${row.id} has invalid assistance',
      );
      _require(
        row.restBeforeSeconds == null || row.restBeforeSeconds! >= 0,
        'performed set segment ${row.id} has invalid rest',
      );
      segmentsBySet.putIfAbsent(row.performedSetId, () => []).add(row);
    }
    _uniqueKeys(
      'performed set segment ordinal',
      performedSetSegments,
      (row) => '${row.performedSetId}\u0000${row.ordinal}',
    );

    for (final row in performedSets) {
      final exercise = performedExerciseById[row.performedExerciseId];
      _require(
        exercise != null,
        'performed set ${row.id} references missing performed exercise ${row.performedExerciseId}',
      );
      _parseB02Enum(
        'performed set ${row.id} role',
        () => B02SetRole.parse(row.role),
      );
      _validateStoredSetValues(
        owner: 'performed set ${row.id}',
        loadBasis: row.targetLoadBasis,
        targetLoadKg: row.targetLoadKg,
        targetRepsMin: row.targetRepsMin,
        targetRepsMax: row.targetRepsMax,
        targetRpe: row.targetRpe,
        effortMode: row.effortMode,
        tempo: [
          row.tempoEccentricSeconds,
          row.tempoBottomPauseSeconds,
          row.tempoConcentricSeconds,
          row.tempoLockoutPauseSeconds,
        ],
        pausedRepPosition: row.pausedRepPosition,
        pausedRepSeconds: row.pausedRepSeconds,
        assistanceMode: row.assistanceMode,
        assistanceKg: row.assistanceKg,
      );
      _validateStoredSetValues(
        owner: 'performed set ${row.id} actual values',
        loadBasis: row.actualLoadBasis,
        targetLoadKg: row.actualLoadKg,
        targetRepsMin: row.actualReps,
        targetRepsMax: null,
        targetRpe: row.actualRpe,
        allowZeroReps: true,
      );
      final segments = segmentsBySet[row.id] ?? const <PerformedSetSegment>[];
      if (row.actualReps != null) {
        final segmentReps = segments.fold<int>(
          0,
          (sum, segment) => sum + segment.reps,
        );
        _require(
          segments.isEmpty || segmentReps == row.actualReps,
          'performed set ${row.id} segment reps do not equal actual reps',
        );
      }
      final ordinals = segments.map((segment) => segment.ordinal).toList();
      if (ordinals.isNotEmpty) {
        _requireContiguous(ordinals, 'performed set ${row.id} segment');
      }
    }
    _uniqueKeys(
      'performed set ordinal',
      performedSets,
      (row) => '${row.performedExerciseId}\u0000${row.ordinal}',
    );

    for (final row in performedRestPeriods) {
      final session = sessionById[row.sessionId];
      _require(
        session != null,
        'performed rest period ${row.id} references missing session ${row.sessionId}',
      );
      var hasParent = false;
      if (row.performedSetId != null) {
        final set = performedSetById[row.performedSetId];
        _require(
          set != null,
          'performed rest period ${row.id} references missing performed set ${row.performedSetId}',
        );
        hasParent = true;
        final exercise = set == null
            ? null
            : performedExerciseById[set.performedExerciseId];
        _require(
          exercise != null && exercise.sessionId == row.sessionId,
          'performed rest period ${row.id} set parent belongs to another session',
        );
      }
      if (row.performedExerciseGroupId != null) {
        final group = performedGroupById[row.performedExerciseGroupId];
        _require(
          group != null,
          'performed rest period ${row.id} references missing group ${row.performedExerciseGroupId}',
        );
        hasParent = true;
        _require(
          group == null || group.sessionId == row.sessionId,
          'performed rest period ${row.id} group parent belongs to another session',
        );
      }
      _require(
        hasParent,
        'performed rest period ${row.id} has no parent execution row',
      );
      _parseB02Enum(
        'performed rest period ${row.id} scope',
        () => B02RestScope.parse(row.scope),
      );
      _parseB02Enum(
        'performed rest period ${row.id} source',
        () => B02RestSource.parse(row.source),
      );
      _parseB02OptionalEnum(
        'performed rest period ${row.id} end reason',
        row.endReason,
        B02RestEndReason.parse,
      );
      _require(
        row.recommendedSeconds == null || row.recommendedSeconds! >= 0,
        'performed rest period ${row.id} has invalid recommendation',
      );
      _require(
        row.selectedSeconds == null || row.selectedSeconds! >= 0,
        'performed rest period ${row.id} has invalid selection',
      );
      _require(
        row.actualSeconds == null || row.actualSeconds! >= 0,
        'performed rest period ${row.id} has invalid actual rest',
      );
      _require(
        row.endedAtUtc == null || !row.endedAtUtc!.isBefore(row.startedAtUtc),
        'performed rest period ${row.id} ends before it starts',
      );
    }

    for (final muscle in muscles) {
      _require(muscle.id.trim().isNotEmpty, 'muscle has an empty ID');
      _require(
        muscle.displayName.trim().isNotEmpty,
        'muscle ${muscle.id} has an empty display name',
      );
      _require(
        muscle.catalogVersion >= 1,
        'muscle ${muscle.id} has invalid catalog version',
      );
    }
    _uniqueKeys(
      'muscle display/catalog identity',
      muscles,
      (row) => '${row.displayName}\u0000${row.catalogVersion}',
    );
    final mappingsByExercise = <String, List<ExerciseMuscleMapping>>{};
    for (final row in exerciseMuscleMappings) {
      _validateExerciseReference(
        row.exerciseId,
        knownExerciseIds,
        'mapping ${row.id}',
      );
      _require(
        muscleIds.contains(row.muscleId),
        'mapping ${row.id} references missing muscle ${row.muscleId}',
      );
      _parseB02Enum(
        'mapping ${row.id} role',
        () => B02MuscleRole.parse(row.role),
      );
      _parseB02Enum(
        'mapping ${row.id} status',
        () => B02MappingStatus.parse(row.mappingStatus),
      );
      _require(
        row.contributionBasisPoints >= 1 &&
            row.contributionBasisPoints <= 10000,
        'mapping ${row.id} has invalid contribution',
      );
      _require(
        row.catalogVersion >= 1,
        'mapping ${row.id} has invalid catalog version',
      );
      if (row.mappingStatus == B02MappingStatus.reviewed.dbValue) {
        _require(
          row.source?.trim().isNotEmpty == true,
          'reviewed mapping ${row.id} has no source',
        );
      }
      mappingsByExercise.putIfAbsent(row.exerciseId, () => []).add(row);
    }
    _uniqueKeys(
      'exercise-muscle mapping pair',
      exerciseMuscleMappings,
      (row) => '${row.exerciseId}\u0000${row.muscleId}',
    );
    for (final entry in mappingsByExercise.entries) {
      final statuses = entry.value.map((row) => row.mappingStatus).toSet();
      if (statuses.length == 1 &&
          statuses.single == B02MappingStatus.reviewed.dbValue) {
        final total = entry.value.fold<int>(
          0,
          (sum, row) => sum + row.contributionBasisPoints,
        );
        _require(
          total == 10000,
          'reviewed mapping ${entry.key} does not total 10000 basis points',
        );
        final sources = entry.value.map((row) => row.source).toSet();
        final versions = entry.value.map((row) => row.catalogVersion).toSet();
        _require(
          sources.length == 1 && versions.length == 1,
          'reviewed mapping ${entry.key} disagrees on source or catalog version',
        );
      }
    }

    final cardioBySession = cardioSessionDetails
        .map((row) => row.sessionId)
        .toSet();
    final mobilityBySession = mobilitySessionDetails
        .map((row) => row.sessionId)
        .toSet();
    final performedBySession = performedExercises
        .map((row) => row.sessionId)
        .toSet();
    for (final session in workoutSessions) {
      final isCardio = const {
        'running',
        'cycling',
        'walking',
      }.contains(session.activityType);
      final isMobility = const {
        'yoga',
        'mobility',
      }.contains(session.activityType);
      final isStrength =
          session.activityType == B02ActivityType.strength.dbValue;
      if (isCardio) {
        _require(
          cardioBySession.contains(session.id),
          'cardio session ${session.id} is missing its detail row',
        );
        _require(
          !mobilityBySession.contains(session.id),
          'cardio session ${session.id} has mobility detail',
        );
        _require(
          !performedBySession.contains(session.id),
          'cardio session ${session.id} has strength execution rows',
        );
      } else if (isMobility) {
        _require(
          mobilityBySession.contains(session.id),
          'mobility session ${session.id} is missing its detail row',
        );
        _require(
          !cardioBySession.contains(session.id),
          'mobility session ${session.id} has cardio detail',
        );
        _require(
          !performedBySession.contains(session.id),
          'mobility session ${session.id} has strength execution rows',
        );
      } else if (isStrength) {
        _require(
          !cardioBySession.contains(session.id),
          'strength session ${session.id} has cardio detail',
        );
        _require(
          !mobilityBySession.contains(session.id),
          'strength session ${session.id} has mobility detail',
        );
      } else {
        _require(
          !cardioBySession.contains(session.id) &&
              !mobilityBySession.contains(session.id) &&
              !performedBySession.contains(session.id),
          'legacy session ${session.id} has typed B02 rows',
        );
      }
    }
    for (final draft in workoutDrafts) {
      _parseB02Enum(
        'draft ${draft.id} activity type',
        () => B02ActivityType.parse(draft.activityType),
      );
      if (draft.activityType == B02ActivityType.legacy.dbValue) {
        _require(
          draft.executionStateJson == null,
          'legacy draft ${draft.id} contains a typed execution state',
        );
      } else {
        _require(
          draft.executionStateJson != null,
          'canonical draft ${draft.id} is missing execution state',
        );
        try {
          final decoded = B02ExecutionDraftCodec.decode(
            draft.executionStateJson!,
          );
          _require(
            decoded.isCanonical,
            'canonical draft ${draft.id} did not decode as v2 state',
          );
          _require(
            decoded.state!.activityType.dbValue == draft.activityType,
            'draft ${draft.id} activity type does not match execution state',
          );
        } on Object catch (error) {
          throw FormatException(
            'Backup validation failed: draft ${draft.id} has invalid execution state: $error',
          );
        }
      }
    }
    for (final provenance in healthProvenances) {
      if (provenance.localSessionId != null) {
        _require(
          sessionIds.contains(provenance.localSessionId),
          'health provenance ${provenance.id} references missing session ${provenance.localSessionId}',
        );
      }
      _require(
        provenance.provider.trim().isNotEmpty,
        'health provenance ${provenance.id} has no provider',
      );
      _require(
        provenance.fingerprint.trim().isNotEmpty,
        'health provenance ${provenance.id} has no fingerprint',
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

  static Set<int> _uniqueIntIds<T>(
    String entity,
    Iterable<T> rows,
    int Function(T) id,
  ) {
    final ids = <int>{};
    for (final row in rows) {
      final value = id(row);
      _require(value > 0, '$entity has an invalid ID');
      _require(ids.add(value), 'duplicate $entity ID "$value"');
    }
    return ids;
  }

  static void _uniqueIntValues(String entity, Iterable<int> values) {
    final seen = <int>{};
    for (final value in values) {
      _require(seen.add(value), 'duplicate $entity "$value"');
    }
  }

  static void _requireContiguous(Iterable<int> values, String entity) {
    final sorted = [...values]..sort();
    for (var index = 0; index < sorted.length; index++) {
      _require(
        sorted[index] == index,
        '$entity ordinals must be contiguous from 0',
      );
    }
  }

  static void _parseB02Enum(String owner, Object? Function() parser) {
    try {
      parser();
    } on B02ValidationException catch (error) {
      throw FormatException(
        'Backup validation failed: $owner: ${error.message}',
      );
    }
  }

  static void _parseB02OptionalEnum<T>(
    String owner,
    String? raw,
    T Function(Object?) parser,
  ) {
    if (raw == null) return;
    _parseB02Enum(owner, () => parser(raw));
  }

  static void _validateStoredSetValues({
    required String owner,
    String? loadBasis,
    double? targetLoadKg,
    int? targetRepsMin,
    int? targetRepsMax,
    int? targetRpe,
    String? effortMode,
    List<int?> tempo = const [],
    String? pausedRepPosition,
    int? pausedRepSeconds,
    String? assistanceMode,
    double? assistanceKg,
    double? incrementKg,
    bool allowZeroReps = false,
  }) {
    _parseB02OptionalEnum(owner, loadBasis, B02LoadBasis.parse);
    _parseB02OptionalEnum(owner, effortMode, B02EffortMode.parse);
    _parseB02OptionalEnum(owner, pausedRepPosition, B02PausedRepPosition.parse);
    _parseB02OptionalEnum(owner, assistanceMode, B02AssistanceMode.parse);
    _require(
      targetLoadKg == null || targetLoadKg >= 0,
      '$owner has a negative load',
    );
    if (targetRepsMin != null) {
      _require(
        allowZeroReps ? targetRepsMin >= 0 : targetRepsMin >= 1,
        '$owner has invalid minimum reps',
      );
    }
    if (targetRepsMax != null) {
      _require(targetRepsMax >= 1, '$owner has invalid maximum reps');
    }
    _require(
      targetRepsMin == null ||
          targetRepsMax == null ||
          targetRepsMin <= targetRepsMax,
      '$owner has a minimum reps value above its maximum',
    );
    _require(
      targetRpe == null || (targetRpe >= 1 && targetRpe <= 10),
      '$owner has invalid RPE',
    );
    _require(
      incrementKg == null || incrementKg > 0,
      '$owner has invalid increment',
    );
    if (tempo.isNotEmpty) {
      final hasTempo = tempo.any((value) => value != null);
      _require(
        !hasTempo || tempo.every((value) => value != null),
        '$owner has incomplete tempo values',
      );
      if (hasTempo) {
        _require(
          tempo.every((value) => value! >= 0),
          '$owner has negative tempo values',
        );
        _require(
          tempo.any((value) => value! > 0),
          '$owner tempo cannot contain four zero values',
        );
      }
    }
    _require(
      (pausedRepPosition == null) == (pausedRepSeconds == null),
      '$owner paused-rep fields must be provided together',
    );
    _require(
      pausedRepSeconds == null || pausedRepSeconds >= 1,
      '$owner has invalid paused-rep duration',
    );
    _require(
      (assistanceMode == null) == (assistanceKg == null),
      '$owner assisted-rep fields must be provided together',
    );
    _require(
      assistanceKg == null || assistanceKg > 0,
      '$owner has invalid assistance load',
    );
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
  Future<void> restoreToDatabase(AppDatabase db, [SharedPreferences? prefs]) =>
      _restoreToDatabase(db, prefs, null, null);

  /// Internal extension seam for a newer versioned graph.  It keeps the
  /// extension inside this restore's transaction and preference compensation
  /// protocol without changing the v5-v7 public call shape.
  Future<void> restoreToDatabaseWithAdditionalMutation(
    AppDatabase db, {
    SharedPreferences? prefs,
    required BackupAdditionalMutation additionalMutation,
  }) => _restoreToDatabase(db, prefs, null, additionalMutation);

  /// Test-only entry point for the stage-aware B03 fixture harness. Production
  /// callers use [restoreToDatabase], leaving the injector absent.
  Future<void> restoreToDatabaseWithFailureInjector(
    AppDatabase db, {
    SharedPreferences? prefs,
    required BackupRestoreFailureInjector failureInjector,
    BackupAdditionalMutation? additionalMutation,
  }) => _restoreToDatabase(db, prefs, failureInjector, additionalMutation);

  Future<void> _restoreToDatabase(
    AppDatabase db,
    SharedPreferences? prefs,
    BackupRestoreFailureInjector? failureInjector,
    BackupAdditionalMutation? additionalMutation,
  ) async {
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
      if (version >= 7) {
        final customExerciseStableIds = customExercises
            .map((exercise) => exercise.stableId)
            .whereType<String>()
            .toSet();
        _validateB02Graph({
          ...seededExerciseStableIds,
          ...customExerciseStableIds,
        });
      }
    }

    if (failureInjector != null) {
      await failureInjector(
        BackupRestoreFailureStage.relationshipPrevalidation,
      );
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
        if (failureInjector != null) {
          await failureInjector(BackupRestoreFailureStage.preferenceWrite);
        }
      }

      // 3. Perform DB deletion and remapped insertion inside one single transaction.
      await db.transaction(() async {
        if (version >= 7) {
          // B02 children must be removed before their parent sessions and
          // prescriptions. Muscle catalog rows are deliberately retained so
          // unknown/legacy catalog data survives a restore; v7 mappings are
          // then replaced from the validated backup graph.
          await db.delete(db.performedRestPeriods).go();
          await db.delete(db.exerciseTargetRecommendations).go();
          await db.delete(db.performedSetSegments).go();
          await db.delete(db.performedSets).go();
          await db.delete(db.performedExercises).go();
          await db.delete(db.performedExerciseGroups).go();
          await db.delete(db.cardioIntervals).go();
          await db.delete(db.cardioSessionDetails).go();
          await db.delete(db.mobilitySessionDetails).go();
          await db.delete(db.exerciseMuscleMappings).go();
          await db.delete(db.exerciseGroupMembers).go();
          await db.delete(db.strengthSetPrescriptions).go();
          await db.delete(db.exerciseGroups).go();
        }
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
        if (failureInjector != null) {
          await failureInjector(BackupRestoreFailureStage.databaseMutation);
        }
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

        if (version >= 7) {
          for (final muscle in muscles) {
            await db
                .into(db.muscles)
                .insert(
                  muscle.toCompanion(true),
                  mode: InsertMode.insertOrReplace,
                );
          }
          for (final mapping in exerciseMuscleMappings) {
            await db
                .into(db.exerciseMuscleMappings)
                .insert(
                  mapping.toCompanion(true),
                  mode: InsertMode.insertOrReplace,
                );
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
          if (version >= 7) {
            await _insertB02PlanGraph(db);
          }
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
                  activityType: Value(
                    version >= 7
                        ? s.activityType
                        : B02ActivityType.legacy.dbValue,
                  ),
                  activitySchemaVersion: Value(
                    version >= 7 ? s.activitySchemaVersion : 1,
                  ),
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

        if (version >= 7) {
          await _insertB02ExecutionGraph(db, sessionIdMap);
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
                  activityType: Value(
                    version >= 7
                        ? d.activityType
                        : B02ActivityType.legacy.dbValue,
                  ),
                  executionStateJson: Value(
                    version >= 7 ? d.executionStateJson : null,
                  ),
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

        if (additionalMutation != null) {
          await additionalMutation(db);
        }

        if (failureInjector != null) {
          await failureInjector(
            BackupRestoreFailureStage.beforeTransactionCommit,
          );
        }
      });
    } catch (e) {
      // Revert every managed preference, including keys created by this restore.
      if (prefs != null && oldPrefValues.isNotEmpty) {
        await _restorePreferences(
          prefs,
          oldPrefValues,
          onEntryRestored: failureInjector == null
              ? null
              : () => failureInjector(
                  BackupRestoreFailureStage.preferenceRestore,
                ),
        );
      }
      rethrow;
    }
  }

  Future<void> _insertB02PlanGraph(AppDatabase db) async {
    for (final row in exerciseGroups) {
      await db.into(db.exerciseGroups).insert(row.toCompanion(true));
    }
    for (final row in exerciseGroupMembers) {
      await db.into(db.exerciseGroupMembers).insert(row.toCompanion(true));
    }
    for (final row in strengthSetPrescriptions) {
      await db.into(db.strengthSetPrescriptions).insert(row.toCompanion(true));
    }
  }

  Future<void> _insertB02ExecutionGraph(
    AppDatabase db,
    Map<int, int> sessionIdMap,
  ) async {
    for (final row in cardioSessionDetails) {
      await db
          .into(db.cardioSessionDetails)
          .insert(
            row
                .toCompanion(true)
                .copyWith(
                  sessionId: Value(
                    sessionIdMap[row.sessionId] ?? row.sessionId,
                  ),
                ),
          );
    }
    for (final row in cardioIntervals) {
      await db
          .into(db.cardioIntervals)
          .insert(
            row
                .toCompanion(true)
                .copyWith(
                  cardioSessionId: Value(
                    sessionIdMap[row.cardioSessionId] ?? row.cardioSessionId,
                  ),
                ),
          );
    }
    for (final row in mobilitySessionDetails) {
      await db
          .into(db.mobilitySessionDetails)
          .insert(
            row
                .toCompanion(true)
                .copyWith(
                  sessionId: Value(
                    sessionIdMap[row.sessionId] ?? row.sessionId,
                  ),
                ),
          );
    }
    for (final row in performedExerciseGroups) {
      await db
          .into(db.performedExerciseGroups)
          .insert(
            row
                .toCompanion(true)
                .copyWith(
                  sessionId: Value(
                    sessionIdMap[row.sessionId] ?? row.sessionId,
                  ),
                ),
          );
    }
    for (final row in performedExercises) {
      await db
          .into(db.performedExercises)
          .insert(
            row
                .toCompanion(true)
                .copyWith(
                  sessionId: Value(
                    sessionIdMap[row.sessionId] ?? row.sessionId,
                  ),
                ),
          );
    }
    for (final row in performedSets) {
      await db.into(db.performedSets).insert(row.toCompanion(true));
    }
    for (final row in performedSetSegments) {
      await db.into(db.performedSetSegments).insert(row.toCompanion(true));
    }
    for (final row in performedRestPeriods) {
      await db
          .into(db.performedRestPeriods)
          .insert(
            row
                .toCompanion(true)
                .copyWith(
                  sessionId: Value(
                    sessionIdMap[row.sessionId] ?? row.sessionId,
                  ),
                ),
          );
    }
    for (final row in exerciseTargetRecommendations) {
      await db
          .into(db.exerciseTargetRecommendations)
          .insert(row.toCompanion(true));
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
    Map<String, _PreferenceSnapshot> snapshots, {
    Future<void> Function()? onEntryRestored,
  }) async {
    Object? firstFailure;
    StackTrace? firstFailureStack;
    for (final entry in snapshots.entries) {
      try {
        final restored = entry.value.existed
            ? await _writePreference(prefs, entry.key, entry.value.value)
            : await prefs.remove(entry.key);
        if (!restored) {
          throw StateError('Failed to roll back preference "${entry.key}".');
        }
      } catch (error, stackTrace) {
        firstFailure ??= error;
        firstFailureStack ??= stackTrace;
      }
      if (onEntryRestored != null) {
        try {
          await onEntryRestored();
        } catch (error, stackTrace) {
          firstFailure ??= error;
          firstFailureStack ??= stackTrace;
        }
      }
    }
    if (firstFailure != null) {
      Error.throwWithStackTrace(firstFailure, firstFailureStack!);
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
      if (data.version >= 7) ...{
        'exercise_groups': data.exerciseGroups.length,
        'exercise_group_members': data.exerciseGroupMembers.length,
        'strength_set_prescriptions': data.strengthSetPrescriptions.length,
        'cardio_session_details': data.cardioSessionDetails.length,
        'cardio_intervals': data.cardioIntervals.length,
        'mobility_session_details': data.mobilitySessionDetails.length,
        'performed_exercise_groups': data.performedExerciseGroups.length,
        'performed_exercises': data.performedExercises.length,
        'exercise_target_recommendations':
            data.exerciseTargetRecommendations.length,
        'performed_sets': data.performedSets.length,
        'performed_set_segments': data.performedSetSegments.length,
        'performed_rest_periods': data.performedRestPeriods.length,
        'muscles': data.muscles.length,
        'exercise_muscle_mappings': data.exerciseMuscleMappings.length,
      },
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
    if (version == null || version < 3 || version > 8) {
      throw FormatException(
        'Unsupported backup envelope version ${json['version']} (latest supported is 8).',
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
      timestamp: (json['timestamp'] as String?) != null
          ? parseLegacyBackupTimestamp(
              json['timestamp'] as String,
            ).toIso8601String()
          : DateTime.now().toUtc().toIso8601String(),
      isEncrypted: json['is_encrypted'] as bool? ?? false,
      checksum: expectedChecksum ?? '',
      profileName: json['profile_name'] as String? ?? 'User Profile',
      tableCounts: counts,
      payload: rawPayload,
    );
  }
}
