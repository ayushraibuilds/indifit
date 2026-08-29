import 'package:intl/intl.dart';

import '../../core/services/local_schedule_date_service.dart';
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
    final workingSetsCount = list.fold<int>(
      0,
      (sum, w) => sum + w.workingSetsCount,
    );
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

  static String formatVolumeSubtitle({
    required String units,
    required bool useRecent,
  }) {
    final symbol = UnitPreferencePresentation.weightSymbol(units);
    return useRecent
        ? '$symbol loaded in the last 4 weeks'
        : '$symbol loaded across recorded strength sessions';
  }

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
