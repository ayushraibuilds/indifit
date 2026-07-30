import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/di/providers.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/utils/app_logger.dart';

final mealPlanServiceProvider = Provider<MealPlanService>((ref) {
  final dio = ref.watch(dioProvider);
  final policy = ref.watch(privacyPolicyProvider);
  return MealPlanService(dio, policy);
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
  final PrivacyPolicy? _policy;

  MealPlanService([Dio? dio, PrivacyPolicy? policy])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 5),
            ),
          ),
      _policy = policy;

  Future<GeneratedMealPlanResult> generateMealPlan({
    required int calorieGoal,
    required String dietPreference,
  }) async {
    final normalizedDiet = _normalizeDiet(dietPreference);

    if (_policy != null && !_policy.isAiAllowed) {
      return _generateOfflineFallback(calorieGoal, normalizedDiet);
    }

    try {
      final response = await _dio.post(
        '${AppConfig.backendUrl}/api/ai/meal-plan',
        data: {
          'calorie_goal': calorieGoal,
          'diet_preference': normalizedDiet,
          'days': 7,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final List<dynamic> daysRaw = data['days'] ?? [];
        final List<dynamic> groceryRaw = data['grocery_list'] ?? [];

        final days = daysRaw
            .map((d) => Map<String, dynamic>.from(d as Map))
            .toList();
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
      AppLogger.warning(
        'MealPlanService AI generation failed, using fallback: $e',
      );
    }

    return _generateOfflineFallback(calorieGoal, normalizedDiet);
  }

  String _normalizeDiet(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('vegan')) return 'vegan';
    if (lower.contains('non') ||
        lower.contains('meat') ||
        lower.contains('egg')) {
      return 'non_veg';
    }
    return 'veg';
  }

  Future<GeneratedMealPlanResult> _generateOfflineFallback(
    int calorieGoal,
    String diet,
  ) async {
    Map<String, dynamic>? planData;

    try {
      final assetPath = 'assets/data/meal_plans/$diet.json';
      final jsonStr = await rootBundle.loadString(assetPath);
      planData = json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      // Fallback to built-in structured templates if rootBundle is unavailable
      planData = _getBuiltInTemplate(diet);
    }

    final double ratio = (calorieGoal / 2000.0).clamp(0.5, 5.0);
    final List<dynamic> rawDays = planData['days'] ?? [];
    final List<dynamic> rawGrocery = planData['grocery_list'] ?? [];

    final List<Map<String, dynamic>> scaledDays = rawDays.map((d) {
      final dayMap = d as Map<String, dynamic>;
      final dayName = dayMap['day'] as String;

      String formatMeal(Map<String, dynamic>? meal) {
        if (meal == null) return 'Balanced portion';
        final title = meal['title'] ?? 'Meal';
        final baseKcal = (meal['base_kcal'] as num?)?.toDouble() ?? 400.0;
        final baseProtein =
            (meal['base_protein_g'] as num?)?.toDouble() ?? 15.0;

        final scaledKcal = (baseKcal * ratio).round();
        final scaledProtein = (baseProtein * ratio).round();

        return '$title - $scaledKcal kcal | P: ${scaledProtein}g';
      }

      return {
        'day': dayName,
        'breakfast': formatMeal(dayMap['breakfast'] as Map<String, dynamic>?),
        'lunch': formatMeal(dayMap['lunch'] as Map<String, dynamic>?),
        'dinner': formatMeal(dayMap['dinner'] as Map<String, dynamic>?),
        'snacks': formatMeal(dayMap['snacks'] as Map<String, dynamic>?),
      };
    }).toList();

    final List<String> groceryList = rawGrocery
        .map((g) => g.toString())
        .toList();

    final dietName = switch (diet) {
      'vegan' => 'Vegan (Plant-based)',
      'non_veg' => 'Non-Vegetarian',
      _ => 'Vegetarian',
    };

    return GeneratedMealPlanResult(
      days: scaledDays,
      groceryList: groceryList,
      isFallback: true,
      fallbackReason:
          'Local offline plan generated for $calorieGoal kcal ($dietName).',
    );
  }

  Map<String, dynamic> _getBuiltInTemplate(String diet) {
    if (diet == 'vegan') {
      return {
        'days': [
          {
            'day': 'Monday',
            'breakfast': {
              'title': 'Moong Dal Cheela with Almonds',
              'base_kcal': 340,
              'base_protein_g': 14,
            },
            'lunch': {
              'title': 'Tofu Scramble (Bhurji) with 2 Rotis',
              'base_kcal': 530,
              'base_protein_g': 26,
            },
            'dinner': {
              'title': 'Yellow Dal Tadka with Steamed Rice',
              'base_kcal': 490,
              'base_protein_g': 18,
            },
            'snacks': {
              'title': 'Roasted Chana (50g) & Green Tea',
              'base_kcal': 180,
              'base_protein_g': 9,
            },
          },
          {
            'day': 'Tuesday',
            'breakfast': {
              'title': 'Oats Upma with Peanuts',
              'base_kcal': 350,
              'base_protein_g': 11,
            },
            'lunch': {
              'title': 'Soya Chunks Curry with Brown Rice',
              'base_kcal': 520,
              'base_protein_g': 28,
            },
            'dinner': {
              'title': 'Moong Dal Khichdi with Olive Oil',
              'base_kcal': 450,
              'base_protein_g': 14,
            },
            'snacks': {
              'title': 'Plant Protein Smoothie & Soy Milk',
              'base_kcal': 220,
              'base_protein_g': 20,
            },
          },
          {
            'day': 'Wednesday',
            'breakfast': {
              'title': 'Besan Cheela (2 pcs) with Chutney',
              'base_kcal': 320,
              'base_protein_g': 12,
            },
            'lunch': {
              'title': 'Chickpea (Chole) Salad with Cucumber',
              'base_kcal': 480,
              'base_protein_g': 18,
            },
            'dinner': {
              'title': 'Tofu Stir-fry with Peppers & Rice',
              'base_kcal': 510,
              'base_protein_g': 24,
            },
            'snacks': {
              'title': 'Mixed Seeds & Walnuts',
              'base_kcal': 180,
              'base_protein_g': 7,
            },
          },
          {
            'day': 'Thursday',
            'breakfast': {
              'title': 'Sprouted Moong & Chana Salad',
              'base_kcal': 290,
              'base_protein_g': 15,
            },
            'lunch': {
              'title': 'Black Lentil Curry with 2 Rotis',
              'base_kcal': 520,
              'base_protein_g': 17,
            },
            'dinner': {
              'title': 'Grilled Tofu Tikka with Rice',
              'base_kcal': 500,
              'base_protein_g': 23,
            },
            'snacks': {
              'title': 'Roasted Makhana',
              'base_kcal': 150,
              'base_protein_g': 4,
            },
          },
          {
            'day': 'Friday',
            'breakfast': {
              'title': 'Peanut Butter Toast (2 slices)',
              'base_kcal': 330,
              'base_protein_g': 12,
            },
            'lunch': {
              'title': 'Soya Keema Curry with 2 Rotis',
              'base_kcal': 530,
              'base_protein_g': 27,
            },
            'dinner': {
              'title': 'Lobia Curry with Steamed Rice',
              'base_kcal': 490,
              'base_protein_g': 18,
            },
            'snacks': {
              'title': 'Boiled Peanut Salad',
              'base_kcal': 200,
              'base_protein_g': 8,
            },
          },
          {
            'day': 'Saturday',
            'breakfast': {
              'title': 'Oats Porridge with Soy Milk',
              'base_kcal': 350,
              'base_protein_g': 12,
            },
            'lunch': {
              'title': 'Rajma Masala with Jeera Rice',
              'base_kcal': 540,
              'base_protein_g': 18,
            },
            'dinner': {
              'title': 'Tofu Wrap in Wheat Bread',
              'base_kcal': 470,
              'base_protein_g': 21,
            },
            'snacks': {
              'title': 'Soy Milk Shake',
              'base_kcal': 160,
              'base_protein_g': 8,
            },
          },
          {
            'day': 'Sunday',
            'breakfast': {
              'title': 'Vegetable Poha with Peanuts',
              'base_kcal': 290,
              'base_protein_g': 7,
            },
            'lunch': {
              'title': 'Mixed Lentil Khichdi',
              'base_kcal': 470,
              'base_protein_g': 16,
            },
            'dinner': {
              'title': 'Tofu Bhurji with 2 Rotis',
              'base_kcal': 520,
              'base_protein_g': 26,
            },
            'snacks': {
              'title': 'Fruit Salad Bowl',
              'base_kcal': 130,
              'base_protein_g': 2,
            },
          },
        ],
        'grocery_list': [
          'Rolled Oats & Chia Seeds',
          'Firm Tofu (750g)',
          'Moong Dal, Rajma & Kala Chana',
          'Soya Chunks (300g)',
          'Soy Milk',
          'Peanut Butter',
          'Mixed Vegetables',
          'Whole Wheat Atta & Brown Rice',
          'Roasted Chana & Makhana',
          'Seasonal Fruits',
        ],
      };
    }

    if (diet == 'non_veg') {
      return {
        'days': [
          {
            'day': 'Monday',
            'breakfast': {
              'title': '3 Egg Omelette with Wheat Toast',
              'base_kcal': 360,
              'base_protein_g': 22,
            },
            'lunch': {
              'title': 'Grilled Chicken Breast with Rice',
              'base_kcal': 540,
              'base_protein_g': 38,
            },
            'dinner': {
              'title': 'Yellow Dal with 2 Rotis',
              'base_kcal': 460,
              'base_protein_g': 18,
            },
            'snacks': {
              'title': 'Boiled Eggs (2 pcs)',
              'base_kcal': 150,
              'base_protein_g': 13,
            },
          },
          {
            'day': 'Tuesday',
            'breakfast': {
              'title': 'Oats Porridge with Whey Protein',
              'base_kcal': 360,
              'base_protein_g': 28,
            },
            'lunch': {
              'title': 'Chicken Curry with 2 Wheat Rotis',
              'base_kcal': 530,
              'base_protein_g': 35,
            },
            'dinner': {
              'title': 'Egg Bhurji (3 eggs) with 2 Rotis',
              'base_kcal': 480,
              'base_protein_g': 24,
            },
            'snacks': {
              'title': 'Greek Yogurt',
              'base_kcal': 180,
              'base_protein_g': 14,
            },
          },
          {
            'day': 'Wednesday',
            'breakfast': {
              'title': 'Egg White Scramble with Toast',
              'base_kcal': 310,
              'base_protein_g': 24,
            },
            'lunch': {
              'title': 'Fish Curry with Steamed Rice',
              'base_kcal': 510,
              'base_protein_g': 32,
            },
            'dinner': {
              'title': 'Grilled Chicken with Stir-fry Veggies',
              'base_kcal': 490,
              'base_protein_g': 38,
            },
            'snacks': {
              'title': 'Roasted Chana',
              'base_kcal': 170,
              'base_protein_g': 9,
            },
          },
          {
            'day': 'Thursday',
            'breakfast': {
              'title': 'Chicken Sausage & Boiled Egg',
              'base_kcal': 350,
              'base_protein_g': 24,
            },
            'lunch': {
              'title': 'Chicken Keema Curry with 2 Rotis',
              'base_kcal': 550,
              'base_protein_g': 36,
            },
            'dinner': {
              'title': 'Moong Dal with Brown Rice',
              'base_kcal': 470,
              'base_protein_g': 18,
            },
            'snacks': {
              'title': 'Roasted Makhana',
              'base_kcal': 160,
              'base_protein_g': 5,
            },
          },
          {
            'day': 'Friday',
            'breakfast': {
              'title': '3 Egg Omelette with Mushrooms',
              'base_kcal': 340,
              'base_protein_g': 22,
            },
            'lunch': {
              'title': 'Chicken Tikka with Mint Chutney',
              'base_kcal': 520,
              'base_protein_g': 38,
            },
            'dinner': {
              'title': 'Egg Curry (2 Eggs) with Rice',
              'base_kcal': 490,
              'base_protein_g': 20,
            },
            'snacks': {
              'title': 'Whey Protein Shake',
              'base_kcal': 150,
              'base_protein_g': 24,
            },
          },
          {
            'day': 'Saturday',
            'breakfast': {
              'title': 'Oats Upma with Egg White',
              'base_kcal': 330,
              'base_protein_g': 16,
            },
            'lunch': {
              'title': 'Chicken Biryani with Raita',
              'base_kcal': 560,
              'base_protein_g': 34,
            },
            'dinner': {
              'title': 'Grilled Fish Fillet with Asparagus',
              'base_kcal': 470,
              'base_protein_g': 33,
            },
            'snacks': {
              'title': 'Spiced Buttermilk',
              'base_kcal': 160,
              'base_protein_g': 8,
            },
          },
          {
            'day': 'Sunday',
            'breakfast': {
              'title': 'Egg & Cheese Wrap',
              'base_kcal': 380,
              'base_protein_g': 20,
            },
            'lunch': {
              'title': 'Home-style Mutton Curry with 2 Rotis',
              'base_kcal': 570,
              'base_protein_g': 32,
            },
            'dinner': {
              'title': 'Yellow Dal with Steamed Rice',
              'base_kcal': 450,
              'base_protein_g': 16,
            },
            'snacks': {
              'title': 'Fresh Fruit Bowl',
              'base_kcal': 130,
              'base_protein_g': 2,
            },
          },
        ],
        'grocery_list': [
          'Fresh Eggs (2 Dozen)',
          'Chicken Breast & Fish Fillet (1.5 kg)',
          'Whole Wheat Atta & Rice',
          'Rolled Oats & Whey Protein',
          'Greek Yogurt',
          'Toor Dal & Moong Dal',
          'Mixed Vegetables',
          'Roasted Chana & Makhana',
          'Almonds & Mixed Seeds',
          'Seasonal Fruits',
        ],
      };
    }

    // Default Veg
    return {
      'days': [
        {
          'day': 'Monday',
          'breakfast': {
            'title': 'Oats Upma with Almonds',
            'base_kcal': 350,
            'base_protein_g': 12,
          },
          'lunch': {
            'title': 'Paneer Bhurji with 2 Rotis',
            'base_kcal': 550,
            'base_protein_g': 28,
          },
          'dinner': {
            'title': 'Yellow Dal Tadka with 2 Rotis',
            'base_kcal': 480,
            'base_protein_g': 18,
          },
          'snacks': {
            'title': 'Roasted Chana',
            'base_kcal': 180,
            'base_protein_g': 9,
          },
        },
        {
          'day': 'Tuesday',
          'breakfast': {
            'title': 'Paneer Paratha with Curd',
            'base_kcal': 380,
            'base_protein_g': 14,
          },
          'lunch': {
            'title': 'Soya Chunks Curry with Rice',
            'base_kcal': 520,
            'base_protein_g': 26,
          },
          'dinner': {
            'title': 'Moong Dal Khichdi',
            'base_kcal': 440,
            'base_protein_g': 12,
          },
          'snacks': {
            'title': 'Greek Yogurt & Seeds',
            'base_kcal': 200,
            'base_protein_g': 15,
          },
        },
        {
          'day': 'Wednesday',
          'breakfast': {
            'title': 'Besan Cheela (2 pcs)',
            'base_kcal': 320,
            'base_protein_g': 12,
          },
          'lunch': {
            'title': 'Chole Salad',
            'base_kcal': 480,
            'base_protein_g': 18,
          },
          'dinner': {
            'title': 'Paneer Tikka with Rice',
            'base_kcal': 510,
            'base_protein_g': 25,
          },
          'snacks': {
            'title': 'Roasted Makhana',
            'base_kcal': 170,
            'base_protein_g': 6,
          },
        },
        {
          'day': 'Thursday',
          'breakfast': {
            'title': 'Sprouted Moong Salad',
            'base_kcal': 280,
            'base_protein_g': 14,
          },
          'lunch': {
            'title': 'Dal Makhani with Rice',
            'base_kcal': 540,
            'base_protein_g': 16,
          },
          'dinner': {
            'title': 'Matar Paneer with 2 Rotis',
            'base_kcal': 500,
            'base_protein_g': 22,
          },
          'snacks': {
            'title': 'Buttermilk & Chana',
            'base_kcal': 160,
            'base_protein_g': 8,
          },
        },
        {
          'day': 'Friday',
          'breakfast': {
            'title': 'Idli (3 pcs) with Sambhar',
            'base_kcal': 310,
            'base_protein_g': 9,
          },
          'lunch': {
            'title': 'Palak Paneer with 2 Rotis',
            'base_kcal': 520,
            'base_protein_g': 24,
          },
          'dinner': {
            'title': 'Lobia Curry with Rice',
            'base_kcal': 490,
            'base_protein_g': 18,
          },
          'snacks': {
            'title': 'Boiled Peanut Salad',
            'base_kcal': 200,
            'base_protein_g': 8,
          },
        },
        {
          'day': 'Saturday',
          'breakfast': {
            'title': 'Oats Porridge with Nuts',
            'base_kcal': 340,
            'base_protein_g': 11,
          },
          'lunch': {
            'title': 'Rajma Masala with Rice',
            'base_kcal': 540,
            'base_protein_g': 18,
          },
          'dinner': {
            'title': 'Paneer Kathi Roll',
            'base_kcal': 480,
            'base_protein_g': 20,
          },
          'snacks': {
            'title': 'Curd Bowl',
            'base_kcal': 170,
            'base_protein_g': 10,
          },
        },
        {
          'day': 'Sunday',
          'breakfast': {
            'title': 'Vegetable Poha',
            'base_kcal': 290,
            'base_protein_g': 7,
          },
          'lunch': {
            'title': 'Mixed Dal Khichdi',
            'base_kcal': 480,
            'base_protein_g': 16,
          },
          'dinner': {
            'title': 'Paneer Bhurji with 2 Rotis',
            'base_kcal': 530,
            'base_protein_g': 28,
          },
          'snacks': {
            'title': 'Fruit Salad',
            'base_kcal': 130,
            'base_protein_g': 2,
          },
        },
      ],
      'grocery_list': [
        'Rolled Oats',
        'Paneer (500g)',
        'Moong Dal & Rajma',
        'Soya Chunks',
        'Fresh Curd',
        'Mixed Vegetables',
        'Atta & Rice',
        'Chana & Makhana',
        'Almonds & Seeds',
        'Fruits',
      ],
    };
  }
}
