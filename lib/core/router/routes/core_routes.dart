part of '../app_router.dart';

final coreRoutes = <RouteBase>[
  GoRoute(
    path: '/',
    builder: (context, state) => const MainNavigationScaffold(),
  ),
  GoRoute(
    path: '/onboarding',
    builder: (context, state) => const OnboardingScreen(),
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
    redirect: (context, state) =>
        compatibilityRouteRedirect(state.matchedLocation),
  ),
  GoRoute(path: '/learn', builder: (context, state) => const LearnScreen()),
  GoRoute(
    path: '/health-hub',
    builder: (context, state) => const HealthSyncHubScreen(),
  ),
  GoRoute(
    path: '/progress',
    builder: (context, state) =>
        const MainNavigationScaffold(initialIndex: 3),
  ),
];
