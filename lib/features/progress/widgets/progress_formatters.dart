import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/presentation/secondary_presentation.dart';
import '../../../core/services/local_schedule_date_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/models/b04_goal_models.dart';
import '../../settings/unit_preference.dart';
import '../progress_dashboard_models.dart';
import 'progress_view_models.dart';

/// Pure presentation helpers for Progress (PV1-ENG-05A first pass).
///
/// Extracted verbatim from `progress_screen.dart`; behavior unchanged.

String progressNutritionStrategyLabel(NutritionGoalType value) =>
    SecondaryConsumerCopy.nutritionStrategy(value.stableId);

List<BodyMeasurementValue> bodyMeasurementValues(
  List<ProgressMeasurementRecord> measurements,
) => [
  latestBodyMeasurementValue(
    'Waist',
    measurements,
    (record) => record.waistCm,
  ),
  latestBodyMeasurementValue(
    'Chest',
    measurements,
    (record) => record.chestCm,
  ),
  latestBodyMeasurementValue('Arms', measurements, (record) => record.armsCm),
].whereType<BodyMeasurementValue>().toList(growable: false);

BodyMeasurementValue? latestBodyMeasurementValue(
  String label,
  List<ProgressMeasurementRecord> measurements,
  double? Function(ProgressMeasurementRecord record) read,
) {
  final entries = measurements
      .where((record) {
        final value = read(record);
        return value != null && value > 0;
      })
      .toList(growable: false);
  if (entries.isEmpty) return null;
  final latest = entries.first;
  final latestValue = read(latest)!;
  ProgressMeasurementRecord? prior;
  for (final candidate in entries.skip(1)) {
    if (candidate.localDate != latest.localDate) {
      prior = candidate;
      break;
    }
  }
  final priorValue = prior == null ? null : read(prior);
  final difference = priorValue == null ? null : latestValue - priorValue;
  final changeText = difference == null || difference == 0
      ? null
      : '${formatNumber(difference.abs())} cm ${difference < 0 ? 'lower' : 'higher'} than ${shortCivilDate(prior!.localDate)}';
  return BodyMeasurementValue(
    label: label,
    value: latestValue,
    localDate: latest.localDate,
    changeText: changeText,
  );
}

StrengthHighlight? selectStrengthHighlight(
  List<ProgressStrengthSetRecord> records,
) {
  final highlights = selectStrengthHighlights(records);
  return highlights.isEmpty ? null : highlights.first;
}

List<StrengthHighlight> selectStrengthHighlights(
  List<ProgressStrengthSetRecord> records,
) {
  if (records.isEmpty) return const [];
  final groups = <String, List<ProgressStrengthSetRecord>>{};
  for (final record in records) {
    final exerciseId = record.exerciseId.trim();
    if (exerciseId.isEmpty || record.exerciseName.trim().isEmpty) continue;
    groups.putIfAbsent(exerciseId, () => []).add(record);
  }
  if (groups.isEmpty) return const [];
  final highlights = <StrengthHighlight>[];
  for (final entry in groups.entries) {
    final values = entry.value;
    final sorted = values.toList(growable: true)
      ..sort(
        (first, second) =>
            compareStrengthRecordsForPresentation(first, second),
      );
    final latestPerformedAtUtc = sorted.last.completedAtUtc;
    final latestSessionKey = presentationStrengthSessionKey(sorted.last);
    final latestSession = sorted
        .where(
          (record) =>
              presentationStrengthSessionKey(record) == latestSessionKey,
        )
        .toList(growable: false);
    final latestExternal = latestSession
        .where((record) => record.loadBasis == 'totalExternal')
        .toList(growable: false);
    final heaviest = latestExternal.isEmpty
        ? sorted.last
        : latestExternal.reduce(heavierStrengthSetForPresentation);
    highlights.add(
      StrengthHighlight(
        exerciseId: entry.key,
        exerciseName: heaviest.exerciseName,
        heaviest: heaviest,
        records: sorted,
        latestPerformedAtUtc: latestPerformedAtUtc,
        comparisonText: presentationStrengthComparison(
          sorted,
          latestSessionKey,
          heaviest,
        ),
      ),
    );
  }
  highlights.sort((first, second) {
    final byLatest = second.latestPerformedAtUtc.compareTo(
      first.latestPerformedAtUtc,
    );
    if (byLatest != 0) return byLatest;
    return second.records.length.compareTo(first.records.length);
  });
  return List.unmodifiable(highlights);
}

int distinctStrengthSessionCount(List<ProgressStrengthSetRecord> records) =>
    records.map(presentationStrengthSessionKey).toSet().length;

int compareStrengthRecordsForPresentation(
  ProgressStrengthSetRecord first,
  ProgressStrengthSetRecord second,
) {
  final byTime = first.completedAtUtc.compareTo(second.completedAtUtc);
  if (byTime != 0) return byTime;
  final bySession = (first.sessionId ?? -1).compareTo(second.sessionId ?? -1);
  if (bySession != 0) return bySession;
  return first.performedSetId.compareTo(second.performedSetId);
}

ProgressStrengthSetRecord heavierStrengthSetForPresentation(
  ProgressStrengthSetRecord first,
  ProgressStrengthSetRecord second,
) {
  if (first.loadKg != second.loadKg) {
    return first.loadKg > second.loadKg ? first : second;
  }
  final firstReps = first.reps;
  final secondReps = second.reps;
  if (firstReps != secondReps) {
    return firstReps > secondReps ? first : second;
  }
  return compareStrengthRecordsForPresentation(first, second) > 0
      ? first
      : second;
}

String presentationStrengthSessionKey(ProgressStrengthSetRecord record) =>
    record.sessionId == null
    ? 'date:${record.localDate}'
    : 'session:${record.sessionId}';

String? presentationStrengthComparison(
  List<ProgressStrengthSetRecord> records,
  String latestSessionKey,
  ProgressStrengthSetRecord current,
) {
  if (current.loadBasis != 'totalExternal') return null;
  final previous = records
      .where(
        (record) =>
            presentationStrengthSessionKey(record) != latestSessionKey &&
            record.loadBasis == 'totalExternal' &&
            record.reps == current.reps,
      )
      .toList(growable: true);
  if (previous.isEmpty) return null;
  previous.sort(compareStrengthRecordsForPresentation);
  final previousSessionKey = presentationStrengthSessionKey(previous.last);
  final previousBest = previous
      .where(
        (record) =>
            presentationStrengthSessionKey(record) == previousSessionKey,
      )
      .reduce(heavierStrengthSetForPresentation);
  final difference = current.loadKg - previousBest.loadKg;
  if (difference == 0) return null;
  final sign = difference > 0 ? '+' : '';
  return '$sign${formatNumber(difference)} kg at ${current.reps} reps vs previous session';
}

bool hasMeaningfulVolume(ProgressDashboardSnapshot snapshot) =>
    (snapshot.workouts ?? const <ProgressWorkoutRecord>[]).any(
      (workout) =>
          workout.isCanonicalStrength &&
          workout.volumeIsTrustworthy &&
          workout.totalVolumeKg > 0,
    );

bool hasKnownStrengthActivity(ProgressDashboardSnapshot snapshot) =>
    snapshot.strengthSets != null &&
    (snapshot.workouts ?? const <ProgressWorkoutRecord>[]).any(
      (workout) => workout.isCanonicalStrength,
    );

bool hasMeaningfulMuscleBalance(ProgressDashboardSnapshot snapshot) =>
    snapshot.muscleBalance != null &&
    snapshot.muscleBalance!.muscles.any((muscle) => muscle.workingSetUnits > 0);

List<ProgressWorkoutRecord> workoutsThisWeek(
  ProgressDashboardSnapshot snapshot,
) {
  final dates = LocalScheduleDateService();
  final weekday = dates.weekday(snapshot.todayLocalDate, snapshot.timezoneId);
  final start = dates.addCalendarDays(
    snapshot.todayLocalDate,
    snapshot.timezoneId,
    DateTime.monday - weekday,
  );
  return (snapshot.workouts ?? const <ProgressWorkoutRecord>[])
      .where(
        (workout) =>
            workout.localDate.compareTo(start) >= 0 &&
            workout.localDate.compareTo(snapshot.todayLocalDate) <= 0,
      )
      .toList(growable: false);
}

List<ProgressWorkoutRecord> workoutsInRecentFourWeeks(
  ProgressDashboardSnapshot snapshot,
) {
  final start = LocalScheduleDateService().addCalendarDays(
    snapshot.todayLocalDate,
    snapshot.timezoneId,
    -27,
  );
  return (snapshot.workouts ?? const <ProgressWorkoutRecord>[])
      .where(
        (workout) =>
            workout.localDate.compareTo(start) >= 0 &&
            workout.localDate.compareTo(snapshot.todayLocalDate) <= 0,
      )
      .toList(growable: false);
}

/// A weight trend needs observations on three distinct local days. Several
/// weigh-ins in one day remain useful history, but cannot imply a day-to-day
/// trend or become extra points in a consumer chart.
bool hasWeightChartHistory(List<ProgressMeasurementRecord> measurements) =>
    dailyWeightObservations(measurements).length >= 3;

int compareMeasurementsChronologically(
  ProgressMeasurementRecord first,
  ProgressMeasurementRecord second,
) {
  final byRecordedAt = first.recordedAt.compareTo(second.recordedAt);
  return byRecordedAt != 0 ? byRecordedAt : first.id.compareTo(second.id);
}

int compareMeasurementsNewestFirst(
  ProgressMeasurementRecord first,
  ProgressMeasurementRecord second,
) => compareMeasurementsChronologically(second, first);

/// Collapses a day's weigh-ins to its latest persisted observation for
/// consumer trend display. The full record history remains unchanged for
/// measurement history and persistence; this is presentation-only grouping.
List<ProgressMeasurementRecord> dailyWeightObservations(
  Iterable<ProgressMeasurementRecord> measurements,
) {
  final chronological =
      measurements
          .where(
            (measurement) =>
                measurement.weightKg != null &&
                measurement.weightKg!.isFinite &&
                measurement.weightKg! > 0,
          )
          .toList(growable: true)
        ..sort(compareMeasurementsChronologically);
  final latestByLocalDate = <String, ProgressMeasurementRecord>{};
  for (final measurement in chronological) {
    latestByLocalDate[measurement.localDate] = measurement;
  }
  final daily = latestByLocalDate.values.toList(growable: true)
    ..sort(compareMeasurementsChronologically);
  return daily;
}

String weightDetail(
  List<ProgressMeasurementRecord> measurements,
  String units,
) {
  final dailyMeasurements = dailyWeightObservations(measurements);
  if (dailyMeasurements.length == 1) {
    return measurements.length > 1
        ? 'Multiple weigh-ins recorded on ${shortCivilDate(measurementDate(dailyMeasurements.last))}'
        : 'Latest weigh-in';
  }
  if (dailyMeasurements.length == 2) {
    return '${formatWeight(dailyMeasurements.first.weightKg!, units)} → ${formatWeight(dailyMeasurements.last.weightKg!, units)}';
  }
  final first = dailyMeasurements.first;
  final last = dailyMeasurements.last;
  final difference = last.weightKg! - first.weightKg!;
  final days = civilDayDifference(
    measurementDate(first),
    measurementDate(last),
  );
  if (days == 0) {
    return 'Multiple weigh-ins recorded on ${shortCivilDate(measurementDate(last))}';
  }
  if (difference == 0) {
    return days > 0
        ? 'No change from ${days == 1 ? 'yesterday' : '$days days ago'}'
        : 'No change across recorded measurements';
  }
  final relation = difference < 0 ? 'lower' : 'higher';
  return days > 0
      ? '${formatWeight(difference.abs(), units)} $relation than $days days ago'
      : '${formatWeight(difference.abs(), units)} $relation across recorded measurements';
}

String weightSemantics(
  List<ProgressMeasurementRecord> measurements,
  String units,
) {
  final latest = dailyWeightObservations(measurements).last;
  final detail = weightDetail(measurements, units);
  return 'Weight: ${formatWeight(latest.weightKg!, units)}. $detail.';
}

IconData weightDirectionIcon(List<ProgressMeasurementRecord> measurements) {
  final dailyMeasurements = dailyWeightObservations(measurements);
  if (dailyMeasurements.length < 2) return Icons.scale_rounded;
  final difference =
      dailyMeasurements.last.weightKg! - dailyMeasurements.first.weightKg!;
  if (difference < 0) return Icons.south_east_rounded;
  if (difference > 0) return Icons.north_east_rounded;
  return Icons.horizontal_rule_rounded;
}

LineChartData weightChartData({
  required BuildContext context,
  required List<ProgressMeasurementRecord> measurements,
  required String units,
  required ValueChanged<int> onTouch,
}) {
  final colors = context.b05Colors;
  final firstDate = measurementDate(measurements.first);
  final chartDaySpan = civilDayDifference(
    firstDate,
    measurementDate(measurements.last),
  );
  final weights = measurements
      .map(
        (record) => UnitPreferencePresentation.weightForDisplay(
          record.weightKg!,
          units,
        ),
      )
      .toList();
  final minimum = weights.reduce(
    (first, second) => first < second ? first : second,
  );
  final maximum = weights.reduce(
    (first, second) => first > second ? first : second,
  );
  final rawSpread = maximum - minimum;
  final spread = rawSpread.isFinite ? rawSpread : maximum;
  final padding = spread < .5 ? .5 : spread * .25;
  final rawMinY = (minimum - padding).clamp(0, double.infinity).toDouble();
  final rawMaxY = maximum + padding;
  final minY = rawMinY.isFinite ? rawMinY : 0.0;
  var maxY = rawMaxY.isFinite ? rawMaxY : maximum;
  if (maxY <= minY) {
    maxY = minY == 0
        ? 1
        : (minY * 1.01).clamp(minY, double.maxFinite).toDouble();
  }
  final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return LineChartData(
    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: (maxY - minY) / 3,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: colors.border.withValues(alpha: .35), strokeWidth: 1),
    ),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: (42 * textScale).clamp(42.0, 72.0),
          interval: (maxY - minY) / 2,
          getTitlesWidget: (value, _) => Text(
            value.toStringAsFixed(0),
            style: B05Typography.caption(context),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: chartDaySpan.toDouble(),
          getTitlesWidget: (value, _) {
            final isFirst = value.abs() < .01;
            final isLast = (value - chartDaySpan).abs() < .01;
            if (!isFirst && !isLast) {
              return const SizedBox.shrink();
            }
            final measurement = isFirst
                ? measurements.first
                : measurements.last;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                shortCivilDate(measurementDate(measurement)),
                style: B05Typography.caption(context),
              ),
            );
          },
        ),
      ),
    ),
    borderData: FlBorderData(show: false),
    minX: 0,
    maxX: chartDaySpan.toDouble(),
    minY: minY,
    maxY: maxY,
    lineTouchData: LineTouchData(
      enabled: true,
      touchCallback: (_, response) {
        final index = response?.lineBarSpots?.firstOrNull?.spotIndex;
        if (index != null) onTouch(index);
      },
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => colors.surfaceSubtle,
        tooltipRoundedRadius: 8,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        getTooltipItems: (spots) => [
          for (final spot in spots)
            LineTooltipItem(
              '${shortCivilDate(measurementDate(measurements[spot.spotIndex]))}\n${formatDisplayedWeight(spot.y, units)}',
              TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
        ],
      ),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: [
          for (var index = 0; index < measurements.length; index++)
            FlSpot(
              civilDayDifference(
                firstDate,
                measurementDate(measurements[index]),
              ).toDouble(),
              UnitPreferencePresentation.weightForDisplay(
                measurements[index].weightKg!,
                units,
              ),
            ),
        ],
        isCurved: false,
        color: colors.action,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
            radius: 3.5,
            color: colors.section,
            strokeColor: colors.action,
            strokeWidth: 2,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.action.withValues(alpha: 0.14),
              colors.action.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    ],
  );
}

String formatWeight(double kilograms, String units) => formatDisplayedWeight(
  UnitPreferencePresentation.weightForDisplay(kilograms, units),
  units,
);

String formatDisplayedWeight(double value, String units) =>
    '${value.toStringAsFixed(1)} ${UnitPreferencePresentation.weightSymbol(units)}';

String formatSet(
  ProgressStrengthSetRecord record,
) => switch (record.loadBasis) {
  'perSide' =>
    '${formatNumber(record.loadKg)} ${strengthLoadUnit(record)} × ${record.reps}',
  'perImplement' =>
    '${formatNumber(record.loadKg)} ${strengthLoadUnit(record)} × ${record.reps}',
  'bodyweight' => 'Bodyweight × ${record.reps}',
  _ => '${formatNumber(record.loadKg)} kg × ${record.reps}',
};

String strengthLoadUnit(ProgressStrengthSetRecord record) =>
    switch (record.loadBasis) {
      'perSide' => 'kg per side',
      'perImplement' => 'kg per implement',
      _ => 'kg',
    };

String formatVolume(double value) =>
    NumberFormat.decimalPattern().format(value.round());

String nutritionAdherenceLabel(ProgressNutritionSummary summary) {
  if (summary.targetProteinG != null && summary.proteinEvidenceDaysCount > 0) {
    return '${summary.proteinTargetMetDaysCount} of ${summary.proteinEvidenceDaysCount} complete ${summary.proteinEvidenceDaysCount == 1 ? 'day' : 'days'} met protein';
  }
  if (summary.calorieEvidenceDaysCount > 0) {
    return '${summary.loggedDaysCount} ${summary.loggedDaysCount == 1 ? 'day' : 'days'} with meals logged · ${summary.calorieEvidenceDaysCount} complete calorie ${summary.calorieEvidenceDaysCount == 1 ? 'day' : 'days'}';
  }
  return '${summary.loggedDaysCount} ${summary.loggedDaysCount == 1 ? 'day' : 'days'} with meals logged';
}

List<ProgressNutritionDaySummary> completeNutritionDays(
  ProgressNutritionSummary summary,
) => summary.days
    .where(
      (day) =>
          day.hasFoodLog &&
          !day.isNutrientIncomplete &&
          day.caloriesKcal != null &&
          day.proteinG != null,
    )
    .toList(growable: false);

String? nutritionCompactFactLine(ProgressNutritionDaySummary? day) {
  if (day == null) return null;
  final facts = <String>[
    if (day.caloriesKcal != null) '${formatVolume(day.caloriesKcal!)} kcal',
    if (day.proteinG != null && day.proteinTargetG != null)
      '${formatNumber(day.proteinG!)} / ${formatNumber(day.proteinTargetG!)} g protein',
    if (day.proteinG != null && day.proteinTargetG == null)
      '${formatNumber(day.proteinG!)} g protein',
  ];
  return facts.isEmpty ? null : facts.join(' · ');
}

String nutritionHeadlineSemantics({
  required ProgressNutritionSummary summary,
  required List<ProgressNutritionDaySummary> completeDays,
  required bool hasRichHistory,
}) {
  if (!hasRichHistory) {
    final day = completeDays.isEmpty ? null : completeDays.last;
    final factLine = nutritionCompactFactLine(day);
    if (factLine != null) {
      return 'Nutrition: $factLine. ${completeDays.length} complete logged day.';
    }
    return 'Nutrition: ${summary.loggedDaysCount} ${summary.loggedDaysCount == 1 ? 'logged day' : 'logged days'}. Some nutrition details are incomplete.';
  }

  final facts = <String>['Nutrition adherence.'];
  if (summary.averageCaloriesKcal != null &&
      summary.calorieEvidenceDaysCount >= 2) {
    facts.add(
      'Average ${summary.averageCaloriesKcal!.round()} calories across ${summary.calorieEvidenceDaysCount} complete days.',
    );
  }
  if (summary.averageProteinG != null &&
      summary.proteinEvidenceDaysCount >= 2) {
    facts.add(
      'Average ${summary.averageProteinG!.round()} grams protein across ${summary.proteinEvidenceDaysCount} complete days.',
    );
  }
  facts.add('${nutritionAdherenceLabel(summary)}.');
  return facts.join(' ');
}

String formatNumber(double value) {
  final whole = value.roundToDouble() == value;
  return whole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

String fullCivilDate(String value) {
  final date = parseCivilDate(value);
  return DateFormat.yMMMd().format(date);
}

String? measurementTime(
  ProgressMeasurementRecord measurement,
  String timezoneId,
) {
  try {
    final local = tz.TZDateTime.from(
      measurement.recordedAt.toUtc(),
      LocalScheduleDateService().locationFor(timezoneId),
    );
    return DateFormat.jm().format(local);
  } on Object {
    // A date label remains authoritative even if an older record cannot be
    // converted through the current timezone database.
    return null;
  }
}

int civilDayDifference(String start, String end) =>
    parseCivilDate(end).difference(parseCivilDate(start)).inDays;

double? parseMeasurement(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}
