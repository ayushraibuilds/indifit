import '../../core/services/local_schedule_date_service.dart';
import '../models/plan_analytics_models.dart';
import 'b02_execution_compatibility_read_repository.dart';
import 'calendar_read_repository.dart';
import 'plan_library_read_repository.dart';

/// Read-only composition for the C.9 plan overview.
///
/// Program/version structure, materialized occurrences, and saved history
/// remain owned by their existing repositories. This object only joins them
/// by the exact version and occurrence identities already persisted.
class PlanOverviewSnapshot {
  const PlanOverviewSnapshot({
    required this.entry,
    required this.occurrences,
    required this.history,
    required this.concurrentIndependentHistory,
    required this.totalIndependentCount,
    required this.analytics,
    required this.weekAnalytics,
  });

  final PlanLibraryEntry entry;
  final List<CalendarOccurrenceReadItem> occurrences;
  final List<B02ActivityHistoryItem> history;
  final List<B02ActivityHistoryItem> concurrentIndependentHistory;
  final int totalIndependentCount;
  final PlanAnalyticsSummary analytics;
  final List<PlanWeekAnalytics> weekAnalytics;

  bool get isCurrent => entry.isActive;

  List<CalendarOccurrenceReadItem> get upcomingOccurrences => occurrences
      .where(
        (item) =>
            item.occurrence.status == 'planned' ||
            item.occurrence.status == 'rescheduled',
      )
      .toList(growable: false);

  List<CalendarOccurrenceReadItem> get completedOccurrences => occurrences
      .where(
        (item) =>
            item.occurrence.status == 'completed' ||
            item.occurrence.status == 'partiallyCompleted',
      )
      .toList(growable: false);
}

class PlanOverviewReadRepository {
  PlanOverviewReadRepository({
    required this.plans,
    required this.calendar,
    required this.history,
    LocalScheduleDateService? dates,
  }) : dates = dates ?? LocalScheduleDateService();

  final PlanLibraryReadRepository plans;
  final CalendarReadRepository calendar;
  final B02ExecutionCompatibilityReadRepository history;
  final LocalScheduleDateService dates;

  Future<PlanOverviewSnapshot?> read({
    required String versionId,
    required String timezoneId,
  }) async {
    final entry = await plans.readVersion(versionId);
    if (entry == null) return null;

    final occurrences = await calendar.readOccurrencesForVersion(
      programVersionId: entry.version.id,
      timezoneId: timezoneId,
    );
    final occurrenceIds = occurrences.map((item) => item.occurrence.id).toSet();

    // Bounded query by exact occurrence ID (fixes silent 500-cap undercounting)
    final matchingHistory = await history.readHistoryForOccurrences(
      occurrenceIds,
    );

    final today = dates.todayIn(timezoneId);
    final independentResult = await _readIndependentHistory(
      occurrences: occurrences,
      timezoneId: timezoneId,
      todayLocalDate: today,
    );

    final analytics = PlanAnalyticsCalculator.calculateSummary(
      occurrences: occurrences,
      history: matchingHistory,
      concurrentIndependentCount: independentResult.totalCount,
      todayLocalDate: today,
      dates: dates,
    );

    final weekAnalytics = PlanAnalyticsCalculator.calculateWeeks(
      occurrences: occurrences,
      history: matchingHistory,
      todayLocalDate: today,
      dates: dates,
    );

    return PlanOverviewSnapshot(
      entry: entry,
      occurrences: List.unmodifiable(occurrences),
      history: List.unmodifiable(matchingHistory),
      concurrentIndependentHistory: List.unmodifiable(independentResult.items),
      totalIndependentCount: independentResult.totalCount,
      analytics: analytics,
      weekAnalytics: List.unmodifiable(weekAnalytics),
    );
  }

  Future<({List<B02ActivityHistoryItem> items, int totalCount})>
  _readIndependentHistory({
    required List<CalendarOccurrenceReadItem> occurrences,
    required String timezoneId,
    required String todayLocalDate,
  }) async {
    if (occurrences.isEmpty) {
      return (items: const <B02ActivityHistoryItem>[], totalCount: 0);
    }

    var minDate = occurrences.first.occurrence.effectiveLocalDate;
    var maxDate = occurrences.first.occurrence.effectiveLocalDate;
    for (final item in occurrences) {
      final d = item.occurrence.effectiveLocalDate;
      if (dates.compare(d, minDate) < 0) minDate = d;
      if (dates.compare(d, maxDate) > 0) maxDate = d;
    }

    final effectiveEndDate = dates.compare(todayLocalDate, maxDate) > 0
        ? todayLocalDate
        : maxDate;
    final nextDay = dates.addCalendarDays(effectiveEndDate, timezoneId, 1);

    final startUtc = dates.instantForLocalDate(minDate, timezoneId, hour: 0);
    final endUtc = dates.instantForLocalDate(nextDay, timezoneId, hour: 0);

    return history.readIndependentHistory(
      completedAtStartUtc: startUtc,
      completedAtEndExclusiveUtc: endUtc,
      limit: 100,
    );
  }
}
