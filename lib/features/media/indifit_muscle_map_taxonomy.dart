import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:indifit/core/fixtures/exercise_display_muscles.dart';

/// Presentation-only resolution of an IndiFit display concept to local
/// MuscleMap geometry slugs.
///
/// This is deliberately one-way. The upstream slugs are not canonical IndiFit
/// muscles, are not written to B02, and never participate in exercise
/// identity, volume arithmetic, or taxonomy decisions.
@immutable
class IndiFitMuscleMapExerciseResolution {
  const IndiFitMuscleMapExerciseResolution({
    required this.primarySlugs,
    required this.secondarySlugs,
    required this.unresolvedMuscles,
  });

  final Set<String> primarySlugs;
  final Set<String> secondarySlugs;
  final List<String> unresolvedMuscles;

  bool get hasMappedRegions =>
      primarySlugs.isNotEmpty || secondarySlugs.isNotEmpty;

  bool get hasUnresolvedMuscles => unresolvedMuscles.isNotEmpty;
}

/// Presentation-only resolution of caller-provided heat values.
@immutable
class IndiFitMuscleMapHeatResolution {
  const IndiFitMuscleMapHeatResolution({
    required this.regionIntensities,
    required this.unresolvedMuscles,
  });

  /// Values are keyed by upstream geometry slug and retain the caller's
  /// intensity. The renderer clamps only while painting.
  final Map<String, double> regionIntensities;
  final List<String> unresolvedMuscles;

  bool get hasMappedRegions => regionIntensities.isNotEmpty;

  bool get hasUnresolvedMuscles => unresolvedMuscles.isNotEmpty;
}

/// Explicit adapter for the presentation concepts currently emitted by
/// [ExerciseDisplayMuscles], plus the existing B02 IDs and display labels.
///
/// Matching is case-insensitive and whitespace-normalized, but otherwise
/// exact. There is no substring, fuzzy, or name-similarity fallback.
class IndiFitMuscleMapTaxonomyAdapter {
  const IndiFitMuscleMapTaxonomyAdapter();

  /// Complete supported presentation-concept table for this renderer.
  ///
  /// Values are MuscleMap slugs from the pinned local geometry registry. The
  /// keys are limited to the current exercise display vocabulary and the
  /// existing B02 IDs/labels. Geometry names are deliberately not accepted as
  /// inputs merely because the pinned renderer happens to contain a region.
  static const Map<String, Set<String>> supportedConceptToGeometry = {
    'back': {'upper-back', 'lower-back', 'trapezius'},
    'biceps': {'biceps'},
    'calves': {'calves'},
    'chest': {'chest', 'upper-chest', 'lower-chest'},
    'core': {'abs', 'obliques'},
    'glute-maximus': {'gluteal'},
    'gluteus maximus': {'gluteal'},
    'glutes': {'gluteal'},
    'hamstrings': {'hamstring'},
    'legs': {'quadriceps', 'inner-quad', 'outer-quad'},
    'quadriceps': {'quadriceps', 'inner-quad', 'outer-quad'},
    'shoulders': {'deltoids', 'front-deltoid'},
    'triceps': {'triceps'},
  };

  /// Resolves the ordered primary/secondary display facts for exercise mode.
  IndiFitMuscleMapExerciseResolution resolveExercise({
    String? primary,
    Iterable<String> secondary = const <String>[],
  }) {
    final primarySlugs = <String>{};
    final secondarySlugs = <String>{};
    final unresolved = <String>[];

    void resolveOne(String value, Set<String> destination) {
      final key = _normalize(value);
      final slugs = supportedConceptToGeometry[key];
      if (slugs == null) {
        if (!_containsNormalized(unresolved, value)) {
          unresolved.add(value.trim());
        }
        return;
      }
      destination.addAll(slugs);
    }

    if (primary != null && primary.trim().isNotEmpty) {
      resolveOne(primary, primarySlugs);
    }
    for (final value in secondary) {
      if (value.trim().isNotEmpty) {
        resolveOne(value, secondarySlugs);
      }
    }

    // A region cannot be both roles visually. Presentation primary wins.
    secondarySlugs.removeAll(primarySlugs);
    return IndiFitMuscleMapExerciseResolution(
      primarySlugs: Set.unmodifiable(primarySlugs),
      secondarySlugs: Set.unmodifiable(secondarySlugs),
      unresolvedMuscles: List.unmodifiable(unresolved),
    );
  }

  /// Resolves caller-provided heat values without inventing values for missing
  /// or unknown concepts. If multiple concepts target a region, the highest
  /// supplied intensity wins deterministically.
  IndiFitMuscleMapHeatResolution resolveHeat(Map<String, double> intensities) {
    final regionIntensities = <String, double>{};
    final unresolved = <String>[];
    for (final entry in intensities.entries) {
      if (!entry.value.isFinite) {
        if (!_containsNormalized(unresolved, entry.key)) {
          unresolved.add('${entry.key.trim()} (invalid intensity)');
        }
        continue;
      }
      final key = _normalize(entry.key);
      final slugs = supportedConceptToGeometry[key];
      if (slugs == null) {
        if (!_containsNormalized(unresolved, entry.key)) {
          unresolved.add(entry.key.trim());
        }
        continue;
      }
      for (final slug in slugs) {
        final existing = regionIntensities[slug];
        if (existing == null || entry.value > existing) {
          regionIntensities[slug] = entry.value;
        }
      }
    }
    return IndiFitMuscleMapHeatResolution(
      regionIntensities: UnmodifiableMapView(regionIntensities),
      unresolvedMuscles: List.unmodifiable(unresolved),
    );
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool _containsNormalized(Iterable<String> values, String candidate) {
    final normalized = _normalize(candidate);
    return values.any((value) => _normalize(value) == normalized);
  }
}

/// Immutable bridge from canonical display facts to the renderer's exercise
/// input. It does not alter [ExerciseDisplayMuscles] or any B02 model.
@immutable
class IndiFitMuscleMapExerciseInput {
  const IndiFitMuscleMapExerciseInput({
    this.primaryMuscle,
    this.secondaryMuscles = const <String>[],
  });

  factory IndiFitMuscleMapExerciseInput.fromDisplayMuscles(
    ExerciseDisplayMuscles displayMuscles,
  ) {
    return IndiFitMuscleMapExerciseInput(
      primaryMuscle: displayMuscles.primary,
      secondaryMuscles: displayMuscles.secondary,
    );
  }

  final String? primaryMuscle;
  final List<String> secondaryMuscles;
}
