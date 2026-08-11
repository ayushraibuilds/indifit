import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/services/b02_strength_execution_draft_service.dart';
import 'package:indifit/features/workout_player/quick_workout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;
  late StrengthExecutionRepository executions;

  setUp(() async {
    db = AppDatabase.memory();
    executions = StrengthExecutionRepository(
      db: db,
      calendarRepo: CalendarRepository(db),
      nowUtc: () => DateTime.utc(2026, 8, 10, 8),
    );
    for (final exercise in [
      ('quick-bench', 'Bench press'),
      ('quick-row', 'Seated row'),
    ]) {
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: Value(exercise.$1),
              name: exercise.$2,
              muscleGroups: 'Back,Chest',
              equipment: 'Barbell',
              difficulty: 'Intermediate',
              formCues: 'Brace',
              commonMistakes: 'Rushing',
            ),
          );
    }
  });

  tearDown(() => db.close());

  test('Quick Workout adds and removes canonical exercise slots', () async {
    final launch = await executions.startUnscheduledDraft(
      routineName: 'Quick workout',
      executionSnapshotJson: quickWorkoutSnapshotJson('Quick workout'),
      snapshotId: 'quick-draft-1',
    );
    final withBench = await executions.addUnscheduledExercise(
      launch: launch,
      exerciseId: 'quick-bench',
      exerciseName: 'Bench press',
    );
    final withRow = await executions.addUnscheduledExercise(
      launch: withBench,
      exerciseId: 'quick-row',
      exerciseName: 'Seated row',
    );

    expect(await executions.readExecutionSlots(withRow), hasLength(2));
    final removed = await executions.removeUnscheduledExercise(
      launch: withRow,
      prescriptionId:
          (jsonDecode(withBench.executionSnapshotJson)
                  as Map<String, dynamic>)['prescriptions'][0]['id']
              as String,
    );
    final slots = await executions.readExecutionSlots(removed);
    expect(slots, hasLength(1));
    expect(slots.single.exerciseNameSnapshot, 'Seated row');
    expect(removed.occurrenceId, isNull);
  });

  test(
    'Quick Workout persists unlimited sets and multiple sessions per day',
    () async {
      final service = const B02StrengthExecutionDraftService();

      Future<int> finish(String draftId, String commandId) async {
        final launch = await executions.startUnscheduledDraft(
          routineName: 'Quick workout',
          executionSnapshotJson: jsonEncode({
            'version': 1,
            'routineName': 'Quick workout',
            'prescriptions': [
              {
                'id': 'quick:$draftId',
                'exerciseId': 'quick-bench',
                'exerciseNameSnapshot': 'Bench press',
                'plannedSets': 1,
                'repsRange': '6-12',
              },
            ],
          }),
          snapshotId: draftId,
        );
        final prepared = await executions.prepareExecution(launch);
        final slot = prepared.slots.single;
        var state = service.recordSet(
          state: prepared.state,
          slot: slot,
          reps: 8,
          loadKg: 60,
          useSlotPrescription: false,
        );
        state = service.recordSet(
          state: state,
          slot: slot,
          reps: 7,
          loadKg: 60,
          useSlotPrescription: false,
        );
        expect(state.performedExercises.single.sets, hasLength(2));
        expect(state.performedExercises.single.status, 'completed');
        await executions.saveDraft(draftId: launch.draftId, state: state);
        return executions.finalizeDraft(
          draftId: launch.draftId,
          commandId: commandId,
          state: state,
          completedAtUtc: DateTime.utc(2026, 8, 10, 8),
        );
      }

      final first = await finish('quick-draft-a', 'quick-finish-a');
      final second = await finish('quick-draft-b', 'quick-finish-b');

      expect(first, isNot(second));
      expect(await db.select(db.workoutSessions).get(), hasLength(2));
      expect(
        (await db.select(db.workoutSessions).get()).every(
          (session) => session.scheduledOccurrenceId == null,
        ),
        isTrue,
      );
      expect(await db.select(db.performedSets).get(), hasLength(4));
    },
  );

  testWidgets('Quick Workout is a first-class empty entry surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const QuickWorkoutScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Quick workout'), findsOneWidget);
    expect(find.text('Start anywhere'), findsOneWidget);
    expect(find.text('Add exercise'), findsOneWidget);
    expect(find.textContaining('No plan or schedule'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(QuickWorkoutScreen),
      matchesGoldenFile('goldens/ux_r07b_quick_workout_empty_light.png'),
    );
  });
}
