import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_exercise_performance_read_repository.dart';

/// Presentation-only facts for R08F.3.
///
/// The input is the exact B02 exercise-performance read. These helpers select
/// and describe persisted sets; they do not estimate strength, classify a PR,
/// compare exercise families, or fill missing values with zero.
abstract final class R08F3StrengthPerformancePresentation {
  static R08F3StrengthPerformanceSummary summarize(
    List<B02ExercisePerformanceRecord> records,
  ) {
    final ordered = records.toList(growable: true)
      ..sort(_compareRecordsChronologically);
    if (ordered.isEmpty) {
      return const R08F3StrengthPerformanceSummary.empty();
    }

    final latestRecord = ordered.last;
    final latestSet = _latestRecordedSet(latestRecord);
    final latestComparable = _latestComparableSet(latestRecord);
    final trendBasis = latestComparable?.actualLoadBasis;
    B02PerformedSet? heaviestRecordedSet;
    final points = <R08F3StrengthTrendPoint>[];
    if (trendBasis != null) {
      for (final record in ordered) {
        final set = _heaviestWorkingSet(record, trendBasis);
        if (set == null || set.actualLoadKg == null) continue;
        heaviestRecordedSet = heaviestRecordedSet == null
            ? set
            : _heavierRecordedSet(heaviestRecordedSet, set);
        points.add(
          R08F3StrengthTrendPoint(
            sessionId: record.sessionId,
            performedExerciseId: record.performedExerciseId,
            completedAt: record.completedAt,
            loadKg: set.actualLoadKg!,
            reps: set.actualReps,
            basis: trendBasis,
            isPartial: record.isPartial,
          ),
        );
      }
    }

    final hasIncompleteTrend =
        ordered.length > 1 &&
        (trendBasis == null || points.length != ordered.length);
    final hasMultipleOccurrencesPerSession = ordered
        .map((record) => record.sessionId)
        .toSet()
        .any(
          (sessionId) =>
              ordered.where((record) => record.sessionId == sessionId).length >
              1,
        );
    final comparisonText = latestComparable == null
        ? null
        : _compareWithPrevious(
            records: ordered,
            currentRecord: latestRecord,
            current: latestComparable,
          );

    return R08F3StrengthPerformanceSummary(
      sessionCount: ordered.map((record) => record.sessionId).toSet().length,
      occurrenceCount: ordered.length,
      latestRecord: latestRecord,
      latestRecordedSet: latestSet,
      heaviestRecordedSet: heaviestRecordedSet,
      comparisonText: comparisonText,
      trendBasis: trendBasis,
      trendPoints: List.unmodifiable(points),
      hasIncompleteTrend: hasIncompleteTrend,
      hasMultipleOccurrencesPerSession: hasMultipleOccurrencesPerSession,
      partialSessionCount: ordered
          .where((record) => record.isPartial)
          .map((record) => record.sessionId)
          .toSet()
          .length,
    );
  }

  static String formatActualSet(B02PerformedSet set) {
    final load = _formatLoad(set.actualLoadKg, set.actualLoadBasis);
    final reps = set.actualReps;
    final main = switch ((load.isEmpty, reps)) {
      (true, null) =>
        set.actualLoadBasis == null
            ? 'Details unavailable'
            : 'Recorded load basis: ${formatLoadBasis(set.actualLoadBasis!)}',
      (true, final value) => '$value ${value == 1 ? 'rep' : 'reps'}',
      (false, null) => load,
      (false, final value) => '$load × $value',
    };
    return [
      'Set ${set.ordinal + 1}',
      if (set.role == B02SetRole.warmup) 'Warm-up',
      main,
      if (set.actualRpe != null) 'RPE ${set.actualRpe}',
    ].join(' · ');
  }

  static String formatActualFact(B02PerformedSet set) =>
      formatActualSet(set).replaceFirst(RegExp(r'^Set \d+ · '), '');

  static String formatLoadBasis(B02LoadBasis basis) => switch (basis) {
    B02LoadBasis.totalExternal => 'total load',
    B02LoadBasis.perImplement => 'per implement',
    B02LoadBasis.perSide => 'per side',
    B02LoadBasis.bodyweight => 'bodyweight',
  };

  static String formatTrendLoad(R08F3StrengthTrendPoint point) {
    final load = _formatLoad(point.loadKg, point.basis);
    return [
      load,
      if (point.reps != null)
        '${point.reps} ${point.reps == 1 ? 'rep' : 'reps'}',
    ].join(' × ');
  }

  static B02PerformedSet? _latestRecordedSet(
    B02ExercisePerformanceRecord record,
  ) {
    final sets = record.sets.where(_hasActualFact).toList(growable: true)
      ..sort((first, second) => first.ordinal.compareTo(second.ordinal));
    return sets.isEmpty ? null : sets.last;
  }

  static B02PerformedSet? _latestComparableSet(
    B02ExercisePerformanceRecord record,
  ) {
    final sets =
        record.sets
            .where(
              (set) =>
                  set.role == B02SetRole.working &&
                  set.actualLoadKg != null &&
                  set.actualLoadBasis != null &&
                  set.actualLoadBasis != B02LoadBasis.bodyweight,
            )
            .toList(growable: true)
          ..sort((first, second) => first.ordinal.compareTo(second.ordinal));
    return sets.isEmpty ? null : sets.last;
  }

  static B02PerformedSet? _heaviestWorkingSet(
    B02ExercisePerformanceRecord record,
    B02LoadBasis basis, {
    int? reps,
  }) {
    final sets = record.sets
        .where(
          (set) =>
              set.role == B02SetRole.working &&
              set.actualLoadKg != null &&
              set.actualLoadBasis == basis &&
              (reps == null || set.actualReps == reps),
        )
        .toList(growable: false);
    if (sets.isEmpty) return null;
    return sets.reduce((first, second) {
      return _heavierRecordedSet(first, second);
    });
  }

  static B02PerformedSet _heavierRecordedSet(
    B02PerformedSet first,
    B02PerformedSet second,
  ) {
    if (first.actualLoadKg != second.actualLoadKg) {
      return first.actualLoadKg! > second.actualLoadKg! ? first : second;
    }
    final firstReps = first.actualReps ?? -1;
    final secondReps = second.actualReps ?? -1;
    if (firstReps != secondReps) {
      return firstReps > secondReps ? first : second;
    }
    return first.ordinal >= second.ordinal ? first : second;
  }

  static String? _compareWithPrevious({
    required List<B02ExercisePerformanceRecord> records,
    required B02ExercisePerformanceRecord currentRecord,
    required B02PerformedSet current,
  }) {
    final currentLoad = current.actualLoadKg;
    final currentBasis = current.actualLoadBasis;
    final currentReps = current.actualReps;
    if (currentLoad == null ||
        currentBasis == null ||
        currentBasis == B02LoadBasis.bodyweight ||
        currentReps == null) {
      return null;
    }

    B02PerformedSet? previous;
    for (final record in records.reversed) {
      if (record.sessionId == currentRecord.sessionId) continue;
      final candidate = _heaviestWorkingSet(
        record,
        currentBasis,
        reps: currentReps,
      );
      if (candidate != null) {
        previous = candidate;
        break;
      }
    }
    if (previous?.actualLoadKg == null) return null;
    final difference = currentLoad - previous!.actualLoadKg!;
    if (difference == 0) {
      return 'Same recorded load at $currentReps reps as the previous session';
    }
    final sign = difference > 0 ? '+' : '';
    return '$sign${_formatNumber(difference)} ${formatLoadUnit(currentBasis)} at $currentReps reps vs previous session';
  }

  static String formatLoadUnit(B02LoadBasis basis) => switch (basis) {
    B02LoadBasis.totalExternal => 'kg',
    B02LoadBasis.perImplement => 'kg per implement',
    B02LoadBasis.perSide => 'kg per side',
    B02LoadBasis.bodyweight => 'bodyweight',
  };

  static bool _hasActualFact(B02PerformedSet set) =>
      set.actualLoadKg != null ||
      set.actualLoadBasis != null ||
      set.actualReps != null ||
      set.actualRpe != null;

  static String _formatLoad(double? loadKg, B02LoadBasis? basis) {
    if (basis == B02LoadBasis.bodyweight) return 'Bodyweight';
    if (loadKg == null) return '';
    if (basis == null) {
      return 'Load ${_formatNumber(loadKg)} (unit not recorded)';
    }
    return switch (basis) {
      B02LoadBasis.totalExternal => '${_formatNumber(loadKg)} kg',
      B02LoadBasis.perImplement => '${_formatNumber(loadKg)} kg per implement',
      B02LoadBasis.perSide => '${_formatNumber(loadKg)} kg per side',
      B02LoadBasis.bodyweight => 'Bodyweight',
    };
  }

  static int _compareRecordsChronologically(
    B02ExercisePerformanceRecord first,
    B02ExercisePerformanceRecord second,
  ) {
    final byTime = first.completedAt.compareTo(second.completedAt);
    if (byTime != 0) return byTime;
    final bySession = first.sessionId.compareTo(second.sessionId);
    if (bySession != 0) return bySession;
    final byOrdinal = first.exerciseOrdinal.compareTo(second.exerciseOrdinal);
    if (byOrdinal != 0) return byOrdinal;
    return first.performedExerciseId.compareTo(second.performedExerciseId);
  }

  static String _formatNumber(double value) {
    if (value.roundToDouble() == value) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}

class R08F3StrengthPerformanceSummary {
  const R08F3StrengthPerformanceSummary({
    required this.sessionCount,
    required this.occurrenceCount,
    required this.latestRecord,
    required this.latestRecordedSet,
    required this.heaviestRecordedSet,
    required this.comparisonText,
    required this.trendBasis,
    required this.trendPoints,
    required this.hasIncompleteTrend,
    required this.hasMultipleOccurrencesPerSession,
    required this.partialSessionCount,
  });

  const R08F3StrengthPerformanceSummary.empty()
    : sessionCount = 0,
      occurrenceCount = 0,
      latestRecord = null,
      latestRecordedSet = null,
      heaviestRecordedSet = null,
      comparisonText = null,
      trendBasis = null,
      trendPoints = const [],
      hasIncompleteTrend = false,
      hasMultipleOccurrencesPerSession = false,
      partialSessionCount = 0;

  final int sessionCount;
  final int occurrenceCount;
  final B02ExercisePerformanceRecord? latestRecord;
  final B02PerformedSet? latestRecordedSet;
  final B02PerformedSet? heaviestRecordedSet;
  final String? comparisonText;
  final B02LoadBasis? trendBasis;
  final List<R08F3StrengthTrendPoint> trendPoints;
  final bool hasIncompleteTrend;
  final bool hasMultipleOccurrencesPerSession;
  final int partialSessionCount;

  bool get canShowTrend =>
      trendBasis != null &&
      trendPoints.length >= 2 &&
      !hasIncompleteTrend &&
      !hasMultipleOccurrencesPerSession;
}

class R08F3StrengthTrendPoint {
  const R08F3StrengthTrendPoint({
    required this.sessionId,
    required this.performedExerciseId,
    required this.completedAt,
    required this.loadKg,
    required this.reps,
    required this.basis,
    required this.isPartial,
  });

  final int sessionId;
  final String performedExerciseId;
  final DateTime completedAt;
  final double loadKg;
  final int? reps;
  final B02LoadBasis basis;
  final bool isPartial;
}
