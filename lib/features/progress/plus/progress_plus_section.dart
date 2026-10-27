import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/plus/plus_gate.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../training/muscles_this_week.dart';
import '../widgets/progress_formatters.dart';
import '../widgets/progress_stat.dart';
import 'muscle_heatmap.dart';
import 'range_comparison.dart';

/// TP-9 on Progress: the 12-week muscle heatmap and the month / custom
/// comparison. Plus only; renders nothing while Plus is off.
class ProgressPlusSection extends StatelessWidget {
  const ProgressPlusSection({super.key, required this.units});

  final String units;

  @override
  Widget build(BuildContext context) {
    return PlusGate(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: B05Layout.space24),
          const MuscleHeatmapCard(),
          const SizedBox(height: B05Layout.space24),
          RangeComparisonCard(units: units),
        ],
      ),
    );
  }
}

String _civilLabel(String localDate) =>
    DateFormat('d MMM').format(DateTime.parse(localDate));

String _muscleLabel(String key) =>
    key.isEmpty ? key : '${key[0].toUpperCase()}${key.substring(1)}';

class MuscleHeatmapCard extends ConsumerWidget {
  const MuscleHeatmapCard({super.key});

  static const _labelWidth = 84.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmap = ref.watch(muscleHeatmapProvider).valueOrNull;
    if (heatmap == null) return const SizedBox.shrink();
    final colors = context.b05Colors;
    final max = heatmap.maxWeeklySets;

    Widget row(String label, List<Widget> cells, {String? semantics}) =>
        Semantics(
          label: semantics,
          excludeSemantics: semantics != null,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: B05Typography.caption(context),
                  ),
                ),
                for (final cell in cells) Expanded(child: cell),
              ],
            ),
          ),
        );

    Widget shade(double sets) => Container(
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: sets <= 0 || max <= 0
            ? colors.inset
            : colors.action.withValues(alpha: 0.2 + 0.8 * (sets / max)),
        borderRadius: BorderRadius.circular(3),
      ),
    );

    return B05Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Muscles, last 12 weeks',
            style: B05Typography.title(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            MuscleHeatmapWeeks.legend,
            style: B05Typography.caption(context),
          ),
          const SizedBox(height: B05Layout.space12),
          if (heatmap.isEmpty)
            Text(
              'No workouts saved in the last 12 weeks.',
              style: B05Typography.body(context),
            )
          else ...[
            row('', [
              Text(
                _civilLabel(heatmap.weekStarts.first),
                style: B05Typography.caption(context),
              ),
              Text(
                'This week',
                textAlign: TextAlign.end,
                style: B05Typography.caption(context),
              ),
            ]),
            for (final muscle in heatmap.muscles)
              row(
                _muscleLabel(muscle),
                [for (final sets in heatmap.sets[muscle]!) shade(sets)],
                semantics:
                    '${_muscleLabel(muscle)}, working sets per week, oldest '
                    'first: ${heatmap.sets[muscle]!.map(formatNumber).join(', ')}',
              ),
            const SizedBox(height: B05Layout.space4),
            row(
              'Training days',
              [
                for (final days in heatmap.trainingDays)
                  Text(
                    '$days',
                    textAlign: TextAlign.center,
                    style: B05Typography.caption(context).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
              semantics:
                  'Training days per week, oldest first: '
                  '${heatmap.trainingDays.join(', ')}',
            ),
          ],
        ],
      ),
    );
  }
}

class RangeComparisonCard extends ConsumerWidget {
  const RangeComparisonCard({super.key, required this.units});

  final String units;

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    RangeComparisonRequest current, {
    required bool first,
  }) async {
    final range = first ? current.first : current.second;
    final today = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: DateTimeRange(
        start: DateTime.parse(range.startLocalDate),
        end: DateTime.parse(range.endLocalDate),
      ),
    );
    if (picked == null) return;
    String civil(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
    final next = CivilRange(civil(picked.start), civil(picked.end));
    ref.read(customRangeComparisonProvider.notifier).state = first
        ? RangeComparisonRequest(first: next, second: current.second)
        : RangeComparisonRequest(first: current.first, second: next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(rangeComparisonModeProvider);
    final comparison = ref.watch(activeRangeComparisonProvider).valueOrNull;
    final a = comparison?.first;
    final b = comparison?.second;

    return B05Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compare periods',
            style: B05Typography.title(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: B05Layout.space8),
          SegmentedButton<RangeComparisonMode>(
            segments: const [
              ButtonSegment(
                value: RangeComparisonMode.month,
                label: Text('Month'),
              ),
              ButtonSegment(
                value: RangeComparisonMode.custom,
                label: Text('Custom'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (selection) =>
                ref.read(rangeComparisonModeProvider.notifier).state =
                    selection.first,
          ),
          if (a != null && b != null) ...[
            const SizedBox(height: B05Layout.space12),
            Row(
              children: [
                for (final (index, facts) in [a, b].indexed)
                  Expanded(
                    child: mode == RangeComparisonMode.custom
                        ? TextButton(
                            onPressed: () => _pick(
                              context,
                              ref,
                              RangeComparisonRequest(
                                first: CivilRange(
                                  a.summary.window.startLocalDate,
                                  a.summary.window.endLocalDate,
                                ),
                                second: CivilRange(
                                  b.summary.window.startLocalDate,
                                  b.summary.window.endLocalDate,
                                ),
                              ),
                              first: index == 0,
                            ),
                            child: Text(_periodLabel(facts)),
                          )
                        : Text(
                            _periodLabel(facts),
                            style: B05Typography.sectionLabel(context),
                          ),
                  ),
              ],
            ),
            ..._rows(a, b),
            ..._muscleRows(context, a, b),
          ],
        ],
      ),
    );
  }

  static String _periodLabel(PeriodRangeFacts facts) {
    final window = facts.summary.window;
    final range =
        '${_civilLabel(window.startLocalDate)} – '
        '${_civilLabel(window.endLocalDate)}';
    return window.isInProgress ? '$range (so far)' : range;
  }

  List<Widget> _rows(PeriodRangeFacts a, PeriodRangeFacts b) {
    String signed(double value, String Function(double) format) {
      if (value == 0) return 'Same';
      final text = format(value.abs());
      return value > 0 ? '+$text' : '−$text';
    }

    Widget pair(
      String label, {
      required double? first,
      required double? second,
      required String Function(double) format,
      String? missing,
      bool neutral = false,
    }) {
      ProgressStat stat(double? value, {ProgressStatDelta? delta}) =>
          value == null
          ? ProgressStat(
              value: '—',
              detail: missing,
              size: ProgressStatSize.compact,
            )
          : ProgressStat.split(
              format(value),
              delta: delta,
              size: ProgressStatSize.compact,
            );
      final change = first != null && second != null ? second - first : null;
      return Padding(
        padding: const EdgeInsets.only(top: B05Layout.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: stat(first)),
                Expanded(
                  child: stat(
                    second,
                    delta: change == null
                        ? null
                        : ProgressStatDelta(
                            text: signed(change, format),
                            trend: change > 0
                                ? ProgressTrend.up
                                : change < 0
                                ? ProgressTrend.down
                                : ProgressTrend.flat,
                            neutral: neutral,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    String count(double value) => formatNumber(value);
    return [
      pair(
        'Workouts',
        first: a.workouts.toDouble(),
        second: b.workouts.toDouble(),
        format: count,
      ),
      pair(
        'Working sets',
        first: a.workingSets.toDouble(),
        second: b.workingSets.toDouble(),
        format: count,
      ),
      pair(
        'Volume',
        first: a.volumeKg,
        second: b.volumeKg,
        format: (kg) => formatTotalLifted(kg, units),
        missing: 'No weighted sets',
      ),
      pair(
        'Days logged',
        first: a.daysLogged?.toDouble(),
        second: b.daysLogged?.toDouble(),
        format: count,
        missing: 'Not available',
      ),
      pair(
        'Average protein, logged days',
        first: a.averageProteinG,
        second: b.averageProteinG,
        format: (grams) => '${grams.round()} g',
        missing: 'No days logged',
      ),
      pair(
        'Weight change',
        first: a.weightChangeKg,
        second: b.weightChangeKg,
        format: (kg) => formatWeight(kg, units),
        missing: 'Needs 2 weigh-ins',
        neutral: true,
      ),
    ];
  }

  List<Widget> _muscleRows(
    BuildContext context,
    PeriodRangeFacts a,
    PeriodRangeFacts b,
  ) {
    final muscles = {...a.muscles.sets.keys, ...b.muscles.sets.keys}.toList()
      ..sort((x, y) {
        double total(String m) =>
            (a.muscles.sets[m] ?? 0) + (b.muscles.sets[m] ?? 0);
        final byTotal = total(y).compareTo(total(x));
        return byTotal != 0 ? byTotal : x.compareTo(y);
      });
    if (muscles.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: B05Layout.space16),
        child: Text(
          'Working sets per muscle group',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      for (final muscle in muscles)
        Padding(
          padding: const EdgeInsets.only(top: B05Layout.space4),
          child: Row(
            children: [
              for (final facts in [a, b])
                Expanded(
                  child: Text(
                    '${_muscleLabel(muscle)} '
                    '${formatNumber(facts.muscles.sets[muscle] ?? 0)}',
                  ),
                ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: B05Layout.space4),
        child: Text(
          'Counted by the rule: ${MuscleSetRule.ruleText}',
          style: B05Typography.caption(context),
        ),
      ),
    ];
  }
}
