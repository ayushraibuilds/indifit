import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../../data/models/progress_period_comparison_models.dart';
import '../progress_period_comparison_controller.dart';
import 'nutrition_period_card.dart';
import 'period_comparison_drilldown_sheet.dart';
import 'period_comparison_selector.dart';
import 'training_period_card.dart';
import 'weight_period_card.dart';

/// Progress tab section displaying truthful cycle-over-cycle comparisons (PV1-PROG-01).
class PeriodComparisonSection extends ConsumerWidget {
  const PeriodComparisonSection({
    super.key,
    required this.units,
  });

  final String units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparisonAsync = ref.watch(progressPeriodComparisonSnapshotProvider);
    final currentRange = ref.watch(periodComparisonRangeProvider);

    return comparisonAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (snapshot) {
        if (!snapshot.hasAnyData) {
          return const SizedBox.shrink();
        }

        final inProgressText = snapshot.currentWindow.isInProgress
            ? snapshot.range == PeriodComparisonRange.week
                ? 'In progress · Day ${snapshot.currentWindow.inProgressDayIndex ?? 1} of 7'
                : 'In progress · 28-day cycle'
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Period Comparison',
                  style: B05Typography.title(context).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton(
                  onPressed: () => PeriodComparisonDrilldownSheet.show(
                    context,
                    snapshot: snapshot,
                    units: units,
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Breakdown'),
                ),
              ],
            ),
            const SizedBox(height: B05Layout.space8),
            PeriodComparisonSelector(
              selectedRange: currentRange,
              onRangeChanged: (newRange) {
                ref.read(periodComparisonRangeProvider.notifier).state = newRange;
              },
              inProgressText: inProgressText,
            ),
            if (snapshot.trainingComparison.hasAnyActivity) ...[
              const SizedBox(height: B05Layout.space12),
              TrainingPeriodCard(
                comparison: snapshot.trainingComparison,
                units: units,
                onTap: () => PeriodComparisonDrilldownSheet.show(
                  context,
                  snapshot: snapshot,
                  units: units,
                ),
              ),
            ],
            if (snapshot.nutritionComparison != null &&
                snapshot.nutritionComparison!.hasAnyLoggedDays) ...[
              const SizedBox(height: B05Layout.space12),
              NutritionPeriodCard(
                comparison: snapshot.nutritionComparison!,
                onTap: () => PeriodComparisonDrilldownSheet.show(
                  context,
                  snapshot: snapshot,
                  units: units,
                ),
              ),
            ],
            if (snapshot.weightComparison != null &&
                snapshot.weightComparison!.hasAnyObservations) ...[
              const SizedBox(height: B05Layout.space12),
              WeightPeriodCard(
                comparison: snapshot.weightComparison!,
                units: units,
                onTap: () => PeriodComparisonDrilldownSheet.show(
                  context,
                  snapshot: snapshot,
                  units: units,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
