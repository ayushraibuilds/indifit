import '../database/app_database.dart';
import 'calendar_read_repository.dart';

/// The small, shared read boundary for the current/next workout decision.
///
/// B01 remains the authority for program activation, occurrence status,
/// progression disposition and civil dates. This resolver only projects that
/// authority for consumer surfaces; it never writes state or infers a plan
/// from history or display names.
class TrainingNextActionResolution {
  const TrainingNextActionResolution({
    required this.localDate,
    required this.activeProgramVersionId,
    required this.activeDraft,
    this.activeDraftReadAvailable = true,
    required this.currentOccurrence,
    required this.todayOccurrence,
    required this.overdueOccurrence,
    required this.nextOccurrence,
    required this.todayCompletedOccurrence,
    required this.upcomingOccurrences,
  });

  final String localDate;
  final String? activeProgramVersionId;
  final WorkoutDraft? activeDraft;

  /// False means B02 could not establish whether an active draft exists.
  /// Consumers must not offer Start while this state is unknown.
  final bool activeDraftReadAvailable;

  /// The occurrence currently being executed, when the active draft or B01
  /// state links one. An unscheduled Quick Workout has no occurrence identity.
  final CalendarOccurrenceReadItem? currentOccurrence;

  /// The first actionable occurrence on [localDate]. Terminal history is
  /// intentionally excluded so a completed workout cannot remain Next Up.
  final CalendarOccurrenceReadItem? todayOccurrence;

  /// The first still-pending occurrence before [localDate]. B01 treats this
  /// as overdue display state; it is not auto-skipped or silently advanced.
  final CalendarOccurrenceReadItem? overdueOccurrence;

  /// The next required/actionable scheduled occurrence after the current
  /// local date. A pending overdue occurrence wins when B01 exposes one.
  final CalendarOccurrenceReadItem? nextOccurrence;

  /// Terminal evidence for the active plan on [localDate]. This is suitable
  /// for history/status presentation, never for a Start or Resume action.
  final CalendarOccurrenceReadItem? todayCompletedOccurrence;

  /// Future actionable occurrences in canonical occurrence order. This is a
  /// presentation list, while [nextOccurrence] is the single current/next
  /// decision.
  final List<CalendarOccurrenceReadItem> upcomingOccurrences;

  bool get hasResumableDraft => activeDraft != null;

  /// Exact occurrence identity for cross-surface assertions and action
  /// routing. It never falls back to a name or a derived movement key.
  String? get currentOrNextOccurrenceId =>
      currentOccurrence?.occurrence.id ??
      todayOccurrence?.occurrence.id ??
      nextOccurrence?.occurrence.id;
}

/// Resolves Today and Training state from the same B01/B02 inputs.
///
/// [snapshot] may contain terminal rows from older plans for history and
/// calendar inspection. They are filtered out here unless they belong to the
/// currently active plan, and terminal rows never become current/next work.
TrainingNextActionResolution resolveTrainingNextAction({
  required CalendarReadSnapshot snapshot,
  required String localDate,
  WorkoutDraft? activeDraft,
  bool activeDraftReadAvailable = true,
}) {
  final activeVersionId = snapshot.activeProgramVersionId;
  final all = <String, CalendarOccurrenceReadItem>{};
  for (final item in [
    ...snapshot.rangeOccurrences,
    ...snapshot.overdueOccurrences,
  ]) {
    all[item.occurrence.id] = item;
  }

  // No active program means there is no scheduled current/next workout. A
  // standalone active draft can still be resumed, so it remains in the
  // resolution independently of scheduled occurrences.
  final activeOccurrences = activeVersionId == null
      ? const <CalendarOccurrenceReadItem>[]
      : all.values
            .where(
              (item) => item.occurrence.programVersionId == activeVersionId,
            )
            .toList(growable: false);

  final ordered = [...activeOccurrences]..sort(_compareOccurrences);
  final actionable = ordered
      .where(
        (item) =>
            _isActionableOccurrence(item, allowInProgress: activeDraft != null),
      )
      .toList(growable: false);

  CalendarOccurrenceReadItem? linkedToDraft;
  final scheduledDraftId = activeDraft?.scheduledOccurrenceId;
  if (scheduledDraftId != null) {
    for (final item in activeOccurrences) {
      if (item.occurrence.id == scheduledDraftId) {
        linkedToDraft = item;
        break;
      }
    }
  }

  final current = linkedToDraft;
  final today = _firstWhere(
    actionable,
    (item) => item.occurrence.effectiveLocalDate == localDate,
  );
  final overdue = _firstWhere(
    actionable,
    (item) => item.occurrence.effectiveLocalDate.compareTo(localDate) < 0,
  );

  // B01 marks the lowest pending root as isNextRequired. Prefer it even when
  // it is overdue; only fall back to the earliest actionable row for legacy
  // or hand-built read fixtures that do not carry the derived flag.
  final nextRequired = _firstWhere(actionable, (item) => item.isNextRequired);
  final next =
      nextRequired ??
      _firstWhere(
        actionable,
        (item) => item.occurrence.effectiveLocalDate.compareTo(localDate) > 0,
      );

  final completedToday = _firstWhere(
    ordered,
    (item) =>
        item.occurrence.effectiveLocalDate == localDate &&
        (item.occurrence.status == 'completed' ||
            item.occurrence.status == 'partiallyCompleted'),
  );
  final upcoming = actionable
      .where(
        (item) => item.occurrence.effectiveLocalDate.compareTo(localDate) > 0,
      )
      .toList(growable: false);

  return TrainingNextActionResolution(
    localDate: localDate,
    activeProgramVersionId: activeVersionId,
    activeDraft: activeDraft,
    activeDraftReadAvailable: activeDraftReadAvailable,
    currentOccurrence: current,
    todayOccurrence: today,
    overdueOccurrence: overdue,
    nextOccurrence: next,
    todayCompletedOccurrence: completedToday,
    upcomingOccurrences: upcoming,
  );
}

bool _isActionableOccurrence(
  CalendarOccurrenceReadItem item, {
  required bool allowInProgress,
}) {
  final status = item.occurrence.status;
  return status == 'planned' ||
      status == 'rescheduled' ||
      (allowInProgress && status == 'inProgress');
}

/// The current Training/Today surfaces can resume the two persisted workout
/// forms they already support: canonical B02 strength drafts and legacy
/// strength drafts handled by the compatibility player. Other activity
/// drafts remain owned by their existing activity surface and must not make
/// these two surfaces disagree about a strength Resume action.
bool isTrainingResumableDraft(WorkoutDraft draft) =>
    draft.activityType == 'strength';

CalendarOccurrenceReadItem? _firstWhere(
  Iterable<CalendarOccurrenceReadItem> items,
  bool Function(CalendarOccurrenceReadItem) test,
) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

int _compareOccurrences(
  CalendarOccurrenceReadItem first,
  CalendarOccurrenceReadItem second,
) {
  var result = first.occurrence.effectiveLocalDate.compareTo(
    second.occurrence.effectiveLocalDate,
  );
  if (result != 0) return result;
  result = first.occurrence.programWeekOrdinal.compareTo(
    second.occurrence.programWeekOrdinal,
  );
  if (result != 0) return result;
  result = first.occurrence.sessionOrdinal.compareTo(
    second.occurrence.sessionOrdinal,
  );
  if (result != 0) return result;
  result = first.occurrence.repeatOrdinal.compareTo(
    second.occurrence.repeatOrdinal,
  );
  if (result != 0) return result;
  return first.occurrence.id.compareTo(second.occurrence.id);
}
