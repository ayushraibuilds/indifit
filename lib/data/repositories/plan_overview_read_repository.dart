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
  });

  final PlanLibraryEntry entry;
  final List<CalendarOccurrenceReadItem> occurrences;
  final List<B02ActivityHistoryItem> history;

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
  const PlanOverviewReadRepository({
    required this.plans,
    required this.calendar,
    required this.history,
  });

  final PlanLibraryReadRepository plans;
  final CalendarReadRepository calendar;
  final B02ExecutionCompatibilityReadRepository history;

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
    final historyItems = await history.readHistory(limit: 500);
    final matchingHistory = historyItems
        .where(
          (item) =>
              item.scheduledOccurrenceId != null &&
              occurrenceIds.contains(item.scheduledOccurrenceId),
        )
        .toList(growable: false);

    return PlanOverviewSnapshot(
      entry: entry,
      occurrences: List.unmodifiable(occurrences),
      history: List.unmodifiable(matchingHistory),
    );
  }
}
