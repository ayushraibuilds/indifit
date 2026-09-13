part of '../app_database.dart';

extension DatabaseMigrations on AppDatabase {
  /// Repairs only the fresh-install seed-order gap where canonical foods were
  /// present but the reviewed legacy mapping table was empty. Existing rows,
  /// identities, nutrition facts, and history are never rewritten.
  Future<void> _repairMissingV17LegacyFoodMappings() async {
    if (!await _tableExists('nutrition_legacy_food_mappings') ||
        !await _tableExists('food_items')) {
      return;
    }
    final mapping = await (select(
      nutritionLegacyFoodMappings,
    )..limit(1)).getSingleOrNull();
    if (mapping != null) return;
    final legacy = await (select(foodItems)..limit(1)).getSingleOrNull();
    if (legacy == null) return;
    final contracts = await _loadV17Contracts();
    await _seedV17FoodIdentity(contracts.manifest);
  }

  /// Applies the accepted B01 graph and imports v14 routine data without
  /// selecting a B01 active version or manufacturing calendar occurrences.
  Future<void> _migrateV14ToV15(Migrator m) async {
    // Drift does not wrap MigrationStrategy callbacks in a transaction. This
    // explicit boundary covers DDL, data backfill, and the schema-version
    // update that happens only after this callback returns successfully.
    await transaction(() async {
      await m.addColumn(exercises, exercises.stableId);
      await _createStableExerciseIdIndex();

      await m.createTable(programs);
      await m.createTable(programVersions);
      await m.createTable(programBlocks);
      await m.createTable(programWeeks);
      await m.createTable(sessionTemplates);
      await m.createTable(exercisePrescriptions);
      await m.createTable(scheduledSessionOccurrences);
      await m.createTable(occurrenceEvents);
      await m.createTable(equipmentProfiles);
      await m.createTable(equipmentProfileItems);
      await m.createTable(trainingPlanSettings);
      await m.createTable(travelContexts);
      await m.createTable(travelContextOccurrences);
      await m.createTable(exerciseUserPreferences);
      await m.createTable(exerciseSetupValues);
      await m.createTable(exercisePersonalCues);
      await m.createTable(legacyRoutineProgramMappings);

      await m.addColumn(workoutSessions, workoutSessions.scheduledOccurrenceId);
      await m.addColumn(workoutSessions, workoutSessions.executionSnapshotJson);
      await m.addColumn(workoutSessions, workoutSessions.executionTimezoneId);
      await m.addColumn(workoutSessions, workoutSessions.completionKind);
      await m.addColumn(workoutSets, workoutSets.exerciseId);
      await m.addColumn(workoutDrafts, workoutDrafts.scheduledOccurrenceId);
      await m.addColumn(workoutDrafts, workoutDrafts.executionSnapshotJson);
      await m.addColumn(workoutDrafts, workoutDrafts.draftSchemaVersion);

      await _createV15IndexesAndTriggers();
      await _backfillStableExerciseIds();
      await _backfillWorkoutSetExerciseIds();
      await _importLegacyRoutinePrograms();
      final defaultProfileId = await _importLegacyEquipmentProfile();
      await _ensureTrainingPlanSettings(defaultProfileId: defaultProfileId);

      final injectedFailure = v15MigrationFailureInjector;
      if (injectedFailure != null) await injectedFailure();
    });
  }

  /// Adds B02 storage without interpreting B01 history. This explicit
  /// transaction covers every v16 DDL statement, the only permitted backfill
  /// (`legacy` activity headers), and migration test injection.
  Future<void> _migrateV15ToV16(Migrator m) async {
    final stageInjector = v16MigrationFailureStageInjector;
    if (stageInjector != null) {
      await stageInjector(V16MigrationFailureStage.validation);
    }

    await transaction(() async {
      // A direct v14 -> v16 upgrade first creates the B01 tables using the
      // current declarations. Check physical columns so it neither attempts a
      // duplicate ALTER nor changes the v15 -> v16 contract for real files.
      if (!await _tableHasColumn('workout_sessions', 'activity_type')) {
        await m.addColumn(workoutSessions, workoutSessions.activityType);
      }
      if (!await _tableHasColumn(
        'workout_sessions',
        'activity_schema_version',
      )) {
        await m.addColumn(
          workoutSessions,
          workoutSessions.activitySchemaVersion,
        );
      }
      if (!await _tableHasColumn('session_templates', 'activity_type')) {
        await m.addColumn(sessionTemplates, sessionTemplates.activityType);
      }
      if (!await _tableHasColumn('session_templates', 'default_rest_seconds')) {
        await m.addColumn(
          sessionTemplates,
          sessionTemplates.defaultRestSeconds,
        );
      }
      if (!await _tableHasColumn('workout_drafts', 'activity_type')) {
        await m.addColumn(workoutDrafts, workoutDrafts.activityType);
      }
      if (!await _tableHasColumn('workout_drafts', 'execution_state_json')) {
        await m.addColumn(workoutDrafts, workoutDrafts.executionStateJson);
      }
      if (!await _tableHasColumn(
        'exercise_user_preferences',
        'warmup_preference',
      )) {
        await m.addColumn(
          exerciseUserPreferences,
          exerciseUserPreferences.warmupPreference,
        );
      }
      if (!await _tableHasColumn(
        'exercise_user_preferences',
        'warmup_set_count',
      )) {
        await m.addColumn(
          exerciseUserPreferences,
          exerciseUserPreferences.warmupSetCount,
        );
      }
      if (!await _tableHasColumn(
        'exercise_user_preferences',
        'custom_rest_seconds',
      )) {
        await m.addColumn(
          exerciseUserPreferences,
          exerciseUserPreferences.customRestSeconds,
        );
      }

      // Parent tables precede their dependants. No B02 data is backfilled:
      // v15 rows lack evidence for groups, rich sets, modalities, mappings,
      // targets, intervals, rest periods, and substitutions.
      await m.createTable(muscles);
      await m.createTable(exerciseGroups);
      await m.createTable(strengthSetPrescriptions);
      await m.createTable(cardioSessionDetails);
      await m.createTable(mobilitySessionDetails);
      await m.createTable(performedExerciseGroups);
      await m.createTable(exerciseMuscleMappings);
      await m.createTable(exerciseGroupMembers);
      await m.createTable(cardioIntervals);
      await m.createTable(performedExercises);
      await m.createTable(exerciseTargetRecommendations);
      await m.createTable(performedSets);
      await m.createTable(performedSetSegments);
      await m.createTable(performedRestPeriods);

      // The `legacy` default is the only historical classification. It is not
      // derived from workout names, old set fields, duration, or provenance.
      await customStatement('''
        UPDATE workout_sessions
        SET activity_type = 'legacy', activity_schema_version = 1
        WHERE activity_type IS NULL OR activity_schema_version IS NULL
      ''');

      await _createV16IndexesAndTriggers();

      // Seed only when every reviewed exercise parent already exists. A
      // legacy-only file therefore receives no fabricated taxonomy/mapping
      // rows, while a canonical catalog is seeded atomically.
      await _seedReviewedMuscleCatalogIfPossible();

      if (stageInjector != null) {
        await stageInjector(V16MigrationFailureStage.ddlAndDataMutation);
        await stageInjector(V16MigrationFailureStage.beforeTransactionCommit);
      }

      final injectedFailure = v16MigrationFailureInjector;
      if (injectedFailure != null) await injectedFailure();
    });
  }

  Future<void> _migrateV16ToV17(Migrator m) async {
    final stageInjector = v17MigrationFailureStageInjector;
    final contracts = await _loadV17Contracts();
    if (stageInjector != null) {
      await stageInjector(V17MigrationFailureStage.validation);
    }

    await transaction(() async {
      // Parent tables are created before dependants. The recipe pointer is
      // intentionally not a database FK, avoiding a mutable FK cycle with
      // immutable recipe versions; repository validation owns that pointer.
      await m.createTable(nutritionFoods);
      await m.createTable(nutritionNutrientDefinitions);
      await m.createTable(nutritionConstraintDefinitions);
      await m.createTable(nutritionHouseholdMeasures);
      await m.createTable(nutritionPersonalVessels);
      await m.createTable(nutritionRecipes);
      await m.createTable(nutritionThalis);
      await m.createTable(nutritionConsumptionSnapshots);

      await m.createTable(nutritionFoodAliases);
      await m.createTable(nutritionFoodPreparations);
      await m.createTable(nutritionLegacyFoodMappings);
      await m.createTable(nutritionFoodNutrientFacts);
      await m.createTable(nutritionQuantityConversions);
      await m.createTable(nutritionVesselCalibrations);
      await m.createTable(nutritionRecipeVersions);
      await m.createTable(nutritionUserCorrections);
      await m.createTable(nutritionEstimates);
      await m.createTable(nutritionThaliItems);
      await m.createTable(nutritionSnapshotItems);
      await m.createTable(nutritionUserConstraints);

      await m.createTable(nutritionEstimateNutrients);
      await m.createTable(nutritionRecipeIngredients);
      await m.createTable(nutritionSnapshotNutrients);
      await m.createTable(nutritionFoodConstraintEvidence);
      await m.createTable(nutritionSnapshotConstraintResults);
      await m.createTable(nutritionSnapshotConstraintResultEvidence);

      await _createV17Indexes();
      await _seedV17NutrientRegistry(contracts.registry);
      await _seedV17ConstraintTaxonomy();
      await _seedV17FoodIdentity(contracts.manifest);

      if (stageInjector != null) {
        await stageInjector(V17MigrationFailureStage.ddlAndDataMutation);
        await stageInjector(V17MigrationFailureStage.beforeTransactionCommit);
      }
    });
  }

  Future<void> _migrateV17ToV18(Migrator m) async {
    final stageInjector = v18MigrationFailureStageInjector;
    if (stageInjector != null) {
      await stageInjector(V18MigrationFailureStage.validation);
    }

    await transaction(() async {
      // B04 adds durable contracts only. No v17 row is interpreted or
      // backfilled, so every new authority starts empty on upgrade.
      await m.createTable(nutritionGoalVersions);
      await m.createTable(coachingConsentEvents);
      await m.createTable(nutritionCoachingPreferences);
      await m.createTable(recoveryObservations);
      await m.createTable(readinessSnapshots);
      await m.createTable(readinessSnapshotEvidence);
      await m.createTable(recommendations);
      await m.createTable(recommendationEvidence);
      await m.createTable(coachingEligibilityEvaluations);
      await m.createTable(recommendationFeedback);
      await _createV18Indexes();

      if (stageInjector != null) {
        await stageInjector(V18MigrationFailureStage.ddlAndDataMutation);
        await stageInjector(V18MigrationFailureStage.beforeTransactionCommit);
      }
    });
  }

  Future<void> _migrateV18ToV19(Migrator m) async {
    final stageInjector = v19MigrationFailureStageInjector;
    if (stageInjector != null) {
      await stageInjector(V19MigrationFailureStage.validation);
    }

    await transaction(() async {
      // B05 stores only portable user intent and versioned content progress.
      // Physical media availability, paths, bytes, and cache state remain
      // device-local derived state and are intentionally absent here.
      await m.createTable(dashboardModulePreferences);
      await m.createTable(educationContentProgress);
      await m.createTable(mediaPackPreferences);
      await m.createTable(workoutPlaylistPreferences);
      await _createV19Indexes();

      if (stageInjector != null) {
        await stageInjector(V19MigrationFailureStage.ddlAndDataMutation);
        await stageInjector(V19MigrationFailureStage.beforeTransactionCommit);
      }
    });
  }

  Future<void> _dropV17GraphForLegacyFixture() async {
    const triggerNames = [
      'nutrition_vessel_volume_only_insert',
      'nutrition_vessel_volume_only_update',
      'nutrition_vessel_calibration_same_vessel_insert',
      'nutrition_vessel_calibration_same_vessel_update',
      'nutrition_vessel_calibration_single_successor_insert',
      'nutrition_vessel_calibration_single_successor_update',
      'nutrition_recipe_current_version_insert',
      'nutrition_recipe_current_version_update',
    ];
    for (final trigger in triggerNames) {
      await customStatement('DROP TRIGGER IF EXISTS $trigger');
    }
    const tables = [
      'nutrition_snapshot_constraint_result_evidence',
      'nutrition_snapshot_constraint_results',
      'nutrition_user_constraints',
      'nutrition_constraint_definitions',
      'nutrition_food_constraint_evidence',
      'nutrition_snapshot_nutrients',
      'nutrition_snapshot_items',
      'nutrition_consumption_snapshots',
      'nutrition_thali_items',
      'nutrition_thalis',
      'nutrition_estimate_nutrients',
      'nutrition_estimates',
      'nutrition_user_corrections',
      'nutrition_recipe_ingredients',
      'nutrition_recipe_versions',
      'nutrition_recipes',
      'nutrition_vessel_calibrations',
      'nutrition_personal_vessels',
      'nutrition_household_measures',
      'nutrition_quantity_conversions',
      'nutrition_food_nutrient_facts',
      'nutrition_nutrient_definitions',
      'nutrition_legacy_food_mappings',
      'nutrition_food_preparations',
      'nutrition_food_aliases',
      'nutrition_foods',
    ];
    for (final table in tables) {
      await customStatement('DROP TABLE IF EXISTS $table');
    }
    await _dropV18GraphForLegacyFixture();
  }

  Future<void> _dropV18GraphForLegacyFixture() async {
    const tables = [
      'workout_playlist_preferences',
      'media_pack_preferences',
      'education_content_progress',
      'dashboard_module_preferences',
      'recommendation_feedback',
      'coaching_eligibility_evaluations',
      'recommendation_evidence',
      'recommendations',
      'readiness_snapshot_evidence',
      'readiness_snapshots',
      'recovery_observations',
      'nutrition_coaching_preferences',
      'coaching_consent_events',
      'nutrition_goal_versions',
    ];
    for (final table in tables) {
      await customStatement('DROP TABLE IF EXISTS $table');
    }
  }

  Future<void> _dropV19GraphForLegacyFixture() async {
    const tables = [
      'workout_playlist_preferences',
      'media_pack_preferences',
      'education_content_progress',
      'dashboard_module_preferences',
    ];
    for (final table in tables) {
      await customStatement('DROP TABLE IF EXISTS $table');
    }
  }

  Future<void> _createV17Indexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS nutrition_foods_kind_lifecycle_idx ON nutrition_foods(kind, lifecycle)',
      'CREATE INDEX IF NOT EXISTS nutrition_foods_source_idx ON nutrition_foods(source_type, source_ref)',
      'CREATE INDEX IF NOT EXISTS nutrition_foods_variant_idx ON nutrition_foods(variant_of_food_id)',
      'CREATE INDEX IF NOT EXISTS nutrition_food_aliases_food_idx ON nutrition_food_aliases(food_id)',
      'CREATE INDEX IF NOT EXISTS nutrition_food_aliases_normalized_idx ON nutrition_food_aliases(normalized_alias, locale)',
      'CREATE INDEX IF NOT EXISTS nutrition_food_preparations_food_idx ON nutrition_food_preparations(food_id, state)',
      'CREATE INDEX IF NOT EXISTS nutrition_legacy_food_mappings_food_idx ON nutrition_legacy_food_mappings(food_id, mapping_status)',
      'CREATE INDEX IF NOT EXISTS nutrition_food_nutrient_facts_current_idx ON nutrition_food_nutrient_facts(food_id, is_current)',
      'CREATE INDEX IF NOT EXISTS nutrition_food_nutrient_facts_nutrient_idx ON nutrition_food_nutrient_facts(nutrient_id)',
      'CREATE INDEX IF NOT EXISTS nutrition_quantity_conversions_food_idx ON nutrition_quantity_conversions(food_id, source_unit, target_unit)',
      'CREATE INDEX IF NOT EXISTS nutrition_personal_vessels_user_idx ON nutrition_personal_vessels(user_id, archived_at)',
      'CREATE INDEX IF NOT EXISTS nutrition_vessel_calibrations_vessel_idx ON nutrition_vessel_calibrations(vessel_id, version)',
      'CREATE INDEX IF NOT EXISTS nutrition_vessel_calibrations_supersedes_idx ON nutrition_vessel_calibrations(supersedes_calibration_id)',
      'CREATE INDEX IF NOT EXISTS nutrition_recipe_versions_recipe_idx ON nutrition_recipe_versions(recipe_id, status)',
      'CREATE INDEX IF NOT EXISTS nutrition_recipe_ingredients_food_idx ON nutrition_recipe_ingredients(food_id)',
      'CREATE INDEX IF NOT EXISTS nutrition_estimates_user_idx ON nutrition_estimates(user_id, created_at)',
      'CREATE INDEX IF NOT EXISTS nutrition_estimate_nutrients_nutrient_idx ON nutrition_estimate_nutrients(nutrient_id)',
      'CREATE INDEX IF NOT EXISTS nutrition_thali_items_food_idx ON nutrition_thali_items(food_id)',
      'CREATE INDEX IF NOT EXISTS nutrition_snapshots_user_time_idx ON nutrition_consumption_snapshots(user_id, logged_at)',
      'CREATE INDEX IF NOT EXISTS nutrition_snapshot_items_food_idx ON nutrition_snapshot_items(food_id)',
      'CREATE INDEX IF NOT EXISTS nutrition_snapshot_nutrients_nutrient_idx ON nutrition_snapshot_nutrients(nutrient_id)',
      'CREATE INDEX IF NOT EXISTS nutrition_food_constraint_evidence_food_idx ON nutrition_food_constraint_evidence(food_id, constraint_key)',
      'CREATE INDEX IF NOT EXISTS nutrition_user_constraints_user_idx ON nutrition_user_constraints(user_id, effective_from)',
      'CREATE INDEX IF NOT EXISTS nutrition_snapshot_constraint_results_snapshot_idx ON nutrition_snapshot_constraint_results(snapshot_id, result)',
      'CREATE INDEX IF NOT EXISTS nutrition_snapshot_constraint_evidence_result_idx ON nutrition_snapshot_constraint_result_evidence(result_id)',
      'CREATE INDEX IF NOT EXISTS nutrition_snapshot_constraint_evidence_food_idx ON nutrition_snapshot_constraint_result_evidence(food_id)',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_vessel_calibration_same_vessel_insert
         BEFORE INSERT ON nutrition_vessel_calibrations
         WHEN NEW.supersedes_calibration_id IS NOT NULL AND
           (SELECT vessel_id FROM nutrition_vessel_calibrations
            WHERE id = NEW.supersedes_calibration_id) <> NEW.vessel_id
         BEGIN SELECT RAISE(ABORT, 'Calibration ancestry must remain within one vessel'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_vessel_calibration_same_vessel_update
         BEFORE UPDATE OF vessel_id, supersedes_calibration_id ON nutrition_vessel_calibrations
         WHEN NEW.supersedes_calibration_id IS NOT NULL AND
           (SELECT vessel_id FROM nutrition_vessel_calibrations
            WHERE id = NEW.supersedes_calibration_id) <> NEW.vessel_id
         BEGIN SELECT RAISE(ABORT, 'Calibration ancestry must remain within one vessel'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_vessel_calibration_single_successor_insert
         BEFORE INSERT ON nutrition_vessel_calibrations
         WHEN NEW.supersedes_calibration_id IS NOT NULL AND EXISTS
           (SELECT 1 FROM nutrition_vessel_calibrations
            WHERE supersedes_calibration_id = NEW.supersedes_calibration_id)
         BEGIN SELECT RAISE(ABORT, 'A calibration may have only one successor'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_vessel_calibration_single_successor_update
         BEFORE UPDATE OF supersedes_calibration_id ON nutrition_vessel_calibrations
         WHEN NEW.supersedes_calibration_id IS NOT NULL AND EXISTS
           (SELECT 1 FROM nutrition_vessel_calibrations
            WHERE supersedes_calibration_id = NEW.supersedes_calibration_id
              AND id <> NEW.id)
         BEGIN SELECT RAISE(ABORT, 'A calibration may have only one successor'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_recipe_current_version_insert
         BEFORE INSERT ON nutrition_recipes
         WHEN NEW.current_version_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_recipe_versions WHERE id = NEW.current_version_id AND recipe_id = NEW.id)
         BEGIN SELECT RAISE(ABORT, 'Recipe current version must belong to the recipe'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_recipe_current_version_update
         BEFORE UPDATE OF current_version_id ON nutrition_recipes
         WHEN NEW.current_version_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_recipe_versions WHERE id = NEW.current_version_id AND recipe_id = NEW.id)
         BEGIN SELECT RAISE(ABORT, 'Recipe current version must belong to the recipe'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_food_fact_preparation_owner_insert
         BEFORE INSERT ON nutrition_food_nutrient_facts
         WHEN NEW.preparation_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_food_preparations
            WHERE id = NEW.preparation_id AND food_id = NEW.food_id)
         BEGIN SELECT RAISE(ABORT, 'Nutrient fact preparation must belong to its food'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_food_fact_preparation_owner_update
         BEFORE UPDATE OF food_id, preparation_id ON nutrition_food_nutrient_facts
         WHEN NEW.preparation_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_food_preparations
            WHERE id = NEW.preparation_id AND food_id = NEW.food_id)
         BEGIN SELECT RAISE(ABORT, 'Nutrient fact preparation must belong to its food'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_conversion_preparation_owner_insert
         BEFORE INSERT ON nutrition_quantity_conversions
         WHEN NEW.preparation_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_food_preparations
            WHERE id = NEW.preparation_id AND food_id = NEW.food_id)
         BEGIN SELECT RAISE(ABORT, 'Conversion preparation must belong to its food'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_conversion_preparation_owner_update
         BEFORE UPDATE OF food_id, preparation_id ON nutrition_quantity_conversions
         WHEN NEW.preparation_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_food_preparations
            WHERE id = NEW.preparation_id AND food_id = NEW.food_id)
         BEGIN SELECT RAISE(ABORT, 'Conversion preparation must belong to its food'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_ingredient_preparation_owner_insert
         BEFORE INSERT ON nutrition_recipe_ingredients
         WHEN NEW.preparation_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_food_preparations
            WHERE id = NEW.preparation_id AND food_id = NEW.food_id)
         BEGIN SELECT RAISE(ABORT, 'Ingredient preparation must belong to its food'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_ingredient_preparation_owner_update
         BEFORE UPDATE OF food_id, preparation_id ON nutrition_recipe_ingredients
         WHEN NEW.preparation_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_food_preparations
            WHERE id = NEW.preparation_id AND food_id = NEW.food_id)
         BEGIN SELECT RAISE(ABORT, 'Ingredient preparation must belong to its food'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_item_preparation_owner_insert
         BEFORE INSERT ON nutrition_snapshot_items
         WHEN NEW.preparation_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_food_preparations
            WHERE id = NEW.preparation_id AND food_id = NEW.food_id)
         BEGIN SELECT RAISE(ABORT, 'Snapshot preparation must belong to its food'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_item_preparation_owner_update
         BEFORE UPDATE OF food_id, preparation_id ON nutrition_snapshot_items
         WHEN NEW.preparation_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_food_preparations
            WHERE id = NEW.preparation_id AND food_id = NEW.food_id)
         BEGIN SELECT RAISE(ABORT, 'Snapshot preparation must belong to its food'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_estimate_nutrient_registry_unit_insert
         BEFORE INSERT ON nutrition_estimate_nutrients
         WHEN NOT EXISTS
           (SELECT 1 FROM nutrition_nutrient_definitions
            WHERE id = NEW.nutrient_id AND unit = NEW.unit)
         BEGIN SELECT RAISE(ABORT, 'Estimate nutrient unit must match the registry'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_estimate_nutrient_registry_unit_update
         BEFORE UPDATE OF nutrient_id, unit ON nutrition_estimate_nutrients
         WHEN NOT EXISTS
           (SELECT 1 FROM nutrition_nutrient_definitions
            WHERE id = NEW.nutrient_id AND unit = NEW.unit)
         BEGIN SELECT RAISE(ABORT, 'Estimate nutrient unit must match the registry'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_nutrient_registry_unit_insert
         BEFORE INSERT ON nutrition_snapshot_nutrients
         WHEN NOT EXISTS
           (SELECT 1 FROM nutrition_nutrient_definitions
            WHERE id = NEW.nutrient_id AND unit = NEW.unit)
         BEGIN SELECT RAISE(ABORT, 'Snapshot nutrient unit must match the registry'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_nutrient_registry_unit_update
         BEFORE UPDATE OF nutrient_id, unit ON nutrition_snapshot_nutrients
         WHEN NOT EXISTS
           (SELECT 1 FROM nutrition_nutrient_definitions
            WHERE id = NEW.nutrient_id AND unit = NEW.unit)
         BEGIN SELECT RAISE(ABORT, 'Snapshot nutrient unit must match the registry'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_nutrient_item_owner_insert
         BEFORE INSERT ON nutrition_snapshot_nutrients
         WHEN NEW.item_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_snapshot_items
            WHERE id = NEW.item_id AND snapshot_id = NEW.snapshot_id)
         BEGIN SELECT RAISE(ABORT, 'Snapshot nutrient item must belong to its snapshot'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_nutrient_item_owner_update
         BEFORE UPDATE OF snapshot_id, item_id ON nutrition_snapshot_nutrients
         WHEN NEW.item_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_snapshot_items
            WHERE id = NEW.item_id AND snapshot_id = NEW.snapshot_id)
         BEGIN SELECT RAISE(ABORT, 'Snapshot nutrient item must belong to its snapshot'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_food_nutrient_state_insert
         BEFORE INSERT ON nutrition_food_nutrient_facts
         WHEN (NEW.status = 'known' AND NEW.amount IS NULL)
           OR (NEW.status = 'known_zero' AND
               (NEW.amount IS NULL OR NEW.amount <> 0 OR
                (NEW.lower IS NOT NULL AND NEW.lower <> 0) OR
                (NEW.upper IS NOT NULL AND NEW.upper <> 0)))
           OR (NEW.status = 'estimated' AND NEW.amount IS NULL AND
               NEW.lower IS NULL AND NEW.upper IS NULL)
         BEGIN SELECT RAISE(ABORT, 'Invalid food nutrient state'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_food_nutrient_state_update
         BEFORE UPDATE OF status, amount, lower, upper
         ON nutrition_food_nutrient_facts
         WHEN (NEW.status = 'known' AND NEW.amount IS NULL)
           OR (NEW.status = 'known_zero' AND
               (NEW.amount IS NULL OR NEW.amount <> 0 OR
                (NEW.lower IS NOT NULL AND NEW.lower <> 0) OR
                (NEW.upper IS NOT NULL AND NEW.upper <> 0)))
           OR (NEW.status = 'estimated' AND NEW.amount IS NULL AND
               NEW.lower IS NULL AND NEW.upper IS NULL)
         BEGIN SELECT RAISE(ABORT, 'Invalid food nutrient state'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_estimate_nutrient_state_insert
         BEFORE INSERT ON nutrition_estimate_nutrients
         WHEN (NEW.status = 'known' AND NEW.amount IS NULL)
           OR (NEW.status = 'known_zero' AND
               (NEW.amount IS NULL OR NEW.amount <> 0 OR
                (NEW.lower IS NOT NULL AND NEW.lower <> 0) OR
                (NEW.upper IS NOT NULL AND NEW.upper <> 0)))
           OR (NEW.status = 'estimated' AND NEW.amount IS NULL AND
               NEW.lower IS NULL AND NEW.upper IS NULL)
         BEGIN SELECT RAISE(ABORT, 'Invalid estimate nutrient state'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_estimate_nutrient_state_update
         BEFORE UPDATE OF status, amount, lower, upper
         ON nutrition_estimate_nutrients
         WHEN (NEW.status = 'known' AND NEW.amount IS NULL)
           OR (NEW.status = 'known_zero' AND
               (NEW.amount IS NULL OR NEW.amount <> 0 OR
                (NEW.lower IS NOT NULL AND NEW.lower <> 0) OR
                (NEW.upper IS NOT NULL AND NEW.upper <> 0)))
           OR (NEW.status = 'estimated' AND NEW.amount IS NULL AND
               NEW.lower IS NULL AND NEW.upper IS NULL)
         BEGIN SELECT RAISE(ABORT, 'Invalid estimate nutrient state'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_nutrient_state_insert
         BEFORE INSERT ON nutrition_snapshot_nutrients
         WHEN (NEW.status = 'known' AND NEW.amount IS NULL)
           OR (NEW.status = 'known_zero' AND
               (NEW.amount IS NULL OR NEW.amount <> 0 OR
                (NEW.lower IS NOT NULL AND NEW.lower <> 0) OR
                (NEW.upper IS NOT NULL AND NEW.upper <> 0)))
           OR (NEW.status = 'estimated' AND NEW.amount IS NULL AND
               NEW.lower IS NULL AND NEW.upper IS NULL)
         BEGIN SELECT RAISE(ABORT, 'Invalid snapshot nutrient state'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_nutrient_state_update
         BEFORE UPDATE OF status, amount, lower, upper
         ON nutrition_snapshot_nutrients
         WHEN (NEW.status = 'known' AND NEW.amount IS NULL)
           OR (NEW.status = 'known_zero' AND
               (NEW.amount IS NULL OR NEW.amount <> 0 OR
                (NEW.lower IS NOT NULL AND NEW.lower <> 0) OR
                (NEW.upper IS NOT NULL AND NEW.upper <> 0)))
           OR (NEW.status = 'estimated' AND NEW.amount IS NULL AND
               NEW.lower IS NULL AND NEW.upper IS NULL)
         BEGIN SELECT RAISE(ABORT, 'Invalid snapshot nutrient state'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_estimate_supersession_owner_insert
         BEFORE INSERT ON nutrition_estimates
         WHEN NEW.supersedes_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_estimates
            WHERE id = NEW.supersedes_id AND user_id = NEW.user_id)
         BEGIN SELECT RAISE(ABORT, 'Estimate ancestry must remain within one user'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_estimate_supersession_owner_update
         BEFORE UPDATE OF user_id, supersedes_id ON nutrition_estimates
         WHEN NEW.supersedes_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_estimates
            WHERE id = NEW.supersedes_id AND user_id = NEW.user_id)
         BEGIN SELECT RAISE(ABORT, 'Estimate ancestry must remain within one user'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_thali_recipe_owner_insert
         BEFORE INSERT ON nutrition_thali_items
         WHEN NEW.recipe_version_id IS NOT NULL AND NOT EXISTS
           (SELECT 1
            FROM nutrition_recipe_versions rv
            JOIN nutrition_recipes r ON r.id = rv.recipe_id
            JOIN nutrition_thalis t ON t.id = NEW.thali_id
            WHERE rv.id = NEW.recipe_version_id AND r.user_id = t.user_id)
         BEGIN SELECT RAISE(ABORT, 'Thali recipe must belong to the thali user'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_thali_recipe_owner_update
         BEFORE UPDATE OF thali_id, recipe_version_id ON nutrition_thali_items
         WHEN NEW.recipe_version_id IS NOT NULL AND NOT EXISTS
           (SELECT 1
            FROM nutrition_recipe_versions rv
            JOIN nutrition_recipes r ON r.id = rv.recipe_id
            JOIN nutrition_thalis t ON t.id = NEW.thali_id
            WHERE rv.id = NEW.recipe_version_id AND r.user_id = t.user_id)
         BEGIN SELECT RAISE(ABORT, 'Thali recipe must belong to the thali user'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_recipe_owner_insert
         BEFORE INSERT ON nutrition_consumption_snapshots
         WHEN NEW.recipe_version_id IS NOT NULL AND NOT EXISTS
           (SELECT 1
            FROM nutrition_recipe_versions rv
            JOIN nutrition_recipes r ON r.id = rv.recipe_id
            WHERE rv.id = NEW.recipe_version_id AND r.user_id = NEW.user_id)
         BEGIN SELECT RAISE(ABORT, 'Snapshot recipe must belong to the snapshot user'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_recipe_owner_update
         BEFORE UPDATE OF user_id, recipe_version_id ON nutrition_consumption_snapshots
         WHEN NEW.recipe_version_id IS NOT NULL AND NOT EXISTS
           (SELECT 1
            FROM nutrition_recipe_versions rv
            JOIN nutrition_recipes r ON r.id = rv.recipe_id
            WHERE rv.id = NEW.recipe_version_id AND r.user_id = NEW.user_id)
         BEGIN SELECT RAISE(ABORT, 'Snapshot recipe must belong to the snapshot user'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_thali_owner_insert
         BEFORE INSERT ON nutrition_consumption_snapshots
         WHEN NEW.thali_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_thalis
            WHERE id = NEW.thali_id AND user_id = NEW.user_id)
         BEGIN SELECT RAISE(ABORT, 'Snapshot thali must belong to the snapshot user'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_thali_owner_update
         BEFORE UPDATE OF user_id, thali_id ON nutrition_consumption_snapshots
         WHEN NEW.thali_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_thalis
            WHERE id = NEW.thali_id AND user_id = NEW.user_id)
         BEGIN SELECT RAISE(ABORT, 'Snapshot thali must belong to the snapshot user'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_constraint_owner_insert
         BEFORE INSERT ON nutrition_snapshot_constraint_results
         WHEN NOT EXISTS
           (SELECT 1
            FROM nutrition_consumption_snapshots s
            JOIN nutrition_user_constraints c ON c.id = NEW.constraint_id
            WHERE s.id = NEW.snapshot_id AND c.user_id = s.user_id)
         BEGIN SELECT RAISE(ABORT, 'Snapshot constraint must belong to the snapshot user'); END''',
      '''CREATE TRIGGER IF NOT EXISTS nutrition_snapshot_constraint_owner_update
         BEFORE UPDATE OF snapshot_id, constraint_id ON nutrition_snapshot_constraint_results
         WHEN NOT EXISTS
           (SELECT 1
            FROM nutrition_consumption_snapshots s
            JOIN nutrition_user_constraints c ON c.id = NEW.constraint_id
            WHERE s.id = NEW.snapshot_id AND c.user_id = s.user_id)
         BEGIN SELECT RAISE(ABORT, 'Snapshot constraint must belong to the snapshot user'); END''',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  Future<void> _createV18Indexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS nutrition_goal_versions_user_effective_idx ON nutrition_goal_versions(user_id, effective_from_local_date, effective_to_local_date)',
      'CREATE INDEX IF NOT EXISTS coaching_consent_events_user_date_idx ON coaching_consent_events(user_id, consent_category, local_date, timestamp_utc)',
      'CREATE INDEX IF NOT EXISTS nutrition_coaching_preferences_user_idx ON nutrition_coaching_preferences(user_id)',
      'CREATE INDEX IF NOT EXISTS recovery_observations_user_time_kind_idx ON recovery_observations(user_id, observed_at_utc, kind)',
      'CREATE INDEX IF NOT EXISTS recovery_observations_user_date_idx ON recovery_observations(user_id, local_date, freshness)',
      'CREATE INDEX IF NOT EXISTS readiness_snapshots_user_date_version_idx ON readiness_snapshots(user_id, local_date, calculation_version)',
      'CREATE INDEX IF NOT EXISTS readiness_snapshot_evidence_snapshot_idx ON readiness_snapshot_evidence(readiness_snapshot_id, observation_id)',
      'CREATE INDEX IF NOT EXISTS recommendations_user_scope_period_status_idx ON recommendations(user_id, scope, local_period_start, local_period_end, status)',
      'CREATE INDEX IF NOT EXISTS recommendations_goal_readiness_idx ON recommendations(goal_version_id, readiness_snapshot_id)',
      'CREATE INDEX IF NOT EXISTS recommendation_evidence_recommendation_source_idx ON recommendation_evidence(recommendation_id, source_type, source_id)',
      'CREATE INDEX IF NOT EXISTS coaching_eligibility_evaluations_user_date_result_idx ON coaching_eligibility_evaluations(user_id, evaluation_local_date, result)',
      'CREATE INDEX IF NOT EXISTS coaching_eligibility_evaluations_goal_recommendation_idx ON coaching_eligibility_evaluations(goal_version_id, recommendation_id)',
      'CREATE INDEX IF NOT EXISTS recommendation_feedback_recommendation_time_idx ON recommendation_feedback(recommendation_id, created_at_utc)',
      'CREATE INDEX IF NOT EXISTS recommendation_feedback_user_time_idx ON recommendation_feedback(user_id, created_at_utc)',
      '''CREATE TRIGGER IF NOT EXISTS b04_goal_versions_append_only_update
         BEFORE UPDATE ON nutrition_goal_versions
         BEGIN SELECT RAISE(ABORT, 'B04 goal versions are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_goal_versions_append_only_delete
         BEFORE DELETE ON nutrition_goal_versions
         BEGIN SELECT RAISE(ABORT, 'B04 goal versions are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_goal_versions_owner_insert
         BEFORE INSERT ON nutrition_goal_versions
         WHEN NEW.supersedes_goal_version_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_goal_versions
            WHERE id = NEW.supersedes_goal_version_id
              AND user_id = NEW.user_id
              AND version_number < NEW.version_number)
         BEGIN SELECT RAISE(ABORT, 'Goal supersession must remain within one user and advance its version'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_goal_versions_owner_update
         BEFORE UPDATE OF user_id, supersedes_goal_version_id ON nutrition_goal_versions
         WHEN NEW.supersedes_goal_version_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_goal_versions
            WHERE id = NEW.supersedes_goal_version_id
              AND user_id = NEW.user_id
              AND version_number < NEW.version_number)
         BEGIN SELECT RAISE(ABORT, 'Goal supersession must remain within one user and advance its version'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_consent_events_append_only_update
         BEFORE UPDATE ON coaching_consent_events
         BEGIN SELECT RAISE(ABORT, 'B04 consent events are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_consent_events_append_only_delete
         BEFORE DELETE ON coaching_consent_events
         BEGIN SELECT RAISE(ABORT, 'B04 consent events are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_consent_events_related_owner_insert
         BEFORE INSERT ON coaching_consent_events
         WHEN NEW.related_or_superseded_event_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM coaching_consent_events
            WHERE id = NEW.related_or_superseded_event_id
              AND user_id = NEW.user_id
              AND consent_category = NEW.consent_category
              AND timestamp_utc < NEW.timestamp_utc)
         BEGIN SELECT RAISE(ABORT, 'Consent event lineage is invalid'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_recovery_observations_append_only_update
         BEFORE UPDATE ON recovery_observations
         BEGIN SELECT RAISE(ABORT, 'B04 recovery observations are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_recovery_observations_append_only_delete
         BEFORE DELETE ON recovery_observations
         BEGIN SELECT RAISE(ABORT, 'B04 recovery observations are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_readiness_snapshots_append_only_update
         BEFORE UPDATE ON readiness_snapshots
         BEGIN SELECT RAISE(ABORT, 'B04 readiness snapshots are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_readiness_snapshots_append_only_delete
         BEFORE DELETE ON readiness_snapshots
         BEGIN SELECT RAISE(ABORT, 'B04 readiness snapshots are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_readiness_snapshots_owner_insert
         BEFORE INSERT ON readiness_snapshots
         WHEN NEW.supersedes_snapshot_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM readiness_snapshots
            WHERE id = NEW.supersedes_snapshot_id AND user_id = NEW.user_id)
         BEGIN SELECT RAISE(ABORT, 'Readiness supersession must remain within one user'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_readiness_snapshots_owner_update
         BEFORE UPDATE OF user_id, supersedes_snapshot_id ON readiness_snapshots
         WHEN NEW.supersedes_snapshot_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM readiness_snapshots
            WHERE id = NEW.supersedes_snapshot_id AND user_id = NEW.user_id)
         BEGIN SELECT RAISE(ABORT, 'Readiness supersession must remain within one user'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_readiness_evidence_append_only_update
         BEFORE UPDATE ON readiness_snapshot_evidence
         BEGIN SELECT RAISE(ABORT, 'B04 readiness evidence is append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_readiness_evidence_append_only_delete
         BEFORE DELETE ON readiness_snapshot_evidence
         BEGIN SELECT RAISE(ABORT, 'B04 readiness evidence is append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_readiness_evidence_owner_insert
         BEFORE INSERT ON readiness_snapshot_evidence
         WHEN NOT EXISTS
           (SELECT 1
            FROM readiness_snapshots s
            JOIN recovery_observations o ON o.id = NEW.observation_id
            WHERE s.id = NEW.readiness_snapshot_id AND s.user_id = o.user_id)
         BEGIN SELECT RAISE(ABORT, 'Readiness evidence ownership is invalid'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_recommendations_append_only_update
         BEFORE UPDATE ON recommendations
         BEGIN SELECT RAISE(ABORT, 'B04 recommendations are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_recommendations_append_only_delete
         BEFORE DELETE ON recommendations
         BEGIN SELECT RAISE(ABORT, 'B04 recommendations are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_recommendations_owner_insert
         BEFORE INSERT ON recommendations
         WHEN (NEW.goal_version_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_goal_versions
            WHERE id = NEW.goal_version_id AND user_id = NEW.user_id))
           OR (NEW.readiness_snapshot_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM readiness_snapshots
            WHERE id = NEW.readiness_snapshot_id AND user_id = NEW.user_id))
           OR (NEW.supersedes_recommendation_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM recommendations
            WHERE id = NEW.supersedes_recommendation_id AND user_id = NEW.user_id))
         BEGIN SELECT RAISE(ABORT, 'Recommendation ownership is invalid'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_recommendation_evidence_append_only_update
         BEFORE UPDATE ON recommendation_evidence
         BEGIN SELECT RAISE(ABORT, 'B04 recommendation evidence is append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_recommendation_evidence_append_only_delete
         BEFORE DELETE ON recommendation_evidence
         BEGIN SELECT RAISE(ABORT, 'B04 recommendation evidence is append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_recommendation_evidence_owner_insert
         BEFORE INSERT ON recommendation_evidence
         WHEN NOT EXISTS
           (SELECT 1 FROM recommendations
            WHERE id = NEW.recommendation_id AND user_id = NEW.user_id)
         BEGIN SELECT RAISE(ABORT, 'Recommendation evidence ownership is invalid'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_eligibility_append_only_update
         BEFORE UPDATE ON coaching_eligibility_evaluations
         BEGIN SELECT RAISE(ABORT, 'B04 eligibility evaluations are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_eligibility_append_only_delete
         BEFORE DELETE ON coaching_eligibility_evaluations
         BEGIN SELECT RAISE(ABORT, 'B04 eligibility evaluations are append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_eligibility_owner_insert
         BEFORE INSERT ON coaching_eligibility_evaluations
         WHEN (NEW.goal_version_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM nutrition_goal_versions
            WHERE id = NEW.goal_version_id AND user_id = NEW.user_id))
           OR (NEW.recommendation_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM recommendations
            WHERE id = NEW.recommendation_id AND user_id = NEW.user_id))
         BEGIN SELECT RAISE(ABORT, 'Eligibility ownership is invalid'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_feedback_append_only_update
         BEFORE UPDATE ON recommendation_feedback
         BEGIN SELECT RAISE(ABORT, 'B04 feedback is append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_feedback_append_only_delete
         BEFORE DELETE ON recommendation_feedback
         BEGIN SELECT RAISE(ABORT, 'B04 feedback is append-only'); END''',
      '''CREATE TRIGGER IF NOT EXISTS b04_feedback_owner_insert
         BEFORE INSERT ON recommendation_feedback
         WHEN (NOT EXISTS
           (SELECT 1 FROM recommendations
            WHERE id = NEW.recommendation_id AND user_id = NEW.user_id))
           OR (NEW.related_feedback_id IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM recommendation_feedback
            WHERE id = NEW.related_feedback_id AND user_id = NEW.user_id))
         BEGIN SELECT RAISE(ABORT, 'Feedback ownership is invalid'); END''',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  Future<void> _createV19Indexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS b05_dashboard_module_preferences_user_ordinal_idx ON dashboard_module_preferences(user_id, ordinal, module_id)',
      'CREATE INDEX IF NOT EXISTS b05_education_content_progress_user_updated_idx ON education_content_progress(user_id, updated_at_utc, content_id)',
      'CREATE INDEX IF NOT EXISTS b05_media_pack_preferences_user_updated_idx ON media_pack_preferences(user_id, updated_at_utc, pack_id)',
      'CREATE INDEX IF NOT EXISTS b05_workout_playlist_preferences_user_provider_idx ON workout_playlist_preferences(user_id, provider_id)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  /// Converts the pre-release v17 calibration-only shape into the corrected
  /// v17 vessel graph without changing the public schema version. The first
  /// v17 implementation was never released, so this is a deterministic
  /// compatibility repair for local databases created from that definition.
  Future<void> _ensurePreReleaseV17VesselGraph() async {
    final hasPersonalVessels = await _tableExists('nutrition_personal_vessels');
    final hasCalibrations = await _tableExists('nutrition_vessel_calibrations');
    if (hasPersonalVessels) {
      if (!hasCalibrations ||
          await _tableHasColumn('nutrition_vessel_calibrations', 'vessel_id')) {
        return;
      }
      throw StateError(
        'Pre-release v17 vessel graph is partially upgraded and cannot be repaired safely.',
      );
    }
    if (!hasCalibrations) return;

    final hasLegacyFoodColumn = await _tableHasColumn(
      'nutrition_vessel_calibrations',
      'food_id',
    );
    final hasLegacyPreparationColumn = await _tableHasColumn(
      'nutrition_vessel_calibrations',
      'preparation_id',
    );
    if (hasLegacyFoodColumn && hasLegacyPreparationColumn) {
      final contextual = await customSelect('''
        SELECT 1
        FROM nutrition_vessel_calibrations
        WHERE food_id IS NOT NULL OR preparation_id IS NOT NULL
        LIMIT 1
      ''').get();
      if (contextual.isNotEmpty) {
        throw StateError(
          'Pre-release vessel calibrations contain food-specific context and cannot be converted to the volume-only v17 contract.',
        );
      }
    }

    await transaction(() async {
      await customStatement(
        'DROP TRIGGER IF EXISTS nutrition_vessel_volume_only_insert',
      );
      await customStatement(
        'DROP TRIGGER IF EXISTS nutrition_vessel_volume_only_update',
      );
      await customStatement('''
        CREATE TABLE nutrition_personal_vessels (
          id TEXT NOT NULL PRIMARY KEY,
          user_id TEXT NOT NULL,
          display_name TEXT NOT NULL,
          vessel_type TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          archived_at INTEGER,
          CHECK (length(trim(id)) > 0),
          CHECK (length(trim(user_id)) > 0),
          CHECK (length(trim(display_name)) > 0)
        )
      ''');
      await customStatement(
        'ALTER TABLE nutrition_vessel_calibrations RENAME TO nutrition_vessel_calibrations_pre_v17',
      );
      await customStatement('''
        CREATE TABLE nutrition_vessel_calibrations (
          id TEXT NOT NULL PRIMARY KEY,
          vessel_id TEXT NOT NULL REFERENCES nutrition_personal_vessels(id),
          volume_amount REAL NOT NULL,
          volume_unit TEXT NOT NULL,
          lower REAL,
          upper REAL,
          method TEXT NOT NULL,
          confidence REAL,
          supersedes_calibration_id TEXT REFERENCES nutrition_vessel_calibrations(id),
          version INTEGER NOT NULL,
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          UNIQUE (vessel_id, version),
          CHECK (length(trim(id)) > 0),
          CHECK (volume_amount > 0),
          CHECK (volume_unit IN ('millilitre', 'litre')),
          CHECK (lower IS NULL OR lower > 0),
          CHECK (upper IS NULL OR upper > 0),
          CHECK (lower IS NULL OR upper IS NULL OR lower <= upper),
          CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
          CHECK (version >= 1),
          CHECK (supersedes_calibration_id IS NULL OR supersedes_calibration_id <> id)
        )
      ''');
      await customStatement('''
        INSERT INTO nutrition_personal_vessels
          (id, user_id, display_name, vessel_type, created_at, updated_at, archived_at)
        SELECT 'vessel:' || id, user_id, label, NULL, created_at, updated_at, NULL
        FROM nutrition_vessel_calibrations_pre_v17
      ''');
      await customStatement('''
        INSERT INTO nutrition_vessel_calibrations
          (id, vessel_id, volume_amount, volume_unit, lower, upper, method,
           confidence, supersedes_calibration_id, version, notes, created_at, updated_at)
        SELECT id, 'vessel:' || id, volume_ml, 'millilitre', lower, upper, method,
               confidence, NULL, 1, NULL, created_at, updated_at
        FROM nutrition_vessel_calibrations_pre_v17
      ''');
      await customStatement('DROP TABLE nutrition_vessel_calibrations_pre_v17');
    });
    await _createV17Indexes();
  }

  Future<bool> _tableExists(String tableName) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(tableName)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _tableHasColumn(String tableName, String columnName) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    return rows.any((row) => row.data['name'] == columnName);
  }

  Future<void> _backfillStableExerciseIds() async {
    final existing = await (select(
      exercises,
    )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();

    // A duplicated or alias-equivalent legacy catalogue row cannot safely be
    // attached to the one manifest identity. Give every such row its own
    // persisted legacy UUID and leave name-only references unresolved later.
    final canonicalCandidateCounts = <String, int>{};
    for (final exercise in existing.where((exercise) => !exercise.isCustom)) {
      final result = B01LegacyImportSupport.lookupExerciseName(exercise.name);
      final canonicalId = result.canonicalUuid;
      if (!result.isResolved || canonicalId == null) continue;
      canonicalCandidateCounts.update(
        canonicalId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    for (final exercise in existing) {
      final manifestResult = B01LegacyImportSupport.lookupExerciseName(
        exercise.name,
      );
      final canonicalId = manifestResult.canonicalUuid;
      final stableId =
          !exercise.isCustom &&
              manifestResult.isResolved &&
              canonicalId != null &&
              canonicalCandidateCounts[canonicalId] == 1
          ? manifestResult.canonicalUuid!
          : B01LegacyImportSupport.legacyExerciseStableId(
              sourceExerciseId: exercise.id,
              name: exercise.name,
            );
      await (update(exercises)..where((table) => table.id.equals(exercise.id)))
          .write(ExercisesCompanion(stableId: Value(stableId)));
    }
  }

  Future<void> _backfillWorkoutSetExerciseIds() async {
    final candidatesByName = <String, List<String>>{};
    final existingExercises = await select(exercises).get();
    for (final exercise in existingExercises) {
      final stableId = exercise.stableId;
      if (stableId == null) continue;
      final key = ExerciseIdentityNormalizer.normalize(exercise.name);
      candidatesByName.putIfAbsent(key, () => []).add(stableId);
    }

    final sets = await (select(
      workoutSets,
    )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
    for (final set in sets) {
      final stableId = _resolveLegacyExerciseReference(
        rawName: set.exerciseName,
        candidatesByName: candidatesByName,
      );
      if (stableId == null) continue;
      await (update(workoutSets)..where((table) => table.id.equals(set.id)))
          .write(WorkoutSetsCompanion(exerciseId: Value(stableId)));
    }
  }

  /// Resolves only the B01-approved exact/alias policy. An ambiguous catalog
  /// input is deliberately never rescued by a same-text local candidate.
  String? _resolveLegacyExerciseReference({
    required String rawName,
    required Map<String, List<String>> candidatesByName,
  }) {
    final manifestResult = B01LegacyImportSupport.lookupExerciseName(rawName);
    if (manifestResult.isAmbiguous) return null;
    if (manifestResult.isResolved) {
      final canonicalId = manifestResult.canonicalUuid!;
      return candidatesByName.values.any((ids) => ids.contains(canonicalId))
          ? canonicalId
          : null;
    }

    final candidates =
        candidatesByName[ExerciseIdentityNormalizer.normalize(rawName)] ??
        const <String>[];
    return candidates.length == 1 ? candidates.single : null;
  }

  Future<void> _importLegacyRoutinePrograms() async {
    final routines = await (select(
      workoutRoutines,
    )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
    final candidatesByName = <String, List<String>>{};
    final existingExercises = await select(exercises).get();
    for (final exercise in existingExercises) {
      final stableId = exercise.stableId;
      if (stableId == null) continue;
      final key = ExerciseIdentityNormalizer.normalize(exercise.name);
      candidatesByName.putIfAbsent(key, () => []).add(stableId);
    }

    for (final routine in routines) {
      final programId = B01LegacyImportSupport.programId(routine.id);
      final versionId = B01LegacyImportSupport.programVersionId(routine.id);
      final blockId = B01LegacyImportSupport.blockId(routine.id);
      final weekId = B01LegacyImportSupport.weekId(routine.id);
      final importedAt = routine.createdAt.toUtc();

      await into(programs).insert(
        ProgramsCompanion.insert(
          id: programId,
          name: routine.name,
          goal: Value(routine.goal),
          notes: Value(routine.notes),
          createdAtUtc: importedAt,
        ),
      );
      await into(programVersions).insert(
        ProgramVersionsCompanion.insert(
          id: versionId,
          programId: programId,
          versionNumber: 1,
          status: 'published',
          origin: const Value('legacyImport'),
          createdAtUtc: importedAt,
          publishedAtUtc: Value(importedAt),
        ),
      );
      await into(programBlocks).insert(
        ProgramBlocksCompanion.insert(
          id: blockId,
          programVersionId: versionId,
          ordinal: 1,
          name: 'Imported legacy block',
        ),
      );
      await into(programWeeks).insert(
        ProgramWeeksCompanion.insert(
          id: weekId,
          programVersionId: versionId,
          programBlockId: blockId,
          ordinalInBlock: 1,
          programWeekOrdinal: 1,
          name: const Value('Imported legacy week'),
        ),
      );

      final days =
          await (select(routineDays)
                ..where((table) => table.routineId.equals(routine.id))
                ..orderBy([
                  (table) => OrderingTerm.asc(table.dayOfWeek),
                  (table) => OrderingTerm.asc(table.id),
                ]))
              .get();
      var templateOrdinal = 1;
      for (final day in days) {
        if (day.isRestDay) continue;
        final templateId = B01LegacyImportSupport.sessionTemplateId(
          routine.id,
          day.id,
        );
        await into(sessionTemplates).insert(
          SessionTemplatesCompanion.insert(
            id: templateId,
            programWeekId: weekId,
            ordinal: templateOrdinal++,
            name: day.name,
            plannedWeekday: day.dayOfWeek,
          ),
        );

        final legacyExercises =
            await (select(routineExercises)
                  ..where((table) => table.dayId.equals(day.id))
                  ..orderBy([
                    (table) => OrderingTerm.asc(table.orderIndex),
                    (table) => OrderingTerm.asc(table.id),
                  ]))
                .get();
        for (var index = 0; index < legacyExercises.length; index++) {
          final legacyExercise = legacyExercises[index];
          final stableId = _resolveLegacyExerciseReference(
            rawName: legacyExercise.exerciseName,
            candidatesByName: candidatesByName,
          );
          await into(exercisePrescriptions).insert(
            ExercisePrescriptionsCompanion.insert(
              id: B01LegacyImportSupport.prescriptionId(
                routine.id,
                legacyExercise.id,
              ),
              sessionTemplateId: templateId,
              ordinal: index + 1,
              exerciseId: Value(stableId),
              exerciseNameSnapshot: legacyExercise.exerciseName,
              plannedSets: legacyExercise.sets,
              repsRange: legacyExercise.repsRange,
            ),
          );
        }
      }

      await into(legacyRoutineProgramMappings).insert(
        LegacyRoutineProgramMappingsCompanion.insert(
          legacyRoutineId: Value(routine.id),
          programId: programId,
          programVersionId: versionId,
          importedAtUtc: importedAt,
        ),
      );
    }
  }

  /// Reuses the v14-to-v15 import rules after a validated v3-v5 backup has
  /// restored its retained legacy tables. Callers must already be inside the
  /// restore transaction; this method intentionally neither activates a
  /// version nor materializes calendar occurrences.
  Future<void> importLegacyCompatibilityDataForRestore() async {
    await _backfillWorkoutSetExerciseIds();
    await _importLegacyRoutinePrograms();
    final defaultProfileId = await _importLegacyEquipmentProfile();
    await _ensureTrainingPlanSettings(defaultProfileId: defaultProfileId);
  }

  /// Runs the one narrowly-scoped B04 restore mutation that must replace the
  /// current immutable projection. Ordinary application writes still use the
  /// append-only triggers; this seam is called only from the versioned backup
  /// transaction and recreates every trigger before the transaction can commit.
  Future<T> withB04RestoreMutation<T>(Future<T> Function() action) async {
    const appendOnlyTriggers = [
      'b04_goal_versions_append_only_update',
      'b04_goal_versions_append_only_delete',
      'b04_consent_events_append_only_update',
      'b04_consent_events_append_only_delete',
      'b04_recovery_observations_append_only_update',
      'b04_recovery_observations_append_only_delete',
      'b04_readiness_snapshots_append_only_update',
      'b04_readiness_snapshots_append_only_delete',
      'b04_readiness_evidence_append_only_update',
      'b04_readiness_evidence_append_only_delete',
      'b04_recommendations_append_only_update',
      'b04_recommendations_append_only_delete',
      'b04_recommendation_evidence_append_only_update',
      'b04_recommendation_evidence_append_only_delete',
      'b04_eligibility_append_only_update',
      'b04_eligibility_append_only_delete',
      'b04_feedback_append_only_update',
      'b04_feedback_append_only_delete',
    ];
    for (final trigger in appendOnlyTriggers) {
      await customStatement('DROP TRIGGER IF EXISTS $trigger');
    }
    try {
      return await action();
    } finally {
      await _createV18Indexes();
    }
  }

  Future<String?> _importLegacyEquipmentProfile() async {
    final profiles = await (select(
      userProfiles,
    )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
    if (profiles.isEmpty) return null;
    final profile = profiles.first;

    final profileId = B01LegacyImportSupport.equipmentProfileId(profile.id);
    final createdAt = profile.updatedAt.toUtc();
    await into(equipmentProfiles).insert(
      EquipmentProfilesCompanion.insert(
        id: profileId,
        name: 'Default Gym',
        legacyAccessCode: Value(profile.equipmentAccess),
        createdAtUtc: createdAt,
        updatedAtUtc: createdAt,
      ),
    );

    var equipment = EquipmentNormalizer.parseLegacyCategory(
      profile.equipmentAccess,
    );
    if (!equipment.isResolved) {
      equipment = EquipmentNormalizer.parseEquipmentString(
        profile.equipmentAccess,
      );
    }
    // A partially understood combined string is deliberately unresolved. The
    // original text remains on the profile, but no subset is silently treated
    // as the user's complete equipment inventory.
    if (equipment.isResolved) {
      for (final item in equipment.canonicalItems) {
        await into(equipmentProfileItems).insert(
          EquipmentProfileItemsCompanion.insert(
            id: B01LegacyImportSupport.equipmentProfileItemId(
              profile.id,
              item.id,
            ),
            equipmentProfileId: profileId,
            equipmentCode: item.id,
          ),
        );
      }
    }
    return profileId;
  }

  /// Adds only nullable lifecycle metadata. Existing active pointers,
  /// occurrences, sessions, and drafts are intentionally untouched.
  Future<void> _migrateV19ToV20(Migrator m) async {
    await transaction(() async {
      // schemaVersionOverride fixtures are created with the current table
      // declarations and then labelled as an older user_version. Treat an
      // already-present column as a valid fixture boundary while still
      // adding all four columns to a real v19 file.
      if (!await _tableHasColumn(
        'training_plan_settings',
        'last_ended_program_version_id',
      )) {
        await m.addColumn(
          trainingPlanSettings,
          trainingPlanSettings.lastEndedProgramVersionId,
        );
      }
      if (!await _tableHasColumn(
        'training_plan_settings',
        'last_ended_outcome',
      )) {
        await m.addColumn(
          trainingPlanSettings,
          trainingPlanSettings.lastEndedOutcome,
        );
      }
      if (!await _tableHasColumn(
        'training_plan_settings',
        'last_ended_at_utc',
      )) {
        await m.addColumn(
          trainingPlanSettings,
          trainingPlanSettings.lastEndedAtUtc,
        );
      }
      if (!await _tableHasColumn(
        'training_plan_settings',
        'last_ended_command_id',
      )) {
        await m.addColumn(
          trainingPlanSettings,
          trainingPlanSettings.lastEndedCommandId,
        );
      }
    });
  }

  /// V22 sync identity (PV1-SYNC-01 prerequisite): nullable opaque UUID on
  /// body_measurements, mirroring the uuid columns on WorkoutSessions and
  /// FoodLogs. Entity identity for sync is this UUID string; the local
  /// autoincrement id is never derived from or overwritten by it. Existing
  /// ids, weights, and timestamps are intentionally untouched.
  Future<void> _migrateV21ToV22(Migrator m) async {
    await transaction(() async {
      // schemaVersionOverride fixtures are created with the current table
      // declarations and then labelled as an older user_version. Treat an
      // already-present column as a valid fixture boundary while still
      // adding the column to a real v21 file.
      if (!await _tableHasColumn('body_measurements', 'uuid')) {
        await m.addColumn(bodyMeasurements, bodyMeasurements.uuid);
      }
      await _backfillBodyMeasurementUuids();
    });
  }

  /// Assigns a fresh UUID v4 to every body_measurements row whose uuid is
  /// null. Rows that already carry a uuid keep it; every backfilled row
  /// receives its own value (never one shared UUID). Uses the same
  /// package:uuid generator pattern as [B01LegacyImportSupport].
  Future<void> _backfillBodyMeasurementUuids() async {
    const generator = Uuid();
    final missing = await (select(
      bodyMeasurements,
    )..where((table) => table.uuid.isNull())).get();
    for (final row in missing) {
      await (update(
        bodyMeasurements,
      )..where((table) => table.id.equals(row.id))).write(
        BodyMeasurementsCompanion(uuid: Value(generator.v4())),
      );
    }
  }

  Future<void> _createStableExerciseIdIndex() async {
    await customStatement('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_exercises_stable_id
      ON exercises(stable_id)
    ''');
  }

  Future<void> _createV15IndexesAndTriggers() async {
    await _createStableExerciseIdIndex();
    const statements = [
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_workout_sessions_occurrence ON workout_sessions(scheduled_occurrence_id)',
      'CREATE INDEX IF NOT EXISTS idx_workout_sets_exercise_id ON workout_sets(exercise_id)',
      'CREATE INDEX IF NOT EXISTS idx_workout_drafts_occurrence ON workout_drafts(scheduled_occurrence_id)',
      'CREATE INDEX IF NOT EXISTS idx_programs_archived_created ON programs(archived_at_utc, created_at_utc)',
      'CREATE INDEX IF NOT EXISTS idx_program_versions_program_status ON program_versions(program_id, status)',
      'CREATE INDEX IF NOT EXISTS idx_program_blocks_version ON program_blocks(program_version_id)',
      'CREATE INDEX IF NOT EXISTS idx_session_templates_week_weekday ON session_templates(program_week_id, planned_weekday)',
      'CREATE INDEX IF NOT EXISTS idx_exercise_prescriptions_template ON exercise_prescriptions(session_template_id)',
      'CREATE INDEX IF NOT EXISTS idx_exercise_prescriptions_exercise ON exercise_prescriptions(exercise_id)',
      'CREATE INDEX IF NOT EXISTS idx_occurrences_effective_date_status ON scheduled_session_occurrences(effective_local_date, status)',
      'CREATE INDEX IF NOT EXISTS idx_occurrences_version_status ON scheduled_session_occurrences(program_version_id, status)',
      'CREATE INDEX IF NOT EXISTS idx_occurrences_repeated_from ON scheduled_session_occurrences(repeated_from_occurrence_id)',
      'CREATE INDEX IF NOT EXISTS idx_occurrence_events_occurrence_time ON occurrence_events(occurrence_id, occurred_at_utc)',
      'CREATE INDEX IF NOT EXISTS idx_travel_contexts_status_dates ON travel_contexts(status, start_local_date, end_local_date)',
      'CREATE INDEX IF NOT EXISTS idx_travel_contexts_profile ON travel_contexts(equipment_profile_id)',
      'CREATE INDEX IF NOT EXISTS idx_equipment_profiles_archived_name ON equipment_profiles(archived_at_utc, name)',
      'CREATE INDEX IF NOT EXISTS idx_equipment_items_profile_available ON equipment_profile_items(equipment_profile_id, is_available)',
      'CREATE INDEX IF NOT EXISTS idx_equipment_items_code ON equipment_profile_items(equipment_code)',
      'CREATE INDEX IF NOT EXISTS idx_exercise_preferences_exercise ON exercise_user_preferences(exercise_id)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS exercises_assign_stable_id
      AFTER INSERT ON exercises
      FOR EACH ROW WHEN NEW.stable_id IS NULL
      BEGIN
        UPDATE exercises
        SET stable_id =
          lower(hex(randomblob(4))) || '-' ||
          lower(hex(randomblob(2))) || '-4' ||
          substr(lower(hex(randomblob(2))), 2) || '-8' ||
          substr(lower(hex(randomblob(2))), 2) || '-' ||
          lower(hex(randomblob(6)))
        WHERE id = NEW.id;
      END
    ''');
  }

  Future<void> _createV16IndexesAndTriggers() async {
    await _createV15IndexesAndTriggers();
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_workout_sessions_activity_completed ON workout_sessions(activity_type, completed_at)',
      'CREATE INDEX IF NOT EXISTS idx_session_templates_week_activity_ordinal ON session_templates(program_week_id, activity_type, ordinal)',
      'CREATE INDEX IF NOT EXISTS idx_exercise_groups_template ON exercise_groups(session_template_id)',
      'CREATE INDEX IF NOT EXISTS idx_exercise_group_members_group ON exercise_group_members(exercise_group_id)',
      'CREATE INDEX IF NOT EXISTS idx_exercise_group_members_prescription ON exercise_group_members(exercise_prescription_id)',
      'CREATE INDEX IF NOT EXISTS idx_strength_set_prescriptions_prescription ON strength_set_prescriptions(exercise_prescription_id)',
      'CREATE INDEX IF NOT EXISTS idx_cardio_session_details_interval ON cardio_session_details(is_interval_workout)',
      'CREATE INDEX IF NOT EXISTS idx_cardio_intervals_session_ordinal ON cardio_intervals(cardio_session_id, ordinal)',
      'CREATE INDEX IF NOT EXISTS idx_mobility_session_details_practice ON mobility_session_details(practice_type)',
      'CREATE INDEX IF NOT EXISTS idx_performed_exercise_groups_session_ordinal ON performed_exercise_groups(session_id, ordinal)',
      'CREATE INDEX IF NOT EXISTS idx_performed_exercises_session_ordinal ON performed_exercises(session_id, ordinal)',
      'CREATE INDEX IF NOT EXISTS idx_performed_exercises_actual_session ON performed_exercises(actual_exercise_id, session_id)',
      'CREATE INDEX IF NOT EXISTS idx_performed_exercises_source_prescription ON performed_exercises(source_exercise_prescription_id)',
      'CREATE INDEX IF NOT EXISTS idx_target_recommendations_performed_exercise ON exercise_target_recommendations(performed_exercise_id)',
      'CREATE INDEX IF NOT EXISTS idx_performed_sets_exercise_role ON performed_sets(performed_exercise_id, role)',
      'CREATE INDEX IF NOT EXISTS idx_performed_set_segments_set_ordinal ON performed_set_segments(performed_set_id, ordinal)',
      'CREATE INDEX IF NOT EXISTS idx_performed_rest_periods_session_started ON performed_rest_periods(session_id, started_at_utc)',
      'CREATE INDEX IF NOT EXISTS idx_performed_rest_periods_set ON performed_rest_periods(performed_set_id)',
      'CREATE INDEX IF NOT EXISTS idx_performed_rest_periods_group ON performed_rest_periods(performed_exercise_group_id)',
      'CREATE INDEX IF NOT EXISTS idx_muscles_region_active ON muscles(region, is_active)',
      'CREATE INDEX IF NOT EXISTS idx_exercise_muscle_mappings_muscle_status ON exercise_muscle_mappings(muscle_id, mapping_status)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }

    // ALTER TABLE cannot add a table-level CHECK to existing v15 tables.
    // These triggers preserve the same typed-value contract on migration as a
    // fresh v16 database receives from the Drift table constraints.
    const triggers = [
      '''
        CREATE TRIGGER IF NOT EXISTS workout_sessions_validate_activity_insert
        BEFORE INSERT ON workout_sessions
        FOR EACH ROW WHEN NEW.activity_type NOT IN ('legacy', 'strength', 'running', 'cycling', 'walking', 'yoga', 'mobility') OR NEW.activity_schema_version < 1
        BEGIN SELECT RAISE(ABORT, 'invalid workout session activity type'); END
      ''',
      '''
        CREATE TRIGGER IF NOT EXISTS workout_sessions_validate_activity_update
        BEFORE UPDATE OF activity_type, activity_schema_version ON workout_sessions
        FOR EACH ROW WHEN NEW.activity_type NOT IN ('legacy', 'strength', 'running', 'cycling', 'walking', 'yoga', 'mobility') OR NEW.activity_schema_version < 1
        BEGIN SELECT RAISE(ABORT, 'invalid workout session activity type'); END
      ''',
      '''
        CREATE TRIGGER IF NOT EXISTS session_templates_validate_activity_insert
        BEFORE INSERT ON session_templates
        FOR EACH ROW WHEN NEW.activity_type NOT IN ('strength', 'running', 'cycling', 'walking', 'yoga', 'mobility') OR (NEW.default_rest_seconds IS NOT NULL AND NEW.default_rest_seconds < 0)
        BEGIN SELECT RAISE(ABORT, 'invalid session template activity type'); END
      ''',
      '''
        CREATE TRIGGER IF NOT EXISTS session_templates_validate_activity_update
        BEFORE UPDATE OF activity_type, default_rest_seconds ON session_templates
        FOR EACH ROW WHEN NEW.activity_type NOT IN ('strength', 'running', 'cycling', 'walking', 'yoga', 'mobility') OR (NEW.default_rest_seconds IS NOT NULL AND NEW.default_rest_seconds < 0)
        BEGIN SELECT RAISE(ABORT, 'invalid session template activity type'); END
      ''',
      '''
        CREATE TRIGGER IF NOT EXISTS workout_drafts_validate_activity_insert
        BEFORE INSERT ON workout_drafts
        FOR EACH ROW WHEN NEW.activity_type NOT IN ('legacy', 'strength', 'running', 'cycling', 'walking', 'yoga', 'mobility')
        BEGIN SELECT RAISE(ABORT, 'invalid workout draft activity type'); END
      ''',
      '''
        CREATE TRIGGER IF NOT EXISTS workout_drafts_validate_activity_update
        BEFORE UPDATE OF activity_type ON workout_drafts
        FOR EACH ROW WHEN NEW.activity_type NOT IN ('legacy', 'strength', 'running', 'cycling', 'walking', 'yoga', 'mobility')
        BEGIN SELECT RAISE(ABORT, 'invalid workout draft activity type'); END
      ''',
      '''
        CREATE TRIGGER IF NOT EXISTS exercise_preferences_validate_execution_insert
        BEFORE INSERT ON exercise_user_preferences
        FOR EACH ROW WHEN (NEW.warmup_preference IS NOT NULL AND NEW.warmup_preference NOT IN ('off', 'ask', 'automatic')) OR (NEW.warmup_set_count IS NOT NULL AND NEW.warmup_set_count NOT BETWEEN 1 AND 4) OR (NEW.custom_rest_seconds IS NOT NULL AND NEW.custom_rest_seconds < 0)
        BEGIN SELECT RAISE(ABORT, 'invalid exercise execution preference'); END
      ''',
      '''
        CREATE TRIGGER IF NOT EXISTS exercise_preferences_validate_execution_update
        BEFORE UPDATE OF warmup_preference, warmup_set_count, custom_rest_seconds ON exercise_user_preferences
        FOR EACH ROW WHEN (NEW.warmup_preference IS NOT NULL AND NEW.warmup_preference NOT IN ('off', 'ask', 'automatic')) OR (NEW.warmup_set_count IS NOT NULL AND NEW.warmup_set_count NOT BETWEEN 1 AND 4) OR (NEW.custom_rest_seconds IS NOT NULL AND NEW.custom_rest_seconds < 0)
        BEGIN SELECT RAISE(ABORT, 'invalid exercise execution preference'); END
      ''',
    ];
    for (final trigger in triggers) {
      await customStatement(trigger);
    }
  }

  Future<void> _migrateLegacyHydrationPreferencesToDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logged = prefs.getInt('water_logged');
      final goal = prefs.getInt('water_goal') ?? 2000;
      if (logged != null && logged > 0) {
        final now = DateTime.now();
        final dateStr =
            "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final existing = await (select(
          dailyHydrations,
        )..where((tbl) => tbl.dateString.equals(dateStr))).getSingleOrNull();

        if (existing == null) {
          await into(dailyHydrations).insert(
            DailyHydrationsCompanion.insert(
              dateString: dateStr,
              totalMl: logged,
              goalMl: goal,
              updatedAt: Value(now),
            ),
          );
        }
      }
    } catch (e, st) {
      AppLogger.warning('Hydration prefs migration failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'Hydration prefs migration failed',
      );
    }
  }
}
