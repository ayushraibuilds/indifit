import 'package:flutter/material.dart';

import '../../../../core/theme/b05_semantic_colors.dart';
import '../../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../../data/models/progress_period_comparison_models.dart';
import '../../widgets/progress_formatters.dart';
import '../../widgets/progress_stat.dart';

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
        ? formatTotalLifted(cur.totalVolumeKg, units)
        : null;

    final prevVolumeText = prev.volumeIsTrustworthy && prev.totalVolumeKg > 0
        ? formatTotalLifted(prev.totalVolumeKg, units)
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
                      'Training activity',
                      style: B05Typography.title(
                        context,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  ?_sessionDelta(comparison.sessionCountMetric.delta),
                ],
              ),
              const SizedBox(height: B05Layout.space12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ProgressStat(
                      label: 'Workouts',
                      value: '${cur.sessionCount}',
                      detail: '${prev.sessionCount} prior',
                      size: ProgressStatSize.compact,
                    ),
                  ),
                  Expanded(
                    child: ProgressStat(
                      label: 'Training days',
                      value: '${cur.trainingDayCount}',
                      detail: '${prev.trainingDayCount} prior',
                      size: ProgressStatSize.compact,
                    ),
                  ),
                  Expanded(
                    child: ProgressStat(
                      label: 'Working sets',
                      value: '${cur.workingSetsCount}',
                      detail: '${prev.workingSetsCount} prior',
                      size: ProgressStatSize.compact,
                    ),
                  ),
                ],
              ),
              if (volumeText != null || prevVolumeText != null) ...[
                const SizedBox(height: B05Layout.space12),
                const Divider(height: 1),
                const SizedBox(height: B05Layout.space12),
                ProgressStat.split(
                  volumeText ?? 'None',
                  label: 'Total volume',
                  detail: prevVolumeText == null
                      ? null
                      : '$prevVolumeText prior',
                  size: ProgressStatSize.compact,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

ProgressStatDelta? _sessionDelta(double? delta) {
  if (delta == null) return null;
  final value = delta.toInt();
  return ProgressStatDelta(
    text: value == 0 ? 'Same' : '${value > 0 ? '+' : '−'}${value.abs()}',
    trend: value == 0
        ? ProgressTrend.flat
        : value > 0
        ? ProgressTrend.up
        : ProgressTrend.down,
  );
}
