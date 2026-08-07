import 'package:flutter/material.dart';

import '../../core/theme/b05_semantic_colors.dart';

/// Stable meal-category IDs used by B03 food logs. Presentation is selected
/// from this registry; display names are never parsed to guess a category.
enum FoodMealCategory { breakfast, lunch, dinner, snack, unknown }

class FoodMealPresentation {
  const FoodMealPresentation({
    required this.category,
    required this.stableId,
    required this.label,
    required this.icon,
    required this.accent,
  });

  final FoodMealCategory category;
  final String stableId;
  final String label;
  final IconData icon;
  final B05MealAccent? accent;

  bool get isKnown => category != FoodMealCategory.unknown;
}

/// The sole B05 mapping from B03 meal-category IDs to icons, labels and
/// semantic accents. Unknown values stay visibly unknown instead of being
/// silently classified from a translated/display name.
abstract final class MealPresentationRegistry {
  static const FoodMealPresentation breakfast = FoodMealPresentation(
    category: FoodMealCategory.breakfast,
    stableId: 'breakfast',
    label: 'Breakfast',
    icon: Icons.wb_sunny_outlined,
    accent: B05MealAccent.breakfast,
  );
  static const FoodMealPresentation lunch = FoodMealPresentation(
    category: FoodMealCategory.lunch,
    stableId: 'lunch',
    label: 'Lunch',
    icon: Icons.wb_twilight_rounded,
    accent: B05MealAccent.lunch,
  );
  static const FoodMealPresentation dinner = FoodMealPresentation(
    category: FoodMealCategory.dinner,
    stableId: 'dinner',
    label: 'Dinner',
    icon: Icons.nightlight_round,
    accent: B05MealAccent.dinner,
  );
  static const FoodMealPresentation snack = FoodMealPresentation(
    category: FoodMealCategory.snack,
    stableId: 'snack',
    label: 'Snacks',
    icon: Icons.cookie_outlined,
    accent: B05MealAccent.snack,
  );
  static const FoodMealPresentation unknown = FoodMealPresentation(
    category: FoodMealCategory.unknown,
    stableId: 'unknown',
    label: 'Meal category unknown',
    icon: Icons.restaurant_outlined,
    accent: null,
  );

  static const List<FoodMealPresentation> values = [
    breakfast,
    lunch,
    dinner,
    snack,
  ];

  static FoodMealPresentation forStableId(String? rawId) {
    final id = rawId?.trim().toLowerCase();
    for (final descriptor in values) {
      if (descriptor.stableId == id) return descriptor;
    }
    return unknown;
  }
}

FoodMealPresentation foodMealPresentationFor(String? mealCategory) =>
    MealPresentationRegistry.forStableId(mealCategory);
