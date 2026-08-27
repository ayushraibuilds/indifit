import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/navigation/app_navigation.dart';
import '../../core/presentation/consumer_copy.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/services/indifit_haptics.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/models/b02_muscle_volume_models.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/repositories/workout_repository.dart';
import '../dashboard/widgets/log_weight_bottom_sheet.dart';
import '../exercise_library/exercise_history_screen.dart';
import '../settings/nutrition_targets_hub_screen.dart';
import '../settings/unit_preference.dart';
import '../training/workout_history_screen.dart';
import 'achievements_screen.dart';
import 'progress_dashboard_controller.dart';
import 'progress_dashboard_models.dart';
import 'r08f4_training_volume_presentation.dart';

/// Outcome-first Progress composition.
///
/// The screen is deliberately allowed to be modular: sections appear only when
/// the underlying completed-session, B02 performed-set, measurement, or B03
/// nutrition facts can support a truthful statement.
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
    // Some deterministic preview fixtures intentionally render without a
    // ProviderScope; production and scoped previews still consume the shared
    // unit preference authority.
    var units = 'kg';
    try {
      units = ref.watch(unitPreferenceProvider);
    } on StateError {
      units = 'kg';
    }
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
          ? _buildProductionBody(units)
          : _buildSnapshot(widget.preview!, units),
    );
  }

  Widget _buildProductionBody(String units) {
    final snapshot = ref.watch(progressDashboardSnapshotProvider);
    return snapshot.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(B05Layout.space20),
          child: ConsumerStatusRow(
            label: 'Loading your progress',
            loading: true,
          ),
        ),
      ),
      error: (_, _) => _failureState(),
      data: (snapshot) => _buildSnapshot(snapshot, units),
    );
  }

  Widget _buildSnapshot(ProgressDashboardSnapshot snapshot, String units) {
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
                _ProgressHighlights(
                  snapshot: snapshot,
                  onViewTrainingHistory: _openTrainingHistory,
                  onViewStrengthHistory: (name, stableExerciseId) =>
                      _openStrengthHistory(
                        name,
                        stableExerciseId,
                        snapshot.timezoneId,
                      ),
                  units: units,
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
                if ((snapshot.workouts?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: B05Layout.space24),
                  _TrainingConsistencySection(
                    snapshot: snapshot,
                    onViewHistory: _openTrainingHistory,
                  ),
                ],
                if ((snapshot.strengthSets?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: B05Layout.space24),
                  _StrengthSection(
                    snapshot: snapshot,
                    onViewHistory: (name, stableExerciseId) =>
                        _openStrengthHistory(
                          name,
                          stableExerciseId,
                          snapshot.timezoneId,
                        ),
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
                    onViewHistory: () => _openWeightHistory(snapshot, units),
                    units: units,
                  ),
                ],
                if (snapshot.nutritionSummary != null &&
                    snapshot.nutritionSummary!.hasAnyLoggedDays) ...[
                  const SizedBox(height: B05Layout.space24),
                  _NutritionAdherenceSection(
                    summary: snapshot.nutritionSummary!,
                    onViewTargets: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NutritionTargetsHubScreen(),
                      ),
                    ),
                  ),
                ],
                if (_hasMeaningfulVolume(snapshot)) ...[
                  const SizedBox(height: B05Layout.space24),
                  _TrainingVolumeSection(snapshot: snapshot, units: units),
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
                    'Complete a workout or log a weigh-in to start seeing useful trends.',
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
      ..sort(_compareMeasurementsChronologically);
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
      ..sort(_compareMeasurementsChronologically);
    final latest = weights.isEmpty ? null : weights.last;
    await LogWeightBottomSheet.show(context, latest?.weightKg ?? 70, (
      weight,
    ) async {
      await ref
          .read(workoutRepositoryProvider)
          .logWeightAndSyncProfile(weight: weight);
      unawaited(IndiFitHaptics.confirmation());
      await _refresh();
    });
  }

  void _startWorkout() => goToTrainingTab(context);

  void _openTrainingHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WorkoutHistoryScreen()));
  }

  void _openStrengthHistory(
    String exerciseName,
    String stableExerciseId,
    String timezoneId,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseHistoryScreen(
          exerciseName: exerciseName,
          stableExerciseId: stableExerciseId,
          timezoneId: timezoneId,
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

  void _openWeightHistory(ProgressDashboardSnapshot snapshot, String units) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProgressWeightHistoryScreen(
          measurements: snapshot.weightMeasurements,
          todayLocalDate: snapshot.todayLocalDate,
          timezoneId: snapshot.timezoneId,
          units: units,
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

class _ProgressHighlights extends StatelessWidget {
  const _ProgressHighlights({
    required this.snapshot,
    required this.onViewTrainingHistory,
    required this.onViewStrengthHistory,
    required this.units,
  });

  final ProgressDashboardSnapshot snapshot;
  final VoidCallback onViewTrainingHistory;
  final void Function(String name, String stableExerciseId)
  onViewStrengthHistory;
  final String units;

  @override
  Widget build(BuildContext context) {
    final highlights = <_ProgressHighlight>[];
    final thisWeek = _workoutsThisWeek(snapshot);
    if (thisWeek.isNotEmpty) {
      final summary = R08F4TrainingVolumePresentation.summarizeConsistency(
        thisWeek,
      );
      final sessionCount = summary.sessionCount;
      final daysCount = snapshot.weeklyTrainedDates.isNotEmpty
          ? snapshot.weeklyTrainedDates.length
          : summary.trainingDayCount;
      final detailText = sessionCount == daysCount
          ? 'completed this week'
          : 'across $daysCount ${daysCount == 1 ? 'day' : 'days'} this week';
      highlights.add(
        _ProgressHighlight(
          label: 'Training',
          value: '$sessionCount ${sessionCount == 1 ? 'workout' : 'workouts'}',
          detail: detailText,
          icon: Icons.fitness_center_rounded,
          onPressed: onViewTrainingHistory,
          actionLabel: 'View workout history',
        ),
      );
    }

    final strength = _selectStrengthHighlight(
      snapshot.strengthSets ?? const [],
    );
    if (strength != null) {
      highlights.add(
        _ProgressHighlight(
          label: 'Strength',
          value: _formatSet(strength.heaviest),
          detail: strength.comparisonText == null
              ? strength.exerciseName
              : '${strength.exerciseName} · ${strength.comparisonText}',
          icon: Icons.show_chart_rounded,
          onPressed: () =>
              onViewStrengthHistory(strength.exerciseName, strength.exerciseId),
          actionLabel: 'View strength history',
        ),
      );
    }

    final allWeights = snapshot.weightMeasurements.toList(growable: true)
      ..sort(_compareMeasurementsChronologically);
    final dailyWeights = _dailyWeightObservations(allWeights);
    if (dailyWeights.isNotEmpty) {
      final latest = dailyWeights.last;
      final detail = _weightOverviewDetail(allWeights, units);
      highlights.add(
        _ProgressHighlight(
          label: 'Weight',
          value: _formatWeight(latest.weightKg!, units),
          detail: detail,
          icon: _weightDirectionIcon(allWeights),
          semanticDetail: _weightSemantics(allWeights, units),
        ),
      );
    }

    final nutrition = snapshot.nutritionSummary;
    if (nutrition != null && nutrition.hasAnyLoggedDays) {
      final detail = _nutritionAdherenceLabel(nutrition);
      highlights.add(
        _ProgressHighlight(
          label: 'Nutrition',
          value: nutrition.averageCaloriesKcal != null
              ? '${_formatVolume(nutrition.averageCaloriesKcal!)} kcal'
              : '${nutrition.loggedDaysCount} days logged',
          detail: detail,
          icon: Icons.restaurant_rounded,
          semanticDetail:
              'Nutrition: ${nutrition.averageCaloriesKcal != null ? '${_formatVolume(nutrition.averageCaloriesKcal!)} average calories across ${nutrition.calorieEvidenceDaysCount} complete days. ' : ''}$detail.',
        ),
      );
    }

    if (highlights.isEmpty && snapshot.bodyMeasurements.isNotEmpty) {
      final measurements = snapshot.bodyMeasurements.toList(growable: true)
        ..sort(_compareMeasurementsNewestFirst);
      final bodyValues = _bodyMeasurementValues(measurements);
      if (bodyValues.isNotEmpty) {
        final value = bodyValues.first;
        highlights.add(
          _ProgressHighlight(
            label: 'Measurements',
            value: '${_formatNumber(value.value)} cm',
            detail: 'Latest ${value.label.toLowerCase()}',
            icon: Icons.straighten_rounded,
            semanticDetail:
                '${value.label}: ${_formatNumber(value.value)} centimetres, latest measurement.',
          ),
        );
      }
    }

    if (highlights.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: 'Progress highlights',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(title: 'Highlights'),
          const SizedBox(height: B05Layout.space8),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final twoColumns = constraints.maxWidth >= 330 && textScale < 1.5;
              final width = twoColumns
                  ? (constraints.maxWidth - B05Layout.space12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: B05Layout.space12,
                runSpacing: B05Layout.space12,
                children: [
                  for (final highlight in highlights)
                    SizedBox(
                      width: width,
                      child: _ProgressHighlightTile(highlight: highlight),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProgressHighlight {
  const _ProgressHighlight({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.semanticDetail,
    this.onPressed,
    this.actionLabel,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final String? semanticDetail;
  final VoidCallback? onPressed;
  final String? actionLabel;
}

class _ProgressHighlightTile extends StatelessWidget {
  const _ProgressHighlightTile({required this.highlight});

  final _ProgressHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final accent = colors.action;
    final semanticLabel =
        '${highlight.label}: ${highlight.value}. '
        '${highlight.semanticDetail ?? highlight.detail}';
    final surface = B05Surface(
      tone: highlight.onPressed == null
          ? B05SurfaceTone.inset
          : B05SurfaceTone.interactive,
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  highlight.icon,
                  size: B05Layout.iconMedium,
                  color: accent,
                ),
              ),
              const SizedBox(width: B05Layout.space8),
              Expanded(
                child: Text(
                  highlight.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: B05Typography.caption(context).copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (highlight.onPressed != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: B05Layout.iconSmall,
                  color: colors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: B05Layout.space8),
          Text(
            highlight.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: B05Typography.title(
              context,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: B05Layout.space4),
          Text(
            highlight.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: B05Typography.caption(context),
          ),
        ],
      ),
    );
    final interactiveSurface = highlight.onPressed == null
        ? surface
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: b05Radius(B05SurfaceRadius.medium),
              onTap: highlight.onPressed,
              child: surface,
            ),
          );
    return Semantics(
      container: true,
      label: semanticLabel,
      button: highlight.onPressed != null,
      enabled: highlight.onPressed != null,
      onTap: highlight.onPressed,
      hint: highlight.actionLabel,
      child: KeyedSubtree(
        key: ValueKey('progress_highlight_${highlight.label.toLowerCase()}'),
        child: ExcludeSemantics(child: interactiveSurface),
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
    final totalWorkingSets = (snapshot.workouts ?? const []).fold<int>(
      0,
      (sum, w) => sum + w.workingSetsCount,
    );

    final thisWeekSummary =
        R08F4TrainingVolumePresentation.summarizeConsistency(thisWeek);
    final thisWeekSessionCount = thisWeekSummary.sessionCount;
    final thisWeekDaysCount = snapshot.weeklyTrainedDates.isNotEmpty
        ? snapshot.weeklyTrainedDates.length
        : thisWeekSummary.trainingDayCount;

    final lastFourWeeksSummary =
        R08F4TrainingVolumePresentation.summarizeConsistency(lastFourWeeks);
    final recentSessionCount = lastFourWeeksSummary.sessionCount;
    final recentDaysCount = lastFourWeeksSummary.trainingDayCount;

    final headingText = R08F4TrainingVolumePresentation.formatThisWeekHeading(
      thisWeekSessionCount,
    );
    final subtitleText = R08F4TrainingVolumePresentation.formatThisWeekSubtitle(
      sessionCount: thisWeekSessionCount,
      dayCount: thisWeekDaysCount,
    );
    final semanticsLabel =
        R08F4TrainingVolumePresentation.formatThisWeekSemantics(
          sessionCount: thisWeekSessionCount,
          dayCount: thisWeekDaysCount,
        );
    final fourWeeksSummaryText =
        R08F4TrainingVolumePresentation.formatRecentHistorySummary(
          sessionCount: recentSessionCount,
          dayCount: recentDaysCount,
          workingSetsCount: totalWorkingSets,
          weeks: 4,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'Training consistency'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: semanticsLabel,
                child: ExcludeSemantics(
                  child: Text(
                    headingText,
                    style: B05Typography.metric(context),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitleText, style: B05Typography.body(context)),
              const SizedBox(height: B05Layout.space16),
              _WeekCalendarStrip(
                todayLocalDate: snapshot.todayLocalDate,
                timezoneId: snapshot.timezoneId,
                trainedDates: snapshot.weeklyTrainedDates,
                workouts: thisWeek,
              ),
              if (fourWeeksSummaryText.isNotEmpty) ...[
                const SizedBox(height: B05Layout.space16),
                Text(
                  fourWeeksSummaryText,
                  style: B05Typography.caption(context),
                ),
              ],
              const SizedBox(height: B05Layout.space16),
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

class _WeekCalendarStrip extends StatelessWidget {
  const _WeekCalendarStrip({
    required this.todayLocalDate,
    required this.timezoneId,
    required this.trainedDates,
    this.workouts = const [],
  });

  final String todayLocalDate;
  final String timezoneId;
  final Set<String> trainedDates;
  final List<ProgressWorkoutRecord> workouts;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final dates = LocalScheduleDateService();
    final currentWeekday = dates.weekday(todayLocalDate, timezoneId);
    final monday = dates.addCalendarDays(
      todayLocalDate,
      timezoneId,
      DateTime.monday - currentWeekday,
    );

    return Semantics(
      container: true,
      label: 'This week training activity calendar',
      child: Row(
        children: [
          for (var i = 0; i < 7; i++) ...[
            Expanded(
              child: Builder(
                builder: (context) {
                  final dateStr = dates.addCalendarDays(monday, timezoneId, i);
                  final sessionsOnDate = workouts
                      .where((w) => w.localDate == dateStr)
                      .length;
                  final isTrained = trainedDates.contains(dateStr);
                  final isToday = dateStr == todayLocalDate;
                  final dayLabel = days[i];

                  final semanticText =
                      R08F4TrainingVolumePresentation.formatDaySemanticLabel(
                        dayLabel: dayLabel,
                        sessionCount: sessionsOnDate > 0
                            ? sessionsOnDate
                            : (isTrained ? 1 : 0),
                        isToday: isToday,
                      );

                  return Semantics(
                    label: semanticText,
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: B05Typography.caption(context).copyWith(
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isToday
                                  ? colors.action
                                  : colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isTrained
                                  ? colors.action
                                  : colors.surfaceSubtle,
                              border: Border.all(
                                color: isToday ? colors.action : colors.border,
                                width: isToday ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              isTrained
                                  ? Icons.fitness_center_rounded
                                  : Icons.horizontal_rule_rounded,
                              size: isTrained ? 14 : 12,
                              color: isTrained
                                  ? colors.onAction
                                  : colors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StrengthSection extends StatelessWidget {
  const _StrengthSection({required this.snapshot, required this.onViewHistory});

  final ProgressDashboardSnapshot snapshot;
  final void Function(String name, String stableExerciseId) onViewHistory;

  @override
  Widget build(BuildContext context) {
    final highlights = _selectStrengthHighlights(
      snapshot.strengthSets ?? const [],
    );
    if (highlights.isEmpty) return const SizedBox.shrink();

    if (highlights.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(title: 'Strength'),
          const SizedBox(height: B05Layout.space8),
          B05Surface(
            padding: const EdgeInsets.all(B05Layout.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saved actual sets from strength sessions.',
                  style: B05Typography.body(context),
                ),
                const SizedBox(height: B05Layout.space8),
                for (final highlight in highlights)
                  Semantics(
                    button: true,
                    label:
                        'View actual performance history for ${highlight.exerciseName}',
                    hint: 'Open this exercise’s recorded sets over time',
                    onTap: () => onViewHistory(
                      highlight.exerciseName,
                      highlight.exerciseId,
                    ),
                    child: ExcludeSemantics(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        minVerticalPadding: B05Layout.space8,
                        title: Text(
                          highlight.exerciseName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: B05Typography.title(context),
                        ),
                        subtitle: Text(
                          '${_formatSet(highlight.heaviest)} · ${_distinctStrengthSessionCount(highlight.records)} ${_distinctStrengthSessionCount(highlight.records) == 1 ? 'session' : 'sessions'}',
                          style: B05Typography.caption(context),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: context.b05Colors.textSecondary,
                        ),
                        onTap: () => onViewHistory(
                          highlight.exerciseName,
                          highlight.exerciseId,
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

    final highlight = highlights.first;

    final setFormatted = _formatSet(highlight.heaviest);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'Strength'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label:
                    '${highlight.exerciseName}, $setFormatted performed.'
                    '${highlight.comparisonText != null ? ' ${highlight.comparisonText}.' : ''}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: B05Layout.space8,
                        runSpacing: B05Layout.space4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            setFormatted,
                            style: B05Typography.metric(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        highlight.exerciseName,
                        style: B05Typography.body(context),
                      ),
                      if (highlight.comparisonText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          highlight.comparisonText!,
                          style: B05Typography.caption(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: B05Layout.space16),
              B05ActionButton(
                label: ConsumerCopy.historyAction('strength'),
                icon: Icons.history_rounded,
                emphasis: B05ActionEmphasis.tertiary,
                onPressed: () =>
                    onViewHistory(highlight.exerciseName, highlight.exerciseId),
              ),
            ],
          ),
        ),
      ],
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
    required this.onViewHistory,
    required this.units,
  });

  final ProgressDashboardSnapshot snapshot;
  final _ProgressTimeRange range;
  final List<_ProgressTimeRange> ranges;
  final List<ProgressMeasurementRecord> measurements;
  final ValueChanged<_ProgressTimeRange> onRangeSelected;
  final VoidCallback onLogWeight;
  final VoidCallback onViewHistory;
  final String units;

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
    final dailyMeasurements = _dailyWeightObservations(measurements);
    final latest = dailyMeasurements.last;
    final hasChart = _hasWeightChartHistory(measurements);
    final hasSameDayEntries = measurements.length != dailyMeasurements.length;
    final allMeasurements = _dailyWeightObservations(
      widget.snapshot.weightMeasurements,
    );
    final hasLongerHistory = _hasWeightChartHistory(allMeasurements);
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
                label: _weightSemantics(measurements, widget.units),
                child: ExcludeSemantics(
                  child: Text(
                    _formatWeight(latest.weightKg!, widget.units),
                    style: B05Typography.metric(context),
                  ),
                ),
              ),
              const SizedBox(height: B05Layout.space4),
              Text(
                _weightDetail(measurements, widget.units),
                style: B05Typography.body(context),
              ),
              if (showRangeSelector) ...[
                const SizedBox(height: B05Layout.space16),
                _WeightRangeSelector(
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
                  label: _weightSemantics(measurements, widget.units),
                  hint:
                      'Drag across the chart to inspect each recorded weight.',
                  child: SizedBox(
                    key: const ValueKey('progress_weight_chart'),
                    height: 200,
                    child: LineChart(
                      _weightChartData(
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
                  '${_shortCivilDate(_measurementDate(selected))} · ${_formatWeight(selected.weightKg!, widget.units)}',
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
          ..sort(_compareMeasurementsNewestFirst);

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
                final date = _fullCivilDate(measurement.localDate);
                final time = _measurementTime(measurement, timezoneId);
                final today = measurement.localDate == todayLocalDate;
                final latest = index == 0;
                final dateLabel = [if (today) 'Today', date, ?time].join(' · ');
                return Semantics(
                  container: true,
                  label:
                      '${latest ? 'Latest. ' : ''}$dateLabel. ${_formatWeight(weight, units)}.',
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
                          _formatWeight(weight, units),
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

class _NutritionAdherenceSection extends StatelessWidget {
  const _NutritionAdherenceSection({
    required this.summary,
    required this.onViewTargets,
  });

  final ProgressNutritionSummary summary;
  final VoidCallback onViewTargets;

  @override
  Widget build(BuildContext context) {
    final titleText = _nutritionAdherenceLabel(summary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'Nutrition adherence'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label:
                    'Nutrition weekly adherence: $titleText.'
                    '${summary.averageCaloriesKcal != null ? ' Average ${summary.averageCaloriesKcal!.round()} calories across ${summary.calorieEvidenceDaysCount} complete days.' : ''}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.averageCaloriesKcal != null
                            ? '${_formatVolume(summary.averageCaloriesKcal!)} kcal'
                            : '${summary.loggedDaysCount} days logged',
                        style: B05Typography.metric(context),
                      ),
                      if (summary.averageCaloriesKcal != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Average across ${summary.calorieEvidenceDaysCount} complete ${summary.calorieEvidenceDaysCount == 1 ? 'day' : 'days'}',
                          style: B05Typography.caption(context),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(titleText, style: B05Typography.body(context)),
                      if (summary.averageProteinG != null &&
                          summary.targetProteinG != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Avg protein: ${summary.averageProteinG!.round()} / ${summary.targetProteinG!.round()} g across ${summary.proteinEvidenceDaysCount} complete ${summary.proteinEvidenceDaysCount == 1 ? 'day' : 'days'}',
                          style: B05Typography.caption(context),
                        ),
                      ] else if (summary.averageProteinG != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Avg protein: ${summary.averageProteinG!.round()} g across ${summary.proteinEvidenceDaysCount} complete ${summary.proteinEvidenceDaysCount == 1 ? 'day' : 'days'}',
                          style: B05Typography.caption(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: B05Layout.space16),
              _NutritionTargetContext(
                summary: summary,
                onViewTargets: onViewTargets,
              ),
              const SizedBox(height: B05Layout.space16),
              _NutritionWeekStrip(days: summary.days),
            ],
          ),
        ),
      ],
    );
  }
}

class _NutritionTargetContext extends StatelessWidget {
  const _NutritionTargetContext({
    required this.summary,
    required this.onViewTargets,
  });

  final ProgressNutritionSummary summary;
  final VoidCallback onViewTargets;

  @override
  Widget build(BuildContext context) {
    final hasTargetValues =
        summary.targetCaloriesKcal != null || summary.targetProteinG != null;
    final hasTargetContext = hasTargetValues || summary.targetGoalType != null;
    final values = <String>[
      if (summary.targetCaloriesKcal != null)
        '${_formatVolume(summary.targetCaloriesKcal!)} kcal',
      if (summary.targetProteinG != null)
        '${_formatNumber(summary.targetProteinG!)} g protein',
    ];

    return B05Surface(
      tone: B05SurfaceTone.inset,
      padding: const EdgeInsets.all(B05Layout.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: [
              if (hasTargetContext) 'Today’s nutrition target.',
              if (values.isNotEmpty) '${values.join(' · ')}.',
              if (summary.targetGoalType != null)
                'Nutrition goal: ${_nutritionGoalLabel(summary.targetGoalType!)}.',
              if (!hasTargetContext) 'No nutrition target saved for today.',
              if (hasTargetContext && !hasTargetValues)
                'No calorie or macro target values are saved for today.',
            ].join(' '),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today’s nutrition target',
                    style: B05Typography.label(context),
                  ),
                  const SizedBox(height: B05Layout.space4),
                  if (values.isNotEmpty)
                    Text(
                      values.join(' · '),
                      style: B05Typography.title(context),
                    ),
                  if (summary.targetGoalType != null) ...[
                    if (values.isNotEmpty)
                      const SizedBox(height: B05Layout.space4),
                    Text(
                      'Nutrition goal: ${_nutritionGoalLabel(summary.targetGoalType!)}',
                      style: B05Typography.body(context),
                    ),
                  ],
                  if (!hasTargetContext)
                    Text(
                      'No nutrition target saved for today.',
                      style: B05Typography.body(context),
                    ),
                  if (hasTargetContext && !hasTargetValues)
                    Text(
                      'No calorie or macro target values are saved for today.',
                      style: B05Typography.body(context),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: B05Layout.space8),
          B05ActionButton(
            label: hasTargetContext
                ? 'View nutrition targets'
                : 'Set nutrition target',
            hint: hasTargetContext
                ? 'Open the saved nutrition target for today.'
                : 'Open Goal & targets to set today’s values.',
            icon: Icons.open_in_new_rounded,
            emphasis: B05ActionEmphasis.tertiary,
            onPressed: onViewTargets,
          ),
        ],
      ),
    );
  }
}

String _nutritionGoalLabel(NutritionGoalType value) => switch (value) {
  NutritionGoalType.loss => 'Weight loss',
  NutritionGoalType.maintenance => 'Maintain',
  NutritionGoalType.gain => 'Weight gain',
  NutritionGoalType.custom => 'Custom goal',
};

class _NutritionWeekStrip extends StatelessWidget {
  const _NutritionWeekStrip({required this.days});

  final List<ProgressNutritionDaySummary> days;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return Semantics(
      container: true,
      label: 'Weekly nutrition adherence day by day',
      child: Row(
        children: [
          for (final day in days) ...[
            Expanded(
              child: Builder(
                builder: (context) {
                  final hasLog = day.hasFoodLog;
                  final metProtein = day.isProteinTargetMet;
                  final incomplete = day.isNutrientIncomplete;

                  final semanticLabel = !hasLog
                      ? '${day.dayLabel}, no meals logged.'
                      : '${day.dayLabel}, logged.'
                            '${day.caloriesKcal != null ? ' ${day.caloriesKcal!.round()} kcal.' : ''}'
                            '${metProtein ? ' Protein target met.' : ''}'
                            '${incomplete ? ' Nutrition data is incomplete.' : ''}';

                  return Semantics(
                    label: semanticLabel,
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            day.dayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: B05Typography.caption(context).copyWith(
                              fontWeight: day.isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: day.isToday
                                  ? colors.action
                                  : colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: metProtein
                                  ? colors.success.indicator
                                  : incomplete
                                  ? colors.warning.container
                                  : hasLog
                                  ? colors.surfaceSubtle
                                  : colors.surfaceSubtle,
                              border: Border.all(
                                color: day.isToday
                                    ? colors.action
                                    : metProtein
                                    ? colors.success.indicator
                                    : incomplete
                                    ? colors.warning.indicator
                                    : colors.border,
                                width: day.isToday ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              metProtein
                                  ? Icons.check_rounded
                                  : incomplete
                                  ? Icons.help_outline_rounded
                                  : hasLog
                                  ? Icons.restaurant_rounded
                                  : Icons.horizontal_rule_rounded,
                              size: 14,
                              color: metProtein
                                  ? Colors.white
                                  : hasLog
                                  ? colors.textPrimary
                                  : colors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
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

class _TrainingVolumeSection extends StatelessWidget {
  const _TrainingVolumeSection({required this.snapshot, this.units = 'kg'});

  final ProgressDashboardSnapshot snapshot;
  final String units;

  @override
  Widget build(BuildContext context) {
    final summary = R08F4TrainingVolumePresentation.summarizeVolume(
      allWorkouts: snapshot.workouts ?? const <ProgressWorkoutRecord>[],
      todayLocalDate: snapshot.todayLocalDate,
      timezoneId: snapshot.timezoneId,
      units: units,
    );

    final semanticLabel = R08F4TrainingVolumePresentation.formatVolumeSemantics(
      displayVolume: summary.displayVolume,
      units: units,
      useRecent: summary.useRecent,
    );
    final subtitle = R08F4TrainingVolumePresentation.formatVolumeSubtitle(
      units: units,
      useRecent: summary.useRecent,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'Training volume'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Semantics(
            label: semanticLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  R08F4TrainingVolumePresentation.formatVolume(
                    summary.displayVolume,
                  ),
                  style: B05Typography.metric(context),
                ),
                Text(subtitle, style: B05Typography.body(context)),
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
        const _SectionHeading(title: 'Recent training emphasis'),
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
                      child: SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: B05Layout.space8,
                          runSpacing: B05Layout.space4,
                          children: [
                            Text(
                              muscle.displayName,
                              style: B05Typography.label(context),
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
      ..sort(_compareMeasurementsNewestFirst);
    final values = _bodyMeasurementValues(ordered);
    final latestEntry = ordered.first;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final compactActions = textScale >= 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'Measurements'),
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
                label: ConsumerCopy.historyAction('measurement'),
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

class ProgressMeasurementHistoryScreen extends StatelessWidget {
  const ProgressMeasurementHistoryScreen({
    super.key,
    required this.measurements,
  });

  final List<ProgressMeasurementRecord> measurements;

  @override
  Widget build(BuildContext context) {
    final ordered = measurements.toList(growable: true)
      ..sort(_compareMeasurementsNewestFirst);
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
    required this.exerciseId,
    required this.exerciseName,
    required this.heaviest,
    required this.records,
    required this.latestPerformedAtUtc,
    this.comparisonText,
  });

  final String exerciseId;
  final String exerciseName;
  final ProgressStrengthSetRecord heaviest;
  final List<ProgressStrengthSetRecord> records;
  final DateTime latestPerformedAtUtc;
  final String? comparisonText;
}

_StrengthHighlight? _selectStrengthHighlight(
  List<ProgressStrengthSetRecord> records,
) {
  final highlights = _selectStrengthHighlights(records);
  return highlights.isEmpty ? null : highlights.first;
}

List<_StrengthHighlight> _selectStrengthHighlights(
  List<ProgressStrengthSetRecord> records,
) {
  if (records.isEmpty) return const [];
  final groups = <String, List<ProgressStrengthSetRecord>>{};
  for (final record in records) {
    final exerciseId = record.exerciseId.trim();
    if (exerciseId.isEmpty || record.exerciseName.trim().isEmpty) continue;
    groups.putIfAbsent(exerciseId, () => []).add(record);
  }
  if (groups.isEmpty) return const [];
  final highlights = <_StrengthHighlight>[];
  for (final entry in groups.entries) {
    final values = entry.value;
    final sorted = values.toList(growable: true)
      ..sort(
        (first, second) =>
            _compareStrengthRecordsForPresentation(first, second),
      );
    final latestPerformedAtUtc = sorted.last.completedAtUtc;
    final latestSessionKey = _presentationStrengthSessionKey(sorted.last);
    final latestSession = sorted
        .where(
          (record) =>
              _presentationStrengthSessionKey(record) == latestSessionKey,
        )
        .toList(growable: false);
    final latestExternal = latestSession
        .where((record) => record.loadBasis == 'totalExternal')
        .toList(growable: false);
    final heaviest = latestExternal.isEmpty
        ? sorted.last
        : latestExternal.reduce(_heavierStrengthSetForPresentation);
    highlights.add(
      _StrengthHighlight(
        exerciseId: entry.key,
        exerciseName: heaviest.exerciseName,
        heaviest: heaviest,
        records: sorted,
        latestPerformedAtUtc: latestPerformedAtUtc,
        comparisonText: _presentationStrengthComparison(
          sorted,
          latestSessionKey,
          heaviest,
        ),
      ),
    );
  }
  highlights.sort((first, second) {
    final byLatest = second.latestPerformedAtUtc.compareTo(
      first.latestPerformedAtUtc,
    );
    if (byLatest != 0) return byLatest;
    return second.records.length.compareTo(first.records.length);
  });
  return List.unmodifiable(highlights);
}

int _distinctStrengthSessionCount(List<ProgressStrengthSetRecord> records) =>
    records.map(_presentationStrengthSessionKey).toSet().length;

int _compareStrengthRecordsForPresentation(
  ProgressStrengthSetRecord first,
  ProgressStrengthSetRecord second,
) {
  final byTime = first.completedAtUtc.compareTo(second.completedAtUtc);
  if (byTime != 0) return byTime;
  final bySession = (first.sessionId ?? -1).compareTo(second.sessionId ?? -1);
  if (bySession != 0) return bySession;
  return first.performedSetId.compareTo(second.performedSetId);
}

ProgressStrengthSetRecord _heavierStrengthSetForPresentation(
  ProgressStrengthSetRecord first,
  ProgressStrengthSetRecord second,
) {
  if (first.loadKg != second.loadKg) {
    return first.loadKg > second.loadKg ? first : second;
  }
  final firstReps = first.reps;
  final secondReps = second.reps;
  if (firstReps != secondReps) {
    return firstReps > secondReps ? first : second;
  }
  return _compareStrengthRecordsForPresentation(first, second) > 0
      ? first
      : second;
}

String _presentationStrengthSessionKey(ProgressStrengthSetRecord record) =>
    record.sessionId == null
    ? 'date:${record.localDate}'
    : 'session:${record.sessionId}';

String? _presentationStrengthComparison(
  List<ProgressStrengthSetRecord> records,
  String latestSessionKey,
  ProgressStrengthSetRecord current,
) {
  if (current.loadBasis != 'totalExternal') return null;
  final previous = records
      .where(
        (record) =>
            _presentationStrengthSessionKey(record) != latestSessionKey &&
            record.loadBasis == 'totalExternal' &&
            record.reps == current.reps,
      )
      .toList(growable: true);
  if (previous.isEmpty) return null;
  previous.sort(_compareStrengthRecordsForPresentation);
  final previousSessionKey = _presentationStrengthSessionKey(previous.last);
  final previousBest = previous
      .where(
        (record) =>
            _presentationStrengthSessionKey(record) == previousSessionKey,
      )
      .reduce(_heavierStrengthSetForPresentation);
  final difference = current.loadKg - previousBest.loadKg;
  if (difference == 0) return null;
  final sign = difference > 0 ? '+' : '';
  return '$sign${_formatNumber(difference)} kg at ${current.reps} reps vs previous session';
}

bool _hasMeaningfulVolume(ProgressDashboardSnapshot snapshot) =>
    (snapshot.workouts ?? const <ProgressWorkoutRecord>[]).any(
      (workout) =>
          workout.isCanonicalStrength &&
          workout.volumeIsTrustworthy &&
          workout.totalVolumeKg > 0,
    );

bool _hasMeaningfulMuscleBalance(ProgressDashboardSnapshot snapshot) =>
    snapshot.muscleBalance != null &&
    snapshot.muscleBalance!.muscles.any((muscle) => muscle.workingSetUnits > 0);

List<ProgressWorkoutRecord> _workoutsThisWeek(
  ProgressDashboardSnapshot snapshot,
) {
  final dates = LocalScheduleDateService();
  final weekday = dates.weekday(snapshot.todayLocalDate, snapshot.timezoneId);
  final start = dates.addCalendarDays(
    snapshot.todayLocalDate,
    snapshot.timezoneId,
    DateTime.monday - weekday,
  );
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
  final start = LocalScheduleDateService().addCalendarDays(
    snapshot.todayLocalDate,
    snapshot.timezoneId,
    -27,
  );
  return (snapshot.workouts ?? const <ProgressWorkoutRecord>[])
      .where(
        (workout) =>
            workout.localDate.compareTo(start) >= 0 &&
            workout.localDate.compareTo(snapshot.todayLocalDate) <= 0,
      )
      .toList(growable: false);
}

/// A weight trend needs observations on three distinct local days. Several
/// weigh-ins in one day remain useful history, but cannot imply a day-to-day
/// trend or become extra points in a consumer chart.
bool _hasWeightChartHistory(List<ProgressMeasurementRecord> measurements) =>
    _dailyWeightObservations(measurements).length >= 3;

int _compareMeasurementsChronologically(
  ProgressMeasurementRecord first,
  ProgressMeasurementRecord second,
) {
  final byRecordedAt = first.recordedAt.compareTo(second.recordedAt);
  return byRecordedAt != 0 ? byRecordedAt : first.id.compareTo(second.id);
}

int _compareMeasurementsNewestFirst(
  ProgressMeasurementRecord first,
  ProgressMeasurementRecord second,
) => _compareMeasurementsChronologically(second, first);

/// Collapses a day's weigh-ins to its latest persisted observation for
/// consumer trend display. The full record history remains unchanged for
/// measurement history and persistence; this is presentation-only grouping.
List<ProgressMeasurementRecord> _dailyWeightObservations(
  Iterable<ProgressMeasurementRecord> measurements,
) {
  final chronological =
      measurements
          .where(
            (measurement) =>
                measurement.weightKg != null &&
                measurement.weightKg!.isFinite &&
                measurement.weightKg! > 0,
          )
          .toList(growable: true)
        ..sort(_compareMeasurementsChronologically);
  final latestByLocalDate = <String, ProgressMeasurementRecord>{};
  for (final measurement in chronological) {
    latestByLocalDate[measurement.localDate] = measurement;
  }
  final daily = latestByLocalDate.values.toList(growable: true)
    ..sort(_compareMeasurementsChronologically);
  return daily;
}

String _weightOverviewDetail(
  List<ProgressMeasurementRecord> measurements,
  String units,
) {
  final dailyMeasurements = _dailyWeightObservations(measurements);
  if (dailyMeasurements.length == 1) return 'latest weight';
  if (dailyMeasurements.length == 2) {
    return '${_formatWeight(dailyMeasurements.first.weightKg!, units)} → ${_formatWeight(dailyMeasurements.last.weightKg!, units)}';
  }
  return _weightDetail(measurements, units);
}

String _weightDetail(
  List<ProgressMeasurementRecord> measurements,
  String units,
) {
  final dailyMeasurements = _dailyWeightObservations(measurements);
  if (dailyMeasurements.length == 1) {
    return measurements.length > 1
        ? 'Multiple weigh-ins recorded on ${_shortCivilDate(_measurementDate(dailyMeasurements.last))}'
        : 'Latest weigh-in';
  }
  if (dailyMeasurements.length == 2) {
    return '${_formatWeight(dailyMeasurements.first.weightKg!, units)} → ${_formatWeight(dailyMeasurements.last.weightKg!, units)}';
  }
  final first = dailyMeasurements.first;
  final last = dailyMeasurements.last;
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
      ? '${_formatWeight(difference.abs(), units)} $relation than $days days ago'
      : '${_formatWeight(difference.abs(), units)} $relation across recorded measurements';
}

String _weightSemantics(
  List<ProgressMeasurementRecord> measurements,
  String units,
) {
  final latest = _dailyWeightObservations(measurements).last;
  final detail = _weightDetail(measurements, units);
  return 'Weight: ${_formatWeight(latest.weightKg!, units)}. $detail.';
}

IconData _weightDirectionIcon(List<ProgressMeasurementRecord> measurements) {
  final dailyMeasurements = _dailyWeightObservations(measurements);
  if (dailyMeasurements.length < 2) return Icons.scale_rounded;
  final difference =
      dailyMeasurements.last.weightKg! - dailyMeasurements.first.weightKg!;
  if (difference < 0) return Icons.south_east_rounded;
  if (difference > 0) return Icons.north_east_rounded;
  return Icons.horizontal_rule_rounded;
}

LineChartData _weightChartData({
  required BuildContext context,
  required List<ProgressMeasurementRecord> measurements,
  required String units,
  required ValueChanged<int> onTouch,
}) {
  final colors = context.b05Colors;
  final firstDate = _measurementDate(measurements.first);
  final chartDaySpan = _civilDayDifference(
    firstDate,
    _measurementDate(measurements.last),
  );
  final weights = measurements
      .map(
        (record) => UnitPreferencePresentation.weightForDisplay(
          record.weightKg!,
          units,
        ),
      )
      .toList();
  final minimum = weights.reduce(
    (first, second) => first < second ? first : second,
  );
  final maximum = weights.reduce(
    (first, second) => first > second ? first : second,
  );
  final rawSpread = maximum - minimum;
  final spread = rawSpread.isFinite ? rawSpread : maximum;
  final padding = spread < .5 ? .5 : spread * .25;
  final rawMinY = (minimum - padding).clamp(0, double.infinity).toDouble();
  final rawMaxY = maximum + padding;
  final minY = rawMinY.isFinite ? rawMinY : 0.0;
  var maxY = rawMaxY.isFinite ? rawMaxY : maximum;
  if (maxY <= minY) {
    maxY = minY == 0
        ? 1
        : (minY * 1.01).clamp(minY, double.maxFinite).toDouble();
  }
  return LineChartData(
    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: (maxY - minY) / 3,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: colors.border.withValues(alpha: .35), strokeWidth: 1),
    ),
    titlesData: FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 42,
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
          interval: chartDaySpan.toDouble(),
          getTitlesWidget: (value, _) {
            final isFirst = value.abs() < .01;
            final isLast = (value - chartDaySpan).abs() < .01;
            if (!isFirst && !isLast) {
              return const SizedBox.shrink();
            }
            final measurement = isFirst
                ? measurements.first
                : measurements.last;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _shortCivilDate(_measurementDate(measurement)),
                style: B05Typography.caption(context),
              ),
            );
          },
        ),
      ),
    ),
    borderData: FlBorderData(show: false),
    minX: 0,
    maxX: chartDaySpan.toDouble(),
    minY: minY,
    maxY: maxY,
    lineTouchData: LineTouchData(
      enabled: true,
      touchCallback: (_, response) {
        final index = response?.lineBarSpots?.firstOrNull?.spotIndex;
        if (index != null) onTouch(index);
      },
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => colors.surfaceSubtle,
        tooltipRoundedRadius: 8,
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        getTooltipItems: (spots) => [
          for (final spot in spots)
            LineTooltipItem(
              '${_shortCivilDate(_measurementDate(measurements[spot.spotIndex]))}\n${_formatDisplayedWeight(spot.y, units)}',
              TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
        ],
      ),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: [
          for (var index = 0; index < measurements.length; index++)
            FlSpot(
              _civilDayDifference(
                firstDate,
                _measurementDate(measurements[index]),
              ).toDouble(),
              UnitPreferencePresentation.weightForDisplay(
                measurements[index].weightKg!,
                units,
              ),
            ),
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.action.withValues(alpha: 0.14),
              colors.action.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    ],
  );
}

String _formatWeight(double kilograms, String units) => _formatDisplayedWeight(
  UnitPreferencePresentation.weightForDisplay(kilograms, units),
  units,
);

String _formatDisplayedWeight(double value, String units) =>
    '${value.toStringAsFixed(1)} ${UnitPreferencePresentation.weightSymbol(units)}';

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

String _nutritionAdherenceLabel(ProgressNutritionSummary summary) {
  if (summary.targetProteinG != null && summary.proteinEvidenceDaysCount > 0) {
    return '${summary.proteinTargetMetDaysCount} of ${summary.proteinEvidenceDaysCount} complete ${summary.proteinEvidenceDaysCount == 1 ? 'day' : 'days'} met protein';
  }
  if (summary.calorieEvidenceDaysCount > 0) {
    return '${summary.loggedDaysCount} ${summary.loggedDaysCount == 1 ? 'day' : 'days'} with meals logged · ${summary.calorieEvidenceDaysCount} complete calorie ${summary.calorieEvidenceDaysCount == 1 ? 'day' : 'days'}';
  }
  return '${summary.loggedDaysCount} ${summary.loggedDaysCount == 1 ? 'day' : 'days'} with meals logged';
}

String _formatNumber(double value) {
  final whole = value.roundToDouble() == value;
  return whole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

String _measurementDate(ProgressMeasurementRecord record) => record.localDate;

String _shortCivilDate(String value) {
  final date = _parseCivilDate(value);
  return DateFormat.MMMd().format(date);
}

String _fullCivilDate(String value) {
  final date = _parseCivilDate(value);
  return DateFormat.yMMMd().format(date);
}

String? _measurementTime(
  ProgressMeasurementRecord measurement,
  String timezoneId,
) {
  try {
    final local = tz.TZDateTime.from(
      measurement.recordedAt.toUtc(),
      LocalScheduleDateService().locationFor(timezoneId),
    );
    return DateFormat.jm().format(local);
  } on Object {
    // A date label remains authoritative even if an older record cannot be
    // converted through the current timezone database.
    return null;
  }
}

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
