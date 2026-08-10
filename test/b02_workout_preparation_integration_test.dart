import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StrengthExecutionRepository repository;
  late StrengthExecutionCompatibilityAdapter adapter;
  late String profileId;

  setUp(() async {
    db = AppDatabase.memory();
    final calendar = CalendarRepository(db);
    repository = StrengthExecutionRepository(
      db: db,
      calendarRepo: calendar,
      nowUtc: () => DateTime.utc(2026, 8, 3, 7),
    );
    adapter = StrengthExecutionCompatibilityAdapter(repository);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('bench-stable'),
            name: 'Flat Barbell Bench Press',
            muscleGroups: 'Chest,Triceps',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Elbows',
          ),
        );
    await db
        .into(db.programs)
        .insert(
          ProgramsCompanion.insert(
            id: 'b02-test-program',
            name: 'B02 test program',
            createdAtUtc: DateTime.utc(2026, 8, 1),
          ),
        );
    await db
        .into(db.programVersions)
        .insert(
          ProgramVersionsCompanion.insert(
            id: 'b02-test-version',
            programId: 'b02-test-program',
            versionNumber: 1,
            status: 'published',
            createdAtUtc: DateTime.utc(2026, 8, 1),
          ),
        );
    await db
        .into(db.programBlocks)
        .insert(
          ProgramBlocksCompanion.insert(
            id: 'b02-test-block',
            programVersionId: 'b02-test-version',
            ordinal: 0,
            name: 'B02 test block',
          ),
        );
    await db
        .into(db.programWeeks)
        .insert(
          ProgramWeeksCompanion.insert(
            id: 'b02-test-week',
            programVersionId: 'b02-test-version',
            programBlockId: 'b02-test-block',
            ordinalInBlock: 0,
            programWeekOrdinal: 0,
          ),
        );
    await db
        .into(db.sessionTemplates)
        .insert(
          SessionTemplatesCompanion.insert(
            id: 'b02-test-template',
            programWeekId: 'b02-test-week',
            ordinal: 0,
            name: 'B02 test session',
            plannedWeekday: 1,
          ),
        );
    await db
        .into(db.exercisePrescriptions)
        .insert(
          ExercisePrescriptionsCompanion.insert(
            id: 'prescription-bench',
            sessionTemplateId: 'b02-test-template',
            ordinal: 0,
            exerciseId: const Value('bench-stable'),
            exerciseNameSnapshot: 'Flat Barbell Bench Press',
            plannedSets: 1,
            repsRange: '8-10',
          ),
        );
    profileId = await EquipmentProfileRepository(db).createProfile(
      name: 'Home barbell',
      defaultWeightIncrementKg: 2.5,
      items: const [
        EquipmentProfileItemInput(
          equipmentCode: 'barbell',
          weightIncrementKg: 2.5,
        ),
      ],
    );
  });

  tearDown(() => db.close());

  Future<void> insertHistory() async {
    final sessionId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            name: 'Prior press',
            totalVolume: 800,
            durationSeconds: 900,
            estimatedCalories: 0,
            completedAt: Value(DateTime.utc(2026, 8, 1, 7)),
            activityType: const Value('strength'),
            activitySchemaVersion: const Value(1),
          ),
        );
    await db
        .into(db.performedExercises)
        .insert(
          PerformedExercisesCompanion.insert(
            id: 'history-exercise',
            sessionId: sessionId,
            ordinal: 0,
            expectedExerciseId: const Value('bench-stable'),
            expectedExerciseNameSnapshot: const Value(
              'Flat Barbell Bench Press',
            ),
            actualExerciseId: 'bench-stable',
            actualExerciseNameSnapshot: 'Flat Barbell Bench Press',
            status: const Value('completed'),
          ),
        );
    await db
        .into(db.performedSets)
        .insert(
          PerformedSetsCompanion.insert(
            id: 'history-set',
            performedExerciseId: 'history-exercise',
            ordinal: 0,
            role: 'working',
            actualLoadKg: const Value(80),
            actualLoadBasis: const Value('totalExternal'),
            actualReps: const Value(10),
            actualRpe: const Value(7),
            effortMode: const Value('standard'),
          ),
        );
  }

  String snapshot({bool includeTarget = true, int? restSeconds}) => jsonEncode({
    'version': 1,
    'routineName': 'Prepared press',
    'week': {'isDeload': false},
    'equipmentProfile': {'equipmentProfileId': profileId},
    'groups': const [],
    'prescriptions': [
      {
        'id': 'prescription-bench',
        'exerciseId': 'bench-stable',
        'exerciseNameSnapshot': 'Flat Barbell Bench Press',
        'plannedSets': 1,
        'repsRange': '8-10',
        if (includeTarget) 'targetLoadKg': 80,
        if (includeTarget) 'loadBasis': 'totalExternal',
        if (includeTarget) 'targetRpe': 8,
        'restSeconds': ?restSeconds,
      },
    ],
  });

  test(
    'production preparation freezes target and warm-up, preserves override, and routes rest through B02',
    () async {
      await insertHistory();
      final controller = B02StrengthExecutionController(adapter);
      addTearDown(controller.dispose);

      await controller.startUnscheduled(
        routineName: 'Prepared press',
        executionSnapshotJson: snapshot(),
      );

      final preparedSlot = controller.state.slots.single;
      final offered =
          controller.state.launch!.state.targetRecommendations[preparedSlot.id];
      expect(offered, isNotNull);
      expect(offered!.recommendedLoadKg, 82.5);
      expect(preparedSlot.targetLoadKg, 82.5);
      expect(
        controller.state.launch!.state.warmupRecommendation?.availability,
        B02WarmupAvailability.available,
      );
      expect(
        controller.state.launch!.state.warmupRecommendation!.proposals,
        isNotEmpty,
      );

      await controller.chooseWarmup(B02WarmupDecision.accepted);
      final resumed = await repository.readDraft(
        controller.state.launch!.draftId,
      );
      expect(
        resumed.state.warmupRecommendation!.decision,
        B02WarmupDecision.accepted,
      );

      await controller.overrideTarget(preparedSlot, loadKg: 85);
      expect(
        controller
            .state
            .launch!
            .state
            .targetRecommendations[preparedSlot.id]!
            .wasOverridden,
        isTrue,
      );
      expect(
        controller
            .state
            .launch!
            .state
            .targetRecommendations[preparedSlot.id]!
            .recommendedLoadKg,
        82.5,
      );

      await controller.recordSet(
        slot: preparedSlot,
        reps: 10,
        loadKg: 85,
        rpe: 8,
      );
      expect(
        controller.state.launch!.state.targetOverrides[preparedSlot.id]!.loadKg,
        85,
      );
      expect(
        controller
            .state
            .launch!
            .state
            .performedExercises
            .single
            .sets
            .single
            .targetLoadKg,
        85,
      );
      await controller.beginRest(preparedSlot);
      final openRest = controller.state.launch!.state.restPeriods.single;
      expect(openRest.source, B02RestSource.automatic);
      expect(openRest.recommendedSeconds, 90);
      expect(openRest.selectedSeconds, 90);
      await controller.extendRest(openRest.id);
      expect(
        controller.state.launch!.state.restPeriods.single.selectedSeconds,
        120,
      );
      await controller.skipRest(openRest.id);
      final durableBeforeFinish = await repository.readDraft(
        controller.state.launch!.draftId,
      );
      expect(
        durableBeforeFinish
            .state
            .performedExercises
            .single
            .sets
            .single
            .targetLoadKg,
        85,
      );

      await controller.finalize(commandId: 'finish-prepared');
      final persistedSet = await (db.select(
        db.performedSets,
      )..where((table) => table.actualLoadKg.equals(85))).getSingle();
      expect(persistedSet.targetLoadKg, 85);
      expect(persistedSet.actualLoadKg, 85);
      final persistedRecommendation =
          (await db.select(db.exerciseTargetRecommendations).get()).single;
      expect(persistedRecommendation.recommendedLoadKg, 82.5);
      expect(persistedRecommendation.wasOverridden, isTrue);
      final persistedRest =
          (await db.select(db.performedRestPeriods).get()).single;
      expect(persistedRest.recommendedSeconds, 90);
      expect(persistedRest.selectedSeconds, 120);
      expect(persistedRest.source, B02RestSource.automatic.dbValue);
    },
  );

  test(
    'missing target evidence stays unavailable instead of becoming zero',
    () async {
      final controller = B02StrengthExecutionController(adapter);
      addTearDown(controller.dispose);

      await controller.startUnscheduled(
        routineName: 'Unknown target',
        executionSnapshotJson: snapshot(includeTarget: false),
      );

      final slot = controller.state.slots.single;
      final recommendation =
          controller.state.launch!.state.targetRecommendations[slot.id]!;
      expect(recommendation.recommendedLoadKg, isNull);
      expect(recommendation.confidence, B02Confidence.insufficient);
      expect(slot.targetLoadKg, isNull);
      expect(
        controller.state.launch!.state.warmupRecommendation!.availability,
        B02WarmupAvailability.unavailable,
      );
    },
  );

  test('elapsed rest closes through the durable B02 rest path', () async {
    final controller = B02StrengthExecutionController(adapter);
    addTearDown(controller.dispose);

    await controller.startUnscheduled(
      routineName: 'Elapsed rest press',
      executionSnapshotJson: snapshot(),
    );
    final slot = controller.state.slots.single;
    await controller.recordSet(slot: slot, reps: 8, loadKg: 80, rpe: 8);
    await controller.beginRest(slot);

    final period = controller.state.launch!.state.restPeriods.single;
    final endedAt = period.startedAtUtc.add(const Duration(seconds: 91));
    await controller.completeRest(period.id, endedAtUtc: endedAt);

    final completed = controller.state.launch!.state.restPeriods.single;
    expect(completed.endedAtUtc, endedAt);
    expect(completed.actualSeconds, 91);
    expect(completed.endReason, B02RestEndReason.elapsed);
  });

  test(
    'prescribed rest remains ahead of automatic rest in production slots',
    () async {
      final controller = B02StrengthExecutionController(adapter);
      addTearDown(controller.dispose);

      await controller.startUnscheduled(
        routineName: 'Configured rest',
        executionSnapshotJson: snapshot(restSeconds: 150),
      );
      final slot = controller.state.slots.single;
      await controller.recordSet(slot: slot, reps: 8, loadKg: 80, rpe: 9);
      await controller.beginRest(slot);

      final period = controller.state.launch!.state.restPeriods.single;
      expect(period.source, B02RestSource.prescription);
      expect(period.recommendedSeconds, 150);
      expect(period.selectedSeconds, 150);
    },
  );

  test(
    'rest-pause execution routes its intra-set interval through B02 rest',
    () async {
      final controller = B02StrengthExecutionController(adapter);
      addTearDown(controller.dispose);

      await controller.startUnscheduled(
        routineName: 'Rest-pause press',
        executionSnapshotJson: snapshot(),
      );
      final slot = controller.state.slots.single;
      await controller.recordSet(
        slot: slot,
        reps: 8,
        loadKg: 80,
        rpe: 9,
        technique: B02TechniqueFields(
          isRestPause: true,
          segments: [
            B02SetSegment(ordinal: 0, reps: 4, externalLoadKg: 80),
            B02SetSegment(
              ordinal: 1,
              reps: 4,
              externalLoadKg: 80,
              restBeforeSeconds: 30,
            ),
          ],
        ),
      );
      await controller.beginRest(slot);

      final period = controller.state.launch!.state.restPeriods.single;
      expect(period.scope, B02RestScope.restPause);
      expect(period.source, B02RestSource.prescription);
      expect(period.recommendedSeconds, 30);
      expect(period.performedSetId, isNotNull);
      expect(period.performedExerciseGroupId, isNull);
    },
  );
}
