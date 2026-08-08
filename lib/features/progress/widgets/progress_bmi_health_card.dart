import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/user_profile_provider.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

class ProgressBmiHealthCard extends ConsumerWidget {
  final double? weightKg;

  const ProgressBmiHealthCard({super.key, required this.weightKg});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.b05Colors;
    final userProfile = ref.watch(userProfileProvider);
    final heightCm = userProfile.userHeight;

    if (weightKg == null || weightKg! <= 0) {
      return const SizedBox.shrink();
    }

    if (heightCm == null || heightCm <= 0) {
      return B05Surface(
        tone: B05SurfaceTone.inset,
        child: Row(
          children: [
            Icon(
              Icons.straighten_rounded,
              color: colors.action,
              size: B05Layout.iconMedium,
            ),
            const SizedBox(width: B05Layout.space12),
            Expanded(
              child: Text(
                'Add your height in Profile to calculate BMI.',
                style: B05Typography.caption(context),
              ),
            ),
          ],
        ),
      );
    }

    final heightMeters = heightCm / 100;
    final bmi = weightKg! / (heightMeters * heightMeters);
    final (category, categoryColor) = switch (bmi) {
      < 18.5 => ('Underweight', colors.warning),
      < 25.0 => ('In the healthy range', colors.success),
      < 30.0 => ('Overweight', colors.warning),
      _ => ('Obese', colors.danger),
    };

    return Semantics(
      label: 'BMI ${bmi.toStringAsFixed(1)}, $category',
      child: B05Surface(
        child: Row(
          children: [
            B05Surface(
              tone: B05SurfaceTone.inset,
              radius: B05SurfaceRadius.medium,
              padding: const EdgeInsets.all(B05Layout.space12),
              child: Icon(
                Icons.monitor_weight_outlined,
                color: categoryColor.indicator,
                size: B05Layout.iconLarge,
              ),
            ),
            const SizedBox(width: B05Layout.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BMI', style: B05Typography.label(context)),
                  const SizedBox(height: B05Layout.space4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: B05Layout.space8,
                    runSpacing: B05Layout.space4,
                    children: [
                      Text(
                        bmi.toStringAsFixed(1),
                        style: B05Typography.title(context),
                      ),
                      B05Surface(
                        tone: B05SurfaceTone.inset,
                        radius: B05SurfaceRadius.small,
                        padding: const EdgeInsets.symmetric(
                          horizontal: B05Layout.space8,
                          vertical: B05Layout.space4,
                        ),
                        child: Text(
                          category,
                          style: B05Typography.caption(context).copyWith(
                            color: categoryColor.foreground,
                            fontWeight: FontWeight.bold,
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
