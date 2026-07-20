import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/repositories/meal_plan_service.dart';

void main() {
  group('MealPlanService Unit Tests', () {
    test('offline fallback returns 7 days of meals and grocery list', () async {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(milliseconds: 50)));
      final service = MealPlanService(dio);
      final result = await service.generateMealPlan(calorieGoal: 2200, dietPreference: 'veg');

      expect(result.isFallback, true);
      expect(result.days.length, 7);
      expect(result.groceryList, isNotEmpty);
      expect(result.days.first['day'], 'Monday');
      expect(result.days.first['breakfast'], contains('Oats Upma'));
    });

    test('GeneratedMealPlanResult fields are properly assigned', () {
      final result = GeneratedMealPlanResult(
        days: [
          {'day': 'Monday', 'breakfast': 'Idli'}
        ],
        groceryList: ['Rice', 'Dal'],
        isFallback: false,
      );

      expect(result.isFallback, false);
      expect(result.days.length, 1);
      expect(result.groceryList, ['Rice', 'Dal']);
    });
  });
}
