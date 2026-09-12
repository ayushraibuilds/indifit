part of '../app_router.dart';

final trainingRoutes = <RouteBase>[
  GoRoute(
    path: '/training',
    builder: (context, state) =>
        const MainNavigationScaffold(initialIndex: 1),
  ),
  // Preserve the former Training entry point without reintroducing a
  // competing bottom-navigation concept.
  GoRoute(
    path: '/workouts',
    redirect: (context, state) =>
        compatibilityRouteRedirect(state.matchedLocation),
  ),
  // Exercise Library now lives under Training, but a saved or external
  // deep link still opens the same production library safely.
  GoRoute(
    path: '/exercises',
    builder: (context, state) => const ExerciseLibraryScreen(),
  ),
  GoRoute(
    path: '/workout-history',
    builder: (context, state) => const WorkoutHistoryScreen(),
  ),
  GoRoute(
    path: '/workout-history/:sessionId',
    builder: (context, state) {
      final sessionId = parsePositiveRouteId(
        state.pathParameters['sessionId'],
      );
      if (sessionId == null) {
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
      final sessionId = parsePositiveRouteId(
        state.pathParameters['sessionId'],
      );
      if (sessionId == null) {
        return const Scaffold(
          body: Center(child: Text('Activity details are unavailable.')),
        );
      }
      return B02ActivityHistoryDetailScreen(sessionId: sessionId);
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
  GoRoute(
    path: '/travel-mode',
    redirect: (context, state) =>
        compatibilityRouteRedirect(state.matchedLocation),
  ),
];
