import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// A compact, consumer-facing nutrition summary for legacy dashboard entry
/// points. New Today routes use the B03 presentation model, but this widget
/// follows the same visual and accessibility contract when it is reached.
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
    final colors = context.b05Colors;
    final userProfile = ref.watch(userProfileProvider);
    final calorieGoal = userProfile.calorieGoal;
    final proteinGoal = userProfile.proteinGoal;
    final carbsGoal = userProfile.carbsGoal;
    final fatGoal = userProfile.fatGoal;
    final calPercent = (calorieGoal > 0 ? eatenCalories / calorieGoal : 0.0)
        .clamp(0.0, 1.0);
    final reduceMotion = B05MotionPolicy.reduceMotion(context);

    final ring = Semantics(
      label: calorieGoal > 0
          ? '$eatenCalories of $calorieGoal calories logged'
          : '$eatenCalories calories logged',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: calPercent),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) {
          return CircularPercentIndicator(
            radius: 64,
            lineWidth: 10,
            percent: animatedValue,
            center: eatenCalories == 0
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu_rounded,
                        size: B05Layout.iconLarge,
                        color: colors.action,
                      ),
                      const SizedBox(height: B05Layout.space4),
                      Text(
                        'Log your\nfirst meal',
                        textAlign: TextAlign.center,
                        style: B05Typography.caption(
                          context,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$eatenCalories',
                        style: B05Typography.metric(
                          context,
                        ).copyWith(fontSize: 32, letterSpacing: -1),
                      ),
                      Text(
                        calorieGoal > 0
                            ? (calorieGoal - eatenCalories) >= 0
                                  ? '${calorieGoal - eatenCalories} left'
                                  : '${eatenCalories - calorieGoal} over'
                            : 'calories logged',
                        style: B05Typography.caption(context).copyWith(
                          color: calorieGoal > 0 && eatenCalories > calorieGoal
                              ? colors.danger.indicator
                              : colors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
            circularStrokeCap: CircularStrokeCap.round,
            backgroundColor: colors.border,
            progressColor: colors.action,
          );
        },
      ),
    );

    final macroBars = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMacroBar(
          context,
          'Protein',
          Icons.egg_alt_rounded,
          eatenProtein,
          proteinGoal,
          colors.success.indicator,
        ),
        const SizedBox(height: B05Layout.space8),
        _buildMacroBar(
          context,
          'Carbs',
          Icons.grain_rounded,
          eatenCarbs,
          carbsGoal,
          colors.warning.indicator,
        ),
        const SizedBox(height: B05Layout.space8),
        _buildMacroBar(
          context,
          'Fat',
          Icons.opacity_rounded,
          eatenFat,
          fatGoal,
          colors.danger.indicator,
        ),
        const SizedBox(height: B05Layout.space8),
        _buildMacroBar(
          context,
          'Fiber',
          Icons.eco_rounded,
          eatenFiber,
          30,
          colors.action,
        ),
      ],
    );

    return B05Surface(
      padding: const EdgeInsets.all(B05Layout.space20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackVertically =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.35;
          if (stackVertically) {
            return Column(
              children: [
                ring,
                const SizedBox(height: B05Layout.space20),
                macroBars,
              ],
            );
          }
          return Row(
            children: [
              ring,
              const SizedBox(width: B05Layout.space20),
              Expanded(child: macroBars),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMacroBar(
    BuildContext context,
    String label,
    IconData icon,
    double eaten,
    double goal,
    Color color,
  ) {
    final colors = context.b05Colors;
    final targetPercent = goal > 0 ? (eaten / goal).clamp(0.0, 1.0) : 0.0;
    final remaining = (goal - eaten).round();
    final reduceMotion = B05MotionPolicy.reduceMotion(context);

    return Semantics(
      label: '$label: ${eaten.round()} of ${goal.round()} grams',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: B05Layout.iconSmall, color: color),
                    const SizedBox(width: B05Layout.space4),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: B05Typography.caption(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: B05Layout.space8),
              Text(
                '${eaten.round()}/${goal.round()}g',
                style: B05Typography.caption(context).copyWith(
                  color: remaining < 0
                      ? colors.danger.indicator
                      : colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space4),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: targetPercent),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: B05Radii.smallRadius,
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
