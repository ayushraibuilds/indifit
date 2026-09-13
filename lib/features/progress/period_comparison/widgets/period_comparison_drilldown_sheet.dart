import 'package:flutter/material.dart';

import '../../../../core/theme/b05_semantic_colors.dart';
import '../../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../../core/widgets/indi_fit_bottom_sheet.dart';
import '../../../../data/models/progress_period_comparison_models.dart';
import '../../widgets/progress_formatters.dart';

/// Modal bottom sheet displaying granular historical drill-downs for the compared periods.
class PeriodComparisonDrilldownSheet extends StatelessWidget {
  const PeriodComparisonDrilldownSheet({
    super.key,
    required this.snapshot,
    required this.units,
  });

  final ProgressPeriodComparisonSnapshot snapshot;
  final String units;

  static void show(
    BuildContext context, {
    required ProgressPeriodComparisonSnapshot snapshot,
    required String units,
  }) {
    showIndiFitBottomSheet<void>(
      context: context,
      builder: (_) => PeriodComparisonDrilldownSheet(
        snapshot: snapshot,
        units: units,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final rangeLabel = snapshot.range == PeriodComparisonRange.week
        ? 'Weekly Period Breakdown'
        : '4-Week Cycle Breakdown';

    final dateRangeLabel =
        '${snapshot.currentWindow.startLocalDate} to ${snapshot.currentWindow.endLocalDate} '
        'vs ${snapshot.previousWindow.startLocalDate} to ${snapshot.previousWindow.endLocalDate}';

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: B05Layout.space16),
              Text(
                rangeLabel,
                style: B05Typography.title(context).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: B05Layout.space4),
              Text(
                dateRangeLabel,
                style: B05Typography.caption(context).copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: B05Layout.space20),

              // Strength Exercises Comparison
              if (snapshot.strengthComparisons.isNotEmpty) ...[
                Text(
                  'Top Trained Exercises',
                  style: B05Typography.body(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: B05Layout.space8),
                for (final ex in snapshot.strengthComparisons.take(5))
                  _StrengthExerciseRow(exercise: ex, units: units),
                const SizedBox(height: B05Layout.space20),
              ],

              // Training Summary
              Text(
                'Training Details',
                style: B05Typography.body(context).copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: B05Layout.space8),
              _DetailGrid(
                items: [
                  _GridItem(
                    label: 'Full Sessions',
                    current: '${snapshot.trainingComparison.current.fullSessionCount}',
                    previous: '${snapshot.trainingComparison.previous.fullSessionCount}',
                  ),
                  _GridItem(
                    label: 'Partial Sessions',
                    current: '${snapshot.trainingComparison.current.partialSessionCount}',
                    previous: '${snapshot.trainingComparison.previous.partialSessionCount}',
                  ),
                  _GridItem(
                    label: 'Total Sets',
                    current: '${snapshot.trainingComparison.current.workingSetsCount}',
                    previous: '${snapshot.trainingComparison.previous.workingSetsCount}',
                  ),
                  _GridItem(
                    label: 'Total Time',
                    current: _formatDuration(snapshot.trainingComparison.current.totalDurationSeconds),
                    previous: _formatDuration(snapshot.trainingComparison.previous.totalDurationSeconds),
                  ),
                ],
              ),
              const SizedBox(height: B05Layout.space20),

              // Nutrition Summary if available
              if (snapshot.nutritionComparison != null) ...[
                Text(
                  'Nutrition Details',
                  style: B05Typography.body(context).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: B05Layout.space8),
                _DetailGrid(
                  items: [
                    _GridItem(
                      label: 'Logged Days',
                      current: '${snapshot.nutritionComparison!.current.loggedDaysCount} / ${snapshot.nutritionComparison!.current.daysInPeriod}',
                      previous: '${snapshot.nutritionComparison!.previous.loggedDaysCount} / ${snapshot.nutritionComparison!.previous.daysInPeriod}',
                    ),
                    _GridItem(
                      label: 'Target Met Days',
                      current: '${snapshot.nutritionComparison!.current.proteinTargetMetDaysCount}',
                      previous: '${snapshot.nutritionComparison!.previous.proteinTargetMetDaysCount}',
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? '${hours}h ${remainingMinutes}m' : '${hours}h';
  }
}

class _StrengthExerciseRow extends StatelessWidget {
  const _StrengthExerciseRow({
    required this.exercise,
    required this.units,
  });

  final StrengthExercisePeriodComparison exercise;
  final String units;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    final curSet = exercise.currentHeaviestLoadKg != null
        ? '${formatWeight(exercise.currentHeaviestLoadKg!, units)} × ${exercise.currentHeaviestReps}'
        : '—';

    final prevSet = exercise.previousHeaviestLoadKg != null
        ? '${formatWeight(exercise.previousHeaviestLoadKg!, units)} × ${exercise.previousHeaviestReps}'
        : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space8),
      child: B05Surface(
        tone: B05SurfaceTone.inset,
        child: Padding(
          padding: const EdgeInsets.all(B05Layout.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                exercise.exerciseName,
                style: B05Typography.body(context).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: B05Layout.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Heaviest: $curSet',
                    style: B05Typography.caption(context).copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'prior: $prevSet',
                    style: B05Typography.caption(context).copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridItem {
  const _GridItem({
    required this.label,
    required this.current,
    required this.previous,
  });

  final String label;
  final String current;
  final String previous;
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.items});

  final List<_GridItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return B05Surface(
      tone: B05SurfaceTone.inset,
      child: Padding(
        padding: const EdgeInsets.all(B05Layout.space12),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    items[i].label,
                    style: B05Typography.caption(context).copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    '${items[i].current} (vs ${items[i].previous} prior)',
                    style: B05Typography.caption(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (i < items.length - 1) const Divider(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
