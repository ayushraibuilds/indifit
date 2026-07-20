import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/theme/colors.dart';

class AdherenceCard extends StatelessWidget {
  final double adherenceScore;

  const AdherenceCard({
    super.key,
    required this.adherenceScore,
  });

  @override
  Widget build(BuildContext context) {
    Color scoreColor = AppColors.danger;
    String feedback = 'Need focus';
    if (adherenceScore >= 80) {
      scoreColor = AppColors.success;
      feedback = 'Excellent Consistency!';
    } else if (adherenceScore >= 50) {
      scoreColor = AppColors.warning;
      feedback = 'Good progress, keep going!';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 36.0,
              lineWidth: 6.0,
              percent: (adherenceScore / 100.0).clamp(0.0, 1.0),
              center: Text(
                '${adherenceScore.round()}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              progressColor: scoreColor,
              backgroundColor: AppColors.border,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Adherence',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feedback,
                    style: TextStyle(color: scoreColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Calorie accuracy (70%) & workouts completed (30%) in past 7 days.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
