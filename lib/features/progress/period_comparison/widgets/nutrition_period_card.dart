import 'package:flutter/material.dart';

import '../../../../core/theme/b05_semantic_colors.dart';
import '../../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../../data/models/progress_period_comparison_models.dart';

class NutritionPeriodCard extends StatelessWidget {
  const NutritionPeriodCard({
    super.key,
    required this.comparison,
    this.onTap,
  });

  final ComparativeNutritionMetrics comparison;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final cur = comparison.current;
    final prev = comparison.previous;

    final curCalories = cur.averageCaloriesKcal != null
        ? '${cur.averageCaloriesKcal!.round()} kcal'
        : 'No logs';

    final prevCalories = prev.averageCaloriesKcal != null
        ? '${prev.averageCaloriesKcal!.round()} kcal prior'
        : 'No prior logs';

    final curProtein = cur.averageProteinG != null
        ? '${cur.averageProteinG!.toStringAsFixed(1)}g'
        : '—';

    final prevProtein = prev.averageProteinG != null
        ? '${prev.averageProteinG!.toStringAsFixed(1)}g prior'
        : '—';

    final evidence = comparison.caloriesMetric.evidenceDescription ??
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
                          'Nutrition Adherence',
                          style: B05Typography.title(context).copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          evidence,
                          style: B05Typography.caption(context).copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: B05Layout.space12),
              Row(
                children: [
                  Expanded(
                    child: _NutritionMetricColumn(
                      label: 'Daily Avg Calories',
                      currentValue: curCalories,
                      previousValue: prevCalories,
                    ),
                  ),
                  Expanded(
                    child: _NutritionMetricColumn(
                      label: 'Daily Avg Protein',
                      currentValue: curProtein,
                      previousValue: prevProtein,
                    ),
                  ),
                  Expanded(
                    child: _NutritionMetricColumn(
                      label: 'Logged Days',
                      currentValue: '${cur.loggedDaysCount}/${cur.daysInPeriod}',
                      previousValue: '${prev.loggedDaysCount}/${prev.daysInPeriod} prior',
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

class _NutritionMetricColumn extends StatelessWidget {
  const _NutritionMetricColumn({
    required this.label,
    required this.currentValue,
    required this.previousValue,
  });

  final String label;
  final String currentValue;
  final String previousValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: B05Typography.caption(context).copyWith(
            color: colors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          currentValue,
          style: B05Typography.body(context).copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          previousValue,
          style: B05Typography.caption(context).copyWith(
            color: colors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
