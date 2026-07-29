import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/fixtures/equipment_fixtures.dart';
import '../../core/fixtures/exercise_identity_fixtures.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/utils/app_logger.dart';
import 'b01_legacy_import_support.dart';
import 'tables/achievement_tables.dart';
import 'tables/food_tables.dart';
import 'tables/health_tables.dart';
import 'tables/hydration_tables.dart';
import 'tables/settings_tables.dart';
import 'tables/training_program_tables.dart';
import 'tables/user_tables.dart';
import 'tables/workout_tables.dart';

part 'app_database.g.dart';

// B01 schema v15 is generated from the table graph declared below.

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : v15MigrationFailureInjector = null, super(_openConnection());
  AppDatabase.memory()
    : v15MigrationFailureInjector = null,
      super(NativeDatabase.memory());
  AppDatabase.executor(super.executor, {this.v15MigrationFailureInjector});

  /// Test-only hook used to prove the v14 -> v15 upgrade rolls back as one
  /// transaction. It is intentionally invoked only from the migration path.
  final Future<void> Function()? v15MigrationFailureInjector;

  /// Schema v15 adds the durable B01 training-plan graph while retaining the
  /// legacy routine and history tables for compatibility.
  @override
  int get schemaVersion => 15;

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
    },

    onCreate: (m) async {
      await m.createAll();
      await _createV15IndexesAndTriggers();
      await _ensureTrainingPlanSettings();
      await seedFoodsFromAsset();
      await seedExercisesFromAsset();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  /// Full seed used on first install.
  Future<void> seedFoodsFromAsset() async {
    try {
      final companions = await _loadFoodCompanionsFromAsset();
      if (companions.isEmpty) return;
      await batch((b) => b.insertAll(foodItems, companions));
    } catch (e, st) {
      AppLogger.warning('seedFoodsFromAsset failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'seedFoodsFromAsset failed',
      );
    }
  }

  /// Upsert by name for non-custom rows; insert brand-new catalog items.
  Future<void> upsertSeededFoodsFromAsset() async {
    try {
      final foodsList = await _loadFoodJsonList();
      if (foodsList.isEmpty) return;

      final existing = await select(foodItems).get();
      final byName = <String, FoodItem>{
        for (final item in existing.where((e) => !e.isCustom)) item.name: item,
      };

      final toInsert = <FoodItemsCompanion>[];
      await transaction(() async {
        for (final raw in foodsList) {
          final name = raw['name'] as String;
          final companionValues = FoodItemsCompanion(
            name: Value(name),
            nameHindi: Value(raw['name_hindi'] as String?),
            calories: Value(raw['calories'] as int),
            proteinG: Value((raw['protein_g'] as num).toDouble()),
            carbsG: Value((raw['carbs_g'] as num).toDouble()),
            fatG: Value((raw['fat_g'] as num).toDouble()),
            fiberG: Value((raw['fiber_g'] as num?)?.toDouble() ?? 0.0),
            servingSize: Value((raw['serving_size'] as num).toDouble()),
            servingUnit: Value(raw['serving_unit'] as String),
            category: Value(raw['category'] as String),
            isCustom: const Value(false),
          );

          final match = byName[name];
          if (match != null) {
            await (update(
              foodItems,
            )..where((t) => t.id.equals(match.id))).write(companionValues);
          } else {
            toInsert.add(
              FoodItemsCompanion.insert(
                name: name,
                nameHindi: Value(raw['name_hindi'] as String?),
                calories: raw['calories'] as int,
                proteinG: (raw['protein_g'] as num).toDouble(),
                carbsG: (raw['carbs_g'] as num).toDouble(),
                fatG: (raw['fat_g'] as num).toDouble(),
                fiberG: Value((raw['fiber_g'] as num?)?.toDouble() ?? 0.0),
                servingSize: (raw['serving_size'] as num).toDouble(),
                servingUnit: raw['serving_unit'] as String,
                category: raw['category'] as String,
              ),
            );
          }
        }
        if (toInsert.isNotEmpty) {
          await batch((b) => b.insertAll(foodItems, toInsert));
        }
      });
    } catch (e, st) {
      AppLogger.warning('upsertSeededFoodsFromAsset failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'upsertSeededFoodsFromAsset failed',
      );
    }
  }

  Future<void> seedExercisesFromAsset() async {
    await upsertSeededExercisesFromAsset();
  }

  /// Idempotent exercise seed: updates existing rows by name, inserts new ones.
  /// Fixes the empty-exercise-library bug where a prior migration's raw
  /// insertAll failed silently on UNIQUE constraints.
  Future<void> upsertSeededExercisesFromAsset() async {
    try {
      final exercisesJson = await rootBundle.loadString(
        'assets/data/exercises.json',
      );
      final List<dynamic> exercisesList = jsonDecode(exercisesJson);
      if (exercisesList.isEmpty) return;

      final existing = await select(exercises).get();
      // A seeded row is identified by the reviewed manifest UUID first. This
      // means a cosmetic catalogue rename updates the existing row instead of
      // minting a new identity or touching a same-named custom exercise.
      final seededByStableId = <String, Exercise>{
        for (final item in existing)
          if (!item.isCustom && item.stableId != null) item.stableId!: item,
      };
      final seededByName = <String, Exercise>{
        for (final item in existing.where((item) => !item.isCustom))
          item.name: item,
      };

      final toInsert = <ExercisesCompanion>[];
      await transaction(() async {
        for (final raw in exercisesList) {
          final name = raw['name'] as String;
          final stableId = ExerciseCatalogManifest
              .goldenCatalogUuids[ExerciseIdentityNormalizer.normalize(name)];
          if (stableId == null) {
            throw StateError(
              'Bundled exercise "$name" is missing from the reviewed identity manifest.',
            );
          }
          final companionValues = ExercisesCompanion(
            stableId: Value(stableId),
            name: Value(name),
            muscleGroups: Value(raw['muscle_groups'] as String),
            equipment: Value(raw['equipment'] as String),
            difficulty: Value(raw['difficulty'] as String),
            formCues: Value((raw['form_cues'] as List).join('\n')),
            commonMistakes: Value((raw['common_mistakes'] as List).join('\n')),
            youtubeId: Value(raw['youtube_id'] as String?),
          );

          final match = seededByStableId[stableId] ?? seededByName[name];
          if (match != null) {
            await (update(
              exercises,
            )..where((t) => t.id.equals(match.id))).write(companionValues);
          } else {
            toInsert.add(
              ExercisesCompanion.insert(
                stableId: Value(stableId),
                name: name,
                muscleGroups: raw['muscle_groups'] as String,
                equipment: raw['equipment'] as String,
                difficulty: raw['difficulty'] as String,
                formCues: (raw['form_cues'] as List).join('\n'),
                commonMistakes: (raw['common_mistakes'] as List).join('\n'),
                youtubeId: Value(raw['youtube_id'] as String?),
              ),
            );
          }
        }
        if (toInsert.isNotEmpty) {
          await batch((b) => b.insertAll(exercises, toInsert));
        }
      });
    } catch (e, st) {
      AppLogger.warning('upsertSeededExercisesFromAsset failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'upsertSeededExercisesFromAsset failed',
      );
    }
  }

  Future<List<dynamic>> _loadFoodJsonList() async {
    final foodsJson = await rootBundle.loadString(
      'assets/data/indian_foods.json',
    );
    final decoded = jsonDecode(foodsJson);
    if (decoded is List) return decoded;
    return const [];
  }

  Future<List<FoodItemsCompanion>> _loadFoodCompanionsFromAsset() async {
    final foodsList = await _loadFoodJsonList();
    return foodsList.map((item) {
      return FoodItemsCompanion.insert(
        name: item['name'],
        nameHindi: Value(item['name_hindi']),
        calories: item['calories'],
        proteinG: (item['protein_g'] as num).toDouble(),
        carbsG: (item['carbs_g'] as num).toDouble(),
        fatG: (item['fat_g'] as num).toDouble(),
        fiberG: Value((item['fiber_g'] as num?)?.toDouble() ?? 0.0),
        servingSize: (item['serving_size'] as num).toDouble(),
        servingUnit: item['serving_unit'],
        category: item['category'],
      );
    }).toList();
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

  Future<void> _ensureTrainingPlanSettings({String? defaultProfileId}) async {
    final existing = await select(trainingPlanSettings).getSingleOrNull();
    if (existing != null) return;
    await into(trainingPlanSettings).insert(
      TrainingPlanSettingsCompanion.insert(
        id: const Value(1),
        defaultEquipmentProfileId: Value(defaultProfileId),
        updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
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

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'indifit.db'));
    return NativeDatabase.createInBackground(file);
  });
}
