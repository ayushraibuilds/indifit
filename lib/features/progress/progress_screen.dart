import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/user_profile_provider.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/presentation/product_failure_presentation.dart';
import '../../core/presentation/secondary_presentation.dart';
import '../../core/services/indifit_haptics.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../data/repositories/workout_repository.dart';
import '../dashboard/widgets/log_weight_bottom_sheet.dart';
import '../exercise_library/exercise_history_screen.dart';
import '../nutrition/adaptive_tdee_providers.dart';
import '../settings/nutrition_targets_hub_screen.dart';
import '../settings/unit_preference.dart';
import '../training/workout_history_screen.dart';
import 'achievements_screen.dart';
import 'period_comparison/widgets/period_comparison_section.dart';
import 'progress_dashboard_controller.dart';
import 'progress_dashboard_models.dart';
import 'widgets/adaptive_tdee_card.dart';
import 'widgets/progress_formatters.dart';
import 'widgets/progress_measurement_widgets.dart';
import 'widgets/progress_sections.dart';
import 'widgets/progress_view_models.dart';
import 'widgets/progress_weight_widgets.dart';

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
  ProgressTimeRange _weightRange = ProgressTimeRange.oneMonth;

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
    String? fitnessGoalLabel;
    try {
      final profile = ref.watch(userProfileProvider);
      if (profile.isLoaded && profile.hasProfile) {
        fitnessGoalLabel = SecondaryConsumerCopy.goal(profile.userGoal);
      }
    } on StateError {
      fitnessGoalLabel = null;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          PopupMenuButton<ProgressMenuAction>(
            tooltip: 'More progress options',
            onSelected: (action) {
              if (action == ProgressMenuAction.achievements) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ProgressMenuAction.achievements,
                child: Text('Achievements'),
              ),
            ],
          ),
        ],
      ),
      body: widget.preview == null
          ? _buildProductionBody(units, fitnessGoalLabel)
          : _buildSnapshot(widget.preview!, units, fitnessGoalLabel),
    );
  }

  Widget _buildProductionBody(String units, String? fitnessGoalLabel) {
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
      data: (snapshot) => _buildSnapshot(snapshot, units, fitnessGoalLabel),
    );
  }

  Widget _buildSnapshot(
    ProgressDashboardSnapshot snapshot,
    String units,
    String? fitnessGoalLabel,
  ) {
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
                ProgressHighlights(
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
                  TrainingConsistencySection(
                    snapshot: snapshot,
                    onViewHistory: _openTrainingHistory,
                  ),
                ],
                if (widget.preview == null) ...[
                  const SizedBox(height: B05Layout.space24),
                  PeriodComparisonSection(units: units),
                ],
                if ((snapshot.strengthSets?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: B05Layout.space24),
                  StrengthSection(
                    snapshot: snapshot,
                    onViewHistory: (name, stableExerciseId) =>
                        _openStrengthHistory(
                          name,
                          stableExerciseId,
                          snapshot.timezoneId,
                        ),
                  ),
                ],
                if (hasKnownStrengthActivity(snapshot) &&
                    (snapshot.strengthSets?.isEmpty ?? false)) ...[
                  const SizedBox(height: B05Layout.space24),
                  const StrengthEmptySection(),
                ],
                if (snapshot.weightMeasurements.isNotEmpty) ...[
                  const SizedBox(height: B05Layout.space24),
                  ProgressWeightSection(
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
                  NutritionAdherenceSection(
                    summary: snapshot.nutritionSummary!,
                    fitnessGoalLabel: fitnessGoalLabel,
                    onViewTargets: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NutritionTargetsHubScreen(),
                      ),
                    ),
                  ),
                  if (widget.preview == null) ...[
                    ref.watch(adaptiveTdeeEstimateProvider).maybeWhen(
                      data: (estimate) => Column(
                        children: [
                          const SizedBox(height: B05Layout.space24),
                          AdaptiveTdeeCard(
                            estimate: estimate,
                            onAdjustTargets: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NutritionTargetsHubScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ],
                if (hasMeaningfulVolume(snapshot)) ...[
                  const SizedBox(height: B05Layout.space24),
                  TrainingVolumeSection(snapshot: snapshot, units: units),
                ],
                if (hasMeaningfulMuscleBalance(snapshot)) ...[
                  const SizedBox(height: B05Layout.space24),
                  MuscleBalanceSection(readModel: snapshot.muscleBalance!),
                ],
                if (snapshot.bodyMeasurements.isNotEmpty) ...[
                  const SizedBox(height: B05Layout.space24),
                  MeasurementsSection(
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

  ProgressTimeRange _effectiveWeightRange(ProgressDashboardSnapshot snapshot) {
    final ranges = _availableWeightRanges(snapshot);
    if (!ranges.contains(_weightRange)) return ranges.last;
    if (_weightsForRange(snapshot, _weightRange).isEmpty) return ranges.last;
    return _weightRange;
  }

  List<ProgressTimeRange> _availableWeightRanges(
    ProgressDashboardSnapshot snapshot,
  ) {
    final all = _weightsForRange(snapshot, ProgressTimeRange.all);
    if (all.isEmpty) return const [ProgressTimeRange.oneMonth];
    final firstDate = measurementDate(all.first);
    final values = <ProgressTimeRange>[ProgressTimeRange.oneMonth];
    if (firstDate.compareTo(
          ProgressTimeRange.oneMonth.startDate(snapshot.todayLocalDate),
        ) <
        0) {
      values.add(ProgressTimeRange.threeMonths);
    }
    if (firstDate.compareTo(
          ProgressTimeRange.threeMonths.startDate(snapshot.todayLocalDate),
        ) <
        0) {
      values.add(ProgressTimeRange.sixMonths);
    }
    if (firstDate.compareTo(
          ProgressTimeRange.sixMonths.startDate(snapshot.todayLocalDate),
        ) <
        0) {
      values.add(ProgressTimeRange.oneYear);
    }
    if (firstDate.compareTo(
          ProgressTimeRange.oneYear.startDate(snapshot.todayLocalDate),
        ) <
        0) {
      values.add(ProgressTimeRange.all);
    }
    return values;
  }

  List<ProgressMeasurementRecord> _weightsForRange(
    ProgressDashboardSnapshot snapshot,
    ProgressTimeRange range,
  ) {
    final records = snapshot.weightMeasurements.toList(growable: true)
      ..sort(compareMeasurementsChronologically);
    if (range == ProgressTimeRange.all) return records;
    final start = range.startDate(snapshot.todayLocalDate);
    return records
        .where((record) => measurementDate(record).compareTo(start) >= 0)
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
      ..sort(compareMeasurementsChronologically);
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
      builder: (_) => ProgressLogBodyMeasurementsSheet(onSaved: _refresh),
    );
  }
}

