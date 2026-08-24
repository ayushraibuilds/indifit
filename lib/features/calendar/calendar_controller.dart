import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../data/database/app_database.dart' show ScheduledSessionOccurrence;
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import 'calendar_read_model.dart';

/// Calendar state is ephemeral Riverpod state. It has no SharedPreferences or
/// Drift mirror; durable schedule state is read exclusively from repositories.
final calendarControllerProvider =
    StateNotifierProvider.autoDispose<CalendarController, CalendarUiState>((
      ref,
    ) {
      final controller = CalendarController(
        calendarRepo: ref.watch(calendarRepositoryProvider),
        readRepo: ref.watch(calendarReadRepositoryProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
      );
      return controller;
    });

class CalendarController extends StateNotifier<CalendarUiState> {
  final CalendarRepository _calendarRepo;
  final CalendarReadRepository _readRepo;
  final LocalScheduleDateService _dates;
  final Uuid _uuid;
  StreamSubscription<void>? _subscription;
  var _generation = 0;

  CalendarController({
    required CalendarRepository calendarRepo,
    required CalendarReadRepository readRepo,
    LocalScheduleDateService? dates,
    Uuid? uuid,
    String timezoneId = 'UTC',
    String? initialLocalDate,
  }) : _calendarRepo = calendarRepo,
       _readRepo = readRepo,
       _dates = dates ?? LocalScheduleDateService(),
       _uuid = uuid ?? const Uuid(),
       super(
         CalendarUiState(
           selectedLocalDate: initialLocalDate != null
               ? (dates ?? LocalScheduleDateService())
                   .normalizeLocalDate(initialLocalDate)
               : (dates ?? LocalScheduleDateService()).todayIn(
                   timezoneId,
                 ),
           timezoneId: timezoneId,
           isLoading: true,
         ),
       ) {
    _dates.validateTimezone(timezoneId);
    _subscribe();
  }

  @visibleForTesting
  CalendarUiState get currentState => state;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> selectDate(String localDate) async {
    state = state.copyWith(
      selectedLocalDate: _dates.normalizeLocalDate(localDate),
    );
    await _subscribe();
  }

  Future<void> setView(CalendarView view) async {
    state = state.copyWith(view: view);
    await _subscribe();
  }

  Future<void> setTimezone(String timezoneId) async {
    _dates.validateTimezone(timezoneId);
    state = state.copyWith(timezoneId: timezoneId);
    await _subscribe();
  }

  /// Bounded manual refresh used after a controller command. Stream updates
  /// also refresh this state when another feature changes an occurrence.
  Future<void> refresh() => _subscribe();

  Future<void> rescheduleOccurrence(
    String occurrenceId,
    String targetLocalDate, {
    required bool confirmed,
    String? effectiveTimezoneId,
    String? reason,
  }) async {
    final occurrence = await _requireOccurrence(occurrenceId);
    await _calendarRepo.reschedule(
      RescheduleOccurrenceCommand(
        occurrenceId: occurrenceId,
        commandId: _uuid.v4(),
        expectedStatus: _status(occurrence.status),
        effectiveLocalDate: targetLocalDate,
        effectiveTimezoneId:
            effectiveTimezoneId ?? occurrence.effectiveTimezoneId,
        confirmed: confirmed,
        reason: reason,
      ),
    );
    await refresh();
  }

  /// The caller must explicitly choose the accepted product decision. There
  /// is intentionally no default disposition.
  Future<void> skipOccurrence(
    String occurrenceId, {
    required SkipDisposition disposition,
    String? reason,
  }) async {
    final occurrence = await _requireOccurrence(occurrenceId);
    await _calendarRepo.skip(
      SkipOccurrenceCommand(
        occurrenceId: occurrenceId,
        commandId: _uuid.v4(),
        expectedStatus: _status(occurrence.status),
        disposition: disposition,
        reason: reason,
      ),
    );
    await refresh();
  }

  Future<void> cancelOccurrence(String occurrenceId, {String? reason}) async {
    final occurrence = await _requireOccurrence(occurrenceId);
    await _calendarRepo.cancel(
      CancelOccurrenceCommand(
        occurrenceId: occurrenceId,
        commandId: _uuid.v4(),
        expectedStatus: _status(occurrence.status),
        reason: reason,
      ),
    );
    await refresh();
  }

  /// Restoring a skipped or cancelled occurrence is guarded by the repository
  /// so a later started dependent can never be silently rewound from the UI.
  Future<void> restoreOccurrence(String occurrenceId) async {
    final occurrence = await _requireOccurrence(occurrenceId);
    await _calendarRepo.restore(
      RestoreOccurrenceCommand(
        occurrenceId: occurrenceId,
        commandId: _uuid.v4(),
        expectedStatus: _status(occurrence.status),
      ),
    );
    await refresh();
  }

  Future<void> repeatOccurrence(
    String occurrenceId,
    String targetLocalDate, {
    required RepeatPurpose purpose,
    String? timezoneId,
  }) async {
    final occurrence = await _requireOccurrence(occurrenceId);
    await _calendarRepo.repeat(
      RepeatOccurrenceCommand(
        occurrenceId: occurrenceId,
        commandId: _uuid.v4(),
        expectedStatus: _status(occurrence.status),
        localDate: targetLocalDate,
        timezoneId: timezoneId ?? occurrence.effectiveTimezoneId,
        purpose: purpose,
      ),
    );
    await refresh();
  }

  Future<void> _subscribe() async {
    final generation = ++_generation;
    await _subscription?.cancel();
    if (!mounted || generation != _generation) return;
    final bounds = _boundsForState();
    state = state.copyWith(isLoading: true, clearError: true);
    _subscription = _readRepo
        .watchInvalidation(
          startLocalDate: bounds.start,
          endLocalDate: bounds.end,
          timezoneId: state.timezoneId,
        )
        .listen(
          (_) {
            unawaited(_loadSnapshot(bounds, generation));
          },
          onError: (Object error, StackTrace _) {
            if (!mounted || generation != _generation) return;
            state = state.copyWith(
              isLoading: false,
              errorMessage: ProductFailurePresentation.fromError(
                error,
                title: 'Calendar unavailable',
                code: 'calendar_unavailable',
              ).message,
            );
          },
        );
    await _loadSnapshot(bounds, generation);
  }

  Future<void> _loadSnapshot(
    ({String start, String end}) bounds,
    int generation,
  ) async {
    try {
      final snapshot = await _readRepo.readSnapshot(
        startLocalDate: bounds.start,
        endLocalDate: bounds.end,
        timezoneId: state.timezoneId,
      );
      if (mounted && generation == _generation) {
        _applySnapshot(snapshot, generation);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: ProductFailurePresentation.fromError(
            error,
            title: 'Calendar unavailable',
            code: 'calendar_unavailable',
          ).message,
        );
      }
    }
  }

  void _applySnapshot(CalendarReadSnapshot snapshot, int generation) {
    if (!mounted || generation != _generation) return;
    final selected =
        snapshot.rangeOccurrences
            .where(
              (item) =>
                  item.occurrence.effectiveLocalDate == state.selectedLocalDate,
            )
            .toList()
          ..sort(_sameDateOrder);
    state = state.copyWith(
      selectedDateOccurrences: selected,
      rangeOccurrences: snapshot.rangeOccurrences,
      overdueOccurrences: snapshot.overdueOccurrences,
      activeProgramVersionId: snapshot.activeProgramVersionId,
      activeProgramName: snapshot.activeProgramName,
      isLoading: false,
      clearError: true,
    );
  }

  ({String start, String end}) _boundsForState() {
    final date = state.selectedLocalDate;
    return switch (state.view) {
      CalendarView.day => (start: date, end: date),
      CalendarView.week => _weekBounds(date),
      CalendarView.month => _monthBounds(date),
    };
  }

  ({String start, String end}) _weekBounds(String localDate) {
    final weekday = _dates.weekday(localDate, state.timezoneId);
    return (
      start: _dates.addCalendarDays(localDate, state.timezoneId, 1 - weekday),
      end: _dates.addCalendarDays(localDate, state.timezoneId, 7 - weekday),
    );
  }

  ({String start, String end}) _monthBounds(String localDate) {
    final normalized = _dates.normalizeLocalDate(localDate);
    final year = int.parse(normalized.substring(0, 4));
    final month = int.parse(normalized.substring(5, 7));
    final first =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    final finalDay = DateTime.utc(year, month + 1, 0).day;
    final last =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${finalDay.toString().padLeft(2, '0')}';
    return (start: first, end: last);
  }

  Future<ScheduledSessionOccurrence> _requireOccurrence(
    String occurrenceId,
  ) async {
    final occurrence = await _calendarRepo.getOccurrence(occurrenceId);
    if (occurrence == null) {
      throw StateError('Occurrence $occurrenceId not found.');
    }
    return occurrence;
  }

  static OccurrenceStatus _status(String dbValue) =>
      OccurrenceStatus.values.firstWhere((status) => status.dbValue == dbValue);

  static int _sameDateOrder(
    CalendarOccurrenceReadItem first,
    CalendarOccurrenceReadItem second,
  ) {
    final firstMinute = first.template.plannedStartMinute;
    final secondMinute = second.template.plannedStartMinute;
    if (firstMinute != null &&
        secondMinute != null &&
        firstMinute != secondMinute) {
      return firstMinute.compareTo(secondMinute);
    }
    if (firstMinute != null && secondMinute == null) return -1;
    if (firstMinute == null && secondMinute != null) return 1;
    final bySession = first.occurrence.sessionOrdinal.compareTo(
      second.occurrence.sessionOrdinal,
    );
    return bySession != 0
        ? bySession
        : first.occurrence.repeatOrdinal.compareTo(
            second.occurrence.repeatOrdinal,
          );
  }
}
