import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
          child: Row(
            key: const ValueKey('dashboard-date-bar-row'),
            children: [
              B05IconAction(
                key: const ValueKey('dashboard-date-bar-previous'),
                icon: Icons.chevron_left_rounded,
                label: canMoveBack
                    ? 'Previous day'
                    : 'Earlier dates unavailable',
                hint: 'Shows the previous day for this date.',
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
                child: Semantics(
                  container: true,
                  label: 'Selected date',
                  value: _spokenDate(selectedDate),
                  child: B05ActionButton(
                    key: const ValueKey('dashboard-date-bar-selected-date'),
                    label: _compactDateLabel(selectedDate, todayDay),
                    hint: 'Choose a date to view.',
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
              ),
              B05IconAction(
                key: const ValueKey('dashboard-date-bar-next'),
                icon: Icons.chevron_right_rounded,
                label: canMoveForward ? 'Next day' : 'Later dates unavailable',
                hint: canMoveForward
                    ? 'Shows the next day for this date.'
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
              if (target != todayDay)
                Semantics(
                  container: true,
                  label: 'Go to today',
                  hint: 'Return to today.',
                  button: true,
                  onTap: () => onDateChanged(todayDay),
                  child: ExcludeSemantics(
                    child: B05ActionButton(
                      key: const ValueKey('dashboard-date-bar-today'),
                      label: 'Today',
                      hint: 'Return to today.',
                      emphasis: B05ActionEmphasis.tertiary,
                      onPressed: () => onDateChanged(todayDay),
                      focusOrder: 3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  String _compactDateLabel(DateTime value, DateTime todayDay) =>
      value == todayDay ? 'Today' : DateFormat('EEE, d MMM').format(value);

  String _spokenDate(DateTime value) =>
      DateFormat('EEEE, d MMMM y').format(_day(value));
}
