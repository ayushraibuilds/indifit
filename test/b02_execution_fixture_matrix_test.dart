import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b02_execution_fixture_matrix.dart';

void main() {
  group('B02-01 execution fixture matrix', () {
    test('current matrix is deterministic and internally valid', () {
      final matrix = B02ExecutionFixtureMatrix.current;

      matrix.validate();
      expect(matrix.version, kB02FixtureContractVersion);
      expect(
        matrix.groups.map((item) => item.id),
        orderedEquals([
          'circuit-three-members',
          'giant-set-repeated-actual-exercise',
          'superset-substitution',
        ]),
      );
      expect(
        matrix.targetComparators.map((item) => item.id),
        orderedEquals([
          'deload-rounds-resolved-load',
          'failed-before-minimum-decreases',
          'max-reps-low-rpe-increases-one-increment',
          'missing-recovery-keeps-comparator',
          'new-exercise-uses-explicit-prescription',
          'unresolved-identity-has-no-target',
        ]),
      );
    });

    test('uses only B01 canonical exercise IDs for B02 writes', () {
      final matrix = B02ExecutionFixtureMatrix.current;
      final canonicalIds = <String>{
        for (final mapping in matrix.muscleMappings)
          if (mapping.status == B02FixtureMappingStatus.reviewed)
            mapping.exerciseStableId,
        for (final target in matrix.targetComparators)
          if (target.identityStatus == B02FixtureIdentityStatus.resolved)
            target.exerciseStableId,
      };

      expect(canonicalIds, isNotEmpty);
      expect(canonicalIds.every((id) => id.contains('-')), isTrue);
      expect(
        matrix.muscleMappings
            .singleWhere(
              (item) => item.status == B02FixtureMappingStatus.unknown,
            )
            .contributions,
        isEmpty,
      );
    });

    test(
      'captures group ordering, substitution ancestry, and repeated actuals',
      () {
        final groups = B02ExecutionFixtureMatrix.current.groups;
        final superset = groups.singleWhere(
          (item) => item.type == B02FixtureGroupType.superset,
        );
        final giantSet = groups.singleWhere(
          (item) => item.type == B02FixtureGroupType.giantSet,
        );

        expect(superset.members, hasLength(2));
        expect(
          superset.members[1].expectedExerciseStableId,
          isNot(superset.members[1].actualExerciseStableId),
        );
        expect(
          giantSet.members.map((item) => item.memberSlotId).toSet(),
          hasLength(3),
        );
        expect(
          giantSet.members.map((item) => item.actualExerciseStableId).toSet(),
          hasLength(2),
        );
      },
    );

    test(
      'captures composable technique facts without treating warm-ups as work',
      () {
        final techniques = B02ExecutionFixtureMatrix.current.techniques;
        final combined = techniques.singleWhere(
          (item) => item.id == 'working-drop-rest-pause',
        );
        final warmup = techniques.singleWhere(
          (item) => item.role == B02FixtureSetRole.warmup,
        );

        expect(
          combined.tags,
          containsAll({
            B02FixtureTechniqueTag.dropSet,
            B02FixtureTechniqueTag.restPause,
          }),
        );
        expect(
          combined.segments.fold<int>(0, (total, item) => total + item.reps),
          combined.performedReps,
        );
        expect(warmup.tags, isEmpty);
        expect(warmup.isAmrap, isFalse);
        expect(warmup.reachedFailure, isFalse);
      },
    );

    test(
      'keeps unknown modality measurements and health deduplication explicit',
      () {
        final matrix = B02ExecutionFixtureMatrix.current;
        final yoga = matrix.activities.singleWhere(
          (item) => item.activityType == B02FixtureActivityType.yoga,
        );
        final walking = matrix.activities.singleWhere(
          (item) => item.id == 'provider-walking-distance-unknown',
        );

        expect(yoga.distanceKm, isNull);
        expect(yoga.paceSecondsPerKm, isNull);
        expect(
          walking.distanceKm,
          isNull,
          reason: 'Unknown distance is not zero.',
        );
        expect(
          matrix.healthImports
              .where(
                (item) => item.source == B02FixtureActivitySource.healthImport,
              )
              .every((item) => item.expectedDuplicateSuppression),
          isTrue,
        );
      },
    );

    test('freezes target safety fallbacks and unknown recovery behavior', () {
      final targets = B02ExecutionFixtureMatrix.current.targetComparators;
      final unresolved = targets.singleWhere(
        (item) => item.identityStatus == B02FixtureIdentityStatus.unresolved,
      );
      final recoveryUnknown = targets.singleWhere(
        (item) => item.id == 'missing-recovery-keeps-comparator',
      );
      final increase = targets.singleWhere(
        (item) => item.id == 'max-reps-low-rpe-increases-one-increment',
      );

      expect(
        unresolved.expectedOutcome,
        B02FixtureTargetOutcome.noRecommendation,
      );
      expect(unresolved.expectedLoadKg, isNull);
      expect(recoveryUnknown.expectedLoadKg, recoveryUnknown.comparableLoadKg);
      expect(recoveryUnknown.requiredRationaleCode, 'recovery-unknown');
      expect(
        increase.expectedLoadKg! - increase.comparableLoadKg!,
        increase.incrementKg,
      );
      expect(increase.userOverrideKg, isNot(increase.expectedLoadKg));
    });

    test(
      'requires complete v7 ownership and rejects orphan or future backups',
      () {
        final backups = B02ExecutionFixtureMatrix.current.backups;
        final complete = backups.singleWhere(
          (item) => item.id == 'backup-v07-complete-b02-graph',
        );
        final orphan = backups.singleWhere(
          (item) => item.id == 'backup-v07-orphan-rejected-before-mutation',
        );
        final future = backups.singleWhere((item) => item.version == 8);

        expect(
          complete.ownedEntities,
          containsAll(B02FixtureBackupEntity.values),
        );
        expect(
          complete.relationships.every((item) => item.parentExists),
          isTrue,
        );
        expect(
          orphan.expectedDisposition,
          B02FixtureBackupDisposition.rejectBeforeMutation,
        );
        expect(orphan.relationships.single.parentExists, isFalse);
        expect(
          future.expectedDisposition,
          B02FixtureBackupDisposition.rejectBeforeMutation,
        );
      },
    );

    test('rejects invalid group contracts before a consumer can use them', () {
      const invalid = B02ExecutionFixtureMatrix(
        version: kB02FixtureContractVersion,
        legacyCases: [],
        groups: [
          B02ExerciseGroupFixture(
            id: 'invalid-superset',
            type: B02FixtureGroupType.superset,
            roundCount: 1,
            groupRestSeconds: 0,
            memberRestSeconds: 0,
            resumeRoundIndex: 0,
            resumeMemberIndex: 0,
            members: [
              B02ExerciseGroupMemberFixture(
                memberSlotId: 'only-slot',
                expectedExerciseStableId:
                    '089ec703-a25e-5b12-a39a-78b17ee33742',
                actualExerciseStableId: '089ec703-a25e-5b12-a39a-78b17ee33742',
              ),
            ],
          ),
        ],
        techniques: [],
        activities: [],
        equipmentIncrements: [],
        muscleMappings: [],
        targetComparators: [],
        providerTypes: [],
        unsupportedProviderTypes: {},
        healthImports: [],
        backups: [],
      );

      expect(invalid.validate, throwsA(isA<StateError>()));
    });

    test(
      'rejects unknown mappings that invent allocation and malformed tempo',
      () {
        const invalidMapping = B02ExecutionFixtureMatrix(
          version: kB02FixtureContractVersion,
          legacyCases: [],
          groups: [],
          techniques: [],
          activities: [],
          equipmentIncrements: [],
          muscleMappings: [
            B02MuscleMappingFixture(
              id: 'unknown-with-weight',
              exerciseStableId: 'legacy-custom-unresolved-001',
              status: B02FixtureMappingStatus.unknown,
              mappingVersion: 1,
              reviewedSource: null,
              contributions: [
                B02MuscleContributionFixture(
                  muscleId: 'chest',
                  role: B02FixtureMuscleRole.primary,
                  contributionBasisPoints: 10000,
                ),
              ],
            ),
          ],
          targetComparators: [],
          providerTypes: [],
          unsupportedProviderTypes: {},
          healthImports: [],
          backups: [],
        );
        const invalidTempo = B02ExecutionFixtureMatrix(
          version: kB02FixtureContractVersion,
          legacyCases: [],
          groups: [],
          techniques: [
            B02TechniqueFixture(
              id: 'partial-tempo',
              role: B02FixtureSetRole.working,
              performedReps: 8,
              eccentricSeconds: 3,
              loadBasis: B02FixtureLoadBasis.external,
            ),
          ],
          activities: [],
          equipmentIncrements: [],
          muscleMappings: [],
          targetComparators: [],
          providerTypes: [],
          unsupportedProviderTypes: {},
          healthImports: [],
          backups: [],
        );

        expect(invalidMapping.validate, throwsA(isA<StateError>()));
        expect(invalidTempo.validate, throwsA(isA<StateError>()));
      },
    );
  });
}
