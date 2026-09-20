import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_preferences_keys.dart';
import '../../core/fixtures/b02_muscle_catalog.dart';
import '../../core/fixtures/equipment_fixtures.dart';
import '../../core/fixtures/exercise_identity_fixtures.dart';
import '../../core/fixtures/food_identity_manifest.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/services/platform_storage_protection.dart';
import '../../core/utils/app_logger.dart';
import '../models/b02_execution_models.dart';
import 'b01_legacy_import_support.dart';
import 'tables/achievement_tables.dart';
import 'tables/b02_activity_tables.dart';
import 'tables/b05_ui_tables.dart';
import 'tables/food_tables.dart';
import 'tables/health_tables.dart';
import 'tables/hydration_tables.dart';
import 'tables/nutrition_tables.dart';
import 'tables/settings_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/training_program_tables.dart';
import 'tables/user_tables.dart';
import 'tables/workout_tables.dart';

part 'app_database.g.dart';
part 'connection/database_connection.dart';
part 'seeders/database_seeders.dart';
part 'migrations/schema_migrations.dart';

// B02 schema v16 retains the complete B01 graph and adds typed activity
// storage. B02-02 deliberately does not write or infer any B02 execution row.

/// Test-only boundaries for the v15 -> v16 migration.
///
/// [beforeTransactionCommit] is the last supported injectable boundary. Drift
/// does not expose a callback after the underlying SQLite COMMIT, so the
/// harness deliberately describes this as a pre-commit boundary rather than
/// claiming post-commit coverage.
enum V16MigrationFailureStage {
  validation,
  ddlAndDataMutation,
  beforeTransactionCommit,
}

typedef V16MigrationFailureStageInjector =
    Future<void> Function(V16MigrationFailureStage stage);

/// Test-only boundaries for the v16 -> v17 migration.
///
/// Drift does not expose a callback after SQLite COMMIT, so the final boundary
/// is intentionally the supported pre-commit seam.
enum V17MigrationFailureStage {
  validation,
  ddlAndDataMutation,
  beforeTransactionCommit,
}

typedef V17MigrationFailureStageInjector =
    Future<void> Function(V17MigrationFailureStage stage);

/// Test-only boundaries for the v17 -> v18 migration.
enum V18MigrationFailureStage {
  validation,
  ddlAndDataMutation,
  beforeTransactionCommit,
}

typedef V18MigrationFailureStageInjector =
    Future<void> Function(V18MigrationFailureStage stage);

/// Test-only boundaries for the v18 -> v19 B05 foundation migration.
enum V19MigrationFailureStage {
  validation,
  ddlAndDataMutation,
  beforeTransactionCommit,
}

typedef V19MigrationFailureStageInjector =
    Future<void> Function(V19MigrationFailureStage stage);

@DriftDatabase(
  tables: [
    FoodItems,
    FoodLogs,
    Exercises,
    WorkoutSessions,
    WorkoutSets,
    BodyMeasurements,
    WorkoutRoutines,
    RoutineDays,
    RoutineExercises,
    WorkoutDrafts,
    UserProfiles,
    MealTemplates,
    MealTemplateItems,
    UserSettings,
    DailyHydrations,
    HealthProvenances,
    AchievementUnlocks,
    Programs,
    ProgramVersions,
    ProgramBlocks,
    ProgramWeeks,
    SessionTemplates,
    ExercisePrescriptions,
    ScheduledSessionOccurrences,
    OccurrenceEvents,
    TrainingPlanSettings,
    EquipmentProfiles,
    EquipmentProfileItems,
    TravelContexts,
    TravelContextOccurrences,
    ExerciseUserPreferences,
    ExerciseSetupValues,
    ExercisePersonalCues,
    LegacyRoutineProgramMappings,
    ExerciseGroups,
    ExerciseGroupMembers,
    StrengthSetPrescriptions,
    CardioSessionDetails,
    CardioIntervals,
    MobilitySessionDetails,
    PerformedExerciseGroups,
    PerformedExercises,
    ExerciseTargetRecommendations,
    PerformedSets,
    PerformedSetSegments,
    PerformedRestPeriods,
    Muscles,
    ExerciseMuscleMappings,
    NutritionFoods,
    NutritionFoodAliases,
    NutritionFoodPreparations,
    NutritionLegacyFoodMappings,
    NutritionNutrientDefinitions,
    NutritionFoodNutrientFacts,
    NutritionQuantityConversions,
    NutritionHouseholdMeasures,
    NutritionPersonalVessels,
    NutritionVesselCalibrations,
    NutritionRecipes,
    NutritionRecipeVersions,
    NutritionRecipeIngredients,
    NutritionUserCorrections,
    NutritionEstimates,
    NutritionEstimateNutrients,
    NutritionThalis,
    NutritionThaliItems,
    NutritionConsumptionSnapshots,
    NutritionSnapshotItems,
    NutritionSnapshotNutrients,
    NutritionFoodConstraintEvidence,
    NutritionConstraintDefinitions,
    NutritionUserConstraints,
    NutritionSnapshotConstraintResults,
    NutritionSnapshotConstraintResultEvidence,
    NutritionGoalVersions,
    CoachingConsentEvents,
    NutritionCoachingPreferences,
    RecoveryObservations,
    ReadinessSnapshots,
    ReadinessSnapshotEvidence,
    Recommendations,
    RecommendationEvidence,
    CoachingEligibilityEvaluations,
    RecommendationFeedback,
    DashboardModulePreferences,
    EducationContentProgress,
    MediaPackPreferences,
    WorkoutPlaylistPreferences,
    OutboxEntries,
    TombstoneEntries,
    CachedRemoteFoods,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : v15MigrationFailureInjector = null,
      v16MigrationFailureInjector = null,
      v16MigrationFailureStageInjector = null,
      v17MigrationFailureStageInjector = null,
      v18MigrationFailureStageInjector = null,
      v19MigrationFailureStageInjector = null,
      schemaVersionOverride = null,
      super(_openConnection());
  AppDatabase.memory({this.schemaVersionOverride})
    : v15MigrationFailureInjector = null,
      v16MigrationFailureInjector = null,
      v16MigrationFailureStageInjector = null,
      v17MigrationFailureStageInjector = null,
      v18MigrationFailureStageInjector = null,
      v19MigrationFailureStageInjector = null,
      super(NativeDatabase.memory());
  AppDatabase.executor(
    super.executor, {
    this.v15MigrationFailureInjector,
    this.v16MigrationFailureInjector,
    this.v16MigrationFailureStageInjector,
    this.v17MigrationFailureStageInjector,
    this.v18MigrationFailureStageInjector,
    this.v19MigrationFailureStageInjector,
    this.schemaVersionOverride,
  });

  /// Test-only hook used to prove the v14 -> v15 upgrade rolls back as one
  /// transaction. It is intentionally invoked only from the migration path.
  final Future<void> Function()? v15MigrationFailureInjector;

  /// Test-only hook used to prove the v15 -> v16 upgrade rolls back its DDL
  /// and compatibility backfill as one transaction.
  final Future<void> Function()? v16MigrationFailureInjector;

  /// Typed test-only seam for proving each supported v15 -> v16 boundary.
  /// Production callers leave this null; it does not alter migration
  /// validation, transaction ownership, or schema versioning.
  final V16MigrationFailureStageInjector? v16MigrationFailureStageInjector;

  /// Typed test-only seam for proving each supported v16 -> v17 boundary.
  final V17MigrationFailureStageInjector? v17MigrationFailureStageInjector;

  /// Typed test-only seam for proving each supported v17 -> v18 boundary.
  final V18MigrationFailureStageInjector? v18MigrationFailureStageInjector;

  /// Typed test-only seam for proving each supported v18 -> v19 boundary.
  final V19MigrationFailureStageInjector? v19MigrationFailureStageInjector;

  /// Test-only read boundary for immutable schema fixtures. It allows
  /// baseline harnesses to inspect a legacy file without triggering the next
  /// migration; production instances always use the current version.
  final int? schemaVersionOverride;

  /// Schema v20 retains the complete B05 graph and adds the bounded B01 plan
  /// end marker used to keep Finish/Leave idempotent without creating a
  /// second active-plan authority.
  @override
  int get schemaVersion => schemaVersionOverride ?? 22;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(foodLogs, foodLogs.mealGroupId);
      }
      if (from < 3) {
        await m.addColumn(workoutSets, workoutSets.rpe);
        await m.addColumn(workoutSets, workoutSets.isWarmUp);
        await m.addColumn(workoutSets, workoutSets.setNotes);
        await m.createTable(workoutDrafts);
      }
      if (from < 4) {
        await m.addColumn(foodLogs, foodLogs.uuid);
        await m.addColumn(workoutSessions, workoutSessions.uuid);
        await m.addColumn(workoutSets, workoutSets.uuid);
      }
      if (from < 5) {
        await m.createTable(userProfiles);
      }
      if (from < 6) {
        await m.createTable(mealTemplates);
        await m.createTable(mealTemplateItems);
        await m.addColumn(workoutSets, workoutSets.setType);
      }
      if (from < 7) {
        // Upsert improved offline food catalog without wiping custom foods
        // or breaking existing food_logs foreign keys for matched names.
        await upsertSeededFoodsFromAsset();
      }
      if (from < 8) {
        await m.addColumn(foodItems, foodItems.brand);
        await m.addColumn(foodItems, foodItems.regionPack);
      }
      if (from < 9) {
        await m.addColumn(workoutSets, workoutSets.durationSeconds);
        await m.addColumn(workoutSets, workoutSets.distanceKm);
        await m.addColumn(workoutSets, workoutSets.inclinePercentage);
      }
      if (from < 10) {
        await m.createTable(userSettings);
      }
      if (from < 11) {
        await upsertSeededFoodsFromAsset();
        await seedExercisesFromAsset();
      }
      if (from < 12) {
        // Idempotent re-seed of exercises so upgrades that previously
        // swallowed a UNIQUE-constraint failure now populate the library.
        await upsertSeededExercisesFromAsset();
      }
      if (from < 13) {
        // v12's re-seed still failed silently due to the muscle_groups
        // type-cast bug fixed above. Re-run now that it's actually fixed
        // so installs sitting on an empty exercise table get populated.
        await upsertSeededExercisesFromAsset();
      }
      if (from < 14) {
        await m.createTable(dailyHydrations);
        await m.createTable(healthProvenances);
        await m.createTable(achievementUnlocks);
        await m.addColumn(userProfiles, userProfiles.name);
        await m.addColumn(userProfiles, userProfiles.equipmentAccess);
        await m.addColumn(userProfiles, userProfiles.injuriesLimitations);
        await _migrateLegacyHydrationPreferencesToDatabase();
      }
      if (from < 15) {
        await _migrateV14ToV15(m);
      }
      if (from < 16) {
        await _migrateV15ToV16(m);
      }
      if (from < 17 && to >= 17) {
        await _migrateV16ToV17(m);
      }
      if (from < 18 && to >= 18) {
        await _migrateV17ToV18(m);
      }
      if (from < 19 && to >= 19) {
        await _migrateV18ToV19(m);
      }
      if (from < 20 && to >= 20) {
        await _migrateV19ToV20(m);
      }
      if (from < 21 && to >= 21) {
        // V21: durable connected-work tables (PV1-NET-01/SYNC-01/CATALOG-01).
        // All three are device-local (never synced); backup specs are
        // explicit allowlists so no backup migration is required.
        await m.createTable(outboxEntries);
        await m.createTable(tombstoneEntries);
        await m.createTable(cachedRemoteFoods);
      }
      if (from < 22 && to >= 22) {
        await _migrateV21ToV22(m);
      }
    },

    onCreate: (m) async {
      await m.createAll();
      if (schemaVersionOverride == 16) {
        await _dropV17GraphForLegacyFixture();
        await _createV16IndexesAndTriggers();
        await _ensureTrainingPlanSettings();
        await seedFoodsFromAsset();
        await seedExercisesFromAsset();
        await _seedReviewedMuscleCatalogIfPossible();
        return;
      }
      if (schemaVersionOverride == 17) {
        await _dropV18GraphForLegacyFixture();
        await _createV17Indexes();
        await _ensureTrainingPlanSettings();
        await seedFoodsFromAsset();
        await seedExercisesFromAsset();
        await _seedReviewedMuscleCatalogIfPossible();
        return;
      }
      if (schemaVersionOverride == 18) {
        await _dropV19GraphForLegacyFixture();
        await _createV18Indexes();
        return;
      }
      final contracts = await _loadV17Contracts();
      await _createV16IndexesAndTriggers();
      await _createV17Indexes();
      await _createV18Indexes();
      await _createV19Indexes();
      await _seedV17NutrientRegistry(contracts.registry);
      await _seedV17ConstraintTaxonomy();
      // Reviewed legacy mappings require the local integer rows to exist.
      // Seed those rows before the canonical B03 identity graph so a fresh
      // install receives the same mapping authority as an upgraded database.
      await seedFoodsFromAsset();
      await _seedV17FoodIdentity(contracts.manifest);
      await _ensureTrainingPlanSettings();
      await seedExercisesFromAsset();
      await _seedReviewedMuscleCatalogIfPossible();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      if (schemaVersionOverride != 16) {
        await _ensurePreReleaseV17VesselGraph();
        if (await _tableExists('nutrition_foods')) {
          await _repairMissingV17LegacyFoodMappings();
          // Triggers are part of the durable v17 boundary. Reinstall them on
          // every open so a v17 database created before a boundary repair
          // cannot bypass the same checks through raw SQL, restore, or a
          // second writer.
          await _createV17Indexes();
          if (schemaVersionOverride != 17) {
            await _createV18Indexes();
          }
        }
      }
    },
  );
}
