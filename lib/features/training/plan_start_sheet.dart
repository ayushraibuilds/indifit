import 'package:flutter/material.dart';

import '../../core/presentation/consumer_date_label.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/services/training_day_schedule.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';

/// What the user chose when starting a plan.
class PlanStartChoice {
  const PlanStartChoice({required this.startLocalDate, this.trainingWeekdays});

  final String startLocalDate;

  /// Null when the plan has no regular weekly pattern to re-lay; its
  /// sessions keep their planned weekdays.
  final List<int>? trainingWeekdays;
}

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Asks "When do you want to start?" and "Which days do you train?" before a
/// plan becomes current. Returns null when dismissed.
Future<PlanStartChoice?> showPlanStartSheet(
  BuildContext context, {
  required String planName,
  required String todayLocalDate,
  required String timezoneId,
  required LocalScheduleDateService dates,
  required List<int> planWeekdays,
  required int? sessionsPerWeek,
}) {
  return showIndiFitBottomSheet<PlanStartChoice>(
    context: context,
    semanticLabel: 'Start $planName',
    builder: (_) => PlanStartSheet(
      planName: planName,
      todayLocalDate: todayLocalDate,
      timezoneId: timezoneId,
      dates: dates,
      planWeekdays: planWeekdays,
      sessionsPerWeek: sessionsPerWeek,
    ),
  );
}

class PlanStartSheet extends StatefulWidget {
  const PlanStartSheet({
    super.key,
    required this.planName,
    required this.todayLocalDate,
    required this.timezoneId,
    required this.dates,
    required this.planWeekdays,
    required this.sessionsPerWeek,
  });

  final String planName;
  final String todayLocalDate;
  final String timezoneId;
  final LocalScheduleDateService dates;
  final List<int> planWeekdays;

  /// The plan's training days a week. Null for an irregular plan, which
  /// skips the days question.
  final int? sessionsPerWeek;

  @override
  State<PlanStartSheet> createState() => _PlanStartSheetState();
}

class _PlanStartSheetState extends State<PlanStartSheet> {
  late final Set<int> _weekdays = {
    ...TrainingDaySchedule.normalizeWeekdays(widget.planWeekdays),
  };
  var _startToday = true;

  bool get _asksDays =>
      widget.sessionsPerWeek != null &&
      widget.sessionsPerWeek! > 0 &&
      widget.sessionsPerWeek! <= 7;

  bool get _daysReady =>
      !_asksDays || _weekdays.length == widget.sessionsPerWeek;

  /// The first chosen training day from today, or null when it is today.
  String? get _firstDay {
    final days = _asksDays ? _weekdays : widget.planWeekdays.toSet();
    if (days.isEmpty) return null;
    final first = TrainingDaySchedule.firstTrainingDayOnOrAfter(
      dates: widget.dates,
      timezoneId: widget.timezoneId,
      fromLocalDate: widget.todayLocalDate,
      weekdays: days,
    );
    return first == widget.todayLocalDate ? null : first;
  }

  void _toggle(int weekday) {
    setState(() {
      if (!_weekdays.remove(weekday)) _weekdays.add(weekday);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = _daysReady ? _firstDay : null;
    final startToday = _startToday || firstDay == null;
    final needed = widget.sessionsPerWeek ?? 0;
    final picked = _weekdays.length;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          B05Layout.space16,
          B05Layout.space8,
          B05Layout.space16,
          B05Layout.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start ${widget.planName}',
              style: B05Typography.title(context),
            ),
            const SizedBox(height: B05Layout.space16),
            Text(
              'When do you want to start?',
              style: B05Typography.body(context),
            ),
            const SizedBox(height: B05Layout.space8),
            Wrap(
              spacing: B05Layout.space8,
              runSpacing: B05Layout.space8,
              children: [
                ChoiceChip(
                  key: const ValueKey('plan_start_today'),
                  label: const Text('Today'),
                  selected: startToday,
                  onSelected: (_) => setState(() => _startToday = true),
                ),
                if (firstDay != null)
                  ChoiceChip(
                    key: const ValueKey('plan_start_first_day'),
                    label: Text(ConsumerDateLabel.date(firstDay)),
                    selected: !startToday,
                    onSelected: (_) => setState(() => _startToday = false),
                  ),
              ],
            ),
            if (_asksDays) ...[
              const SizedBox(height: B05Layout.space16),
              Text(
                'Which days do you train?',
                style: B05Typography.body(context),
              ),
              const SizedBox(height: B05Layout.space8),
              Wrap(
                spacing: B05Layout.space8,
                runSpacing: B05Layout.space8,
                children: [
                  for (var weekday = 1; weekday <= 7; weekday++)
                    FilterChip(
                      key: ValueKey('plan_start_day_$weekday'),
                      label: Text(_weekdayLabels[weekday - 1]),
                      selected: _weekdays.contains(weekday),
                      onSelected: (_) => _toggle(weekday),
                    ),
                ],
              ),
              const SizedBox(height: B05Layout.space8),
              Text(
                picked == needed
                    ? '$needed days a week, as the plan is written.'
                    : 'Pick $needed days. This plan has $needed workouts a '
                          'week ($picked picked).',
                style: B05Typography.caption(context),
              ),
            ],
            const SizedBox(height: B05Layout.space16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('plan_start_confirm'),
                onPressed: _daysReady
                    ? () => Navigator.pop(
                        context,
                        PlanStartChoice(
                          startLocalDate: startToday
                              ? widget.todayLocalDate
                              : firstDay,
                          trainingWeekdays: _asksDays
                              ? (_weekdays.toList()..sort())
                              : null,
                        ),
                      )
                    : null,
                child: const Text('Start plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
