import 'package:intl/intl.dart';

import '../../data/models/progress_dashboard_models.dart';
import '../settings/unit_preference.dart';

/// Presentation-only facts and formatting for R08F.4 Training Consistency
/// and Volume.
///
/// Distinguishes canonical sessions from distinct local training days and derives
/// volume truthfully from supported performed-set evidence.
abstract final class R08F4TrainingVolumePresentation {
  /// Analyzes a collection of workout records for session and day semantics.
  static R08F4ConsistencySummary summarizeConsistency(
    Iterable<ProgressWorkoutRecord> workouts,
  ) {
    final list = workouts.toList(growable: false);
    final sessionCount = list.length;
    final trainingDays = <String>{for (final w in list) w.localDate};
    final workingSetsCount = list.fold<int>(0, (sum, w) => sum + w.workingSetsCount);
    final partialSessionCount = list.where((w) => w.isPartial).length;
    final activityTypeCounts = <String, int>{};
    for (final w in list) {
      activityTypeCounts[w.activityType] =
          (activityTypeCounts[w.activityType] ?? 0) + 1;
    }

    return R08F4ConsistencySummary(
      sessionCount: sessionCount,
      trainingDayCount: trainingDays.length,
      trainingDays: Set.unmodifiable(trainingDays),
      workingSetsCount: workingSetsCount,
      partialSessionCount: partialSessionCount,
      activityTypeCounts: Map.unmodifiable(activityTypeCounts),
    );
  }

  /// Summarizes strength volume across trustworthy recorded workouts.
  static R08F4VolumeSummary summarizeVolume({
    required Iterable<ProgressWorkoutRecord> allWorkouts,
    required String todayLocalDate,
    required String units,
    int recentDays = 28,
  }) {
    final eligibleAll = allWorkouts
        .where(
          (w) =>
              w.isCanonicalStrength &&
              w.volumeIsTrustworthy &&
              w.totalVolumeKg > 0,
        )
        .toList(growable: false);

    // Compute cutoff for recent window (default: 28 days / 4 weeks)
    final recentCutoff = _addCivilDays(todayLocalDate, -(recentDays - 1));
    final eligibleRecent = eligibleAll
        .where((w) => w.localDate.compareTo(recentCutoff) >= 0)
        .toList(growable: false);

    final useRecent = eligibleRecent.isNotEmpty;
    final selectedWorkouts = useRecent ? eligibleRecent : eligibleAll;
    final totalVolumeKg = selectedWorkouts.fold<double>(
      0,
      (sum, w) => sum + w.totalVolumeKg,
    );

    final displayVolume = UnitPreferencePresentation.weightForDisplay(
      totalVolumeKg,
      units,
    );
    final symbol = UnitPreferencePresentation.weightSymbol(units);
    final isImperial = UnitPreferencePresentation.isImperial(units);

    return R08F4VolumeSummary(
      totalVolumeKg: totalVolumeKg,
      displayVolume: displayVolume,
      unitSymbol: symbol,
      isImperial: isImperial,
      useRecent: useRecent,
      contributingSessionCount: selectedWorkouts.length,
      hasTrustworthyVolume: eligibleAll.isNotEmpty,
    );
  }

  // --- Copy Formatting ---

  static String formatThisWeekHeading(int sessionCount) {
    if (sessionCount == 0) return 'No workouts this week';
    return '$sessionCount ${sessionCount == 1 ? 'workout' : 'workouts'}';
  }

  static String formatThisWeekSubtitle({
    required int sessionCount,
    required int dayCount,
  }) {
    if (sessionCount == 0) return 'this week';
    if (sessionCount == dayCount) return 'completed this week';
    return 'completed across $dayCount ${dayCount == 1 ? 'training day' : 'training days'} this week';
  }

  static String formatThisWeekSemantics({
    required int sessionCount,
    required int dayCount,
  }) {
    if (sessionCount == 0) return 'No workouts completed this week.';
    if (sessionCount == dayCount) {
      return '$sessionCount ${sessionCount == 1 ? 'workout' : 'workouts'} completed this week.';
    }
    return '$sessionCount ${sessionCount == 1 ? 'workout' : 'workouts'} completed across $dayCount ${dayCount == 1 ? 'training day' : 'training days'} this week.';
  }

  static String formatRecentHistorySummary({
    required int sessionCount,
    required int dayCount,
    required int workingSetsCount,
    int weeks = 4,
  }) {
    if (sessionCount == 0) return '';
    final setsSuffix =
        workingSetsCount > 0 ? ' · $workingSetsCount working sets' : '';
    if (sessionCount == dayCount) {
      return '$sessionCount ${sessionCount == 1 ? 'workout' : 'workouts'} completed in the last $weeks weeks$setsSuffix';
    }
    return '$sessionCount ${sessionCount == 1 ? 'workout' : 'workouts'} across $dayCount ${dayCount == 1 ? 'training day' : 'training days'} in the last $weeks weeks$setsSuffix';
  }

  static String formatDaySemanticLabel({
    required String dayLabel,
    required int sessionCount,
    required bool isToday,
  }) {
    if (sessionCount > 1) {
      return '$dayLabel, $sessionCount workouts completed.';
    }
    if (sessionCount == 1) {
      return '$dayLabel, workout completed.';
    }
    if (isToday) {
      return '$dayLabel, today.';
    }
    return '$dayLabel, rest day.';
  }

  static String formatVolume(double value) =>
      NumberFormat.decimalPattern().format(value.round());

  static String formatVolumeSubtitle({
    required String units,
    required bool useRecent,
  }) {
    final symbol = UnitPreferencePresentation.weightSymbol(units);
    return useRecent
        ? '$symbol recorded in the last 4 weeks'
        : '$symbol across recorded strength workouts';
  }

  static String formatVolumeSemantics({
    required double displayVolume,
    required String units,
    required bool useRecent,
  }) {
    final unitWord =
        UnitPreferencePresentation.isImperial(units) ? 'pounds' : 'kilograms';
    final timeframe =
        useRecent
            ? 'in the last four weeks'
            : 'across recorded strength workouts';
    return '${formatVolume(displayVolume)} $unitWord $timeframe.';
  }

  static String _addCivilDays(String dateStr, int days) {
    final parts = dateStr.split('-').map(int.parse).toList(growable: false);
    final date = DateTime.utc(parts[0], parts[1], parts[2]).add(
      Duration(days: days),
    );
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class R08F4ConsistencySummary {
  const R08F4ConsistencySummary({
    required this.sessionCount,
    required this.trainingDayCount,
    required this.trainingDays,
    required this.workingSetsCount,
    required this.partialSessionCount,
    required this.activityTypeCounts,
  });

  final int sessionCount;
  final int trainingDayCount;
  final Set<String> trainingDays;
  final int workingSetsCount;
  final int partialSessionCount;
  final Map<String, int> activityTypeCounts;

  bool get hasMultipleSessionsOnSameDay => sessionCount > trainingDayCount;
  bool get hasAnyWorkouts => sessionCount > 0;
}

class R08F4VolumeSummary {
  const R08F4VolumeSummary({
    required this.totalVolumeKg,
    required this.displayVolume,
    required this.unitSymbol,
    required this.isImperial,
    required this.useRecent,
    required this.contributingSessionCount,
    required this.hasTrustworthyVolume,
  });

  final double totalVolumeKg;
  final double displayVolume;
  final String unitSymbol;
  final bool isImperial;
  final bool useRecent;
  final int contributingSessionCount;
  final bool hasTrustworthyVolume;
}
