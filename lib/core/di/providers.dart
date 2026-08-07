import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/app_database.dart';
import '../../data/models/b04_recommendation_context_models.dart';
import '../../data/repositories/b02_progress_read_repository.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/b04_briefing_read_repositories.dart';
import '../../data/repositories/b04_recommendation_history_repository.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/coaching_preference_repository.dart';
import '../../data/repositories/equipment_preference_repository.dart';
import '../../data/repositories/health_service.dart';
import '../../data/repositories/legacy_program_compatibility_adapter.dart';
import '../../data/repositories/nutrition_constraint_repository.dart';
import '../../data/repositories/nutrition_consumption_repository.dart';
import '../../data/repositories/nutrition_estimate_repository.dart';
import '../../data/repositories/nutrition_goal_repository.dart';
import '../../data/repositories/nutrition_household_measure_repository.dart';
import '../../data/repositories/nutrition_protein_distribution_repository.dart';
import '../../data/repositories/nutrition_read_model_repository.dart';
import '../../data/repositories/nutrition_recipe_log_coordinator.dart';
import '../../data/repositories/nutrition_recipe_repository.dart';
import '../../data/repositories/nutrition_thali_repository.dart';
import '../../data/repositories/nutrition_transformation_repository.dart';
import '../../data/repositories/program_activation_coordinator.dart';
import '../../data/repositories/program_repository.dart';
import '../../data/repositories/readiness_snapshot_repository.dart';
import '../../data/repositories/recovery_observation_repository.dart';
import '../../data/repositories/travel_repository.dart';
import '../../data/repositories/workout_execution_compatibility_adapter.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/services/b04_adaptive_target_engine.dart';
import '../../data/services/b04_current_food_guidance_service.dart';
import '../../data/services/b04_meal_opportunity_service.dart';
import '../../data/services/b04_nutrition_safety_filter.dart';
import '../../data/services/b04_optional_ai_assistance.dart';
import '../../data/services/b04_production_recommendation_orchestrator.dart';
import '../../data/services/b04_recommendation_context_assembler.dart';
import '../../data/services/b04_recovery_production_adapter.dart';
import '../../features/coaching/b04_production_surface_controller.dart';
import '../../features/dashboard/b04_daily_briefing_controller.dart';
import '../../features/food_log/nutrition_estimate_review_controller.dart';
import '../../features/food_log/nutrition_thali_controller.dart';
import '../../features/food_log/saved_recipe_log_controller.dart';
import '../../features/nutrition/current_food_controller.dart';
import '../../features/nutrition/protein_distribution_controller.dart';
import '../../features/progress/b04_weekly_review_controller.dart';
import '../../features/settings/nutrition_constraint_review_controller.dart';
import '../../features/settings/nutrition_constraints_controller.dart';
import '../config/app_config.dart';
import '../nutrients.dart';
import '../nutrition_calculation_service.dart';
import '../nutrition_household_measures.dart';
import '../privacy/nutrition_estimate_privacy.dart';
import '../privacy/privacy_policy.dart';
import '../services/local_schedule_date_service.dart';
import '../services/local_timezone_service.dart';

export 'user_profile_provider.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

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

final b04CurrentFoodGuidanceServiceProvider =
    Provider<B04CurrentFoodGuidanceService>(
      (_) => const B04CurrentFoodGuidanceService(),
    );

final b04CurrentFoodControllerProvider =
    StateNotifierProvider.autoDispose<
      B04CurrentFoodController,
      B04CurrentFoodState
    >((ref) {
      // The controller exposes an imperative production command boundary;
      // keep it alive while a caller awaits the orchestration future.
      ref.keepAlive();
      return B04CurrentFoodController(
        service: ref.watch(b04CurrentFoodGuidanceServiceProvider),
        loadOrchestrator: () =>
            ref.read(b04ProductionRecommendationOrchestratorProvider.future),
      );
    });

final nutritionGoalRepositoryProvider = Provider<NutritionGoalRepository>(
  (ref) => NutritionGoalRepository(
    database: ref.watch(databaseProvider),
    dates: ref.watch(localScheduleDateServiceProvider),
  ),
);

final coachingPreferenceRepositoryProvider =
    Provider<CoachingPreferenceRepository>(
      (ref) => CoachingPreferenceRepository(
        database: ref.watch(databaseProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
      ),
    );

final b04ProductionUserContextProvider =
    FutureProvider.autoDispose<B04ProductionUserContext>((ref) async {
      return B04ProductionUserContextLoader(
        database: ref.watch(databaseProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
        timezones: ref.watch(localTimezoneServiceProvider),
      ).load();
    });

final b04ProductionRecommendationContextProvider =
    FutureProvider.autoDispose<B04RecommendationContext>((ref) async {
      return B04ProductionRecommendationContextLoader(
        users: B04ProductionUserContextLoader(
          database: ref.watch(databaseProvider),
          dates: ref.watch(localScheduleDateServiceProvider),
          timezones: ref.watch(localTimezoneServiceProvider),
        ),
        dates: ref.watch(localScheduleDateServiceProvider),
        loadOrchestrator: () =>
            ref.read(b04ProductionRecommendationOrchestratorProvider.future),
      ).load();
    });

final b04GoalSettingsControllerProvider =
    StateNotifierProvider.autoDispose<
      B04GoalSettingsController,
      B04GoalSettingsState
    >((ref) {
      ref.keepAlive();
      final controller = B04GoalSettingsController(
        loadContext: () => ref.read(b04ProductionUserContextProvider.future),
        goals: ref.watch(nutritionGoalRepositoryProvider),
        preferences: ref.watch(coachingPreferenceRepositoryProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
      );
      unawaited(controller.load());
      return controller;
    });

final b04RecommendationHistoryRepositoryProvider =
    Provider<B04RecommendationHistoryRepository>(
      (ref) => B04RecommendationHistoryRepository(
        database: ref.watch(databaseProvider),
      ),
    );

final b04DailyBriefingReadRepositoryProvider =
    Provider<B04DailyBriefingReadRepository>(
      (ref) => B04DailyBriefingReadRepository(
        history: ref.watch(b04RecommendationHistoryRepositoryProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
      ),
    );

final b04WeeklyReviewReadRepositoryProvider =
    Provider<B04WeeklyReviewReadRepository>(
      (ref) => B04WeeklyReviewReadRepository(
        history: ref.watch(b04RecommendationHistoryRepositoryProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
      ),
    );

final b04ProductionRecommendationOrchestratorProvider =
    FutureProvider<B04ProductionRecommendationOrchestrator>((ref) async {
      final registry = await ref.watch(nutritionRegistryProvider.future);
      final recipeLogging = await ref.watch(
        nutritionRecipeLogCoordinatorProvider.future,
      );
      final thalis = await ref.watch(nutritionThaliRepositoryProvider.future);
      final nutrition = await ref.watch(
        nutritionReadModelRepositoryProvider.future,
      );
      final database = ref.watch(databaseProvider);
      final dates = ref.watch(localScheduleDateServiceProvider);
      return B04ProductionRecommendationOrchestrator(
        goals: ref.watch(nutritionGoalRepositoryProvider),
        preferences: ref.watch(coachingPreferenceRepositoryProvider),
        nutrition: nutrition,
        constraints: ref.watch(nutritionConstraintRepositoryProvider),
        recipes: ref.watch(nutritionRecipeRepositoryProvider),
        recipeLogging: recipeLogging,
        thalis: thalis,
        readiness: ref.watch(b04ReadinessSnapshotRepositoryProvider),
        progress: B02ProgressReadRepository(database, civilDates: dates),
        calendar: CalendarReadRepository(database, dates: dates),
        targetEngine: B04AdaptiveTargetEngine(dates: dates),
        assembler: B04RecommendationContextAssembler(dates: dates),
        history: ref.watch(b04RecommendationHistoryRepositoryProvider),
        dailyRead: ref.watch(b04DailyBriefingReadRepositoryProvider),
        weeklyRead: ref.watch(b04WeeklyReviewReadRepositoryProvider),
        currentFood: ref.watch(b04CurrentFoodGuidanceServiceProvider),
        opportunities: B04MealOpportunityService(dates: dates),
        safety: const B04NutritionSafetyFilter(),
        registry: registry,
        dates: dates,
        recoveryAdapter: ref.watch(b04RecoveryProductionAdapterProvider),
      );
    });

final b04DailyBriefingControllerProvider =
    StateNotifierProvider.autoDispose<
      B04DailyBriefingController,
      B04DailyBriefingState
    >((ref) {
      ref.keepAlive();
      return B04DailyBriefingController(
        repository: ref.watch(b04DailyBriefingReadRepositoryProvider),
        history: ref.watch(b04RecommendationHistoryRepositoryProvider),
        goals: ref.watch(nutritionGoalRepositoryProvider),
        preferences: ref.watch(coachingPreferenceRepositoryProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
        loadOrchestrator: () =>
            ref.read(b04ProductionRecommendationOrchestratorProvider.future),
      );
    });

final b04WeeklyReviewControllerProvider =
    StateNotifierProvider.autoDispose<
      B04WeeklyReviewController,
      B04WeeklyReviewState
    >((ref) {
      ref.keepAlive();
      return B04WeeklyReviewController(
        repository: ref.watch(b04WeeklyReviewReadRepositoryProvider),
        history: ref.watch(b04RecommendationHistoryRepositoryProvider),
        goals: ref.watch(nutritionGoalRepositoryProvider),
        preferences: ref.watch(coachingPreferenceRepositoryProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
        loadOrchestrator: () =>
            ref.read(b04ProductionRecommendationOrchestratorProvider.future),
      );
    });

final b04RecoveryObservationRepositoryProvider =
    Provider<RecoveryObservationRepository>(
      (ref) => RecoveryObservationRepository(
        database: ref.watch(databaseProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
      ),
    );

final b04ReadinessSnapshotRepositoryProvider =
    Provider<ReadinessSnapshotRepository>(
      (ref) => ReadinessSnapshotRepository(
        database: ref.watch(databaseProvider),
        observations: ref.watch(b04RecoveryObservationRepositoryProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
      ),
    );

final b04RecoveryProductionAdapterProvider =
    Provider<B04RecoveryProductionAdapter>((ref) {
      final dates = ref.watch(localScheduleDateServiceProvider);
      return B04RecoveryProductionAdapter(
        observations: ref.watch(b04RecoveryObservationRepositoryProvider),
        snapshots: ref.watch(b04ReadinessSnapshotRepositoryProvider),
        source: B04CanonicalRecoveryEvidenceSource(
          health: ref.watch(healthServiceProvider),
          progress: B02ProgressReadRepository(
            ref.watch(databaseProvider),
            civilDates: dates,
          ),
          dates: dates,
        ),
        dates: dates,
      );
    });

final b04OptionalAiAssistanceProvider =
    Provider<B04OptionalAiAssistanceService>((ref) {
      final preferences = CoachingPreferenceRepository(
        database: ref.watch(databaseProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
      );
      return B04OptionalAiAssistanceService(
        consent: CoachingPreferenceOptionalAiConsentReader(preferences),
        provider: B04DioOptionalAiProvider(dio: ref.watch(dioProvider)),
        privacyPolicy: ref.watch(privacyPolicyProvider),
      );
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

final dioProvider = Provider<Dio>((ref) {
  // AppConfig.apiKey validates the build key and throws a deterministic StateError
  // in BOTH debug and release modes if missing, ensuring release builds never
  // silently ship with an unconfigured empty key.
  final apiKey = AppConfig.apiKey;
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'x-indifit-key': apiKey},
    ),
  );
  dio.interceptors.add(PrivacyNetworkInterceptor(ref));
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(responseBody: false, requestBody: false),
    );
  }
  return dio;
});

class PrivacyNetworkInterceptor extends Interceptor {
  final Ref _ref;
  PrivacyNetworkInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final policy = _ref.read(privacyPolicyProvider);
    if (policy.isOfflineOnly) {
      handler.reject(
        DioException(
          requestOptions: options,
          error:
              'Outbound network call blocked by strict offline privacy policy.',
          type: DioExceptionType.cancel,
        ),
      );
      return;
    }
    handler.next(options);
  }
}

// Shared state for hydration goals & progress
class WaterState {
  final int waterLogged;
  final int waterGoal;
  final String lastLoggedDate;
  final int glassSize; // glass capacity in ml (default: 250)

  WaterState({
    required this.waterLogged,
    required this.waterGoal,
    required this.lastLoggedDate,
    required this.glassSize,
  });

  WaterState copyWith({
    int? waterLogged,
    int? waterGoal,
    String? lastLoggedDate,
    int? glassSize,
  }) {
    return WaterState(
      waterLogged: waterLogged ?? this.waterLogged,
      waterGoal: waterGoal ?? this.waterGoal,
      lastLoggedDate: lastLoggedDate ?? this.lastLoggedDate,
      glassSize: glassSize ?? this.glassSize,
    );
  }
}

class WaterNotifier extends StateNotifier<WaterState> {
  final AppDatabase? _db;
  Timer? _timer;

  WaterNotifier([this._db])
    : super(
        WaterState(
          waterLogged: 0,
          waterGoal: 8,
          lastLoggedDate: '',
          glassSize: 250,
        ),
      ) {
    loadState();
    // Periodic check every 15 seconds to support midnight resets if app is left open
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkMidnightReset();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> checkMidnightReset() async {
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    if (state.lastLoggedDate.isNotEmpty && state.lastLoggedDate != todayStr) {
      await loadState();
    }
  }

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    int goal = prefs.getInt('water_goal') ?? 8;
    int size = prefs.getInt('water_glass_size') ?? 250;
    int logged = 0;

    var hydratedFromDatabase = false;
    if (_db != null) {
      try {
        final record = await (_db.select(
          _db.dailyHydrations,
        )..where((tbl) => tbl.dateString.equals(todayStr))).getSingleOrNull();
        hydratedFromDatabase = true;
        if (record != null) {
          // The UI is glass-based, while the durable history is millilitre-based.
          // Round only for presentation; the database retains the precise total.
          logged = (record.totalMl / size).round();
          goal = (record.goalMl / size).round();
        }
      } catch (_) {
        // Keep the tracker usable when the database is still opening. The
        // preference mirror is only a temporary compatibility fallback.
      }
    }
    if (!hydratedFromDatabase) {
      final savedDate = prefs.getString('water_last_logged_date') ?? todayStr;
      if (savedDate == todayStr) {
        logged = prefs.getInt('water_logged') ?? 0;
      }
    }

    await prefs.setInt('water_logged', logged);
    await prefs.setString('water_last_logged_date', todayStr);

    if (!mounted) return;
    state = WaterState(
      waterLogged: logged,
      waterGoal: goal,
      lastLoggedDate: todayStr,
      glassSize: size,
    );
  }

  Future<void> logWater(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    int currentLogged = state.waterLogged;

    if (state.lastLoggedDate != todayStr) {
      currentLogged = 0;
      await prefs.setString('water_last_logged_date', todayStr);
    }

    final newLogged = (currentLogged + amount).clamp(0, 100);
    await prefs.setInt('water_logged', newLogged);
    await prefs.setString('water_last_logged_date', todayStr);

    if (_db != null) {
      final totalMl = newLogged * state.glassSize;
      final goalMl = state.waterGoal * state.glassSize;
      await _db
          .into(_db.dailyHydrations)
          .insert(
            DailyHydrationsCompanion.insert(
              dateString: todayStr,
              totalMl: totalMl,
              goalMl: goalMl,
              updatedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }

    state = state.copyWith(waterLogged: newLogged, lastLoggedDate: todayStr);
  }

  Future<void> updateGoal(int newGoal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_goal', newGoal);
    if (_db != null) {
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final totalMl = state.waterLogged * state.glassSize;
      await _db
          .into(_db.dailyHydrations)
          .insert(
            DailyHydrationsCompanion.insert(
              dateString: todayStr,
              totalMl: totalMl,
              goalMl: newGoal * state.glassSize,
              updatedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    state = state.copyWith(waterGoal: newGoal);
  }

  Future<void> updateGlassSize(int newSize) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_glass_size', newSize);
    if (_db != null) {
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      await _db
          .into(_db.dailyHydrations)
          .insert(
            DailyHydrationsCompanion.insert(
              dateString: todayStr,
              totalMl: state.waterLogged * newSize,
              goalMl: state.waterGoal * newSize,
              updatedAt: Value(DateTime.now()),
            ),
            mode: InsertMode.insertOrReplace,
          );
    }
    state = state.copyWith(glassSize: newSize);
  }
}

final waterProvider = StateNotifierProvider<WaterNotifier, WaterState>((ref) {
  return WaterNotifier(ref.watch(databaseProvider));
});

final programRepositoryProvider = Provider<ProgramRepository>((ref) {
  return ProgramRepository(ref.watch(databaseProvider));
});

final localScheduleDateServiceProvider = Provider<LocalScheduleDateService>((
  ref,
) {
  return LocalScheduleDateService();
});

final localTimezoneServiceProvider = Provider<LocalTimezoneService>((ref) {
  return LocalTimezoneService(
    dates: ref.watch(localScheduleDateServiceProvider),
  );
});

final programActivationCoordinatorProvider =
    Provider<ProgramActivationCoordinator>((ref) {
      return ProgramActivationCoordinator(
        ref.watch(databaseProvider),
        dates: ref.watch(localScheduleDateServiceProvider),
      );
    });

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(
    ref.watch(databaseProvider),
    dates: ref.watch(localScheduleDateServiceProvider),
  );
});

final calendarReadRepositoryProvider = Provider<CalendarReadRepository>((ref) {
  return CalendarReadRepository(
    ref.watch(databaseProvider),
    dates: ref.watch(localScheduleDateServiceProvider),
  );
});

final equipmentProfileRepositoryProvider = Provider<EquipmentProfileRepository>(
  (ref) {
    return EquipmentProfileRepository(ref.watch(databaseProvider));
  },
);

/// Compatibility alias for callers not yet migrated to the bounded-context
/// name. It is the same provider/owner, not a second authority.
final equipmentRepositoryProvider = equipmentProfileRepositoryProvider;

final exercisePreferenceRepositoryProvider =
    Provider<ExercisePreferenceRepository>((ref) {
      return ExercisePreferenceRepository(ref.watch(databaseProvider));
    });

final programListProvider = StreamProvider<List<Program>>((ref) {
  return ref.watch(programRepositoryProvider).watchAllPrograms();
});

final programVersionDetailProvider =
    StreamProvider.family<ProgramDetailAggregate?, String>((ref, versionId) {
      return ref
          .watch(programRepositoryProvider)
          .watchProgramVersionDetail(versionId);
    });

final equipmentProfileListProvider = StreamProvider<List<EquipmentProfile>>((
  ref,
) {
  return ref.watch(equipmentProfileRepositoryProvider).watchActiveProfiles();
});

final defaultEquipmentProfileIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(equipmentProfileRepositoryProvider).watchDefaultProfileId();
});

final exercisePreferenceAggregateProvider =
    StreamProvider.family<
      ExercisePreferenceAggregate?,
      ExercisePreferenceLookup
    >((ref, lookup) {
      return ref
          .watch(exercisePreferenceRepositoryProvider)
          .watchPreference(stableId: lookup.stableId, rawName: lookup.rawName);
    });

final workoutExecutionCompatibilityAdapterProvider =
    Provider<WorkoutExecutionCompatibilityAdapter>((ref) {
      return WorkoutExecutionCompatibilityAdapter(
        db: ref.watch(databaseProvider),
        calendarRepo: ref.watch(calendarRepositoryProvider),
        workoutRepo: ref.watch(workoutRepositoryProvider),
        preferenceRepo: ref.watch(exercisePreferenceRepositoryProvider),
        travelRepo: ref.watch(travelRepositoryProvider),
      );
    });

final strengthExecutionRepositoryProvider =
    Provider<StrengthExecutionRepository>(
      (ref) => StrengthExecutionRepository(
        db: ref.watch(databaseProvider),
        calendarRepo: ref.watch(calendarRepositoryProvider),
      ),
    );

final strengthExecutionCompatibilityAdapterProvider =
    Provider<StrengthExecutionCompatibilityAdapter>(
      (ref) => StrengthExecutionCompatibilityAdapter(
        ref.watch(strengthExecutionRepositoryProvider),
      ),
    );

final travelRepositoryProvider = Provider<TravelRepository>((ref) {
  return TravelRepository(
    db: ref.watch(databaseProvider),
    calendarRepo: ref.watch(calendarRepositoryProvider),
    equipmentRepo: ref.watch(equipmentProfileRepositoryProvider),
  );
});

final legacyProgramCompatibilityAdapterProvider =
    Provider<LegacyProgramCompatibilityAdapter>((ref) {
      return LegacyProgramCompatibilityAdapter(ref.watch(databaseProvider));
    });
