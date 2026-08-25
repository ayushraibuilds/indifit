import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/services/b02_strength_execution_draft_service.dart';

void main() {
  const service = B02StrengthExecutionDraftService();

  B02ExecutionDraftState draft() => B02ExecutionDraftState(
    snapshotId: 'snapshot-1',
    snapshotVersion: 1,
    activityType: B02ActivityType.strength,
    routineName: 'Grouped press',
    elapsedSeconds: 0,
    currentExerciseOrdinal: 0,
    currentSetOrdinal: 0,
    groups: [
      B02ExerciseGroup(
        id: 'group-1',
        ordinal: 0,
        groupType: B02GroupType.superset,
        roundCount: 1,
        members: [
          B02ExerciseGroupMember(
            id: 'member-1',
            exercisePrescriptionId: 'prescription-1',
            ordinal: 0,
          ),
          B02ExerciseGroupMember(
            id: 'member-2',
            exercisePrescriptionId: 'prescription-2',
            ordinal: 1,
          ),
        ],
      ),
    ],
  );

  const slot = B02StrengthExecutionSlot(
    id: 'group-1:0:0',
    groupId: 'group-1',
    groupType: B02GroupType.superset,
    groupLabel: 'Push pair',
    groupOrdinal: 0,
    roundOrdinal: 0,
    memberOrdinal: 0,
    prescriptionId: 'prescription-1',
    exerciseId: 'exercise-1',
    exerciseNameSnapshot: 'Bench press',
    plannedSets: 2,
    targetRepsMin: 8,
    targetRepsMax: 10,
    targetRpe: 8,
    targetLoadKg: 80,
    targetLoadBasis: B02LoadBasis.totalExternal,
  );

  test('records canonical sets, target provenance and group position', () {
    final first = service.recordSet(
      state: draft(),
      slot: slot,
      reps: 8,
      loadKg: 80,
      rpe: 8,
    );
    expect(first.elapsedSeconds, 1);
    expect(first.currentGroupId, 'group-1');
    expect(first.performedExercises.single.status, 'partial');
    expect(first.performedExercises.single.sets.single.targetRepsMin, 8);

    final second = service.recordSet(
      state: first,
      slot: slot,
      reps: 9,
      loadKg: 82.5,
      rpe: 9,
    );
    expect(second.performedExercises.single.status, 'completed');
    expect(second.performedExercises.single.sets, hasLength(2));
    expect(second.performedExercises.single.actualExerciseId, 'exercise-1');
  });

  test('edit and delete restore the prescribed terminal state by set ID', () {
    final first = service.recordSet(
      state: draft(),
      slot: slot,
      reps: 8,
      loadKg: 80,
    );
    final complete = service.recordSet(
      state: first,
      slot: slot,
      reps: 9,
      loadKg: 82.5,
    );
    final sets = complete.performedExercises.single.sets;
    final firstId = sets[0].id;
    final secondId = sets[1].id;

    final edited = service.editSet(
      state: complete,
      slot: slot,
      setId: firstId,
      reps: 7,
      loadKg: 77.5,
      actualLoadBasis: B02LoadBasis.totalExternal,
      rpe: 7,
    );
    expect(edited.performedExercises.single.status, 'completed');
    expect(edited.performedExercises.single.sets.first.id, firstId);
    expect(edited.performedExercises.single.sets.first.actualReps, 7);
    expect(edited.performedExercises.single.sets.first.actualRpe, 7);

    final partial = service.deleteSet(
      state: edited,
      slot: slot,
      setId: firstId,
    );
    expect(partial.performedExercises.single.status, 'partial');
    expect(partial.performedExercises.single.sets.single.id, secondId);
    expect(partial.performedExercises.single.sets.single.ordinal, 0);

    final restored = service.recordSet(
      state: partial,
      slot: slot,
      reps: 10,
      loadKg: 85,
    );
    expect(restored.performedExercises.single.status, 'completed');
    expect(restored.performedExercises.single.sets, hasLength(2));
    expect(restored.performedExercises.single.sets.last.id, isNot(firstId));
    expect(restored.performedExercises.single.sets.last.id, isNot(secondId));
  });

  test('refuses to invent a stable identity for an unresolved slot', () {
    final unresolved = B02StrengthExecutionSlot(
      id: 'group-1:0:1',
      groupId: 'group-1',
      groupType: B02GroupType.superset,
      groupLabel: 'Push pair',
      groupOrdinal: 0,
      roundOrdinal: 0,
      memberOrdinal: 1,
      prescriptionId: 'prescription-2',
      exerciseId: null,
      exerciseNameSnapshot: 'Unknown exercise',
      plannedSets: 1,
      targetRepsMin: null,
      targetRepsMax: null,
      targetRpe: null,
      targetLoadKg: null,
      targetLoadBasis: null,
    );
    expect(
      () => service.recordSet(state: draft(), slot: unresolved, reps: 8),
      throwsA(isA<B02ValidationException>()),
    );
  });

  test('keeps skipped slots visible for explicit partial completion', () {
    final skipped = service.skipSlot(
      state: draft(),
      slot: slot,
      reason: 'No time',
    );
    expect(skipped.performedExercises.single.status, 'skipped');
    expect(skipped.performedExercises.single.substitutionReason, 'No time');
  });

  test('preserves a substituted actual exercise across resumed sets', () {
    final substituted = service.recordSet(
      state: draft(),
      slot: slot,
      reps: 8,
      actualExerciseId: 'exercise-2',
      actualExerciseNameSnapshot: 'Dumbbell press',
      substitutionReason: 'Equipment unavailable',
    );
    final resumed = service.recordSet(state: substituted, slot: slot, reps: 7);

    expect(resumed.performedExercises.single.actualExerciseId, 'exercise-2');
    expect(
      resumed.performedExercises.single.actualExerciseNameSnapshot,
      'Dumbbell press',
    );
    expect(resumed.performedExercises.single.sets, hasLength(2));
  });

  test('loaded Quick sets default to a canonical total-external basis', () {
    final quickSlot = B02StrengthExecutionSlot(
      id: 'quick-slot',
      groupId: null,
      groupType: null,
      groupLabel: null,
      groupOrdinal: null,
      roundOrdinal: null,
      memberOrdinal: null,
      prescriptionId: 'quick-prescription',
      exerciseId: 'exercise-1',
      exerciseNameSnapshot: 'Bench press',
      plannedSets: 1,
      targetRepsMin: null,
      targetRepsMax: null,
      targetRpe: null,
      targetLoadKg: null,
      targetLoadBasis: null,
    );
    final logged = service.recordSet(
      state: draft(),
      slot: quickSlot,
      reps: 8,
      loadKg: 60,
      useSlotPrescription: false,
    );
    expect(
      logged.performedExercises.single.sets.single.actualLoadBasis,
      B02LoadBasis.totalExternal,
    );
  });
}
