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
    final firstDate = DateTime(2020);
    final lastDate = DateTime(todayDay.year + 1, todayDay.month, todayDay.day);
    final canMoveBack = target.isAfter(firstDate);
    final canMoveForward = target.isBefore(lastDate);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.b05Colors.surfaceSubtle,
        borderRadius: B05Radii.mediumRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: B05Layout.space4),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  B05IconAction(
                    icon: Icons.chevron_left_rounded,
                    label: canMoveBack
                        ? 'Previous day'
                        : 'Earlier dates unavailable',
                    hint: 'Shows the previous day on Today.',
                    onPressed: canMoveBack
                        ? () => onDateChanged(
                            DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day - 1,
                            ),
                          )
                        : null,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      onPressed: () async {
                        final initialDate = target.isBefore(firstDate)
                            ? firstDate
                            : target.isAfter(lastDate)
                            ? lastDate
                            : target;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: firstDate,
                          lastDate: lastDate,
                        );
                        if (picked != null) onDateChanged(picked);
                      },
                      focusOrder: 1,
                    ),
                  ),
                  B05IconAction(
                    icon: Icons.chevron_right_rounded,
                    label: canMoveForward
                        ? 'Next day'
                        : 'Later dates unavailable',
                    hint: canMoveForward
                        ? 'Shows the next day on Today.'
                        : 'The latest selectable date is one year from today.',
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
              if (target != todayDay)
                Align(
                  alignment: Alignment.centerRight,
                  child: B05ActionButton(
                    label: 'Today',
                    icon: Icons.today_outlined,
                    hint: 'Return to today.',
                    emphasis: B05ActionEmphasis.tertiary,
                    onPressed: () => onDateChanged(todayDay),
                    focusOrder: 3,
                  ),
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
