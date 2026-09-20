import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/typed_quantities.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../../data/repositories/nutrition_food_logging_coordinator.dart';
import 'natural_language_meal_service.dart';
import 'nutrition_label_ocr_service.dart';

// =============================================================================
// NUTRITION LABEL OCR CONTROLLER
// =============================================================================

enum NutritionLabelOcrStatus {
  idle,
  picking,
  scanning,
  ready,
  saving,
  success,
  failure,
}

class NutritionLabelOcrState {
  final NutritionLabelOcrStatus status;
  final NutritionLabelOcrResult? ocrResult;
  final String basis; // 'per_100g' or 'per_serving'
  final String productName;
  final String brandName;
  final double servingSizeAmount;
  final String servingUnit;
  final double portionMultiplier; // default 1.0
  final double? customGrams;
  final Map<String, double> editableNutrients;
  final String? errorMessage;
  final bool isSaved;
  final bool isLogged;

  const NutritionLabelOcrState({
    this.status = NutritionLabelOcrStatus.idle,
    this.ocrResult,
    this.basis = 'per_100g',
    this.productName = '',
    this.brandName = '',
    this.servingSizeAmount = 100.0,
    this.servingUnit = 'g',
    this.portionMultiplier = 1.0,
    this.customGrams,
    this.editableNutrients = const {},
    this.errorMessage,
    this.isSaved = false,
    this.isLogged = false,
  });

  bool get isBusy =>
      status == NutritionLabelOcrStatus.picking ||
      status == NutritionLabelOcrStatus.scanning ||
      status == NutritionLabelOcrStatus.saving;

  double get effectiveMultiplier {
    if (customGrams != null && customGrams! > 0) {
      final base = basis == 'per_100g' ? 100.0 : (servingSizeAmount > 0 ? servingSizeAmount : 100.0);
      return customGrams! / base;
    }
    return portionMultiplier > 0 ? portionMultiplier : 1.0;
  }

  double get effectiveServingSize {
    if (customGrams != null && customGrams! > 0) return customGrams!;
    if (basis == 'per_serving') return servingSizeAmount * effectiveMultiplier;
    return 100.0 * effectiveMultiplier;
  }

  double? get effectiveEnergyKcal {
    final raw = editableNutrients['calories'];
    return raw != null ? raw * effectiveMultiplier : null;
  }

  double? get effectiveProteinG {
    final raw = editableNutrients['protein'];
    return raw != null ? raw * effectiveMultiplier : null;
  }

  double? get effectiveCarbsG {
    final raw = editableNutrients['carbs'];
    return raw != null ? raw * effectiveMultiplier : null;
  }

  double? get effectiveFatG {
    final raw = editableNutrients['fat'];
    return raw != null ? raw * effectiveMultiplier : null;
  }

  double? get effectiveFiberG {
    final raw = editableNutrients['fiber'];
    return raw != null ? raw * effectiveMultiplier : null;
  }

  NutritionLabelOcrState copyWith({
    NutritionLabelOcrStatus? status,
    NutritionLabelOcrResult? ocrResult,
    String? basis,
    String? productName,
    String? brandName,
    double? servingSizeAmount,
    String? servingUnit,
    double? portionMultiplier,
    double? customGrams,
    bool clearCustomGrams = false,
    Map<String, double>? editableNutrients,
    String? errorMessage,
    bool clearError = false,
    bool? isSaved,
    bool? isLogged,
  }) {
    return NutritionLabelOcrState(
      status: status ?? this.status,
      ocrResult: ocrResult ?? this.ocrResult,
      basis: basis ?? this.basis,
      productName: productName ?? this.productName,
      brandName: brandName ?? this.brandName,
      servingSizeAmount: servingSizeAmount ?? this.servingSizeAmount,
      servingUnit: servingUnit ?? this.servingUnit,
      portionMultiplier: portionMultiplier ?? this.portionMultiplier,
      customGrams: clearCustomGrams ? null : (customGrams ?? this.customGrams),
      editableNutrients: editableNutrients ?? this.editableNutrients,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSaved: isSaved ?? this.isSaved,
      isLogged: isLogged ?? this.isLogged,
    );
  }
}

class NutritionLabelOcrController extends StateNotifier<NutritionLabelOcrState> {
  final NutritionLabelOcrService _ocrService;
  final Future<NutritionFoodCatalogRepository> Function() _catalogRepository;
  final Future<NutritionFoodLoggingCoordinator> Function() _loggingCoordinator;
  final String _userId;
  final Future<String> Function() _timezoneId;
  final ImagePicker _picker;

  NutritionLabelOcrController({
    required NutritionLabelOcrService ocrService,
    required Future<NutritionFoodCatalogRepository> Function() catalogRepository,
    required Future<NutritionFoodLoggingCoordinator> Function() loggingCoordinator,
    required String userId,
    required Future<String> Function() timezoneId,
    ImagePicker? picker,
  })  : _ocrService = ocrService,
        _catalogRepository = catalogRepository,
        _loggingCoordinator = loggingCoordinator,
        _userId = userId,
        _timezoneId = timezoneId,
        _picker = picker ?? ImagePicker(),
        super(const NutritionLabelOcrState());

  Future<void> pickAndScan(ImageSource source) async {
    state = state.copyWith(status: NutritionLabelOcrStatus.picking, clearError: true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (file == null) {
        state = state.copyWith(status: NutritionLabelOcrStatus.idle);
        return;
      }

      state = state.copyWith(status: NutritionLabelOcrStatus.scanning);
      final result = await _ocrService.processLabelImage(imagePath: file.path);

      final nutrients = <String, double>{};
      for (final entry in result.nutrients.entries) {
        if (entry.value.value != null) {
          nutrients[entry.key] = entry.value.value!;
        }
      }

      state = state.copyWith(
        status: NutritionLabelOcrStatus.ready,
        ocrResult: result,
        basis: result.basis,
        productName: result.productName ?? '',
        brandName: result.brandName ?? '',
        servingSizeAmount: result.servingSizeAmount ?? (result.isPer100g ? 100.0 : 1.0),
        servingUnit: result.servingSizeUnit ?? (result.isPer100g ? 'g' : 'serving'),
        portionMultiplier: 1.0,
        editableNutrients: nutrients,
      );
    } catch (e) {
      state = state.copyWith(
        status: NutritionLabelOcrStatus.failure,
        errorMessage: e.toString(),
      );
    }
  }

  void updateBasis(String basis) {
    state = state.copyWith(basis: basis);
  }

  void updateMultiplier(double multiplier) {
    state = state.copyWith(
      portionMultiplier: multiplier,
      clearCustomGrams: true,
    );
  }

  void updateCustomGrams(double grams) {
    state = state.copyWith(customGrams: grams);
  }

  void updateProductName(String name) {
    state = state.copyWith(productName: name);
  }

  void updateNutrient(String key, double value) {
    final updated = Map<String, double>.from(state.editableNutrients);
    updated[key] = value;
    state = state.copyWith(editableNutrients: updated);
  }

  Future<NutritionFoodOption?> saveAsCustomFood() async {
    state = state.copyWith(status: NutritionLabelOcrStatus.saving, clearError: true);
    try {
      final name = state.productName.trim().isNotEmpty
          ? state.productName.trim()
          : (state.brandName.trim().isNotEmpty
              ? '${state.brandName.trim()} Item'
              : 'Packaged Food Item');

      final catalog = await _catalogRepository();
      final option = await catalog.createUserFood(
        displayName: name,
        servingSize: state.effectiveServingSize,
        servingUnit: state.servingUnit,
        energyKcal: state.effectiveEnergyKcal,
        proteinG: state.effectiveProteinG,
        carbohydrateG: state.effectiveCarbsG,
        fatG: state.effectiveFatG,
        fibreG: state.effectiveFiberG,
      );

      state = state.copyWith(
        status: NutritionLabelOcrStatus.ready,
        isSaved: true,
      );
      return option;
    } catch (e) {
      state = state.copyWith(
        status: NutritionLabelOcrStatus.failure,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<bool> logToDiary({
    required String mealType,
    required DateTime date,
  }) async {
    state = state.copyWith(status: NutritionLabelOcrStatus.saving, clearError: true);
    try {
      final name = state.productName.trim().isNotEmpty
          ? state.productName.trim()
          : (state.brandName.trim().isNotEmpty
              ? '${state.brandName.trim()} Item'
              : 'Packaged Food Item');

      final catalog = await _catalogRepository();
      final option = await catalog.createUserFood(
        displayName: name,
        servingSize: state.effectiveServingSize,
        servingUnit: state.servingUnit,
        energyKcal: state.effectiveEnergyKcal,
        proteinG: state.effectiveProteinG,
        carbohydrateG: state.effectiveCarbsG,
        fatG: state.effectiveFatG,
        fibreG: state.effectiveFiberG,
      );

      final coordinator = await _loggingCoordinator();
      final preview = await coordinator.preview(
        option: option,
        quantity: option.baseQuantity,
      );

      final localDate =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      await coordinator.finalize(
        userId: _userId,
        preview: preview,
        mealCategory: mealType,
        loggedAt: date.toUtc(),
        localDate: localDate,
        timezoneId: await _timezoneId(),
      );

      state = state.copyWith(
        status: NutritionLabelOcrStatus.success,
        isLogged: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: NutritionLabelOcrStatus.failure,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}

// =============================================================================
// NATURAL LANGUAGE MEAL CONTROLLER
// =============================================================================

enum NaturalLanguageMealStatus {
  idle,
  analyzing,
  ready,
  logging,
  success,
  failure,
}

class NaturalLanguageMealState {
  final NaturalLanguageMealStatus status;
  final MealDecompositionResult? result;
  final List<DecomposedFoodItem> editableItems;
  final String? errorMessage;
  final bool isLogged;

  const NaturalLanguageMealState({
    this.status = NaturalLanguageMealStatus.idle,
    this.result,
    this.editableItems = const [],
    this.errorMessage,
    this.isLogged = false,
  });

  bool get isBusy =>
      status == NaturalLanguageMealStatus.analyzing ||
      status == NaturalLanguageMealStatus.logging;

  int get totalCalories =>
      editableItems.fold(0, (sum, item) => sum + item.estimatedCalories);
  double get totalProtein =>
      editableItems.fold(0.0, (sum, item) => sum + item.estimatedProtein);
  double get totalCarbs =>
      editableItems.fold(0.0, (sum, item) => sum + item.estimatedCarbs);
  double get totalFat =>
      editableItems.fold(0.0, (sum, item) => sum + item.estimatedFat);

  NaturalLanguageMealState copyWith({
    NaturalLanguageMealStatus? status,
    MealDecompositionResult? result,
    List<DecomposedFoodItem>? editableItems,
    String? errorMessage,
    bool clearError = false,
    bool? isLogged,
  }) {
    return NaturalLanguageMealState(
      status: status ?? this.status,
      result: result ?? this.result,
      editableItems: editableItems ?? this.editableItems,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLogged: isLogged ?? this.isLogged,
    );
  }
}

class NaturalLanguageMealController
    extends StateNotifier<NaturalLanguageMealState> {
  final Future<NaturalLanguageMealService> Function() _mealService;
  final Future<NutritionFoodCatalogRepository> Function() _catalogRepository;
  final Future<NutritionFoodLoggingCoordinator> Function() _loggingCoordinator;
  final String _userId;
  final Future<String> Function() _timezoneId;

  NaturalLanguageMealController({
    required Future<NaturalLanguageMealService> Function() mealService,
    required Future<NutritionFoodCatalogRepository> Function() catalogRepository,
    required Future<NutritionFoodLoggingCoordinator> Function() loggingCoordinator,
    required String userId,
    required Future<String> Function() timezoneId,
  })  : _mealService = mealService,
        _catalogRepository = catalogRepository,
        _loggingCoordinator = loggingCoordinator,
        _userId = userId,
        _timezoneId = timezoneId,
        super(const NaturalLanguageMealState());

  Future<void> analyzeMeal(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    state = state.copyWith(
      status: NaturalLanguageMealStatus.analyzing,
      clearError: true,
    );

    try {
      final mealService = await _mealService();
      final res = await mealService.decomposeMeal(text: clean);
      state = state.copyWith(
        status: NaturalLanguageMealStatus.ready,
        result: res,
        editableItems: List.from(res.items),
      );
    } catch (e) {
      state = state.copyWith(
        status: NaturalLanguageMealStatus.failure,
        errorMessage: e.toString(),
      );
    }
  }

  void updateItemQuantity(int index, double newAmount, String newUnit) {
    if (index < 0 || index >= state.editableItems.length) return;
    final item = state.editableItems[index];
    final oldAmount = item.quantityAmount > 0 ? item.quantityAmount : 1.0;
    final ratio = newAmount > 0 ? (newAmount / oldAmount) : 1.0;

    final updated = item.copyWith(
      quantityAmount: newAmount,
      quantityUnit: newUnit,
      estimatedCalories: (item.estimatedCalories * ratio).round(),
      estimatedProtein: item.estimatedProtein * ratio,
      estimatedCarbs: item.estimatedCarbs * ratio,
      estimatedFat: item.estimatedFat * ratio,
    );

    final list = List<DecomposedFoodItem>.from(state.editableItems);
    list[index] = updated;
    state = state.copyWith(editableItems: list);
  }

  void updateItemFoodMatch(int index, NutritionFoodOption? option) {
    if (index < 0 || index >= state.editableItems.length) return;
    final list = List<DecomposedFoodItem>.from(state.editableItems);
    list[index] = list[index].copyWith(
      matchedCatalogOption: option,
      clearCatalogOption: option == null,
    );
    state = state.copyWith(editableItems: list);
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.editableItems.length) return;
    final list = List<DecomposedFoodItem>.from(state.editableItems);
    list.removeAt(index);
    state = state.copyWith(editableItems: list);
  }

  Future<bool> logAllToDiary({
    required String mealType,
    required DateTime date,
  }) async {
    if (state.editableItems.isEmpty) return false;

    state = state.copyWith(
      status: NaturalLanguageMealStatus.logging,
      clearError: true,
    );

    try {
      final mealGroupId = 'nl-meal::${const Uuid().v4()}';
      final localDate =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final tz = await _timezoneId();
      final catalog = await _catalogRepository();
      final coordinator = await _loggingCoordinator();

      for (final item in state.editableItems) {
        NutritionFoodOption option;
        Quantity quantity;

        if (item.matchedCatalogOption != null) {
          option = item.matchedCatalogOption!;
          if (option.baseQuantity.unit == QuantityUnit.gram) {
            final isGram = item.quantityUnit.toLowerCase() == 'g' ||
                item.quantityUnit.toLowerCase() == 'grams';
            final grams = isGram ? item.quantityAmount : (item.quantityAmount * 100.0);
            quantity = Quantity.fromNum(amount: grams, unit: QuantityUnit.gram);
          } else {
            quantity = Quantity.fromNum(
              amount: item.quantityAmount,
              unit: option.baseQuantity.unit,
              context: option.baseQuantity.context,
            );
          }
        } else {
          option = await catalog.createUserFood(
            displayName: item.foodName,
            servingSize: item.quantityAmount > 0 ? item.quantityAmount : 1.0,
            servingUnit: item.quantityUnit,
            energyKcal: item.estimatedCalories.toDouble(),
            proteinG: item.estimatedProtein,
            carbohydrateG: item.estimatedCarbs,
            fatG: item.estimatedFat,
          );
          quantity = option.baseQuantity;
        }

        final preview = await coordinator.preview(
          option: option,
          quantity: quantity,
        );

        await coordinator.finalize(
          userId: _userId,
          preview: preview,
          mealCategory: mealType,
          mealGroupId: mealGroupId,
          loggedAt: date.toUtc(),
          localDate: localDate,
          timezoneId: tz,
        );
      }

      state = state.copyWith(
        status: NaturalLanguageMealStatus.success,
        isLogged: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: NaturalLanguageMealStatus.failure,
        errorMessage: e.toString(),
      );
      return false;
    }
  }
}
