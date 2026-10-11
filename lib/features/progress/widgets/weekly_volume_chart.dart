import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/indifit_haptics.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../r08f4_training_volume_presentation.dart';
import 'progress_formatters.dart';
import 'progress_view_models.dart';

/// Loaded volume per week as bars, oldest on the left (V9). The current week
/// is selected first; tapping a bar selects that week and the line under the
/// chart reads it out. Empty weeks keep a short stub so a gap reads as a gap.
class WeeklyVolumeChart extends StatefulWidget {
  const WeeklyVolumeChart({
    super.key,
    required this.weeks,
    required this.unitSymbol,
  });

  final List<R08F4WeeklyVolume> weeks;
  final String unitSymbol;

  /// The chart needs two weeks with volume to show a change.
  static bool canShow(List<R08F4WeeklyVolume> weeks) =>
      weeks.where((week) => week.volumeKg > 0).length >= 2;

  @override
  State<WeeklyVolumeChart> createState() => _WeeklyVolumeChartState();
}

class _WeeklyVolumeChartState extends State<WeeklyVolumeChart> {
  static const double _barAreaHeight = 112;
  static const double _stubHeight = 3;

  late int _selected = widget.weeks.length - 1;

  @override
  void didUpdateWidget(WeeklyVolumeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected >= widget.weeks.length) _selected = widget.weeks.length - 1;
  }

  void _select(int index) {
    if (index == _selected) return;
    unawaited(IndiFitHaptics.selection());
    setState(() => _selected = index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final weeks = widget.weeks;
    final peak = weeks.fold<double>(
      0,
      (max, week) => week.displayVolume > max ? week.displayVolume : max,
    );
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    // Every other label at large text, always keeping this week's.
    final labelEvery = textScale >= 1.3 ? 2 : 1;
    final duration = B05MotionPolicy.transitionDuration(context);
    final selected = weeks[_selected];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < weeks.length; i++)
              Expanded(
                child: Semantics(
                  key: ValueKey('weekly_volume_bar_$i'),
                  button: true,
                  selected: i == _selected,
                  label: _semanticLabel(weeks[i]),
                  onTap: () => _select(i),
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _select(i),
                      child: Column(
                        children: [
                          SizedBox(
                            height: _barAreaHeight,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                widthFactor: 0.56,
                                child: AnimatedContainer(
                                  duration: duration,
                                  curve: B05MotionPolicy.standardCurve,
                                  height: _barHeight(weeks[i], peak),
                                  decoration: BoxDecoration(
                                    color: weeks[i].volumeKg <= 0
                                        ? colors.border
                                        : i == _selected
                                        ? colors.action
                                        : colors.action.withValues(alpha: 0.32),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                      bottom: Radius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: B05Layout.space8),
                          Text(
                            (weeks.length - 1 - i) % labelEvery == 0
                                ? _axisLabel(i)
                                : '',
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            softWrap: false,
                            style: B05Typography.caption(context).copyWith(
                              fontSize: 11,
                              color: i == _selected
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                              fontWeight: i == _selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: B05Layout.space12),
        Text(
          _selectionLine(selected),
          key: const ValueKey('weekly_volume_selection'),
          style: B05Typography.caption(
            context,
          ).copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }

  double _barHeight(R08F4WeeklyVolume week, double peak) {
    if (week.volumeKg <= 0 || peak <= 0) return _stubHeight;
    final height = week.displayVolume / peak * _barAreaHeight;
    return height < 6 ? 6 : height;
  }

  /// "18 Aug", then day numbers until the month changes: "25", "1 Sep", "8".
  String _axisLabel(int index) {
    final start = parseCivilDate(widget.weeks[index].weekStartLocalDate);
    if (index == 0) return DateFormat('d MMM').format(start);
    final previous = parseCivilDate(widget.weeks[index - 1].weekStartLocalDate);
    return previous.month == start.month
        ? '${start.day}'
        : DateFormat('d MMM').format(start);
  }

  String _weekName(R08F4WeeklyVolume week) => week.isCurrentWeek
      ? 'This week'
      : 'Week of ${DateFormat('d MMM').format(parseCivilDate(week.weekStartLocalDate))}';

  String _amount(R08F4WeeklyVolume week) =>
      '${formatVolume(week.displayVolume)} ${widget.unitSymbol}';

  String _workouts(R08F4WeeklyVolume week) =>
      '${week.sessionCount} ${week.sessionCount == 1 ? 'workout' : 'workouts'}';

  String _selectionLine(R08F4WeeklyVolume week) => week.volumeKg <= 0
      ? '${_weekName(week)} · No loaded volume'
      : '${_weekName(week)} · ${_amount(week)} · ${_workouts(week)}';

  String _semanticLabel(R08F4WeeklyVolume week) {
    final unitWord = widget.unitSymbol == 'lb' ? 'pounds' : 'kilograms';
    return week.volumeKg <= 0
        ? '${_weekName(week)}, no loaded volume.'
        : '${_weekName(week)}, ${formatVolume(week.displayVolume)} $unitWord, ${_workouts(week)}.';
  }
}
