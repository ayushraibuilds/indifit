import 'package:flutter/foundation.dart';

import '../../core/fixtures/exercise_display_muscles.dart';
import '../database/app_database.dart';

/// Typed availability for the exercise-context read boundary.
///
/// A missing catalog row is a normal presentation fallback. A read failure is
/// kept distinct for diagnostics, but neither state is allowed to block set
/// logging or expose database details to the player.
enum B07ExerciseContextStatus { available, unavailable, queryFailure }

@immutable
class B07ExerciseContext {
  final String canonicalExerciseId;
  final String canonicalName;
  final String equipment;
  final ExerciseDisplayMuscles displayMuscles;
  final List<String> formCues;
  final List<String> commonMistakes;

  const B07ExerciseContext({
    required this.canonicalExerciseId,
    required this.canonicalName,
    required this.equipment,
    required this.displayMuscles,
    required this.formCues,
    required this.commonMistakes,
  });

  bool get hasGuidance => formCues.isNotEmpty || commonMistakes.isNotEmpty;
}

@immutable
class B07ExerciseContextResult {
  final B07ExerciseContextStatus status;
  final B07ExerciseContext? context;

  const B07ExerciseContextResult._({required this.status, this.context});

  const B07ExerciseContextResult.available(B07ExerciseContext context)
    : this._(status: B07ExerciseContextStatus.available, context: context);

  const B07ExerciseContextResult.unavailable()
    : this._(status: B07ExerciseContextStatus.unavailable);

  const B07ExerciseContextResult.queryFailure()
    : this._(status: B07ExerciseContextStatus.queryFailure);

  bool get isAvailable => status == B07ExerciseContextStatus.available;
}

/// Exact canonical stable-ID reader for the B.7 execution context.
///
/// This repository deliberately does not accept a display name, perform a
/// fuzzy lookup, or infer a replacement from muscles/equipment. The player
/// supplies the actual performed UUID, so a successful replacement naturally
/// resolves a different context record.
class B07ExerciseContextRepository {
  final AppDatabase database;

  const B07ExerciseContextRepository(this.database);

  Future<B07ExerciseContextResult> resolve(String canonicalExerciseId) async {
    final id = canonicalExerciseId.trim();
    if (id.isEmpty) return const B07ExerciseContextResult.unavailable();

    try {
      final exercise = await (database.select(
        database.exercises,
      )..where((table) => table.stableId.equals(id))).getSingleOrNull();
      if (exercise == null || exercise.stableId?.trim() != id) {
        return const B07ExerciseContextResult.unavailable();
      }

      return B07ExerciseContextResult.available(
        B07ExerciseContext(
          canonicalExerciseId: id,
          canonicalName: exercise.name.trim(),
          equipment: exercise.equipment.trim(),
          displayMuscles: ExerciseDisplayMuscles.fromMuscleGroups(
            exercise.muscleGroups,
          ),
          formCues: _lines(exercise.formCues),
          commonMistakes: _lines(exercise.commonMistakes),
        ),
      );
    } catch (_) {
      return const B07ExerciseContextResult.queryFailure();
    }
  }

  static List<String> _lines(String raw) => List.unmodifiable(
    raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty),
  );
}
