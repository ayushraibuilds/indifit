import 'package:flutter/material.dart';

import '../../../../core/theme/b05_semantic_colors.dart';
import '../../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../../data/models/progress_period_comparison_models.dart';
import '../../widgets/progress_formatters.dart';

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
                      color: Colors.blueAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.monitor_weight_outlined,
                      size: B05Layout.iconMedium,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: Text(
                      'Body Weight Trend',
                      style: B05Typography.title(context).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (deltaText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.inset,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        deltaText,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: B05Layout.space12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latest Weight',
                          style: B05Typography.caption(context).copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          curLatest,
                          style: B05Typography.body(context).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'vs $prevLatest',
                          style: B05Typography.caption(context).copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (rateText != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate of Change',
                            style: B05Typography.caption(context).copyWith(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rateText,
                            style: B05Typography.body(context).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'civil week average',
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
            ],
          ),
        ),
      ),
    );
  }
}
