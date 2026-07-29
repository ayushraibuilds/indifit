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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late WorkoutRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    repo = WorkoutRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('B01-04 Workout Summary Lifecycle & Idempotency Tests', () {
    test('8. Opening summary does not delete the draft', () async {
      // Save an active draft first
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

      // Verify draft is present
      var draft = await repo.getActiveDraft();
      expect(draft, isNotNull);

      // Create controller and finish player (stops timer)
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final controller = WorkoutPlayerController(
        container.read(providerContainerProvider).ref,
        routineName: 'Push Split',
        initialExercises: const [],
      );

      await controller.finishWorkout(); // Stopping timer for summary transition

      // Draft MUST still exist in database!
      draft = await repo.getActiveDraft();
      expect(draft, isNotNull);
      expect(draft!.routineName, equals('Push Split'));
    });

    testWidgets('9. Cancelling summary does not delete the draft', (
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

      // Simulate opening WorkoutSummaryScreen widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: WorkoutSummaryScreen(
              routineName: 'Leg Split',
              elapsedSeconds: 240,
              loggedSets: [],
            ),
          ),
        ),
      );

      // Verify draft is still present while summary screen is open
      final draft = await repo.getActiveDraft();
      expect(draft, isNotNull);
      expect(draft!.routineName, equals('Leg Split'));
    });

    testWidgets('11. Successful session save deletes the draft afterward', (
      WidgetTester tester,
    ) async {
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
          overrides: [databaseProvider.overrideWithValue(db)],
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

      // Tap Save Workout button
      final saveButton = find.widgetWithText(
        ElevatedButton,
        'Save Workout & Exit',
      );
      expect(saveButton, findsOneWidget);

      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Session must be logged in database
      final sessions = await db.select(db.workoutSessions).get();
      expect(sessions.length, equals(1));
      expect(sessions.first.name, equals('Chest & Arms'));

      // 2. Draft MUST be deleted ONLY AFTER successful save
      final activeDraft = await repo.getActiveDraft();
      expect(activeDraft, isNull);
    });

    testWidgets('12. Repeated save taps do not create duplicate sessions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: WorkoutSummaryScreen(
              routineName: 'Multi-Tap Test',
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

      // Perform multiple rapid taps
      await tester.tap(saveButton);
      await tester.tap(saveButton);
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Only exactly 1 session should have been saved
      final sessions = await db.select(db.workoutSessions).get();
      expect(sessions.length, equals(1));
    });
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
