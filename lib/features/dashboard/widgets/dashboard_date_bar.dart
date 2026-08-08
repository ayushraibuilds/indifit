import 'package:flutter/material.dart';

import '../../../core/presentation/consumer_date_label.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// Compact date navigation for Today. It uses civil-day comparisons and only
/// presents the selected date; timezone semantics remain in the read model.
class DashboardDateBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final DateTime? today;

  const DashboardDateBar({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.today,
  });

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final todayDay = _day(now);
    final target = _day(selectedDate);
    final canMoveForward = target.isBefore(todayDay);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.b05Colors.surfaceSubtle,
        borderRadius: B05Radii.mediumRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space4),
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
                  label: ConsumerDateLabel.day(
                    _dateKey(selectedDate),
                    today: now,
                  ),
                  hint: 'Choose a date to view.',
                  icon: Icons.calendar_today_outlined,
                  emphasis: B05ActionEmphasis.secondary,
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: target.isAfter(todayDay) ? todayDay : target,
                      firstDate: DateTime(2020),
                      lastDate: todayDay,
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
      ),
    );
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
