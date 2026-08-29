import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../dashboard_controller.dart';

class StreakFreezeCard extends ConsumerWidget {
  const StreakFreezeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.b05Colors;
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    final freezes = state.streakFreezesCount;

    return B05Surface(
      radius: B05SurfaceRadius.large,
      subtle: true,
      showBorder: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.info.container,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.ac_unit_rounded,
              color: colors.info.indicator,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Streak Freeze Shield',
                  style: B05Typography.title(context).copyWith(fontSize: 14),
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
                  style: B05Typography.caption(context).copyWith(fontSize: 12),
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
                          backgroundColor: msg.contains('Claimed')
                              ? colors.info.indicator
                              : colors.warning.indicator,
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: freezes >= 2
                  ? colors.inset
                  : colors.info.container,
              foregroundColor: freezes >= 2
                  ? colors.textDisabled
                  : colors.info.indicator,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  freezes >= 2 ? Icons.shield_rounded : Icons.add_rounded,
                  size: 14,
                ),
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
    );
  }
}
