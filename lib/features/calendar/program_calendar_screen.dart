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
    CalendarView.day => 'Today',
    CalendarView.week => 'Week',
    CalendarView.month => 'Month',
  };

  static String _selectedDateLabel(CalendarView view, String localDate) {
    final day = ConsumerDateLabel.day(localDate);
    return switch (view) {
      CalendarView.day => day,
      CalendarView.week => 'Week of $day',
      CalendarView.month => 'Month of $day',
    };
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
      final isDay = view == CalendarView.day;
      return CalendarEmptyState(
        isDay: isDay,
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
        title: Text(
          state.activeProgramName == null
              ? 'Training Calendar'
              : 'Training Calendar • ${state.activeProgramName}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (state.activeProgramVersionId != null)
            PopupMenuButton<String>(
              tooltip: 'Calendar options',
              onSelected: (value) {
                if (value == 'travel') context.push('/travel-mode');
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'travel',
                  child: Row(
                    children: [
                      Icon(
                        Icons.flight_rounded,
                        color: travelState.activeTravelContext != null
                            ? context.b05Colors.success.indicator
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        travelState.activeTravelContext != null
                            ? 'Travel mode active'
                            : 'Travel mode',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.add_box_rounded),
            tooltip: 'Author / activate program',
            onPressed: () => context.push('/program-author'),
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
                    'Travel mode: ${ConsumerDateLabel.range(travel.startLocalDate, travel.endLocalDate)} • ${travelState.activeTravelOccurrenceIds.length} previewed workout${travelState.activeTravelOccurrenceIds.length == 1 ? '' : 's'} use travel equipment.',
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

class CalendarEmptyState extends StatelessWidget {
  const CalendarEmptyState({
    required this.isDay,
    required this.hasActiveProgram,
    required this.onAction,
    super.key,
  });

  final bool isDay;
  final bool hasActiveProgram;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = hasActiveProgram
        ? 'Open training plan'
        : 'Set up a training plan';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ProductEmptyState(
          icon: Icons.event_note_rounded,
          title: isDay ? 'Nothing planned today' : 'Nothing planned here',
          message: isDay
              ? hasActiveProgram
                    ? 'No workout is scheduled for this day. Open your training plan to choose another day.'
                    : 'Choose a workout or enjoy a recovery day.'
              : hasActiveProgram
              ? 'No workouts are scheduled in this range. Open your training plan to choose another day.'
              : 'Try another date or set up a training plan.',
          action: onAction,
          actionLabel: actionLabel,
          actionIcon: Icons.fitness_center_rounded,
        ),
      ),
    );
  }
}
