import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/ai/ai_gateway.dart';
import '../../core/ai/ai_photo_sanitizer.dart';
import '../../core/ai/backend_ai_gateway.dart';
import '../../core/config/app_config.dart';
import '../../core/nutrition_estimates.dart';
import '../../core/privacy/nutrition_estimate_privacy.dart';
import '../../core/privacy/privacy_policy.dart';

/// Field-level OCR result for a nutrient.
class NutrientOcrData {
  final double? value;
  final String unit;
  final String confidence;
  final String? notes;

  const NutrientOcrData({
    required this.value,
    required this.unit,
    required this.confidence,
    this.notes,
  });

  bool get isHighConfidence => confidence.toLowerCase() == 'high';
  bool get isLowConfidence => confidence.toLowerCase() == 'low';

  factory NutrientOcrData.fromJson(Map<String, dynamic> json) {
    return NutrientOcrData(
      value: (json['value'] as num?)?.toDouble(),
      unit: (json['unit'] as String?) ?? 'g',
      confidence: (json['confidence'] as String?) ?? 'medium',
      notes: json['notes'] as String?,
    );
  }
}

/// Parsed nutrition facts table result from OCR.
class NutritionLabelOcrResult {
  final String? productName;
  final String? brandName;
  final double? servingSizeAmount;
  final String? servingSizeUnit;
  final String? servingDescription;
  final double? servingsPerContainer;
  final String basis; // 'per_100g' or 'per_serving'
  final Map<String, NutrientOcrData> nutrients;
  final String? rawText;
  final bool isFallback;
  final String? fallbackReason;

  const NutritionLabelOcrResult({
    this.productName,
    this.brandName,
    this.servingSizeAmount,
    this.servingSizeUnit,
    this.servingDescription,
    this.servingsPerContainer,
    this.basis = 'per_100g',
    required this.nutrients,
    this.rawText,
    this.isFallback = false,
    this.fallbackReason,
  });

  bool get isPer100g => basis == 'per_100g';
  bool get isPerServing => basis == 'per_serving';

  double? get energyKcal => nutrients['calories']?.value;
  double? get proteinG => nutrients['protein']?.value;
  double? get carbsG => nutrients['carbs']?.value;
  double? get fatG => nutrients['fat']?.value;
  double? get fiberG => nutrients['fiber']?.value;
  double? get sodiumMg => nutrients['sodium']?.value;
  double? get sugarG => nutrients['sugar']?.value;
  double? get saturatedFatG => nutrients['saturated_fat']?.value;
  double? get transFatG => nutrients['trans_fat']?.value;
  double? get cholesterolMg => nutrients['cholesterol']?.value;

  factory NutritionLabelOcrResult.fromJson(Map<String, dynamic> json) {
    final rawNutrients = json['nutrients'] as Map<String, dynamic>? ?? {};
    final nutrients = <String, NutrientOcrData>{};
    for (final entry in rawNutrients.entries) {
      if (entry.value is Map<String, dynamic>) {
        nutrients[entry.key] = NutrientOcrData.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    return NutritionLabelOcrResult(
      productName: json['product_name'] as String?,
      brandName: json['brand_name'] as String?,
      servingSizeAmount: (json['serving_size_amount'] as num?)?.toDouble(),
      servingSizeUnit: json['serving_size_unit'] as String?,
      servingDescription: json['serving_description'] as String?,
      servingsPerContainer: (json['servings_per_container'] as num?)
          ?.toDouble(),
      basis: (json['basis'] as String?) ?? 'per_100g',
      nutrients: nutrients,
      rawText: json['raw_text'] as String?,
      isFallback: json['is_fallback'] as bool? ?? false,
      fallbackReason: json['fallback_reason'] as String?,
    );
  }
}

/// Reads nutrition-label photos through an [AiGateway] and guarantees the
/// temporary image file is deleted afterwards, whatever happens.
class NutritionLabelOcrService {
  final AiGateway? _gateway;
  final Dio? _dio;
  final NutritionEstimatePrivacyService _privacyService;
  final PrivacyPolicy Function() _policy;
  final String _baseUrl;

  /// Pass [gateway] (production: Firebase). Without one, requests go to the
  /// FastAPI backend through [dio], which is the development and test path.
  NutritionLabelOcrService({
    AiGateway? gateway,
    Dio? dio,
    required NutritionEstimatePrivacyService privacyService,
    required PrivacyPolicy Function() policy,
    String? baseUrl,
  }) : assert(gateway != null || dio != null, 'Provide a gateway or a Dio.'),
       _gateway = gateway,
       _dio = dio,
       _privacyService = privacyService,
       _policy = policy,
       _baseUrl = baseUrl ?? AppConfig.backendUrl;

  Future<NutritionLabelOcrResult> processLabelImage({
    required String imagePath,
  }) async {
    final policy = _policy();
    if (!policy.isImageUploadAllowed) {
      // Ensure cleanup even if policy blocks before dispatch
      await _privacyService.cleanupTemporaryImage(
        path: imagePath,
        lifecycle: NutritionEstimateImageLifecycle.cancelled,
      );
      throw const NutritionEstimatePrivacyError(
        'privacy_blocked',
        'Connected photo processing is disabled under your current privacy settings.',
      );
    }

    var lifecycle = NutritionEstimateImageLifecycle.failed;
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw const NutritionEstimateValidationError(
          'missing_file',
          'The selected image file does not exist on this device.',
        );
      }

      // Location and other EXIF metadata never leave the device.
      final bytes = await AiPhotoSanitizer.sanitize(
        await file.readAsBytes(),
        maxDimension: AiPhotoSanitizer.labelMaxDimension,
      );
      final gateway =
          _gateway ?? BackendAiGateway(dio: _dio!, baseUrl: _baseUrl);
      final data = await gateway.readNutritionLabel(bytes);
      lifecycle = NutritionEstimateImageLifecycle.completed;
      return NutritionLabelOcrResult.fromJson(data);
    } finally {
      // Strict ephemeral privacy invariant: temporary image is cleaned up
      await _privacyService.cleanupTemporaryImage(
        path: imagePath,
        lifecycle: lifecycle,
      );
    }
  }
}
