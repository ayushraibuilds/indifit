import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/di/providers.dart';
import '../../core/fixtures/exercise_display_muscles.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/utils/weekly_training_goal_calculator.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_exercise_performance_read_repository.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../dashboard/widgets/today_header_widgets.dart';
import '../media/indifit_muscle_map.dart';
import '../progress/training_bests.dart';
import 'muscles_this_week.dart';

/// How far back the strip pages: the first week with a workout, or this
/// many weeks before this one, whichever is nearer.
const int trainingWeekStripMaxWeeksBack = 12;

/// The taxonomy groups for strip labels: display muscle → group.
const Map<String, String> trainingMuscleGroups = {
  'chest': 'Push',
  'shoulders': 'Push',
  'triceps': 'Push',
  'back': 'Pull',
  'biceps': 'Pull',
  'legs': 'Legs',
  'hamstrings': 'Legs',
  'glutes': 'Legs',
  'calves': 'Legs',
  'core': 'Core',
};

/// "Legs · Push": the day's top one or two groups by working sets.
String? trainingMuscleGroupLabel(Map<String, double> sets) {
  final groups = <String, double>{};
  for (final entry in sets.entries) {
    final group = trainingMuscleGroups[entry.key];
    if (group == null) continue;
    groups[group] = (groups[group] ?? 0) + entry.value;
  }
  if (groups.isEmpty) return null;
  final ranked = groups.entries.toList()
    ..sort(
      (a, b) => b.value != a.value
          ? b.value.compareTo(a.value)
          : a.key.compareTo(b.key),
    );
  return ranked.take(2).map((entry) => entry.key).join(' · ');
}

/// One saved workout on a day of the strip.
@immutable
class TrainingDayWorkout {
  const TrainingDayWorkout({
    required this.sessionId,
    required this.name,
    required this.sets,
    required this.topSet,
  });

  final int sessionId;
  final String name;

  /// Working sets counted by [MuscleSetRule.counts].
  final int sets;

  /// "Back Squat · 100 kg × 5": the heaviest comparable set, if any.
  final String? topSet;
}

/// One day of the strip: sets done against sets planned, and its workouts.
@immutable
class TrainingStripDay {
  const TrainingStripDay({
    required this.localDate,
    this.plannedSets = 0,
    this.doneSets = 0,
    this.workouts = const [],
    this.scheduledStatus,
  });

  final String localDate;
  final int plannedSets;
  final int doneSets;
  final List<TrainingDayWorkout> workouts;

  /// The plan's word for the day ("scheduled", "skipped"), if it has one.
  final String? scheduledStatus;

  bool get trained => workouts.isNotEmpty;

  /// Done against planned, capped at a full ring; null with no plan.
  double? get progress =>
      plannedSets > 0 ? (doneSets / plannedSets).clamp(0.0, 1.0) : null;

  /// Trained with nothing planned: a tick instead of a ring.
  bool get doneMark => plannedSets == 0 && trained;
}

@immutable
class TrainingWeekQuery {
  const TrainingWeekQuery(this.weekStartLocalDate, this.timezoneId);

  final String weekStartLocalDate;
  final String timezoneId;

  @override
  bool operator ==(Object other) =>
      other is TrainingWeekQuery &&
      other.weekStartLocalDate == weekStartLocalDate &&
      other.timezoneId == timezoneId;

  @override
  int get hashCode => Object.hash(weekStartLocalDate, timezoneId);
}

/// Seven days from Monday: planned sets from the plan's prescriptions and
/// done sets from saved workouts. Re-reads when a workout is saved.
final trainingStripWeekProvider = FutureProvider.autoDispose
    .family<List<TrainingStripDay>, TrainingWeekQuery>((ref, query) async {
      final db = ref.watch(databaseProvider);
      final changes = db
          .tableUpdates(
            TableUpdateQuery.onAllTables([
              db.performedSets,
              db.workoutSessions,
            ]),
          )
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      final dates = ref.watch(localScheduleDateServiceProvider);
      final tz = query.timezoneId;
      final start = query.weekStartLocalDate;
      final days = [
        for (var i = 0; i < 7; i++) dates.addCalendarDays(start, tz, i),
      ];
      final records = await ref
          .watch(b02ExercisePerformanceReadRepositoryProvider)
          .readCompletedBetween(
            startUtc: dates.instantForLocalDate(start, tz, hour: 0),
            endExclusiveUtc: dates.instantForLocalDate(
              dates.addCalendarDays(start, tz, 7),
              tz,
              hour: 0,
            ),
          );
      final plan = await ref
          .watch(calendarReadRepositoryProvider)
          .readSnapshot(
            startLocalDate: days.first,
            endLocalDate: days.last,
            timezoneId: tz,
          );
      return [
        for (final day in days)
          _stripDay(
            day,
            records.where(
              (record) => dates.localDateFor(record.completedAt, tz) == day,
            ),
            plan.rangeOccurrences.where(
              (item) =>
                  item.occurrence.effectiveLocalDate == day &&
                  item.occurrence.status != 'cancelled',
            ),
          ),
      ];
    });

TrainingStripDay _stripDay(
  String localDate,
  Iterable<B02ExercisePerformanceRecord> records,
  Iterable<CalendarOccurrenceReadItem> occurrences,
) {
  final bySession = <int, List<B02ExercisePerformanceRecord>>{};
  for (final record in records) {
    bySession.putIfAbsent(record.sessionId, () => []).add(record);
  }
  final workouts = <TrainingDayWorkout>[];
  var done = 0;
  final sessions = bySession.entries.toList()
    ..sort(
      (a, b) => a.value.first.completedAt.compareTo(b.value.first.completedAt),
    );
  for (final entry in sessions) {
    var sets = 0;
    B02PerformedSet? top;
    String? topExercise;
    for (final record in entry.value) {
      for (final set in record.sets) {
        final segmented = record.segmentedSetIds.contains(set.id);
        if (MuscleSetRule.counts(set, segmented: segmented)) sets++;
        if (!TrainingBests.isComparable(set, segmented: segmented)) continue;
        final load = set.actualLoadKg ?? 0;
        final topLoad = top?.actualLoadKg ?? 0;
        if (top == null ||
            load > topLoad ||
            (load == topLoad && set.actualReps! > top.actualReps!)) {
          top = set;
          topExercise = record.actualExerciseName;
        }
      }
    }
    done += sets;
    workouts.add(
      TrainingDayWorkout(
        sessionId: entry.key,
        name: entry.value.first.sessionName,
        sets: sets,
        topSet: top == null ? null : '$topExercise · ${_setLabel(top)}',
      ),
    );
  }
  final planned = occurrences.toList();
  return TrainingStripDay(
    localDate: localDate,
    plannedSets: planned.fold<int>(
      0,
      (sum, item) =>
          sum +
          item.prescriptions.fold<int>(
            0,
            (inner, prescription) => inner + prescription.plannedSets,
          ),
    ),
    doneSets: done,
    workouts: List.unmodifiable(workouts),
    scheduledStatus: planned.isEmpty ? null : planned.first.occurrence.status,
  );
}

/// "100 kg × 5", as the bests read.
String _setLabel(B02PerformedSet set) => TrainingBestsCopy.setLabel(
  TrainingBestsSetFact(
    setId: set.id,
    exerciseId: '',
    exerciseName: '',
    basis: set.actualLoadBasis!,
    loadKg: set.actualLoadKg ?? 0,
    reps: set.actualReps!,
    performedAt: DateTime.utc(2000),
  ),
);

/// The Monday of the first week with a saved workout, or null with none.
final trainingFirstWeekProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, timezoneId) async {
      final db = ref.watch(databaseProvider);
      final changes = db
          .tableUpdates(TableUpdateQuery.onAllTables([db.workoutSessions]))
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      final first = db.workoutSessions.completedAt.min();
      final value =
          await (db.selectOnly(db.workoutSessions)
                ..addColumns([first])
                ..where(db.workoutSessions.completedAt.isNotNull()))
              .map((row) => row.read(first))
              .getSingleOrNull();
      if (value == null) return null;
      final dates = ref.watch(localScheduleDateServiceProvider);
      return WeeklyTrainingGoalCalculator.weekStartOf(
        dates.localDateFor(value.toUtc(), timezoneId),
        dates: dates,
      );
    });

/// How many weeks before [currentWeekStart] the strip may page back to.
int trainingWeekStripWeeksBack({
  required String currentWeekStart,
  required String? firstWeekStart,
}) {
  if (firstWeekStart == null) return 0;
  final current = DateTime.parse('${currentWeekStart}T12:00:00Z');
  final first = DateTime.parse('${firstWeekStart}T12:00:00Z');
  final weeks = current.difference(first).inDays ~/ 7;
  return weeks.clamp(0, trainingWeekStripMaxWeeksBack);
}

/// Training's week strip (TF-3, UR-26): the same day cell as Today's strip,
/// a ring per day for sets done against planned, and the day's muscle
/// groups. Swipe back through past weeks; tap a day for its workouts.
class TrainingWeekStrip extends ConsumerStatefulWidget {
  const TrainingWeekStrip({
    super.key,
    required this.currentWeekStartLocalDate,
    required this.localDate,
    required this.timezoneId,
  });

  final String currentWeekStartLocalDate;
  final String localDate;
  final String timezoneId;

  @override
  ConsumerState<TrainingWeekStrip> createState() => _TrainingWeekStripState();
}

class _TrainingWeekStripState extends ConsumerState<TrainingWeekStrip> {
  /// 0 is this week; 1 is last week, and so on.
  int _weeksBack = 0;

  void _page(int delta, int limit) {
    final next = (_weeksBack + delta).clamp(0, limit);
    if (next != _weeksBack) setState(() => _weeksBack = next);
  }

  @override
  Widget build(BuildContext context) {
    final dates = ref.watch(localScheduleDateServiceProvider);
    final tz = widget.timezoneId;
    final limit = trainingWeekStripWeeksBack(
      currentWeekStart: widget.currentWeekStartLocalDate,
      firstWeekStart: ref.watch(trainingFirstWeekProvider(tz)).valueOrNull,
    );
    final weeksBack = _weeksBack.clamp(0, limit);
    final weekStart = dates.addCalendarDays(
      widget.currentWeekStartLocalDate,
      tz,
      -7 * weeksBack,
    );
    final days = ref
        .watch(trainingStripWeekProvider(TrainingWeekQuery(weekStart, tz)))
        .valueOrNull;
    final start = DateTime.parse('${weekStart}T12:00:00Z');
    final today = DateTime.parse('${widget.localDate}T12:00:00Z');
    final end = start.add(const Duration(days: 6));
    // The section above already says "This week".
    final title =
        '${DateFormat('d MMM').format(start)} – '
        '${DateFormat('d MMM').format(end)}';
    return B05Surface(
      key: const ValueKey('training-week-strip'),
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space8,
        B05Layout.space4,
        B05Layout.space8,
        B05Layout.space12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('training-week-older'),
                tooltip: 'Earlier week',
                onPressed: weeksBack < limit ? () => _page(1, limit) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  title,
                  key: const ValueKey('training-week-title'),
                  textAlign: TextAlign.center,
                  style: B05Typography.label(context),
                ),
              ),
              IconButton(
                key: const ValueKey('training-week-newer'),
                tooltip: 'Later week',
                onPressed: weeksBack > 0 ? () => _page(-1, limit) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            // Swipe right for older weeks, left for newer.
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 200) _page(1, limit);
              if (velocity < -200) _page(-1, limit);
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < 7; index++)
                  Expanded(
                    child: _TrainingStripDayCell(
                      date: start.add(Duration(days: index)),
                      day: days?[index],
                      isToday: start.add(Duration(days: index)) == today,
                      timezoneId: tz,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingStripDayCell extends ConsumerWidget {
  const _TrainingStripDayCell({
    required this.date,
    required this.day,
    required this.isToday,
    required this.timezoneId,
  });

  final DateTime date;
  final TrainingStripDay? day;
  final bool isToday;
  final String timezoneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localDate = _key(date);
    final muscles = day?.trained == true
        ? ref
              .watch(
                muscleSetsProvider(
                  MuscleSetRange(
                    startLocalDate: localDate,
                    endLocalDate: localDate,
                    timezoneId: timezoneId,
                  ),
                ),
              )
              .valueOrNull
        : null;
    final caption = muscles == null
        ? null
        : trainingMuscleGroupLabel(muscles.sets);
    return WeekStripDayCell(
      key: ValueKey('training-week-day-$localDate'),
      date: date,
      progress: day?.progress,
      filled: false,
      doneMark: day?.doneMark ?? false,
      caption: caption,
      spokenValue: _spoken(day, caption),
      selected: false,
      isToday: isToday,
      onTap: () => showTrainingDaySheet(
        context,
        date: date,
        day: day ?? TrainingStripDay(localDate: localDate),
        muscles: muscles,
      ),
    );
  }

  static String _spoken(TrainingStripDay? day, String? caption) {
    if (day == null) return '';
    final parts = <String>[
      if (day.plannedSets > 0)
        '${day.doneSets} of ${day.plannedSets} planned sets'
      else if (day.trained)
        '${day.doneSets} ${day.doneSets == 1 ? 'set' : 'sets'} done'
      else if (day.scheduledStatus != null)
        day.scheduledStatus!
      else
        'no workout',
      ?caption,
    ];
    return parts.join(', ');
  }
}

/// The light day sheet: workouts, sets, top set and muscles as chips, with
/// "Open workout" to its history page. No body map here.
Future<void> showTrainingDaySheet(
  BuildContext context, {
  required DateTime date,
  required TrainingStripDay day,
  MuscleSetCounts? muscles,
}) => showIndiFitBottomSheet<void>(
  context: context,
  semanticLabel: 'Training on ${DateFormat('EEEE d MMMM').format(date)}',
  builder: (sheetContext) {
    final colors = sheetContext.b05Colors;
    return SafeArea(
      top: false,
      child: Padding(
        key: const ValueKey('training-day-sheet'),
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          B05Layout.space8,
          B05Layout.space16,
          B05Layout.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE d MMMM').format(date),
              style: B05Typography.title(sheetContext),
            ),
            const SizedBox(height: B05Layout.space12),
            if (!day.trained)
              Text(
                day.plannedSets > 0
                    ? '${day.plannedSets} sets planned, none logged.'
                    : 'No workout logged.',
                style: B05Typography.body(sheetContext),
              ),
            for (final workout in day.workouts) ...[
              Text(workout.name, style: B05Typography.label(sheetContext)),
              const SizedBox(height: B05Layout.space4),
              Text(
                '${workout.sets} working ${workout.sets == 1 ? 'set' : 'sets'}'
                '${workout.topSet == null ? '' : ' · Top set ${workout.topSet}'}',
                style: B05Typography.body(
                  sheetContext,
                ).copyWith(color: colors.textSecondary),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/workout-history/${workout.sessionId}');
                  },
                  child: const Text('Open workout'),
                ),
              ),
              const SizedBox(height: B05Layout.space8),
            ],
            if (muscles != null && !muscles.isEmpty) ...[
              Wrap(
                spacing: B05Layout.space8,
                runSpacing: B05Layout.space8,
                children: [
                  for (final entry in muscles.ranked)
                    Chip(
                      label: Text(
                        '${ExerciseDisplayMuscles.formatMuscle(entry.key)} '
                        '${IndiFitMuscleMap.formatSets(entry.value)}',
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  },
);

String _key(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
