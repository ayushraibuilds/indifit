import 'dart:math' as math;

import 'b02_execution_models.dart';

/// The immutable input fact used by the muscle-volume calculator.  It is
/// deliberately smaller than a widget model: only performed repetitions and
/// the target minimum needed for the accepted completion ratio are exposed.
class B02MuscleVolumeSetFact {
  final String id;
  final String exerciseId;
  final B02SetRole role;
  final int? actualReps;
  final int? targetRepsMin;
  final List<B02MuscleVolumeSegmentFact> segments;
  final bool isAssisted;

  B02MuscleVolumeSetFact({
    required this.id,
    required this.exerciseId,
    required this.role,
    required this.actualReps,
    required this.targetRepsMin,
    this.segments = const [],
    this.isAssisted = false,
  }) {
    _requireText(id, 'set id');
    _requireText(exerciseId, 'exercise id');
    if (actualReps != null && actualReps! < 0) {
      throw const B02MuscleVolumeValidationException(
        'Actual repetitions cannot be negative.',
      );
    }
    if (targetRepsMin != null && targetRepsMin! < 1) {
      throw const B02MuscleVolumeValidationException(
        'Target minimum repetitions must be positive.',
      );
    }
    var expectedOrdinal = 0;
    var segmentReps = 0;
    for (final segment in segments) {
      if (segment.reps < 1) {
        throw const B02MuscleVolumeValidationException(
          'Set segment repetitions must be positive.',
        );
      }
      if (segment.ordinal != expectedOrdinal) {
        throw const B02MuscleVolumeValidationException(
          'Set segment ordinals must be contiguous.',
        );
      }
      expectedOrdinal++;
      segmentReps += segment.reps;
    }
    if (segments.isNotEmpty &&
        actualReps != null &&
        actualReps != segmentReps) {
      throw const B02MuscleVolumeValidationException(
        'Segment repetitions must equal the performed set repetitions.',
      );
    }
  }

  /// Segments are one set slot.  When the parent row has no total, their
  /// observed repetitions remain valid performed facts.
  int get performedReps =>
      actualReps ??
      segments.fold<int>(0, (total, segment) => total + segment.reps);

  bool get hasPositiveReps => performedReps > 0;

  /// Mechanical completion ratio from B02-D10.  Missing target evidence is
  /// represented by null rather than a fabricated zero.
  double? get effectiveCompletionRatio {
    final target = targetRepsMin;
    if (target == null || !hasPositiveReps) return null;
    return math.min(performedReps / target, 1.0);
  }

  static void _requireText(String value, String field) {
    if (value.trim().isEmpty) {
      throw B02MuscleVolumeValidationException('$field must not be blank.');
    }
  }
}

class B02MuscleVolumeSegmentFact {
  final int ordinal;
  final int reps;

  const B02MuscleVolumeSegmentFact({required this.ordinal, required this.reps})
    : assert(ordinal >= 0),
      assert(reps > 0);
}

/// A grouped, stable-ID mapping read from the normalized mapping table.
/// Unknown mappings intentionally carry no allocatable contributions.
class B02MuscleVolumeMapping {
  final String exerciseId;
  final B02MappingStatus status;
  final String? source;
  final int catalogVersion;
  final List<B02MuscleContribution> contributions;

  B02MuscleVolumeMapping({
    required this.exerciseId,
    required this.status,
    required this.source,
    required this.catalogVersion,
    required this.contributions,
  }) {
    if (exerciseId.trim().isEmpty) {
      throw const B02MuscleVolumeValidationException(
        'Mapping exercise ID must not be blank.',
      );
    }
    if (catalogVersion < 1) {
      throw const B02MuscleVolumeValidationException(
        'Mapping catalog version must be positive.',
      );
    }
    if (status == B02MappingStatus.reviewed &&
        (source == null || source!.trim().isEmpty)) {
      throw const B02MuscleVolumeValidationException(
        'Reviewed mappings require a reviewed source.',
      );
    }
    if (status == B02MappingStatus.unknown && contributions.isNotEmpty) {
      throw const B02MuscleVolumeValidationException(
        'Unknown mappings cannot contain allocation values.',
      );
    }
    final muscleIds = <String>{};
    var total = 0;
    for (final contribution in contributions) {
      if (!muscleIds.add(contribution.muscleId)) {
        throw const B02MuscleVolumeValidationException(
          'A mapping cannot allocate the same muscle twice.',
        );
      }
      total += contribution.contributionBasisPoints;
    }
    if (status == B02MappingStatus.reviewed && total != 10000) {
      throw const B02MuscleVolumeValidationException(
        'Reviewed mappings must total 10000 basis points.',
      );
    }
  }

  bool get isReviewed => status == B02MappingStatus.reviewed;
}

class B02MuscleCatalogEntry {
  final String id;
  final String displayName;
  final String region;
  final int catalogVersion;
  final bool isActive;

  const B02MuscleCatalogEntry({
    required this.id,
    required this.displayName,
    required this.region,
    required this.catalogVersion,
    this.isActive = true,
  });
}

class B02MuscleVolumeCell {
  final String muscleId;
  final String displayName;
  final String region;
  final int catalogVersion;
  final double workingSetUnits;
  final double? effectiveSetUnits;
  final double effectiveEvidenceUnits;

  const B02MuscleVolumeCell({
    required this.muscleId,
    required this.displayName,
    required this.region,
    required this.catalogVersion,
    required this.workingSetUnits,
    required this.effectiveSetUnits,
    required this.effectiveEvidenceUnits,
  });

  /// Null means that no target-backed effective-set evidence exists.
  double? get effectiveEvidenceCoverage =>
      workingSetUnits <= 0 ? null : effectiveEvidenceUnits / workingSetUnits;
}

class B02MuscleVolumeUnknown {
  final double workingSetUnits;
  final double? effectiveSetUnits;
  final double effectiveEvidenceUnits;
  final int workingSetCount;

  const B02MuscleVolumeUnknown({
    required this.workingSetUnits,
    required this.effectiveSetUnits,
    required this.effectiveEvidenceUnits,
    required this.workingSetCount,
  });

  bool get hasUnknownCoverage => workingSetCount > 0;

  double? get effectiveEvidenceCoverage =>
      workingSetUnits <= 0 ? null : effectiveEvidenceUnits / workingSetUnits;
}

class B02MuscleVolumeDateRange {
  final String startLocalDate;
  final String endLocalDate;
  final String timezoneId;
  final DateTime startUtc;
  final DateTime endExclusiveUtc;

  const B02MuscleVolumeDateRange({
    required this.startLocalDate,
    required this.endLocalDate,
    required this.timezoneId,
    required this.startUtc,
    required this.endExclusiveUtc,
  });
}

/// Derived, non-persisted B02 muscle read model.  Its version is part of the
/// contract so consumers cannot silently mix rule revisions.
class B02MuscleVolumeReadModel {
  static const schemaVersion = 'b02-muscle-volume-v1';

  final String startLocalDate;
  final String endLocalDate;
  final String timezoneId;
  final DateTime startUtc;
  final DateTime endExclusiveUtc;
  final List<B02MuscleVolumeCell> muscles;
  final B02MuscleVolumeUnknown unknown;
  final int totalWorkingSetCount;
  final int mappedWorkingSetCount;
  final double mappedWorkingSetUnits;
  final double? mappedEffectiveSetUnits;
  final double totalEffectiveEvidenceUnits;
  final int legacySetCount;
  final int assistedWorkingSetCount;

  const B02MuscleVolumeReadModel({
    required this.startLocalDate,
    required this.endLocalDate,
    required this.timezoneId,
    required this.startUtc,
    required this.endExclusiveUtc,
    required this.muscles,
    required this.unknown,
    required this.totalWorkingSetCount,
    required this.mappedWorkingSetCount,
    required this.mappedWorkingSetUnits,
    required this.mappedEffectiveSetUnits,
    required this.totalEffectiveEvidenceUnits,
    this.legacySetCount = 0,
    this.assistedWorkingSetCount = 0,
  });

  bool get isEmpty => totalWorkingSetCount == 0 && legacySetCount == 0;

  /// Null for an empty range; zero is a real value only when working facts
  /// exist but none have a reviewed mapping.
  double? get mappingCoverage => totalWorkingSetCount == 0
      ? null
      : mappedWorkingSetUnits / totalWorkingSetCount;

  /// Coverage of target-backed effective-set evidence across all working
  /// facts. Missing targets therefore remain visibly incomplete.
  double? get effectiveEvidenceCoverage => totalWorkingSetCount == 0
      ? null
      : totalEffectiveEvidenceUnits / totalWorkingSetCount;

  double get unknownWorkingSetUnits => unknown.workingSetUnits;

  /// Legacy rows retain a count-only coverage category because their role and
  /// target evidence cannot be recovered safely from B01 fields.
  bool get hasLegacyCoverage => legacySetCount > 0;

  bool get hasAssistedWork => assistedWorkingSetCount > 0;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'startLocalDate': startLocalDate,
    'endLocalDate': endLocalDate,
    'timezoneId': timezoneId,
    'startUtc': startUtc.toUtc().toIso8601String(),
    'endExclusiveUtc': endExclusiveUtc.toUtc().toIso8601String(),
    'totalWorkingSetCount': totalWorkingSetCount,
    'mappedWorkingSetCount': mappedWorkingSetCount,
    'mappedWorkingSetUnits': mappedWorkingSetUnits,
    'legacySetCount': legacySetCount,
    'assistedWorkingSetCount': assistedWorkingSetCount,
    if (mappedEffectiveSetUnits != null)
      'mappedEffectiveSetUnits': mappedEffectiveSetUnits,
    'totalEffectiveEvidenceUnits': totalEffectiveEvidenceUnits,
    'mappingCoverage': mappingCoverage,
    'effectiveEvidenceCoverage': effectiveEvidenceCoverage,
    'muscles': [
      for (final cell in muscles)
        {
          'muscleId': cell.muscleId,
          'displayName': cell.displayName,
          'region': cell.region,
          'catalogVersion': cell.catalogVersion,
          'workingSetUnits': cell.workingSetUnits,
          if (cell.effectiveSetUnits != null)
            'effectiveSetUnits': cell.effectiveSetUnits,
          'effectiveEvidenceUnits': cell.effectiveEvidenceUnits,
        },
    ],
    'unknown': {
      'workingSetUnits': unknown.workingSetUnits,
      if (unknown.effectiveSetUnits != null)
        'effectiveSetUnits': unknown.effectiveSetUnits,
      'effectiveEvidenceUnits': unknown.effectiveEvidenceUnits,
      'workingSetCount': unknown.workingSetCount,
    },
    'legacyCoverage': {'setCount': legacySetCount},
  };
}

class B02MuscleVolumeValidationException implements Exception {
  final String message;

  const B02MuscleVolumeValidationException(this.message);

  @override
  String toString() => 'B02MuscleVolumeValidationException: $message';
}

class B02MuscleMappingSeedResult {
  final int insertedMuscles;
  final int insertedMappings;
  final int preservedMuscles;
  final int preservedMappings;

  const B02MuscleMappingSeedResult({
    required this.insertedMuscles,
    required this.insertedMappings,
    required this.preservedMuscles,
    required this.preservedMappings,
  });
}
