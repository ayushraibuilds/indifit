import 'dart:math' as math;

enum Gender { male, female, other }

enum ActivityLevel {
  sedentary, // 1.2
  lightlyActive, // 1.375
  moderatelyActive, // 1.55
  veryActive, // 1.6
  extraActive, // 1.9
}

enum FitnessGoal {
  weightLoss, // -500 kcal
  maintain, // 0 kcal
  muscleGain, // +300 kcal
}

class MacroTargets {
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final int minCalories;
  final int maxCalories;
  final double minProteinG;
  final double maxProteinG;

  const MacroTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    int? minCalories,
    int? maxCalories,
    double? minProteinG,
    double? maxProteinG,
  })  : minCalories = minCalories ?? calories,
        maxCalories = maxCalories ?? calories,
        minProteinG = minProteinG ?? proteinG,
        maxProteinG = maxProteinG ?? proteinG;

  String get calorieRangeLabel => '$minCalories–$maxCalories kcal';
  String get proteinRangeLabel => '${minProteinG.round()}–${maxProteinG.round()}g';
}

class TdeeCalculator {
  /// Calculates Basal Metabolic Rate (BMR) using Mifflin-St Jeor equation.
  ///
  /// For [Gender.other], uses the mathematical midpoint offset (-78.0 kcal,
  /// between male +5.0 and female -161.0) as an estimated baseline approximation.
  static double calculateBmr({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required Gender gender,
  }) {
    if (weightKg <= 0 || heightCm <= 0 || ageYears <= 0) return 0.0;

    final base = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * ageYears);
    switch (gender) {
      case Gender.male:
        return base + 5.0;
      case Gender.female:
        return base - 161.0;
      case Gender.other:
        return base - 78.0;
    }
  }

  /// Returns activity multiplier.
  static double getActivityMultiplier(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.lightlyActive:
        return 1.375;
      case ActivityLevel.moderatelyActive:
        return 1.55;
      case ActivityLevel.veryActive:
        return 1.6;
      case ActivityLevel.extraActive:
        return 1.9;
    }
  }

  /// Calculates Total Daily Energy Expenditure (TDEE).
  static double calculateTdee({
    required double bmr,
    required ActivityLevel activityLevel,
  }) {
    return bmr * getActivityMultiplier(activityLevel);
  }

  /// Calculates macro distribution based on calorie target and weight.
  static MacroTargets calculateMacros({
    required double tdee,
    required FitnessGoal goal,
    required double weightKg,
  }) {
    int targetCalories = tdee.round();
    int minCalories = targetCalories;
    int maxCalories = targetCalories;

    if (goal == FitnessGoal.weightLoss) {
      targetCalories -= 500;
      minCalories = (tdee - 600).round();
      maxCalories = (tdee - 350).round();
    } else if (goal == FitnessGoal.muscleGain) {
      final surplus = math.min(300, (tdee * 0.15).round());
      targetCalories += surplus;
      minCalories = (tdee + (surplus * 0.5)).round();
      maxCalories = (tdee + surplus).round();
    } else {
      minCalories = targetCalories - 100;
      maxCalories = targetCalories + 100;
    }

    if (targetCalories < 1200) targetCalories = 1200;
    if (minCalories < 1200) minCalories = 1200;
    if (maxCalories < 1200) maxCalories = 1200;

    // Protein: 2.0g per kg for weightLoss/muscleGain, 1.6g for maintain
    final proteinPerKg = goal == FitnessGoal.maintain ? 1.6 : 2.0;
    final proteinG = (weightKg * proteinPerKg).clamp(50.0, 250.0);
    final minProteinG = (weightKg * (goal == FitnessGoal.maintain ? 1.4 : 1.6)).clamp(50.0, 220.0);
    final maxProteinG = (weightKg * (goal == FitnessGoal.maintain ? 1.8 : 2.2)).clamp(60.0, 250.0);

    // Fat: 25% of total calories (9 kcal/g)
    final fatCalFraction = 0.25;
    final fatG = ((targetCalories * fatCalFraction) / 9.0).clamp(30.0, 120.0);

    // Carbs: Remaining calories (4 kcal/g)
    final proteinCal = proteinG * 4.0;
    final fatCal = fatG * 9.0;
    final remainingCal = (targetCalories - proteinCal - fatCal).clamp(
      0.0,
      2000.0,
    );
    final carbsG = remainingCal / 4.0;

    return MacroTargets(
      calories: targetCalories,
      proteinG: double.parse(proteinG.toStringAsFixed(1)),
      carbsG: double.parse(carbsG.toStringAsFixed(1)),
      fatG: double.parse(fatG.toStringAsFixed(1)),
      minCalories: minCalories,
      maxCalories: maxCalories,
      minProteinG: double.parse(minProteinG.toStringAsFixed(1)),
      maxProteinG: double.parse(maxProteinG.toStringAsFixed(1)),
    );
  }
}
