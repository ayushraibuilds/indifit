import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_calculation_service.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/privacy/nutrition_estimate_privacy.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/repositories/nutrition_constraint_repository.dart';
import '../../data/repositories/nutrition_consumption_repository.dart';
import '../../data/repositories/nutrition_estimate_repository.dart';
import '../../data/repositories/nutrition_food_catalog_repository.dart';
import '../../data/repositories/nutrition_food_logging_coordinator.dart';
import '../../data/repositories/nutrition_goal_repository.dart';
import '../../data/repositories/nutrition_household_measure_repository.dart';
import '../../data/repositories/nutrition_protein_distribution_repository.dart';
import '../../data/repositories/nutrition_read_model_repository.dart';
import '../../data/repositories/nutrition_recipe_log_coordinator.dart';
import '../../data/repositories/nutrition_recipe_repository.dart';
import '../../data/repositories/nutrition_target_authority.dart';
import '../../data/repositories/nutrition_thali_repository.dart';
import '../../data/repositories/nutrition_transformation_repository.dart';
import '../food_log/nutrition_estimate_review_controller.dart';
import '../food_log/nutrition_thali_controller.dart';
import '../food_log/saved_recipe_log_controller.dart';
import '../nutrition_ai/natural_language_meal_service.dart';
import '../nutrition_ai/nutrition_ai_controllers.dart';
import '../nutrition_ai/nutrition_label_ocr_service.dart';
import '../settings/nutrition_constraint_review_controller.dart';
import '../settings/nutrition_constraints_controller.dart';
import 'protein_distribution_controller.dart';
export 'adaptive_tdee_providers.dart';

final nutritionRecipeRepositoryProvider = Provider<NutritionRecipeRepository>(
  (ref) => NutritionRecipeRepository(db: ref.watch(databaseProvider)),
);

final nutritionConstraintRepositoryProvider =
    Provider<NutritionConstraintRepository>(
      (ref) =>
          NutritionConstraintRepository(database: ref.watch(databaseProvider)),
    );

final nutritionConstraintManagementControllerProvider =
    StateNotifierProvider.autoDispose<
      NutritionConstraintManagementController,
      NutritionConstraintManagementState
    >((ref) {
      final controller = NutritionConstraintManagementController(
        repository: ref.watch(nutritionConstraintRepositoryProvider),
        userId: kLocalNutritionUserScopeId,
      );
      unawaited(controller.load());
      return controller;
    });

final nutritionConstraintEvaluationReviewControllerProvider =
    StateNotifierProvider.autoDispose<
      NutritionConstraintEvaluationReviewController,
      NutritionConstraintEvaluationReviewState
    >(
      (ref) => NutritionConstraintEvaluationReviewController(
        repository: ref.watch(nutritionConstraintRepositoryProvider),
        userId: kLocalNutritionUserScopeId,
      ),
    );

final nutritionTransformationRepositoryProvider =
    Provider<NutritionTransformationRepository>(
      (ref) =>
          NutritionTransformationRepository(db: ref.watch(databaseProvider)),
    );

final nutritionHouseholdMeasureRepositoryProvider =
    Provider<NutritionHouseholdMeasureRepository>(
      (ref) =>
          NutritionHouseholdMeasureRepository(db: ref.watch(databaseProvider)),
    );

/// The recipe calculator is pure and owns no repository or database state.
final nutritionCalculationServiceProvider =
    Provider<NutritionCalculationService>(
      (_) => const NutritionCalculationService(),
    );

/// The checked-in registry is loaded through Flutter's asset boundary so the
/// mobile app does not depend on a development filesystem path.
final nutritionRegistryProvider = FutureProvider<NutrientRegistry>((ref) async {
  final raw = await rootBundle.loadString('assets/data/nutrient_registry.json');
  return NutrientRegistry.fromJson(jsonDecode(raw));
});

final nutritionConsumptionRepositoryProvider =
    FutureProvider<NutritionConsumptionRepository>((ref) async {
      final registry = await ref.watch(nutritionRegistryProvider.future);
      return NutritionConsumptionRepository(
        db: ref.watch(databaseProvider),
        registry: registry,
      );
    });

final nutritionFoodCatalogRepositoryProvider =
    FutureProvider<NutritionFoodCatalogRepository>((ref) async {
      final registry = await ref.watch(nutritionRegistryProvider.future);
      return NutritionFoodCatalogRepository(
        db: ref.watch(databaseProvider),
        registry: registry,
      );
    });

final nutritionFoodLoggingCoordinatorProvider =
    FutureProvider<NutritionFoodLoggingCoordinator>((ref) async {
      final registry = await ref.watch(nutritionRegistryProvider.future);
      return NutritionFoodLoggingCoordinator(
        db: ref.watch(databaseProvider),
        registry: registry,
        catalog: await ref.watch(nutritionFoodCatalogRepositoryProvider.future),
        calculator: ref.watch(nutritionCalculationServiceProvider),
        consumption: await ref.watch(
          nutritionConsumptionRepositoryProvider.future,
        ),
        transformations: ref.watch(nutritionTransformationRepositoryProvider),
      );
    });

final nutritionEstimateRepositoryProvider =
    FutureProvider<NutritionEstimateRepository>((ref) async {
      final registry = await ref.watch(nutritionRegistryProvider.future);
      return NutritionEstimateRepository(
        database: ref.watch(databaseProvider),
        registry: registry,
      );
    });

final nutritionEstimatePrivacyServiceProvider =
    Provider<NutritionEstimatePrivacyService>(
      (_) => NutritionEstimatePrivacyService(),
    );

final nutritionEstimateFinalizationServiceProvider =
    FutureProvider<NutritionEstimateFinalizationService>((ref) async {
      final registry = await ref.watch(nutritionRegistryProvider.future);
      final estimates = await ref.watch(
        nutritionEstimateRepositoryProvider.future,
      );
      final consumption = await ref.watch(
        nutritionConsumptionRepositoryProvider.future,
      );
      return NutritionEstimateFinalizationService(
        estimates: estimates,
        consumption: consumption,
        registry: registry,
      );
    });

final nutritionEstimateReviewControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      NutritionEstimateReviewController,
      NutritionEstimateReviewControllerState,
      String
    >((ref, estimateId) {
      final repository = ref
          .watch(nutritionEstimateRepositoryProvider)
          .requireValue;
      final controller = NutritionEstimateReviewController(
        repository: repository,
        userId: kLocalNutritionUserScopeId,
        estimateId: estimateId,
      );
      unawaited(controller.load());
      return controller;
    });

final nutritionRecipeLogCoordinatorProvider =
    FutureProvider<NutritionRecipeLogCoordinator>((ref) async {
      final registry = await ref.watch(nutritionRegistryProvider.future);
      final consumption = await ref.watch(
        nutritionConsumptionRepositoryProvider.future,
      );
      return NutritionRecipeLogCoordinator(
        db: ref.watch(databaseProvider),
        recipes: ref.watch(nutritionRecipeRepositoryProvider),
        calculator: ref.watch(nutritionCalculationServiceProvider),
        consumption: consumption,
        registry: registry,
      );
    });

final nutritionThaliRepositoryProvider =
    FutureProvider<NutritionThaliRepository>((ref) async {
      final registry = await ref.watch(nutritionRegistryProvider.future);
      final consumption = await ref.watch(
        nutritionConsumptionRepositoryProvider.future,
      );
      final recipeLogging = await ref.watch(
        nutritionRecipeLogCoordinatorProvider.future,
      );
      return NutritionThaliRepository(
        db: ref.watch(databaseProvider),
        registry: registry,
        recipes: ref.watch(nutritionRecipeRepositoryProvider),
        recipeLogging: recipeLogging,
        measures: ref.watch(nutritionHouseholdMeasureRepositoryProvider),
        constraints: ref.watch(nutritionConstraintRepositoryProvider),
        consumption: consumption,
      );
    });

final nutritionThaliControllerProvider = StateNotifierProvider.autoDispose
    .family<NutritionThaliController, NutritionThaliState, String>((
      ref,
      mealCategory,
    ) {
      final controller = NutritionThaliController(
        repository: ref.watch(nutritionThaliRepositoryProvider.future),
        userId: kLocalNutritionUserScopeId,
        mealCategory: mealCategory,
      );
      unawaited(controller.initialize());
      return controller;
    });

final nutritionReadModelRepositoryProvider =
    FutureProvider<NutritionReadModelRepository>((ref) async {
      final registry = await ref.watch(nutritionRegistryProvider.future);
      final consumption = await ref.watch(
        nutritionConsumptionRepositoryProvider.future,
      );
      return NutritionReadModelRepository(
        db: ref.watch(databaseProvider),
        registry: registry,
        canonicalRepository: consumption,
        legacyUserId: kLocalNutritionUserScopeId,
      );
    });

final nutritionGoalRepositoryProvider = Provider<NutritionGoalRepository>(
  (ref) => NutritionGoalRepository(
    database: ref.watch(databaseProvider),
    dates: ref.watch(localScheduleDateServiceProvider),
  ),
);

/// Persisted goal-version and primary-profile writes invalidate every
/// date-scoped nutrition target consumer. The profile table participates
/// because it owns the primary local profile identity resolved by B04.
final nutritionTargetAuthorityChangesProvider =
    StreamProvider.autoDispose<Object>((ref) {
      final database = ref.watch(databaseProvider);
      return database
          .tableUpdates(
            TableUpdateQuery.onAllTables([
              database.nutritionGoalVersions,
              database.userProfiles,
            ]),
          )
          .map<Object>((_) => Object());
    });

/// One consumer-facing target resolver shared by Today, Food, and Progress.
/// The resolver is stateless; each Riverpod read boundary watches the durable
/// goal-version stream so its date reads are recomputed after a change.
final nutritionTargetAuthorityProvider = Provider<NutritionTargetAuthority>((
  ref,
) {
  return NutritionTargetAuthority(
    goals: ref.watch(nutritionGoalRepositoryProvider),
    dates: ref.watch(localScheduleDateServiceProvider),
  );
});

final nutritionTargetsForDateProvider = FutureProvider.autoDispose
    .family<NutritionTargetsForDate, NutritionTargetDateQuery>((ref, query) {
      ref.watch(nutritionTargetAuthorityChangesProvider);
      return ref.watch(nutritionTargetAuthorityProvider).resolve(query);
    });

/// Read-only history for the Nutrition Targets hub. Values still come from
/// the goal-version repository; this provider adds no current-target or
/// date-resolution semantics of its own.
final nutritionGoalHistoryProvider = FutureProvider.autoDispose
    .family<List<NutritionGoalVersionReadModel>, String>((ref, userId) {
      ref.watch(nutritionTargetAuthorityChangesProvider);
      return ref
          .watch(nutritionGoalRepositoryProvider)
          .listVersions(userId: userId);
    });

final nutritionProteinDistributionRepositoryProvider =
    FutureProvider<NutritionProteinDistributionRepository>((ref) async {
      final registry = await ref.watch(nutritionRegistryProvider.future);
      final history = await ref.watch(
        nutritionReadModelRepositoryProvider.future,
      );
      return NutritionProteinDistributionRepository(
        registry: registry,
        history: history,
      );
    });

final nutritionProteinDistributionControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      NutritionProteinDistributionController,
      NutritionProteinDistributionState,
      String
    >((ref, localDate) {
      final controller = NutritionProteinDistributionController(
        repository: ref.watch(
          nutritionProteinDistributionRepositoryProvider.future,
        ),
        userId: kLocalNutritionUserScopeId,
        localDate: localDate,
      );
      unawaited(controller.load());
      return controller;
    });

final savedRecipeLogControllerProvider =
    StateNotifierProvider.autoDispose<
      SavedRecipeLogController,
      SavedRecipeLogState
    >((ref) {
      final controller = SavedRecipeLogController(
        coordinator: ref.watch(nutritionRecipeLogCoordinatorProvider.future),
        userId: kLocalNutritionUserScopeId,
      );
      unawaited(controller.loadRecipes());
      return controller;
    });

final nutritionLabelOcrServiceProvider = Provider<NutritionLabelOcrService>((ref) {
  return NutritionLabelOcrService(
    dio: ref.watch(dioProvider),
    privacyService: ref.watch(nutritionEstimatePrivacyServiceProvider),
    policy: () => ref.watch(privacyPolicyProvider),
  );
});

final naturalLanguageMealServiceProvider = FutureProvider<NaturalLanguageMealService>((ref) async {
  return NaturalLanguageMealService(
    dio: ref.watch(dioProvider),
    catalog: await ref.watch(nutritionFoodCatalogRepositoryProvider.future),
    policy: () => ref.watch(privacyPolicyProvider),
  );
});

final nutritionLabelOcrControllerProvider = StateNotifierProvider.autoDispose<
  NutritionLabelOcrController,
  NutritionLabelOcrState
>((ref) {
  return NutritionLabelOcrController(
    ocrService: ref.watch(nutritionLabelOcrServiceProvider),
    catalogRepository: () => ref.read(nutritionFoodCatalogRepositoryProvider.future),
    loggingCoordinator: () => ref.read(nutritionFoodLoggingCoordinatorProvider.future),
    userId: kLocalNutritionUserScopeId,
    timezoneId: () => ref.read(localTimezoneServiceProvider).currentTimezoneId(),
  );
});

final naturalLanguageMealControllerProvider = StateNotifierProvider.autoDispose<
  NaturalLanguageMealController,
  NaturalLanguageMealState
>((ref) {
  return NaturalLanguageMealController(
    mealService: () => ref.read(naturalLanguageMealServiceProvider.future),
    catalogRepository: () => ref.read(nutritionFoodCatalogRepositoryProvider.future),
    loggingCoordinator: () => ref.read(nutritionFoodLoggingCoordinatorProvider.future),
    userId: kLocalNutritionUserScopeId,
    timezoneId: () => ref.read(localTimezoneServiceProvider).currentTimezoneId(),
  );
});
