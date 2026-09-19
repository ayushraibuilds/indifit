import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/coaching/coaching_providers.dart';
import '../../features/dashboard/today_surface_controller.dart';
import '../../features/hydration/hydration_providers.dart';
import '../../features/nutrition/nutrition_providers.dart';
import '../../features/settings/settings_controller.dart';
import '../../features/training/training_providers.dart';
import '../../features/workout_player/b02_strength_execution_controller.dart';
import '../capabilities/capabilities_registry.dart';
import '../presentation/today_onboarding_handoff.dart';
import '../privacy/privacy_policy.dart';
import '../router/app_router.dart';
import 'user_profile_provider.dart';

/// Targeted in-memory Riverpod state reset across all user-scoped providers.
/// Must be called after complete erasure to prevent stale cached state from
/// leaking into the subsequent onboarding or session experience.
void resetIndiFitUserState(WidgetRef ref) {
  ref.read(onboardingCompletedProvider.notifier).state = false;
  _invalidateUserProviders(ref.invalidate);
}

/// Reset in-memory state on a [ProviderContainer].
void resetIndiFitContainerUserState(ProviderContainer container) {
  container.read(onboardingCompletedProvider.notifier).state = false;
  _invalidateUserProviders(container.invalidate);
}

/// MAINTENANCE OBLIGATION:
/// This list must be updated whenever new user-scoped Riverpod providers,
/// controllers, or cached view models are introduced to IndiFit.
///
/// If a provider is omitted here, the failure mode is stale in-memory state
/// until the controller rebuilds from wiped persistent storage (not data
/// corruption). However, to prevent ghost state from appearing immediately
/// upon navigating back to onboarding or starting a fresh profile, ensure all
/// user-data-dependent providers are registered here.
void _invalidateUserProviders(void Function(ProviderOrFamily) invalidate) {
  invalidate(userProfileProvider);
  invalidate(settingsControllerProvider);
  invalidate(waterProvider);
  invalidate(todaySurfaceSnapshotProvider);
  invalidate(todaySurfaceReadRepositoryProvider);
  invalidate(todayNutritionRevisionProvider);
  invalidate(todayHydrationRevisionProvider);
  invalidate(b02StrengthExecutionControllerProvider);
  invalidate(b04DailyBriefingControllerProvider);
  invalidate(b04WeeklyReviewControllerProvider);
  invalidate(b04CurrentFoodControllerProvider);
  invalidate(b04ProductionUserContextProvider);
  invalidate(b04ProductionRecommendationContextProvider);
  invalidate(b04GoalSettingsControllerProvider);
  invalidate(nutritionProteinDistributionControllerProvider);
  invalidate(nutritionConstraintManagementControllerProvider);
  invalidate(nutritionConstraintEvaluationReviewControllerProvider);
  invalidate(todayOnboardingHandoffPendingProvider);
  invalidate(cloudBackupStatusProvider);
  invalidate(privacyPolicyProvider);
  invalidate(programListProvider);
  invalidate(equipmentProfileListProvider);
}
