import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/models/b02_execution_models.dart';

void main() {
  group('B02 execution model validation', () {
    test(
      'accepts every explicit group type and rejects invalid membership',
      () {
        B02ExerciseGroup makeGroup(B02GroupType type, int memberCount) {
          return B02ExerciseGroup(
            id: type.dbValue,
            ordinal: 0,
            groupType: type,
            roundCount: 2,
            members: [
              for (var index = 0; index < memberCount; index++)
                B02ExerciseGroupMember(
                  id: '$type-$index',
                  exercisePrescriptionId: 'prescription-$index',
                  ordinal: index,
                ),
            ],
          );
        }

        expect(makeGroup(B02GroupType.superset, 2).members, hasLength(2));
        expect(makeGroup(B02GroupType.circuit, 2).members, hasLength(2));
        expect(makeGroup(B02GroupType.giantSet, 3).members, hasLength(3));
        expect(
          () => makeGroup(B02GroupType.superset, 3),
          throwsA(isA<B02ValidationException>()),
        );
        expect(
          () => B02ExerciseGroup(
            id: 'duplicate',
            ordinal: 0,
            groupType: B02GroupType.superset,
            roundCount: 1,
            members: [
              B02ExerciseGroupMember(
                id: 'one',
                exercisePrescriptionId: 'same',
                ordinal: 0,
              ),
              B02ExerciseGroupMember(
                id: 'two',
                exercisePrescriptionId: 'same',
                ordinal: 1,
              ),
            ],
          ),
          throwsA(isA<B02ValidationException>()),
        );
      },
    );

    test(
      'supports composable tempo, paused, assisted, drop and rest-pause facts',
      () {
        final technique = B02TechniqueFields(
          isDropSet: true,
          isRestPause: true,
          tempoEccentricSeconds: 3,
          tempoBottomPauseSeconds: 1,
          tempoConcentricSeconds: 1,
          tempoLockoutPauseSeconds: 0,
          pausedRepPosition: B02PausedRepPosition.bottom,
          pausedRepSeconds: 1,
          assistanceMode: B02AssistanceMode.machine,
          assistanceKg: 15,
          segments: [
            B02SetSegment(ordinal: 0, reps: 8, externalLoadKg: 50),
            B02SetSegment(
              ordinal: 1,
              reps: 4,
              externalLoadKg: 40,
              restBeforeSeconds: 20,
            ),
          ],
        );

        expect(technique.toJson()['isDropSet'], isTrue);
        expect(technique.toJson()['isRestPause'], isTrue);
        expect(
          () => B02TechniqueFields(
            tempoEccentricSeconds: 3,
            tempoBottomPauseSeconds: 1,
          ),
          throwsA(isA<B02ValidationException>()),
        );
        expect(
          () => B02TechniqueFields(
            isRestPause: true,
            segments: [
              B02SetSegment(ordinal: 0, reps: 8, externalLoadKg: 50),
              B02SetSegment(ordinal: 1, reps: 4, externalLoadKg: 40),
            ],
          ),
          throwsA(isA<B02ValidationException>()),
        );
      },
    );

    test(
      'validates typed cardio and mobility details without cross-modality fields',
      () {
        final cardio = B02CardioSessionDetail(
          activityType: B02ActivityType.running,
          durationSeconds: 900,
          distanceMetres: 3000,
          isIntervalWorkout: true,
          inputMode: B02InputMode.manual,
          intervals: [
            B02CardioInterval(
              id: 'work-1',
              ordinal: 0,
              segmentType: B02CardioSegmentType.work,
              durationSeconds: 300,
            ),
          ],
        );
        expect(cardio.toJson()['activityType'], 'running');
        expect(
          () => B02CardioSessionDetail(
            activityType: B02ActivityType.yoga,
            durationSeconds: 900,
            inputMode: B02InputMode.manual,
          ),
          throwsA(isA<B02ValidationException>()),
        );
        expect(
          () => B02MobilitySessionDetail(
            practiceType: B02ActivityType.mobility,
            durationSeconds: 600,
            style: 'floor',
          ),
          returnsNormally,
        );
      },
    );

    test('requires reviewed muscle mappings to total 10000 basis points', () {
      final mapping = B02ExerciseMuscleMapping(
        id: 'mapping-1',
        exerciseId: 'exercise-1',
        mappingStatus: B02MappingStatus.reviewed,
        source: 'reviewed-b02-v1',
        catalogVersion: 1,
        contributions: [
          B02MuscleContribution(
            muscleId: 'quadriceps',
            role: B02MuscleRole.primary,
            contributionBasisPoints: 7000,
          ),
          B02MuscleContribution(
            muscleId: 'glute-maximus',
            role: B02MuscleRole.secondary,
            contributionBasisPoints: 3000,
          ),
        ],
      );
      expect(mapping.toJson()['contributions'], hasLength(2));
      expect(
        () => B02ExerciseMuscleMapping(
          id: 'unknown',
          exerciseId: 'exercise-unknown',
          mappingStatus: B02MappingStatus.unknown,
          catalogVersion: 1,
          contributions: [
            B02MuscleContribution(
              muscleId: 'quadriceps',
              role: B02MuscleRole.primary,
              contributionBasisPoints: 10000,
            ),
          ],
        ),
        throwsA(isA<B02ValidationException>()),
      );
    });
  });
}
