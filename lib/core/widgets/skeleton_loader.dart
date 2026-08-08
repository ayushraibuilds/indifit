import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/b05_semantic_colors.dart';
import 'b05_accessibility_primitives.dart';

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    final box = SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.inset,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
    final content = B05MotionPolicy.reduceMotion(context)
        ? box
        : box
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .shimmer(duration: 1200.ms, color: colors.interactive)
              .fadeIn(duration: 180.ms);
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(child: content),
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double height;

  const SkeletonCard({super.key, this.height = 72.0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space8),
      child: B05Surface(
        subtle: true,
        showBorder: false,
        padding: const EdgeInsets.all(B05Layout.space16),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              const SkeletonBox(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: B05Layout.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SkeletonBox(width: 140, height: 14),
                    const SizedBox(height: B05Layout.space8),
                    SkeletonBox(width: 80, height: 10, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;

  const SkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (context, index) => const SkeletonCard(),
    );
  }
}
