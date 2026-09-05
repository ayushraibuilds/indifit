import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/services/indifit_haptics.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../progress_dashboard_models.dart';
import 'progress_formatters.dart';
import 'progress_sections.dart';
import 'progress_view_models.dart';

/// Progress weight widgets (PV1-ENG-05A first pass).
///
/// Extracted verbatim from `progress_screen.dart`; behavior unchanged.

class ProgressWeightSection extends StatefulWidget {
  const ProgressWeightSection({super.key, 
    required this.snapshot,
    required this.range,
    required this.ranges,
    required this.measurements,
    required this.onRangeSelected,
    required this.onLogWeight,
    required this.onViewHistory,
    required this.units,
  });

  final ProgressDashboardSnapshot snapshot;
  final ProgressTimeRange range;
  final List<ProgressTimeRange> ranges;
  final List<ProgressMeasurementRecord> measurements;
  final ValueChanged<ProgressTimeRange> onRangeSelected;
  final VoidCallback onLogWeight;
  final VoidCallback onViewHistory;
  final String units;

  @override
  State<ProgressWeightSection> createState() => ProgressWeightSectionState();
}

class ProgressWeightSectionState extends State<ProgressWeightSection> {
  int? _touchedPoint;

  @override
  void didUpdateWidget(covariant ProgressWeightSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measurements != widget.measurements) _touchedPoint = null;
  }

  @override
  Widget build(BuildContext context) {
    final measurements = widget.measurements;
    final dailyMeasurements = dailyWeightObservations(measurements);
    final latest = dailyMeasurements.last;
    final hasChart = hasWeightChartHistory(measurements);
    final hasSameDayEntries = measurements.length != dailyMeasurements.length;
    final allMeasurements = dailyWeightObservations(
      widget.snapshot.weightMeasurements,
    );
    final hasLongerHistory = hasWeightChartHistory(allMeasurements);
    final showRangeSelector = hasLongerHistory && widget.ranges.length > 1;
    final selected =
        _touchedPoint == null || _touchedPoint! >= dailyMeasurements.length
        ? latest
        : dailyMeasurements[_touchedPoint!];
    final colors = context.b05Colors;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final logWeightAction = B05ActionButton(
      label: 'Log weight',
      icon: Icons.add_rounded,
      emphasis: B05ActionEmphasis.tertiary,
      onPressed: widget.onLogWeight,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stackHeader = constraints.maxWidth < 330 && textScale >= 1.5;
            if (stackHeader) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProgressSectionHeading(title: 'Weight'),
                  const SizedBox(height: B05Layout.space4),
                  logWeightAction,
                ],
              );
            }
            return Row(
              children: [
                const Expanded(child: ProgressSectionHeading(title: 'Weight')),
                logWeightAction,
              ],
            );
          },
        ),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: EdgeInsets.all(
            hasChart ? B05Layout.space20 : B05Layout.space16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: weightSemantics(measurements, widget.units),
                child: ExcludeSemantics(
                  child: Text(
                    formatWeight(latest.weightKg!, widget.units),
                    style: B05Typography.metric(context),
                  ),
                ),
              ),
              const SizedBox(height: B05Layout.space4),
              Text(
                weightDetail(measurements, widget.units),
                style: B05Typography.body(context),
              ),
              if (showRangeSelector) ...[
                const SizedBox(height: B05Layout.space16),
                ProgressWeightRangeSelector(
                  ranges: widget.ranges,
                  selected: widget.range,
                  onSelected: widget.onRangeSelected,
                ),
              ],
              if (!hasChart && dailyMeasurements.length == 1) ...[
                const SizedBox(height: B05Layout.space16),
                Text(
                  hasLongerHistory
                      ? 'One measurement in this period. Choose a longer range to see more history.'
                      : measurements.length > 1
                      ? 'Multiple weigh-ins were recorded on one day. Log a measurement on another day to start seeing a trend.'
                      : 'Log another measurement to start seeing your trend.',
                  style: B05Typography.caption(context),
                ),
              ],
              if (!hasChart && dailyMeasurements.length == 2) ...[
                const SizedBox(height: B05Layout.space16),
                Text(
                  hasLongerHistory
                      ? 'Two measurements in this period. Choose a longer range to see more history.'
                      : 'Two measurements recorded. Add another to see a fuller trend.',
                  style: B05Typography.caption(context),
                ),
              ],
              if (hasChart) ...[
                const SizedBox(height: B05Layout.space20),
                Semantics(
                  container: true,
                  label: weightSemantics(measurements, widget.units),
                  hint:
                      'Drag across the chart to inspect each recorded weight.',
                  child: SizedBox(
                    key: const ValueKey('progress_weight_chart'),
                    height: 200,
                    child: LineChart(
                      weightChartData(
                        context: context,
                        measurements: dailyMeasurements,
                        units: widget.units,
                        onTouch: (index) =>
                            setState(() => _touchedPoint = index),
                      ),
                      duration: B05MotionPolicy.transitionDuration(context),
                    ),
                  ),
                ),
                const SizedBox(height: B05Layout.space8),
                Text(
                  '${shortCivilDate(measurementDate(selected))} · ${formatWeight(selected.weightKg!, widget.units)}',
                  style: B05Typography.caption(
                    context,
                  ).copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: B05Layout.space4),
                Text(
                  hasSameDayEntries
                      ? 'Chart shows the latest value for each local day; history keeps every entry.'
                      : 'Each point is a recorded local-day value; gaps are not filled.',
                  style: B05Typography.caption(context),
                ),
              ],
              const SizedBox(height: B05Layout.space12),
              B05ActionButton(
                label: 'View weight history',
                icon: Icons.history_rounded,
                emphasis: B05ActionEmphasis.tertiary,
                onPressed: widget.onViewHistory,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Full-fidelity weight history. The chart intentionally uses one value per
/// local day for trend readability, while this screen keeps every persisted
/// weight record in deterministic newest-first order.
class ProgressWeightHistoryScreen extends StatelessWidget {
  const ProgressWeightHistoryScreen({
    super.key,
    required this.measurements,
    required this.todayLocalDate,
    required this.timezoneId,
    required this.units,
  });

  final List<ProgressMeasurementRecord> measurements;
  final String todayLocalDate;
  final String timezoneId;
  final String units;

  @override
  Widget build(BuildContext context) {
    final ordered =
        measurements
            .where(
              (measurement) =>
                  measurement.weightKg != null &&
                  measurement.weightKg!.isFinite &&
                  measurement.weightKg! > 0,
            )
            .toList(growable: true)
          ..sort(compareMeasurementsNewestFirst);

    return Scaffold(
      appBar: AppBar(title: const Text('Weight history')),
      body: ordered.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(B05Layout.space24),
                child: Text(
                  'No weight entries yet.',
                  style: B05Typography.body(context),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                B05Layout.space20,
                B05Layout.space16,
                B05Layout.space20,
                B05Layout.space24,
              ),
              itemCount: ordered.length + 1,
              separatorBuilder: (_, index) => index == ordered.length - 1
                  ? const SizedBox(height: B05Layout.space16)
                  : const SizedBox(height: B05Layout.space8),
              itemBuilder: (context, index) {
                if (index == ordered.length) {
                  return Text(
                    'Today’s entry can be edited from Log weight. Earlier entries are shown as recorded.',
                    style: B05Typography.caption(context),
                  );
                }
                final measurement = ordered[index];
                final weight = measurement.weightKg!;
                final date = fullCivilDate(measurement.localDate);
                final time = measurementTime(measurement, timezoneId);
                final today = measurement.localDate == todayLocalDate;
                final latest = index == 0;
                final dateLabel = [if (today) 'Today', date, ?time].join(' · ');
                return Semantics(
                  container: true,
                  label:
                      '${latest ? 'Latest. ' : ''}$dateLabel. ${formatWeight(weight, units)}.',
                  child: B05Surface(
                    tone: B05SurfaceTone.interactive,
                    padding: const EdgeInsets.all(B05Layout.space16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateLabel,
                                style: B05Typography.label(context),
                              ),
                              const SizedBox(height: B05Layout.space4),
                              Text(
                                latest
                                    ? 'Latest recorded weight'
                                    : 'Recorded weight',
                                style: B05Typography.caption(context),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: B05Layout.space12),
                        Text(
                          formatWeight(weight, units),
                          style: B05Typography.label(context),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ProgressWeightRangeSelector extends StatelessWidget {
  const ProgressWeightRangeSelector({super.key, 
    required this.ranges,
    required this.selected,
    required this.onSelected,
  });

  final List<ProgressTimeRange> ranges;
  final ProgressTimeRange selected;
  final ValueChanged<ProgressTimeRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Weight chart time range',
      child: Wrap(
        spacing: B05Layout.space8,
        runSpacing: B05Layout.space8,
        children: [
          for (final range in ranges)
            Semantics(
              label: '${range.label} weight range',
              selected: range == selected,
              button: true,
              child: ChoiceChip(
                label: Text(range.label),
                selected: range == selected,
                onSelected: (isSelected) {
                  if (!isSelected || range == selected) return;
                  onSelected(range);
                  unawaited(IndiFitHaptics.selection());
                },
              ),
            ),
        ],
      ),
    );
  }
}

