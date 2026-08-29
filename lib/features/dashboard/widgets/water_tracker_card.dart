import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

class WaterTrackerCard extends ConsumerWidget {
  const WaterTrackerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.b05Colors;
    final waterState = ref.watch(waterProvider);
    final int waterLogged = waterState.waterLogged;
    final int waterGoal = waterState.waterGoal;
    final int glassSize = waterState.glassSize;

    final double waterRatio = waterGoal > 0
        ? (waterLogged / waterGoal).clamp(0.0, 1.0)
        : 0.0;
    final int waterMl = waterLogged * glassSize;

    return B05Surface(
      radius: B05SurfaceRadius.large,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.info.container,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: colors.info.indicator,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HYDRATION TRACKER',
                      style: B05Typography.caption(context).copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$waterLogged / $waterGoal Glasses ($waterMl ml)',
                      style: B05Typography.title(context).copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),

              // Decrement button
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: colors.textSecondary,
                  size: 20,
                ),
                onPressed: waterLogged > 0
                    ? () {
                        HapticFeedback.lightImpact();
                        ref.read(waterProvider.notifier).logWater(-1);
                      }
                    : null,
                tooltip: 'Decrease water intake',
              ),

              // Quick Increment (+1 glass)
              IconButton(
                icon: Icon(
                  Icons.add_circle,
                  color: colors.info.indicator,
                  size: 24,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(waterProvider.notifier).logWater(1);
                },
                tooltip: 'Add glass of water',
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: waterRatio),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, animRatio, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: animRatio,
                  minHeight: 6,
                  backgroundColor: colors.inset,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colors.info.indicator,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickChip(context, ref, '+250ml', 1),
              _buildQuickChip(context, ref, '+500ml', 2),
              _buildQuickChip(context, ref, '+750ml', 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    int glasses,
  ) {
    final colors = context.b05Colors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(waterProvider.notifier).logWater(glasses);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.info.container,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.info.indicator.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 12, color: colors.info.indicator),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: colors.info.indicator,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
