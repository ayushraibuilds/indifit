import '../../../data/models/b02_execution_models.dart';
import '../../../data/repositories/b02_execution_compatibility_read_repository.dart';
import '../../../data/repositories/b02_strength_execution_repository.dart';

/// Immutable factual read model for workout completion recap and share card.
///
/// Invariant: Must contain ONLY exact logged facts (sets, reps, weight, duration,
/// completed exercises, volume). Never contains e1RM, inferred PRs, fake calorie
/// estimates, or speculative readiness scores.
class WorkoutCompletionRecap {
  final int? sessionId;
  final String workoutTitle;
  final DateTime completedAt;
  final int durationSeconds;
  final bool isPartial;
  final double totalVolumeKg;
  final int completedSetsCount;
  final int completedExercisesCount;
  final int totalRepsCount;
  final List<ExerciseRecapSummary> exercises;
  final PreviousSessionComparison? previousComparison;

  const WorkoutCompletionRecap({
    this.sessionId,
    required this.workoutTitle,
    required this.completedAt,
    required this.durationSeconds,
    required this.isPartial,
    required this.totalVolumeKg,
    required this.completedSetsCount,
    required this.completedExercisesCount,
    required this.totalRepsCount,
    required this.exercises,
    this.previousComparison,
  });

  bool get isFirstSession => previousComparison == null;

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Factory from persisted canonical history detail.
  factory WorkoutCompletionRecap.fromHistory(
    B02StrengthHistoryDetail history, {
    B02StrengthHistoryDetail? previousHistory,
  }) {
    var setsCount = 0;
    var repsCount = 0;
    final exerciseSummaries = <ExerciseRecapSummary>[];

    for (final exercise in history.exercises) {
      final validSets = exercise.sets
          .where((s) => s.role == B02SetRole.working || s.role == B02SetRole.warmup)
          .toList();
      if (validSets.isEmpty) continue;

      setsCount += validSets.length;
      var topWeight = 0.0;
      var minReps = 999999;
      var maxReps = 0;

      for (final s in validSets) {
        final load = s.actualLoadKg ?? 0.0;
        if (load > topWeight) topWeight = load;
        final reps = s.actualReps ?? 0;
        repsCount += reps;
        if (reps < minReps) minReps = reps;
        if (reps > maxReps) maxReps = reps;
      }

      final name = exercise.actualExerciseNameSnapshot.isNotEmpty
          ? exercise.actualExerciseNameSnapshot
          : (exercise.expectedExerciseNameSnapshot ?? 'Exercise');

      exerciseSummaries.add(
        ExerciseRecapSummary(
          exerciseName: name,
          setsCount: validSets.length,
          topWeightKg: topWeight,
          minReps: minReps == 999999 ? 0 : minReps,
          maxReps: maxReps,
        ),
      );
    }

    PreviousSessionComparison? comparison;
    if (previousHistory != null) {
      final prevSetsCount = previousHistory.exercises.fold<int>(
        0,
        (sum, e) => sum + e.sets.length,
      );
      comparison = PreviousSessionComparison(
        volumeDeltaKg: history.totalVolumeKg - previousHistory.totalVolumeKg,
        setsDelta: setsCount - prevSetsCount,
        previousCompletedAt: previousHistory.completedAt,
      );
    }

    return WorkoutCompletionRecap(
      sessionId: history.sessionId,
      workoutTitle: history.name,
      completedAt: history.completedAt,
      durationSeconds: history.durationSeconds,
      isPartial: history.isPartial,
      totalVolumeKg: history.totalVolumeKg,
      completedSetsCount: setsCount,
      completedExercisesCount: exerciseSummaries.length,
      totalRepsCount: repsCount,
      exercises: exerciseSummaries,
      previousComparison: comparison,
    );
  }

  /// Factory fallback from in-memory execution launch draft.
  factory WorkoutCompletionRecap.fromLaunch(B02StrengthExecutionLaunch launch) {
    var setsCount = 0;
    var repsCount = 0;
    var volume = 0.0;
    final exerciseSummaries = <ExerciseRecapSummary>[];

    for (final exercise in launch.state.performedExercises) {
      final validSets = exercise.sets;
      if (validSets.isEmpty) continue;

      setsCount += validSets.length;
      var topWeight = 0.0;
      var minReps = 999999;
      var maxReps = 0;

      for (final s in validSets) {
        final load = s.actualLoadKg ?? 0.0;
        if (load > topWeight) topWeight = load;
        final reps = s.actualReps ?? 0;
        repsCount += reps;
        if (reps < minReps) minReps = reps;
        if (reps > maxReps) maxReps = reps;
        if (s.role == B02SetRole.working && s.actualLoadKg != null && s.actualReps != null) {
          volume += s.actualLoadKg! * s.actualReps!;
        }
      }

      final name = exercise.actualExerciseNameSnapshot.isNotEmpty
          ? exercise.actualExerciseNameSnapshot
          : (exercise.expectedExerciseNameSnapshot ?? 'Exercise');

      exerciseSummaries.add(
        ExerciseRecapSummary(
          exerciseName: name,
          setsCount: validSets.length,
          topWeightKg: topWeight,
          minReps: minReps == 999999 ? 0 : minReps,
          maxReps: maxReps,
        ),
      );
    }

    return WorkoutCompletionRecap(
      sessionId: null,
      workoutTitle: launch.state.routineName,
      completedAt: DateTime.now().toUtc(),
      durationSeconds: launch.state.elapsedSeconds,
      isPartial: false,
      totalVolumeKg: volume,
      completedSetsCount: setsCount,
      completedExercisesCount: exerciseSummaries.length,
      totalRepsCount: repsCount,
      exercises: exerciseSummaries,
      previousComparison: null,
    );
  }

  /// Generate factual text format suitable for system sharing.
  String generateShareText({bool includeWeights = true}) {
    final buffer = StringBuffer();
    buffer.writeln('IndiFit Workout: $workoutTitle');
    buffer.writeln('Duration: $formattedDuration');
    buffer.writeln(
      'Exercises: $completedExercisesCount | Sets: $completedSetsCount | Reps: $totalRepsCount',
    );
    if (includeWeights && totalVolumeKg > 0) {
      buffer.writeln('Total Volume: ${totalVolumeKg.toStringAsFixed(1)} kg');
    }
    if (previousComparison case final prev?) {
      final sign = prev.volumeDeltaKg >= 0 ? '+' : '';
      if (includeWeights) {
        buffer.writeln(
          'Comparison: $sign${prev.volumeDeltaKg.toStringAsFixed(1)} kg vs previous session',
        );
      }
    } else {
      buffer.writeln('Milestone: First time logging this routine!');
    }
    buffer.writeln();
    for (final ex in exercises) {
      final repsStr = ex.minReps == ex.maxReps
          ? '${ex.minReps} reps'
          : '${ex.minReps}-${ex.maxReps} reps';
      if (includeWeights && ex.topWeightKg > 0) {
        buffer.writeln(
          '• ${ex.exerciseName}: ${ex.setsCount} sets × $repsStr (top: ${ex.topWeightKg.toStringAsFixed(1)} kg)',
        );
      } else {
        buffer.writeln('• ${ex.exerciseName}: ${ex.setsCount} sets × $repsStr');
      }
    }
    return buffer.toString().trim();
  }
}

class ExerciseRecapSummary {
  final String exerciseName;
  final int setsCount;
  final double topWeightKg;
  final int minReps;
  final int maxReps;

  const ExerciseRecapSummary({
    required this.exerciseName,
    required this.setsCount,
    required this.topWeightKg,
    required this.minReps,
    required this.maxReps,
  });
}

class PreviousSessionComparison {
  final double volumeDeltaKg;
  final int setsDelta;
  final DateTime previousCompletedAt;

  const PreviousSessionComparison({
    required this.volumeDeltaKg,
    required this.setsDelta,
    required this.previousCompletedAt,
  });
}
