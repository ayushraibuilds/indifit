import 'package:flutter/material.dart';

import '../../core/theme/b05_semantic_colors.dart';
import '../../data/models/meal_category_definitions.dart';

export '../../data/models/meal_category_definitions.dart';

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
  static const FoodMealPresentation morningSnack = FoodMealPresentation(
    category: FoodMealCategory.morningSnack,
    stableId: 'morning_snack',
    label: 'Morning snack',
    icon: Icons.coffee_outlined,
    accent: B05MealAccent.snack,
  );
  static const FoodMealPresentation lunch = FoodMealPresentation(
    category: FoodMealCategory.lunch,
    stableId: 'lunch',
    label: 'Lunch',
    icon: Icons.wb_twilight_rounded,
    accent: B05MealAccent.lunch,
  );
  static const FoodMealPresentation afternoonSnack = FoodMealPresentation(
    category: FoodMealCategory.afternoonSnack,
    stableId: 'afternoon_snack',
    label: 'Afternoon snack',
    icon: Icons.cookie_outlined,
    accent: B05MealAccent.snack,
  );
  static const FoodMealPresentation eveningSnack = FoodMealPresentation(
    category: FoodMealCategory.eveningSnack,
    stableId: 'evening_snack',
    label: 'Evening snack',
    icon: Icons.cookie_outlined,
    accent: B05MealAccent.snack,
  );
  static const FoodMealPresentation dinner = FoodMealPresentation(
    category: FoodMealCategory.dinner,
    stableId: 'dinner',
    label: 'Dinner',
    icon: Icons.nightlight_round,
    accent: B05MealAccent.dinner,
  );
  static const FoodMealPresentation preWorkout = FoodMealPresentation(
    category: FoodMealCategory.preWorkout,
    stableId: 'pre_workout',
    label: 'Pre-workout',
    icon: Icons.bolt_outlined,
    accent: B05MealAccent.snack,
  );
  static const FoodMealPresentation postWorkout = FoodMealPresentation(
    category: FoodMealCategory.postWorkout,
    stableId: 'post_workout',
    label: 'Post-workout',
    icon: Icons.fitness_center_outlined,
    accent: B05MealAccent.snack,
  );
  static const FoodMealPresentation snack = FoodMealPresentation(
    category: FoodMealCategory.snack,
    stableId: 'snack',
    label: 'Snacks',
    icon: Icons.cookie_outlined,
    accent: B05MealAccent.snack,
  );
  static const FoodMealPresentation lateSnack = FoodMealPresentation(
    category: FoodMealCategory.lateSnack,
    stableId: 'late_snack',
    label: 'Late snack',
    icon: Icons.bedtime_outlined,
    accent: B05MealAccent.snack,
  );
  static const FoodMealPresentation unknown = FoodMealPresentation(
    category: FoodMealCategory.unknown,
    stableId: 'unknown',
    label: 'Meal category unknown',
    icon: Icons.restaurant_outlined,
    accent: null,
  );

  /// Default 4 canonical meal slots per R08D baseline.
  static const List<FoodMealPresentation> values = [
    breakfast,
    lunch,
    dinner,
    snack,
  ];

  /// All supported canonical and optional meal/snack slot descriptors.
  static const List<FoodMealPresentation> allSupported = [
    breakfast,
    morningSnack,
    lunch,
    afternoonSnack,
    eveningSnack,
    dinner,
    preWorkout,
    postWorkout,
    snack,
    lateSnack,
  ];

  static FoodMealPresentation forStableId(String? rawId) {
    var id = rawId?.trim().toLowerCase();
    if (id == 'snacks') id = 'snack';
    for (final descriptor in allSupported) {
      if (descriptor.stableId == id) return descriptor;
    }
    return unknown;
  }
}

FoodMealPresentation foodMealPresentationFor(String? mealCategory) =>
    MealPresentationRegistry.forStableId(mealCategory);
