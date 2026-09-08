import '../../core/services/local_schedule_date_service.dart';
import '../repositories/b02_execution_compatibility_read_repository.dart';
import '../repositories/calendar_read_repository.dart';
import 'b02_execution_models.dart';

/// Summary metrics for a training plan version.
///
/// Strictly factual: zero synthetic strength scoring, zero fake PRs,
/// zero inferred readiness, and zero unestimated workout calorie burns.
class PlanAnalyticsSummary {
  final int totalScheduled;
  final int completedCount;
  final int partiallyCompletedCount;
  final int skippedCount;
  final int skippedAdvanceCount;
  final int skippedKeepPendingCount;
  final int rescheduledCount;
  final int cancelledCount;
  final int inProgressCount;
  final int pendingUpcomingCount;
  final int overdueCount;
  final int concurrentIndependentCount;
  final double totalVolumeKg;
  final int totalDurationSeconds;
  final bool hasStrengthSessions;
  final int elapsedCount;
  final int elapsedEligibleCount;
  final double? strictAdherenceRate;
  final double? compositeAdherenceRate;

  const PlanAnalyticsSummary({
    required this.totalScheduled,
    required this.completedCount,
    required this.partiallyCompletedCount,
    required this.skippedCount,
    required this.skippedAdvanceCount,
    required this.skippedKeepPendingCount,
    required this.rescheduledCount,
    required this.cancelledCount,
    required this.inProgressCount,
    required this.pendingUpcomingCount,
    required this.overdueCount,
    required this.concurrentIndependentCount,
    required this.totalVolumeKg,
    required this.totalDurationSeconds,
    required this.hasStrengthSessions,
    required this.elapsedCount,
    required this.elapsedEligibleCount,
    required this.strictAdherenceRate,
    required this.compositeAdherenceRate,
  });

  const PlanAnalyticsSummary.empty()
      : totalScheduled = 0,
        completedCount = 0,
        partiallyCompletedCount = 0,
        skippedCount = 0,
        skippedAdvanceCount = 0,
        skippedKeepPendingCount = 0,
        rescheduledCount = 0,
        cancelledCount = 0,
        inProgressCount = 0,
        pendingUpcomingCount = 0,
        overdueCount = 0,
        concurrentIndependentCount = 0,
        totalVolumeKg = 0.0,
        totalDurationSeconds = 0,
        hasStrengthSessions = false,
        elapsedCount = 0,
        elapsedEligibleCount = 0,
        strictAdherenceRate = null,
        compositeAdherenceRate = null;

  bool get hasActiveOccurrences => totalScheduled > 0;
}

/// Week-level training analytics within a plan phase/block.
class PlanWeekAnalytics {
  final int blockOrdinal;
  final String? blockName;
  final int weekOrdinal;
  final int displayWeekNumber;
  final String? weekName;
  final bool isDeload;
  final int plannedSessions;
  final int completedSessions;
  final int partiallyCompletedSessions;
  final int skippedSessions;
  final int rescheduledSessions;
  final int cancelledSessions;
  final int inProgressSessions;
  final int pendingSessions;
  final int overdueSessions;
  final int upcomingSessions;
  final bool hasStrengthSessions;
  final int strengthSessionCount;
  final int cardioOrMobilitySessionCount;
  final double totalVolumeKg;
  final int totalDurationSeconds;
  final String startDate;
  final String endDate;
  final bool isElapsed;
  final bool isCurrent;
  final PlanWeekComparison? comparisonWithPrevious;

  const PlanWeekAnalytics({
    required this.blockOrdinal,
    this.blockName,
    required this.weekOrdinal,
    required this.displayWeekNumber,
    this.weekName,
    required this.isDeload,
    required this.plannedSessions,
    required this.completedSessions,
    required this.partiallyCompletedSessions,
    required this.skippedSessions,
    required this.rescheduledSessions,
    required this.cancelledSessions,
    required this.inProgressSessions,
    required this.pendingSessions,
    this.overdueSessions = 0,
    this.upcomingSessions = 0,
    required this.hasStrengthSessions,
    required this.strengthSessionCount,
    required this.cardioOrMobilitySessionCount,
    required this.totalVolumeKg,
    required this.totalDurationSeconds,
    required this.startDate,
    required this.endDate,
    required this.isElapsed,
    required this.isCurrent,
    this.comparisonWithPrevious,
  });
}

/// Week-over-week period comparison between consecutive active weeks.
class PlanWeekComparison {
  final double? volumeDeltaKg;
  final double? volumeDeltaPercentage;
  final int durationDeltaSeconds;
  final double? durationDeltaPercentage;
  final int completedDelta;
  final bool isDeloadComparison;
  final bool isCardioOrMobilityComparison;

  const PlanWeekComparison({
    this.volumeDeltaKg,
    this.volumeDeltaPercentage,
    required this.durationDeltaSeconds,
    this.durationDeltaPercentage,
    required this.completedDelta,
    required this.isDeloadComparison,
    required this.isCardioOrMobilityComparison,
  });
}

/// Pure deterministic calculator for plan analytics.
abstract final class PlanAnalyticsCalculator {
  static PlanAnalyticsSummary calculateSummary({
    required List<CalendarOccurrenceReadItem> occurrences,
    required List<B02ActivityHistoryItem> history,
    required int concurrentIndependentCount,
    required String todayLocalDate,
    required LocalScheduleDateService dates,
  }) {
    if (occurrences.isEmpty) {
      return PlanAnalyticsSummary.empty();
    }

    final historyByOccurrenceId = <String, B02ActivityHistoryItem>{};
    for (final item in history) {
      if (item.scheduledOccurrenceId != null) {
        assert(
          !historyByOccurrenceId.containsKey(item.scheduledOccurrenceId!),
          'Duplicate history session found for occurrence ${item.scheduledOccurrenceId}',
        );
        historyByOccurrenceId[item.scheduledOccurrenceId!] = item;
      }
    }

    var completedCount = 0;
    var partiallyCompletedCount = 0;
    var skippedCount = 0;
    var skippedAdvanceCount = 0;
    var skippedKeepPendingCount = 0;
    var rescheduledCount = 0;
    var cancelledCount = 0;
    var inProgressCount = 0;
    var pendingUpcomingCount = 0;
    var overdueCount = 0;
    var elapsedCount = 0;

    var totalVolumeKg = 0.0;
    var totalDurationSeconds = 0;
    var hasStrengthSessions = false;

    for (final item in occurrences) {
      final occ = item.occurrence;
      final status = occ.status;
      final isPast = dates.compare(occ.effectiveLocalDate, todayLocalDate) < 0;
      final isToday = occ.effectiveLocalDate == todayLocalDate;
      final isFuture = dates.compare(occ.effectiveLocalDate, todayLocalDate) > 0;

      if (item.template.activityType == B02ActivityType.strength.dbValue) {
        hasStrengthSessions = true;
      }

      final isRescheduled =
          occ.effectiveLocalDate != occ.originalLocalDate ||
          status == 'rescheduled';
      if (isRescheduled) {
        rescheduledCount++;
      }

      switch (status) {
        case 'completed':
          completedCount++;
          elapsedCount++;
          final h = historyByOccurrenceId[occ.id];
          if (h != null) {
            totalVolumeKg += h.totalVolumeKg;
            totalDurationSeconds += h.durationSeconds;
            if (h.totalVolumeKg > 0 ||
                h.activityType == B02ActivityType.strength) {
              hasStrengthSessions = true;
            }
          }
          break;
        case 'partiallyCompleted':
          partiallyCompletedCount++;
          elapsedCount++;
          final h = historyByOccurrenceId[occ.id];
          if (h != null) {
            totalVolumeKg += h.totalVolumeKg;
            totalDurationSeconds += h.durationSeconds;
            if (h.totalVolumeKg > 0 ||
                h.activityType == B02ActivityType.strength) {
              hasStrengthSessions = true;
            }
          }
          break;
        case 'skipped':
          skippedCount++;
          elapsedCount++;
          if (occ.skipMode == 'advance') {
            skippedAdvanceCount++;
          } else {
            // default or explicit 'keepPending'
            skippedKeepPendingCount++;
          }
          break;
        case 'cancelled':
          cancelledCount++;
          elapsedCount++;
          break;
        case 'inProgress':
          inProgressCount++;
          if (isPast || isToday) {
            elapsedCount++;
          }
          break;
        case 'planned':
        case 'rescheduled':
        default:
          if (isPast) {
            elapsedCount++;
            if (occ.progressionDisposition == 'pending') {
              overdueCount++;
            }
          } else if (isToday) {
            if (occ.progressionDisposition == 'pending') {
              pendingUpcomingCount++;
            }
          } else if (isFuture) {
            if (occ.progressionDisposition == 'pending') {
              pendingUpcomingCount++;
            }
          }
          break;
      }
    }

    final elapsedEligibleCount =
        elapsedCount > cancelledCount ? elapsedCount - cancelledCount : 0;

    double? strictAdherenceRate;
    double? compositeAdherenceRate;
    if (elapsedEligibleCount > 0) {
      strictAdherenceRate = completedCount / elapsedEligibleCount;
      compositeAdherenceRate =
          (completedCount + (0.5 * partiallyCompletedCount)) /
          elapsedEligibleCount;
    }

    return PlanAnalyticsSummary(
      totalScheduled: occurrences.length,
      completedCount: completedCount,
      partiallyCompletedCount: partiallyCompletedCount,
      skippedCount: skippedCount,
      skippedAdvanceCount: skippedAdvanceCount,
      skippedKeepPendingCount: skippedKeepPendingCount,
      rescheduledCount: rescheduledCount,
      cancelledCount: cancelledCount,
      inProgressCount: inProgressCount,
      pendingUpcomingCount: pendingUpcomingCount,
      overdueCount: overdueCount,
      concurrentIndependentCount: concurrentIndependentCount,
      totalVolumeKg: totalVolumeKg,
      totalDurationSeconds: totalDurationSeconds,
      hasStrengthSessions: hasStrengthSessions,
      elapsedCount: elapsedCount,
      elapsedEligibleCount: elapsedEligibleCount,
      strictAdherenceRate: strictAdherenceRate,
      compositeAdherenceRate: compositeAdherenceRate,
    );
  }

  static List<PlanWeekAnalytics> calculateWeeks({
    required List<CalendarOccurrenceReadItem> occurrences,
    required List<B02ActivityHistoryItem> history,
    required String todayLocalDate,
    required LocalScheduleDateService dates,
  }) {
    if (occurrences.isEmpty) {
      return const [];
    }

    final historyByOccurrenceId = <String, B02ActivityHistoryItem>{};
    for (final item in history) {
      if (item.scheduledOccurrenceId != null) {
        assert(
          !historyByOccurrenceId.containsKey(item.scheduledOccurrenceId!),
          'Duplicate history session found for occurrence ${item.scheduledOccurrenceId}',
        );
        historyByOccurrenceId[item.scheduledOccurrenceId!] = item;
      }
    }

    final weekGroups = <int, List<CalendarOccurrenceReadItem>>{};
    final weekKeys = <int>[];

    for (final item in occurrences) {
      final key = item.week.programWeekOrdinal;
      if (!weekGroups.containsKey(key)) {
        weekGroups[key] = [];
        weekKeys.add(key);
      }
      weekGroups[key]!.add(item);
    }

    weekKeys.sort();

    final result = <PlanWeekAnalytics>[];
    PlanWeekAnalytics? previousWeek;

    for (final weekOrdinal in weekKeys) {
      final weekOccurrences = weekGroups[weekOrdinal]!;
      final first = weekOccurrences.first;
      final blockOrdinal = first.block.ordinal;
      final blockName = first.block.name;
      final weekName = first.week.name;
      final isDeload = first.isDeload;

      final plannedSessions = weekOccurrences.length;
      var completedSessions = 0;
      var partiallyCompletedSessions = 0;
      var skippedSessions = 0;
      var rescheduledSessions = 0;
      var cancelledSessions = 0;
      var inProgressSessions = 0;
      var pendingSessions = 0;
      var overdueSessions = 0;
      var upcomingSessions = 0;

      var weekVolumeKg = 0.0;
      var weekDurationSeconds = 0;
      var strengthSessionCount = 0;
      var cardioOrMobilitySessionCount = 0;
      var plannedStrengthSessionCount = 0;

      var minDate = weekOccurrences.first.occurrence.effectiveLocalDate;
      var maxDate = weekOccurrences.first.occurrence.effectiveLocalDate;
      var isCurrent = false;
      var allTerminal = true;

      for (final item in weekOccurrences) {
        final occ = item.occurrence;
        final date = occ.effectiveLocalDate;
        if (dates.compare(date, minDate) < 0) minDate = date;
        if (dates.compare(date, maxDate) > 0) maxDate = date;

        if (date == todayLocalDate) {
          isCurrent = true;
        }

        if (item.template.activityType == B02ActivityType.strength.dbValue) {
          plannedStrengthSessionCount++;
        }

        if (occ.effectiveLocalDate != occ.originalLocalDate ||
            occ.status == 'rescheduled') {
          rescheduledSessions++;
        }

        switch (occ.status) {
          case 'completed':
            completedSessions++;
            final h = historyByOccurrenceId[occ.id];
            if (h != null) {
              weekVolumeKg += h.totalVolumeKg;
              weekDurationSeconds += h.durationSeconds;
              if (h.totalVolumeKg > 0 ||
                  h.activityType == B02ActivityType.strength) {
                strengthSessionCount++;
              } else {
                cardioOrMobilitySessionCount++;
              }
            }
            break;
          case 'partiallyCompleted':
            partiallyCompletedSessions++;
            final h = historyByOccurrenceId[occ.id];
            if (h != null) {
              weekVolumeKg += h.totalVolumeKg;
              weekDurationSeconds += h.durationSeconds;
              if (h.totalVolumeKg > 0 ||
                  h.activityType == B02ActivityType.strength) {
                strengthSessionCount++;
              } else {
                cardioOrMobilitySessionCount++;
              }
            }
            break;
          case 'skipped':
            skippedSessions++;
            break;
          case 'cancelled':
            cancelledSessions++;
            break;
          case 'inProgress':
            inProgressSessions++;
            allTerminal = false;
            break;
          case 'planned':
          case 'rescheduled':
          default:
            pendingSessions++;
            final isPastOccurrence =
                dates.compare(occ.effectiveLocalDate, todayLocalDate) < 0;
            if (isPastOccurrence) {
              overdueSessions++;
            } else {
              upcomingSessions++;
            }
            allTerminal = false;
            break;
        }
      }

      final isPast = dates.compare(maxDate, todayLocalDate) < 0;
      final isElapsed = isPast || allTerminal;
      final hasStrength =
          strengthSessionCount > 0 || plannedStrengthSessionCount > 0;

      PlanWeekComparison? comparison;
      if (previousWeek != null && isElapsed) {
        final prev = previousWeek;
        final durationDelta = weekDurationSeconds - prev.totalDurationSeconds;
        final durationDeltaPct = prev.totalDurationSeconds > 0
            ? (durationDelta / prev.totalDurationSeconds) * 100
            : null;
        final completedDelta = completedSessions - prev.completedSessions;
        final isDeloadComparison = isDeload || prev.isDeload;
        final isCardioOrMobility = !hasStrength || !prev.hasStrengthSessions;

        double? volumeDelta;
        double? volumeDeltaPct;
        if (!isCardioOrMobility) {
          volumeDelta = weekVolumeKg - prev.totalVolumeKg;
          if (prev.totalVolumeKg > 0) {
            volumeDeltaPct = (volumeDelta / prev.totalVolumeKg) * 100;
          }
        }

        comparison = PlanWeekComparison(
          volumeDeltaKg: volumeDelta,
          volumeDeltaPercentage: volumeDeltaPct,
          durationDeltaSeconds: durationDelta,
          durationDeltaPercentage: durationDeltaPct,
          completedDelta: completedDelta,
          isDeloadComparison: isDeloadComparison,
          isCardioOrMobilityComparison: isCardioOrMobility,
        );
      }

      final weekAnalytics = PlanWeekAnalytics(
        blockOrdinal: blockOrdinal,
        blockName: blockName,
        weekOrdinal: weekOrdinal,
        displayWeekNumber: weekOrdinal + 1,
        weekName: weekName,
        isDeload: isDeload,
        plannedSessions: plannedSessions,
        completedSessions: completedSessions,
        partiallyCompletedSessions: partiallyCompletedSessions,
        skippedSessions: skippedSessions,
        rescheduledSessions: rescheduledSessions,
        cancelledSessions: cancelledSessions,
        inProgressSessions: inProgressSessions,
        pendingSessions: pendingSessions,
        overdueSessions: overdueSessions,
        upcomingSessions: upcomingSessions,
        hasStrengthSessions: hasStrength,
        strengthSessionCount: strengthSessionCount,
        cardioOrMobilitySessionCount: cardioOrMobilitySessionCount,
        totalVolumeKg: weekVolumeKg,
        totalDurationSeconds: weekDurationSeconds,
        startDate: minDate,
        endDate: maxDate,
        isElapsed: isElapsed,
        isCurrent: isCurrent,
        comparisonWithPrevious: comparison,
      );

      result.add(weekAnalytics);
      previousWeek = weekAnalytics;
    }

    return result;
  }
}
