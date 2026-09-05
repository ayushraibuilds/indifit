import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../models/workout_completion_recap.dart';

/// Privacy-aware visual workout recap and system share card.
///
/// Invariant: Respects user privacy by allowing weight redaction before
/// sharing, and never exposes unbacked synthetic scores.
class WorkoutShareCard extends StatefulWidget {
  final WorkoutCompletionRecap recap;

  const WorkoutShareCard({super.key, required this.recap});

  @override
  State<WorkoutShareCard> createState() => _WorkoutShareCardState();
}

class _WorkoutShareCardState extends State<WorkoutShareCard> {
  bool _includeWeights = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final theme = Theme.of(context);
    final recap = widget.recap;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: b05Radius(B05SurfaceRadius.large),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(B05Layout.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                recap.isPartial
                    ? Icons.check_circle_outline_rounded
                    : Icons.check_circle_rounded,
                color: colors.success.indicator,
                size: 28,
              ),
              const SizedBox(width: B05Layout.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recap.workoutTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      recap.formattedDuration,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space16),
          // Metric chips
          Wrap(
            spacing: B05Layout.space8,
            runSpacing: B05Layout.space8,
            children: [
              _buildMetricChip(
                context,
                label: 'Exercises',
                value: '${recap.completedExercisesCount}',
              ),
              _buildMetricChip(
                context,
                label: 'Sets',
                value: '${recap.completedSetsCount}',
              ),
              _buildMetricChip(
                context,
                label: 'Reps',
                value: '${recap.totalRepsCount}',
              ),
              if (_includeWeights && recap.totalVolumeKg > 0)
                _buildMetricChip(
                  context,
                  label: 'Volume',
                  value: '${recap.totalVolumeKg.toStringAsFixed(1)} kg',
                ),
            ],
          ),
          if (recap.previousComparison case final prev?) ...[
            const SizedBox(height: B05Layout.space12),
            Container(
              padding: const EdgeInsets.all(B05Layout.space8),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: b05Radius(B05SurfaceRadius.small),
              ),
              child: Row(
                children: [
                  Icon(
                    prev.volumeDeltaKg >= 0
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    size: 16,
                    color: prev.volumeDeltaKg >= 0
                        ? colors.success.indicator
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: Text(
                      _includeWeights
                          ? '${prev.volumeDeltaKg >= 0 ? '+' : ''}${prev.volumeDeltaKg.toStringAsFixed(1)} kg vs previous'
                          : '${prev.setsDelta >= 0 ? '+' : ''}${prev.setsDelta} sets vs previous',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (recap.isFirstSession) ...[
            const SizedBox(height: B05Layout.space12),
            Text(
              'First time logging this routine',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: B05Layout.space16),
          // Privacy Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Include weights in share',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Switch.adaptive(
                value: _includeWeights,
                onChanged: (val) => setState(() => _includeWeights = val),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space12),
          // Share Action Button
          FilledButton.icon(
            key: const Key('workout_share_button'),
            onPressed: () {
              final text = recap.generateShareText(includeWeights: _includeWeights);
              Share.share(text);
            },
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share workout recap'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colors = context.b05Colors;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: B05Layout.space12,
        vertical: B05Layout.space4,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: b05Radius(B05SurfaceRadius.small),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
