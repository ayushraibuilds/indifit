import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/workout_execution_compatibility_adapter.dart';
import '../../features/activity/b02_activity_creation_screen.dart';
import '../../features/activity/b02_activity_history_detail_screen.dart';
import '../../features/calendar/program_calendar_screen.dart';
import '../../features/dashboard/main_navigation_scaffold.dart';
import '../../features/education/learn_screen.dart';
import '../../features/equipment/equipment_profile_editor_screen.dart';
import '../../features/equipment/equipment_profiles_screen.dart';
import '../../features/equipment/exercise_preference_editor_screen.dart';
import '../../features/exercise_library/exercise_library_screen.dart';
import '../../features/food_log/meal_presentation_registry.dart';
import '../../features/food_log/nutrition_estimate_review_screen.dart';
import '../../features/food_log/nutrition_recipe_editor_screen.dart';
import '../../features/food_log/thali/thali_builder_screen.dart';
import '../../features/nutrition_ai/natural_language_meal_screen.dart';
import '../../features/nutrition_ai/nutrition_label_ocr_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/program_authoring/program_author_screen.dart';
import '../../features/program_authoring/program_review_screen.dart';
import '../../features/progress/achievements_screen.dart';
import '../../features/settings/health_sync_hub_screen.dart';
import '../../features/settings/household_measures_screen.dart';
import '../../features/settings/nutrition_constraint_review_screen.dart';
import '../../features/settings/nutrition_constraints_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/training/plan_library_screen.dart';
import '../../features/training/workout_history_screen.dart';
import '../../features/workout_player/b02_strength_player_screen.dart';
import '../../features/workout_player/b02_strength_summary_screen.dart';
import '../../features/workout_player/quick_workout_screen.dart';
import '../../features/workout_player/routine_editor_screen.dart';
import '../../features/workout_player/workout_execution_route.dart';
import '../../features/workout_player/workout_player_screen.dart';
import '../../features/workout_player/workout_summary_screen.dart';

part 'routes/core_routes.dart';
part 'routes/nutrition_routes.dart';
part 'routes/training_routes.dart';
part 'routes/workout_player_routes.dart';

/// Tracks whether the user has completed onboarding. Initialized from
/// SharedPreferences in main.dart and updated when onboarding finishes.
final onboardingCompletedProvider = StateProvider<bool>((ref) => false);

/// Saved/deep-link entry points retained only as compatibility redirects.
///
/// Keeping this table explicit makes route retirement reviewable without
/// restoring the superseded consumer surfaces.
const compatibilityRouteRedirects = <String, String>{
  '/routine-wizard': '/plan-library',
  '/workout': '/training',
  '/workouts': '/training',
  '/food/ai': '/food',
  '/settings/profile': '/profile',
  '/meal-planner': '/food',
  '/weekly-report': '/progress',
  '/travel-mode': '/training',
};

String? compatibilityRouteRedirect(String location) =>
    compatibilityRouteRedirects[location];

/// Pure onboarding routing gate used by [appRouterProvider]'s redirect.
///
/// Kept as a top-level function so the routing contract (first launch,
/// completed onboarding) is unit-testable without
/// mounting any screen.
String? onboardingGateRedirect({
  required bool onboardingCompleted,
  required String location,
}) {
  final goingToOnboarding = location == '/onboarding';

  if (!onboardingCompleted && !goingToOnboarding) {
    return '/onboarding';
  }
  if (onboardingCompleted && goingToOnboarding) {
    return '/';
  }
  return null;
}

/// Parses the food route's local civil date without applying a timezone or
/// silently substituting the current day. The dashboard emits this exact
/// `yyyy-MM-dd` form so the selected Today date survives navigation.
DateTime? parseFoodRouteDate(String? raw) {
  final value = raw?.trim();
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final parts = value.split('-');
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;

  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

B02ActivityType? parseManualActivityRouteType(String? raw) {
  if (raw == null) return B02ActivityType.running;
  try {
    final parsed = B02ActivityType.parse(raw.trim());
    return parsed == B02ActivityType.strength ||
            parsed == B02ActivityType.legacy
        ? null
        : parsed;
  } on B02ValidationException {
    return null;
  }
}

String? parseFoodRouteMealType(String? raw) {
  if (raw == null) return null;
  final presentation = MealPresentationRegistry.forStableId(raw);
  return presentation.isKnown ? presentation.stableId : null;
}

/// Parses a SQLite row identifier carried in a route path or query string.
/// Zero, negative, missing, and malformed values all use the existing
/// unavailable-state path instead of becoming database queries.
int? parsePositiveRouteId(String? raw) {
  final value = raw == null ? null : int.tryParse(raw);
  return value != null && value > 0 ? value : null;
}

MainNavigationScaffold foodRouteDestination({String? mealType, String? date}) =>
    MainNavigationScaffold(
      initialIndex: 2,
      foodMealType: parseFoodRouteMealType(mealType),
      foodSelectedDate: parseFoodRouteDate(date),
      foodReturnToParentOnSave: true,
    );

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    // R07F-0: synchronous redirect. The gate is seeded once from
    // SharedPreferences in main() and kept current by onboarding completion,
    // reset, and restore/erase flows, so navigation performs no async
    // preference I/O.
    redirect: (context, state) => onboardingGateRedirect(
      onboardingCompleted: ref.read(onboardingCompletedProvider),
      location: state.matchedLocation,
    ),
    routes: [
      ...coreRoutes,
      ...nutritionRoutes,
      ...trainingRoutes,
      ...workoutPlayerRoutes,
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
