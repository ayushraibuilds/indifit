import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/core_providers.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../data/models/b04_recommendation_context_models.dart';
import '../../data/repositories/b02_progress_read_repository.dart';
import '../../data/repositories/b04_briefing_read_repositories.dart';
import '../../data/repositories/b04_recommendation_history_repository.dart';
import '../../data/repositories/calendar_read_repository.dart';
import '../../data/repositories/coaching_preference_repository.dart';
import '../../data/repositories/health_service.dart';
import '../../data/repositories/readiness_snapshot_repository.dart';
import '../../data/repositories/recovery_observation_repository.dart';
import '../../data/services/b04_adaptive_target_engine.dart';
import '../../data/services/b04_current_food_guidance_service.dart';
import '../../data/services/b04_meal_opportunity_service.dart';
import '../../data/services/b04_nutrition_safety_filter.dart';
import '../../data/services/b04_optional_ai_assistance.dart';
import '../../data/services/b04_production_recommendation_orchestrator.dart';
import '../../data/services/b04_recommendation_context_assembler.dart';
import '../../data/services/b04_recovery_production_adapter.dart';
import '../dashboard/b04_daily_briefing_controller.dart';
import '../nutrition/current_food_controller.dart';
import '../nutrition/nutrition_providers.dart';
import '../progress/b04_weekly_review_controller.dart';
import 'b04_production_surface_controller.dart';

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
        nutritionUserId: kLocalNutritionUserScopeId,
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
