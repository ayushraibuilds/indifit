import 'package:flutter/material.dart';

import '../../../../core/theme/b05_semantic_colors.dart';
import '../../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../../data/models/progress_period_comparison_models.dart';
import '../../widgets/progress_formatters.dart';
import '../../widgets/progress_stat.dart';

class WeightPeriodCard extends StatelessWidget {
  const WeightPeriodCard({
    super.key,
    required this.comparison,
    required this.units,
    this.onTap,
  });

  final ComparativeWeightMetrics comparison;
  final String units;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final cur = comparison.current;
    final prev = comparison.previous;

    final curLatest = cur.latestWeightKg != null
        ? formatWeight(cur.latestWeightKg!, units)
        : 'No records';

    final prevLatest = prev.latestWeightKg != null
        ? formatWeight(prev.latestWeightKg!, units)
        : 'No prior records';

    final delta = comparison.weightDeltaBetweenPeriodsKg;
    final deltaText = delta != null
        ? '${delta > 0 ? '+' : ''}${formatWeight(delta, units)}'
        : null;

    final rate = comparison.ratePerWeekKg;
    final rateText = rate != null
        ? '${rate > 0 ? '+' : ''}${formatWeight(rate, units)} / week'
        : null;

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
                      color: colors.action.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.monitor_weight_outlined,
                      size: B05Layout.iconMedium,
                      color: colors.action,
                    ),
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: Text(
                      'Body weight trend',
                      style: B05Typography.title(
                        context,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (delta != null)
                    ProgressStatDelta(
                      text: deltaText!,
                      trend: delta == 0
                          ? ProgressTrend.flat
                          : delta > 0
                          ? ProgressTrend.up
                          : ProgressTrend.down,
                      neutral: true,
                    ),
                ],
              ),
              const SizedBox(height: B05Layout.space12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ProgressStat.split(
                      curLatest,
                      label: 'Latest weight',
                      detail: 'vs $prevLatest',
                      size: ProgressStatSize.compact,
                    ),
                  ),
                  if (rateText != null)
                    Expanded(
                      child: ProgressStat.split(
                        rateText,
                        label: 'Rate of change',
                        detail: 'Average per week',
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
