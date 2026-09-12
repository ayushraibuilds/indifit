part of '../app_router.dart';

final workoutPlayerRoutes = <RouteBase>[
  // Retired AI routine generation and the legacy Training Split surface
  // must not compete with the reviewed Training planning experience.
  GoRoute(
    path: '/routine-wizard',
    redirect: (context, state) =>
        compatibilityRouteRedirect(state.matchedLocation),
  ),
  GoRoute(
    path: '/workout',
    redirect: (context, state) =>
        compatibilityRouteRedirect(state.matchedLocation),
  ),
  GoRoute(
    path: '/routine-editor',
    builder: (context, state) => const RoutineEditorScreen(),
  ),
  // The retired AI report must not remain reachable from saved links.
  // Weekly reminders now open the factual Progress destination.
  GoRoute(
    path: '/weekly-report',
    redirect: (context, state) =>
        compatibilityRouteRedirect(state.matchedLocation),
  ),
  // Legacy player route (/workout-player) is in sunset-bound maintenance mode.
  // Authoritative strength player is B02StrengthPlayerScreen (/strength-player).
  // Rest timer expiry here is intentionally silent following the deletion of the legacy notification route.
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
      final draftId = parsePositiveRouteId(rawDraftId);
      if (type == null ||
          (rawDate != null && selectedDate == null) ||
          (rawDraftId != null && draftId == null)) {
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
    path: '/achievements',
    builder: (context, state) => const AchievementsScreen(),
  ),
];
