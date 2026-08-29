import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/services/b02_execution_progression.dart';
import 'package:indifit/data/services/b02_strength_execution_draft_service.dart';
import 'package:indifit/features/exercise_picker/exercise_picker_models.dart';
import 'package:indifit/features/program_authoring/b02_technique_editor.dart';
import 'package:indifit/features/workout_player/b02_previous_performance_integration.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/widgets/b02_compact_set_table.dart';
import 'package:indifit/features/workout_player/widgets/b02_execution_advanced_controls.dart';
import 'package:indifit/features/workout_player/widgets/b02_execution_semantics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = B02StrengthExecutionDraftService();

  test('ordinary rows remain compact and do not invent advanced details', () {
    final row = B02CompactSetRow.fromPlannedSlot(
      slot: _slot(setPrescriptions: [_setPrescription(ordinal: 0)]),
      displayNumber: 1,
      isExtra: false,
      prescriptionOrdinal: 0,
    );

    expect(row.plannedLabel, '80 kg × 8–10 reps × RPE 8');
    expect(row.plannedDetailsLabel, isNull);
    expect(row.actualLabel, isNull);
  });

  test('planned rows use the exact ordinal-addressed technique', () {
    final row = B02CompactSetRow.fromPlannedSlot(
      slot: _slot(
        setPrescriptions: [
          _setPrescription(ordinal: 0),
          _setPrescription(
            ordinal: 1,
            technique: B02TechniqueFields(effortMode: B02EffortMode.amrap),
          ),
        ],
      ),
      displayNumber: 2,
      isExtra: false,
      prescriptionOrdinal: 1,
    );

    expect(row.plannedDetailsLabel, 'As many good reps as possible');
    expect(_slot().copyWith().setPrescriptions, isEmpty);
  });

  test('RPE stays a factual optional value without inference', () {
    final logged = service.recordSet(
      state: _draft(),
      slot: _slot(),
      reps: 8,
      loadKg: 80,
      rpe: null,
    );
    final set = logged.performedExercises.single.sets.single;
    final row = B02CompactSetRow.fromLoggedSet(
      set: set,
      displayNumber: 1,
      isExtra: false,
    );

    expect(set.targetRpe, 8);
    expect(set.actualRpe, isNull);
    expect(row.actualLabel, '80 kg × 8');
  });

  test(
    'advanced technique and RPE edit persist on the stable set identity',
    () {
      final originalTechnique = _advancedTechnique();
      final first = service.recordSet(
        state: _draft(),
        slot: _slot(),
        reps: 12,
        loadKg: 60,
        rpe: 9,
        technique: originalTechnique,
      );
      final originalSet = first.performedExercises.single.sets.single;
      final editedTechnique = B02TechniqueFields(
        effortMode: B02EffortMode.toFailure,
        endedAtFailure: true,
        tempoEccentricSeconds: 2,
        tempoBottomPauseSeconds: 0,
        tempoConcentricSeconds: 1,
        tempoLockoutPauseSeconds: 0,
      );
      final edited = service.editSet(
        state: first,
        slot: _slot(),
        setId: originalSet.id,
        reps: 12,
        loadKg: 57.5,
        actualLoadBasis: B02LoadBasis.totalExternal,
        rpe: 10,
        technique: editedTechnique,
      );
      final result = edited.performedExercises.single.sets.single;

      expect(result.id, originalSet.id);
      expect(result.actualRpe, 10);
      expect(result.technique.toJson(), editedTechnique.toJson());
      expect(result.technique.segments, isEmpty);
    },
  );

  test('warm-up remains a distinct set role in the compact row', () {
    final state = service.recordSet(
      state: _draft(),
      slot: _slot(),
      reps: 10,
      loadKg: 40,
      rpe: 5,
      role: B02SetRole.warmup,
    );
    final row = B02CompactSetRow.fromLoggedSet(
      set: state.performedExercises.single.sets.single,
      displayNumber: 1,
      isExtra: false,
    );

    expect(row.role, B02SetRole.warmup);
    expect(row.actualLabel, contains('RPE 5'));
    expect(b02ExecutionSetRoleLabel(row.role), 'Warm-up set');
  });

  test(
    'group ordering and progression use persisted member and round ordinals',
    () {
      final group = _group(roundCount: 2);
      final slots = [
        _groupSlot(memberOrdinal: 1, roundOrdinal: 1, prescriptionId: 'p-2'),
        _groupSlot(memberOrdinal: 0, roundOrdinal: 1, prescriptionId: 'p-1'),
        _groupSlot(memberOrdinal: 1, roundOrdinal: 0, prescriptionId: 'p-2'),
        _groupSlot(memberOrdinal: 0, roundOrdinal: 0, prescriptionId: 'p-1'),
      ];

      expect(
        b02GroupRoundSlots(
          slots: slots,
          groupId: group.id,
          roundOrdinal: 1,
        ).map((slot) => slot.memberOrdinal),
        [0, 1],
      );
      expect(
        B02GroupExecutionIntegrity.check(group: group, slots: slots).isValid,
        isTrue,
      );
    },
  );

  test(
    'contradictory grouped state fails closed without exposing identifiers',
    () {
      final group = _group(roundCount: 1);
      final broken = [
        _groupSlot(memberOrdinal: 0, roundOrdinal: 0, prescriptionId: 'p-1'),
      ];
      final result = B02GroupExecutionIntegrity.check(
        group: group,
        slots: broken,
      );

      expect(result.isValid, isFalse);
      expect(
        result.consumerMessage,
        'Some exercise details are unavailable right now.',
      );
      expect(result.consumerMessage, isNot(contains('group-1')));
      expect(result.consumerMessage, isNot(contains('UUID')));
    },
  );

  test(
    'planned grouped cursor advances member, then round, from canonical state',
    () {
      final group = _group(roundCount: 2);
      final slots = [
        _groupSlot(memberOrdinal: 0, roundOrdinal: 0, prescriptionId: 'p-1'),
        _groupSlot(memberOrdinal: 1, roundOrdinal: 0, prescriptionId: 'p-2'),
        _groupSlot(memberOrdinal: 0, roundOrdinal: 1, prescriptionId: 'p-1'),
        _groupSlot(memberOrdinal: 1, roundOrdinal: 1, prescriptionId: 'p-2'),
      ];
      final first = service.recordSet(
        state: _draft(groups: [group]),
        slot: slots[0],
        reps: 8,
      );
      final afterFirst = B02ExecutionProgression.advanceAfterCompletedSlot(
        state: first,
        slots: slots,
        current: slots[0],
      );
      expect(
        B02ExecutionProgression.cursorSlot(state: afterFirst, slots: slots)?.id,
        slots[1].id,
      );

      final second = service.recordSet(
        state: afterFirst,
        slot: slots[1],
        reps: 8,
      );
      final afterRound = B02ExecutionProgression.advanceAfterCompletedSlot(
        state: second,
        slots: slots,
        current: slots[1],
      );
      expect(
        B02ExecutionProgression.cursorSlot(state: afterRound, slots: slots)?.id,
        slots[2].id,
      );
    },
  );

  test('contradictory persisted current group position fails closed', () {
    final state = _draft(groups: [_group(roundCount: 1)]).copyWith(
      currentGroupOrdinal: 0,
      currentGroupId: 'missing-group',
      currentRoundOrdinal: 0,
      currentMemberOrdinal: 0,
    );
    final result = B02GroupExecutionIntegrity.checkCurrentPosition(
      state: state,
      slots: const [],
    );

    expect(result.isValid, isFalse);
    expect(
      result.consumerMessage,
      'Some exercise details are unavailable right now.',
    );
    expect(result.consumerMessage, isNot(contains('missing-group')));
  });

  test('planned grouped replacement preserves group and member identity', () {
    final group = _group(roundCount: 1);
    final slot = _groupSlot(
      memberOrdinal: 0,
      roundOrdinal: 0,
      prescriptionId: 'p-1',
    );
    final state = service.recordSet(
      state: _draft(groups: [group]),
      slot: slot,
      reps: 8,
      actualExerciseId: 'replacement-exercise',
      actualExerciseNameSnapshot: 'Replacement press',
      substitutionReason: 'Equipment unavailable',
    );
    final performed = state.performedExercises.single;

    expect(performed.actualExerciseId, 'replacement-exercise');
    expect(performed.performedExerciseGroupId, group.id);
    expect(performed.groupMemberOrdinal, 0);
    expect(performed.groupRoundOrdinal, 0);
    expect(performed.sourceExercisePrescriptionId, 'p-1');
  });

  test('grouped set edit targets the exact stable set identity', () {
    final group = _group(roundCount: 1);
    final slots = [
      _groupSlot(memberOrdinal: 0, roundOrdinal: 0, prescriptionId: 'p-1'),
      _groupSlot(memberOrdinal: 1, roundOrdinal: 0, prescriptionId: 'p-2'),
    ];
    final first = service.recordSet(
      state: _draft(groups: [group]),
      slot: slots[0],
      reps: 8,
      loadKg: 60,
    );
    final both = service.recordSet(
      state: first,
      slot: slots[1],
      reps: 9,
      loadKg: 40,
    );
    final firstSet = both.performedExercises
        .firstWhere((exercise) => exercise.id == 'performed:${slots[0].id}')
        .sets
        .single;
    final edited = service.editSet(
      state: both,
      slot: slots[0],
      setId: firstSet.id,
      reps: 7,
      loadKg: 62.5,
      actualLoadBasis: B02LoadBasis.totalExternal,
    );

    final editedFirst = edited.performedExercises.firstWhere(
      (exercise) => exercise.id == 'performed:${slots[0].id}',
    );
    final untouchedSecond = edited.performedExercises.firstWhere(
      (exercise) => exercise.id == 'performed:${slots[1].id}',
    );
    expect(editedFirst.sets.single.id, firstSet.id);
    expect(editedFirst.sets.single.actualReps, 7);
    expect(editedFirst.groupMemberOrdinal, 0);
    expect(editedFirst.groupRoundOrdinal, 0);
    expect(untouchedSecond.sets.single.actualReps, 9);
    expect(untouchedSecond.groupMemberOrdinal, 1);
  });

  test('grouped set deletion does not alter another member or round order', () {
    final group = _group(roundCount: 1);
    final slots = [
      _groupSlot(memberOrdinal: 0, roundOrdinal: 0, prescriptionId: 'p-1'),
      _groupSlot(memberOrdinal: 1, roundOrdinal: 0, prescriptionId: 'p-2'),
    ];
    final first = service.recordSet(
      state: _draft(groups: [group]),
      slot: slots[0],
      reps: 8,
    );
    final both = service.recordSet(state: first, slot: slots[1], reps: 9);
    final firstSet = both.performedExercises
        .firstWhere((exercise) => exercise.id == 'performed:${slots[0].id}')
        .sets
        .single;
    final deleted = service.deleteSet(
      state: both,
      slot: slots[0],
      setId: firstSet.id,
    );

    final emptyFirst = deleted.performedExercises.firstWhere(
      (exercise) => exercise.id == 'performed:${slots[0].id}',
    );
    final untouchedSecond = deleted.performedExercises.firstWhere(
      (exercise) => exercise.id == 'performed:${slots[1].id}',
    );
    expect(emptyFirst.sets, isEmpty);
    expect(emptyFirst.groupMemberOrdinal, 0);
    expect(emptyFirst.groupRoundOrdinal, 0);
    expect(untouchedSecond.sets.single.actualReps, 9);
    expect(untouchedSecond.groupMemberOrdinal, 1);
    expect(untouchedSecond.groupRoundOrdinal, 0);
  });

  test(
    'canonical replacement commit preserves grouped Planned identity',
    () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      await _insertExercise(database, 'exercise-0', 'Bench press');
      await _insertExercise(
        database,
        'replacement-exercise',
        'Replacement press',
      );
      final executions = StrengthExecutionRepository(
        db: database,
        calendarRepo: CalendarRepository(database),
      );
      final group = _group(roundCount: 1);
      final snapshot = jsonEncode({
        'version': 1,
        'routineName': 'Grouped Planned',
        'prescriptions': [
          {
            'id': 'p-1',
            'exerciseId': 'exercise-0',
            'exerciseNameSnapshot': 'Bench press',
            'plannedSets': 1,
            'repsRange': '8-10',
          },
          {
            'id': 'p-2',
            'exerciseId': 'exercise-0',
            'exerciseNameSnapshot': 'Bench press',
            'plannedSets': 1,
            'repsRange': '8-10',
          },
        ],
        'groups': [group.toJson()],
      });
      final quickLaunch = await executions.startUnscheduledDraft(
        routineName: 'Grouped Planned',
        snapshotId: 'grouped-planned-replacement',
        executionSnapshotJson: snapshot,
        groups: [group],
      );
      final plannedLaunch = B02StrengthExecutionLaunch(
        draftId: quickLaunch.draftId,
        occurrenceId: 'occurrence-42',
        executionSnapshotJson: quickLaunch.executionSnapshotJson,
        state: quickLaunch.state,
      );
      final controller = B02StrengthExecutionController(
        StrengthExecutionCompatibilityAdapter(executions),
        initialLaunch: plannedLaunch,
      );
      addTearDown(controller.dispose);

      await controller.loadSlots();
      final slot = controller.state.slots.first;
      final target = PlannedExerciseReplacementTarget(
        draftId: plannedLaunch.draftId,
        scheduledOccurrenceId: 'occurrence-42',
        slotId: slot.id,
        expectedExerciseId: slot.exerciseId!,
        currentPerformedExerciseId: slot.exerciseId!,
        currentExerciseNameSnapshot: slot.exerciseNameSnapshot,
      );
      final compatibility = await controller.readCompatibility(target: target);
      expect(
        compatibility.forExerciseId('replacement-exercise').state,
        CanonicalReplacementCandidateState.allowed,
      );

      await controller.commit(
        target: target,
        selection: const ExercisePickerSelection(
          exerciseId: 'replacement-exercise',
          exerciseNameSnapshot: 'Replacement press',
        ),
      );

      final performed =
          controller.state.launch!.state.performedExercises.single;
      expect(controller.state.launch!.occurrenceId, 'occurrence-42');
      expect(performed.actualExerciseId, 'replacement-exercise');
      expect(performed.performedExerciseGroupId, 'group-1');
      expect(performed.groupMemberOrdinal, 0);
      expect(performed.groupRoundOrdinal, 0);
      expect(await database.select(database.workoutDrafts).get(), hasLength(1));
    },
  );

  test(
    'malformed frozen set details fail closed before group slot creation',
    () async {
      final database = AppDatabase.memory();
      addTearDown(database.close);
      final group = _group(roundCount: 1);
      final repository = StrengthExecutionRepository(
        db: database,
        calendarRepo: CalendarRepository(database),
      );
      final launch = B02StrengthExecutionLaunch(
        draftId: 1,
        occurrenceId: null,
        executionSnapshotJson: jsonEncode({
          'version': 1,
          'prescriptions': [
            {
              'id': 'p-1',
              'exerciseId': 'exercise-0',
              'exerciseNameSnapshot': 'Bench press',
              'plannedSets': 1,
              'repsRange': '8-10',
              'strengthSetPrescriptions': 'not-a-list',
            },
            {
              'id': 'p-2',
              'exerciseId': 'exercise-1',
              'exerciseNameSnapshot': 'Row',
              'plannedSets': 1,
              'repsRange': '8-10',
              'strengthSetPrescriptions': [],
            },
          ],
          'groups': [group.toJson()],
        }),
        state: _draft(groups: [group]),
      );

      await expectLater(
        repository.readExecutionSlots(launch),
        throwsA(isA<B02StrengthExecutionRecoveryException>()),
      );
    },
  );

  test(
    'Quick recording stays ungrouped and reuses one active performed exercise',
    () {
      final quickSlot = _slot(
        id: 'quick-slot',
        groupId: null,
        groupType: null,
        groupLabel: null,
        groupOrdinal: null,
        roundOrdinal: null,
        memberOrdinal: null,
      );
      final first = service.recordSet(
        state: _draft(),
        slot: quickSlot,
        reps: 8,
        useSlotPrescription: false,
      );
      final second = service.recordSet(
        state: first,
        slot: quickSlot,
        reps: 9,
        useSlotPrescription: false,
      );

      expect(second.performedExercises, hasLength(1));
      expect(second.performedExercises.single.performedExerciseGroupId, isNull);
      expect(second.performedExercises.single.sets, hasLength(2));
    },
  );

  test(
    'exact exercise identity remains part of previous-performance context',
    () {
      const bench = B02PreviousPerformanceRequestKey(
        slotId: 'slot',
        actualExerciseId: 'exercise-bench',
        role: B02SetRole.working,
        loadBasis: B02LoadBasis.totalExternal,
        effortMode: B02EffortMode.standard,
        endedAtFailure: false,
      );
      const row = B02PreviousPerformanceRequestKey(
        slotId: 'slot',
        actualExerciseId: 'exercise-row',
        role: B02SetRole.working,
        loadBasis: B02LoadBasis.totalExternal,
        effortMode: B02EffortMode.standard,
        endedAtFailure: false,
      );
      final tempo = const B02PreviousPerformanceRequestKey(
        slotId: 'slot',
        actualExerciseId: 'exercise-bench',
        role: B02SetRole.working,
        loadBasis: B02LoadBasis.totalExternal,
        effortMode: B02EffortMode.standard,
        endedAtFailure: false,
        tempoEccentricSeconds: 3,
        tempoBottomPauseSeconds: 1,
        tempoConcentricSeconds: 1,
        tempoLockoutPauseSeconds: 0,
      );

      expect(bench, isNot(equals(row)));
      expect(bench, isNot(equals(tempo)));
    },
  );

  testWidgets('advanced controls disclose uncommon fields and explain RPE', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: B02ExecutionAdvancedControls(
              initialValue: B02TechniqueFields(),
              headerReps: null,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.text(
        'RPE describes how hard the set felt: 1 is very easy and 10 is maximum effort.',
      ),
      findsOneWidget,
    );
    expect(find.text('Eccentric (s)'), findsNothing);
    await tester.tap(find.text('Advanced technique'));
    await tester.pumpAndSettle();
    expect(find.text('Tempo'), findsOneWidget);
    expect(find.text('Eccentric (s)'), findsNothing);
    await tester.tap(find.text('Tempo'));
    await tester.pumpAndSettle();
    expect(find.text('Eccentric (s)'), findsOneWidget);
    expect(find.bySemanticsLabel('Tempo eccentric seconds'), findsOneWidget);
  });

  testWidgets('advanced presentation remains usable with text scaling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: B02ExecutionAdvancedControls(
                initialValue: _advancedTechnique(),
                headerReps: null,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RPE explanation'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'RPE explanation: RPE describes how hard the set felt: 1 is very easy and 10 is maximum effort.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('advanced segment disclosure appends a valid third segment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: B02TechniqueEditor(
              initialValue: _advancedTechnique(),
              headerReps: null,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add segment'), findsOneWidget);
    await tester.ensureVisible(find.text('Add segment'));
    await tester.tap(find.text('Add segment'));
    await tester.pumpAndSettle();

    expect(find.text('Segment 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'consumer labels do not expose internal enum or storage terminology',
    () {
      final labels = [
        b02ExecutionEffortLabel(B02EffortMode.amrap),
        b02ExecutionGroupTypeLabel(B02GroupType.giantSet),
        b02ExecutionPausedRepPositionLabel(B02PausedRepPosition.bottom),
        b02ExecutionAssistanceLabel(B02AssistanceMode.counterweight),
      ];

      for (final label in labels) {
        expect(label, isNot(contains('amrap')));
        expect(label, isNot(contains('giantSet')));
        expect(label, isNot(contains('groupId')));
        expect(label, isNot(contains('failureReason')));
        expect(label, isNot(contains('UUID')));
      }
    },
  );

  test('unresolved exercise identity fails safely before logging', () {
    final unresolved = _slot(exerciseId: null);

    expect(
      () => service.recordSet(state: _draft(), slot: unresolved, reps: 8),
      throwsA(isA<B02ValidationException>()),
    );
  });
}

B02TechniqueFields _advancedTechnique() => B02TechniqueFields(
  effortMode: B02EffortMode.amrap,
  endedAtFailure: true,
  isDropSet: true,
  isRestPause: true,
  tempoEccentricSeconds: 3,
  tempoBottomPauseSeconds: 1,
  tempoConcentricSeconds: 1,
  tempoLockoutPauseSeconds: 0,
  pausedRepPosition: B02PausedRepPosition.bottom,
  pausedRepSeconds: 1,
  assistanceMode: B02AssistanceMode.machine,
  assistanceKg: 10,
  segments: [
    B02SetSegment(ordinal: 0, reps: 8, externalLoadKg: 60),
    B02SetSegment(
      ordinal: 1,
      reps: 4,
      externalLoadKg: 50,
      restBeforeSeconds: 20,
    ),
  ],
);

B02StrengthSetPrescription _setPrescription({
  required int ordinal,
  B02TechniqueFields? technique,
}) => B02StrengthSetPrescription(
  id: 'set-prescription-$ordinal',
  exercisePrescriptionId: 'p-1',
  ordinal: ordinal,
  targetLoadKg: 80,
  loadBasis: B02LoadBasis.totalExternal,
  targetRepsMin: 8,
  targetRepsMax: 10,
  targetRpe: 8,
  technique: technique,
);

B02StrengthExecutionSlot _slot({
  String id = 'slot',
  String? groupId,
  B02GroupType? groupType,
  String? groupLabel,
  int? groupOrdinal,
  int? roundOrdinal,
  int? memberOrdinal,
  String? exerciseId = 'exercise-1',
  List<B02StrengthSetPrescription> setPrescriptions = const [],
}) => B02StrengthExecutionSlot(
  id: id,
  groupId: groupId,
  groupType: groupType,
  groupLabel: groupLabel,
  groupOrdinal: groupOrdinal,
  roundOrdinal: roundOrdinal,
  memberOrdinal: memberOrdinal,
  prescriptionId: memberOrdinal == 1 ? 'p-2' : 'p-1',
  exerciseId: exerciseId,
  exerciseNameSnapshot: 'Bench press',
  plannedSets: 2,
  setPrescriptions: setPrescriptions,
  targetRepsMin: 8,
  targetRepsMax: 10,
  targetRpe: 8,
  targetLoadKg: 80,
  targetLoadBasis: B02LoadBasis.totalExternal,
);

B02StrengthExecutionSlot _groupSlot({
  required int memberOrdinal,
  required int roundOrdinal,
  required String prescriptionId,
}) => B02StrengthExecutionSlot(
  id: 'group-1:$roundOrdinal:$memberOrdinal',
  groupId: 'group-1',
  groupType: B02GroupType.superset,
  groupLabel: 'Push pair',
  groupOrdinal: 0,
  roundOrdinal: roundOrdinal,
  memberOrdinal: memberOrdinal,
  prescriptionId: prescriptionId,
  exerciseId: 'exercise-$memberOrdinal',
  exerciseNameSnapshot: memberOrdinal == 0 ? 'Bench press' : 'Row',
  plannedSets: 1,
  targetRepsMin: 8,
  targetRepsMax: 10,
  targetRpe: 8,
  targetLoadKg: 80,
  targetLoadBasis: B02LoadBasis.totalExternal,
);

B02ExerciseGroup _group({required int roundCount}) => B02ExerciseGroup(
  id: 'group-1',
  ordinal: 0,
  groupType: B02GroupType.superset,
  roundCount: roundCount,
  members: [
    B02ExerciseGroupMember(
      id: 'member-1',
      exercisePrescriptionId: 'p-1',
      ordinal: 0,
    ),
    B02ExerciseGroupMember(
      id: 'member-2',
      exercisePrescriptionId: 'p-2',
      ordinal: 1,
    ),
  ],
);

B02ExecutionDraftState _draft({List<B02ExerciseGroup>? groups}) =>
    B02ExecutionDraftState(
      snapshotId: 'r08b5-draft',
      snapshotVersion: 1,
      activityType: B02ActivityType.strength,
      routineName: 'B.5 execution test',
      elapsedSeconds: 0,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
      groups: groups ?? const [],
    );

Future<void> _insertExercise(
  AppDatabase database,
  String stableId,
  String name,
) async {
  await database
      .into(database.exercises)
      .insert(
        ExercisesCompanion.insert(
          stableId: Value(stableId),
          name: name,
          muscleGroups: 'Chest',
          equipment: 'Barbell',
          difficulty: 'Intermediate',
          formCues: '',
          commonMistakes: '',
        ),
      );
}
