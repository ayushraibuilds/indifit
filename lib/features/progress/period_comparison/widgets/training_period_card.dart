import 'package:flutter/material.dart';

import '../../../../core/theme/b05_semantic_colors.dart';
import '../../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../../data/models/progress_period_comparison_models.dart';
import '../../widgets/progress_formatters.dart';

class TrainingPeriodCard extends StatelessWidget {
  const TrainingPeriodCard({
    super.key,
    required this.comparison,
    required this.units,
    this.onTap,
  });

  final ComparativeTrainingMetrics comparison;
  final String units;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final cur = comparison.current;
    final prev = comparison.previous;

    final volumeText = cur.volumeIsTrustworthy && cur.totalVolumeKg > 0
        ? formatWeight(cur.totalVolumeKg, units)
        : null;

    final prevVolumeText = prev.volumeIsTrustworthy && prev.totalVolumeKg > 0
        ? formatWeight(prev.totalVolumeKg, units)
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
                      Icons.fitness_center_rounded,
                      size: B05Layout.iconMedium,
                      color: colors.action,
                    ),
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: Text(
                      'Training Activity',
                      style: B05Typography.title(context).copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _DeltaBadge(
                    delta: comparison.sessionCountMetric.delta,
                    unitLabel: 'workouts',
                  ),
                ],
              ),
              const SizedBox(height: B05Layout.space12),
              Row(
                children: [
                  Expanded(
                    child: _MetricColumn(
                      label: 'Workouts',
                      currentValue: '${cur.sessionCount}',
                      previousValue: '${prev.sessionCount} prior',
                    ),
                  ),
                  Expanded(
                    child: _MetricColumn(
                      label: 'Training Days',
                      currentValue: '${cur.trainingDayCount}',
                      previousValue: '${prev.trainingDayCount} prior',
                    ),
                  ),
                  Expanded(
                    child: _MetricColumn(
                      label: 'Working Sets',
                      currentValue: '${cur.workingSetsCount}',
                      previousValue: '${prev.workingSetsCount} prior',
                    ),
                  ),
                ],
              ),
              if (volumeText != null || prevVolumeText != null) ...[
                const SizedBox(height: B05Layout.space12),
                const Divider(height: 1),
                const SizedBox(height: B05Layout.space12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Volume',
                            style: B05Typography.caption(context).copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            volumeText ?? 'None',
                            style: B05Typography.body(context).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (prevVolumeText != null)
                      Text(
                        'vs $prevVolumeText prior',
                        style: B05Typography.caption(context).copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
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
            fontSize: 16,
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

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({
    required this.delta,
    required this.unitLabel,
  });

  final double? delta;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    if (delta == null) return const SizedBox.shrink();

    final intDelta = delta!.toInt();
    final isPositive = intDelta > 0;
    final isZero = intDelta == 0;

    final bgColor = isZero
        ? colors.inset
        : isPositive
            ? colors.success.container
            : colors.textSecondary.withValues(alpha: 0.12);

    final textColor = isZero
        ? colors.textSecondary
        : isPositive
            ? colors.success.foreground
            : colors.textPrimary;

    final text = isZero ? '= prior' : (isPositive ? '+$intDelta' : '$intDelta');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
