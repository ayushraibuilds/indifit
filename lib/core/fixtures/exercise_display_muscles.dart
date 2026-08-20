import 'package:flutter/foundation.dart';

/// Resolved primary and secondary display muscles for consumer UI presentation,
/// exercise library categorization, and search.
///
/// Under canonical IndiFit domain rules:
/// - The first valid ordered muscle token is the PRIMARY display muscle.
/// - Any remaining valid, distinct muscle tokens are SECONDARY display muscles.
///
/// NOTE: B02 `ExerciseMuscleMappings` and `B02MuscleVolumeRepository` remain the
/// sole authoritative source for muscle-allocation arithmetic, volume tracking,
/// and analytics. This resolver operates strictly on catalog display metadata.
@immutable
class ExerciseDisplayMuscles {
  /// The primary target muscle for library categorization and prominent display.
  final String? primary;

  /// Ordered list of distinct secondary/assisting muscles.
  final List<String> secondary;

  const ExerciseDisplayMuscles._({this.primary, this.secondary = const []});

  /// Empty or unassigned display muscles.
  static const ExerciseDisplayMuscles empty = ExerciseDisplayMuscles._();

  /// Whether a valid primary muscle is resolved.
  bool get hasPrimary => primary != null && primary!.trim().isNotEmpty;

  /// Whether any secondary muscles are resolved.
  bool get hasSecondary => secondary.isNotEmpty;

  /// Whether no primary or secondary muscles are present.
  bool get isEmpty => !hasPrimary && !hasSecondary;

  /// Whether any display muscle information is present.
  bool get isNotEmpty => !isEmpty;

  /// All distinct display muscles with primary first, followed by secondary.
  List<String> get all => [if (hasPrimary) primary!, ...secondary];

  /// Resolves display muscles from a comma-separated [muscleGroups] string.
  ///
  /// Safe against null, empty, whitespace-only, malformed strings, and duplicate tokens.
  /// Preserves the original token casing of the first occurrence for display,
  /// while performing case-insensitive deduplication.
  factory ExerciseDisplayMuscles.fromMuscleGroups(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return empty;
    }

    final rawTokens = raw.split(',');
    final seen = <String>{};
    final tokens = <String>[];

    for (final rawToken in rawTokens) {
      final trimmed = rawToken.trim();
      if (trimmed.isEmpty) continue;
      final normalized = trimmed.toLowerCase();
      if (seen.add(normalized)) {
        tokens.add(trimmed);
      }
    }

    if (tokens.isEmpty) {
      return empty;
    }

    final primaryToken = tokens.first;
    final secondaryTokens = tokens.length > 1
        ? List<String>.unmodifiable(tokens.sublist(1))
        : const <String>[];

    return ExerciseDisplayMuscles._(
      primary: primaryToken,
      secondary: secondaryTokens,
    );
  }

  /// Checks whether this exercise matches the given [muscleCategory] as its PRIMARY muscle.
  ///
  /// Matching is case-insensitive and exact token (not substring).
  /// Passing 'All' (case-insensitive) matches any exercise.
  bool matchesPrimary(String? muscleCategory) {
    if (muscleCategory == null || muscleCategory.trim().isEmpty) return false;
    final cleanCategory = muscleCategory.trim().toLowerCase();
    if (cleanCategory == 'all') return true;
    if (!hasPrimary) return false;
    return primary!.trim().toLowerCase() == cleanCategory;
  }

  /// Checks whether this exercise includes [muscle] as either PRIMARY or SECONDARY.
  ///
  /// Matching is case-insensitive and exact token (not substring).
  bool containsMuscle(String? muscle) {
    if (muscle == null || muscle.trim().isEmpty) return false;
    final cleanMuscle = muscle.trim().toLowerCase();
    if (hasPrimary && primary!.trim().toLowerCase() == cleanMuscle) return true;
    return secondary.any((sec) => sec.trim().toLowerCase() == cleanMuscle);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseDisplayMuscles &&
          runtimeType == other.runtimeType &&
          primary == other.primary &&
          listEquals(secondary, other.secondary);

  @override
  int get hashCode => Object.hash(primary, Object.hashAll(secondary));

  @override
  String toString() =>
      'ExerciseDisplayMuscles(primary: $primary, secondary: $secondary)';
}
