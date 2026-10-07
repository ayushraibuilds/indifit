import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/ai/ai_gateway.dart';
import '../../core/ai/ai_photo_sanitizer.dart';
import '../../core/ai/backend_ai_gateway.dart';
import '../../core/config/app_config.dart';
import '../../core/nutrients.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/typed_quantities.dart';
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
        'The AI meal tool is unavailable right now. Your description is saved, so try again shortly.',
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

  /// Set when the AI's unit couldn't be converted to the matched food's
  /// measure: the amount was reset to one serving and the user should check
  /// it.
  final String? portionNote;

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
    this.portionNote,
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
    String? portionNote,
    bool clearPortionNote = false,
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
      portionNote: clearPortionNote ? null : (portionNote ?? this.portionNote),
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

/// Binds [item] to the catalogue food [option]: the amount becomes a count of
/// the food's own measure and the nutrition comes from the catalogue, so the
/// review card shows exactly what [catalogLogQuantity] will log. A unit that
/// doesn't convert resets the amount to one serving with a [portionNote].
DecomposedFoodItem bindToCatalog(
  DecomposedFoodItem item,
  NutritionFoodOption option,
) {
  final portion = PortionMapping.map(
    amount: item.quantityAmount,
    unit: item.quantityUnit,
    option: option,
  );
  // The mapped amount already counts the food's own measure; it differs
  // from the AI's number when pieces convert to servings ("4 eggs" is 2
  // servings of "Boiled Eggs (2 pieces)"), and then the unit says so too.
  final quantity = portion.quantity;
  final amount = quantity.amount.asDouble;
  final converted = !portion.needsReview && amount != item.quantityAmount;
  final unit = portion.needsReview || converted
      ? _measureWord(option)
      : item.quantityUnit;
  // A nutrient the catalogue lacks keeps the AI's figure rather than
  // silently becoming zero.
  final kcal = _scaledFact(option, 'energy', quantity);
  return item.copyWith(
    matchedCatalogOption: option,
    quantityAmount: amount,
    quantityUnit: unit,
    estimatedCalories: kcal?.round() ?? item.estimatedCalories,
    estimatedProtein:
        _scaledFact(option, 'protein', quantity) ?? item.estimatedProtein,
    estimatedCarbs:
        _scaledFact(option, 'carbohydrate', quantity) ?? item.estimatedCarbs,
    estimatedFat: _scaledFact(option, 'fat', quantity) ?? item.estimatedFat,
    portionNote: portion.reviewReason,
    clearPortionNote: !portion.needsReview,
  );
}

/// The quantity to log for an item bound with [bindToCatalog]: its amount is
/// already a count of the food's base measure.
Quantity catalogLogQuantity(DecomposedFoodItem item) {
  final base = item.matchedCatalogOption!.baseQuantity;
  return Quantity.fromNum(
    amount: item.quantityAmount,
    unit: base.unit,
    context: base.context,
  );
}

String _measureWord(NutritionFoodOption option) {
  // The catalogue's own unit when one serving is one of it ("katori").
  final measure = option.measure;
  if (option.baseQuantity.unit == QuantityUnit.serving &&
      measure?.unit != null &&
      measure?.unitsPerServing?.asDouble == 1) {
    return measure!.unit!;
  }
  final label = option.servingUnitLabel?.trim();
  return switch (option.baseQuantity.unit) {
    QuantityUnit.gram => 'g',
    QuantityUnit.millilitre => 'ml',
    QuantityUnit.piece => 'piece',
    _ =>
      label == null || label.isEmpty
          ? 'serving'
          // "1 katori" -> "katori": the amount is shown separately.
          : label.replaceFirst(RegExp(r'^[\d.]+\s+'), ''),
  };
}

double? _scaledFact(
  NutritionFoodOption option,
  String nutrientId,
  Quantity quantity,
) {
  final fact = option.facts[nutrientId];
  if (fact == null || !fact.isAvailable || fact.point == null) return null;
  try {
    return fact.scaleBy(quantity).point?.value.asDouble;
  } on NutrientError {
    return null;
  } on QuantityError {
    return null;
  }
}

/// Stepper increment for an item's amount: grams and millilitres move in
/// tens, small counts in quarters.
double quantityStep(DecomposedFoodItem item, {required bool decreasing}) {
  final unit = item.quantityUnit.trim().toLowerCase();
  if (const {'g', 'gm', 'gram', 'grams', 'ml'}.contains(unit)) return 10;
  final amount = item.quantityAmount;
  return (decreasing ? amount <= 1.0 : amount < 1.0) ? 0.25 : 1.0;
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

/// Turns a typed meal description or a meal photo into food items through
/// an [AiGateway], then cross-references them with the curated catalogue.
class NaturalLanguageMealService {
  final AiGateway? _gateway;
  final Dio? _dio;
  final NutritionFoodCatalogRepository _catalog;
  final PrivacyPolicy Function() _policy;
  final String _baseUrl;

  /// Pass [gateway] (production: Firebase). Without one, requests go to the
  /// FastAPI backend through [dio], which is the development and test path.
  NaturalLanguageMealService({
    AiGateway? gateway,
    Dio? dio,
    required NutritionFoodCatalogRepository catalog,
    required PrivacyPolicy Function() policy,
    String? baseUrl,
  }) : assert(gateway != null || dio != null, 'Provide a gateway or a Dio.'),
       _gateway = gateway,
       _dio = dio,
       _catalog = catalog,
       _policy = policy,
       _baseUrl = baseUrl ?? AppConfig.backendUrl;

  AiGateway _gatewayFor({String? deviceUuid}) =>
      _gateway ??
      BackendAiGateway(dio: _dio!, baseUrl: _baseUrl, deviceUuid: deviceUuid);

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

    final data = await _call(() => _gatewayFor().decomposeMealText(cleanText));
    return MealDecompositionResult(
      query: cleanText,
      items: await _resolveAgainstCatalog(_itemsOf(data)),
      totalCalories: (data['total_calories'] as num?)?.toInt() ?? 0,
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
    // Location and other EXIF metadata never leave the device.
    final bytes = await AiPhotoSanitizer.sanitize(
      await file.readAsBytes(),
      maxDimension: AiPhotoSanitizer.mealMaxDimension,
    );

    final data = await _call(
      () => _gatewayFor(deviceUuid: deviceUuid).decomposeMealPhoto(bytes),
    );
    return MealDecompositionResult(
      query: 'Photo Upload',
      items: await _resolveAgainstCatalog(_itemsOf(data)),
      totalCalories: (data['total_calories'] as num?)?.toInt() ?? 0,
    );
  }

  static List<dynamic> _itemsOf(Map<String, dynamic> data) =>
      (data['items'] as List<dynamic>?) ?? const [];

  /// Maps gateway failures onto the exceptions the screens already handle.
  /// Gateways never return fabricated data, so there is no fallback result.
  Future<Map<String, dynamic>> _call(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on AiGatewayException catch (error) {
      if (error.failure == AiGatewayFailure.offline) {
        throw const MealAiOfflineException();
      }
      throw MealAiUnavailableException(error.message);
    }
  }

  /// Only foods with calorie data can be a match: a catalogue entry without
  /// facts (e.g. an uninstalled regional pack) would "verify" an item with
  /// no numbers behind it.
  Future<List<NutritionFoodOption>> _searchWithNutrition(String query) async =>
      [
        for (final option in await _catalog.search(query: query))
          if (option.facts['energy']?.point != null) option,
      ];

  /// Matches each parsed item against the curated catalogue. A clear match
  /// supplies the nutrition; a close call is left for the user to choose;
  /// anything else stays an AI estimate. Catalogue failures degrade to an
  /// estimate rather than failing the whole parse.
  Future<List<DecomposedFoodItem>> _resolveAgainstCatalog(
    List<dynamic> rawItems,
  ) async {
    final resolver = MealItemResolver(search: _searchWithNutrition);
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
      final item = DecomposedFoodItem.fromJson(
        raw,
        catalogChoices: match.choices,
      );
      final option = match.option;
      items.add(option == null ? item : bindToCatalog(item, option));
    }
    return items;
  }
}
