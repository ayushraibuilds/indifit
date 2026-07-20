import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/main_navigation_scaffold.dart';
import '../../features/food_log/ai_meal_logger_screen.dart';
import '../../features/food_log/ai_meal_planner_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/progress/achievements_screen.dart';
import '../../features/reports/weekly_report_screen.dart';
import '../../features/settings/health_sync_hub_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/workout_player/routine_display_screen.dart';
import '../../features/workout_player/routine_editor_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
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
    ],
  );
});
