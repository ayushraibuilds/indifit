import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b02_muscle_catalog.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_muscle_volume_models.dart';
import 'package:indifit/data/services/b02_muscle_volume_service.dart';

void main() {
  final muscles = {
    for (final muscle in B02CanonicalMuscleCatalog.muscles) muscle.id: muscle,
  };
  final mappings = {
    for (final mapping in B02CanonicalMuscleCatalog.reviewedMappings())
      mapping.exerciseId: mapping,
  };
  final range = B02MuscleVolumeDateRange(
    startLocalDate: '2026-08-01',
    endLocalDate: '2026-08-07',
    timezoneId: 'Asia/Kolkata',
    startUtc: DateTime.utc(2026, 7, 31, 18, 30),
    endExclusiveUtc: DateTime.utc(2026, 8, 7, 18, 30),
  );

  B02MuscleVolumeSetFact fact({
    required String id,
    required String exerciseId,
    required B02SetRole role,
    required int? reps,
    int? target = 10,
    List<B02MuscleVolumeSegmentFact> segments = const [],
    bool assisted = false,
  }) => B02MuscleVolumeSetFact(
    id: id,
    exerciseId: exerciseId,
    role: role,
    actualReps: reps,
    targetRepsMin: target,
    segments: segments,
    isAssisted: assisted,
  );

  test('allocates reviewed sets, excludes warm-ups, and exposes unknowns', () {
    final model = const B02MuscleVolumeCalculator().calculate(
      range: range,
      muscles: muscles,
      mappings: mappings,
      facts: [
        fact(
          id: 'warmup',
          exerciseId: '089ec703-a25e-5b12-a39a-78b17ee33742',
          role: B02SetRole.warmup,
          reps: 12,
        ),
        fact(
          id: 'bench-partial',
          exerciseId: '089ec703-a25e-5b12-a39a-78b17ee33742',
          role: B02SetRole.working,
          reps: 8,
        ),
        fact(
          id: 'squat-drop-rest-pause',
          exerciseId: 'd3b5ab04-74f6-5155-9621-50238644eeda',
          role: B02SetRole.working,
          reps: null,
          target: 10,
          segments: [
            const B02MuscleVolumeSegmentFact(ordinal: 0, reps: 8),
            const B02MuscleVolumeSegmentFact(ordinal: 1, reps: 4),
            const B02MuscleVolumeSegmentFact(ordinal: 2, reps: 3),
          ],
        ),
        fact(
          id: 'assisted-no-target',
          exerciseId: '089ec703-a25e-5b12-a39a-78b17ee33742',
          role: B02SetRole.working,
          reps: 6,
          target: null,
          assisted: true,
        ),
        fact(
          id: 'custom-unknown',
          exerciseId: 'legacy-custom-unresolved-001',
          role: B02SetRole.working,
          reps: 5,
        ),
      ],
    );

    expect(model.totalWorkingSetCount, 4);
    expect(model.mappedWorkingSetCount, 3);
    expect(model.unknown.workingSetCount, 1);
    expect(model.mappingCoverage, closeTo(0.75, 0.000001));
    expect(model.assistedWorkingSetCount, 1);
    expect(model.unknown.effectiveSetUnits, closeTo(0.5, 0.000001));

    final chest = model.muscles.singleWhere((cell) => cell.muscleId == 'chest');
    final triceps = model.muscles.singleWhere(
      (cell) => cell.muscleId == 'triceps',
    );
    final quadriceps = model.muscles.singleWhere(
      (cell) => cell.muscleId == 'quadriceps',
    );
    final glutes = model.muscles.singleWhere(
      (cell) => cell.muscleId == 'glute-maximus',
    );
    expect(chest.workingSetUnits, closeTo(0.7 * 2, 0.000001));
    expect(triceps.workingSetUnits, closeTo(0.3 * 2, 0.000001));
    expect(chest.effectiveSetUnits, closeTo(0.7 * 0.8, 0.000001));
    expect(quadriceps.effectiveSetUnits, closeTo(0.7, 0.000001));
    expect(glutes.effectiveSetUnits, closeTo(0.3, 0.000001));
    expect(model.totalEffectiveEvidenceUnits, closeTo(3, 0.000001));
  });

  test('group membership and advanced segments do not multiply set slots', () {
    final model = const B02MuscleVolumeCalculator().calculate(
      range: range,
      muscles: muscles,
      mappings: mappings,
      facts: [
        fact(
          id: 'member-a',
          exerciseId: '089ec703-a25e-5b12-a39a-78b17ee33742',
          role: B02SetRole.working,
          reps: 10,
        ),
        fact(
          id: 'member-b',
          exerciseId: '089ec703-a25e-5b12-a39a-78b17ee33742',
          role: B02SetRole.working,
          reps: 10,
          segments: const [
            B02MuscleVolumeSegmentFact(ordinal: 0, reps: 5),
            B02MuscleVolumeSegmentFact(ordinal: 1, reps: 5),
          ],
        ),
      ],
    );
    expect(model.totalWorkingSetCount, 2);
    expect(model.mappedWorkingSetUnits, closeTo(2, 0.000001));
    expect(
      model.muscles
          .singleWhere((cell) => cell.muscleId == 'chest')
          .workingSetUnits,
      closeTo(1.4, 0.000001),
    );
  });

  test('malformed reviewed mapping fails closed', () {
    final bad = B02MuscleVolumeMapping(
      exerciseId: '089ec703-a25e-5b12-a39a-78b17ee33742',
      status: B02MappingStatus.reviewed,
      source: 'reviewed-b02-v1',
      catalogVersion: 1,
      contributions: [
        B02MuscleContribution(
          muscleId: 'not-in-canonical-taxonomy',
          role: B02MuscleRole.primary,
          contributionBasisPoints: 10000,
        ),
      ],
    );
    expect(
      () => const B02MuscleMappingValidator().validate(
        mappings: [bad],
        canonicalExerciseIds: {'089ec703-a25e-5b12-a39a-78b17ee33742'},
        muscles: muscles,
      ),
      throwsA(isA<B02MuscleVolumeValidationException>()),
    );
  });

  test('versioned projection keeps unknown and legacy coverage explicit', () {
    final model = const B02MuscleVolumeCalculator().calculate(
      range: range,
      muscles: muscles,
      mappings: const {},
      facts: [
        fact(
          id: 'unknown-working',
          exerciseId: 'legacy-custom-unresolved-001',
          role: B02SetRole.working,
          reps: 6,
          target: null,
        ),
      ],
      legacySetCount: 2,
    );
    final json = model.toJson();
    expect(json['schemaVersion'], B02MuscleVolumeReadModel.schemaVersion);
    expect(json['legacyCoverage'], {'setCount': 2});
    expect(json['unknown'], containsPair('workingSetCount', 1));
    expect(json['unknown'], isNot(containsPair('effectiveSetUnits', 0)));
    expect(json['mappingCoverage'], 0.0);
  });
}
