import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../../data/models/adaptive_tdee_models.dart';
import 'progress_sections.dart';

/// Informational card displaying the on-device Adaptive TDEE estimate.
///
/// Strictly informational:
/// - Displays estimated daily caloric burn, noise-filtered trend weight, and confidence.
/// - Does not write or directly set targets. Target adjustments navigate to the
///   canonical B04 Coaching Hub (`NutritionTargetsHubScreen`).
class AdaptiveTdeeCard extends StatelessWidget {
  const AdaptiveTdeeCard({
    super.key,
    required this.estimate,
    required this.onAdjustTargets,
  });

  final AdaptiveTdeeEstimate estimate;
  final VoidCallback onAdjustTargets;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final int displayKcal = estimate.currentTdeeKcal.round();

    final (confidenceLabel, confidenceRole) = switch (estimate.confidence) {
      AdaptiveTdeeConfidence.high => ('High Confidence', colors.success),
      AdaptiveTdeeConfidence.moderate => ('Moderate Confidence', colors.info),
      AdaptiveTdeeConfidence.calibrating => ('Calibrating', colors.warning),
    };

    final semanticsLabel =
        'Adaptive expenditure: $displayKcal kilocalories per day. $confidenceLabel. ${estimate.confidenceMessage}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProgressSectionHeading(title: 'Adaptive expenditure'),
        const SizedBox(height: B05Layout.space8),
        B05Surface(
          padding: const EdgeInsets.all(B05Layout.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: semanticsLabel,
                          child: ExcludeSemantics(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$displayKcal',
                                  style: B05Typography.metric(context),
                                ),
                                const SizedBox(width: B05Layout.space8),
                                Text(
                                  'kcal/day',
                                  style: B05Typography.caption(context).copyWith(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          estimate.confidenceMessage,
                          style: B05Typography.caption(context).copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: B05Layout.space8,
                      vertical: B05Layout.space4,
                    ),
                    decoration: BoxDecoration(
                      color: confidenceRole.container,
                      borderRadius: b05Radius(B05SurfaceRadius.small),
                      border: Border.all(color: confidenceRole.indicator),
                    ),
                    child: Text(
                      confidenceLabel,
                      style: B05Typography.caption(context).copyWith(
                        color: confidenceRole.foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              if (estimate.trendWeightKg != null) ...[
                const SizedBox(height: B05Layout.space16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: B05Layout.space12,
                    vertical: B05Layout.space8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: b05Radius(B05SurfaceRadius.small),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_graph_rounded, size: 16, color: colors.action),
                      const SizedBox(width: B05Layout.space8),
                      Text(
                        estimate.currentScaleWeightKg != null
                            ? 'Trend: ${estimate.trendWeightKg!.toStringAsFixed(1)} kg · Scale: ${estimate.currentScaleWeightKg!.toStringAsFixed(1)} kg'
                            : 'Trend: ${estimate.trendWeightKg!.toStringAsFixed(1)} kg',
                        style: B05Typography.caption(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: B05Layout.space12),
              Text(
                'Informational estimate for general wellness only. Adjust targets in the Coaching Hub.',
                style: B05Typography.caption(context).copyWith(
                  color: colors.textDisabled,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: B05Layout.space16),
              Row(
                children: [
                  B05ActionButton(
                    label: 'How it works',
                    icon: Icons.info_outline_rounded,
                    emphasis: B05ActionEmphasis.tertiary,
                    onPressed: () => _showExplanationSheet(context),
                  ),
                  const SizedBox(width: B05Layout.space12),
                  B05ActionButton(
                    label: 'Adjust targets',
                    icon: Icons.tune_rounded,
                    emphasis: B05ActionEmphasis.secondary,
                    onPressed: onAdjustTargets,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showExplanationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.b05Colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(B05Radii.large),
        ),
      ),
      builder: (ctx) {
        final colors = ctx.b05Colors;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(B05Layout.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'How Adaptive TDEE Works',
                      style: B05Typography.title(ctx),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: B05Layout.space16),
                Text(
                  'IndiFit dynamically calculates your true daily energy expenditure locally on-device '
                  'using dynamic energy balance:\n\n'
                  'Expenditure = Calories In - (Delta Trend Weight * 7,700 kcal)\n\n'
                  '• Adherence-Neutral: Missing food logs or weigh-ins are treated as unobserved—never assumed as 0 calories.\n\n'
                  '• Noise-Filtered: Daily scale water fluctuations are smoothed into Trend Weight.\n\n'
                  '• Physiologically Bounded: Day-over-day changes are clamped (+/- 35 kcal/day) to prevent whiplash.\n\n'
                  '• General Wellness Only: This is an informational baseline. All target proposals and coaching adjustments '
                  'are explicitly accepted in the Coaching Hub under clinical safety checks.',
                  style: B05Typography.body(ctx).copyWith(
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: B05Layout.space24),
                SizedBox(
                  width: double.infinity,
                  child: B05ActionButton(
                    label: 'Got it',
                    emphasis: B05ActionEmphasis.primary,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
