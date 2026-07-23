import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_rounded, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Prior Session Performance',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                if (bestPrSet != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text('👑 ', style: TextStyle(fontSize: 10)),
                        Text(
                          'PR: ${bestPrSet!.weight.toStringAsFixed(1)}kg x ${bestPrSet!.reps}',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (priorSets.isEmpty)
              const Text(
                'No previous logs found for this exercise. Start your baseline weight today!',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: priorSets.map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'Set ${s.setNumber}: ${s.weight.toStringAsFixed(1)} kg × ${s.reps}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Recommendation: ${suggestedWeight.toStringAsFixed(1)} kg for progressive overload',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
