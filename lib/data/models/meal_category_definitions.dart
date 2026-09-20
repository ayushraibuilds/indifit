/// Stable meal-category IDs used by B03 food logs and repositories.
/// Pure domain definitions without Flutter UI dependencies.
library;

enum FoodMealCategory {
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
  unknown;

  String get stableId => switch (this) {
    FoodMealCategory.breakfast => 'breakfast',
    FoodMealCategory.morningSnack => 'morning_snack',
    FoodMealCategory.lunch => 'lunch',
    FoodMealCategory.afternoonSnack => 'afternoon_snack',
    FoodMealCategory.eveningSnack => 'evening_snack',
    FoodMealCategory.dinner => 'dinner',
    FoodMealCategory.preWorkout => 'pre_workout',
    FoodMealCategory.postWorkout => 'post_workout',
    FoodMealCategory.snack => 'snack',
    FoodMealCategory.lateSnack => 'late_snack',
    FoodMealCategory.unknown => 'unknown',
  };

  static const Set<String> supportedStableIds = {
    'breakfast',
    'morning_snack',
    'lunch',
    'afternoon_snack',
    'evening_snack',
    'dinner',
    'pre_workout',
    'post_workout',
    'snack',
    'late_snack',
  };
}
