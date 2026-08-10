import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
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

/// Calendar MVP for dated B01 occurrences. The selected date and view are
/// Riverpod-memory state; occurrence data remains repository-owned.
class ProgramCalendarScreen extends ConsumerWidget {
  const ProgramCalendarScreen({super.key});

  void _showActions(BuildContext context, CalendarOccurrenceReadItem item) {
    showIndiFitBottomSheet<void>(
      context: context,
      semanticLabel: 'Workout actions',
      builder: (context) => OccurrenceActionsSheet(occurrenceItem: item),
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
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
        .selectDate(_formatDate(picked));
  }

  Future<void> _moveDate(WidgetRef ref, int direction) async {
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
      CalendarView.month => _moveMonth(state.selectedLocalDate, direction),
    };
    await ref.read(calendarControllerProvider.notifier).selectDate(next);
  }

  Future<void> _goToToday(WidgetRef ref) {
    final state = ref.read(calendarControllerProvider);
    final dates = ref.read(localScheduleDateServiceProvider);
    return ref
        .read(calendarControllerProvider.notifier)
        .selectDate(dates.todayIn(state.timezoneId));
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
      CalendarView.day => ConsumerDateLabel.day(localDate),
      CalendarView.week => ConsumerDateLabel.range(
        _weekStart(localDate),
        _weekEnd(localDate),
      ),
      CalendarView.month => ConsumerDateLabel.range(
        _monthStart(localDate),
        _monthEnd(localDate),
      ),
    };
  }

  static String _weekStart(String localDate) {
    final date = DateTime.parse('${localDate}T12:00:00');
    return _formatDate(date.subtract(Duration(days: date.weekday - 1)));
  }

  static String _weekEnd(String localDate) {
    final date = DateTime.parse('${localDate}T12:00:00');
    return _formatDate(date.add(Duration(days: 7 - date.weekday)));
  }

  static String _monthStart(String localDate) {
    final date = DateTime.parse('${localDate}T12:00:00');
    return _formatDate(DateTime(date.year, date.month, 1));
  }

  static String _monthEnd(String localDate) {
    final date = DateTime.parse('${localDate}T12:00:00');
    return _formatDate(DateTime(date.year, date.month + 1, 0));
  }

  Widget _buildOccurrenceCard(
    BuildContext context,
    CalendarOccurrenceReadItem item, {
    required bool hasTravelOverride,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: WorkoutContextualActions(
      item: item,
      hasTravelOverride: hasTravelOverride,
      onOpenDetails: () => _showActions(context, item),
    ),
  );

  Widget _buildOccurrences(
    BuildContext context,
    List<CalendarOccurrenceReadItem> items,
    Set<String> activeTravelOccurrenceIds,
    CalendarView view,
    bool hasActiveProgram,
  ) {
    if (items.isEmpty) {
      return CalendarEmptyState(
        view: view,
        hasActiveProgram: hasActiveProgram,
        onAction: () =>
            context.push(hasActiveProgram ? '/workout' : '/routine-wizard'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildOccurrenceCard(
        context,
        items[index],
        hasTravelOverride: activeTravelOccurrenceIds.contains(
          items[index].occurrence.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarControllerProvider);
    final controller = ref.read(calendarControllerProvider.notifier);
    final travelState = ref.watch(travelControllerProvider);
    final visibleItems = switch (state.view) {
      CalendarView.day => state.selectedDateOccurrences,
      CalendarView.week || CalendarView.month => state.rangeOccurrences,
    };

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
                      label: Text(_viewLabel(view)),
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
              onPrevious: () => _moveDate(ref, -1),
              onPickDate: () => _pickDate(context, ref),
              onToday: () => _goToToday(ref),
              onNext: () => _moveDate(ref, 1),
            ),
          ),
          if (state.view == CalendarView.week)
            _CalendarWeekStrip(
              localDate: state.selectedLocalDate,
              onDateSelected: (date) => controller.selectDate(date),
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
                    'Travel mode is on for ${travelState.activeTravelOccurrenceIds.length} workout${travelState.activeTravelOccurrenceIds.length == 1 ? '' : 's'} (${ConsumerDateLabel.range(travel.startLocalDate, travel.endLocalDate)}).',
                    style: B05Typography.body(context),
                  ),
                ),
              ),
            ),
          if (state.isLoading)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(B05Layout.space16),
                child: const ConsumerStatusRow(
                  label: 'Loading your calendar',
                  detail: 'Finding planned workouts for this period.',
                  loading: true,
                ),
              ),
            )
          else
            Expanded(
              child: _buildOccurrences(
                context,
                visibleItems,
                travelState.activeTravelOccurrenceIds,
                state.view,
                state.activeProgramVersionId != null,
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

class _CalendarWeekStrip extends StatelessWidget {
  const _CalendarWeekStrip({
    required this.localDate,
    required this.onDateSelected,
  });

  final String localDate;
  final ValueChanged<String> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final selected = DateTime.parse('${localDate}T12:00:00');
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        B05Layout.space16,
        B05Layout.space4,
        B05Layout.space16,
        B05Layout.space8,
      ),
      child: Row(
        children: [
          for (var index = 0; index < weekdays.length; index++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == weekdays.length - 1 ? 0 : B05Layout.space4,
                ),
                child: _CalendarDayButton(
                  label: weekdays[index],
                  date: monday.add(Duration(days: index)),
                  selected:
                      _formatDate(monday.add(Duration(days: index))) ==
                      localDate,
                  onPressed: onDateSelected,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _CalendarDayButton extends StatelessWidget {
  const _CalendarDayButton({
    required this.label,
    required this.date,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final DateTime date;
  final bool selected;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return Semantics(
      button: true,
      selected: selected,
      label: '$label ${date.day}',
      onTap: () => onPressed(dateKey),
      child: InkWell(
        onTap: () => onPressed(dateKey),
        borderRadius: B05Radii.smallRadius,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: B05Layout.minTouchTarget,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.selected : colors.inset,
            borderRadius: B05Radii.smallRadius,
            border: Border.all(color: selected ? colors.action : colors.border),
          ),
          padding: const EdgeInsets.symmetric(vertical: B05Layout.space4),
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
                ),
              ),
            ],
          ),
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
