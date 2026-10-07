import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/repositories/b02_exercise_performance_read_repository.dart';
import 'training_bests.dart';
import 'training_vs_last_time.dart';

extension TrainingBestsPerformanceRecord on B02ExercisePerformanceRecord {
  TrainingBestsEntry toTrainingBestsEntry() => TrainingBestsEntry(
    sessionId: sessionId,
    completedAt: completedAt,
    actualExerciseId: actualExerciseId,
    actualExerciseName: actualExerciseName,
    exerciseOrdinal: exerciseOrdinal,
    sets: sets,
    segmentedSetIds: segmentedSetIds,
  );
}

/// Reads the bests one saved session set, judged only against the sessions
/// saved before it. Later sessions never change what this session earned.
abstract final class TrainingBestsSessionRead {
  static Future<TrainingBestsResult> read(
    B02ExercisePerformanceReadRepository repository,
    int sessionId,
  ) async {
    final exerciseIds = await repository.readSessionExerciseIds(sessionId);
    final bests = <TrainingBest>[];
    final baselines = <String>{};
    // One read per exercise, matching the exercise-history read.
    for (final exerciseId in exerciseIds) {
      final records = await repository.read(stableExerciseId: exerciseId);
      final current = records
          .where((record) => record.sessionId == sessionId)
          .toList(growable: false);
      if (current.isEmpty) continue;
      final at = current.first.completedAt;
      final earlier = records.where(
        (record) =>
            record.sessionId != sessionId &&
            (record.completedAt.isBefore(at) ||
                (record.completedAt == at && record.sessionId < sessionId)),
      );
      final result = TrainingBests.evaluate(
        history: earlier.map((record) => record.toTrainingBestsEntry()),
        current: current.map((record) => record.toTrainingBestsEntry()),
      );
      bests.addAll(result.bests);
      baselines.addAll(result.baselineExerciseIds);
    }
    return TrainingBestsResult(
      bests: List.unmodifiable(bests),
      baselineExerciseIds: Set.unmodifiable(baselines),
    );
  }
}

/// Bests set by one saved workout (summary, share card, workout details).
final trainingBestsForSessionProvider = FutureProvider.autoDispose
    .family<TrainingBestsResult, int>(
      (ref, sessionId) => TrainingBestsSessionRead.read(
        ref.watch(b02ExercisePerformanceReadRepositoryProvider),
        sessionId,
      ),
    );

/// "Vs last time" for each exercise of one saved session, in workout order,
/// judged only against sessions saved before it (TP-6).
abstract final class TrainingVsLastTimeSessionRead {
  static Future<List<ExerciseVsLastTime>> read(
    B02ExercisePerformanceReadRepository repository,
    int sessionId,
  ) async {
    final exerciseIds = await repository.readSessionExerciseIds(sessionId);
    final lines = <ExerciseVsLastTime>[];
    for (final exerciseId in exerciseIds) {
      final records = await repository.read(stableExerciseId: exerciseId);
      final current = records
          .where((record) => record.sessionId == sessionId)
          .toList(growable: false);
      if (current.isEmpty) continue;
      final at = current.first.completedAt;
      final earlier = records.where(
        (record) =>
            record.sessionId != sessionId &&
            (record.completedAt.isBefore(at) ||
                (record.completedAt == at && record.sessionId < sessionId)),
      );
      final line = TrainingVsLastTime.compare(
        exerciseId: exerciseId,
        exerciseName: current.first.actualExerciseName,
        history: earlier.map((record) => record.toTrainingBestsEntry()),
        current: current.map((record) => record.toTrainingBestsEntry()),
      );
      if (line != null) lines.add(line);
    }
    return List.unmodifiable(lines);
  }
}

/// "Vs last time" lines for one saved workout's summary.
final trainingVsLastTimeForSessionProvider = FutureProvider.autoDispose
    .family<List<ExerciseVsLastTime>, int>(
      (ref, sessionId) => TrainingVsLastTimeSessionRead.read(
        ref.watch(b02ExercisePerformanceReadRepositoryProvider),
        sessionId,
      ),
    );
