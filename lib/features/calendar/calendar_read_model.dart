import '../../data/repositories/calendar_read_repository.dart';

enum CalendarView { day, week, month }

/// Reactive UI state for calendar navigation and occurrence management.
class CalendarUiState {
  final String selectedLocalDate;
  final String timezoneId;
  final CalendarView view;
  final List<CalendarOccurrenceReadItem> selectedDateOccurrences;
  final List<CalendarOccurrenceReadItem> rangeOccurrences;
  final List<CalendarOccurrenceReadItem> overdueOccurrences;
  final bool isLoading;
  final String? errorMessage;
  final String? activeProgramVersionId;
  final String? activeProgramName;

  const CalendarUiState({
    required this.selectedLocalDate,
    required this.timezoneId,
    this.view = CalendarView.week,
    this.selectedDateOccurrences = const [],
    this.rangeOccurrences = const [],
    this.overdueOccurrences = const [],
    this.isLoading = false,
    this.errorMessage,
    this.activeProgramVersionId,
    this.activeProgramName,
  });

  CalendarUiState copyWith({
    String? selectedLocalDate,
    String? timezoneId,
    CalendarView? view,
    List<CalendarOccurrenceReadItem>? selectedDateOccurrences,
    List<CalendarOccurrenceReadItem>? rangeOccurrences,
    List<CalendarOccurrenceReadItem>? overdueOccurrences,
    bool? isLoading,
    String? errorMessage,
    String? activeProgramVersionId,
    String? activeProgramName,
    bool clearError = false,
  }) {
    return CalendarUiState(
      selectedLocalDate: selectedLocalDate ?? this.selectedLocalDate,
      timezoneId: timezoneId ?? this.timezoneId,
      view: view ?? this.view,
      selectedDateOccurrences:
          selectedDateOccurrences ?? this.selectedDateOccurrences,
      rangeOccurrences: rangeOccurrences ?? this.rangeOccurrences,
      overdueOccurrences: overdueOccurrences ?? this.overdueOccurrences,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      activeProgramVersionId:
          activeProgramVersionId ?? this.activeProgramVersionId,
      activeProgramName: activeProgramName ?? this.activeProgramName,
    );
  }
}
