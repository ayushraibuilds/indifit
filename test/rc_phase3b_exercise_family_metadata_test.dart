import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/exercise_family_metadata.dart';
import 'package:indifit/core/fixtures/exercise_identity_fixtures.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/features/exercise_library/exercise_family_presentation.dart';

void main() {
  group('Phase 3B reviewed family metadata', () {
    test(
      'all reviewed families and members validate against the catalogue',
      () {
        final knownIds = ExerciseCatalogManifest.goldenCatalogUuids.values
            .toSet();
        final registry = ExerciseFamilyRegistry.validated(
          families: reviewedExerciseFamilies,
          knownExerciseIds: knownIds,
        );

        expect(registry.families, hasLength(35));
        expect(
          registry.families.expand((family) => family.members).length,
          140,
        );
        for (final family in registry.families) {
          expect(knownIds, contains(family.baseExerciseId));
          expect(
            family.members.where(
              (member) => member.role == ExerciseFamilyMemberRole.base,
            ),
            hasLength(1),
          );
          expect(
            family.members.map((member) => member.exerciseId).toSet(),
            hasLength(family.members.length),
          );
        }
      },
    );

    test('runtime metadata exactly matches the reviewed UUID ledger', () {
      final rows = File(
        'docs/implementation/r08/R08_0_2_REPDB_MAPPING_REVIEW.csv',
      ).readAsLinesSync().skip(1);
      final ledger = <String, ({String baseId, List<String> memberIds})>{};
      for (final row in rows) {
        if (row.trim().isEmpty) continue;
        final columns = row.split(',');
        ledger[columns[0]] = (
          baseId: columns[2],
          memberIds: columns[3].split(';'),
        );
      }

      expect(ledger, hasLength(reviewedExerciseFamilies.length));
      for (final family in reviewedExerciseFamilies) {
        final reviewed = ledger[family.familyId];
        expect(reviewed, isNotNull, reason: family.familyId);
        expect(family.baseExerciseId, reviewed!.baseId);
        expect(
          family.members.map((member) => member.exerciseId),
          orderedEquals(reviewed.memberIds),
          reason: family.familyId,
        );
      }
    });

    test('known reviewed duplicate examples resolve by exact UUID', () {
      expect(
        reviewedExerciseFamilyRegistry.familyForId('FAM-07')?.baseExerciseId,
        _deadliftBaseId,
      );
      expect(
        reviewedExerciseFamilyRegistry.familyForId('FAM-13')?.baseExerciseId,
        'd3b5ab04-74f6-5155-9621-50238644eeda',
      );
      expect(
        reviewedExerciseFamilyRegistry.familyForId('FAM-32')?.baseExerciseId,
        'bdd4c5a6-ea2b-55e0-a6e0-206ea683b886',
      );
    });

    test('rejected media does not erase explicit family identity', () {
      expect(
        reviewedExerciseFamilyRegistry.familyForExerciseId(
          '767caf63-b617-5a2f-9a01-a22b55918316',
        ),
        same(reviewedExerciseFamilyRegistry.familyForId('FAM-03')),
      );
    });

    test('unknown member and missing base fail validation', () {
      final invalid = ExerciseFamilyMetadata(
        familyId: 'invalid',
        baseExerciseId: _deadliftBaseId,
        approvalRecordId: 'review',
        members: const [
          ExerciseFamilyMemberMetadata(
            exerciseId: _deadliftStandardId,
            role: ExerciseFamilyMemberRole.variant,
            variantLabel: 'Standard',
          ),
          ExerciseFamilyMemberMetadata(
            exerciseId: 'unknown-id',
            role: ExerciseFamilyMemberRole.variant,
            variantLabel: 'Other',
          ),
        ],
      );

      expect(
        () => ExerciseFamilyRegistry.validated(
          families: [invalid],
          knownExerciseIds: {_deadliftBaseId, _deadliftStandardId},
        ),
        throwsA(isA<ExerciseFamilyValidationException>()),
      );
    });

    test(
      'duplicate family membership and duplicate family IDs are rejected',
      () {
        final first = _family(
          'duplicate',
          _deadliftBaseId,
          _deadliftStandardId,
        );
        final second = _family('other', _deadliftPauseId, _deadliftStandardId);
        final third = _family('duplicate', _deadliftSlowId, _deadliftSlowId);

        final errors = ExerciseFamilyRegistry.validate(
          [first, second, third],
          {
            _deadliftBaseId,
            _deadliftStandardId,
            _deadliftPauseId,
            _deadliftSlowId,
          },
        );
        expect(
          errors.any((error) => error.contains('Duplicate family ID')),
          isTrue,
        );
        expect(
          errors.any((error) => error.contains('belongs to both')),
          isTrue,
        );
      },
    );

    test('invalid optional metadata fails open to an empty registry', () {
      final registry = ExerciseFamilyRegistry.failOpen(
        families: [_family('invalid', _deadliftBaseId, 'unknown-id')],
        knownExerciseIds: {_deadliftBaseId},
      );
      expect(registry.families, isEmpty);
      expect(registry.familyForExerciseId(_deadliftBaseId), isNull);
    });
  });

  group('Phase 3B family presentation', () {
    test('generic results collapse exact siblings behind the base row', () {
      final items = buildExerciseFamilyPresentation([
        _exercise(_deadliftStandardId, 'Barbell Deadlift (Standard)'),
        _exercise(_deadliftPauseId, 'Pause Barbell Deadlift'),
        _exercise(_deadliftBaseId, 'Barbell Deadlift'),
        _exercise(_deadliftSlowId, 'Slow Eccentric Barbell Deadlift'),
        _exercise('independent-id', 'Independent Row'),
      ]);

      expect(items, hasLength(2));
      final family = items.singleWhere((item) => item.isFamily);
      expect(family.primaryExercise.stableId, _deadliftBaseId);
      expect(family.variantCount, 3);
      expect(
        family.visibleVariants.map((exercise) => exercise.stableId),
        containsAll({_deadliftStandardId, _deadliftPauseId, _deadliftSlowId}),
      );
    });

    test('a precise variant result stays independently discoverable', () {
      final items = buildExerciseFamilyPresentation([
        _exercise(_deadliftStandardId, 'Barbell Deadlift (Standard)'),
      ]);
      expect(items, hasLength(1));
      expect(items.single.isFamily, isFalse);
      expect(items.single.primaryExercise.stableId, _deadliftStandardId);
    });

    test('similar names and unknown IDs are never grouped', () {
      final items = buildExerciseFamilyPresentation([
        _exercise('custom-a', 'Barbell Deadlift'),
        _exercise('custom-b', 'Barbell Deadlift (Standard)'),
      ]);
      expect(items, hasLength(2));
      expect(items.every((item) => !item.isFamily), isTrue);
    });
  });
}

ExerciseFamilyMetadata _family(
  String familyId,
  String baseId,
  String variantId,
) {
  return ExerciseFamilyMetadata(
    familyId: familyId,
    baseExerciseId: baseId,
    approvalRecordId: 'review-$familyId',
    members: [
      ExerciseFamilyMemberMetadata(
        exerciseId: baseId,
        role: ExerciseFamilyMemberRole.base,
      ),
      ExerciseFamilyMemberMetadata(
        exerciseId: variantId,
        role: ExerciseFamilyMemberRole.variant,
        variantLabel: 'Variant',
      ),
    ],
  );
}

Exercise _exercise(String id, String name) => Exercise(
  id: id.hashCode,
  stableId: id,
  name: name,
  muscleGroups: 'Back,Hamstrings',
  equipment: 'Barbell',
  difficulty: 'Intermediate',
  formCues: 'Keep the bar close.',
  commonMistakes: '',
  isCustom: id.startsWith('custom') || id == 'independent-id',
);

const _deadliftBaseId = 'b102bfa4-6cc5-5e60-accb-82a1ae39b8bc';
const _deadliftStandardId = '7fd950ce-79e5-5558-86d7-fc197b1026ea';
const _deadliftPauseId = '18b6bdf9-9941-5bb1-9369-1c8d73f41560';
const _deadliftSlowId = '3bc421ec-ab46-5c7c-a9fb-ce137b9bf737';
