import 'package:intl/intl.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../../data/models/progress_dashboard_models.dart';
import '../settings/unit_preference.dart';

export '../../data/models/progress_dashboard_models.dart'
    show R08F4ConsistencySummary;

/// Presentation-only facts and formatting for R08F.4 Training Consistency
/// and Volume.
///
/// Distinguishes canonical sessions from distinct local training days and derives
/// volume truthfully from supported performed-set evidence.
abstract final class R08F4TrainingVolumePresentation {
  /// Analyzes a collection of workout records for session and day semantics.
  static R08F4ConsistencySummary summarizeConsistency(
    Iterable<ProgressWorkoutRecord> workouts,
  ) => R08F4ConsistencySummary.summarize(workouts);

  /// Summarizes strength volume across trustworthy recorded workouts.
  static R08F4VolumeSummary summarizeVolume({
    required Iterable<ProgressWorkoutRecord> allWorkouts,
    required String todayLocalDate,
    required String timezoneId,
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

    // Keep the recent window on the same explicit civil-date authority that
    // produced each workout's localDate.
    final recentCutoff = LocalScheduleDateService().addCalendarDays(
      todayLocalDate,
      timezoneId,
      -(recentDays - 1),
    );
    final eligibleRecent = eligibleAll
        .where((w) => w.localDate.compareTo(recentCutoff) >= 0)
        .toList(growable: false);

    final useRecent = eligibleRecent.isNotEmpty;
    final selectedWorkouts = useRecent ? eligibleRecent : eligibleAll;
    final totalVolumeKg = selectedWorkouts.fold<double>(
      0,
      (sum, w) => sum + w.totalVolumeKg,
    );

    // Compare like-for-like four-week windows only when the current window
    // has evidence and the immediately preceding window has evidence too.
    // An all-time fallback is intentionally not compared with a recent
    // window, because those periods do not have the same denominator.
    final previousPeriodStart = LocalScheduleDateService().addCalendarDays(
      todayLocalDate,
      timezoneId,
      -(recentDays * 2 - 1),
    );
    final eligiblePrevious = useRecent
        ? eligibleAll
              .where(
                (w) =>
                    w.localDate.compareTo(previousPeriodStart) >= 0 &&
                    w.localDate.compareTo(recentCutoff) < 0,
              )
              .toList(growable: false)
        : const <ProgressWorkoutRecord>[];
    final previousPeriodVolumeKg = eligiblePrevious.isEmpty
        ? null
        : eligiblePrevious.fold<double>(0, (sum, w) => sum + w.totalVolumeKg);

    final displayVolume = UnitPreferencePresentation.weightForDisplay(
      totalVolumeKg,
      units,
    );
    final previousPeriodDisplayVolume = previousPeriodVolumeKg == null
        ? null
        : UnitPreferencePresentation.weightForDisplay(
            previousPeriodVolumeKg,
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
      previousPeriodVolumeKg: previousPeriodVolumeKg,
      previousPeriodDisplayVolume: previousPeriodDisplayVolume,
      previousPeriodContributingSessionCount: eligiblePrevious.length,
    );
  }

  /// Loaded volume per Monday-start week, oldest first, ending with the
  /// current week. Weeks without trustworthy volume are kept as zero so the
  /// chart shows gaps instead of closing them.
  static List<R08F4WeeklyVolume> weeklyVolume({
    required Iterable<ProgressWorkoutRecord> allWorkouts,
    required String todayLocalDate,
    required String timezoneId,
    required String units,
    int weeks = 8,
  }) {
    final dates = LocalScheduleDateService();
    final currentWeekStart = dates.addCalendarDays(
      todayLocalDate,
      timezoneId,
      DateTime.monday - dates.weekday(todayLocalDate, timezoneId),
    );
    final starts = [
      for (var i = weeks - 1; i >= 0; i--)
        dates.addCalendarDays(currentWeekStart, timezoneId, -7 * i),
    ];
    final totals = List<double>.filled(weeks, 0);
    final sessions = List<int>.filled(weeks, 0);
    for (final w in allWorkouts) {
      if (!w.isCanonicalStrength ||
          !w.volumeIsTrustworthy ||
          w.totalVolumeKg <= 0 ||
          w.localDate.compareTo(starts.first) < 0 ||
          w.localDate.compareTo(todayLocalDate) > 0) {
        continue;
      }
      final index = starts.lastIndexWhere(
        (start) => w.localDate.compareTo(start) >= 0,
      );
      totals[index] += w.totalVolumeKg;
      sessions[index]++;
    }
    return [
      for (var i = 0; i < weeks; i++)
        R08F4WeeklyVolume(
          weekStartLocalDate: starts[i],
          volumeKg: totals[i],
          displayVolume: UnitPreferencePresentation.weightForDisplay(
            totals[i],
            units,
          ),
          sessionCount: sessions[i],
          isCurrentWeek: i == weeks - 1,
        ),
    ];
  }

  /// "+12%" against the previous four weeks, or null when there is no
  /// comparable period. Rounds toward a whole percent; under 1 % reads "Same".
  static String? formatVolumeChangePercent(R08F4VolumeSummary summary) {
    if (!summary.hasComparablePreviousPeriod) return null;
    final previous = summary.previousPeriodVolumeKg!;
    if (previous <= 0) return null;
    final percent = ((summary.totalVolumeKg - previous) / previous * 100)
        .round();
    if (percent == 0) return 'Same';
    return '${percent > 0 ? '+' : '−'}${percent.abs()}%';
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
    final setsSuffix = workingSetsCount > 0
        ? ' · $workingSetsCount working sets'
        : '';
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

  /// The line under the volume figure; the unit sits beside the figure.
  static String formatVolumeSubtitle({required bool useRecent}) => useRecent
      ? 'Loaded in the last 4 weeks'
      : 'Loaded across recorded strength sessions';

  static String formatVolumeSemantics({
    required double displayVolume,
    required String units,
    required bool useRecent,
  }) {
    final unitWord = UnitPreferencePresentation.isImperial(units)
        ? 'pounds'
        : 'kilograms';
    final timeframe = useRecent
        ? 'in the last four weeks'
        : 'across recorded strength sessions';
    return '${formatVolume(displayVolume)} $unitWord of loaded volume $timeframe.';
  }

  /// Returns a comparison only when both periods contain compatible loaded
  /// volume. A missing prior period remains a single factual metric.
  static String? formatVolumeComparison(R08F4VolumeSummary summary) {
    if (!summary.hasComparablePreviousPeriod) return null;

    final differenceKg =
        summary.totalVolumeKg - summary.previousPeriodVolumeKg!;
    if (differenceKg == 0) return 'Same as the previous 4 weeks';

    final units = summary.isImperial
        ? UnitPreferenceNotifier.imperial
        : UnitPreferenceNotifier.metric;
    final difference = UnitPreferencePresentation.weightForDisplay(
      differenceKg.abs(),
      units,
    );
    final direction = differenceKg > 0 ? 'more' : 'less';
    return '${formatVolume(difference)} ${summary.unitSymbol} $direction than the previous 4 weeks';
  }
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
    this.previousPeriodVolumeKg,
    this.previousPeriodDisplayVolume,
    this.previousPeriodContributingSessionCount = 0,
  });

  final double totalVolumeKg;
  final double displayVolume;
  final String unitSymbol;
  final bool isImperial;
  final bool useRecent;
  final int contributingSessionCount;
  final bool hasTrustworthyVolume;
  final double? previousPeriodVolumeKg;
  final double? previousPeriodDisplayVolume;
  final int previousPeriodContributingSessionCount;

  bool get hasComparablePreviousPeriod =>
      useRecent &&
      previousPeriodVolumeKg != null &&
      previousPeriodDisplayVolume != null &&
      previousPeriodContributingSessionCount > 0;
}

class R08F4WeeklyVolume {
  const R08F4WeeklyVolume({
    required this.weekStartLocalDate,
    required this.volumeKg,
    required this.displayVolume,
    required this.sessionCount,
    required this.isCurrentWeek,
  });

  /// The Monday that starts the week, as a local civil date.
  final String weekStartLocalDate;
  final double volumeKg;
  final double displayVolume;
  final int sessionCount;
  final bool isCurrentWeek;
}
