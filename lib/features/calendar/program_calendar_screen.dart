import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_count_label.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../travel/travel_controller.dart';
import 'calendar_controller.dart';
import 'calendar_read_model.dart';
import 'occurrence_actions_sheet.dart';
import 'workout_contextual_actions.dart';

/// Training calendar screen providing Day, Week, and Month schedule and history
/// navigation using canonical B01 occurrence state.
class ProgramCalendarScreen extends ConsumerStatefulWidget {
  const ProgramCalendarScreen({super.key, this.initialLocalDate});

  final String? initialLocalDate;

  @override
  ConsumerState<ProgramCalendarScreen> createState() =>
      _ProgramCalendarScreenState();

  static bool _isLocalDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse('${value}T12:00:00');
    return parsed != null && _formatDate(parsed) == value;
  }

  static String _moveMonth(String localDate, int direction) {
    final year = int.parse(localDate.substring(0, 4));
    final month = int.parse(localDate.substring(5, 7));
    final day = int.parse(localDate.substring(8, 10));
    final monthStart = DateTime.utc(year, month + direction, 1);
    final lastDay = DateTime.utc(monthStart.year, monthStart.month + 1, 0).day;
    return _formatDate(
      DateTime.utc(monthStart.year, monthStart.month, day.clamp(1, lastDay)),
    );
  }

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _viewLabel(CalendarView view) => switch (view) {
    CalendarView.day => 'Day',
    CalendarView.week => 'Week',
    CalendarView.month => 'Month',
  };

  static String _selectedDateLabel(CalendarView view, String localDate) {
    return switch (view) {
      CalendarView.day => _humanDate(localDate),
      CalendarView.week => _humanRange(
        _weekStart(localDate),
        _weekEnd(localDate),
      ),
      CalendarView.month => DateFormat(
        'MMMM y',
      ).format(DateTime.parse('${localDate}T12:00:00')),
    };
  }

  static String _humanDate(String localDate) =>
      DateFormat('d MMM y').format(DateTime.parse('${localDate}T12:00:00'));

  static String _humanRange(String start, String end) {
    final first = DateTime.parse('${start}T12:00:00');
    final last = DateTime.parse('${end}T12:00:00');
    final sameYear = first.year == last.year;
    final sameMonth = sameYear && first.month == last.month;
    if (sameMonth) {
      return '${first.day}–${last.day} ${DateFormat('MMM').format(last)}';
    }
    final firstLabel = DateFormat(sameYear ? 'd MMM' : 'd MMM y').format(first);
    final lastLabel = DateFormat('d MMM y').format(last);
    return '$firstLabel–$lastLabel';
  }

  static String _weekStart(String localDate) {
    final date = DateTime.parse('${localDate}T12:00:00');
    return _formatDate(date.subtract(Duration(days: date.weekday - 1)));
  }

  static String _weekEnd(String localDate) {
    final date = DateTime.parse('${localDate}T12:00:00');
    return _formatDate(date.add(Duration(days: 7 - date.weekday)));
  }
}

class _ProgramCalendarScreenState extends ConsumerState<ProgramCalendarScreen> {
  @override
  void initState() {
    super.initState();
    final requested = widget.initialLocalDate;
    if (requested != null && ProgramCalendarScreen._isLocalDate(requested)) {
      Future.microtask(() {
        if (mounted) {
          ref.read(calendarControllerProvider.notifier).selectDate(requested);
        }
      });
    }
  }

  void _showActions(BuildContext context, CalendarOccurrenceReadItem item) {
    showIndiFitBottomSheet<void>(
      context: context,
      semanticLabel: 'Workout actions',
      builder: (context) => OccurrenceActionsSheet(occurrenceItem: item),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final state = ref.read(calendarControllerProvider);
    final selected = DateTime.parse('${state.selectedLocalDate}T12:00:00Z');
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await ref
        .read(calendarControllerProvider.notifier)
        .selectDate(ProgramCalendarScreen._formatDate(picked));
  }

  Future<void> _moveDate(int direction) async {
    final state = ref.read(calendarControllerProvider);
    final dates = ref.read(localScheduleDateServiceProvider);
    final next = switch (state.view) {
      CalendarView.day => dates.addCalendarDays(
        state.selectedLocalDate,
        state.timezoneId,
        direction,
      ),
      CalendarView.week => dates.addCalendarDays(
        state.selectedLocalDate,
        state.timezoneId,
        direction * 7,
      ),
      CalendarView.month => ProgramCalendarScreen._moveMonth(
        state.selectedLocalDate,
        direction,
      ),
    };
    await ref.read(calendarControllerProvider.notifier).selectDate(next);
  }

  Future<void> _goToToday() {
    final state = ref.read(calendarControllerProvider);
    final dates = ref.read(localScheduleDateServiceProvider);
    return ref
        .read(calendarControllerProvider.notifier)
        .selectDate(dates.todayIn(state.timezoneId));
  }

  Widget _buildOccurrenceCard(
    BuildContext context,
    CalendarOccurrenceReadItem item, {
    required bool hasTravelOverride,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: B05Layout.space12),
    child: WorkoutContextualActions(
      item: item,
      hasTravelOverride: hasTravelOverride,
      onOpenDetails: () => _showActions(context, item),
    ),
  );

  Widget _buildCalendarContent(
    BuildContext context,
    CalendarUiState state,
    Set<String> activeTravelOccurrenceIds,
  ) {
    final hasActiveProgram = state.activeProgramVersionId != null;

    if (!hasActiveProgram && state.rangeOccurrences.isEmpty) {
      return CalendarEmptyState(
        view: state.view,
        hasActiveProgram: false,
        onAction: () => context.push('/routine-wizard'),
      );
    }

    final selectedOccurrences = state.selectedDateOccurrences;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: B05Layout.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.view == CalendarView.month)
            _CalendarMonthGrid(
              selectedLocalDate: state.selectedLocalDate,
              timezoneId: state.timezoneId,
              occurrences: state.rangeOccurrences,
              onDateSelected: (date) => ref
                  .read(calendarControllerProvider.notifier)
                  .selectDate(date),
            )
          else if (state.view == CalendarView.week)
            _CalendarWeekStrip(
              localDate: state.selectedLocalDate,
              timezoneId: state.timezoneId,
              occurrences: state.rangeOccurrences,
              onDateSelected: (date) => ref
                  .read(calendarControllerProvider.notifier)
                  .selectDate(date),
            ),

          // Selected date header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              B05Layout.space16,
              B05Layout.space12,
              B05Layout.space16,
              B05Layout.space8,
            ),
            child: Text(
              _selectedDateSectionHeader(
                state.selectedLocalDate,
                state.timezoneId,
              ),
              style: B05Typography.title(context),
            ),
          ),

          // Selected date occurrences or rest day
          if (selectedOccurrences.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: B05Layout.space16,
              ),
              child: Column(
                children: [
                  for (final item in selectedOccurrences)
                    _buildOccurrenceCard(
                      context,
                      item,
                      hasTravelOverride: activeTravelOccurrenceIds.contains(
                        item.occurrence.id,
                      ),
                    ),
                ],
              ),
            )
          else
            _CalendarRestDayCard(
              localDate: state.selectedLocalDate,
              hasActiveProgram: hasActiveProgram,
            ),
        ],
      ),
    );
  }

  static String _selectedDateSectionHeader(
    String localDate,
    String timezoneId,
  ) {
    final date = DateTime.parse('${localDate}T12:00:00');
    return DateFormat('EEEE, d MMMM y').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarControllerProvider);
    final controller = ref.read(calendarControllerProvider.notifier);
    final travelState = ref.watch(travelControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More training options',
            onSelected: (value) {
              switch (value) {
                case 'plan':
                  context.push('/program-author');
                case 'travel':
                  context.push('/travel-mode');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'plan',
                child: Text(
                  state.activeProgramVersionId == null
                      ? 'Choose a training plan'
                      : 'Manage training plan',
                ),
              ),
              if (state.activeProgramVersionId != null)
                PopupMenuItem(
                  value: 'travel',
                  child: Text(
                    travelState.activeTravelContext != null
                        ? 'Travel mode active'
                        : 'Travel mode',
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              children: CalendarView.values
                  .map(
                    (view) => ChoiceChip(
                      label: Text(ProgramCalendarScreen._viewLabel(view)),
                      selected: state.view == view,
                      onSelected: (_) => controller.setView(view),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: B05Layout.space8),
            child: _CalendarDateControls(
              view: state.view,
              localDate: state.selectedLocalDate,
              onPrevious: () => _moveDate(-1),
              onPickDate: () => _pickDate(context),
              onToday: _goToToday,
              onNext: () => _moveDate(1),
            ),
          ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConsumerStatusRow(
                label: 'Calendar unavailable',
                detail: ProductFailurePresentation.fromCode(
                  'calendar_unavailable',
                ).message,
                error: true,
                onRetry: controller.refresh,
              ),
            ),
          if (travelState.activeTravelContext case final travel?)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                B05Layout.space16,
                B05Layout.space4,
                B05Layout.space16,
                0,
              ),
              child: B05Surface(
                tone: B05SurfaceTone.selected,
                showBorder: false,
                padding: const EdgeInsets.all(B05Layout.space12),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Travel mode is on for ${ConsumerCountLabel.format(travelState.activeTravelOccurrenceIds.length, 'workout')} (${ConsumerDateLabel.range(travel.startLocalDate, travel.endLocalDate)}).',
                    style: B05Typography.body(context),
                  ),
                ),
              ),
            ),
          if (state.isLoading)
            const Expanded(
              child: Center(
                child: ConsumerStatusRow(
                  label: 'Loading your calendar',
                  detail: 'Finding planned workouts for this period.',
                  loading: true,
                ),
              ),
            )
          else
            Expanded(
              child: _buildCalendarContent(
                context,
                state,
                travelState.activeTravelOccurrenceIds,
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarDateControls extends StatelessWidget {
  const _CalendarDateControls({
    required this.view,
    required this.localDate,
    required this.onPrevious,
    required this.onPickDate,
    required this.onToday,
    required this.onNext,
  });

  final CalendarView view;
  final String localDate;
  final VoidCallback onPrevious;
  final VoidCallback onPickDate;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compact = MediaQuery.sizeOf(context).width < 360 || scale >= 1.6;
    final period = ProgramCalendarScreen._viewLabel(view).toLowerCase();
    final selectedLabel = ProgramCalendarScreen._selectedDateLabel(
      view,
      localDate,
    );
    final dateButton = Semantics(
      label: 'Selected $selectedLabel',
      button: true,
      child: B05ActionButton(
        label: selectedLabel,
        icon: Icons.calendar_today_outlined,
        emphasis: B05ActionEmphasis.tertiary,
        hint: 'Choose a date to view.',
        onPressed: onPickDate,
      ),
    );
    final previous = B05IconAction(
      icon: Icons.chevron_left_rounded,
      label: 'Previous $period',
      onPressed: onPrevious,
    );
    final next = B05IconAction(
      icon: Icons.chevron_right_rounded,
      label: 'Next $period',
      onPressed: onNext,
    );
    final today = B05ActionButton(
      label: 'Today',
      emphasis: B05ActionEmphasis.tertiary,
      onPressed: onToday,
    );

    if (compact) {
      return Column(
        children: [
          Row(
            children: [
              previous,
              Expanded(child: dateButton),
              next,
            ],
          ),
          Align(alignment: Alignment.centerRight, child: today),
        ],
      );
    }
    return Row(
      children: [
        previous,
        Expanded(child: dateButton),
        today,
        next,
      ],
    );
  }
}

enum _DayOccurrenceStatus {
  completed,
  inProgress,
  partiallyCompleted,
  scheduled,
  skipped,
  cancelled,
  none,
}

_DayOccurrenceStatus _resolveDayStatus(
  List<CalendarOccurrenceReadItem>? items,
) {
  if (items == null || items.isEmpty) return _DayOccurrenceStatus.none;
  if (items.any((i) => i.occurrence.status == 'completed')) {
    return _DayOccurrenceStatus.completed;
  }
  if (items.any((i) => i.occurrence.status == 'inProgress')) {
    return _DayOccurrenceStatus.inProgress;
  }
  if (items.any((i) => i.occurrence.status == 'partiallyCompleted')) {
    return _DayOccurrenceStatus.partiallyCompleted;
  }
  if (items.any((i) =>
      i.occurrence.status == 'planned' ||
      i.occurrence.status == 'rescheduled')) {
    return _DayOccurrenceStatus.scheduled;
  }
  if (items.any((i) => i.occurrence.status == 'skipped')) {
    return _DayOccurrenceStatus.skipped;
  }
  if (items.any((i) => i.occurrence.status == 'cancelled')) {
    return _DayOccurrenceStatus.cancelled;
  }
  return _DayOccurrenceStatus.none;
}

Widget? _buildStatusIndicator(
  BuildContext context,
  _DayOccurrenceStatus status,
  bool isSelected,
) {
  final colors = context.b05Colors;
  return switch (status) {
    _DayOccurrenceStatus.completed => Icon(
      Icons.check_circle_rounded,
      size: 14,
      color: isSelected ? colors.action : colors.success.indicator,
    ),
    _DayOccurrenceStatus.inProgress => Icon(
      Icons.play_circle_fill_rounded,
      size: 14,
      color: isSelected ? colors.action : colors.info.indicator,
    ),
    _DayOccurrenceStatus.partiallyCompleted => Icon(
      Icons.pie_chart_outline_rounded,
      size: 14,
      color: isSelected ? colors.action : colors.info.indicator,
    ),
    _DayOccurrenceStatus.scheduled => Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: isSelected ? colors.action : colors.textSecondary,
        shape: BoxShape.circle,
      ),
    ),
    _DayOccurrenceStatus.skipped => Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: colors.unavailable.indicator,
        shape: BoxShape.circle,
      ),
    ),
    _DayOccurrenceStatus.cancelled => Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: colors.danger.indicator,
        shape: BoxShape.circle,
      ),
    ),
    _DayOccurrenceStatus.none => null,
  };
}

class _CalendarMonthGrid extends StatelessWidget {
  const _CalendarMonthGrid({
    required this.selectedLocalDate,
    required this.timezoneId,
    required this.occurrences,
    required this.onDateSelected,
  });

  final String selectedLocalDate;
  final String timezoneId;
  final List<CalendarOccurrenceReadItem> occurrences;
  final ValueChanged<String> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final year = int.parse(selectedLocalDate.substring(0, 4));
    final month = int.parse(selectedLocalDate.substring(5, 7));
    final firstOfMonth = DateTime.utc(year, month, 1);
    final daysInMonth = DateTime.utc(year, month + 1, 0).day;
    final startWeekday = firstOfMonth.weekday; // 1 = Mon, 7 = Sun
    final leadingDays = startWeekday - 1;
    final prevMonthLastDay = DateTime.utc(year, month, 0).day;
    final totalOccupied = leadingDays + daysInMonth;
    final trailingDays = (7 - (totalOccupied % 7)) % 7;
    final totalCells = totalOccupied + trailingDays;

    final byDate = <String, List<CalendarOccurrenceReadItem>>{};
    for (final item in occurrences) {
      (byDate[item.occurrence.effectiveLocalDate] ??= []).add(item);
    }

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: B05Layout.space16,
        vertical: B05Layout.space8,
      ),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: [
              for (final day in weekdays)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: B05Layout.space4,
                      ),
                      child: Text(
                        day,
                        style: B05Typography.caption(context).copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: B05Layout.space4),
          // Calendar cells
          for (var row = 0; row < totalCells ~/ 7; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: B05Layout.space4),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++) ...[
                    if (col > 0) const SizedBox(width: B05Layout.space4),
                    Expanded(
                      child: _buildCell(
                        context,
                        index: row * 7 + col,
                        year: year,
                        month: month,
                        leadingDays: leadingDays,
                        daysInMonth: daysInMonth,
                        prevMonthLastDay: prevMonthLastDay,
                        byDate: byDate,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCell(
    BuildContext context, {
    required int index,
    required int year,
    required int month,
    required int leadingDays,
    required int daysInMonth,
    required int prevMonthLastDay,
    required Map<String, List<CalendarOccurrenceReadItem>> byDate,
  }) {
    final colors = context.b05Colors;
    final int cellDay;
    final int cellMonth;
    final int cellYear;
    final bool isCurrentMonth;

    if (index < leadingDays) {
      cellDay = prevMonthLastDay - leadingDays + 1 + index;
      if (month == 1) {
        cellMonth = 12;
        cellYear = year - 1;
      } else {
        cellMonth = month - 1;
        cellYear = year;
      }
      isCurrentMonth = false;
    } else if (index < leadingDays + daysInMonth) {
      cellDay = index - leadingDays + 1;
      cellMonth = month;
      cellYear = year;
      isCurrentMonth = true;
    } else {
      cellDay = index - leadingDays - daysInMonth + 1;
      if (month == 12) {
        cellMonth = 1;
        cellYear = year + 1;
      } else {
        cellMonth = month + 1;
        cellYear = year;
      }
      isCurrentMonth = false;
    }

    final dateKey =
        '${cellYear.toString().padLeft(4, '0')}-${cellMonth.toString().padLeft(2, '0')}-${cellDay.toString().padLeft(2, '0')}';
    final isSelected = dateKey == selectedLocalDate;
    final dayOccurrences = byDate[dateKey];
    final status = _resolveDayStatus(dayOccurrences);
    final indicator = _buildStatusIndicator(context, status, isSelected);

    final statusText = switch (status) {
      _DayOccurrenceStatus.completed => 'Workout completed',
      _DayOccurrenceStatus.inProgress => 'Workout in progress',
      _DayOccurrenceStatus.partiallyCompleted => 'Workout partially completed',
      _DayOccurrenceStatus.scheduled => 'Workout scheduled',
      _DayOccurrenceStatus.skipped => 'Workout skipped',
      _DayOccurrenceStatus.cancelled => 'Workout cancelled',
      _DayOccurrenceStatus.none => 'Rest day',
    };

    final semanticsLabel =
        '$cellDay ${DateFormat('MMMM y').format(DateTime.utc(cellYear, cellMonth, cellDay))}, $statusText${isSelected ? ', selected' : ''}';

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      onTap: () => onDateSelected(dateKey),
      child: InkWell(
        onTap: () => onDateSelected(dateKey),
        borderRadius: B05Radii.smallRadius,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: B05Layout.minTouchTarget,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.selected
                : isCurrentMonth
                ? colors.inset
                : Colors.transparent,
            borderRadius: B05Radii.smallRadius,
            border: Border.all(
              color: isSelected
                  ? colors.action
                  : isCurrentMonth
                  ? colors.border
                  : Colors.transparent,
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: B05Layout.space4,
            horizontal: 2,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$cellDay',
                style: B05Typography.caption(context).copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? colors.action
                      : isCurrentMonth
                      ? colors.textPrimary
                      : colors.textSecondary.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 14,
                child: Center(
                  child: indicator ?? const SizedBox(height: 6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarWeekStrip extends StatelessWidget {
  const _CalendarWeekStrip({
    required this.localDate,
    required this.timezoneId,
    required this.occurrences,
    required this.onDateSelected,
  });

  final String localDate;
  final String timezoneId;
  final List<CalendarOccurrenceReadItem> occurrences;
  final ValueChanged<String> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final selected = DateTime.parse('${localDate}T12:00:00');
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final byDate = <String, List<CalendarOccurrenceReadItem>>{};
    for (final item in occurrences) {
      (byDate[item.occurrence.effectiveLocalDate] ??= []).add(item);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space16,
        B05Layout.space4,
        B05Layout.space16,
        B05Layout.space8,
      ),
      child: Row(
        children: [
          for (var index = 0; index < weekdays.length; index++) ...[
            if (index > 0) const SizedBox(width: B05Layout.space4),
            Expanded(
              child: _buildDayButton(
                context,
                label: weekdays[index],
                date: monday.add(Duration(days: index)),
                byDate: byDate,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayButton(
    BuildContext context, {
    required String label,
    required DateTime date,
    required Map<String, List<CalendarOccurrenceReadItem>> byDate,
  }) {
    final colors = context.b05Colors;
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final selected = dateKey == localDate;
    final dayOccurrences = byDate[dateKey];
    final status = _resolveDayStatus(dayOccurrences);
    final indicator = _buildStatusIndicator(context, status, selected);

    final statusText = switch (status) {
      _DayOccurrenceStatus.completed => 'Workout completed',
      _DayOccurrenceStatus.inProgress => 'Workout in progress',
      _DayOccurrenceStatus.partiallyCompleted => 'Workout partially completed',
      _DayOccurrenceStatus.scheduled => 'Workout scheduled',
      _DayOccurrenceStatus.skipped => 'Workout skipped',
      _DayOccurrenceStatus.cancelled => 'Workout cancelled',
      _DayOccurrenceStatus.none => 'Rest day',
    };

    final semanticsLabel =
        '$label ${date.day} ${DateFormat('MMMM y').format(date)}, $statusText${selected ? ', selected' : ''}';

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      onTap: () => onDateSelected(dateKey),
      child: InkWell(
        onTap: () => onDateSelected(dateKey),
        borderRadius: B05Radii.smallRadius,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: B05Layout.minTouchTarget,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.selected : colors.inset,
            borderRadius: B05Radii.smallRadius,
            border: Border.all(
              color: selected ? colors.action : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: B05Layout.space4,
            horizontal: 2,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: B05Typography.caption(context).copyWith(
                  color: selected ? colors.action : colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${date.day}',
                style: B05Typography.label(context).copyWith(
                  color: selected ? colors.action : colors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 14,
                child: Center(
                  child: indicator ?? const SizedBox(height: 6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarRestDayCard extends StatelessWidget {
  const _CalendarRestDayCard({
    required this.localDate,
    required this.hasActiveProgram,
  });

  final String localDate;
  final bool hasActiveProgram;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final formattedDate = ConsumerDateLabel.day(localDate);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: B05Layout.space16,
        vertical: B05Layout.space12,
      ),
      child: B05Surface(
        tone: B05SurfaceTone.inset,
        padding: const EdgeInsets.all(B05Layout.space16),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.info.container,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(B05Layout.space12),
                child: Icon(
                  Icons.self_improvement_rounded,
                  color: colors.info.indicator,
                  size: B05Layout.iconLarge,
                ),
              ),
            ),
            const SizedBox(width: B05Layout.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rest Day',
                    style: B05Typography.title(context),
                  ),
                  const SizedBox(height: B05Layout.space4),
                  Text(
                    hasActiveProgram
                        ? 'No workouts scheduled on your plan for $formattedDate. Rest and recover.'
                        : 'No workouts scheduled for $formattedDate.',
                    style: B05Typography.body(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalendarEmptyState extends StatelessWidget {
  const CalendarEmptyState({
    this.view,
    this.isDay,
    required this.hasActiveProgram,
    required this.onAction,
    super.key,
  });

  final CalendarView? view;
  final bool? isDay;
  final bool hasActiveProgram;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = hasActiveProgram
        ? 'Open training plan'
        : 'Set up a training plan';
    final resolvedView =
        view ?? (isDay == true ? CalendarView.day : CalendarView.week);
    final legacyCopy = view == null && isDay != null;
    final title = legacyCopy && isDay == false
        ? 'Nothing planned here'
        : switch (resolvedView) {
            CalendarView.day => 'Nothing planned today',
            CalendarView.week => 'Nothing planned this week',
            CalendarView.month => 'Nothing planned this month',
          };
    final message = legacyCopy
        ? isDay == true
              ? hasActiveProgram
                    ? 'No workout is scheduled for this day. Open your training plan to choose another day.'
                    : 'Choose a workout or enjoy a recovery day.'
              : hasActiveProgram
              ? 'No workouts are scheduled in this range. Open your training plan to choose another day.'
              : 'Try another date or set up a training plan.'
        : switch (resolvedView) {
            CalendarView.day =>
              hasActiveProgram
                  ? 'No workout is scheduled today. Open your training plan to choose another day.'
                  : 'Choose a workout whenever you’re ready.',
            CalendarView.week =>
              hasActiveProgram
                  ? 'No workouts are scheduled this week. Open your training plan to choose another day.'
                  : 'Choose a plan when you’re ready to schedule workouts.',
            CalendarView.month =>
              hasActiveProgram
                  ? 'No workouts are scheduled this month. Open your training plan to choose another day.'
                  : 'Choose a plan when you’re ready to schedule workouts.',
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ProductEmptyState(
          icon: Icons.event_note_rounded,
          title: title,
          message: message,
          action: onAction,
          actionLabel: actionLabel,
          actionIcon: Icons.fitness_center_rounded,
        ),
      ),
    );
  }
}
