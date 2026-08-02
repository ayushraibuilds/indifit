import '../../data/models/b02_execution_models.dart';
import '../../data/models/b02_muscle_volume_models.dart';
import 'b02_execution_fixture_matrix.dart';

/// The reviewed B02-D10 taxonomy and mapping seed.  The exercise allocations
/// are projected only from the accepted fixture matrix; no muscleGroups text
/// or fuzzy exercise-name lookup is involved.
class B02CanonicalMuscleCatalog {
  static const int catalogVersion = 1;

  static const List<B02MuscleCatalogEntry> muscles = [
    B02MuscleCatalogEntry(
      id: 'chest',
      displayName: 'Chest',
      region: 'torso',
      catalogVersion: catalogVersion,
    ),
    B02MuscleCatalogEntry(
      id: 'glute-maximus',
      displayName: 'Gluteus Maximus',
      region: 'hips',
      catalogVersion: catalogVersion,
    ),
    B02MuscleCatalogEntry(
      id: 'quadriceps',
      displayName: 'Quadriceps',
      region: 'legs',
      catalogVersion: catalogVersion,
    ),
    B02MuscleCatalogEntry(
      id: 'triceps',
      displayName: 'Triceps',
      region: 'arms',
      catalogVersion: catalogVersion,
    ),
  ];

  static List<B02MuscleVolumeMapping> reviewedMappings() {
    final fixture = B02ExecutionFixtureMatrix.current;
    fixture.validate();
    return [
      for (final mapping in fixture.muscleMappings)
        if (mapping.status == B02FixtureMappingStatus.reviewed)
          B02MuscleVolumeMapping(
            exerciseId: mapping.exerciseStableId,
            status: B02MappingStatus.reviewed,
            source: mapping.reviewedSource,
            catalogVersion: mapping.mappingVersion,
            contributions: [
              for (final contribution in mapping.contributions)
                B02MuscleContribution(
                  muscleId: contribution.muscleId,
                  role: _role(contribution.role),
                  contributionBasisPoints: contribution.contributionBasisPoints,
                ),
            ],
          ),
    ];
  }

  static B02MuscleRole _role(B02FixtureMuscleRole role) => switch (role) {
    B02FixtureMuscleRole.primary => B02MuscleRole.primary,
    B02FixtureMuscleRole.secondary => B02MuscleRole.secondary,
    B02FixtureMuscleRole.stabilizing => B02MuscleRole.stabilizing,
  };
}
