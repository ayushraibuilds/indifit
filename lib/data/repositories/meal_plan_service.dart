import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/di/providers.dart';

final mealPlanServiceProvider = Provider<MealPlanService>((ref) {
  final dio = ref.watch(dioProvider);
  return MealPlanService(dio);
});

class GeneratedMealPlanResult {
  final List<Map<String, dynamic>> days;
  final List<String> groceryList;
  final bool isFallback;
  final String? fallbackReason;

  GeneratedMealPlanResult({
    required this.days,
    required this.groceryList,
    required this.isFallback,
    this.fallbackReason,
  });
}

class MealPlanService {
  final Dio _dio;

  MealPlanService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 5),
            ));

  Future<GeneratedMealPlanResult> generateMealPlan({
    required int calorieGoal,
    required String dietPreference,
  }) async {
    try {
      final response = await _dio.post(
        '${AppConfig.backendUrl}/api/ai/meal-plan',
        data: {
          'calorie_goal': calorieGoal,
          'diet_preference': dietPreference,
          'days': 7,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final List<dynamic> daysRaw = data['days'] ?? [];
        final List<dynamic> groceryRaw = data['grocery_list'] ?? [];

        final days = daysRaw.map((d) => Map<String, dynamic>.from(d as Map)).toList();
        final groceryList = groceryRaw.map((g) => g.toString()).toList();
        final bool isFallback = data['is_fallback'] ?? false;

        return GeneratedMealPlanResult(
          days: days,
          groceryList: groceryList,
          isFallback: isFallback,
          fallbackReason: data['fallback_reason'],
        );
      }
    } catch (e) {
      // Log and fall back to local offline structured meal plan
    }

    return _generateOfflineFallback(calorieGoal, dietPreference);
  }

  GeneratedMealPlanResult _generateOfflineFallback(int calorieGoal, String dietPreference) {
    final List<Map<String, dynamic>> days = [
      {
        'day': 'Monday',
        'breakfast': 'Oats Upma (1 bowl) with almonds (10 pcs) - 350 kcal | P: 12g',
        'lunch': 'Paneer Bhurji (150g) with 2 Chapatis & Curd - 550 kcal | P: 28g',
        'dinner': 'Yellow Dal Tadka (1 bowl) with Mixed Veg & 2 Chapatis - 480 kcal | P: 18g',
        'snacks': 'Roasted Chana (50g) & Green Tea - 180 kcal | P: 9g',
      },
      {
        'day': 'Tuesday',
        'breakfast': 'Paneer Stuffed Paratha (1 pc) with curd - 380 kcal | P: 14g',
        'lunch': 'Soya Chunks Curry (1 bowl) with Jeera Rice - 520 kcal | P: 26g',
        'dinner': 'Moong Dal Khichdi (1 plate) with ghee - 440 kcal | P: 12g',
        'snacks': 'Whey Protein Shake with 1 banana - 250 kcal | P: 26g',
      },
      {
        'day': 'Wednesday',
        'breakfast': 'Besan Cheela (2 pcs) with mint chutney - 320 kcal | P: 12g',
        'lunch': 'Chickpea (Chole) Salad with cucumber & tomatoes - 480 kcal | P: 18g',
        'dinner': 'Tofu Stir-fry (150g) with brown rice (1 cup) - 510 kcal | P: 22g',
        'snacks': 'Mixed seeds (1 handful) & Green Tea - 190 kcal | P: 6g',
      },
      {
        'day': 'Thursday',
        'breakfast': 'Sprouted Moong Salad (1 bowl) - 280 kcal | P: 14g',
        'lunch': 'Dal Makhani (1 bowl) with Jeera Rice & Veg Salad - 540 kcal | P: 16g',
        'dinner': 'Paneer Tikka (150g) with Grilled Bell Peppers - 460 kcal | P: 24g',
        'snacks': 'Roasted Makhana (1 bowl) - 150 kcal | P: 3g',
      },
      {
        'day': 'Friday',
        'breakfast': 'Idli (3 pcs) with Sambhar - 310 kcal | P: 8g',
        'lunch': 'Palak Paneer (150g) with 2 Chapatis - 520 kcal | P: 24g',
        'dinner': 'Black Eyed Peas (Lobia) Curry with brown rice - 490 kcal | P: 18g',
        'snacks': 'Boiled Peanut Salad (50g) - 200 kcal | P: 8g',
      },
      {
        'day': 'Saturday',
        'breakfast': 'Oats Porridge with 1 scoop Whey Protein - 360 kcal | P: 30g',
        'lunch': 'Rajma Masala (1 bowl) with Jeera Rice - 540 kcal | P: 18g',
        'dinner': 'Paneer Kathi Roll (1 pc) - 480 kcal | P: 20g',
        'snacks': 'Buttermilk (1 glass) & Roasted Chana - 160 kcal | P: 7g',
      },
      {
        'day': 'Sunday',
        'breakfast': 'Vegetable Poha (1 bowl) with peanuts - 290 kcal | P: 7g',
        'lunch': 'Mix Dal Khichdi (1 plate) with Curd - 480 kcal | P: 16g',
        'dinner': 'Paneer Bhurji (150g) with 2 multigrain rotis - 530 kcal | P: 28g',
        'snacks': 'Fruit Salad (Papaya, Apple) - 120 kcal | P: 1g',
      },
    ];

    final List<String> groceryList = [
      'Rolled Oats (1 kg)',
      'Paneer (500g)',
      'Moong Dal & Toor Dal (1 kg each)',
      'Soya Chunks (200g)',
      'Mixed Vegetables (Onion, Tomato, Spinach, Bell Pepper)',
      'Whole Wheat Atta & Rice',
      'Roasted Chana & Makhana',
      'Almonds & Mixed Seeds',
      'Curd / Yogurt (1 kg)',
      'Fruits (Apples, Papaya, Bananas)',
    ];

    return GeneratedMealPlanResult(
      days: days,
      groceryList: groceryList,
      isFallback: true,
      fallbackReason: 'Local offline plan generated for $calorieGoal kcal ($dietPreference).',
    );
  }
}
