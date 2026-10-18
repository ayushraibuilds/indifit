import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/exercise_display_muscles.dart';
import '../../core/utils/weekly_training_goal_calculator.dart';
import '../../data/database/app_database.dart' show Exercise;
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_exercise_performance_read_repository.dart';
import '../progress/training_bests.dart';

/// Working sets per muscle for a span of days (TF-4, free).
///
/// Counts only: no recovery, fatigue or readiness meaning. Keys are the
/// exercise catalogue's display muscles in lower case ("chest", "back"),
/// which [IndiFitMuscleMap] already resolves to geometry.
@immutable
class MuscleSetCounts {
  const MuscleSetCounts({
    required this.startLocalDate,
    required this.endLocalDate,
    required this.sets,
    required this.exercises,
  });

  final String startLocalDate;
  final String endLocalDate;

  /// Muscle → working sets (halves allowed). Only muscles with sets.
  final Map<String, double> sets;

  /// Muscle → the exercises that hit it, in the order first logged.
  final Map<String, List<String>> exercises;

  bool get isEmpty => sets.isEmpty;

  /// Most sets first, then by name.
  List<MapEntry<String, double>> get ranked =>
      sets.entries.toList()..sort(
        (a, b) => b.value != a.value
            ? b.value.compareTo(a.value)
            : a.key.compareTo(b.key),
      );
}

/// The one counting rule, printed in the legend.
abstract final class MuscleSetRule {
  static const primarySets = 1.0;
  static const secondarySets = 0.5;

  static const legend =
      'Shaded by working sets this week · primary 1, secondary ½';

  /// A logged working set with reps and no technique. Assisted, tempo,
  /// paused, drop and rest-pause sets are left out, as the bests engine
  /// leaves them out (TP-1).
  static bool counts(B02PerformedSet set, {bool segmented = false}) =>
      set.role == B02SetRole.working &&
      (set.actualReps ?? 0) >= 1 &&
      !TrainingBests.hasTechnique(set, segmented: segmented);

  /// Applies the rule: each counted set adds 1 to the exercise's primary
  /// muscle and ½ to each distinct secondary one. Exercises with no
  /// display muscles add nothing.
  static MuscleSetCounts count({
    required String startLocalDate,
    required String endLocalDate,
    required Iterable<B02ExercisePerformanceRecord> records,
    required Map<String, ExerciseDisplayMuscles> musclesByExercise,
  }) {
    final sets = <String, double>{};
    final exercises = <String, List<String>>{};
    // Oldest first, so exercise names read in the order they were trained.
    final ordered = records.toList()
      ..sort((a, b) {
        final byTime = a.completedAt.compareTo(b.completedAt);
        return byTime != 0
            ? byTime
            : a.exerciseOrdinal.compareTo(b.exerciseOrdinal);
      });
    for (final record in ordered) {
      final muscles = musclesByExercise[record.actualExerciseId];
      if (muscles == null || muscles.isEmpty) continue;
      final counted = record.sets
          .where(
            (set) => counts(
              set,
              segmented: record.segmentedSetIds.contains(set.id),
            ),
          )
          .length;
      if (counted == 0) continue;
      final primary = muscles.hasPrimary ? _key(muscles.primary!) : null;
      final contributions = <String, double>{
        ?primary: primarySets,
        for (final secondary in muscles.secondary)
          if (_key(secondary) != primary) _key(secondary): secondarySets,
      };
      for (final entry in contributions.entries) {
        sets[entry.key] = (sets[entry.key] ?? 0) + entry.value * counted;
        final names = exercises.putIfAbsent(entry.key, () => []);
        if (!names.contains(record.actualExerciseName)) {
          names.add(record.actualExerciseName);
        }
      }
    }
    return MuscleSetCounts(
      startLocalDate: startLocalDate,
      endLocalDate: endLocalDate,
      sets: Map.unmodifiable(sets),
      exercises: Map.unmodifiable({
        for (final entry in exercises.entries)
          entry.key: List<String>.unmodifiable(entry.value),
      }),
    );
  }

  static String _key(String muscle) => muscle.trim().toLowerCase();
}

/// Inclusive civil dates in one timezone.
@immutable
class MuscleSetRange {
  const MuscleSetRange({
    required this.startLocalDate,
    required this.endLocalDate,
    required this.timezoneId,
  });

  final String startLocalDate;
  final String endLocalDate;
  final String timezoneId;

  @override
  bool operator ==(Object other) =>
      other is MuscleSetRange &&
      other.startLocalDate == startLocalDate &&
      other.endLocalDate == endLocalDate &&
      other.timezoneId == timezoneId;

  @override
  int get hashCode => Object.hash(startLocalDate, endLocalDate, timezoneId);
}

/// Muscle → working sets for a date range, from saved workouts. Re-reads
/// whenever performed sets or sessions change, so it fills in live.
final muscleSetsProvider = FutureProvider.autoDispose
    .family<MuscleSetCounts, MuscleSetRange>((ref, range) async {
      final db = ref.watch(databaseProvider);
      final changes = db
          .tableUpdates(
            TableUpdateQuery.onAllTables([
              db.performedSets,
              db.performedExercises,
              db.workoutSessions,
            ]),
          )
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      final dates = ref.watch(localScheduleDateServiceProvider);
      final records = await ref
          .watch(b02ExercisePerformanceReadRepositoryProvider)
          .readCompletedBetween(
            startUtc: dates.instantForLocalDate(
              range.startLocalDate,
              range.timezoneId,
              hour: 0,
            ),
            endExclusiveUtc: dates.instantForLocalDate(
              dates.addCalendarDays(range.endLocalDate, range.timezoneId, 1),
              range.timezoneId,
              hour: 0,
            ),
          );
      final ids = {for (final record in records) record.actualExerciseId};
      final rows = ids.isEmpty
          ? const <Exercise>[]
          : await (db.select(
              db.exercises,
            )..where((table) => table.stableId.isIn(ids))).get();
      return MuscleSetRule.count(
        startLocalDate: range.startLocalDate,
        endLocalDate: range.endLocalDate,
        records: records,
        musclesByExercise: {
          for (final row in rows)
            if (row.stableId != null)
              row.stableId!: ExerciseDisplayMuscles.fromMuscleGroups(
                row.muscleGroups,
              ),
        },
      );
    });

/// This week, Monday to Sunday in the local timezone: the weekly goal's
/// week.
final musclesThisWeekProvider = FutureProvider.autoDispose<MuscleSetCounts>((
  ref,
) async {
  ref.watch(civilDateRevisionProvider);
  final dates = ref.watch(localScheduleDateServiceProvider);
  final timezoneId = await ref
      .watch(localTimezoneServiceProvider)
      .currentTimezoneId();
  final start = WeeklyTrainingGoalCalculator.weekStartOf(
    dates.todayIn(timezoneId),
    dates: dates,
  );
  return ref.watch(
    muscleSetsProvider(
      MuscleSetRange(
        startLocalDate: start,
        endLocalDate: dates.addCalendarDays(start, timezoneId, 6),
        timezoneId: timezoneId,
      ),
    ).future,
  );
});
