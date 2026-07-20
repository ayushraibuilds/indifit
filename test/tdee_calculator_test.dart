import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/utils/tdee_calculator.dart';

void main() {
  group('TdeeCalculator Engine Tests', () {
    test('calculates male BMR accurately via Mifflin-St Jeor equation', () {
      // Male: 75kg, 175cm, 25 years
      // 10*75 + 6.25*175 - 5*25 + 5 = 750 + 1093.75 - 125 + 5 = 1723.75 kcal
      final bmr = TdeeCalculator.calculateBmr(
        weightKg: 75.0,
        heightCm: 175.0,
        ageYears: 25,
        gender: Gender.male,
      );

      expect(bmr, equals(1723.75));
    });

    test('calculates female BMR accurately via Mifflin-St Jeor equation', () {
      // Female: 60kg, 165cm, 30 years
      // 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25 kcal
      final bmr = TdeeCalculator.calculateBmr(
        weightKg: 60.0,
        heightCm: 165.0,
        ageYears: 30,
        gender: Gender.female,
      );

      expect(bmr, equals(1320.25));
    });

    test('calculates TDEE with activity multipliers correctly', () {
      final bmr = 1700.0;
      final tdeeSedentary = TdeeCalculator.calculateTdee(bmr: bmr, activityLevel: ActivityLevel.sedentary);
      final tdeeModerate = TdeeCalculator.calculateTdee(bmr: bmr, activityLevel: ActivityLevel.moderatelyActive);

      expect(tdeeSedentary, equals(2040.0)); // 1700 * 1.2
      expect(tdeeModerate, equals(2635.0)); // 1700 * 1.55
    });

    test('calculates macro splits for weight loss goal', () {
      final tdee = 2500.0;
      final weightKg = 80.0;
      final macros = TdeeCalculator.calculateMacros(
        tdee: tdee,
        goal: FitnessGoal.weightLoss,
        weightKg: weightKg,
      );

      // Target calories: 2500 - 500 = 2000 kcal
      expect(macros.calories, equals(2000));
      // Protein: 80 * 2.0 = 160g
      expect(macros.proteinG, equals(160.0));
      // Fat: 2000 * 0.25 / 9 = 55.6g
      expect(macros.fatG, equals(55.6));
    });
  });
}
