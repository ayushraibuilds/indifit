enum Gender { male, female }

enum ActivityLevel {
  sedentary, // 1.2
  lightlyActive, // 1.375
  moderatelyActive, // 1.55
  veryActive, // 1.725
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

  const MacroTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

class TdeeCalculator {
  /// Calculates Basal Metabolic Rate (BMR) using Mifflin-St Jeor equation.
  static double calculateBmr({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required Gender gender,
  }) {
    if (weightKg <= 0 || heightCm <= 0 || ageYears <= 0) return 0.0;

    final base = (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * ageYears);
    return gender == Gender.male ? base + 5.0 : base - 161.0;
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
        return 1.725;
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
    if (goal == FitnessGoal.weightLoss) {
      targetCalories -= 500;
    } else if (goal == FitnessGoal.muscleGain) {
      targetCalories += 300;
    }

    if (targetCalories < 1200) targetCalories = 1200;

    // Protein: 2.0g per kg for weightLoss/muscleGain, 1.6g for maintain
    final proteinPerKg = goal == FitnessGoal.maintain ? 1.6 : 2.0;
    final proteinG = (weightKg * proteinPerKg).clamp(50.0, 250.0);

    // Fat: 25% of total calories (9 kcal/g)
    final fatG = ((targetCalories * 0.25) / 9.0).clamp(30.0, 120.0);

    // Carbs: Remaining calories (4 kcal/g)
    final proteinCal = proteinG * 4.0;
    final fatCal = fatG * 9.0;
    final remainingCal = (targetCalories - proteinCal - fatCal).clamp(0.0, 2000.0);
    final carbsG = remainingCal / 4.0;

    return MacroTargets(
      calories: targetCalories,
      proteinG: double.parse(proteinG.toStringAsFixed(1)),
      carbsG: double.parse(carbsG.toStringAsFixed(1)),
      fatG: double.parse(fatG.toStringAsFixed(1)),
    );
  }
}
