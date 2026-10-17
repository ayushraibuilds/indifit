import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';

/// How a plan sits on the calendar, derived from its occurrences: the
/// weekdays the user trains on and the plan's first scheduled date.
class PlanScheduleShape {
  const PlanScheduleShape({
    required this.trainingWeekdays,
    required this.firstLocalDate,
  });

  /// Sorted Monday (1) to Sunday (7) weekdays.
  final List<int> trainingWeekdays;
  final String firstLocalDate;

  int get sessionsPerWeek => trainingWeekdays.length;
}

/// Reads a plan's [PlanScheduleShape]. Nothing is stored for it: the chosen
/// days live on the activation events, and plans activated before that
/// choice existed fall back to the weekdays they were scheduled on.
class PlanScheduleReader {
  const PlanScheduleReader(this._db, this._dates);

  final AppDatabase _db;
  final LocalScheduleDateService _dates;

  Future<PlanScheduleShape?> read(String programVersionId) async {
    final occurrences =
        await (_db.select(_db.scheduledSessionOccurrences)..where(
              (table) =>
                  table.programVersionId.equals(programVersionId) &
                  table.repeatOrdinal.equals(0),
            ))
            .get();
    if (occurrences.isEmpty) return null;

    final firstLocalDate = occurrences
        .map((occurrence) => occurrence.originalLocalDate)
        .reduce((a, b) => _dates.compare(a, b) <= 0 ? a : b);
    final chosen = await _chosenWeekdays(occurrences.map((o) => o.id));
    final weekdays =
        chosen ??
        (occurrences
            .map(
              (occurrence) => _dates.weekday(
                occurrence.originalLocalDate,
                occurrence.originalTimezoneId,
              ),
            )
            .toSet()
            .toList()
          ..sort());
    return PlanScheduleShape(
      trainingWeekdays: weekdays,
      firstLocalDate: firstLocalDate,
    );
  }

  Future<List<int>?> _chosenWeekdays(Iterable<String> occurrenceIds) async {
    final event =
        await (_db.select(_db.occurrenceEvents)
              ..where(
                (table) =>
                    table.eventType.equals('activated') &
                    table.occurrenceId.isIn(occurrenceIds),
              )
              ..limit(1))
            .getSingleOrNull();
    final raw = event?.metadataJson;
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      final days = decoded is Map ? decoded['trainingWeekdays'] : null;
      if (days is! List || days.isEmpty) return null;
      final values = days.whereType<int>().toSet().toList()..sort();
      return values.length == days.length ? values : null;
    } on FormatException {
      return null;
    }
  }
}
