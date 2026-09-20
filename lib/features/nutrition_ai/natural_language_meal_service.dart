import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';

/// Single item parsed from a natural-language meal description.
class DecomposedFoodItem {
  final String rawSegment;
  final String foodName;
  final double quantityAmount;
  final String quantityUnit;
  final int estimatedCalories;
  final double estimatedProtein;
  final double estimatedCarbs;
  final double estimatedFat;
  final String confidence;
  final NutritionFoodOption? matchedCatalogOption;

  const DecomposedFoodItem({
    required this.rawSegment,
    required this.foodName,
    required this.quantityAmount,
    required this.quantityUnit,
    required this.estimatedCalories,
    required this.estimatedProtein,
    required this.estimatedCarbs,
    required this.estimatedFat,
    this.confidence = 'medium',
    this.matchedCatalogOption,
  });

  bool get isCatalogVerified => matchedCatalogOption != null;

  DecomposedFoodItem copyWith({
    String? rawSegment,
    String? foodName,
    double? quantityAmount,
    String? quantityUnit,
    int? estimatedCalories,
    double? estimatedProtein,
    double? estimatedCarbs,
    double? estimatedFat,
    String? confidence,
    NutritionFoodOption? matchedCatalogOption,
    bool clearCatalogOption = false,
  }) {
    return DecomposedFoodItem(
      rawSegment: rawSegment ?? this.rawSegment,
      foodName: foodName ?? this.foodName,
      quantityAmount: quantityAmount ?? this.quantityAmount,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      estimatedProtein: estimatedProtein ?? this.estimatedProtein,
      estimatedCarbs: estimatedCarbs ?? this.estimatedCarbs,
      estimatedFat: estimatedFat ?? this.estimatedFat,
      confidence: confidence ?? this.confidence,
      matchedCatalogOption: clearCatalogOption
          ? null
          : (matchedCatalogOption ?? this.matchedCatalogOption),
    );
  }

  factory DecomposedFoodItem.fromJson(
    Map<String, dynamic> json, {
    NutritionFoodOption? catalogOption,
  }) {
    return DecomposedFoodItem(
      rawSegment: (json['raw_segment'] as String?) ?? '',
      foodName: (json['food_name'] as String?) ?? '',
      quantityAmount: (json['quantity_amount'] as num?)?.toDouble() ?? 1.0,
      quantityUnit: (json['quantity_unit'] as String?) ?? 'serving',
      estimatedCalories: (json['estimated_calories'] as num?)?.toInt() ?? 0,
      estimatedProtein:
          (json['estimated_protein'] as num?)?.toDouble() ?? 0.0,
      estimatedCarbs: (json['estimated_carbs'] as num?)?.toDouble() ?? 0.0,
      estimatedFat: (json['estimated_fat'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as String?) ?? 'medium',
      matchedCatalogOption: catalogOption,
    );
  }
}

/// Overall response from natural-language meal decomposition.
class MealDecompositionResult {
  final String query;
  final List<DecomposedFoodItem> items;
  final int totalCalories;
  final bool isFallback;
  final String? fallbackReason;

  const MealDecompositionResult({
    required this.query,
    required this.items,
    required this.totalCalories,
    this.isFallback = false,
    this.fallbackReason,
  });

  double get totalProtein =>
      items.fold(0.0, (sum, item) => sum + item.estimatedProtein);
  double get totalCarbs =>
      items.fold(0.0, (sum, item) => sum + item.estimatedCarbs);
  double get totalFat =>
      items.fold(0.0, (sum, item) => sum + item.estimatedFat);
}

/// Service that queries the backend meal decomposition endpoint and
/// cross-references candidates with the curated food catalog repository.
class NaturalLanguageMealService {
  final Dio _dio;
  final NutritionFoodCatalogRepository _catalog;
  final PrivacyPolicy Function() _policy;
  final String _baseUrl;

  NaturalLanguageMealService({
    required Dio dio,
    required NutritionFoodCatalogRepository catalog,
    required PrivacyPolicy Function() policy,
    String? baseUrl,
  })  : _dio = dio,
        _catalog = catalog,
        _policy = policy,
        _baseUrl = baseUrl ?? AppConfig.backendUrl;

  Future<MealDecompositionResult> decomposeMeal({
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw ArgumentError('Meal text cannot be empty.');
    }

    final policy = _policy();
    if (!policy.isAiAllowed) {
      throw StateError(
        'Connected AI assistance is disabled under your current privacy settings.',
      );
    }

    final url = '$_baseUrl/api/ai/meal-decompose';
    final response = await _dio.post(
      url,
      data: {'text': cleanText},
    );

    if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
      throw StateError('Failed to parse meal description from service.');
    }

    final data = response.data as Map<String, dynamic>;
    final rawItems = (data['items'] as List<dynamic>?) ?? [];
    final totalCalories = (data['total_calories'] as num?)?.toInt() ?? 0;
    final isFallback = (data['is_fallback'] as bool?) ?? false;
    final fallbackReason = data['fallback_reason'] as String?;

    // Cross-reference each parsed item with the curated catalog
    final resolvedItems = <DecomposedFoodItem>[];
    for (final raw in rawItems) {
      if (raw is Map<String, dynamic>) {
        final foodName = (raw['food_name'] as String?) ?? '';
        NutritionFoodOption? catalogMatch;
        if (foodName.isNotEmpty) {
          try {
            final candidates = await _catalog.search(query: foodName);
            if (candidates.isNotEmpty) {
              // Exact match preferred, otherwise first candidate
              catalogMatch = candidates.firstWhere(
                (c) => c.displayName.toLowerCase() == foodName.toLowerCase(),
                orElse: () => candidates.first,
              );
            }
          } catch (_) {
            // Non-fatal if local catalog search fails; fallback to estimate
          }
        }
        resolvedItems.add(
          DecomposedFoodItem.fromJson(raw, catalogOption: catalogMatch),
        );
      }
    }

    return MealDecompositionResult(
      query: cleanText,
      items: resolvedItems,
      totalCalories: totalCalories,
      isFallback: isFallback,
      fallbackReason: fallbackReason,
    );
  }
}
