import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/user_profile_provider.dart';
import '../../../core/theme/colors.dart';

class ProgressBmiHealthCard extends ConsumerWidget {
  final double? weightKg;

  const ProgressBmiHealthCard({super.key, required this.weightKg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    final double? heightCm = userProfile.userHeight;

    if (weightKg == null || weightKg! <= 0) {
      return const SizedBox.shrink();
    }

    if (heightCm == null || heightCm <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: const [
              Icon(Icons.straighten_rounded, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Set your height in onboarding/profile to calculate your BMI.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final double heightMeters = heightCm / 100.0;
    final double bmi = weightKg! / (heightMeters * heightMeters);

    String category;
    Color categoryColor;
    if (bmi < 18.5) {
      category = 'Underweight';
      categoryColor = AppColors.warning;
    } else if (bmi < 25.0) {
      category = 'Normal weight';
      categoryColor = AppColors.success;
    } else if (bmi < 30.0) {
      category = 'Overweight';
      categoryColor = AppColors.warning;
    } else {
      category = 'Obese';
      categoryColor = AppColors.danger;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.monitor_weight_outlined,
                color: categoryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BMI & Weight Category',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'BMI: ${bmi.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: categoryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
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
