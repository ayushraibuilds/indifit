import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/providers.dart';
import '../../core/presentation/consumer_date_label.dart';
import '../../core/theme/colors.dart';
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
  ) {
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_rounded, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('Nothing planned in this range.'),
          ],
        ),
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
          style: TextStyle(fontFamily: GoogleFonts.outfit().fontFamily),
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final travelState = ref.watch(travelControllerProvider);
              final isActive = travelState.activeTravelContext != null;
              return IconButton(
                icon: Icon(
                  Icons.flight_rounded,
                  color: isActive ? AppColors.success : null,
                ),
                tooltip: isActive ? 'Travel mode active' : 'Travel mode',
                onPressed: () => context.push('/travel-mode'),
              );
            },
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous ${_viewLabel(state.view).toLowerCase()}',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _moveDate(ref, -1),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _pickDate(context, ref),
                    child: Text(
                      _selectedDateLabel(state.view, state.selectedLocalDate),
                      semanticsLabel:
                          'Selected ${_selectedDateLabel(state.view, state.selectedLocalDate)}',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _goToToday(ref),
                  child: const Text('Today'),
                ),
                IconButton(
                  tooltip: 'Next ${_viewLabel(state.view).toLowerCase()}',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _moveDate(ref, 1),
                ),
              ],
            ),
          ),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (travelState.activeTravelContext case final travel?)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Travel mode: ${ConsumerDateLabel.range(travel.startLocalDate, travel.endLocalDate)} • ${travelState.activeTravelOccurrenceIds.length} previewed workout${travelState.activeTravelOccurrenceIds.length == 1 ? '' : 's'} use travel equipment.',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildOccurrences(
                    context,
                    visibleItems,
                    travelState.activeTravelOccurrenceIds,
                  ),
          ),
        ],
      ),
    );
  }
}
