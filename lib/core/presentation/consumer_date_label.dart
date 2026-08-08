import 'package:intl/intl.dart';

/// Formats the civil dates already selected by a domain read model for people.
///
/// A local-date string is deliberately treated as a civil date here. The
/// timezone used to produce it remains an internal concern; it is never
/// appended to ordinary consumer copy.
abstract final class ConsumerDateLabel {
  static String day(String localDate, {DateTime? today}) {
    final date = _parse(localDate);
    if (date == null) return 'Selected day';
    final reference = _civil(today ?? DateTime.now());
    final difference = date.difference(reference).inDays;
    if (difference == 0) return 'Today';
    if (difference == -1) return 'Yesterday';
    if (difference == 1) return 'Tomorrow';
    return DateFormat('EEE, MMM d').format(date);
  }

  static String range(
    String startLocalDate,
    String endLocalDate, {
    DateTime? today,
  }) {
    final start = _parse(startLocalDate);
    final end = _parse(endLocalDate);
    if (start == null || end == null) return 'Selected period';
    if (_sameDay(start, end)) return day(startLocalDate, today: today);
    return '${DateFormat('MMM d').format(start)} – '
        '${DateFormat('MMM d, y').format(end)}';
  }

  static String dateTime(DateTime value, {DateTime? today}) {
    final civil = _civil(value.toLocal());
    return day(_isoDate(civil), today: today);
  }

  static DateTime? _parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
    if (match == null) return null;
    final date = DateTime.tryParse('${match.group(0)}T00:00:00');
    return date == null ? null : _civil(date);
  }

  static DateTime _civil(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
