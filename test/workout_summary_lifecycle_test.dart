import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/workout_draft_codec.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/workout_player/workout_player_controller.dart';
import 'package:indifit/features/workout_player/workout_summary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test repository seam allowing controllable failure injection and call count tracking.
class ControllableWorkoutRepository extends WorkoutRepository {
  bool shouldFail = false;
  int logSessionCallCount = 0;

  ControllableWorkoutRepository(super.db);

  @override
  Future<int> logSession({
    required String name,
    required double volume,
    required int durationSeconds,
    required int calories,
    required List<WorkoutSetsCompanion> sets,
    DateTime? completedAt,
  }) async {
    logSessionCallCount++;
    if (shouldFail) {
      throw Exception('Simulated database failure during session save');
    }
    return super.logSession(
      name: name,
      volume: volume,
      durationSeconds: durationSeconds,
      calories: calories,
      sets: sets,
      completedAt: completedAt,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ControllableWorkoutRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    repo = ControllableWorkoutRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('B01-04 Workout Summary Lifecycle & Idempotency Tests (Remediated)', () {
    test('1. Opening summary preserves the draft', () async {
      final jsonStr = WorkoutDraftCodec.encode(
        routineName: 'Push Split',
        currentExerciseIndex: 0,
        currentSetIndex: 1,
        elapsedSeconds: 180,
        loggedSets: [
          WorkoutSetsCompanion.insert(
            sessionId: 0,
            exerciseName: 'Bench Press',
            weight: 80.0,
            reps: 8,
            setNumber: 1,
            isPr: const Value(false),
          ),
        ],
      );

      await repo.saveWorkoutDraft(
        WorkoutDraftsCompanion.insert(
          routineName: 'Push Split',
          currentExerciseIndex: 0,
          currentSetIndex: 1,
          elapsedSeconds: 180,
          loggedSetsJson: jsonStr,
        ),
      );

      var draft = await repo.getActiveDraft();
      expect(draft, isNotNull);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final controller = WorkoutPlayerController(
        container.read(providerContainerProvider).ref,
        routineName: 'Push Split',
        initialExercises: const [],
      );

      await controller.finishWorkout(); // Stops timer for summary transition

      draft = await repo.getActiveDraft();
      expect(draft, isNotNull);
      expect(draft!.routineName, equals('Push Split'));
    });

    testWidgets('2. Leaving or cancelling summary preserves the draft', (
      WidgetTester tester,
    ) async {
      final jsonStr = WorkoutDraftCodec.encode(
        routineName: 'Leg Split',
        currentExerciseIndex: 1,
        currentSetIndex: 0,
        elapsedSeconds: 240,
        loggedSets: [
          WorkoutSetsCompanion.insert(
            sessionId: 0,
            exerciseName: 'Barbell Squat',
            weight: 100.0,
            reps: 5,
            setNumber: 1,
          ),
        ],
      );

      await repo.saveWorkoutDraft(
        WorkoutDraftsCompanion.insert(
          routineName: 'Leg Split',
          currentExerciseIndex: 1,
          currentSetIndex: 0,
          elapsedSeconds: 240,
          loggedSetsJson: jsonStr,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [workoutRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: WorkoutSummaryScreen(
              routineName: 'Leg Split',
              elapsedSeconds: 240,
              loggedSets: [],
            ),
          ),
        ),
      );

      final draft = await repo.getActiveDraft();
      expect(draft, isNotNull);
      expect(draft!.routineName, equals('Leg Split'));
    });

    testWidgets(
      '3 & 4. Successful session save persists 1 session, all sets, and deletes draft afterward',
      (WidgetTester tester) async {
        final jsonStr = WorkoutDraftCodec.encode(
          routineName: 'Chest & Arms',
          currentExerciseIndex: 0,
          currentSetIndex: 1,
          elapsedSeconds: 300,
          loggedSets: [
            WorkoutSetsCompanion.insert(
              sessionId: 0,
              exerciseName: 'Incline Bench',
              weight: 70.0,
              reps: 10,
              setNumber: 1,
            ),
          ],
        );

        await repo.saveWorkoutDraft(
          WorkoutDraftsCompanion.insert(
            routineName: 'Chest & Arms',
            currentExerciseIndex: 0,
            currentSetIndex: 1,
            elapsedSeconds: 300,
            loggedSetsJson: jsonStr,
          ),
        );

        expect(await repo.getActiveDraft(), isNotNull);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [workoutRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: WorkoutSummaryScreen(
                routineName: 'Chest & Arms',
                elapsedSeconds: 300,
                loggedSets: [
                  WorkoutSetsCompanion(
                    sessionId: Value(0),
                    exerciseName: Value('Incline Bench'),
                    weight: Value(70.0),
                    reps: Value(10),
                    setNumber: Value(1),
                  ),
                ],
              ),
            ),
          ),
        );

        final saveButton = find.widgetWithText(
          ElevatedButton,
          'Save Workout & Exit',
        );
        expect(saveButton, findsOneWidget);

        await tester.tap(saveButton);
        await tester.pump(); // Execute tap handler

        // 1. Exactly 1 session must be logged in database
        final sessions = await db.select(db.workoutSessions).get();
        expect(sessions.length, equals(1));
        expect(sessions.first.name, equals('Chest & Arms'));

        // 2. Logged sets must be present in database
        final sets = await db.select(db.workoutSets).get();
        expect(sets.length, equals(1));
        expect(sets.first.exerciseName, equals('Incline Bench'));

        // 3. Active draft MUST be deleted ONLY AFTER successful save
        final activeDraft = await repo.getActiveDraft();
        expect(activeDraft, isNull);
        expect(repo.logSessionCallCount, equals(1));
      },
    );

    testWidgets(
      '5 & 6. Failed session save preserves draft and displays failure',
      (WidgetTester tester) async {
        repo.shouldFail = true; // Inject database failure

        final jsonStr = WorkoutDraftCodec.encode(
          routineName: 'Failing Routine',
          currentExerciseIndex: 0,
          currentSetIndex: 0,
          elapsedSeconds: 100,
          loggedSets: [
            WorkoutSetsCompanion.insert(
              sessionId: 0,
              exerciseName: 'Press',
              weight: 50.0,
              reps: 5,
              setNumber: 1,
            ),
          ],
        );

        await repo.saveWorkoutDraft(
          WorkoutDraftsCompanion.insert(
            routineName: 'Failing Routine',
            currentExerciseIndex: 0,
            currentSetIndex: 0,
            elapsedSeconds: 100,
            loggedSetsJson: jsonStr,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [workoutRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: WorkoutSummaryScreen(
                routineName: 'Failing Routine',
                elapsedSeconds: 100,
                loggedSets: [],
              ),
            ),
          ),
        );

        final saveButton = find.widgetWithText(
          ElevatedButton,
          'Save Workout & Exit',
        );
        await tester.tap(saveButton);
        await tester.pump(); // Execute save handler and trigger error SnackBar

        // SnackBar must display failure message
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Failed to save session'), findsOneWidget);

        // Database session count MUST be 0
        final sessions = await db.select(db.workoutSessions).get();
        expect(sessions, isEmpty);

        // Active draft MUST be preserved in database for user recovery
        final activeDraft = await repo.getActiveDraft();
        expect(activeDraft, isNotNull);
        expect(activeDraft!.routineName, equals('Failing Routine'));
      },
    );

    testWidgets(
      '7 & 8 & 10. Retry after failure succeeds and resets saving guard',
      (WidgetTester tester) async {
        repo.shouldFail = true;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [workoutRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: WorkoutSummaryScreen(
                routineName: 'Retry Test Routine',
                elapsedSeconds: 150,
                loggedSets: [
                  WorkoutSetsCompanion(
                    sessionId: Value(0),
                    exerciseName: Value('Dumbbell Press'),
                    weight: Value(25.0),
                    reps: Value(10),
                    setNumber: Value(1),
                  ),
                ],
              ),
            ),
          ),
        );

        final saveButton = find.widgetWithText(
          ElevatedButton,
          'Save Workout & Exit',
        );

        // Attempt 1: Fails
        await tester.tap(saveButton);
        await tester.pump();
        expect(repo.logSessionCallCount, equals(1));
        expect((await db.select(db.workoutSessions).get()), isEmpty);

        // Fix failure condition and retry
        repo.shouldFail = false;

        // Attempt 2 (Retry): Succeeds
        await tester.tap(saveButton);
        await tester.pump();

        expect(repo.logSessionCallCount, equals(2));

        // Exactly ONE durable session created for the successful attempt
        final sessions = await db.select(db.workoutSessions).get();
        expect(sessions.length, equals(1));
        expect(sessions.first.name, equals('Retry Test Routine'));
      },
    );

    testWidgets(
      '9. Repeated save taps while saving produce one repository call',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [workoutRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: WorkoutSummaryScreen(
                routineName: 'Multi-Tap Guard Test',
                elapsedSeconds: 200,
                loggedSets: [
                  WorkoutSetsCompanion(
                    sessionId: Value(0),
                    exerciseName: Value('Dumbbell Curl'),
                    weight: Value(15.0),
                    reps: Value(12),
                    setNumber: Value(1),
                  ),
                ],
              ),
            ),
          ),
        );

        final saveButton = find.byType(ElevatedButton);
        expect(saveButton, findsOneWidget);

        // Rapid multi-tap
        await tester.tap(saveButton);
        await tester.tap(saveButton);
        await tester.tap(saveButton);
        await tester.pump();

        // Exactly ONE repository logSession call must occur
        expect(repo.logSessionCallCount, equals(1));
        final sessions = await db.select(db.workoutSessions).get();
        expect(sessions.length, equals(1));
      },
    );

    test(
      '11. Dashboard active-draft loading restores with WorkoutDraftCodec',
      () async {
        final jsonStr = WorkoutDraftCodec.encode(
          routineName: 'Dashboard Resume Test',
          currentExerciseIndex: 0,
          currentSetIndex: 0,
          elapsedSeconds: 400,
          loggedSets: [
            WorkoutSetsCompanion.insert(
              sessionId: 0,
              exerciseName: 'Pull-Ups',
              weight: 0.0,
              reps: 10,
              setNumber: 1,
              isPr: const Value(true),
              rpe: const Value(8),
              setNotes: const Value('Clean reps'),
            ),
          ],
        );

        await repo.saveWorkoutDraft(
          WorkoutDraftsCompanion.insert(
            routineName: 'Dashboard Resume Test',
            currentExerciseIndex: 0,
            currentSetIndex: 0,
            elapsedSeconds: 400,
            loggedSetsJson: jsonStr,
          ),
        );

        final draft = await repo.getActiveDraft();
        expect(draft, isNotNull);

        final restoredCompanions = WorkoutDraftCodec.decodeLoggedSets(
          draft!.loggedSetsJson,
        );
        expect(restoredCompanions.length, equals(1));
        expect(restoredCompanions.first.exerciseName.value, equals('Pull-Ups'));
        expect(restoredCompanions.first.rpe.value, equals(8));
        expect(restoredCompanions.first.setNotes.value, equals('Clean reps'));
      },
    );
  });
}

// Provider container ref helper for unit tests
final providerContainerProvider = Provider<ProviderContainerRef>(
  (ref) => ProviderContainerRef(ref),
);

class ProviderContainerRef {
  final Ref ref;
  ProviderContainerRef(this.ref);
}
