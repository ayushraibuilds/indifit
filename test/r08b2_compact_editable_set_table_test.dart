import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/services/b02_strength_execution_draft_service.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/widgets/b02_compact_set_table.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = B02StrengthExecutionDraftService();

  test('edit and delete use stable set IDs rather than display positions', () {
    final first = service.recordSet(
      state: _draft(),
      slot: _slot(plannedSets: 3),
      reps: 8,
      loadKg: 80,
      rpe: 8,
    );
    final second = service.recordSet(
      state: first,
      slot: _slot(plannedSets: 3),
      reps: 9,
      loadKg: 82.5,
      rpe: 9,
    );
    final third = service.recordSet(
      state: second,
      slot: _slot(plannedSets: 3),
      reps: 7,
      loadKg: 85,
      rpe: 9,
    );
    final ids = third.performedExercises.single.sets.map((set) => set.id);

    final withoutSecond = service.deleteSet(
      state: third,
      slot: _slot(plannedSets: 3),
      setId: ids.elementAt(1),
    );
    expect(withoutSecond.performedExercises.single.sets.map((set) => set.id), [
      ids.first,
      ids.last,
    ]);
    expect(
      withoutSecond.performedExercises.single.sets.map((set) => set.ordinal),
      [0, 1],
    );

    final edited = service.editSet(
      state: withoutSecond,
      slot: _slot(plannedSets: 3),
      setId: ids.last,
      reps: 11,
      loadKg: 87.5,
      actualLoadBasis: B02LoadBasis.totalExternal,
      rpe: 10,
    );
    final remaining = edited.performedExercises.single.sets;
    expect(remaining.first.actualReps, 8);
    expect(remaining.last.id, ids.last);
    expect(remaining.last.actualReps, 11);
    expect(remaining.last.actualLoadKg, 87.5);
    expect(remaining.last.actualRpe, 10);

    final reAdded = service.recordSet(
      state: withoutSecond,
      slot: _slot(plannedSets: 3),
      reps: 6,
      loadKg: 90,
    );
    expect(
      reAdded.performedExercises.single.sets.map((set) => set.id).toSet(),
      hasLength(3),
    );
  });

  test('warm-up and RPE remain canonical row facts', () {
    final state = service.recordSet(
      state: _draft(),
      slot: _slot(plannedSets: 2),
      reps: 10,
      loadKg: 40,
      rpe: 6,
      role: B02SetRole.warmup,
    );
    final set = state.performedExercises.single.sets.single;
    final row = B02CompactSetRow.fromLoggedSet(
      set: set,
      displayNumber: 1,
      isExtra: false,
    );

    expect(row.role, B02SetRole.warmup);
    expect(row.actualLabel, contains('RPE 6'));
    expect(row.plannedLabel, contains('8–10'));
  });

  testWidgets('Planned rows show targets and expose labelled edit/delete', (
    tester,
  ) async {
    final set = service
        .recordSet(
          state: _draft(),
          slot: _slot(plannedSets: 2),
          reps: 8,
          loadKg: 80,
          rpe: 8,
        )
        .performedExercises
        .single
        .sets
        .single;
    final edited = <B02PerformedSet>[];
    final deleted = <B02PerformedSet>[];
    final loadController = TextEditingController(text: '80');
    final repsController = TextEditingController(text: '8');
    addTearDown(loadController.dispose);
    addTearDown(repsController.dispose);

    await _pumpTable(
      tester,
      slot: _slot(plannedSets: 2),
      loggedSets: [set],
      isPlannedMode: true,
      loadController: loadController,
      repsController: repsController,
      onEdit: edited.add,
      onDelete: deleted.add,
    );

    expect(find.text('PLANNED'), findsOneWidget);
    expect(find.text('ACTUAL'), findsOneWidget);
    expect(find.text('Enter actuals'), findsOneWidget);
    expect(find.text('Planned input'), findsNothing);
    expect(find.text('80 kg × 8–10 reps × RPE 8'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Edit set 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete set 1'), findsOneWidget);
    expect(tester.getRect(find.bySemanticsLabel('Edit set 1')).width, 48);
    expect(tester.getRect(find.bySemanticsLabel('Delete set 1')).height, 48);

    await tester.tap(find.bySemanticsLabel('Edit set 1'));
    await tester.tap(find.bySemanticsLabel('Delete set 1'));
    expect(edited.single.id, set.id);
    expect(deleted.single.id, set.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Quick without a target omits fake target columns and keeps one input',
    (tester) async {
      final loadController = TextEditingController();
      final repsController = TextEditingController(text: '8');
      addTearDown(loadController.dispose);
      addTearDown(repsController.dispose);

      await _pumpTable(
        tester,
        size: const Size(390, 844),
        slot: _slot(id: 'quick-slot', plannedSets: 1, hasTarget: false),
        isPlannedMode: false,
        loadController: loadController,
        repsController: repsController,
        onAddSet: () {},
      );

      expect(find.text('PLANNED'), findsNothing);
      expect(find.text('Next set · 1'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Add set'), findsOneWidget);
      expect(find.text('RPE'), findsNothing);
      await tester.tap(find.text('More for this set'));
      await tester.pumpAndSettle();
      expect(find.text('RPE'), findsOneWidget);
      expect(
        find.text('RPE is optional. RPE 8 ≈ about 2 good reps left.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('parent-owned controllers retain typed values through rebuilds', (
    tester,
  ) async {
    final loadController = TextEditingController(text: '80');
    final repsController = TextEditingController(text: '8');
    addTearDown(loadController.dispose);
    addTearDown(repsController.dispose);

    await _pumpTable(
      tester,
      slot: _slot(plannedSets: 2),
      isPlannedMode: true,
      loadController: loadController,
      repsController: repsController,
    );
    await tester.enterText(
      find.byKey(const ValueKey('compact-load-slot')),
      '77',
    );
    await tester.enterText(
      find.byKey(const ValueKey('compact-reps-slot')),
      '9',
    );
    await tester.pump();

    await _pumpTable(
      tester,
      slot: _slot(plannedSets: 2),
      isPlannedMode: true,
      loadController: loadController,
      repsController: repsController,
    );

    expect(loadController.text, '77');
    expect(repsController.text, '9');
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('compact-load-slot')),
          )
          .controller,
      same(loadController),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'table stays usable at compact widths, large text, and both themes',
    (tester) async {
      addTearDown(tester.view.reset);
      final loadController = TextEditingController();
      final repsController = TextEditingController(text: '8');
      addTearDown(loadController.dispose);
      addTearDown(repsController.dispose);

      for (final size in const [
        Size(320, 568),
        Size(360, 700),
        Size(430, 844),
      ]) {
        for (final scale in const [1.0, 2.0]) {
          for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData.fromView(
                    tester.view,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: B02CompactSetTable(
                        slot: _slot(plannedSets: 2),
                        loggedSets: const [],
                        isPlannedMode: true,
                        isBusy: false,
                        currentSet: 1,
                        loadController: loadController,
                        repsController: repsController,
                        rpe: null,
                        isWarmup: false,
                        loadLabel: 'Weight (kg)',
                        onRpeChanged: (_) {},
                        onWarmupChanged: (_) {},
                        onEdit: (_) {},
                        onDelete: (_) {},
                        moreContent: null,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Table overflowed at ${size.width}pt, ${scale}x.',
            );
          }
        }
      }
    },
  );

  test('controller persists edit/delete and presents a safe failure', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('r08b2-bench'),
            name: 'Bench press',
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );
    final repository = StrengthExecutionRepository(
      db: db,
      calendarRepo: CalendarRepository(db),
      nowUtc: () => DateTime.utc(2026, 8, 22, 8),
    );
    final controller = B02StrengthExecutionController(
      StrengthExecutionCompatibilityAdapter(repository),
    );
    addTearDown(controller.dispose);

    await controller.startUnscheduled(
      routineName: 'Quick edit test',
      executionSnapshotJson: jsonEncode({
        'version': 1,
        'routineName': 'Quick edit test',
      }),
    );
    await controller.addUnscheduledExercise(
      exerciseId: 'r08b2-bench',
      exerciseName: 'Bench press',
    );
    final slot = controller.state.slots.single;
    await controller.recordSet(slot: slot, reps: 8, loadKg: 80, rpe: 8);
    await controller.recordSet(slot: slot, reps: 9, loadKg: 82.5, rpe: 9);
    final logged =
        controller.state.launch!.state.performedExercises.single.sets;
    final firstId = logged.first.id;
    final secondId = logged.last.id;

    expect(
      await controller.editSet(
        slot: slot,
        setId: secondId,
        reps: 10,
        loadKg: 85,
        actualLoadBasis: B02LoadBasis.totalExternal,
        rpe: 8,
      ),
      isTrue,
    );
    expect(
      controller
          .state
          .launch!
          .state
          .performedExercises
          .single
          .sets
          .last
          .actualReps,
      10,
    );
    expect(await controller.deleteSet(slot: slot, setId: firstId), isTrue);
    final remaining =
        controller.state.launch!.state.performedExercises.single.sets;
    expect(remaining.single.id, secondId);
    expect(remaining.single.ordinal, 0);

    expect(await controller.deleteSet(slot: slot, setId: firstId), isFalse);
    expect(controller.state.errorMessage, contains('could not be saved'));
    expect(controller.state.errorMessage, isNot(contains('B02')));
    expect(controller.state.errorMessage, isNot(contains('UUID')));
  });
}

B02ExecutionDraftState _draft() => B02ExecutionDraftState(
  snapshotId: 'r08b2-test-draft',
  snapshotVersion: 1,
  activityType: B02ActivityType.strength,
  routineName: 'Set table test',
  elapsedSeconds: 0,
  currentExerciseOrdinal: 0,
  currentSetOrdinal: 0,
);

B02StrengthExecutionSlot _slot({
  String id = 'slot',
  int plannedSets = 2,
  bool hasTarget = true,
}) => B02StrengthExecutionSlot(
  id: id,
  groupId: null,
  groupType: null,
  groupLabel: null,
  groupOrdinal: null,
  roundOrdinal: null,
  memberOrdinal: null,
  prescriptionId: '$id-prescription',
  exerciseId: 'exercise-1',
  exerciseNameSnapshot: 'Bench press',
  plannedSets: plannedSets,
  targetRepsMin: hasTarget ? 8 : null,
  targetRepsMax: hasTarget ? 10 : null,
  targetRpe: hasTarget ? 8 : null,
  targetLoadKg: hasTarget ? 80 : null,
  targetLoadBasis: hasTarget ? B02LoadBasis.totalExternal : null,
);

Future<void> _pumpTable(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  required B02StrengthExecutionSlot slot,
  List<B02PerformedSet> loggedSets = const [],
  required bool isPlannedMode,
  required TextEditingController loadController,
  required TextEditingController repsController,
  ValueChanged<B02PerformedSet>? onEdit,
  ValueChanged<B02PerformedSet>? onDelete,
  VoidCallback? onAddSet,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData.fromView(tester.view),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: B02CompactSetTable(
              slot: slot,
              loggedSets: loggedSets,
              isPlannedMode: isPlannedMode,
              isBusy: false,
              currentSet: 1,
              loadController: loadController,
              repsController: repsController,
              rpe: 8,
              isWarmup: false,
              loadLabel: 'Weight (kg)',
              onRpeChanged: (_) {},
              onWarmupChanged: (_) {},
              onEdit: onEdit,
              onDelete: onDelete,
              moreContent: null,
              onAddSet: onAddSet,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
