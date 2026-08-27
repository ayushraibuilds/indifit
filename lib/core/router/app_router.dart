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
import '../../features/food_log/nutrition_estimate_review_screen.dart';
import '../../features/food_log/nutrition_recipe_editor_screen.dart';
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

/// Tracks whether the user has completed onboarding. Initialized from
/// SharedPreferences in main.dart and updated when onboarding finishes.
final onboardingCompletedProvider = StateProvider<bool>((ref) => false);

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
  final value = raw?.trim().toLowerCase();
  return switch (value) {
    'breakfast' ||
    'lunch' ||
    'dinner' ||
    'snack' ||
    'snacks' => value == 'snacks' ? 'snack' : value,
    _ => null,
  };
}

MainNavigationScaffold foodRouteDestination({String? mealType, String? date}) =>
    MainNavigationScaffold(
      initialIndex: 2,
      foodMealType: parseFoodRouteMealType(mealType),
      foodSelectedDate: parseFoodRouteDate(date),
      foodReturnToParentOnSave: true,
    );

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
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
      GoRoute(
        path: '/',
        builder: (context, state) => const MainNavigationScaffold(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Retired AI routine generation and the legacy Training Split surface
      // must not compete with the reviewed Training planning experience.
      GoRoute(
        path: '/routine-wizard',
        redirect: (context, state) => '/plan-library',
      ),
      GoRoute(path: '/workout', redirect: (context, state) => '/training'),
      GoRoute(
        path: '/training',
        builder: (context, state) =>
            const MainNavigationScaffold(initialIndex: 1),
      ),
      GoRoute(
        path: '/progress',
        builder: (context, state) =>
            const MainNavigationScaffold(initialIndex: 3),
      ),
      // Preserve the former Training entry point without reintroducing a
      // competing bottom-navigation concept.
      GoRoute(path: '/workouts', redirect: (context, state) => '/training'),
      // Exercise Library now lives under Training, but a saved or external
      // deep link still opens the same production library safely.
      GoRoute(
        path: '/exercises',
        builder: (context, state) => const ExerciseLibraryScreen(),
      ),
      GoRoute(
        path: '/food',
        builder: (context, state) => foodRouteDestination(
          mealType: state.uri.queryParameters['mealType'],
          date: state.uri.queryParameters['date'],
        ),
      ),
      // Former AI meal logging route fails safely into Food diary without
      // mounting unavailable surfaces.
      GoRoute(path: '/food/ai', redirect: (context, state) => '/food'),
      GoRoute(
        path: '/food/estimate-review',
        builder: (context, state) {
          final estimateId = state.uri.queryParameters['estimateId'];
          if (estimateId == null || estimateId.trim().isEmpty) {
            return const Scaffold(
              body: Center(child: Text('No estimate selected.')),
            );
          }
          return NutritionEstimateReviewScreen(estimateId: estimateId);
        },
      ),
      GoRoute(
        path: '/food/recipes/edit',
        builder: (context, state) => NutritionRecipeEditorScreen(
          recipeId: state.uri.queryParameters['recipeId'],
          draftVersionId: state.uri.queryParameters['draftVersionId'],
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings/profile',
        redirect: (context, state) => '/profile',
      ),
      GoRoute(path: '/learn', builder: (context, state) => const LearnScreen()),
      GoRoute(
        path: '/health-hub',
        builder: (context, state) => const HealthSyncHubScreen(),
      ),
      GoRoute(
        path: '/settings/household-measures',
        builder: (context, state) => const HouseholdMeasuresScreen(),
      ),
      GoRoute(
        path: '/settings/dietary-constraints',
        builder: (context, state) => const NutritionConstraintsScreen(),
      ),
      GoRoute(
        path: '/settings/dietary-constraints/review',
        builder: (context, state) => NutritionConstraintEvaluationReviewScreen(
          foodId: state.uri.queryParameters['foodId'],
          recipeVersionId: state.uri.queryParameters['recipeVersionId'],
        ),
      ),
      // Former AI meal planner route fails safely into Food diary.
      GoRoute(path: '/meal-planner', redirect: (context, state) => '/food'),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/routine-editor',
        builder: (context, state) => const RoutineEditorScreen(),
      ),
      // The retired AI report must not remain reachable from saved links.
      // Weekly reminders now open the factual Progress destination.
      GoRoute(
        path: '/weekly-report',
        redirect: (context, state) => '/progress',
      ),
      GoRoute(
        path: '/workout-player',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final scheduled = extra['scheduledLaunch'];
          if (scheduled is WorkoutPlayerLaunchData) {
            return WorkoutPlayerScreen(
              routineName: scheduled.routineName,
              exercises: scheduled.exercises,
              scheduledOccurrenceId: scheduled.occurrenceId,
              executionSnapshotJson: scheduled.executionSnapshotJson,
              personalExerciseContextByName:
                  scheduled.personalExerciseContextByName,
            );
          }
          return WorkoutPlayerScreen(
            routineName: extra['routineName'] ?? 'Workout',
            exercises:
                (extra['exercises'] as List?)?.cast<RoutineExercise>() ?? [],
          );
        },
      ),
      GoRoute(
        path: '/workout-summary',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return WorkoutSummaryScreen(
            routineName: extra['routineName'] ?? 'Workout',
            elapsedSeconds: extra['elapsedSeconds'] ?? 0,
            loggedSets:
                (extra['loggedSets'] as List?)?.cast<WorkoutSetsCompanion>() ??
                [],
            scheduledOccurrenceId: extra['scheduledOccurrenceId'] as String?,
            completionCommandId: extra['completionCommandId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/b02-strength-player',
        builder: (context, state) {
          final routeData = workoutExecutionRouteDataFromExtra(state.extra);
          if (routeData == null) {
            return const Scaffold(
              body: Center(child: Text('This workout draft is unavailable.')),
            );
          }
          return B02StrengthPlayerScreen(
            launch: routeData.execution.launch,
            executionContext: routeData.execution,
          );
        },
      ),
      GoRoute(
        path: '/b02-strength-summary',
        builder: (context, state) {
          final routeData = workoutExecutionRouteDataFromExtra(state.extra);
          if (routeData == null) {
            return const Scaffold(
              body: Center(child: Text('This workout draft is unavailable.')),
            );
          }
          return B02StrengthSummaryScreen(
            launch: routeData.execution.launch,
            executionContext: routeData.execution,
          );
        },
      ),
      GoRoute(
        path: '/workout-history',
        builder: (context, state) => const WorkoutHistoryScreen(),
      ),
      GoRoute(
        path: '/workout-history/:sessionId',
        builder: (context, state) {
          final sessionId = int.tryParse(
            state.pathParameters['sessionId'] ?? '',
          );
          if (sessionId == null || sessionId < 1) {
            return const Scaffold(
              body: Center(child: Text('Workout details are unavailable.')),
            );
          }
          return B02StrengthHistoryDetailScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/activity-history/:sessionId',
        builder: (context, state) {
          final sessionId = int.tryParse(
            state.pathParameters['sessionId'] ?? '',
          );
          if (sessionId == null || sessionId < 1) {
            return const Scaffold(
              body: Center(child: Text('Activity details are unavailable.')),
            );
          }
          return B02ActivityHistoryDetailScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/quick-workout',
        builder: (context, state) => const QuickWorkoutScreen(),
      ),
      GoRoute(
        path: '/activity-create',
        builder: (context, state) {
          final rawType = state.uri.queryParameters['type'];
          final type = parseManualActivityRouteType(rawType);
          final rawDate = state.uri.queryParameters['date'];
          final selectedDate = parseFoodRouteDate(rawDate);
          final rawDraftId = state.uri.queryParameters['draftId'];
          final draftId = rawDraftId == null ? null : int.tryParse(rawDraftId);
          if (type == null ||
              (rawDate != null && selectedDate == null) ||
              (rawDraftId != null && (draftId == null || draftId < 1))) {
            return const Scaffold(
              body: Center(child: Text('Activity entry is unavailable.')),
            );
          }
          return B02ActivityCreationScreen(
            initialType: type,
            draftId: draftId,
            selectedDate: selectedDate,
          );
        },
      ),
      GoRoute(
        path: '/program-author',
        builder: (context, state) {
          final programId = state.uri.queryParameters['programId'];
          final versionId = state.uri.queryParameters['versionId'];
          return ProgramAuthorScreen(
            programId: programId,
            programVersionId: versionId,
          );
        },
      ),
      GoRoute(
        path: '/program-review/:versionId',
        builder: (context, state) {
          final versionId = state.pathParameters['versionId']!;
          return ProgramReviewScreen(programVersionId: versionId);
        },
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => ProgramCalendarScreen(
          initialLocalDate: state.uri.queryParameters['date'],
        ),
      ),
      GoRoute(
        path: '/plan-library',
        builder: (context, state) => const PlanLibraryScreen(),
      ),
      GoRoute(
        path: '/plan-overview/:versionId',
        builder: (context, state) =>
            PlanOverviewScreen(versionId: state.pathParameters['versionId']!),
      ),
      GoRoute(
        path: '/plan-library/:programId',
        builder: (context, state) => PlanLibraryDetailScreen(
          programId: state.pathParameters['programId']!,
        ),
      ),
      GoRoute(
        path: '/equipment-profiles',
        builder: (context, state) => const EquipmentProfilesScreen(),
      ),
      GoRoute(
        path: '/equipment-profile-editor',
        builder: (context, state) {
          final profileId = state.uri.queryParameters['profileId'];
          return EquipmentProfileEditorScreen(profileId: profileId);
        },
      ),
      GoRoute(
        path: '/exercise-preference-editor',
        builder: (context, state) {
          final stableId = state.uri.queryParameters['stableId'];
          final rawName = state.uri.queryParameters['rawName'] ?? 'Exercise';
          return ExercisePreferenceEditorScreen(
            stableId: stableId,
            rawName: rawName,
          );
        },
      ),
      // Former Travel Mode route fails safely into Training without loading
      // deprecated surfaces.
      GoRoute(path: '/travel-mode', redirect: (context, state) => '/training'),
    ],
  );
});
