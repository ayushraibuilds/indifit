import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';

import '../theme/b05_semantic_colors.dart';
import 'b05_accessibility_primitives.dart';

/// A mark in a tinted squircle: Fluent 3D [art] (assets/ui_icons/SOURCE.md)
/// when there is some, else [fallbackIcon]. Decorative; callers label the row.
class ArtChip extends StatelessWidget {
  const ArtChip({
    super.key,
    required this.color,
    required this.fallbackIcon,
    this.art,
    this.size = 40,
  });

  final B05ColorRole color;
  final String? art;
  final IconData fallbackIcon;
  final double size;

  /// Art fills this share of the chip, so a 40 pt chip carries 28 pt art.
  static const double artFraction = 0.7;

  @override
  Widget build(BuildContext context) {
    final markSize = size * artFraction;
    Widget icon() =>
        Icon(fallbackIcon, size: size * 0.5, color: color.indicator);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: color.container,
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: size * 0.32,
                cornerSmoothing: B05Radii.smoothing,
              ),
            ),
          ),
          child: Center(
            child: art == null
                ? icon()
                : Image.asset(
                    art!,
                    width: markSize,
                    height: markSize,
                    cacheWidth: (markSize * 3).round(),
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => icon(),
                  ),
          ),
        ),
      ),
    );
  }
}
