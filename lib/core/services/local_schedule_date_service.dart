import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Civil-date operations for B01 scheduling. A workout date is never derived
/// from a UTC midnight; all week arithmetic is performed in its stored IANA
/// location and then persisted as an ISO local date.
class LocalScheduleDateService {
  static var _timeZonesInitialized = false;

  final DateTime Function() _nowUtc;

  LocalScheduleDateService({DateTime Function()? nowUtc})
    : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()) {
    _ensureTimeZones();
  }

  tz.Location locationFor(String timezoneId) {
    try {
      return tz.getLocation(timezoneId);
    } catch (_) {
      throw ArgumentError.value(
        timezoneId,
        'timezoneId',
        'Unknown IANA timezone.',
      );
    }
  }

  void validateTimezone(String timezoneId) {
    locationFor(timezoneId);
  }

  /// Validates and canonicalizes YYYY-MM-DD without allowing DateTime to roll
  /// an invalid civil date into the following month.
  String normalizeLocalDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw ArgumentError.value(value, 'localDate', 'Expected YYYY-MM-DD.');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final candidate = DateTime.utc(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      throw ArgumentError.value(value, 'localDate', 'Invalid civil date.');
    }
    return _format(year, month, day);
  }

  int weekday(String localDate, String timezoneId) {
    final date = _parse(normalizeLocalDate(localDate));
    return tz.TZDateTime(
      locationFor(timezoneId),
      date.$1,
      date.$2,
      date.$3,
    ).weekday;
  }

  /// Calendar-day addition, intentionally not Duration-based, so DST weeks
  /// retain their original civil weekdays.
  String addCalendarDays(String localDate, String timezoneId, int days) {
    final date = _parse(normalizeLocalDate(localDate));
    final value = tz.TZDateTime(
      locationFor(timezoneId),
      date.$1,
      date.$2,
      date.$3 + days,
    );
    return _format(value.year, value.month, value.day);
  }

  /// Builds an occurrence date for [programWeekOrdinal] and [plannedWeekday]
  /// from a user supplied activation civil date in the home/program timezone.
  String occurrenceDate({
    required String activationLocalDate,
    required String timezoneId,
    required int programWeekOrdinal,
    required int plannedWeekday,
  }) {
    if (programWeekOrdinal < 0) {
      throw ArgumentError.value(
        programWeekOrdinal,
        'programWeekOrdinal',
        'Must be non-negative.',
      );
    }
    if (plannedWeekday < DateTime.monday || plannedWeekday > DateTime.sunday) {
      throw ArgumentError.value(
        plannedWeekday,
        'plannedWeekday',
        'Must be between Monday (1) and Sunday (7).',
      );
    }
    final activation = normalizeLocalDate(activationLocalDate);
    final startWeekday = weekday(activation, timezoneId);
    final weekdayOffset = (plannedWeekday - startWeekday + 7) % 7;
    return addCalendarDays(
      activation,
      timezoneId,
      programWeekOrdinal * 7 + weekdayOffset,
    );
  }

  String todayIn(String timezoneId) {
    final local = tz.TZDateTime.from(
      _nowUtc().toUtc(),
      locationFor(timezoneId),
    );
    return _format(local.year, local.month, local.day);
  }

  /// Returns the injectable UTC clock used by this date authority. Consumers
  /// that schedule a civil-date boundary signal must use the same clock as
  /// [todayIn] so deterministic tests and timezone transitions do not drift.
  DateTime nowUtc() => _nowUtc().toUtc();

  /// Converts an event instant to the stored civil date for its explicit
  /// timezone. Historical callers must use this persisted location rather
  /// than the device's current timezone.
  String localDateFor(DateTime instantUtc, String timezoneId) {
    final local = tz.TZDateTime.from(
      instantUtc.toUtc(),
      locationFor(timezoneId),
    );
    return _format(local.year, local.month, local.day);
  }

  /// Returns an instant inside an explicitly selected civil date in the
  /// supplied timezone. Feature flows use this for historical logging so a
  /// device timezone change cannot move a selected date across midnight.
  DateTime instantForLocalDate(
    String localDate,
    String timezoneId, {
    int hour = 12,
  }) {
    final date = _parse(normalizeLocalDate(localDate));
    if (hour < 0 || hour > 23) {
      throw ArgumentError.value(hour, 'hour', 'Must be between 0 and 23.');
    }
    return tz.TZDateTime(
      locationFor(timezoneId),
      date.$1,
      date.$2,
      date.$3,
      hour,
    ).toUtc();
  }

  int compare(String first, String second) {
    return normalizeLocalDate(first).compareTo(normalizeLocalDate(second));
  }

  static void _ensureTimeZones() {
    if (_timeZonesInitialized) return;
    tz_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }

  static (int, int, int) _parse(String value) {
    return (
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
  }

  static String _format(int year, int month, int day) {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }
}
