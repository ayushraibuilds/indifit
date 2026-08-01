import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/fixtures/b02_execution_draft_codec.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_rich_set_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'v7 round-trip preserves every B02 relation and typed modality',
    () async {
      final source = AppDatabase.memory();
      final target = AppDatabase.memory();
      addTearDown(source.close);
      addTearDown(target.close);

      await _populateB02Graph(source);
      final backup = await BackupData.createFromDatabase(source);
      expect(backup.version, BackupData.currentVersion);
      expect(backup.exerciseGroups, hasLength(1));
      expect(backup.exerciseGroupMembers, hasLength(2));
      expect(backup.strengthSetPrescriptions, hasLength(2));
      expect(backup.cardioSessionDetails, hasLength(1));
      expect(backup.cardioIntervals, hasLength(1));
      expect(backup.mobilitySessionDetails, hasLength(1));
      expect(backup.performedExerciseGroups, hasLength(1));
      expect(backup.performedExercises, hasLength(2));
      expect(backup.exerciseTargetRecommendations, hasLength(1));
      expect(backup.performedSets, hasLength(2));
      expect(backup.performedSetSegments, hasLength(2));
      expect(backup.performedRestPeriods, hasLength(1));
      expect(
        backup.exerciseMuscleMappings.any(
          (row) => row.mappingStatus == 'unknown',
        ),
        isTrue,
      );

      final json = backup.toJson();
      for (final key in const [
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
      ]) {
        expect(json.containsKey(key), isTrue, reason: key);
      }

      final decoded = BackupData.fromJson(json);
      await decoded.restoreToDatabase(target);

      expect(await target.select(target.exerciseGroups).get(), hasLength(1));
      expect(
        await target.select(target.exerciseGroupMembers).get(),
        hasLength(2),
      );
      expect(
        await target.select(target.strengthSetPrescriptions).get(),
        hasLength(2),
      );
      expect(
        await target.select(target.cardioSessionDetails).get(),
        hasLength(1),
      );
      expect(await target.select(target.cardioIntervals).get(), hasLength(1));
      expect(
        await target.select(target.mobilitySessionDetails).get(),
        hasLength(1),
      );
      expect(
        await target.select(target.performedExerciseGroups).get(),
        hasLength(1),
      );
      expect(
        await target.select(target.performedExercises).get(),
        hasLength(2),
      );
      expect(
        await target.select(target.exerciseTargetRecommendations).get(),
        hasLength(1),
      );
      expect(await target.select(target.performedSets).get(), hasLength(2));
      expect(
        await target.select(target.performedSetSegments).get(),
        hasLength(2),
      );
      expect(
        await target.select(target.performedRestPeriods).get(),
        hasLength(1),
      );
      expect(
        (await target.select(target.workoutSessions).get()).map(
          (row) => row.activityType,
        ),
        containsAll(['strength', 'running', 'yoga']),
      );
      expect(
        (await target.select(target.workoutDrafts).get())
            .single
            .executionStateJson,
        isNotNull,
      );
      expect(
        (await target.select(target.exerciseMuscleMappings).get()).where(
          (row) => row.mappingStatus == 'unknown',
        ),
        isNotEmpty,
      );
    },
  );

  test(
    'v7 invalid relationship fails before preferences or database mutation',
    () async {
      final source = AppDatabase.memory();
      final target = AppDatabase.memory();
      addTearDown(source.close);
      addTearDown(target.close);
      await _populateB02Graph(source);
      final valid = await BackupData.createFromDatabase(source);
      final payload =
          jsonDecode(jsonEncode(valid.toJson())) as Map<String, dynamic>;
      final groups = payload['exercise_groups'] as List;
      (groups.single as Map<String, dynamic>)['sessionTemplateId'] =
          'missing-template';
      final invalid = BackupData.fromJson(payload);

      await target
          .into(target.workoutRoutines)
          .insert(WorkoutRoutinesCompanion.insert(name: 'Sentinel', goal: 'x'));
      await target
          .into(target.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: 'Sentinel session',
              totalVolume: 0,
              durationSeconds: 0,
              estimatedCalories: 0,
            ),
          );
      expect(
        () => invalid.restoreToDatabase(target),
        throwsA(isA<FormatException>()),
      );
      expect(
        (await target.select(target.workoutRoutines).get()).single.name,
        'Sentinel',
      );
      expect(
        (await target.select(target.workoutSessions).get()).single.name,
        'Sentinel session',
      );
    },
  );

  test('v7 database failure rolls back B02 rows and preferences', () async {
    final source = AppDatabase.memory();
    final target = AppDatabase.memory();
    addTearDown(source.close);
    addTearDown(target.close);
    await _populateB02Graph(source);
    final valid = await BackupData.createFromDatabase(source);
    await target
        .into(target.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            name: 'Rollback sentinel',
            totalVolume: 0,
            durationSeconds: 0,
            estimatedCalories: 0,
          ),
        );
    await target.customStatement('''
      CREATE TRIGGER fail_b02_backup_restore
      BEFORE INSERT ON performed_sets
      BEGIN
        SELECT RAISE(ABORT, 'simulated B02 restore failure');
      END;
    ''');
    SharedPreferences.setMockInitialValues({'water_logged': 3});
    final prefs = await SharedPreferences.getInstance();
    valid.userPreferences['water_logged'] = 9;

    await expectLater(
      valid.restoreToDatabase(target, prefs),
      throwsA(isA<Exception>()),
    );
    expect(
      (await target.select(target.workoutSessions).get()).map(
        (row) => row.name,
      ),
      contains('Rollback sentinel'),
    );
    expect(await target.select(target.performedSets).get(), isEmpty);
    expect(prefs.getInt('water_logged'), 3);
  });

  test('v6 payload imports without creating B02 execution rows', () async {
    final source = AppDatabase.memory();
    final target = AppDatabase.memory();
    addTearDown(source.close);
    addTearDown(target.close);
    await _populateB02Graph(source);
    final current = await BackupData.createFromDatabase(source);
    final legacyPayload =
        jsonDecode(jsonEncode(current.toJson())) as Map<String, dynamic>;
    legacyPayload['version'] = 6;
    for (final key in const [
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
    ]) {
      legacyPayload.remove(key);
    }
    final legacy = BackupData.fromJson(legacyPayload);
    expect(legacy.version, 6);
    expect(legacy.exerciseGroups, isEmpty);
    expect(legacy.performedSets, isEmpty);
    await legacy.restoreToDatabase(target);
    expect(await target.select(target.exerciseGroups).get(), isEmpty);
    expect(await target.select(target.performedSets).get(), isEmpty);
    expect(await target.select(target.cardioSessionDetails).get(), isEmpty);
  });
}

Future<void> _populateB02Graph(AppDatabase db) async {
  final now = DateTime.utc(2026, 8, 1, 8);
  final exercises = (await db.select(db.exercises).get())
      .where((row) => !row.isCustom && row.stableId != null)
      .take(2)
      .toList();
  final firstExercise = exercises[0];
  final secondExercise = exercises[1];
  final firstId = firstExercise.stableId!;
  final secondId = secondExercise.stableId!;

  await db
      .into(db.programs)
      .insert(
        ProgramsCompanion.insert(
          id: 'b02-program',
          name: 'B02 program',
          createdAtUtc: now,
        ),
      );
  await db
      .into(db.programVersions)
      .insert(
        ProgramVersionsCompanion.insert(
          id: 'b02-version',
          programId: 'b02-program',
          versionNumber: 1,
          status: 'published',
          createdAtUtc: now,
        ),
      );
  await db
      .into(db.programBlocks)
      .insert(
        ProgramBlocksCompanion.insert(
          id: 'b02-block',
          programVersionId: 'b02-version',
          ordinal: 0,
          name: 'Base',
        ),
      );
  await db
      .into(db.programWeeks)
      .insert(
        ProgramWeeksCompanion.insert(
          id: 'b02-week',
          programVersionId: 'b02-version',
          programBlockId: 'b02-block',
          ordinalInBlock: 0,
          programWeekOrdinal: 0,
        ),
      );
  await db
      .into(db.sessionTemplates)
      .insert(
        SessionTemplatesCompanion.insert(
          id: 'b02-template',
          programWeekId: 'b02-week',
          ordinal: 0,
          name: 'B02 strength',
          plannedWeekday: 1,
        ),
      );
  for (final entry in [
    ('b02-prescription-a', firstId, firstExercise.name),
    ('b02-prescription-b', secondId, secondExercise.name),
  ]) {
    await db
        .into(db.exercisePrescriptions)
        .insert(
          ExercisePrescriptionsCompanion.insert(
            id: entry.$1,
            sessionTemplateId: 'b02-template',
            ordinal:
                entry == ('b02-prescription-a', firstId, firstExercise.name)
                ? 0
                : 1,
            exerciseId: Value(entry.$2),
            exerciseNameSnapshot: entry.$3,
            plannedSets: 1,
            repsRange: '8',
          ),
        );
  }
  await db
      .into(db.trainingPlanSettings)
      .insertOnConflictUpdate(
        TrainingPlanSettingsCompanion.insert(
          id: const Value(1),
          updatedAtUtc: now,
        ),
      );

  await db
      .into(db.exerciseGroups)
      .insert(
        ExerciseGroupsCompanion.insert(
          id: 'b02-group',
          sessionTemplateId: 'b02-template',
          ordinal: 0,
          groupType: 'superset',
          roundCount: 1,
        ),
      );
  await db
      .into(db.exerciseGroupMembers)
      .insert(
        ExerciseGroupMembersCompanion.insert(
          id: 'b02-member-a',
          exerciseGroupId: 'b02-group',
          exercisePrescriptionId: 'b02-prescription-a',
          ordinal: 0,
        ),
      );
  await db
      .into(db.exerciseGroupMembers)
      .insert(
        ExerciseGroupMembersCompanion.insert(
          id: 'b02-member-b',
          exerciseGroupId: 'b02-group',
          exercisePrescriptionId: 'b02-prescription-b',
          ordinal: 1,
        ),
      );
  final technique = B02TechniqueFields(
    isDropSet: true,
    segments: [
      B02SetSegment(ordinal: 0, reps: 5, externalLoadKg: 20),
      B02SetSegment(ordinal: 1, reps: 3, externalLoadKg: 15),
    ],
  );
  await db
      .into(db.strengthSetPrescriptions)
      .insert(
        StrengthSetPrescriptionsCompanion.insert(
          id: 'b02-strength-a',
          exercisePrescriptionId: 'b02-prescription-a',
          ordinal: 0,
          targetLoadKg: const Value(20),
          loadBasis: const Value('totalExternal'),
          targetRepsMin: const Value(8),
          targetRepsMax: const Value(10),
          effortMode: const Value('standard'),
          techniquePlanJson: Value(B02TechniqueDraftCodec.encode(technique)),
        ),
      );
  await db
      .into(db.strengthSetPrescriptions)
      .insert(
        StrengthSetPrescriptionsCompanion.insert(
          id: 'b02-strength-b',
          exercisePrescriptionId: 'b02-prescription-b',
          ordinal: 0,
          targetRepsMin: const Value(8),
          targetRepsMax: const Value(8),
        ),
      );

  final strengthSessionId = await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: 'Strength execution',
          totalVolume: 180,
          durationSeconds: 900,
          estimatedCalories: 120,
          completedAt: Value(now),
          activityType: const Value('strength'),
          activitySchemaVersion: const Value(1),
        ),
      );
  final cardioSessionId = await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: 'Run',
          totalVolume: 0,
          durationSeconds: 1200,
          estimatedCalories: 200,
          completedAt: Value(now),
          activityType: const Value('running'),
          activitySchemaVersion: const Value(1),
        ),
      );
  final mobilitySessionId = await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: 'Yoga',
          totalVolume: 0,
          durationSeconds: 600,
          estimatedCalories: 60,
          completedAt: Value(now),
          activityType: const Value('yoga'),
          activitySchemaVersion: const Value(1),
        ),
      );

  await db
      .into(db.cardioSessionDetails)
      .insert(
        CardioSessionDetailsCompanion.insert(
          sessionId: Value(cardioSessionId),
          distanceMetres: const Value(2000),
          inputMode: const Value('manual'),
        ),
      );
  await db
      .into(db.cardioIntervals)
      .insert(
        CardioIntervalsCompanion.insert(
          id: 'b02-interval',
          cardioSessionId: cardioSessionId,
          ordinal: 0,
          segmentType: 'work',
          durationSeconds: const Value(1200),
        ),
      );
  await db
      .into(db.mobilitySessionDetails)
      .insert(
        MobilitySessionDetailsCompanion.insert(
          sessionId: Value(mobilitySessionId),
          practiceType: 'yoga',
          style: const Value('vinyasa'),
        ),
      );

  await db
      .into(db.performedExerciseGroups)
      .insert(
        PerformedExerciseGroupsCompanion.insert(
          id: 'b02-performed-group',
          sessionId: strengthSessionId,
          sourceExerciseGroupId: const Value('b02-group'),
          groupTypeSnapshot: 'superset',
          ordinal: 0,
          plannedRounds: 1,
          completedRounds: const Value(1),
          status: const Value('completed'),
        ),
      );
  for (final entry in [
    ('b02-performed-a', firstId, firstExercise.name, 'b02-prescription-a', 0),
    ('b02-performed-b', secondId, secondExercise.name, 'b02-prescription-b', 1),
  ]) {
    await db
        .into(db.performedExercises)
        .insert(
          PerformedExercisesCompanion.insert(
            id: entry.$1,
            sessionId: strengthSessionId,
            performedExerciseGroupId: const Value('b02-performed-group'),
            sourceExercisePrescriptionId: Value(entry.$4),
            groupMemberOrdinal: Value(entry.$5),
            groupRoundOrdinal: const Value(0),
            ordinal: entry.$5,
            expectedExerciseId: Value(entry.$2),
            expectedExerciseNameSnapshot: Value(entry.$3),
            actualExerciseId: entry.$2,
            actualExerciseNameSnapshot: entry.$3,
            status: const Value('completed'),
          ),
        );
  }
  await db
      .into(db.performedSets)
      .insert(
        PerformedSetsCompanion.insert(
          id: 'b02-set-a',
          performedExerciseId: 'b02-performed-a',
          ordinal: 0,
          role: 'working',
          targetRepsMin: const Value(8),
          actualReps: const Value(8),
          actualLoadKg: const Value(20),
        ),
      );
  await db
      .into(db.performedSets)
      .insert(
        PerformedSetsCompanion.insert(
          id: 'b02-set-b',
          performedExerciseId: 'b02-performed-b',
          ordinal: 0,
          role: 'warmup',
          actualReps: const Value(5),
        ),
      );
  await db
      .into(db.performedSetSegments)
      .insert(
        PerformedSetSegmentsCompanion.insert(
          id: 'b02-segment-a',
          performedSetId: 'b02-set-a',
          ordinal: 0,
          reps: 4,
        ),
      );
  await db
      .into(db.performedSetSegments)
      .insert(
        PerformedSetSegmentsCompanion.insert(
          id: 'b02-segment-b',
          performedSetId: 'b02-set-a',
          ordinal: 1,
          reps: 4,
        ),
      );
  await db
      .into(db.exerciseTargetRecommendations)
      .insert(
        ExerciseTargetRecommendationsCompanion.insert(
          id: 'b02-target',
          performedExerciseId: 'b02-performed-a',
          ruleVersion: 'target-v1',
          confidence: 'medium',
          completenessJson: '{"recovery":"unknown"}',
          recommendedLoadKg: const Value(20),
          targetRepsMin: const Value(8),
          targetRepsMax: const Value(10),
          rationaleCodesJson: '["history"]',
        ),
      );
  await db
      .into(db.performedRestPeriods)
      .insert(
        PerformedRestPeriodsCompanion.insert(
          id: 'b02-rest',
          sessionId: strengthSessionId,
          performedSetId: const Value('b02-set-a'),
          scope: 'exerciseSet',
          recommendedSeconds: const Value(90),
          selectedSeconds: const Value(90),
          actualSeconds: const Value(95),
          source: 'automatic',
          startedAtUtc: now,
          endedAtUtc: Value(now.add(const Duration(seconds: 95))),
          endReason: const Value('elapsed'),
        ),
      );

  await db
      .into(db.exercises)
      .insert(
        ExercisesCompanion.insert(
          stableId: const Value('b02-custom-exercise'),
          name: 'Unresolved custom movement',
          muscleGroups: 'unknown',
          equipment: 'unknown',
          difficulty: 'unknown',
          formCues: '',
          commonMistakes: '',
          isCustom: const Value(true),
        ),
      );
  await db
      .into(db.muscles)
      .insert(
        MusclesCompanion.insert(
          id: 'b02-unknown-muscle',
          displayName: 'Unresolved muscle',
          region: 'unknown',
          catalogVersion: 1,
        ),
      );
  await db
      .into(db.exerciseMuscleMappings)
      .insert(
        ExerciseMuscleMappingsCompanion.insert(
          id: 'b02-unknown-mapping',
          exerciseId: 'b02-custom-exercise',
          muscleId: 'b02-unknown-muscle',
          role: 'primary',
          contributionBasisPoints: 10000,
          mappingStatus: 'unknown',
          catalogVersion: 1,
        ),
      );

  final draftState = B02ExecutionDraftState(
    snapshotId: 'b02-draft-snapshot',
    snapshotVersion: 1,
    activityType: B02ActivityType.strength,
    routineName: 'B02 draft',
    elapsedSeconds: 10,
    currentExerciseOrdinal: 0,
    currentSetOrdinal: 0,
  );
  await db
      .into(db.workoutDrafts)
      .insert(
        WorkoutDraftsCompanion.insert(
          routineName: 'B02 draft',
          currentExerciseIndex: 0,
          currentSetIndex: 0,
          elapsedSeconds: 10,
          loggedSetsJson: '[]',
          draftSchemaVersion: const Value(2),
          activityType: const Value('strength'),
          executionStateJson: Value(B02ExecutionDraftCodec.encode(draftState)),
        ),
      );
  await db
      .into(db.healthProvenances)
      .insert(
        HealthProvenancesCompanion.insert(
          provider: 'test-provider',
          sourceName: 'B02 test',
          importedAt: Value(now),
          localSessionId: Value(strengthSessionId),
          fingerprint: 'b02-fingerprint',
        ),
      );
}
