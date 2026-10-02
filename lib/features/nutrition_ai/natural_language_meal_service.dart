import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/utils/app_logger.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import 'meal_item_resolver.dart';

/// Typed domain exceptions for AI meal parsing failures.
sealed class MealAiException implements Exception {
  final String message;
  const MealAiException(this.message);

  @override
  String toString() => message;
}

class MealAiOfflineException extends MealAiException {
  const MealAiOfflineException([
    super.message =
        'Unable to connect to AI meal parser. Check your internet connection or use food search.',
  ]);
}

class MealAiUnavailableException extends MealAiException {
  const MealAiUnavailableException([
    super.message =
        'Kitchen AI is currently unavailable. Your description is saved—please try again shortly.',
  ]);
}

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

  /// Plausible catalogue foods when no single match was clear. The user must
  /// pick one (or swap to another) before the item can be logged.
  final List<NutritionFoodOption> catalogChoices;

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
    this.catalogChoices = const [],
  });

  bool get isCatalogVerified => matchedCatalogOption != null;

  bool get needsCatalogChoice =>
      matchedCatalogOption == null && catalogChoices.isNotEmpty;

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
    List<NutritionFoodOption>? catalogChoices,
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
      catalogChoices: catalogChoices ?? this.catalogChoices,
    );
  }

  factory DecomposedFoodItem.fromJson(
    Map<String, dynamic> json, {
    NutritionFoodOption? catalogOption,
    List<NutritionFoodOption> catalogChoices = const [],
  }) {
    return DecomposedFoodItem(
      rawSegment: (json['raw_segment'] as String?) ?? '',
      foodName: (json['food_name'] as String?) ?? '',
      quantityAmount: (json['quantity_amount'] as num?)?.toDouble() ?? 1.0,
      quantityUnit: (json['quantity_unit'] as String?) ?? 'serving',
      estimatedCalories: (json['estimated_calories'] as num?)?.toInt() ?? 0,
      estimatedProtein: (json['estimated_protein'] as num?)?.toDouble() ?? 0.0,
      estimatedCarbs: (json['estimated_carbs'] as num?)?.toDouble() ?? 0.0,
      estimatedFat: (json['estimated_fat'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as String?) ?? 'medium',
      matchedCatalogOption: catalogOption,
      catalogChoices: catalogChoices,
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
  }) : _dio = dio,
       _catalog = catalog,
       _policy = policy,
       _baseUrl = baseUrl ?? AppConfig.backendUrl;

  Future<MealDecompositionResult> decomposeMeal({required String text}) async {
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
    final Response<dynamic> response;
    try {
      response = await _dio.post(url, data: {'text': cleanText});
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const MealAiOfflineException();
      }
      throw const MealAiUnavailableException();
    }

    if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
      throw const MealAiUnavailableException();
    }

    final data = response.data as Map<String, dynamic>;
    final rawItems = (data['items'] as List<dynamic>?) ?? [];
    final totalCalories = (data['total_calories'] as num?)?.toInt() ?? 0;
    final isFallback = (data['is_fallback'] as bool?) ?? false;
    final fallbackReason = data['fallback_reason'] as String?;

    final resolvedItems = await _resolveAgainstCatalog(rawItems);

    return MealDecompositionResult(
      query: cleanText,
      items: resolvedItems,
      totalCalories: totalCalories,
      isFallback: isFallback,
      fallbackReason: fallbackReason,
    );
  }

  Future<MealDecompositionResult> decomposePhotoMeal({
    required String imagePath,
    required String deviceUuid,
  }) async {
    final policy = _policy();
    if (!policy.isAiAllowed || !policy.isImageUploadAllowed) {
      throw StateError(
        'Connected AI or photo assistance is disabled under your current privacy settings.',
      );
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw ArgumentError('The selected image file does not exist.');
    }

    final bytes = await file.readAsBytes();
    final filename = imagePath.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final url = '$_baseUrl/api/ai/meal-estimate-photo-v2';
    final response = await _dio.post(
      url,
      data: formData,
      options: Options(headers: {'x-device-uuid': deviceUuid}),
    );

    if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
      throw StateError('Failed to parse photo meal estimate from service.');
    }

    final data = response.data as Map<String, dynamic>;
    final rawItems = (data['items'] as List<dynamic>?) ?? [];
    final totalCalories = (data['total_calories'] as num?)?.toInt() ?? 0;
    final isFallback = (data['is_fallback'] as bool?) ?? false;
    final fallbackReason = data['fallback_reason'] as String?;

    final resolvedItems = await _resolveAgainstCatalog(rawItems);

    return MealDecompositionResult(
      query: 'Photo Upload',
      items: resolvedItems,
      totalCalories: totalCalories,
      isFallback: isFallback,
      fallbackReason: fallbackReason,
    );
  }

  /// Matches each parsed item against the curated catalogue. A clear match
  /// supplies the nutrition; a close call is left for the user to choose;
  /// anything else stays an AI estimate. Catalogue failures degrade to an
  /// estimate rather than failing the whole parse.
  Future<List<DecomposedFoodItem>> _resolveAgainstCatalog(
    List<dynamic> rawItems,
  ) async {
    final resolver = MealItemResolver(
      search: (query) => _catalog.search(query: query),
    );
    final items = <DecomposedFoodItem>[];
    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) continue;
      final foodName = (raw['food_name'] as String?) ?? '';
      var match = const CatalogMatch.unmatched();
      if (foodName.isNotEmpty) {
        try {
          match = await resolver.resolve(foodName);
        } on Object catch (error, stackTrace) {
          AppLogger.error(
            'Catalogue match failed for AI item',
            error,
            stackTrace,
          );
        }
      }
      items.add(
        DecomposedFoodItem.fromJson(
          raw,
          catalogOption: match.option,
          catalogChoices: match.choices,
        ),
      );
    }
    return items;
  }
}
