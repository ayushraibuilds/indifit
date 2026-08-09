import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/presentation/product_failure_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/models/b02_muscle_volume_models.dart';
import '../../data/repositories/workout_repository.dart';
import '../dashboard/widgets/log_weight_bottom_sheet.dart';
import '../workout_player/routine_display_screen.dart';
import 'achievements_screen.dart';
import 'progress_dashboard_controller.dart';
import 'progress_dashboard_models.dart';

/// Outcome-first Progress composition.
///
/// The screen is deliberately allowed to be small: sections appear only when
/// the underlying completed-session, B02 performed-set, measurement, or B02
/// muscle-volume facts can support a useful statement.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key, this.preview});

  /// Deterministic read seam used by representative UX tests. Production
  /// callers leave this null and consume [progressDashboardSnapshotProvider].
  final ProgressDashboardSnapshot? preview;

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  _ProgressTimeRange _weightRange = _ProgressTimeRange.oneMonth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          PopupMenuButton<_ProgressMenuAction>(
            tooltip: 'More progress options',
            onSelected: (action) {
              if (action == _ProgressMenuAction.achievements) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ProgressMenuAction.achievements,
                child: Text('Achievements'),
              ),
            ],
          ),
        ],
      ),
      body: widget.preview == null
          ? _buildProductionBody()
          : _buildSnapshot(widget.preview!),
    );
  }

  Widget _buildProductionBody() {
    final snapshot = ref.watch(progressDashboardSnapshotProvider);
    return snapshot.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(B05Layout.space20),
          child: ConsumerStatusRow(
            label: 'Loading your progress',
            detail: 'Preparing your recent activity and measurements.',
            loading: true,
          ),
        ),
      ),
      error: (_, _) => _failureState(),
      data: _buildSnapshot,
    );
  }

  Widget _buildSnapshot(ProgressDashboardSnapshot snapshot) {
    if (snapshot.hasKnownZeroData) return _emptyState(snapshot);
    if (snapshot.hasPrimaryDataFailureWithoutUsefulFacts) {
      return _failureState();
    }

    final range = _effectiveWeightRange(snapshot);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        key: const ValueKey('progress_scroll_view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgressOverview(
                  snapshot: snapshot,
                  selectedWeights: _weightsForRange(snapshot, range),
                ),
                if (snapshot.unavailableSections.isNotEmpty) ...[
                  const SizedBox(height: B05Layout.space12),
                  ConsumerStatusRow(
                    label: 'Some progress details are unavailable',
                    detail: 'Your available history is still shown.',
                    error: true,
                    onRetry: _refresh,
                  ),
                ],
                if (snapshot.weightMeasurements.isNotEmpty) ...[
                  const SizedBox(height: B05Layout.space24),
                  _WeightSection(
                    snapshot: snapshot,
                    range: range,
                    ranges: _availableWeightRanges(snapshot),
                    measurements: _weightsForRange(snapshot, range),
                    onRangeSelected: (value) {
                      setState(() => _weightRange = value);
                    },
                    onLogWeight: () => _logWeight(snapshot),
                  ),
                ],
                if ((snapshot.workouts?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: B05Layout.space24),
                  _TrainingConsistencySection(
                    snapshot: snapshot,
                    onViewHistory: () => _openTrainingHistory(snapshot),
                  ),
                ],
                if ((snapshot.strengthSets?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: B05Layout.space24),
                  _StrengthSection(
                    records: snapshot.strengthSets!,
                    onOpenHistory: (highlight) => _openExerciseHistory(
                      highlight.exerciseName,
                      highlight.records,
                    ),
                  ),
                ],
                if (_hasMeaningfulVolume(snapshot)) ...[
                  const SizedBox(height: B05Layout.space24),
                  _TrainingVolumeSection(snapshot: snapshot),
                ],
                if (_hasMeaningfulMuscleBalance(snapshot)) ...[
                  const SizedBox(height: B05Layout.space24),
                  _MuscleBalanceSection(readModel: snapshot.muscleBalance!),
                ],
                if (snapshot.bodyMeasurements.isNotEmpty) ...[
                  const SizedBox(height: B05Layout.space24),
                  _MeasurementsSection(
                    measurements: snapshot.bodyMeasurements,
                    onLogMeasurement: () => _logMeasurements(snapshot),
                    onViewHistory: () => _openMeasurementHistory(snapshot),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ProgressDashboardSnapshot snapshot) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(B05Layout.space24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Semantics(
            container: true,
            label:
                'Your progress starts here. Complete a workout or log a weigh-in to start seeing useful trends.',
            child: B05Surface(
              tone: B05SurfaceTone.inset,
              padding: const EdgeInsets.all(B05Layout.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_graph_rounded,
                    color: context.b05Colors.action,
                    size: 32,
                  ),
                  const SizedBox(height: B05Layout.space16),
                  Text(
                    'Your progress starts here',
                    style: B05Typography.title(context),
                  ),
                  const SizedBox(height: B05Layout.space4),
                  Text(
                    'Complete a workout or log another weigh-in to start seeing useful trends.',
                    style: B05Typography.body(context),
                  ),
                  const SizedBox(height: B05Layout.space20),
                  B05ActionGroup(
                    children: [
                      B05ActionButton(
                        label: 'Log weight',
                        icon: Icons.scale_rounded,
                        onPressed: () => _logWeight(snapshot),
                      ),
                      B05ActionButton(
                        label: 'Start workout',
                        icon: Icons.fitness_center_rounded,
                        emphasis: B05ActionEmphasis.secondary,
                        onPressed: _startWorkout,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _failureState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(B05Layout.space20),
        child: ProductFailureCard(
          failure: ProductFailurePresentation.fromCode(
            'progress_unavailable',
            title: 'Couldn’t load your progress',
          ),
          onRetry: _refresh,
        ),
      ),
    );
  }

  _ProgressTimeRange _effectiveWeightRange(ProgressDashboardSnapshot snapshot) {
    final ranges = _availableWeightRanges(snapshot);
    if (!ranges.contains(_weightRange)) return ranges.last;
    if (_weightsForRange(snapshot, _weightRange).isEmpty) return ranges.last;
    return _weightRange;
  }

  List<_ProgressTimeRange> _availableWeightRanges(
    ProgressDashboardSnapshot snapshot,
  ) {
    final all = _weightsForRange(snapshot, _ProgressTimeRange.all);
    if (all.isEmpty) return const [_ProgressTimeRange.oneMonth];
    final firstDate = _measurementDate(all.first);
    final values = <_ProgressTimeRange>[_ProgressTimeRange.oneMonth];
    if (firstDate.compareTo(
          _ProgressTimeRange.oneMonth.startDate(snapshot.todayLocalDate),
        ) <
        0) {
      values.add(_ProgressTimeRange.threeMonths);
    }
    if (firstDate.compareTo(
          _ProgressTimeRange.threeMonths.startDate(snapshot.todayLocalDate),
        ) <
        0) {
      values.add(_ProgressTimeRange.sixMonths);
    }
    if (firstDate.compareTo(
          _ProgressTimeRange.sixMonths.startDate(snapshot.todayLocalDate),
        ) <
        0) {
      values.add(_ProgressTimeRange.oneYear);
    }
    if (firstDate.compareTo(
          _ProgressTimeRange.oneYear.startDate(snapshot.todayLocalDate),
        ) <
        0) {
      values.add(_ProgressTimeRange.all);
    }
    return values;
  }

  List<ProgressMeasurementRecord> _weightsForRange(
    ProgressDashboardSnapshot snapshot,
    _ProgressTimeRange range,
  ) {
    final records = snapshot.weightMeasurements.toList(growable: true)
      ..sort((first, second) => first.recordedAt.compareTo(second.recordedAt));
    if (range == _ProgressTimeRange.all) return records;
    final start = range.startDate(snapshot.todayLocalDate);
    return records
        .where((record) => _measurementDate(record).compareTo(start) >= 0)
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    if (widget.preview != null) return;
    ref.invalidate(progressDashboardSnapshotProvider);
    try {
      await ref.read(progressDashboardSnapshotProvider.future);
    } catch (_) {
      // The provider maps recoverable source failures to section-level state.
    }
  }

  Future<void> _logWeight(ProgressDashboardSnapshot snapshot) async {
    final weights = snapshot.weightMeasurements.toList(growable: true)
      ..sort((first, second) => first.recordedAt.compareTo(second.recordedAt));
    final latest = weights.isEmpty ? null : weights.last;
    await LogWeightBottomSheet.show(context, latest?.weightKg ?? 70, (
      weight,
    ) async {
      await ref
          .read(workoutRepositoryProvider)
          .logWeightAndSyncProfile(weight: weight);
      await _refresh();
    });
  }

  void _startWorkout() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RoutineDisplayScreen()));
  }

  void _openTrainingHistory(ProgressDashboardSnapshot snapshot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProgressTrainingHistoryScreen(
          workouts: snapshot.workouts ?? const [],
        ),
      ),
    );
  }

  void _openExerciseHistory(
    String exerciseName,
    List<ProgressStrengthSetRecord> records,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProgressExerciseHistoryScreen(
          exerciseName: exerciseName,
          records: records,
        ),
      ),
    );
  }

  void _openMeasurementHistory(ProgressDashboardSnapshot snapshot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProgressMeasurementHistoryScreen(
          measurements: snapshot.bodyMeasurements,
        ),
      ),
    );
  }

  Future<void> _logMeasurements(ProgressDashboardSnapshot snapshot) async {
    await showIndiFitBottomSheet<void>(
      context: context,
      semanticLabel: 'Log body measurements',
      builder: (_) => _LogBodyMeasurementsSheet(onSaved: _refresh),
    );
  }
}

enum _ProgressMenuAction { achievements }

enum _ProgressTimeRange {
  oneMonth('1M', 1),
  threeMonths('3M', 3),
  sixMonths('6M', 6),
  oneYear('1Y', 12),
  all('All', null);

  const _ProgressTimeRange(this.label, this.months);

  final String label;
  final int? months;

  String startDate(String today) {
    if (months == null) return '0000-01-01';
    final parsed = _parseCivilDate(today);
    return _formatCivilDate(_subtractMonths(parsed, months!));
  }
}

class _ProgressOverview extends StatelessWidget {
  const _ProgressOverview({
    required this.snapshot,
    required this.selectedWeights,
  });

  final ProgressDashboardSnapshot snapshot;
  final List<ProgressMeasurementRecord> selectedWeights;

  @override
  Widget build(BuildContext context) {
    final metrics = <Widget>[];
    if (selectedWeights.isNotEmpty) {
      final latest = selectedWeights.last;
      metrics.add(
        _OverviewMetric(
          value: _formatWeight(latest.weightKg!),
          label: _weightOverviewDetail(selectedWeights),
          semanticLabel: _weightSemantics(snapshot, selectedWeights),
          direction: _weightDirectionIcon(selectedWeights),
          color: _goalAwareTrendColor(context, snapshot, selectedWeights),
        ),
      );
    }
    final thisWeek = _workoutsThisWeek(snapshot);
    if (thisWeek.isNotEmpty) {
      metrics.add(
        _OverviewMetric(
          value: '${thisWeek.length}',
          label: thisWeek.length == 1
              ? 'workout this week'
              : 'workouts this week',
          semanticLabel:
              '${thisWeek.length} ${thisWeek.length == 1 ? 'workout' : 'workouts'} completed this week',
          direction: Icons.calendar_today_rounded,
        ),
      );
    }
    final strength = _selectStrengthHighlight(
      snapshot.strengthSets ?? const [],
    );
    if (strength != null) {
      metrics.add(
        _OverviewMetric(
          value: _formatSet(strength.heaviest),
          label: strength.comparisonText ?? strength.exerciseName,
          semanticLabel:
              '${strength.exerciseName}, ${_formatSet(strength.heaviest)}. ${strength.comparisonText ?? 'Heaviest recorded performed set.'}',
          direction: Icons.fitness_center_rounded,
        ),
      );
    }
    if (metrics.isEmpty && snapshot.bodyMeasurements.isNotEmpty) {
      final measurements = snapshot.bodyMeasurements.toList(
        growable: true,
      )..sort((first, second) => second.recordedAt.compareTo(first.recordedAt));
      final bodyValues = _bodyMeasurementValues(measurements);
      if (bodyValues.isNotEmpty) {
        final value = bodyValues.first;
        metrics.add(
          _OverviewMetric(
            value: '${_formatNumber(value.value)} cm',
            label: 'latest ${value.label.toLowerCase()}',
            semanticLabel:
                '${value.label}: ${_formatNumber(value.value)} centimetres, latest measurement.',
            direction: Icons.straighten_rounded,
          ),
        );
      }
    }

    if (metrics.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: 'Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(title: 'Overview'),
          const SizedBox(height: B05Layout.space8),
          B05Surface(
            padding: const EdgeInsets.all(B05Layout.space20),
            child: Wrap(spacing: 24, runSpacing: 20, children: metrics),
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.value,
    required this.label,
    required this.semanticLabel,
    required this.direction,
    this.color,
  });

  final String value;
  final String label;
  final String semanticLabel;
  final IconData direction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final valueColor = color ?? colors.textPrimary;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 132, maxWidth: 240),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(direction, size: 16, color: valueColor),
                  const SizedBox(width: B05Layout.space4),
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: B05Typography.title(
                        context,
                      ).copyWith(color: valueColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(label, style: B05Typography.caption(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightSection extends StatefulWidget {
  const _WeightSection({
    required this.snapshot,
    required this.range,
    required this.ranges,
    required this.measurements,
    required this.onRangeSelected,
    required this.onLogWeight,
  });

  final ProgressDashboardSnapshot snapshot;
  final _ProgressTimeRange range;
  final List<_ProgressTimeRange> ranges;
  final List<ProgressMeasurementRecord> measurements;
  final ValueChanged<_ProgressTimeRange> onRangeSelected;
  final VoidCallback onLogWeight;

  @override
  State<_WeightSection> createState() => _WeightSectionState();
}

class _WeightSectionState extends State<_WeightSection> {
  int? _touchedPoint;

  @override
  void didUpdateWidget(covariant _WeightSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measurements != widget.measurements) _touchedPoint = null;
  }

  @override
  Widget build(BuildContext context) {
    final measurements = widget.measurements;
    final latest = measurements.last;
    final hasChart = _hasWeightChartHistory(measurements);
    final allMeasurements = widget.snapshot.weightMeasurements.toList(
      growable: true,
    )..sort((first, second) => first.recordedAt.compareTo(second.recordedAt));
    final hasLongerHistory = _hasWeightChartHistory(allMeasurements);
    final showRangeSelector = hasLongerHistory && widget.ranges.length > 1;
    final selected =
        _touchedPoint == null || _touchedPoint! >= measurements.length
        ? latest
        : measurements[_touchedPoint!];
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
                  const _SectionHeading(title: 'Weight'),
                  const SizedBox(height: B05Layout.space4),
                  logWeightAction,
                ],
              );
            }
            return Row(
              children: [
                const Expanded(child: _SectionHeading(title: 'Weight')),
                logWeightAction,
              ],
            );
          },
        ),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: _weightSemantics(widget.snapshot, measurements),
                child: ExcludeSemantics(
                  child: Text(
                    _formatWeight(latest.weightKg!),
                    style: B05Typography.metric(context),
                  ),
                ),
              ),
              const SizedBox(height: B05Layout.space4),
              Text(
                _weightDetail(measurements),
                style: B05Typography.body(context),
              ),
              if (widget.snapshot.weightGoal case final goal?) ...[
                const SizedBox(height: B05Layout.space12),
                _WeightGoalSummary(goal: goal, currentWeight: latest.weightKg!),
              ],
              if (showRangeSelector) ...[
                const SizedBox(height: B05Layout.space16),
                _WeightRangeSelector(
                  ranges: widget.ranges,
                  selected: widget.range,
                  onSelected: widget.onRangeSelected,
                ),
              ],
              if (measurements.length == 1) ...[
                const SizedBox(height: B05Layout.space16),
                Text(
                  hasLongerHistory
                      ? 'One measurement in this period. Choose a longer range to see more history.'
                      : 'Log another measurement to start seeing your trend.',
                  style: B05Typography.caption(context),
                ),
              ],
              if (measurements.length == 2) ...[
                const SizedBox(height: B05Layout.space16),
                Text(
                  hasLongerHistory
                      ? 'Two measurements in this period. Choose a longer range to see more history.'
                      : 'Two measurements recorded. Add another to see a fuller trend.',
                  style: B05Typography.caption(context),
                ),
              ],
              if (measurements.length >= 3 && !hasChart) ...[
                const SizedBox(height: B05Layout.space16),
                Text(
                  hasLongerHistory
                      ? 'This period only has same-day measurements. Choose a longer range to see more history.'
                      : 'Log a measurement on another day to start seeing a trend.',
                  style: B05Typography.caption(context),
                ),
              ],
              if (hasChart) ...[
                const SizedBox(height: B05Layout.space20),
                Semantics(
                  container: true,
                  label: _weightSemantics(widget.snapshot, measurements),
                  hint:
                      'Drag across the chart to inspect each recorded weight.',
                  child: SizedBox(
                    key: const ValueKey('progress_weight_chart'),
                    height: 200,
                    child: LineChart(
                      _weightChartData(
                        context: context,
                        measurements: measurements,
                        goal: widget.snapshot.weightGoal,
                        onTouch: (index) =>
                            setState(() => _touchedPoint = index),
                      ),
                      duration: B05MotionPolicy.transitionDuration(context),
                    ),
                  ),
                ),
                const SizedBox(height: B05Layout.space8),
                Text(
                  '${_shortCivilDate(_measurementDate(selected))} · ${_formatWeight(selected.weightKg!)}',
                  style: B05Typography.caption(
                    context,
                  ).copyWith(color: colors.textPrimary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WeightGoalSummary extends StatelessWidget {
  const _WeightGoalSummary({required this.goal, required this.currentWeight});

  final ProgressWeightGoal goal;
  final double currentWeight;

  @override
  Widget build(BuildContext context) {
    final distance = (currentWeight - goal.targetKg).abs();
    final targetLabel =
        goal.direction == ProgressWeightGoalDirection.maintenance
        ? 'Target ${_formatWeight(goal.targetKg)}'
        : 'Goal ${_formatWeight(goal.targetKg)}';
    return Semantics(
      label: goal.direction == ProgressWeightGoalDirection.maintenance
          ? targetLabel
          : '$targetLabel. ${_formatWeight(distance)} to go.',
      child: B05Surface(
        tone: B05SurfaceTone.inset,
        radius: B05SurfaceRadius.small,
        padding: const EdgeInsets.symmetric(
          horizontal: B05Layout.space12,
          vertical: B05Layout.space8,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final stacked = constraints.maxWidth < 330 || textScale >= 1.5;
            final target = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: context.b05Colors.action,
                ),
                const SizedBox(width: B05Layout.space8),
                Flexible(
                  child: Text(
                    targetLabel,
                    style: B05Typography.caption(context),
                  ),
                ),
              ],
            );
            final distanceText = Text(
              '${_formatWeight(distance)} to go',
              style: B05Typography.label(context),
            );
            if (goal.direction == ProgressWeightGoalDirection.maintenance) {
              return target;
            }
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  target,
                  const SizedBox(height: B05Layout.space4),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: distanceText,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: target),
                const SizedBox(width: B05Layout.space8),
                distanceText,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WeightRangeSelector extends StatelessWidget {
  const _WeightRangeSelector({
    required this.ranges,
    required this.selected,
    required this.onSelected,
  });

  final List<_ProgressTimeRange> ranges;
  final _ProgressTimeRange selected;
  final ValueChanged<_ProgressTimeRange> onSelected;

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
                onSelected: (_) => onSelected(range),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrainingConsistencySection extends StatelessWidget {
  const _TrainingConsistencySection({
    required this.snapshot,
    required this.onViewHistory,
  });

  final ProgressDashboardSnapshot snapshot;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final thisWeek = _workoutsThisWeek(snapshot);
    final lastFourWeeks = _workoutsInRecentFourWeeks(snapshot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: 'Training consistency'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: thisWeek.isEmpty
                    ? 'No workouts completed this week.'
                    : '${thisWeek.length} ${thisWeek.length == 1 ? 'workout' : 'workouts'} completed this week.',
                child: ExcludeSemantics(
                  child: Text(
                    thisWeek.isEmpty
                        ? 'No workouts yet'
                        : '${thisWeek.length} ${thisWeek.length == 1 ? 'workout' : 'workouts'}',
                    style: B05Typography.metric(context),
                  ),
                ),
              ),
              Text(
                thisWeek.isEmpty ? 'this week' : 'completed this week',
                style: B05Typography.body(context),
              ),
              if (lastFourWeeks.isNotEmpty) ...[
                const SizedBox(height: B05Layout.space12),
                Text(
                  '${lastFourWeeks.length} ${lastFourWeeks.length == 1 ? 'workout' : 'workouts'} completed in the last 4 weeks',
                  style: B05Typography.caption(context),
                ),
              ],
              const SizedBox(height: B05Layout.space12),
              B05ActionButton(
                label: 'View workout history',
                icon: Icons.history_rounded,
                emphasis: B05ActionEmphasis.tertiary,
                onPressed: onViewHistory,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StrengthSection extends StatelessWidget {
  const _StrengthSection({required this.records, required this.onOpenHistory});

  final List<ProgressStrengthSetRecord> records;
  final ValueChanged<_StrengthHighlight> onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final highlight = _selectStrengthHighlight(records)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: 'Strength'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Semantics(
            container: true,
            label:
                '${highlight.exerciseName}. Heaviest recorded set: ${_formatSet(highlight.heaviest)}.${highlight.comparisonText == null ? '' : ' ${highlight.comparisonText}.'}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  highlight.exerciseName,
                  style: B05Typography.title(context),
                ),
                const SizedBox(height: B05Layout.space8),
                Text(
                  _formatSet(highlight.heaviest),
                  style: B05Typography.metric(context),
                ),
                const SizedBox(height: B05Layout.space4),
                Text(
                  highlight.comparisonText ?? 'Heaviest recorded performed set',
                  style: B05Typography.body(context),
                ),
                const SizedBox(height: B05Layout.space12),
                B05ActionButton(
                  label: 'View history',
                  icon: Icons.arrow_forward_rounded,
                  emphasis: B05ActionEmphasis.tertiary,
                  onPressed: () => onOpenHistory(highlight),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrainingVolumeSection extends StatelessWidget {
  const _TrainingVolumeSection({required this.snapshot});

  final ProgressDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final all = (snapshot.workouts ?? const <ProgressWorkoutRecord>[])
        .where(
          (workout) => workout.isCanonicalStrength && workout.totalVolumeKg > 0,
        )
        .toList(growable: false);
    final recent = all
        .where(
          (workout) =>
              workout.localDate.compareTo(
                _addCivilDays(snapshot.todayLocalDate, -27),
              ) >=
              0,
        )
        .toList(growable: false);
    final useRecent = recent.isNotEmpty;
    final total = (useRecent ? recent : all).fold<double>(
      0,
      (sum, workout) => sum + workout.totalVolumeKg,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: 'Training volume'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Semantics(
            label:
                '${_formatVolume(total)} kilograms ${useRecent ? 'in the last four weeks' : 'across recorded strength workouts'}.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatVolume(total),
                  style: B05Typography.metric(context),
                ),
                Text(
                  useRecent
                      ? 'kg recorded in the last 4 weeks'
                      : 'kg across recorded strength workouts',
                  style: B05Typography.body(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MuscleBalanceSection extends StatelessWidget {
  const _MuscleBalanceSection({required this.readModel});

  final B02MuscleVolumeReadModel readModel;

  @override
  Widget build(BuildContext context) {
    final muscles =
        readModel.muscles
            .where((muscle) => muscle.workingSetUnits > 0)
            .toList(growable: false)
          ..sort(
            (first, second) =>
                second.workingSetUnits.compareTo(first.workingSetUnits),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: 'Recent training emphasis'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            children: [
              for (final muscle in muscles.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: B05Layout.space12),
                  child: Semantics(
                    label:
                        '${muscle.displayName}, ${_formatNumber(muscle.workingSetUnits)} working set units.',
                    child: ExcludeSemantics(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              muscle.displayName,
                              style: B05Typography.label(context),
                            ),
                          ),
                          Text(
                            '${_formatNumber(muscle.workingSetUnits)} working sets',
                            style: B05Typography.caption(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MeasurementsSection extends StatelessWidget {
  const _MeasurementsSection({
    required this.measurements,
    required this.onLogMeasurement,
    required this.onViewHistory,
  });

  final List<ProgressMeasurementRecord> measurements;
  final VoidCallback onLogMeasurement;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final ordered = measurements.toList(growable: true)
      ..sort((first, second) => second.recordedAt.compareTo(first.recordedAt));
    final values = _bodyMeasurementValues(ordered);
    final latestEntry = ordered.first;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compactActions = textScale >= 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: 'Measurements'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final value in values)
                Padding(
                  padding: const EdgeInsets.only(bottom: B05Layout.space8),
                  child: Semantics(
                    label:
                        '${value.label}, ${_formatNumber(value.value)} centimetres${value.changeText == null ? '.' : '. ${value.changeText}.'}',
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value.label,
                            style: B05Typography.label(context),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_formatNumber(value.value)} cm',
                            style: B05Typography.body(context),
                          ),
                          if (value.changeText != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              value.changeText!,
                              style: B05Typography.caption(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              Text(
                'Latest entry · ${_shortCivilDate(_measurementDate(latestEntry))}',
                style: B05Typography.caption(context),
              ),
              const SizedBox(height: B05Layout.space12),
              B05ActionButton(
                label: 'View history',
                icon: Icons.history_rounded,
                emphasis: B05ActionEmphasis.tertiary,
                onPressed: onViewHistory,
              ),
              B05ActionButton(
                label: compactActions ? 'Log' : 'Log measurement',
                hint: compactActions ? 'Log measurement' : null,
                icon: Icons.add_rounded,
                emphasis: B05ActionEmphasis.tertiary,
                onPressed: onLogMeasurement,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BodyMeasurementValue {
  const _BodyMeasurementValue({
    required this.label,
    required this.value,
    required this.localDate,
    this.changeText,
  });

  final String label;
  final double value;
  final String localDate;
  final String? changeText;
}

List<_BodyMeasurementValue> _bodyMeasurementValues(
  List<ProgressMeasurementRecord> measurements,
) => [
  _latestBodyMeasurementValue(
    'Waist',
    measurements,
    (record) => record.waistCm,
  ),
  _latestBodyMeasurementValue(
    'Chest',
    measurements,
    (record) => record.chestCm,
  ),
  _latestBodyMeasurementValue('Arms', measurements, (record) => record.armsCm),
].whereType<_BodyMeasurementValue>().toList(growable: false);

_BodyMeasurementValue? _latestBodyMeasurementValue(
  String label,
  List<ProgressMeasurementRecord> measurements,
  double? Function(ProgressMeasurementRecord record) read,
) {
  final entries = measurements
      .where((record) {
        final value = read(record);
        return value != null && value > 0;
      })
      .toList(growable: false);
  if (entries.isEmpty) return null;
  final latest = entries.first;
  final latestValue = read(latest)!;
  ProgressMeasurementRecord? prior;
  for (final candidate in entries.skip(1)) {
    if (candidate.localDate != latest.localDate) {
      prior = candidate;
      break;
    }
  }
  final priorValue = prior == null ? null : read(prior);
  final difference = priorValue == null ? null : latestValue - priorValue;
  final changeText = difference == null || difference == 0
      ? null
      : '${_formatNumber(difference.abs())} cm ${difference < 0 ? 'lower' : 'higher'} than ${_shortCivilDate(prior!.localDate)}';
  return _BodyMeasurementValue(
    label: label,
    value: latestValue,
    localDate: latest.localDate,
    changeText: changeText,
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: B05Typography.caption(
        context,
      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: .5),
    );
  }
}

/// Detail history stays behind the root summary so a complete training log
/// does not turn the Progress tab into an unscannable data dump.
class ProgressTrainingHistoryScreen extends StatelessWidget {
  const ProgressTrainingHistoryScreen({super.key, required this.workouts});

  final List<ProgressWorkoutRecord> workouts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout history')),
      body: ListView.separated(
        padding: const EdgeInsets.all(B05Layout.space20),
        itemCount: workouts.length,
        separatorBuilder: (_, _) => const SizedBox(height: B05Layout.space8),
        itemBuilder: (context, index) {
          final workout = workouts[index];
          return Semantics(
            label: '${workout.name}, ${_shortCivilDate(workout.localDate)}',
            child: B05Surface(
              tone: B05SurfaceTone.interactive,
              child: Row(
                children: [
                  Icon(
                    Icons.fitness_center_rounded,
                    color: context.b05Colors.action,
                  ),
                  const SizedBox(width: B05Layout.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(workout.name, style: B05Typography.label(context)),
                        Text(
                          _shortCivilDate(workout.localDate),
                          style: B05Typography.caption(context),
                        ),
                      ],
                    ),
                  ),
                  if (workout.isCanonicalStrength && workout.totalVolumeKg > 0)
                    Text(
                      '${_formatVolume(workout.totalVolumeKg)} kg',
                      style: B05Typography.caption(context),
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

class ProgressExerciseHistoryScreen extends StatelessWidget {
  const ProgressExerciseHistoryScreen({
    super.key,
    required this.exerciseName,
    required this.records,
  });

  final String exerciseName;
  final List<ProgressStrengthSetRecord> records;

  @override
  Widget build(BuildContext context) {
    final sorted = records.toList(growable: true)
      ..sort(
        (first, second) =>
            second.completedAtUtc.compareTo(first.completedAtUtc),
      );
    return Scaffold(
      appBar: AppBar(title: Text(exerciseName)),
      body: ListView.separated(
        padding: const EdgeInsets.all(B05Layout.space20),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: B05Layout.space8),
        itemBuilder: (context, index) {
          final record = sorted[index];
          return Semantics(
            label:
                '${_shortCivilDate(record.localDate)}, ${_formatSet(record)} performed.',
            child: B05Surface(
              tone: B05SurfaceTone.interactive,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _shortCivilDate(record.localDate),
                      style: B05Typography.label(context),
                    ),
                  ),
                  Text(
                    _formatSet(record),
                    style: B05Typography.body(context).copyWith(
                      color: context.b05Colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
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

/// Measurement detail stays behind the root overview so Progress can surface
/// the latest useful values without turning every historical entry into a
/// default card.
class ProgressMeasurementHistoryScreen extends StatelessWidget {
  const ProgressMeasurementHistoryScreen({
    super.key,
    required this.measurements,
  });

  final List<ProgressMeasurementRecord> measurements;

  @override
  Widget build(BuildContext context) {
    final ordered = measurements.toList(growable: true)
      ..sort((first, second) => second.recordedAt.compareTo(first.recordedAt));
    return Scaffold(
      appBar: AppBar(title: const Text('Measurement history')),
      body: ListView.separated(
        padding: const EdgeInsets.all(B05Layout.space20),
        itemCount: ordered.length,
        separatorBuilder: (_, _) => const SizedBox(height: B05Layout.space8),
        itemBuilder: (context, index) {
          final measurement = ordered[index];
          final values = <String>[
            if (measurement.waistCm case final value?)
              'Waist ${_formatNumber(value)} cm',
            if (measurement.chestCm case final value?)
              'Chest ${_formatNumber(value)} cm',
            if (measurement.armsCm case final value?)
              'Arms ${_formatNumber(value)} cm',
          ];
          return Semantics(
            label:
                '${_shortCivilDate(measurement.localDate)}. ${values.join(', ')}.',
            child: B05Surface(
              tone: B05SurfaceTone.interactive,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shortCivilDate(measurement.localDate),
                      style: B05Typography.label(context),
                    ),
                    const SizedBox(height: B05Layout.space8),
                    Wrap(
                      spacing: B05Layout.space8,
                      runSpacing: B05Layout.space4,
                      children: [
                        for (final value in values)
                          Text(value, style: B05Typography.caption(context)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogBodyMeasurementsSheet extends ConsumerStatefulWidget {
  const _LogBodyMeasurementsSheet({required this.onSaved});

  final Future<void> Function() onSaved;

  @override
  ConsumerState<_LogBodyMeasurementsSheet> createState() =>
      _LogBodyMeasurementsSheetState();
}

class _LogBodyMeasurementsSheetState
    extends ConsumerState<_LogBodyMeasurementsSheet> {
  late final TextEditingController _waist;
  late final TextEditingController _chest;
  late final TextEditingController _arms;
  var _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _waist = TextEditingController();
    _chest = TextEditingController();
    _arms = TextEditingController();
  }

  @override
  void dispose() {
    _waist.dispose();
    _chest.dispose();
    _arms.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final waist = _parseMeasurement(_waist.text);
    final chest = _parseMeasurement(_chest.text);
    final arms = _parseMeasurement(_arms.text);
    if (waist == null && chest == null && arms == null) {
      setState(
        () => _message = 'Enter at least one measurement in centimetres.',
      );
      return;
    }
    if ([waist, chest, arms].any((value) => value != null && value <= 0)) {
      setState(() => _message = 'Measurements must be greater than zero.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref
          .read(workoutRepositoryProvider)
          .logBodyMeasurement(waist: waist, chest: chest, arms: arms);
      await widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _message = 'Measurements could not be saved. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Log measurements',
                  style: B05Typography.title(context),
                ),
              ),
              B05IconAction(
                icon: Icons.close_rounded,
                label: 'Close',
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            'Record today’s values in centimetres.',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space16),
          _MeasurementField(label: 'Waist', controller: _waist),
          const SizedBox(height: B05Layout.space12),
          _MeasurementField(label: 'Chest', controller: _chest),
          const SizedBox(height: B05Layout.space12),
          _MeasurementField(label: 'Arms', controller: _arms),
          if (_message != null) ...[
            const SizedBox(height: B05Layout.space12),
            Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                style: B05Typography.caption(
                  context,
                ).copyWith(color: context.b05Colors.danger.indicator),
              ),
            ),
          ],
          const SizedBox(height: B05Layout.space20),
          SizedBox(
            width: double.infinity,
            child: B05ActionButton(
              label: _saving ? 'Saving…' : 'Save measurements',
              icon: Icons.check_rounded,
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurementField extends StatelessWidget {
  const _MeasurementField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, suffixText: 'cm'),
    );
  }
}

class _StrengthHighlight {
  const _StrengthHighlight({
    required this.exerciseName,
    required this.heaviest,
    required this.records,
    this.comparisonText,
  });

  final String exerciseName;
  final ProgressStrengthSetRecord heaviest;
  final List<ProgressStrengthSetRecord> records;
  final String? comparisonText;
}

_StrengthHighlight? _selectStrengthHighlight(
  List<ProgressStrengthSetRecord> records,
) {
  if (records.isEmpty) return null;
  final groups = <String, List<ProgressStrengthSetRecord>>{};
  for (final record in records) {
    groups
        .putIfAbsent('${record.exerciseId}|${record.loadBasis}', () => [])
        .add(record);
  }
  final highlights = <_StrengthHighlight>[];
  for (final values in groups.values) {
    final sorted = values.toList(growable: true)
      ..sort(
        (first, second) =>
            first.completedAtUtc.compareTo(second.completedAtUtc),
      );
    final fallback = sorted.reduce((current, record) {
      if (record.loadKg != current.loadKg) {
        return record.loadKg > current.loadKg ? record : current;
      }
      return record.reps > current.reps ? record : current;
    });
    final byReps = <int, List<ProgressStrengthSetRecord>>{};
    for (final record in sorted) {
      byReps.putIfAbsent(record.reps, () => []).add(record);
    }
    final comparable = <_StrengthHighlight>[];
    for (final matching in byReps.values) {
      if (matching.first.loadBasis == 'bodyweight') continue;
      final dates = matching.map((record) => record.localDate).toSet();
      if (dates.length < 2) continue;
      final earliest = matching.first;
      final bestAtRep = matching.reduce((current, record) {
        if (record.loadKg != current.loadKg) {
          return record.loadKg > current.loadKg ? record : current;
        }
        return record.completedAtUtc.isAfter(current.completedAtUtc)
            ? record
            : current;
      });
      if (bestAtRep.localDate == earliest.localDate) continue;
      final difference = bestAtRep.loadKg - earliest.loadKg;
      if (difference == 0) continue;
      comparable.add(
        _StrengthHighlight(
          exerciseName: bestAtRep.exerciseName,
          heaviest: bestAtRep,
          records: sorted,
          comparisonText:
              '${_formatNumber(difference.abs())} ${_strengthLoadUnit(bestAtRep)} higher at ${bestAtRep.reps} reps since ${_shortCivilDate(earliest.localDate)}',
        ),
      );
    }
    if (comparable.isNotEmpty) {
      comparable.sort(
        (first, second) => second.heaviest.completedAtUtc.compareTo(
          first.heaviest.completedAtUtc,
        ),
      );
      highlights.add(comparable.first);
    } else {
      highlights.add(
        _StrengthHighlight(
          exerciseName: fallback.exerciseName,
          heaviest: fallback,
          records: sorted,
        ),
      );
    }
  }
  highlights.sort((first, second) {
    final withComparison =
        (second.comparisonText != null ? 1 : 0) -
        (first.comparisonText != null ? 1 : 0);
    if (withComparison != 0) return withComparison;
    return second.heaviest.completedAtUtc.compareTo(
      first.heaviest.completedAtUtc,
    );
  });
  return highlights.first;
}

bool _hasMeaningfulVolume(ProgressDashboardSnapshot snapshot) =>
    (snapshot.workouts ?? const <ProgressWorkoutRecord>[]).any(
      (workout) => workout.isCanonicalStrength && workout.totalVolumeKg > 0,
    );

bool _hasMeaningfulMuscleBalance(ProgressDashboardSnapshot snapshot) =>
    snapshot.muscleBalance != null &&
    snapshot.muscleBalance!.muscles.any((muscle) => muscle.workingSetUnits > 0);

List<ProgressWorkoutRecord> _workoutsThisWeek(
  ProgressDashboardSnapshot snapshot,
) {
  final start = _addCivilDays(snapshot.todayLocalDate, -6);
  return (snapshot.workouts ?? const <ProgressWorkoutRecord>[])
      .where(
        (workout) =>
            workout.localDate.compareTo(start) >= 0 &&
            workout.localDate.compareTo(snapshot.todayLocalDate) <= 0,
      )
      .toList(growable: false);
}

List<ProgressWorkoutRecord> _workoutsInRecentFourWeeks(
  ProgressDashboardSnapshot snapshot,
) {
  final start = _addCivilDays(snapshot.todayLocalDate, -27);
  return (snapshot.workouts ?? const <ProgressWorkoutRecord>[])
      .where(
        (workout) =>
            workout.localDate.compareTo(start) >= 0 &&
            workout.localDate.compareTo(snapshot.todayLocalDate) <= 0,
      )
      .toList(growable: false);
}

bool _hasWeightChartHistory(List<ProgressMeasurementRecord> measurements) =>
    measurements.length >= 3 &&
    measurements.map(_measurementDate).toSet().length >= 2;

String _weightOverviewDetail(List<ProgressMeasurementRecord> measurements) {
  if (measurements.length == 1) return 'latest weight';
  if (measurements.length == 2) {
    return '${_formatWeight(measurements.first.weightKg!)} → ${_formatWeight(measurements.last.weightKg!)}';
  }
  return _weightDetail(measurements);
}

String _weightDetail(List<ProgressMeasurementRecord> measurements) {
  if (measurements.length == 1) return 'Latest weigh-in';
  if (measurements.length == 2) {
    return '${_formatWeight(measurements.first.weightKg!)} → ${_formatWeight(measurements.last.weightKg!)}';
  }
  final first = measurements.first;
  final last = measurements.last;
  final difference = last.weightKg! - first.weightKg!;
  final days = _civilDayDifference(
    _measurementDate(first),
    _measurementDate(last),
  );
  if (days == 0) {
    return 'Multiple weigh-ins recorded on ${_shortCivilDate(_measurementDate(last))}';
  }
  if (difference == 0) {
    return days > 0
        ? 'No change from ${days == 1 ? 'yesterday' : '$days days ago'}'
        : 'No change across recorded measurements';
  }
  final relation = difference < 0 ? 'lower' : 'higher';
  return days > 0
      ? '${_formatWeight(difference.abs())} $relation than $days days ago'
      : '${_formatWeight(difference.abs())} $relation across recorded measurements';
}

String _weightSemantics(
  ProgressDashboardSnapshot snapshot,
  List<ProgressMeasurementRecord> measurements,
) {
  final latest = measurements.last;
  final detail = _weightDetail(measurements);
  final goal = snapshot.weightGoal;
  final goalText = goal == null
      ? ''
      : goal.direction == ProgressWeightGoalDirection.maintenance
      ? ' Target ${_formatWeight(goal.targetKg)}.'
      : ' Goal ${_formatWeight(goal.targetKg)}, ${_formatWeight((latest.weightKg! - goal.targetKg).abs())} to go.';
  return 'Weight: ${_formatWeight(latest.weightKg!)}. $detail.$goalText';
}

IconData _weightDirectionIcon(List<ProgressMeasurementRecord> measurements) {
  if (measurements.length < 2) return Icons.scale_rounded;
  if (measurements.length >= 3 &&
      _civilDayDifference(
            _measurementDate(measurements.first),
            _measurementDate(measurements.last),
          ) ==
          0) {
    return Icons.scale_rounded;
  }
  final difference = measurements.last.weightKg! - measurements.first.weightKg!;
  if (difference < 0) return Icons.south_east_rounded;
  if (difference > 0) return Icons.north_east_rounded;
  return Icons.horizontal_rule_rounded;
}

Color? _goalAwareTrendColor(
  BuildContext context,
  ProgressDashboardSnapshot snapshot,
  List<ProgressMeasurementRecord> measurements,
) {
  if (!_hasWeightChartHistory(measurements) || snapshot.weightGoal == null) {
    return null;
  }
  final difference = measurements.last.weightKg! - measurements.first.weightKg!;
  final favourable = switch (snapshot.weightGoal!.direction) {
    ProgressWeightGoalDirection.loss => difference < 0,
    ProgressWeightGoalDirection.gain => difference > 0,
    ProgressWeightGoalDirection.maintenance => false,
  };
  return favourable ? context.b05Colors.success.indicator : null;
}

LineChartData _weightChartData({
  required BuildContext context,
  required List<ProgressMeasurementRecord> measurements,
  required ProgressWeightGoal? goal,
  required ValueChanged<int> onTouch,
}) {
  final colors = context.b05Colors;
  final weights = measurements.map((record) => record.weightKg!).toList();
  final minimum = weights.reduce(
    (first, second) => first < second ? first : second,
  );
  final maximum = weights.reduce(
    (first, second) => first > second ? first : second,
  );
  final spread = maximum - minimum;
  final padding = spread < .5 ? .5 : spread * .25;
  final minY = (minimum - padding).clamp(0, double.infinity).toDouble();
  final maxY = maximum + padding;
  final canShowGoalLine =
      goal != null && goal.targetKg >= minY && goal.targetKg <= maxY;
  return LineChartData(
    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: (maxY - minY) / 3,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: colors.border.withValues(alpha: .45), strokeWidth: 1),
    ),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 38,
          interval: (maxY - minY) / 2,
          getTitlesWidget: (value, _) => Text(
            value.toStringAsFixed(0),
            style: B05Typography.caption(context),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, _) {
            if (value != 0 && value != measurements.length - 1) {
              return const SizedBox.shrink();
            }
            final index = value.round().clamp(0, measurements.length - 1);
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _shortCivilDate(_measurementDate(measurements[index])),
                style: B05Typography.caption(context),
              ),
            );
          },
        ),
      ),
    ),
    borderData: FlBorderData(show: false),
    minX: 0,
    maxX: (measurements.length - 1).toDouble(),
    minY: minY,
    maxY: maxY,
    lineTouchData: LineTouchData(
      enabled: true,
      touchCallback: (_, response) {
        final index = response?.lineBarSpots?.firstOrNull?.spotIndex;
        if (index != null) onTouch(index);
      },
      touchTooltipData: LineTouchTooltipData(
        getTooltipItems: (spots) => [
          for (final spot in spots)
            LineTooltipItem(
              '${_shortCivilDate(_measurementDate(measurements[spot.spotIndex]))}\n${_formatWeight(spot.y)}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    ),
    extraLinesData: canShowGoalLine
        ? ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: goal.targetKg,
                color: colors.action.withValues(alpha: .8),
                strokeWidth: 1,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => 'Goal',
                  style: B05Typography.caption(context),
                ),
              ),
            ],
          )
        : const ExtraLinesData(),
    lineBarsData: [
      LineChartBarData(
        spots: [
          for (var index = 0; index < measurements.length; index++)
            FlSpot(index.toDouble(), measurements[index].weightKg!),
        ],
        isCurved: false,
        color: colors.action,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, _, _, _) => FlDotCirclePainter(
            radius: 3.5,
            color: colors.section,
            strokeColor: colors.action,
            strokeWidth: 2,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: colors.action.withValues(alpha: .08),
        ),
      ),
    ],
  );
}

String _formatWeight(double value) => '${value.toStringAsFixed(1)} kg';

String _formatSet(
  ProgressStrengthSetRecord record,
) => switch (record.loadBasis) {
  'perSide' =>
    '${_formatNumber(record.loadKg)} ${_strengthLoadUnit(record)} × ${record.reps}',
  'perImplement' =>
    '${_formatNumber(record.loadKg)} ${_strengthLoadUnit(record)} × ${record.reps}',
  'bodyweight' => 'Bodyweight × ${record.reps}',
  _ => '${_formatNumber(record.loadKg)} kg × ${record.reps}',
};

String _strengthLoadUnit(ProgressStrengthSetRecord record) =>
    switch (record.loadBasis) {
      'perSide' => 'kg per side',
      'perImplement' => 'kg per implement',
      _ => 'kg',
    };

String _formatVolume(double value) =>
    NumberFormat.decimalPattern().format(value.round());

String _formatNumber(double value) {
  final whole = value.roundToDouble() == value;
  return whole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

String _measurementDate(ProgressMeasurementRecord record) => record.localDate;

String _shortCivilDate(String value) {
  final date = _parseCivilDate(value);
  return DateFormat.MMMd().format(date);
}

String _addCivilDays(String date, int days) =>
    _formatCivilDate(_parseCivilDate(date).add(Duration(days: days)));

int _civilDayDifference(String start, String end) =>
    _parseCivilDate(end).difference(_parseCivilDate(start)).inDays;

DateTime _parseCivilDate(String value) => DateTime.utc(
  int.parse(value.substring(0, 4)),
  int.parse(value.substring(5, 7)),
  int.parse(value.substring(8, 10)),
);

DateTime _subtractMonths(DateTime date, int months) {
  final zeroBasedMonth = date.year * 12 + date.month - 1 - months;
  final year = zeroBasedMonth ~/ 12;
  final month = zeroBasedMonth % 12 + 1;
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, date.day.clamp(1, lastDay));
}

String _formatCivilDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

double? _parseMeasurement(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}
