import 'package:flutter/material.dart';

import '../../../../core/presentation/consumer_number_label.dart';
import '../../../../core/theme/b05_semantic_colors.dart';
import '../../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../../data/models/progress_period_comparison_models.dart';
import '../../widgets/progress_stat.dart';

class NutritionPeriodCard extends StatelessWidget {
  const NutritionPeriodCard({super.key, required this.comparison, this.onTap});

  final ComparativeNutritionMetrics comparison;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final cur = comparison.current;
    final prev = comparison.previous;

    final curCalories = cur.averageCaloriesKcal != null
        ? '${ConsumerNumberLabel.rounded(cur.averageCaloriesKcal!)} kcal'
        : 'No logs';

    final prevCalories = prev.averageCaloriesKcal != null
        ? '${ConsumerNumberLabel.rounded(prev.averageCaloriesKcal!)} kcal prior'
        : 'No prior logs';

    final curProtein = cur.averageProteinG != null
        ? '${cur.averageProteinG!.toStringAsFixed(1)} g'
        : '—';

    final prevProtein = prev.averageProteinG != null
        ? '${prev.averageProteinG!.toStringAsFixed(1)} g prior'
        : '—';

    final evidence =
        comparison.caloriesMetric.evidenceDescription ??
        '${cur.loggedDaysCount}/${cur.daysInPeriod} days logged';

    return B05Surface(
      tone: onTap != null ? B05SurfaceTone.interactive : B05SurfaceTone.inset,
      child: InkWell(
        onTap: onTap,
        borderRadius: b05Radius(B05SurfaceRadius.medium),
        child: Padding(
          padding: const EdgeInsets.all(B05Layout.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.success.container,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_rounded,
                      size: B05Layout.iconMedium,
                      color: colors.success.foreground,
                    ),
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nutrition adherence',
                          style: B05Typography.title(
                            context,
                          ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          evidence,
                          style: B05Typography.caption(
                            context,
                          ).copyWith(color: colors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: B05Layout.space12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ProgressStat.split(
                      curCalories,
                      label: 'Daily avg calories',
                      detail: prevCalories,
                      size: ProgressStatSize.compact,
                    ),
                  ),
                  Expanded(
                    child: ProgressStat.split(
                      curProtein,
                      label: 'Daily avg protein',
                      detail: prevProtein,
                      size: ProgressStatSize.compact,
                    ),
                  ),
                  Expanded(
                    child: ProgressStat.split(
                      '${cur.loggedDaysCount}/${cur.daysInPeriod}',
                      label: 'Logged days',
                      detail:
                          '${prev.loggedDaysCount}/${prev.daysInPeriod} prior',
                      size: ProgressStatSize.compact,
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
