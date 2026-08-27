import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/health_provider.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

class TodaysActivityCard extends ConsumerWidget {
  const TodaysActivityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.b05Colors;
    final healthState = ref.watch(healthStateProvider);
    final data = healthState.summary;
    final int steps = data.steps;
    final double activeCals = data.activeCalories;
    final double sleepHours = data.sleepHours;
    final double stepProgress = (steps / 10000.0).clamp(0.0, 1.0);
    final bool isConnected = data.isConnected;

    return B05Surface(
      radius: B05SurfaceRadius.large,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    color: colors.danger.indicator,
                    size: 18,
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Text(
                    "TODAY'S HEALTH ACTIVITY",
                    style: B05Typography.caption(context).copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () async {
                  await ref
                      .read(healthStateProvider.notifier)
                      .connectAndRefresh();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? colors.success.container
                        : colors.interactive,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isConnected
                          ? colors.success.indicator.withValues(alpha: 0.3)
                          : colors.action.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConnected
                            ? Icons.check_circle_rounded
                            : Icons.link_rounded,
                        size: 12,
                        color: isConnected
                            ? colors.success.indicator
                            : colors.action,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnected ? 'Health Sync Active' : 'Connect Health',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isConnected
                              ? colors.success.foreground
                              : colors.action,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Steps',
                      style: B05Typography.caption(context).copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$steps',
                      style: B05Typography.title(context).copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stepProgress,
                        minHeight: 4,
                        backgroundColor: colors.inset,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.action,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Energy',
                      style: B05Typography.caption(context).copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${activeCals.toStringAsFixed(0)} kcal',
                      style: B05Typography.title(context).copyWith(
                        fontSize: 18,
                        color: colors.warning.indicator,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sleep',
                      style: B05Typography.caption(context).copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sleepHours.toStringAsFixed(1)} hrs',
                      style: B05Typography.title(context).copyWith(
                        fontSize: 18,
                        color: colors.info.indicator,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
