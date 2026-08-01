import '../models/b02_execution_models.dart';
import '../models/b02_muscle_volume_models.dart';

/// Pure B02-D10 working/effective-set calculator.  It has no database or UI
/// dependency, which keeps the allocation rules deterministic and testable.
class B02MuscleVolumeCalculator {
  const B02MuscleVolumeCalculator();

  B02MuscleVolumeReadModel calculate({
    required B02MuscleVolumeDateRange range,
    required Iterable<B02MuscleVolumeSetFact> facts,
    required Map<String, B02MuscleVolumeMapping> mappings,
    required Map<String, B02MuscleCatalogEntry> muscles,
    int legacySetCount = 0,
  }) {
    if (legacySetCount < 0) {
      throw const B02MuscleVolumeValidationException(
        'Legacy set coverage cannot be negative.',
      );
    }
    final accumulators = <String, _MuscleAccumulator>{};
    for (final muscle in muscles.values) {
      if (muscle.id.trim().isEmpty ||
          muscle.displayName.trim().isEmpty ||
          muscle.region.trim().isEmpty ||
          muscle.catalogVersion < 1) {
        throw const B02MuscleVolumeValidationException(
          'The canonical muscle catalog contains an invalid row.',
        );
      }
      if (muscle.isActive) {
        accumulators[muscle.id] = _MuscleAccumulator();
      }
    }

    var totalWorkingSetCount = 0;
    var mappedWorkingSetCount = 0;
    var mappedWorkingSetUnits = 0.0;
    var mappedEffectiveSetUnits = 0.0;
    var mappedEffectiveEvidenceUnits = 0.0;
    var hasMappedEffectiveEvidence = false;
    var unknownWorkingSetUnits = 0.0;
    var unknownWorkingSetCount = 0;
    var unknownEffectiveSetUnits = 0.0;
    var unknownEffectiveEvidenceUnits = 0.0;
    var observedAssistedWorkingSetCount = 0;

    for (final fact in facts) {
      if (fact.role != B02SetRole.working || !fact.hasPositiveReps) {
        // Warm-ups and unperformed/zero-rep rows are deliberately absent from
        // both the numerator and denominator.
        continue;
      }
      totalWorkingSetCount++;
      if (fact.isAssisted) observedAssistedWorkingSetCount++;
      final ratio = fact.effectiveCompletionRatio;
      final mapping = mappings[fact.exerciseId];
      final allocation = mapping?.exerciseId == fact.exerciseId
          ? _reviewedAllocation(mapping, muscles)
          : null;
      if (allocation == null) {
        unknownWorkingSetUnits += 1.0;
        unknownWorkingSetCount++;
        if (ratio != null) {
          unknownEffectiveSetUnits += ratio;
          unknownEffectiveEvidenceUnits += 1.0;
        }
        continue;
      }

      mappedWorkingSetCount++;
      mappedWorkingSetUnits += 1.0;
      for (final entry in allocation.entries) {
        final contribution = entry.value;
        final units = contribution / 10000.0;
        final accumulator = accumulators[entry.key];
        // `_reviewedAllocation` has already checked the active catalog, but
        // keep this guard so a future caller cannot silently drop a muscle.
        if (accumulator == null) {
          throw const B02MuscleVolumeValidationException(
            'A reviewed mapping references a missing active muscle.',
          );
        }
        accumulator.workingSetUnits += units;
        if (ratio != null) {
          accumulator.effectiveSetUnits += units * ratio;
          accumulator.effectiveEvidenceUnits += units;
          mappedEffectiveSetUnits += units * ratio;
          mappedEffectiveEvidenceUnits += units;
          hasMappedEffectiveEvidence = true;
        }
      }
    }

    final cells = <B02MuscleVolumeCell>[
      for (final muscle in muscles.values.where((entry) => entry.isActive))
        () {
          final accumulator = accumulators[muscle.id]!;
          return B02MuscleVolumeCell(
            muscleId: muscle.id,
            displayName: muscle.displayName,
            region: muscle.region,
            catalogVersion: muscle.catalogVersion,
            workingSetUnits: accumulator.workingSetUnits,
            effectiveSetUnits: accumulator.hasEffectiveEvidence
                ? accumulator.effectiveSetUnits
                : null,
            effectiveEvidenceUnits: accumulator.effectiveEvidenceUnits,
          );
        }(),
    ]..sort((left, right) => left.muscleId.compareTo(right.muscleId));

    return B02MuscleVolumeReadModel(
      startLocalDate: range.startLocalDate,
      endLocalDate: range.endLocalDate,
      timezoneId: range.timezoneId,
      startUtc: range.startUtc,
      endExclusiveUtc: range.endExclusiveUtc,
      muscles: List.unmodifiable(cells),
      unknown: B02MuscleVolumeUnknown(
        workingSetUnits: unknownWorkingSetUnits,
        effectiveSetUnits:
            unknownWorkingSetCount > 0 && unknownEffectiveEvidenceUnits > 0
            ? unknownEffectiveSetUnits
            : null,
        effectiveEvidenceUnits: unknownEffectiveEvidenceUnits,
        workingSetCount: unknownWorkingSetCount,
      ),
      totalWorkingSetCount: totalWorkingSetCount,
      mappedWorkingSetCount: mappedWorkingSetCount,
      mappedWorkingSetUnits: mappedWorkingSetUnits,
      mappedEffectiveSetUnits: hasMappedEffectiveEvidence
          ? mappedEffectiveSetUnits
          : null,
      totalEffectiveEvidenceUnits:
          mappedEffectiveEvidenceUnits + unknownEffectiveEvidenceUnits,
      legacySetCount: legacySetCount,
      assistedWorkingSetCount: observedAssistedWorkingSetCount,
    );
  }

  /// Returns a complete allocation only when the mapping is reviewed, all
  /// referenced muscles are active canonical rows, and the total is exact.
  /// Any other state is an explicit unknown set, never a zero allocation.
  Map<String, int>? _reviewedAllocation(
    B02MuscleVolumeMapping? mapping,
    Map<String, B02MuscleCatalogEntry> muscles,
  ) {
    if (mapping == null || !mapping.isReviewed) return null;
    final allocation = <String, int>{};
    var total = 0;
    for (final contribution in mapping.contributions) {
      final muscle = muscles[contribution.muscleId];
      if (muscle == null ||
          !muscle.isActive ||
          muscle.catalogVersion != mapping.catalogVersion) {
        return null;
      }
      if (allocation.containsKey(contribution.muscleId)) return null;
      allocation[contribution.muscleId] = contribution.contributionBasisPoints;
      total += contribution.contributionBasisPoints;
    }
    return allocation.isNotEmpty && total == 10000 ? allocation : null;
  }
}

/// Naming alias used by repositories and future progress consumers.  The
/// public operation remains the pure calculator above.
class B02MuscleVolumeService {
  final B02MuscleVolumeCalculator _calculator;

  const B02MuscleVolumeService({
    B02MuscleVolumeCalculator calculator = const B02MuscleVolumeCalculator(),
  }) : _calculator = calculator;

  B02MuscleVolumeReadModel calculate({
    required B02MuscleVolumeDateRange range,
    required Iterable<B02MuscleVolumeSetFact> facts,
    required Map<String, B02MuscleVolumeMapping> mappings,
    required Map<String, B02MuscleCatalogEntry> muscles,
    int legacySetCount = 0,
  }) => _calculator.calculate(
    range: range,
    facts: facts,
    mappings: mappings,
    muscles: muscles,
    legacySetCount: legacySetCount,
  );
}

class _MuscleAccumulator {
  double workingSetUnits = 0.0;
  double effectiveSetUnits = 0.0;
  double effectiveEvidenceUnits = 0.0;

  bool get hasEffectiveEvidence => effectiveEvidenceUnits > 0;
}

/// Stable-ID mapping validation shared by catalog seeding and read paths.
class B02MuscleMappingValidator {
  const B02MuscleMappingValidator();

  void validate({
    required Iterable<B02MuscleVolumeMapping> mappings,
    required Set<String> canonicalExerciseIds,
    required Map<String, B02MuscleCatalogEntry> muscles,
  }) {
    final byExercise = <String, List<B02MuscleVolumeMapping>>{};
    for (final mapping in mappings) {
      if (!canonicalExerciseIds.contains(mapping.exerciseId)) {
        throw const B02MuscleVolumeValidationException(
          'A muscle mapping references a missing canonical exercise.',
        );
      }
      if (mapping.isReviewed) {
        for (final contribution in mapping.contributions) {
          final muscle = muscles[contribution.muscleId];
          if (muscle == null ||
              !muscle.isActive ||
              muscle.catalogVersion != mapping.catalogVersion) {
            throw const B02MuscleVolumeValidationException(
              'A reviewed mapping references a non-canonical muscle version.',
            );
          }
        }
      }
      byExercise.putIfAbsent(mapping.exerciseId, () => []).add(mapping);
    }

    for (final entries in byExercise.values) {
      final reviewed = entries.where((entry) => entry.isReviewed).toList();
      final unknown = entries.where((entry) => !entry.isReviewed).toList();
      if (reviewed.isEmpty) continue;
      if (unknown.isNotEmpty) {
        throw const B02MuscleVolumeValidationException(
          'A canonical exercise cannot mix reviewed and unknown mappings.',
        );
      }
      final muscleIds = <String>{};
      var total = 0;
      for (final mapping in reviewed) {
        for (final contribution in mapping.contributions) {
          if (!muscleIds.add(contribution.muscleId)) {
            throw const B02MuscleVolumeValidationException(
              'A canonical exercise maps a muscle more than once.',
            );
          }
          total += contribution.contributionBasisPoints;
        }
      }
      if (total != 10000) {
        throw const B02MuscleVolumeValidationException(
          'Reviewed exercise allocations must total 10000 basis points.',
        );
      }
    }
  }
}
