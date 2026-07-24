import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../dashboard_controller.dart';

class StreakFreezeCard extends ConsumerWidget {
  const StreakFreezeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    final freezes = state.streakFreezesCount;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.lightBlue.withValues(alpha: 0.25)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.lightBlue.withValues(alpha: 0.08),
              Colors.blue.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.lightBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.ac_unit_rounded,
                color: Colors.lightBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Streak Freeze Shield',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.streakCount == 0
                        ? (freezes == 0
                            ? 'No freeze tokens! Log a workout to start your streak.'
                            : 'Start a streak today to activate your freeze protection shield.')
                        : (freezes == 0
                            ? 'No freeze tokens left! Your streak is unprotected.'
                            : 'Your streak is protected for $freezes missed day${freezes > 1 ? 's' : ''}.'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: freezes >= 2
                  ? null
                  : () async {
                      final msg = await controller.purchaseStreakFreeze();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: msg.contains('Claimed') ? Colors.lightBlue : Colors.orangeAccent,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: freezes >= 2 ? Colors.grey.withValues(alpha: 0.12) : Colors.lightBlue.withValues(alpha: 0.15),
                foregroundColor: freezes >= 2 ? AppColors.textMuted : Colors.lightBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(freezes >= 2 ? Icons.shield_rounded : Icons.add_rounded, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    freezes >= 2 ? 'Max 2/2' : 'Claim',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
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
