import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../progress_dashboard_models.dart';

/// Immutable view data shared by Progress sections (PV1-ENG-05A first pass).
///
/// Extracted verbatim from `progress_screen.dart`; behavior unchanged.

enum ProgressMenuAction { achievements }

enum ProgressTimeRange {
  oneMonth('1M', 1),
  threeMonths('3M', 3),
  sixMonths('6M', 6),
  oneYear('1Y', 12),
  all('All', null);

  const ProgressTimeRange(this.label, this.months);

  final String label;
  final int? months;

  String startDate(String today) {
    if (months == null) return '0000-01-01';
    final parsed = parseCivilDate(today);
    return formatCivilDate(subtractMonths(parsed, months!));
  }
}

class ProgressHighlight {
  const ProgressHighlight({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.semanticDetail,
    this.onPressed,
    this.actionLabel,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final String? semanticDetail;
  final VoidCallback? onPressed;
  final String? actionLabel;
}

class BodyMeasurementValue {
  const BodyMeasurementValue({
    required this.label,
    required this.value,
    required this.localDate,
    this.changeText,
  });

  final String label;
  final double value;
  final String localDate;
  final String? changeText;
}

class StrengthHighlight {
  const StrengthHighlight({
    required this.exerciseId,
    required this.exerciseName,
    required this.heaviest,
    required this.records,
    required this.latestPerformedAtUtc,
    this.comparisonText,
  });

  final String exerciseId;
  final String exerciseName;
  final ProgressStrengthSetRecord heaviest;
  final List<ProgressStrengthSetRecord> records;
  final DateTime latestPerformedAtUtc;
  final String? comparisonText;
}


/// Civil-date primitives shared by the range enum and formatters.
///
/// Moved verbatim from `progress_screen.dart` (PV1-ENG-05A).

String measurementDate(ProgressMeasurementRecord record) => record.localDate;

String shortCivilDate(String value) {
  final date = parseCivilDate(value);
  return DateFormat.MMMd().format(date);
}

DateTime parseCivilDate(String value) => DateTime.utc(
  int.parse(value.substring(0, 4)),
  int.parse(value.substring(5, 7)),
  int.parse(value.substring(8, 10)),
);

DateTime subtractMonths(DateTime date, int months) {
  final zeroBasedMonth = date.year * 12 + date.month - 1 - months;
  final year = zeroBasedMonth ~/ 12;
  final month = zeroBasedMonth % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, date.day.clamp(1, lastDay));
}

String formatCivilDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

