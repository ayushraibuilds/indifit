import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/colors.dart';

class CalorieRingCard extends ConsumerWidget {
  final int eatenCalories;
  final double eatenProtein;
  final double eatenCarbs;
  final double eatenFat;
  final double eatenFiber;

  const CalorieRingCard({
    super.key,
    required this.eatenCalories,
    required this.eatenProtein,
    required this.eatenCarbs,
    required this.eatenFat,
    this.eatenFiber = 0.0,
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
            // Circular Ring with Smooth Animation
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: calPercent),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, animatedValue, _) {
                return CircularPercentIndicator(
                  radius: 68.0,
                  lineWidth: 12.0,
                  percent: animatedValue,
                  center: eatenCalories == 0
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu_rounded, size: 24, color: AppColors.primary),
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
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: GoogleFonts.outfit().fontFamily,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              (calorieGoal - eatenCalories) >= 0
                                  ? '${calorieGoal - eatenCalories} left'
                                  : '${eatenCalories - calorieGoal} over',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (calorieGoal - eatenCalories) >= 0 ? AppColors.textSecondary : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                  circularStrokeCap: CircularStrokeCap.round,
                  backgroundColor: AppColors.border,
                  progressColor: AppColors.primary,
                );
              },
            ),
            const SizedBox(width: 20),

            // Horizontal Macro Bars
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMacroBar('Protein', Icons.egg_alt_rounded, eatenProtein, proteinGoal, AppColors.success),
                  const SizedBox(height: 10),
                  _buildMacroBar('Carbs', Icons.grain_rounded, eatenCarbs, carbsGoal, AppColors.warning),
                  const SizedBox(height: 10),
                  _buildMacroBar('Fat', Icons.opacity_rounded, eatenFat, fatGoal, AppColors.danger),
                  const SizedBox(height: 10),
                  _buildMacroBar('Fiber', Icons.eco_rounded, eatenFiber, 30.0, AppColors.fiberTeal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(String label, IconData icon, double eaten, double goal, Color color) {
    double targetPercent = goal > 0 ? (eaten / goal).clamp(0.0, 1.0) : 0.0;
    int remaining = (goal - eaten).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
            Text(
              '${eaten.round()}/${goal.round()}g',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: remaining < 0 ? AppColors.danger : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: targetPercent),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: val,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6.0,
              ),
            );
          },
        ),
      ],
    );
  }
}
