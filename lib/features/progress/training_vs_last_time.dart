import '../../data/models/b02_execution_models.dart';
import 'training_bests.dart';

/// How one exercise's top set compares with the last time it was done.
enum VsLastTimeKind { up, same, down, firstTime }

/// One "vs last time" line on the workout summary (TP-6).
///
/// The top set is the heaviest comparable set (most reps breaks a tie), as
/// defined by [TrainingBests.isComparable]. "Last time" is the most recent
/// earlier session with a comparable set on the same load basis.
class ExerciseVsLastTime {
  const ExerciseVsLastTime({
    required this.exerciseId,
    required this.exerciseName,
    required this.kind,
    this.current,
    this.previous,
  });

  final String exerciseId;
  final String exerciseName;
  final VsLastTimeKind kind;

  /// Today's top set. Null only for [VsLastTimeKind.firstTime] when nothing
  /// comparable was logged.
  final TrainingBestsSetFact? current;

  /// Last time's top set. Null for [VsLastTimeKind.firstTime].
  final TrainingBestsSetFact? previous;

  /// Load difference in kg, rounded inside [TrainingBests.toleranceKg] to 0.
  double get loadDeltaKg {
    final now = current;
    final before = previous;
    if (now == null || before == null) return 0;
    final delta = now.loadKg - before.loadKg;
    return delta.abs() <= TrainingBests.toleranceKg ? 0 : delta;
  }

  int get repsDelta {
    final now = current;
    final before = previous;
    if (now == null || before == null) return 0;
    return now.reps - before.reps;
  }
}

abstract final class TrainingVsLastTime {
  /// Compares [current] (one workout's occurrences of one exercise) with
  /// [history] (that exercise's earlier sessions, any order).
  ///
  /// Returns null when there is nothing honest to say: no comparable set
  /// today, or earlier sessions exist but none has a comparable set on
  /// today's load basis.
  static ExerciseVsLastTime? compare({
    required String exerciseId,
    required String exerciseName,
    required Iterable<TrainingBestsEntry> history,
    required Iterable<TrainingBestsEntry> current,
  }) {
    final earlier = history.toList(growable: false);
    if (earlier.isEmpty) {
      return ExerciseVsLastTime(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        kind: VsLastTimeKind.firstTime,
        current: _topSet(_facts(current)),
      );
    }
    final today = _topSet(_facts(current));
    if (today == null) return null;

    // The most recent earlier session with a comparable set on this basis.
    final bySession = <int, List<TrainingBestsEntry>>{};
    for (final entry in earlier) {
      final id = entry.sessionId;
      if (id == null) continue;
      bySession.putIfAbsent(id, () => []).add(entry);
    }
    final sessions = bySession.entries.toList()
      ..sort((a, b) {
        final byTime = b.value.first.completedAt.compareTo(
          a.value.first.completedAt,
        );
        return byTime != 0 ? byTime : b.key.compareTo(a.key);
      });
    TrainingBestsSetFact? before;
    for (final session in sessions) {
      before = _topSet(
        _facts(session.value).where((fact) => fact.basis == today.basis),
      );
      if (before != null) break;
    }
    if (before == null) return null;

    final loadDelta = today.loadKg - before.loadKg;
    final repsDelta = today.reps - before.reps;
    final kind = loadDelta > TrainingBests.toleranceKg
        ? VsLastTimeKind.up
        : loadDelta < -TrainingBests.toleranceKg
        ? VsLastTimeKind.down
        : repsDelta > 0
        ? VsLastTimeKind.up
        : repsDelta < 0
        ? VsLastTimeKind.down
        : VsLastTimeKind.same;
    return ExerciseVsLastTime(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      kind: kind,
      current: today,
      previous: before,
    );
  }

  static List<TrainingBestsSetFact> _facts(
    Iterable<TrainingBestsEntry> entries,
  ) => [
    for (final entry in entries)
      for (final set in entry.sets)
        if (TrainingBests.isComparable(
          set,
          segmented: entry.segmentedSetIds.contains(set.id),
        ))
          TrainingBestsSetFact(
            setId: set.id,
            exerciseId: entry.actualExerciseId,
            exerciseName: entry.actualExerciseName,
            basis: set.actualLoadBasis!,
            loadKg: set.actualLoadKg ?? 0,
            reps: set.actualReps!,
            performedAt: entry.completedAt,
          ),
  ];

  /// Heaviest, then most reps. Bodyweight without added load compares by
  /// reps alone, since its load is 0.
  static TrainingBestsSetFact? _topSet(Iterable<TrainingBestsSetFact> facts) {
    TrainingBestsSetFact? top;
    for (final fact in facts) {
      if (top == null ||
          fact.loadKg > top.loadKg + TrainingBests.toleranceKg ||
          ((fact.loadKg - top.loadKg).abs() <= TrainingBests.toleranceKg &&
              fact.reps > top.reps)) {
        top = fact;
      }
    }
    return top;
  }
}

/// Plain, factual copy (§ 10): numbers first, no "PR", nothing estimated.
abstract final class TrainingVsLastTimeCopy {
  static const title = 'Vs last time';

  /// "+2.5 kg on top set", "+2 reps on top set", "same as last time" or
  /// "first time logged".
  static String change(ExerciseVsLastTime line) {
    switch (line.kind) {
      case VsLastTimeKind.firstTime:
        return 'first time logged';
      case VsLastTimeKind.same:
        return 'same as last time';
      case VsLastTimeKind.up:
      case VsLastTimeKind.down:
        final load = line.loadDeltaKg;
        if (load != 0) {
          return '${_signed(load, TrainingBestsCopy.number(load.abs()))} kg'
              '${_basisSuffix(line.current!.basis)} on top set';
        }
        final reps = line.repsDelta;
        final unit = reps.abs() == 1 ? 'rep' : 'reps';
        return '${_signed(reps.toDouble(), '${reps.abs()}')} $unit on top set';
    }
  }

  /// "Leg press: +2.5 kg on top set".
  static String line(ExerciseVsLastTime line) =>
      '${line.exerciseName}: ${change(line)}';

  /// "62.5 kg × 8 (was 60 kg × 8)", for screen readers and detail.
  static String? detail(ExerciseVsLastTime line) {
    final now = line.current;
    final before = line.previous;
    if (now == null) return null;
    if (before == null) return TrainingBestsCopy.setLabel(now);
    return '${TrainingBestsCopy.setLabel(now)} '
        '(was ${TrainingBestsCopy.setLabel(before)})';
  }

  static String _signed(double value, String magnitude) =>
      value > 0 ? '+$magnitude' : '-$magnitude';

  static String _basisSuffix(B02LoadBasis basis) => switch (basis) {
    B02LoadBasis.perImplement => ' each',
    B02LoadBasis.perSide => ' per side',
    B02LoadBasis.totalExternal || B02LoadBasis.bodyweight => '',
  };
}
