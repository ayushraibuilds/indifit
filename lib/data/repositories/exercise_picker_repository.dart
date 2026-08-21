import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/exercise_display_muscles.dart';
import '../database/app_database.dart';

/// Read-only source used by the shared exercise picker. Keeping the source
/// behind this small interface makes picker tests deterministic and prevents
/// widgets from reaching into Drift directly.
abstract interface class ExerciseCatalogSource {
  Future<List<Exercise>> readAll();

  Future<Exercise?> readByStableId(String stableId);
}

final class DriftExerciseCatalogSource implements ExerciseCatalogSource {
  const DriftExerciseCatalogSource(this.database);

  final AppDatabase database;

  @override
  Future<List<Exercise>> readAll() {
    return (database.select(
      database.exercises,
    )..orderBy([(table) => OrderingTerm(expression: table.name)])).get();
  }

  @override
  Future<Exercise?> readByStableId(String stableId) {
    final id = stableId.trim();
    if (id.isEmpty) return Future<Exercise?>.value(null);
    return (database.select(
      database.exercises,
    )..where((table) => table.stableId.equals(id))).getSingleOrNull();
  }
}

@immutable
class ExercisePickerQuery {
  const ExercisePickerQuery({
    this.text = '',
    this.primaryMuscle,
    this.equipment,
  });

  final String text;
  final String? primaryMuscle;
  final String? equipment;

  ExercisePickerQuery copyWith({
    String? text,
    Object? primaryMuscle = _unset,
    Object? equipment = _unset,
  }) {
    return ExercisePickerQuery(
      text: text ?? this.text,
      primaryMuscle: identical(primaryMuscle, _unset)
          ? this.primaryMuscle
          : primaryMuscle as String?,
      equipment: identical(equipment, _unset)
          ? this.equipment
          : equipment as String?,
    );
  }
}

/// Canonical-ID exercise retrieval for the shared picker.
///
/// Text search intentionally includes the current display name, equipment,
/// and all accepted display-muscle tokens so secondary muscles remain useful
/// discovery terms. Category filtering is separate and exact-primary-only via
/// [ExerciseDisplayMuscles.matchesPrimary].
class ExercisePickerRepository {
  ExercisePickerRepository(AppDatabase database)
    : source = DriftExerciseCatalogSource(database);

  ExercisePickerRepository.fromSource(this.source);

  final ExerciseCatalogSource source;

  Future<List<Exercise>> search([
    ExercisePickerQuery query = const ExercisePickerQuery(),
  ]) async {
    final filter = query;
    final all = await source.readAll();
    final textTokens = _tokens(filter.text);
    final primary = _cleanFilter(filter.primaryMuscle);
    final equipment = _cleanFilter(filter.equipment);

    final matches = all
        .where((exercise) {
          // Picker selection must never carry an unresolved/name-only identity.
          final stableId = exercise.stableId?.trim();
          if (stableId == null ||
              stableId.isEmpty ||
              exercise.name.trim().isEmpty) {
            return false;
          }

          final displayMuscles = ExerciseDisplayMuscles.fromMuscleGroups(
            exercise.muscleGroups,
          );
          if (primary != null && !displayMuscles.matchesPrimary(primary)) {
            return false;
          }
          if (equipment != null &&
              !_containsNormalized(exercise.equipment, equipment)) {
            return false;
          }

          if (textTokens.isEmpty) return true;
          final searchable = _normalize(
            [
              exercise.name,
              exercise.equipment,
              exercise.muscleGroups,
            ].join(' '),
          );
          return textTokens.every(searchable.contains);
        })
        .toList(growable: false);

    if (textTokens.isEmpty) return matches;
    matches.sort((left, right) {
      final leftScore = _searchScore(left, filter.text);
      final rightScore = _searchScore(right, filter.text);
      final score = rightScore.compareTo(leftScore);
      if (score != 0) return score;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return matches;
  }

  Future<Exercise?> readByStableId(String stableId) {
    return source.readByStableId(stableId.trim());
  }

  Future<List<String>> readPrimaryMuscles() async {
    final rows = await source.readAll();
    final values = <String, String>{};
    for (final exercise in rows) {
      if (exercise.stableId?.trim().isEmpty != false ||
          exercise.name.trim().isEmpty) {
        continue;
      }
      final primary = ExerciseDisplayMuscles.fromMuscleGroups(
        exercise.muscleGroups,
      ).primary;
      if (primary != null && primary.trim().isNotEmpty) {
        values[primary.toLowerCase()] = primary;
      }
    }
    final result = values.values.toList()..sort();
    return result;
  }

  Future<List<String>> readEquipmentOptions() async {
    final rows = await source.readAll();
    final values = <String, String>{};
    for (final exercise in rows) {
      if (exercise.stableId?.trim().isEmpty != false) continue;
      final equipment = exercise.equipment.trim();
      if (equipment.isNotEmpty) values[equipment.toLowerCase()] = equipment;
    }
    final result = values.values.toList()..sort();
    return result;
  }

  static List<String> _tokens(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return const [];
    return normalized.split(' ');
  }

  static String? _cleanFilter(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty || clean.toLowerCase() == 'all') {
      return null;
    }
    return clean;
  }

  static bool _containsNormalized(String value, String filter) {
    return _normalize(value).contains(_normalize(filter));
  }

  static int _searchScore(Exercise exercise, String query) {
    final normalizedName = _normalize(exercise.name);
    final normalizedQuery = _normalize(query);
    if (normalizedName == normalizedQuery) return 3;
    if (normalizedName.startsWith(normalizedQuery)) return 2;
    return 1;
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}

final exercisePickerRepositoryProvider = Provider<ExercisePickerRepository>(
  (ref) => ExercisePickerRepository(ref.watch(databaseProvider)),
);

const Object _unset = Object();
