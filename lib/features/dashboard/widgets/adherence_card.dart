import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

class AdherenceCard extends StatelessWidget {
  final double adherenceScore;

  const AdherenceCard({super.key, required this.adherenceScore});

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    Color scoreColor = colors.danger.indicator;
    String feedback = 'Need focus';
    if (adherenceScore >= 80) {
      scoreColor = colors.success.indicator;
      feedback = 'Excellent Consistency!';
    } else if (adherenceScore >= 50) {
      scoreColor = colors.warning.indicator;
      feedback = 'Good progress, keep going!';
    }

    return B05Surface(
      radius: B05SurfaceRadius.large,
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 36.0,
            lineWidth: 6.0,
            percent: (adherenceScore / 100.0).clamp(0.0, 1.0),
            animation: true,
            animationDuration: 600,
            center: Text(
              '${adherenceScore.round()}%',
              style: B05Typography.label(context).copyWith(fontSize: 14),
            ),
            progressColor: scoreColor,
            backgroundColor: colors.border,
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(width: B05Layout.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Adherence',
                  style: B05Typography.label(context),
                ),
                const SizedBox(height: 4),
                Text(
                  feedback,
                  style: TextStyle(
                    color: scoreColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Calorie accuracy (70%) & workouts completed (30%) in past 7 days.',
                  style: B05Typography.caption(context).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
