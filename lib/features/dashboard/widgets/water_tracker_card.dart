import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../../../core/theme/colors.dart';

class WaterTrackerCard extends ConsumerWidget {
  const WaterTrackerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waterState = ref.watch(waterProvider);
    final int waterLogged = waterState.waterLogged;
    final int waterGoal = waterState.waterGoal;
    final int glassSize = waterState.glassSize;

    final double waterRatio = waterGoal > 0 ? (waterLogged / waterGoal).clamp(0.0, 1.0) : 0.0;
    final int waterMl = waterLogged * glassSize;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop_rounded, color: Colors.blueAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HYDRATION TRACKER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$waterLogged / $waterGoal Glasses ($waterMl ml)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // Decrement button
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 20),
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
                  icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 24),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(waterProvider.notifier).logWater(1);
                  },
                  tooltip: 'Add glass of water',
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: waterRatio,
                minHeight: 6,
                backgroundColor: AppColors.surface,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
