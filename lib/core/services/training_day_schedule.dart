import 'local_schedule_date_service.dart';

/// Civil-date maths for laying a plan's training days onto the calendar.
/// Every date goes through [LocalScheduleDateService], so DST never moves a
/// session to another day.
abstract final class TrainingDaySchedule {
  /// Sorted, distinct Monday (1) to Sunday (7) weekdays.
  static List<int> normalizeWeekdays(Iterable<int> weekdays) {
    final values = weekdays.toSet().toList()..sort();
    for (final weekday in values) {
      if (weekday < DateTime.monday || weekday > DateTime.sunday) {
        throw ArgumentError.value(
          weekday,
          'weekday',
          'Must be between Monday (1) and Sunday (7).',
        );
      }
    }
    return values;
  }

  /// The first date on or after [fromLocalDate] that is a training day.
  static String firstTrainingDayOnOrAfter({
    required LocalScheduleDateService dates,
    required String timezoneId,
    required String fromLocalDate,
    required Iterable<int> weekdays,
  }) {
    final days = normalizeWeekdays(weekdays);
    if (days.isEmpty) {
      throw ArgumentError.value(weekdays, 'weekdays', 'Must not be empty.');
    }
    var cursor = dates.normalizeLocalDate(fromLocalDate);
    while (!days.contains(dates.weekday(cursor, timezoneId))) {
      cursor = dates.addCalendarDays(cursor, timezoneId, 1);
    }
    return cursor;
  }

  /// [count] training dates. The first is [startLocalDate] itself when
  /// [startsOnStartDate] is true (the user chose to start that day, training
  /// day or not); otherwise the first training day after it. Each next date
  /// is the next training day after the previous one.
  static List<String> layDates({
    required LocalScheduleDateService dates,
    required String timezoneId,
    required String startLocalDate,
    required Iterable<int> weekdays,
    required int count,
    bool startsOnStartDate = true,
  }) {
    final days = normalizeWeekdays(weekdays);
    if (days.isEmpty) {
      throw ArgumentError.value(weekdays, 'weekdays', 'Must not be empty.');
    }
    final result = <String>[];
    var previous = dates.normalizeLocalDate(startLocalDate);
    if (count <= 0) return result;
    if (startsOnStartDate) {
      result.add(previous);
    }
    while (result.length < count) {
      previous = firstTrainingDayOnOrAfter(
        dates: dates,
        timezoneId: timezoneId,
        fromLocalDate: dates.addCalendarDays(previous, timezoneId, 1),
        weekdays: days,
      );
      result.add(previous);
    }
    return result;
  }
}
