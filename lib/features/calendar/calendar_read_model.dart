import '../../data/database/app_database.dart';

/// Rich read model representing a scheduled occurrence item with full program hierarchy context.
class CalendarOccurrenceItem {
  final ScheduledSessionOccurrence occurrence;
  final SessionTemplate template;
  final ProgramWeek week;
  final ProgramBlock block;
  final ProgramVersion version;
  final Program program;
  final List<ExercisePrescription> prescriptions;
  final bool isOverdue;
  final bool isDeload;

  const CalendarOccurrenceItem({
    required this.occurrence,
    required this.template,
    required this.week,
    required this.block,
    required this.version,
    required this.program,
    required this.prescriptions,
    required this.isOverdue,
    required this.isDeload,
  });
}

/// Reactive UI state for calendar navigation and occurrence management.
class CalendarUiState {
  final String selectedLocalDate;
  final String timezoneId;
  final List<CalendarOccurrenceItem> selectedDateOccurrences;
  final List<CalendarOccurrenceItem> rangeOccurrences;
  final List<CalendarOccurrenceItem> overdueOccurrences;
  final bool isLoading;
  final String? errorMessage;
  final String? activeProgramVersionId;
  final String? activeProgramName;

  const CalendarUiState({
    required this.selectedLocalDate,
    required this.timezoneId,
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
    List<CalendarOccurrenceItem>? selectedDateOccurrences,
    List<CalendarOccurrenceItem>? rangeOccurrences,
    List<CalendarOccurrenceItem>? overdueOccurrences,
    bool? isLoading,
    String? errorMessage,
    String? activeProgramVersionId,
    String? activeProgramName,
  }) {
    return CalendarUiState(
      selectedLocalDate: selectedLocalDate ?? this.selectedLocalDate,
      timezoneId: timezoneId ?? this.timezoneId,
      selectedDateOccurrences:
          selectedDateOccurrences ?? this.selectedDateOccurrences,
      rangeOccurrences: rangeOccurrences ?? this.rangeOccurrences,
      overdueOccurrences: overdueOccurrences ?? this.overdueOccurrences,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeProgramVersionId:
          activeProgramVersionId ?? this.activeProgramVersionId,
      activeProgramName: activeProgramName ?? this.activeProgramName,
    );
  }
}
