import '../../data/models/b02_execution_models.dart';

/// Factual best-ever sets (TP-1).
///
/// A best is derived on read from sets the user logged: the heaviest load, or
/// the most reps at that load or heavier. Nothing is estimated (no e1RM, no
/// formula) and nothing is stored, so editing or deleting a workout simply
/// re-derives the answer. This file has no Flutter or database imports.
enum TrainingBestKind { heaviest, mostReps }

/// One exercise occurrence handed to the engine.
///
/// [sessionId] is null for the workout still in progress.
class TrainingBestsEntry {
  const TrainingBestsEntry({
    required this.sessionId,
    required this.completedAt,
    required this.actualExerciseId,
    required this.sets,
    this.actualExerciseName = '',
    this.exerciseOrdinal = 0,
    this.segmentedSetIds = const {},
  });

  final int? sessionId;
  final DateTime completedAt;
  final String actualExerciseId;
  final String actualExerciseName;
  final int exerciseOrdinal;
  final List<B02PerformedSet> sets;

  /// IDs of [sets] with persisted drop-set or rest-pause segments.
  final Set<String> segmentedSetIds;
}

/// A comparable logged set: what was lifted, how many times and when.
class TrainingBestsSetFact {
  const TrainingBestsSetFact({
    required this.setId,
    required this.exerciseId,
    required this.exerciseName,
    required this.basis,
    required this.loadKg,
    required this.reps,
    required this.performedAt,
  });

  final String setId;
  final String exerciseId;
  final String exerciseName;
  final B02LoadBasis basis;

  /// External load in kg. For bodyweight this is the added load (0 if none).
  final double loadKg;
  final int reps;
  final DateTime performedAt;
}

/// A set that beat every earlier comparable set.
class TrainingBest {
  const TrainingBest({
    required this.kind,
    required this.set,
    required this.previous,
  });

  final TrainingBestKind kind;
  final TrainingBestsSetFact set;

  /// The earlier set it beat: the heaviest one, or the one with the most reps
  /// at that load or heavier.
  final TrainingBestsSetFact previous;

  String get setId => set.setId;
  String get exerciseId => set.exerciseId;
  String get exerciseName => set.exerciseName;
}

class TrainingBestsResult {
  const TrainingBestsResult({
    this.bests = const [],
    this.baselineExerciseIds = const {},
  });

  /// In workout order. At most one per set.
  final List<TrainingBest> bests;

  /// Exercises whose comparable sets in this workout are the first ever for
  /// their load basis. They set the baseline and produce no bests.
  final Set<String> baselineExerciseIds;

  bool get isEmpty => bests.isEmpty;

  Map<String, TrainingBestKind> get kindsBySetId => {
    for (final best in bests) best.setId: best.kind,
  };
}

/// Best-ever facts for one exercise and load basis.
class TrainingBestRecord {
  const TrainingBestRecord({
    required this.basis,
    required this.heaviest,
    required this.mostReps,
  });

  final B02LoadBasis basis;
  final TrainingBestsSetFact heaviest;

  /// Lighter loads where more reps were done than at any heavier load,
  /// heaviest first. Excludes [heaviest].
  final List<TrainingBestsSetFact> mostReps;
}

abstract final class TrainingBests {
  /// Absorbs lb → kg rounding: 135 lb is 61.235 kg.
  static const toleranceKg = 0.1;

  /// Assistance, tempo, paused reps and segments change what a set means.
  static bool hasTechnique(B02PerformedSet set, {bool segmented = false}) {
    final technique = set.technique;
    return segmented ||
        technique.segments.isNotEmpty ||
        technique.isDropSet ||
        technique.isRestPause ||
        technique.assistanceMode != null ||
        technique.assistanceKg != null ||
        technique.pausedRepPosition != null ||
        technique.pausedRepSeconds != null ||
        technique.tempoEccentricSeconds != null ||
        technique.tempoBottomPauseSeconds != null ||
        technique.tempoConcentricSeconds != null ||
        technique.tempoLockoutPauseSeconds != null;
  }

  /// A working set with logged reps, a known load and no technique.
  static bool isComparable(B02PerformedSet set, {bool segmented = false}) {
    if (set.role != B02SetRole.working) return false;
    final reps = set.actualReps;
    if (reps == null || reps < 1) return false;
    final basis = set.actualLoadBasis;
    if (basis == null) return false;
    final load = set.actualLoadKg;
    if (load != null && (!load.isFinite || load < 0)) return false;
    if (basis != B02LoadBasis.bodyweight && load == null) return false;
    return !hasTechnique(set, segmented: segmented);
  }

  /// Bests set by [current] against every set in [history].
  ///
  /// [history] must hold only earlier sessions; its order doesn't matter.
  /// [current] is one workout. Its sets are taken in workout order, so a set
  /// must also beat earlier sets from the same workout.
  static TrainingBestsResult evaluate({
    required Iterable<TrainingBestsEntry> history,
    required Iterable<TrainingBestsEntry> current,
  }) {
    final earlier = <_GroupKey, List<TrainingBestsSetFact>>{};
    for (final fact in history.expand(_facts)) {
      earlier.putIfAbsent(_GroupKey.of(fact), () => []).add(fact);
    }

    final ordered = current.toList(growable: false)
      ..sort((a, b) => a.exerciseOrdinal.compareTo(b.exerciseOrdinal));
    final baselineGroups = <_GroupKey>{};
    final bests = <TrainingBest>[];
    for (final fact in ordered.expand(_facts)) {
      final key = _GroupKey.of(fact);
      final previous = earlier.putIfAbsent(key, () => []);
      if (previous.isEmpty) baselineGroups.add(key);
      if (!baselineGroups.contains(key)) {
        final best = _beat(fact, previous);
        if (best != null) bests.add(best);
      }
      previous.add(fact);
    }
    return TrainingBestsResult(
      bests: List.unmodifiable(bests),
      baselineExerciseIds: Set.unmodifiable(
        baselineGroups.map((key) => key.exerciseId),
      ),
    );
  }

  /// Best-ever facts per load basis, most recently used basis first.
  static List<TrainingBestRecord> bestEver(
    Iterable<TrainingBestsEntry> history, {
    int mostRepsLimit = 3,
  }) {
    final byBasis = <B02LoadBasis, List<TrainingBestsSetFact>>{};
    for (final fact in history.expand(_facts)) {
      byBasis.putIfAbsent(fact.basis, () => []).add(fact);
    }
    final records = <TrainingBestRecord>[];
    for (final MapEntry(key: basis, value: facts) in byBasis.entries) {
      // Heaviest first, then most reps, then the first time it was done.
      final ordered = facts.toList()
        ..sort((a, b) {
          final byLoad = b.loadKg.compareTo(a.loadKg);
          if (byLoad != 0) return byLoad;
          final byReps = b.reps.compareTo(a.reps);
          if (byReps != 0) return byReps;
          return a.performedAt.compareTo(b.performedAt);
        });
      final frontier = <TrainingBestsSetFact>[];
      for (final fact in ordered) {
        if (frontier.isEmpty || fact.reps > frontier.last.reps) {
          frontier.add(fact);
        }
      }
      records.add(
        TrainingBestRecord(
          basis: basis,
          heaviest: frontier.first,
          mostReps: List.unmodifiable(frontier.skip(1).take(mostRepsLimit)),
        ),
      );
    }
    DateTime lastUsed(TrainingBestRecord record) => byBasis[record.basis]!
        .map((fact) => fact.performedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    records.sort((a, b) => lastUsed(b).compareTo(lastUsed(a)));
    return List.unmodifiable(records);
  }

  static TrainingBest? _beat(
    TrainingBestsSetFact fact,
    List<TrainingBestsSetFact> earlier,
  ) {
    TrainingBestsSetFact? heaviest;
    for (final candidate in earlier) {
      if (heaviest == null || _heavier(candidate, heaviest)) {
        heaviest = candidate;
      }
    }
    if (heaviest == null) return null;
    final addsLoad = fact.basis != B02LoadBasis.bodyweight || fact.loadKg > 0;
    if (addsLoad && fact.loadKg > heaviest.loadKg + toleranceKg) {
      return TrainingBest(
        kind: TrainingBestKind.heaviest,
        set: fact,
        previous: heaviest,
      );
    }

    // A reps best needs an earlier set at this same load: doing more reps at
    // a lighter weight than ever before isn't progress.
    TrainingBestsSetFact? mostReps;
    var sameLoadSeen = false;
    for (final candidate in earlier) {
      if (candidate.loadKg < fact.loadKg - toleranceKg) continue;
      if (candidate.loadKg <= fact.loadKg + toleranceKg) sameLoadSeen = true;
      if (mostReps == null ||
          candidate.reps > mostReps.reps ||
          (candidate.reps == mostReps.reps &&
              !candidate.performedAt.isBefore(mostReps.performedAt))) {
        mostReps = candidate;
      }
    }
    if (!sameLoadSeen || mostReps == null || fact.reps <= mostReps.reps) {
      return null;
    }
    return TrainingBest(
      kind: TrainingBestKind.mostReps,
      set: fact,
      previous: mostReps,
    );
  }

  static bool _heavier(TrainingBestsSetFact a, TrainingBestsSetFact b) {
    if (a.loadKg != b.loadKg) return a.loadKg > b.loadKg;
    if (a.reps != b.reps) return a.reps > b.reps;
    return !a.performedAt.isBefore(b.performedAt);
  }

  static Iterable<TrainingBestsSetFact> _facts(TrainingBestsEntry entry) {
    final sets = entry.sets.toList(growable: false)
      ..sort((a, b) => a.ordinal.compareTo(b.ordinal));
    return [
      for (final set in sets)
        if (isComparable(
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
  }
}

/// Plain, factual copy for bests (§ 10): numbers first, no "PR", no estimate.
abstract final class TrainingBestsCopy {
  static const newBest = 'New best';
  static const baseline = 'First time logged. This is your baseline.';

  static String kindLabel(TrainingBestKind kind) => switch (kind) {
    TrainingBestKind.heaviest => 'Heaviest',
    TrainingBestKind.mostReps => 'Most reps',
  };

  /// "New best, heaviest" for screen readers.
  static String semanticsLabel(TrainingBestKind kind) =>
      '$newBest, ${kindLabel(kind).toLowerCase()}';

  /// "62.5 kg × 8 (was 60 kg × 10)" or "10 reps at 60 kg (was 8)".
  static String detail(TrainingBest best) => switch (best.kind) {
    TrainingBestKind.heaviest =>
      '${setLabel(best.set)} (was ${setLabel(best.previous)})',
    TrainingBestKind.mostReps =>
      '${best.set.reps} reps at ${load(best.set)} (was ${best.previous.reps})',
  };

  /// "Heaviest: 62.5 kg × 8 (was 60 kg × 10)".
  static String line(TrainingBest best) => switch (best.kind) {
    TrainingBestKind.heaviest => 'Heaviest: ${detail(best)}',
    TrainingBestKind.mostReps => detail(best),
  };

  /// "62.5 kg × 8".
  static String setLabel(TrainingBestsSetFact fact) {
    final value = load(fact);
    return '${value[0].toUpperCase()}${value.substring(1)} × ${fact.reps}';
  }

  static String load(TrainingBestsSetFact fact) => switch (fact.basis) {
    B02LoadBasis.totalExternal => '${number(fact.loadKg)} kg',
    B02LoadBasis.perImplement => '${number(fact.loadKg)} kg each',
    B02LoadBasis.perSide => '${number(fact.loadKg)} kg per side',
    B02LoadBasis.bodyweight =>
      fact.loadKg > 0 ? 'BW + ${number(fact.loadKg)} kg' : 'bodyweight',
  };

  static String number(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}

class _GroupKey {
  const _GroupKey(this.exerciseId, this.basis);

  factory _GroupKey.of(TrainingBestsSetFact fact) =>
      _GroupKey(fact.exerciseId, fact.basis);

  final String exerciseId;
  final B02LoadBasis basis;

  @override
  bool operator ==(Object other) =>
      other is _GroupKey &&
      other.exerciseId == exerciseId &&
      other.basis == basis;

  @override
  int get hashCode => Object.hash(exerciseId, basis);
}
