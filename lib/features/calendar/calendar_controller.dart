import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/di/providers.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/calendar_repository.dart';
import 'calendar_read_model.dart';

/// Provider for CalendarController managing reactive calendar UI state.
final calendarControllerProvider =
    StateNotifierProvider.autoDispose<CalendarController, CalendarUiState>((
      ref,
    ) {
      final db = ref.watch(databaseProvider);
      final calendarRepo = ref.watch(calendarRepositoryProvider);
      return CalendarController(db: db, calendarRepo: calendarRepo);
    });

class CalendarController extends StateNotifier<CalendarUiState> {
  final AppDatabase _db;
  final CalendarRepository _calendarRepo;
  final LocalScheduleDateService _dates;
  final Uuid _uuid;

  CalendarController({
    required AppDatabase db,
    required CalendarRepository calendarRepo,
    LocalScheduleDateService? dates,
    Uuid? uuid,
  }) : _db = db,
       _calendarRepo = calendarRepo,
       _dates = dates ?? LocalScheduleDateService(),
       _uuid = uuid ?? const Uuid(),
       super(
         CalendarUiState(
           selectedLocalDate: (dates ?? LocalScheduleDateService()).todayIn(
             'UTC',
           ),
           timezoneId: 'UTC',
           isLoading: true,
         ),
       ) {
    loadCalendarData();
  }

  @visibleForTesting
  CalendarUiState get currentState => state;

  /// Sets the selected date and reloads date-specific occurrences.
  Future<void> selectDate(String localDate) async {
    final normalized = _dates.normalizeLocalDate(localDate);
    state = state.copyWith(selectedLocalDate: normalized);
    await loadCalendarData();
  }

  /// Loads range and date occurrences for the active calendar view.
  Future<void> loadCalendarData({
    String? startLocalDate,
    String? endLocalDate,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final today = _dates.todayIn(state.timezoneId);
      final targetDate = state.selectedLocalDate;

      final rangeStart =
          startLocalDate ??
          _dates.addCalendarDays(targetDate, state.timezoneId, -14);
      final rangeEnd =
          endLocalDate ??
          _dates.addCalendarDays(targetDate, state.timezoneId, 14);

      // 1. Fetch occurrences from CalendarRepository
      final rangeOccurrencesRaw = await _calendarRepo
          .getOccurrencesInLocalDateRange(
            startLocalDate: rangeStart,
            endLocalDate: rangeEnd,
            includeTerminal: true,
          );

      // 2. Build rich CalendarOccurrenceItems
      final rangeItems = await _hydrateOccurrenceItems(
        rangeOccurrencesRaw,
        today,
      );

      final dateItems = rangeItems
          .where((item) => item.occurrence.effectiveLocalDate == targetDate)
          .toList();

      // Sort date items by plannedStartMinute (nulls last) and sessionOrdinal
      dateItems.sort((a, b) {
        final minuteA = a.template.plannedStartMinute;
        final minuteB = b.template.plannedStartMinute;
        if (minuteA != null && minuteB != null) {
          if (minuteA != minuteB) return minuteA.compareTo(minuteB);
        } else if (minuteA != null) {
          return -1;
        } else if (minuteB != null) {
          return 1;
        }
        return a.occurrence.sessionOrdinal.compareTo(
          b.occurrence.sessionOrdinal,
        );
      });

      // 3. Fetch overdue occurrences (effectiveLocalDate < today & status == 'planned')
      final overdueRaw =
          await (_db.select(_db.scheduledSessionOccurrences)
                ..where(
                  (t) =>
                      t.effectiveLocalDate.isSmallerThanValue(today) &
                      t.status.equals('planned') &
                      t.progressionDisposition.equals('pending'),
                )
                ..orderBy([
                  (t) => OrderingTerm(expression: t.effectiveLocalDate),
                ]))
              .get();

      final overdueItems = await _hydrateOccurrenceItems(overdueRaw, today);

      // 4. Fetch active program version info
      final settings = await (_db.select(
        _db.trainingPlanSettings,
      )..where((t) => t.id.equals(1))).getSingleOrNull();
      String? activeVersionId = settings?.activeProgramVersionId;
      String? activeProgName;

      if (activeVersionId != null) {
        final version = await (_db.select(
          _db.programVersions,
        )..where((t) => t.id.equals(activeVersionId))).getSingleOrNull();
        if (version != null) {
          final prog = await (_db.select(
            _db.programs,
          )..where((t) => t.id.equals(version.programId))).getSingleOrNull();
          activeProgName = prog?.name;
        }
      }

      state = state.copyWith(
        rangeOccurrences: rangeItems,
        selectedDateOccurrences: dateItems,
        overdueOccurrences: overdueItems,
        isLoading: false,
        activeProgramVersionId: activeVersionId,
        activeProgramName: activeProgName,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Reschedules an occurrence to a new local date.
  Future<void> rescheduleOccurrence(
    String occurrenceId,
    String targetLocalDate, {
    String? reason,
  }) async {
    final occurrence = await _calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw StateError('Occurrence $occurrenceId not found.');
    }

    final command = RescheduleOccurrenceCommand(
      occurrenceId: occurrenceId,
      commandId: _uuid.v4(),
      expectedStatus: OccurrenceStatus.values.firstWhere(
        (s) => s.dbValue == occurrence.status,
      ),
      effectiveLocalDate: targetLocalDate,
      effectiveTimezoneId: state.timezoneId,
      confirmed: true,
      reason: reason,
    );

    await _calendarRepo.reschedule(command);
    await loadCalendarData();
  }

  /// Skips an occurrence.
  Future<void> skipOccurrence(
    String occurrenceId, {
    SkipDisposition disposition = SkipDisposition.advance,
    String? reason,
  }) async {
    final occurrence = await _calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw StateError('Occurrence $occurrenceId not found.');
    }

    final command = SkipOccurrenceCommand(
      occurrenceId: occurrenceId,
      commandId: _uuid.v4(),
      expectedStatus: OccurrenceStatus.values.firstWhere(
        (s) => s.dbValue == occurrence.status,
      ),
      disposition: disposition,
      reason: reason,
    );

    await _calendarRepo.skip(command);
    await loadCalendarData();
  }

  /// Cancels an occurrence.
  Future<void> cancelOccurrence(String occurrenceId, {String? reason}) async {
    final occurrence = await _calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw StateError('Occurrence $occurrenceId not found.');
    }

    final command = CancelOccurrenceCommand(
      occurrenceId: occurrenceId,
      commandId: _uuid.v4(),
      expectedStatus: OccurrenceStatus.values.firstWhere(
        (s) => s.dbValue == occurrence.status,
      ),
      reason: reason,
    );

    await _calendarRepo.cancel(command);
    await loadCalendarData();
  }

  /// Repeats an occurrence for extra or make-up work.
  Future<void> repeatOccurrence(
    String occurrenceId,
    String targetLocalDate, {
    RepeatPurpose purpose = RepeatPurpose.extra,
  }) async {
    final occurrence = await _calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw StateError('Occurrence $occurrenceId not found.');
    }

    final command = RepeatOccurrenceCommand(
      occurrenceId: occurrenceId,
      commandId: _uuid.v4(),
      expectedStatus: OccurrenceStatus.values.firstWhere(
        (s) => s.dbValue == occurrence.status,
      ),
      localDate: targetLocalDate,
      timezoneId: state.timezoneId,
      purpose: purpose,
    );

    await _calendarRepo.repeat(command);
    await loadCalendarData();
  }

  // --- Helper Methods ---

  Future<List<CalendarOccurrenceItem>> _hydrateOccurrenceItems(
    List<ScheduledSessionOccurrence> occurrences,
    String today,
  ) async {
    final result = <CalendarOccurrenceItem>[];

    for (final occ in occurrences) {
      final tmpl = await (_db.select(
        _db.sessionTemplates,
      )..where((t) => t.id.equals(occ.sessionTemplateId))).getSingleOrNull();
      if (tmpl == null) continue;

      final week = await (_db.select(
        _db.programWeeks,
      )..where((t) => t.id.equals(tmpl.programWeekId))).getSingleOrNull();
      if (week == null) continue;

      final block = await (_db.select(
        _db.programBlocks,
      )..where((t) => t.id.equals(week.programBlockId))).getSingleOrNull();
      if (block == null) continue;

      final version = await (_db.select(
        _db.programVersions,
      )..where((t) => t.id.equals(occ.programVersionId))).getSingleOrNull();
      if (version == null) continue;

      final prog = await (_db.select(
        _db.programs,
      )..where((t) => t.id.equals(version.programId))).getSingleOrNull();
      if (prog == null) continue;

      final prescriptions =
          await (_db.select(_db.exercisePrescriptions)
                ..where((t) => t.sessionTemplateId.equals(tmpl.id))
                ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
              .get();

      final isOverdue =
          occ.status == 'planned' &&
          _dates.compare(occ.effectiveLocalDate, today) < 0;

      result.add(
        CalendarOccurrenceItem(
          occurrence: occ,
          template: tmpl,
          week: week,
          block: block,
          version: version,
          program: prog,
          prescriptions: prescriptions,
          isOverdue: isOverdue,
          isDeload: week.isDeload,
        ),
      );
    }

    return result;
  }
}
