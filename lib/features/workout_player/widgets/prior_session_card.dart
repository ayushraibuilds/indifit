import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/database/app_database.dart';

class PriorSessionCard extends StatelessWidget {
  final List<WorkoutSet> priorSets;
  final WorkoutSet? bestPrSet;
  final double suggestedWeight;

  const PriorSessionCard({
    super.key,
    required this.priorSets,
    this.bestPrSet,
    required this.suggestedWeight,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return B05Surface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stackHeader =
                  constraints.maxWidth < B05Layout.compactBreakpoint ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final heading = Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: colors.action,
                    size: B05Layout.iconSmall,
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: Text(
                      'Last time',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: B05Typography.label(context),
                    ),
                  ),
                ],
              );
              final prBadge = bestPrSet == null
                  ? null
                  : B05Surface(
                      tone: B05SurfaceTone.inset,
                      radius: B05SurfaceRadius.small,
                      padding: const EdgeInsets.symmetric(
                        horizontal: B05Layout.space8,
                        vertical: B05Layout.space4,
                      ),
                      child: Text(
                        'PR: ${bestPrSet!.weight.toStringAsFixed(1)} kg × ${bestPrSet!.reps}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: B05Typography.caption(context).copyWith(
                          color: colors.warning.indicator,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );

              if (prBadge == null) return heading;
              if (stackHeader) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: B05Layout.space8),
                    prBadge,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: B05Layout.space8),
                  Flexible(child: prBadge),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (priorSets.isEmpty)
            Text(
              'No previous sets yet. Start with a comfortable baseline today.',
              style: B05Typography.caption(context),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: priorSets.map((s) {
                return B05Surface(
                  tone: B05SurfaceTone.inset,
                  radius: B05SurfaceRadius.small,
                  padding: const EdgeInsets.symmetric(
                    horizontal: B05Layout.space8,
                    vertical: B05Layout.space4,
                  ),
                  child: Text(
                    'Set ${s.setNumber}: ${s.weight.toStringAsFixed(1)} kg × ${s.reps}',
                    style: B05Typography.caption(
                      context,
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          B05Surface(
            tone: B05SurfaceTone.selected,
            radius: B05SurfaceRadius.small,
            padding: const EdgeInsets.symmetric(
              horizontal: B05Layout.space12,
              vertical: B05Layout.space8,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: colors.action,
                  size: B05Layout.iconSmall,
                ),
                const SizedBox(width: B05Layout.space8),
                Expanded(
                  child: Text(
                    'Suggested starting weight: ${suggestedWeight.toStringAsFixed(1)} kg',
                    style: B05Typography.caption(context).copyWith(
                      color: colors.action,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
