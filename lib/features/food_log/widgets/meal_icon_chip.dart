import 'package:flutter/material.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/art_chip.dart';
import '../meal_presentation_registry.dart';

/// A meal slot's mark in a tinted squircle: the Fluent 3D art when the slot
/// has some, else its icon. The one chip for Today, the Food diary, the meal
/// picker and diary settings, so they always agree.
class MealIconChip extends StatelessWidget {
  const MealIconChip({
    super.key,
    required this.presentation,
    this.color,
    this.size = 40,
  });

  final FoodMealPresentation presentation;

  /// Tint; defaults to the slot's accent, or the snack role when it has none.
  final B05ColorRole? color;

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return ArtChip(
      color:
          color ??
          (presentation.accent != null
              ? colors.meal(presentation.accent!)
              : colors.snack),
      art: presentation.art,
      fallbackIcon: presentation.icon,
      size: size,
    );
  }
}
