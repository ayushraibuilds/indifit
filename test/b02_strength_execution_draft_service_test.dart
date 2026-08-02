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
}
