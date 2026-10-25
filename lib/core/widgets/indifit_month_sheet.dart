import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../presentation/consumer_date_label.dart';
import '../theme/b05_semantic_colors.dart';
import 'b05_accessibility_primitives.dart';
import 'indi_fit_bottom_sheet.dart';

/// The days in one month that have food logged and workouts saved, for the
/// dots under each day.
class IndiFitMonthMarks {
  const IndiFitMonthMarks({
    this.foodDays = const {},
    this.workoutDays = const {},
  });

  static const none = IndiFitMonthMarks();

  /// Civil days (midnight, local) with at least one food log.
  final Set<DateTime> foodDays;

  /// Civil days with at least one saved workout.
  final Set<DateTime> workoutDays;
}

/// Loads [IndiFitMonthMarks] for the month starting at [monthStart]. The
/// feature that opens the sheet supplies it, so core never reads feature
/// data.
typedef IndiFitMonthMarksLoader =
    Future<IndiFitMonthMarks> Function(DateTime monthStart);

/// Opens [IndiFitMonthSheet] and returns the picked civil day, or null.
/// Days after [lastDay] (today by default) and before [firstDay] can't be
/// picked.
Future<DateTime?> showIndiFitMonthSheet(
  BuildContext context, {
  required DateTime initialDay,
  DateTime? firstDay,
  DateTime? lastDay,
  DateTime? today,
  IndiFitMonthMarksLoader? marks,
  String title = 'Pick a day',
}) => showIndiFitBottomSheet<DateTime>(
  context: context,
  semanticLabel: title,
  builder: (_) => IndiFitMonthSheet(
    initialDay: initialDay,
    firstDay: firstDay,
    lastDay: lastDay,
    today: today,
    marks: marks,
    title: title,
  ),
);

/// A month grid for picking a day to view or log (U-9): swipe between
/// months, today ringed, days past [lastDay] disabled, and a dot for food
/// logged and another for a saved workout. Pops with the picked day.
class IndiFitMonthSheet extends StatefulWidget {
  const IndiFitMonthSheet({
    super.key,
    required this.initialDay,
    this.firstDay,
    this.lastDay,
    this.today,
    this.marks,
    this.title = 'Pick a day',
  });

  final DateTime initialDay;

  /// The earliest day that can be picked; 2020-01-01 when null.
  final DateTime? firstDay;

  /// The last day that can be picked; [today] when null.
  final DateTime? lastDay;

  /// The clock's day when null.
  final DateTime? today;
  final IndiFitMonthMarksLoader? marks;
  final String title;

  @override
  State<IndiFitMonthSheet> createState() => _IndiFitMonthSheetState();
}

class _IndiFitMonthSheetState extends State<IndiFitMonthSheet> {
  late final DateTime _today = _civil(widget.today ?? DateTime.now());
  late final DateTime _first = _civil(widget.firstDay ?? DateTime(2020));
  late final DateTime _last = _civil(widget.lastDay ?? _today);
  late final DateTime _firstMonth = DateTime(_first.year, _first.month);
  late final int _monthCount =
      _monthIndex(DateTime(_last.year, _last.month)) + 1;
  late final PageController _pages;
  late int _page;
  final Map<int, Future<IndiFitMonthMarks>> _marks = {};

  @override
  void initState() {
    super.initState();
    final initial = _civil(widget.initialDay);
    final clamped = initial.isBefore(_first)
        ? _first
        : initial.isAfter(_last)
        ? _last
        : initial;
    _page = _monthIndex(DateTime(clamped.year, clamped.month));
    _pages = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  int _monthIndex(DateTime month) =>
      (month.year - _firstMonth.year) * 12 + month.month - _firstMonth.month;

  DateTime _monthAt(int index) =>
      DateTime(_firstMonth.year, _firstMonth.month + index);

  Future<IndiFitMonthMarks> _marksFor(int index) => _marks.putIfAbsent(
    index,
    () =>
        widget.marks?.call(_monthAt(index)) ??
        Future.value(IndiFitMonthMarks.none),
  );

  void _go(int delta) {
    final next = _page + delta;
    if (next < 0 || next >= _monthCount) return;
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final month = _monthAt(_page);
    final colors = context.b05Colors;
    final selected = _civil(widget.initialDay);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        key: const Key('indifit_month_sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.title, style: B05Typography.title(context)),
              ),
              B05IconAction(
                icon: Icons.close_rounded,
                label: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                key: const Key('indifit_month_previous'),
                tooltip: 'Previous month',
                onPressed: _page > 0 ? () => _go(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM y').format(month),
                  key: const Key('indifit_month_title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                key: const Key('indifit_month_next'),
                tooltip: 'Next month',
                onPressed: _page < _monthCount - 1 ? () => _go(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          _WeekdayRow(firstWeekday: _firstWeekday(context)),
          SizedBox(
            // Six weeks of 48 pt rows.
            height: 6 * 48,
            child: PageView.builder(
              controller: _pages,
              itemCount: _monthCount,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => FutureBuilder<IndiFitMonthMarks>(
                future: _marksFor(index),
                builder: (context, snapshot) => _MonthGrid(
                  month: _monthAt(index),
                  firstWeekday: _firstWeekday(context),
                  first: _first,
                  last: _last,
                  today: _today,
                  selected: selected,
                  marks: snapshot.data ?? IndiFitMonthMarks.none,
                  onPick: (day) => Navigator.of(context).pop(day),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Dot(color: colors.success.indicator),
              const SizedBox(width: 4),
              Text('Food logged', style: B05Typography.caption(context)),
              const SizedBox(width: 16),
              _Dot(color: colors.info.indicator),
              const SizedBox(width: 4),
              Text('Workout saved', style: B05Typography.caption(context)),
            ],
          ),
        ],
      ),
    );
  }

  /// 1 = Monday ... 7 = Sunday, from the locale.
  int _firstWeekday(BuildContext context) {
    final index = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return index == 0 ? DateTime.sunday : index;
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.firstWeekday});

  final int firstWeekday;

  @override
  Widget build(BuildContext context) {
    // 2024-01-01 was a Monday.
    final names = [
      for (var i = 0; i < 7; i++)
        DateFormat(
          'EEEEE',
        ).format(DateTime(2024, 1, (firstWeekday - 1 + i) % 7 + 1)),
    ];
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final name in names)
            Expanded(
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: B05Typography.caption(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.firstWeekday,
    required this.first,
    required this.last,
    required this.today,
    required this.selected,
    required this.marks,
    required this.onPick,
  });

  final DateTime month;
  final int firstWeekday;
  final DateTime first;
  final DateTime last;
  final DateTime today;
  final DateTime selected;
  final IndiFitMonthMarks marks;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final lead = (month.weekday - firstWeekday) % 7;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = <Widget>[];
    for (var week = 0; week * 7 < lead + days; week++) {
      rows.add(
        Row(
          children: [
            for (var column = 0; column < 7; column++)
              Expanded(
                child: _cell(context, week * 7 + column - lead + 1, days),
              ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _cell(BuildContext context, int dayOfMonth, int days) {
    if (dayOfMonth < 1 || dayOfMonth > days) {
      return const SizedBox(height: 48);
    }
    final day = DateTime(month.year, month.month, dayOfMonth);
    return _DayCell(
      day: day,
      enabled: !day.isBefore(first) && !day.isAfter(last),
      isToday: day == today,
      isSelected: day == selected,
      food: marks.foodDays.contains(day),
      workout: marks.workoutDays.contains(day),
      today: today,
      onPick: onPick,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.enabled,
    required this.isToday,
    required this.isSelected,
    required this.food,
    required this.workout,
    required this.today,
    required this.onPick,
  });

  final DateTime day;
  final bool enabled;
  final bool isToday;
  final bool isSelected;
  final bool food;
  final bool workout;
  final DateTime today;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final iso = _isoDate(day);
    final label = [
      ConsumerDateLabel.date(iso),
      if (isToday) 'today',
      if (food) 'food logged',
      if (workout) 'workout saved',
      if (!enabled) 'not available',
    ].join(', ');
    final textColor = !enabled
        ? colors.textDisabled
        : isSelected
        ? colors.onAction
        : colors.textPrimary;
    return Semantics(
      button: enabled,
      enabled: enabled,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        key: ValueKey('indifit_month_day_$iso'),
        onTap: enabled ? () => onPick(day) : null,
        radius: 22,
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected && enabled ? colors.actionFill : null,
                  border: isToday
                      ? Border.all(color: colors.action, width: 1.5)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: textColor),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (food)
                      _Dot(
                        key: ValueKey('indifit_month_food_$iso'),
                        color: colors.success.indicator,
                      ),
                    if (food && workout) const SizedBox(width: 3),
                    if (workout)
                      _Dot(
                        key: ValueKey('indifit_month_workout_$iso'),
                        color: colors.info.indicator,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

DateTime _civil(DateTime value) => DateTime(value.year, value.month, value.day);

String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
