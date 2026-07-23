import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/colors.dart';

class CalorieRingCard extends ConsumerWidget {
  final int eatenCalories;
  final double eatenProtein;
  final double eatenCarbs;
  final double eatenFat;

  const CalorieRingCard({
    super.key,
    required this.eatenCalories,
    required this.eatenProtein,
    required this.eatenCarbs,
    required this.eatenFat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    final calorieGoal = userProfile.calorieGoal;
    final proteinGoal = userProfile.proteinGoal;
    final carbsGoal = userProfile.carbsGoal;
    final fatGoal = userProfile.fatGoal;

    final double calPercent = (calorieGoal > 0 ? (eatenCalories / calorieGoal) : 0.0).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Circular Ring
            CircularPercentIndicator(
              radius: 60.0,
              lineWidth: 10.0,
              percent: calPercent,
              center: eatenCalories == 0
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu_rounded, size: 22, color: AppColors.primary),
                        SizedBox(height: 4),
                        Text(
                          'Log your\nfirst meal',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$eatenCalories',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          (calorieGoal - eatenCalories) >= 0
                              ? '${calorieGoal - eatenCalories} left'
                              : '${eatenCalories - calorieGoal} over',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: (calorieGoal - eatenCalories) >= 0 ? AppColors.textSecondary : AppColors.danger,
                          ),
                        ),
                      ],
                    ),
              circularStrokeCap: CircularStrokeCap.round,
              backgroundColor: AppColors.border,
              progressColor: AppColors.primary,
            ),
            const SizedBox(width: 24),

            // Horizontal Macro Bars
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMacroBar('Protein', eatenProtein, proteinGoal, AppColors.success),
                  const SizedBox(height: 12),
                  _buildMacroBar('Carbs', eatenCarbs, carbsGoal, AppColors.warning),
                  const SizedBox(height: 12),
                  _buildMacroBar('Fat', eatenFat, fatGoal, AppColors.danger),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(String label, double eaten, double goal, Color color) {
    double percent = goal > 0 ? (eaten / goal).clamp(0.0, 1.0) : 0.0;
    int remaining = (goal - eaten).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            Text(
              '${eaten.round()}/${goal.round()}g (${remaining >= 0 ? '${remaining}g left' : '${-remaining}g over'})',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: remaining < 0 ? AppColors.danger : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6.0,
          ),
        ),
      ],
    );
  }
}
