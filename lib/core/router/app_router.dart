import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/models/b02_execution_models.dart';
import '../../data/repositories/b02_strength_execution_repository.dart';
import '../../data/repositories/workout_execution_compatibility_adapter.dart';
import '../../features/activity/b02_activity_creation_screen.dart';
import '../../features/calendar/program_calendar_screen.dart';
import '../../features/dashboard/main_navigation_scaffold.dart';
import '../../features/equipment/equipment_profile_editor_screen.dart';
import '../../features/equipment/equipment_profiles_screen.dart';
import '../../features/equipment/exercise_preference_editor_screen.dart';
import '../../features/food_log/ai_meal_logger_screen.dart';
import '../../features/food_log/ai_meal_planner_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/routine_wizard_screen.dart';
import '../../features/program_authoring/program_author_screen.dart';
import '../../features/program_authoring/program_review_screen.dart';
import '../../features/progress/achievements_screen.dart';
import '../../features/reports/weekly_report_screen.dart';
import '../../features/settings/health_sync_hub_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/travel/travel_mode_screen.dart';
import '../../features/workout_player/b02_strength_player_screen.dart';
import '../../features/workout_player/b02_strength_summary_screen.dart';
import '../../features/workout_player/routine_display_screen.dart';
import '../../features/workout_player/routine_editor_screen.dart';
import '../../features/workout_player/workout_player_screen.dart';
import '../../features/workout_player/workout_summary_screen.dart';

/// Tracks whether the user has completed onboarding. Initialized from
/// SharedPreferences in main.dart and updated when onboarding finishes.
final onboardingCompletedProvider = StateProvider<bool>((ref) => false);

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;
      final location = state.matchedLocation;
      final goingToOnboarding = location == '/onboarding';
      final goingToWizard = location == '/routine-wizard';

      if (!onboardingCompleted && !goingToOnboarding && !goingToWizard) {
        return '/onboarding';
      }
      if (onboardingCompleted && goingToOnboarding) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainNavigationScaffold(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/routine-wizard',
        builder: (context, state) {
          final goal = state.uri.queryParameters['goal'];
          return RoutineWizardScreen(initialGoal: goal);
        },
      ),
      GoRoute(
        path: '/workout',
        builder: (context, state) => const RoutineDisplayScreen(),
      ),
      GoRoute(
        path: '/food',
        builder: (context, state) {
          final mealType = state.uri.queryParameters['mealType'] ?? 'breakfast';
          return AiMealLoggerScreen(mealType: mealType);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/health-hub',
        builder: (context, state) => const HealthSyncHubScreen(),
      ),
      GoRoute(
        path: '/meal-planner',
        builder: (context, state) => const AiMealPlannerScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/routine-editor',
        builder: (context, state) => const RoutineEditorScreen(),
      ),
      GoRoute(
        path: '/weekly-report',
        builder: (context, state) => const WeeklyReportScreen(),
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
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final launch = extra['launch'];
          if (launch is! B02StrengthExecutionLaunch) {
            return const Scaffold(
              body: Center(child: Text('B02 strength draft is unavailable.')),
            );
          }
          return B02StrengthPlayerScreen(launch: launch);
        },
      ),
      GoRoute(
        path: '/b02-strength-summary',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final launch = extra['launch'];
          if (launch is! B02StrengthExecutionLaunch) {
            return const Scaffold(
              body: Center(child: Text('B02 strength draft is unavailable.')),
            );
          }
          return B02StrengthSummaryScreen(launch: launch);
        },
      ),
      GoRoute(
        path: '/activity-create',
        builder: (context, state) {
          final rawType = state.uri.queryParameters['type'];
          B02ActivityType type = B02ActivityType.running;
          if (rawType != null) {
            try {
              type = B02ActivityType.parse(rawType);
            } catch (_) {
              type = B02ActivityType.running;
            }
          }
          final draftId = int.tryParse(
            state.uri.queryParameters['draftId'] ?? '',
          );
          return B02ActivityCreationScreen(initialType: type, draftId: draftId);
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
        builder: (context, state) => const ProgramCalendarScreen(),
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
      GoRoute(
        path: '/travel-mode',
        builder: (context, state) => const TravelModeScreen(),
      ),
    ],
  );
});
