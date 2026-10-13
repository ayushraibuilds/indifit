import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import 'hydration_fluid_fill.dart';

/// A drinking glass that fills upward with the day's water: the Today water
/// row's gauge. Reuses the fluid fill painter, clipped to a glass; under
/// Reduce Motion the level is a still block of water.
class HydrationGlass extends StatelessWidget {
  const HydrationGlass({
    super.key,
    required this.progress,
    required this.isGoalMet,
    required this.fillDuration,
    this.width = 52,
    this.height = 76,
  });

  /// Raw ratio of intake to goal; the water is clamped to a full glass.
  final double progress;
  final bool isGoalMet;
  final Duration fillDuration;
  final double width;
  final double height;

  /// Narrow rim, rounded base.
  static const BorderRadius shape = BorderRadius.only(
    topLeft: Radius.circular(6),
    topRight: Radius.circular(6),
    bottomLeft: Radius.circular(18),
    bottomRight: Radius.circular(18),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final water = isGoalMet ? colors.success : colors.info;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: B05MotionContent(
              animatedChild: HydrationFluidFillIndicator(
                progress: progress,
                isGoalMet: isGoalMet,
                fillDuration: fillDuration,
                height: height,
                borderRadius: shape,
              ),
              reducedMotionChild: ClipRRect(
                borderRadius: shape,
                child: ColoredBox(
                  color: water.container.withValues(alpha: 0.30),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      key: const Key('hydration_glass_still_level'),
                      heightFactor: progress.clamp(0.0, 1.0),
                      widthFactor: 1,
                      child: ColoredBox(color: water.indicator),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Glass: a rim and a long highlight down the left side.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: shape,
                  border: Border.all(
                    color: colors.textSecondary.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: width * 0.15,
            top: height * 0.13,
            bottom: height * 0.24,
            width: 3,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.55),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
