import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/b05_accessibility_primitives.dart';

/// Date navigation for Today. It uses civil-day comparisons so the page keeps
/// its historic past/today/future behaviour without deriving schedule state.
class DashboardDateBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const DashboardDateBar({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  String _formattedLabel(DateTime now) {
    final today = _day(now);
    final target = _day(selectedDate);
    final diff = target.difference(today).inDays;
    final date = DateFormat('EEE, MMM d').format(selectedDate);
    return switch (diff) {
      0 => 'Today ($date)',
      -1 => 'Yesterday ($date)',
      1 => 'Tomorrow ($date)',
      _ => date,
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = _day(now);
    final target = _day(selectedDate);
    final canMoveForward = target.isBefore(today);
    return B05Surface(
      padding: const EdgeInsets.symmetric(horizontal: B05Layout.space8),
      radius: B05SurfaceRadius.small,
      subtle: true,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Row(
          children: [
            B05IconAction(
              icon: Icons.chevron_left_rounded,
              label: 'Previous day',
              hint: 'Shows the previous day on Today.',
              onPressed: () => onDateChanged(
                DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day - 1,
                ),
              ),
              focusOrder: 0,
            ),
            Expanded(
              child: B05ActionButton(
                label: _formattedLabel(now),
                hint: 'Choose a date to view.',
                icon: Icons.calendar_today_outlined,
                emphasis: B05ActionEmphasis.secondary,
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: target.isAfter(today) ? today : target,
                    firstDate: DateTime(2020),
                    lastDate: today,
                  );
                  if (picked != null) onDateChanged(picked);
                },
                focusOrder: 1,
              ),
            ),
            B05IconAction(
              icon: Icons.chevron_right_rounded,
              label: canMoveForward ? 'Next day' : 'Future dates unavailable',
              hint: canMoveForward
                  ? 'Shows the next day on Today.'
                  : 'Today is the latest available day.',
              onPressed: canMoveForward
                  ? () => onDateChanged(
                      DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day + 1,
                      ),
                    )
                  : null,
              focusOrder: 2,
            ),
          ],
        ),
      ),
    );
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}
