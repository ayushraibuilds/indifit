import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b02_execution_draft_codec.dart';
import 'package:indifit/core/fixtures/workout_draft_codec.dart';
import 'package:indifit/data/models/b02_execution_models.dart';

void main() {
  B02ExecutionDraftState makeState() {
    final technique = B02TechniqueFields(
      effortMode: B02EffortMode.amrap,
      endedAtFailure: true,
      tempoEccentricSeconds: 3,
      tempoBottomPauseSeconds: 1,
      tempoConcentricSeconds: 1,
      tempoLockoutPauseSeconds: 0,
      pausedRepPosition: B02PausedRepPosition.bottom,
      pausedRepSeconds: 1,
      assistanceMode: B02AssistanceMode.machine,
      assistanceKg: 10,
    );
    return B02ExecutionDraftState(
      snapshotId: 'snapshot-1',
      snapshotVersion: 1,
      activityType: B02ActivityType.strength,
      routineName: 'B02 Strength',
      elapsedSeconds: 125,
      currentGroupOrdinal: 0,
      currentGroupId: 'group-1',
      currentRoundOrdinal: 1,
      currentMemberOrdinal: 0,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
      groups: [
        B02ExerciseGroup(
          id: 'group-1',
          ordinal: 0,
          groupType: B02GroupType.superset,
          roundCount: 2,
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
      performedExercises: [
        B02PerformedExerciseDraft(
          id: 'performed-exercise-1',
          performedExerciseGroupId: 'group-1',
          sourceExercisePrescriptionId: 'prescription-1',
          groupMemberOrdinal: 0,
          groupRoundOrdinal: 1,
          ordinal: 0,
          expectedExerciseId: 'exercise-expected',
          expectedExerciseNameSnapshot: 'Expected Exercise',
          actualExerciseId: 'exercise-actual',
          actualExerciseNameSnapshot: 'Actual Exercise',
          status: 'completed',
          substitutionReason: 'equipment',
          sets: [
            B02PerformedSet(
              id: 'performed-set-1',
              performedExerciseId: 'performed-exercise-1',
              ordinal: 0,
              role: B02SetRole.working,
              targetLoadKg: 50,
              targetLoadBasis: B02LoadBasis.totalExternal,
              targetRepsMin: 8,
              targetRepsMax: 12,
              actualLoadKg: 47.5,
              actualLoadBasis: B02LoadBasis.totalExternal,
              actualReps: 10,
              actualRpe: 8,
              technique: technique,
              notes: 'override',
            ),
          ],
          targetRecommendation: B02TargetRecommendation(
            id: 'target-1',
            performedExerciseId: 'performed-exercise-1',
            ruleVersion: 'b02-target-v1',
            confidence: B02Confidence.medium,
            completeness: {'recoveryKnown': false},
            recommendedLoadKg: 50,
            loadBasis: B02LoadBasis.totalExternal,
            targetRepsMin: 8,
            targetRepsMax: 12,
            comparatorCount: 1,
            rationaleCodes: ['recovery-unknown'],
            wasOverridden: true,
          ),
        ),
      ],
    );
  }

  group('B02 execution draft codec v2', () {
    test(
      'round trips a canonical execution state with groups and techniques',
      () {
        final encoded = B02ExecutionDraftCodec.encode(makeState());
        final result = B02ExecutionDraftCodec.decode(encoded);

        expect(result.isCanonical, isTrue);
        expect(result.isLegacy, isFalse);
        expect(result.version, 2);
        expect(result.state!.snapshotId, 'snapshot-1');
        expect(result.state!.groups.single.groupType, B02GroupType.superset);
        expect(
          result.state!.performedExercises.single.sets.single.actualReps,
          10,
        );
        expect(
          result
              .state!
              .performedExercises
              .single
              .sets
              .single
              .technique
              .tempoEccentricSeconds,
          3,
        );
        expect(
          result
              .state!
              .performedExercises
              .single
              .targetRecommendation!
              .wasOverridden,
          isTrue,
        );
      },
    );

    test(
      'delegates legacy v0 and v1 decoding without changing the old codec',
      () {
        const legacyV0 =
            '[{"sessionId":0,"exerciseName":"Bench Press","weight":50.0,"reps":8,"setNumber":1,"isPr":false}]';
        final v0 = B02ExecutionDraftCodec.decode(legacyV0);
        expect(v0.isLegacy, isTrue);
        expect(v0.version, 0);
        expect(v0.legacyLoggedSets, hasLength(1));

        final v1Payload = WorkoutDraftCodec.encode(
          routineName: 'Legacy',
          currentExerciseIndex: 0,
          currentSetIndex: 0,
          elapsedSeconds: 1,
          loggedSets: const [],
        );
        final v1 = B02ExecutionDraftCodec.decode(v1Payload);
        expect(v1.isLegacy, isTrue);
        expect(v1.version, 1);
        expect(v1.legacyLoggedSets, isEmpty);
      },
    );

    test('rejects malformed and future B02 envelopes', () {
      final valid =
          jsonDecode(B02ExecutionDraftCodec.encode(makeState()))
              as Map<String, dynamic>;

      final future = {...valid, 'version': 3};
      expect(
        () => B02ExecutionDraftCodec.decode(jsonEncode(future)),
        throwsA(isA<B02UnsupportedDraftVersionException>()),
      );

      final invalidActivity = {...valid, 'activityType': 'run'};
      expect(
        () => B02ExecutionDraftCodec.decode(jsonEncode(invalidActivity)),
        throwsA(isA<B02ValidationException>()),
      );

      final invalidGroup = {
        ...valid,
        'groups': [
          {
            ...(valid['groups'] as List).single as Map<String, dynamic>,
            'groupType': 'not-a-group',
          },
        ],
      };
      expect(
        () => B02ExecutionDraftCodec.decode(jsonEncode(invalidGroup)),
        throwsA(isA<B02ValidationException>()),
      );
    });
  });
}
