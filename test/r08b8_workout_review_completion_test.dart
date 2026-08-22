import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_execution_compatibility_read_repository.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/workout_player/b02_strength_summary_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    // Open the lazy Drift connection before widget tests enter the fake
    // async zone; direct database awaits in a widget test otherwise stall.
    await db.select(db.workoutSessions).get();
  });

  tearDown(() => db.close());

  test(
    'saved strength detail preserves exact IDs, groups, roles and facts',
    () async {
      final sessionId = await _insertSavedStrength(
        db,
        completionKind: CompletionKind.partial,
        totalVolume: 480,
      );

      final detail = await B02ExecutionCompatibilityReadRepository(
        db,
      ).readStrengthSession(sessionId);

      expect(detail, isNotNull);
      expect(detail!.isPartial, isTrue);
      expect(detail.durationSeconds, 1234);
      expect(detail.totalVolumeKg, 480);
      expect(detail.groups.single.id, 'performed-group-1');
      expect(detail.groups.single.completedRounds, 1);
      expect(detail.exercises.single.id, 'performed-exercise-1');
      expect(detail.exercises.single.actualExerciseId, 'replacement-exercise');
      expect(detail.exercises.single.expectedExerciseId, 'planned-exercise');
      expect(detail.exercises.single.wasSubstituted, isTrue);
      expect(detail.exercises.single.sets.single.id, 'performed-set-1');
      expect(detail.exercises.single.sets.single.role, B02SetRole.working);
      expect(detail.exercises.single.sets.single.actualRpe, 8);
      expect(
        detail.exercises.single.segmentsFor(
          detail.exercises.single.sets.single,
        ),
        hasLength(2),
      );
    },
  );

  test(
    'history detail fails closed for a missing or non-strength session',
    () async {
      final otherId = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: 'Running',
              totalVolume: 0,
              durationSeconds: 60,
              estimatedCalories: 0,
              activityType: const Value('running'),
            ),
          );
      final repository = B02ExecutionCompatibilityReadRepository(db);
      expect(await repository.readStrengthSession(404), isNull);
      expect(await repository.readStrengthSession(otherId), isNull);
    },
  );

  test('malformed saved completion state fails closed', () async {
    final sessionId = await _insertSavedStrength(
      db,
      completionKind: CompletionKind.full,
      totalVolume: 0,
    );
    await (db.update(
      db.workoutSessions,
    )..where((table) => table.id.equals(sessionId))).write(
      const WorkoutSessionsCompanion(completionKind: Value('unknown')),
    );

    expect(
      B02ExecutionCompatibilityReadRepository(
        db,
      ).readStrengthSession(sessionId),
      throwsA(isA<B02ValidationException>()),
    );
  });

  testWidgets(
    'saved summary uses persisted duration, identity and partial state',
    (tester) async {
      final sessionId = (await tester.runAsync(
        () => _insertSavedStrength(
          db,
          completionKind: CompletionKind.partial,
          totalVolume: 480,
        ),
      ))!;
      final history = (await tester.runAsync(
        () => B02ExecutionCompatibilityReadRepository(
          db,
        ).readStrengthSession(sessionId),
      ))!;
      final launch = _launch(
        routineName: 'Stale draft name',
        actualName: 'Stale draft exercise',
        elapsedSeconds: 2,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            b02StrengthHistoryDetailProvider(
              sessionId,
            ).overrideWith((ref) async => history),
          ],
          child: MaterialApp(
            home: B02WorkoutCompletionSuccess(
              launch: launch,
              sessionId: sessionId,
              completionKind: CompletionKind.partial,
              onDone: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Workout partially completed'), findsOneWidget);
      expect(find.text('Workout complete'), findsNothing);
      expect(find.text('Persisted strength'), findsOneWidget);
      expect(find.text('Replacement strength'), findsOneWidget);
      expect(find.textContaining('20 min 34 sec'), findsOneWidget);
      expect(find.text('480 kg'), findsOneWidget);
      expect(find.text('Stale draft exercise'), findsNothing);
      expect(find.textContaining('RPE 8'), findsOneWidget);
      expect(
        find.textContaining('Performed instead of Planned strength'),
        findsOneWidget,
      );
    },
  );

  testWidgets('full summary has one obvious action and no invented metrics', (
    tester,
  ) async {
    final launch = _launch(
      routineName: 'Quick evidence',
      actualName: 'Quick press',
      elapsedSeconds: 90,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: B02WorkoutCompletionSuccess(launch: launch, onDone: () {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Workout complete'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.textContaining('kcal'), findsNothing);
    expect(find.textContaining('e1RM'), findsNothing);
    expect(find.textContaining('personal best'), findsNothing);
    expect(find.textContaining('progress'), findsNothing);
    expect(find.textContaining('Target'), findsNothing);
  });

  test(
    'controller exposes the exact session returned by canonical finalization',
    () async {
      final repository = StrengthExecutionRepository(
        db: db,
        calendarRepo: CalendarRepository(db),
        nowUtc: () => DateTime.utc(2026, 8, 22, 10),
      );
      final adapter = StrengthExecutionCompatibilityAdapter(repository);
      final launch = await adapter.startUnscheduledDraft(
        routineName: 'Controller evidence',
        executionSnapshotJson: '{"version":1}',
      );
      final withExercise = await adapter.addUnscheduledExercise(
        launch: launch,
        exerciseId: 'controller-exercise',
        exerciseName: 'Controller exercise',
      );
      // Quick additions require a canonical exercise row for finalization
      // ancestry validation, so insert it before the actual set is recorded.
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: const Value('controller-exercise'),
              name: 'Controller exercise',
              muscleGroups: 'Chest',
              equipment: 'Barbell',
              difficulty: 'Intermediate',
              formCues: '',
              commonMistakes: '',
            ),
          );
      final exercise = B02PerformedExerciseDraft(
        id: 'performed:controller-exercise',
        ordinal: 0,
        expectedExerciseId: 'controller-exercise',
        expectedExerciseNameSnapshot: 'Controller exercise',
        actualExerciseId: 'controller-exercise',
        actualExerciseNameSnapshot: 'Controller exercise',
        status: 'completed',
        sets: [
          B02PerformedSet(
            id: 'set:controller-exercise:0',
            performedExerciseId: 'performed:controller-exercise',
            ordinal: 0,
            role: B02SetRole.working,
            actualReps: 5,
            actualLoadKg: 40,
            actualLoadBasis: B02LoadBasis.totalExternal,
          ),
        ],
      );
      final finalizedState = withExercise.state.copyWith(
        elapsedSeconds: 60,
        performedExercises: [exercise],
      );
      await adapter.saveDraft(
        draftId: withExercise.draftId,
        state: finalizedState,
      );
      // The adapter-level finalizer is the authority exercised by the player;
      // this test verifies its returned session ID can be read back exactly.
      final sessionId = await adapter.finalizeDraft(
        draftId: withExercise.draftId,
        commandId: 'b8-exact-session',
        state: finalizedState,
      );
      expect(sessionId, greaterThan(0));
      expect(
        (await B02ExecutionCompatibilityReadRepository(
          db,
        ).readStrengthSession(sessionId))!.sessionId,
        sessionId,
      );
    },
  );
}

B02StrengthExecutionLaunch _launch({
  required String routineName,
  required String actualName,
  required int elapsedSeconds,
}) {
  final exercise = B02PerformedExerciseDraft(
    id: 'draft-exercise',
    ordinal: 0,
    expectedExerciseId: 'quick-exercise',
    expectedExerciseNameSnapshot: actualName,
    actualExerciseId: 'quick-exercise',
    actualExerciseNameSnapshot: actualName,
    status: 'completed',
    sets: [
      B02PerformedSet(
        id: 'draft-set',
        performedExerciseId: 'draft-exercise',
        ordinal: 0,
        role: B02SetRole.working,
        actualReps: 8,
        actualLoadKg: 60,
        actualLoadBasis: B02LoadBasis.totalExternal,
      ),
    ],
  );
  return B02StrengthExecutionLaunch(
    draftId: 91,
    occurrenceId: null,
    executionSnapshotJson: '{"version":1}',
    state: B02ExecutionDraftState(
      snapshotId: 'b8-snapshot',
      snapshotVersion: 1,
      activityType: B02ActivityType.strength,
      routineName: routineName,
      elapsedSeconds: elapsedSeconds,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
      performedExercises: [exercise],
    ),
  );
}

Future<int> _insertSavedStrength(
  AppDatabase db, {
  required CompletionKind completionKind,
  required double totalVolume,
}) async {
  await _insertExercise(db, 'planned-exercise', 'Planned strength');
  await _insertExercise(db, 'replacement-exercise', 'Replacement strength');
  final sessionId = await db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: 'Persisted strength',
          totalVolume: totalVolume,
          durationSeconds: 1234,
          estimatedCalories: 0,
          completionKind: Value(completionKind.dbValue),
          activityType: const Value('strength'),
          activitySchemaVersion: const Value(1),
        ),
      );
  await db
      .into(db.performedExerciseGroups)
      .insert(
        PerformedExerciseGroupsCompanion.insert(
          id: 'performed-group-1',
          sessionId: sessionId,
          groupTypeSnapshot: 'superset',
          ordinal: 0,
          plannedRounds: 2,
          completedRounds: const Value(1),
          status: const Value('partial'),
        ),
      );
  await db
      .into(db.performedExercises)
      .insert(
        PerformedExercisesCompanion.insert(
          id: 'performed-exercise-1',
          sessionId: sessionId,
          performedExerciseGroupId: const Value('performed-group-1'),
          groupMemberOrdinal: const Value(0),
          groupRoundOrdinal: const Value(0),
          ordinal: 0,
          expectedExerciseId: const Value('planned-exercise'),
          expectedExerciseNameSnapshot: const Value('Planned strength'),
          actualExerciseId: 'replacement-exercise',
          actualExerciseNameSnapshot: 'Replacement strength',
          status: const Value('partial'),
          substitutionReason: const Value('Equipment unavailable'),
        ),
      );
  await db
      .into(db.performedSets)
      .insert(
        PerformedSetsCompanion.insert(
          id: 'performed-set-1',
          performedExerciseId: 'performed-exercise-1',
          ordinal: 0,
          role: B02SetRole.working.dbValue,
          actualLoadKg: const Value(80),
          actualLoadBasis: const Value('totalExternal'),
          actualReps: const Value(6),
          actualRpe: const Value(8),
          effortMode: const Value('toFailure'),
          endedAtFailure: const Value(true),
        ),
      );
  await db
      .into(db.performedSetSegments)
      .insert(
        PerformedSetSegmentsCompanion.insert(
          id: 'segment-1',
          performedSetId: 'performed-set-1',
          ordinal: 0,
          reps: 4,
          externalLoadKg: const Value(80),
        ),
      );
  await db
      .into(db.performedSetSegments)
      .insert(
        PerformedSetSegmentsCompanion.insert(
          id: 'segment-2',
          performedSetId: 'performed-set-1',
          ordinal: 1,
          reps: 2,
          externalLoadKg: const Value(60),
          restBeforeSeconds: const Value(20),
        ),
      );
  return sessionId;
}

Future<void> _insertExercise(AppDatabase db, String id, String name) => db
    .into(db.exercises)
    .insert(
      ExercisesCompanion.insert(
        stableId: Value(id),
        name: name,
        muscleGroups: 'Chest',
        equipment: 'Barbell',
        difficulty: 'Intermediate',
        formCues: '',
        commonMistakes: '',
      ),
    );
