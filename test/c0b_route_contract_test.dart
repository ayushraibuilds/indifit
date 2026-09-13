import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/services/notification_service.dart';
import 'package:indifit/data/models/b02_execution_models.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  // Canonical declared routes in modular concatenation order (coreRoutes,
  // nutritionRoutes, trainingRoutes, workoutPlayerRoutes).
  // Order sensitivity only constrains ambiguous sibling pairs (e.g. static
  // paths before parameter segments like /workout-history before
  // /workout-history/:sessionId, and /plan-library before
  // /plan-library/:programId), which are preserved within each feature family.
  const declaredPaths = <String>[
    // Core routes (8)
    '/',
    '/onboarding',
    '/settings',
    '/profile',
    '/settings/profile',
    '/learn',
    '/health-hub',
    '/progress',
    // Nutrition routes (11)
    '/food',
    '/food/ai',
    '/food/estimate-review',
    '/food/label-ocr',
    '/food/describe',
    '/food/recipes/edit',
    '/food/thali',
    '/settings/household-measures',
    '/settings/dietary-constraints',
    '/settings/dietary-constraints/review',
    '/meal-planner',
    // Training routes (16)
    '/training',
    '/workouts',
    '/exercises',
    '/workout-history',
    '/workout-history/:sessionId',
    '/activity-history/:sessionId',
    '/program-author',
    '/program-review/:versionId',
    '/calendar',
    '/plan-library',
    '/plan-overview/:versionId',
    '/plan-library/:programId',
    '/equipment-profiles',
    '/equipment-profile-editor',
    '/exercise-preference-editor',
    '/travel-mode',
    // Workout player routes (11)
    '/routine-wizard',
    '/workout',
    '/routine-editor',
    '/weekly-report',
    '/workout-player',
    '/workout-summary',
    '/b02-strength-player',
    '/b02-strength-summary',
    '/quick-workout',
    '/activity-create',
    '/achievements',
  ];

  test('root router exposes the canonical 46-path contract in order', () {
    final container = ProviderContainer(
      overrides: [onboardingCompletedProvider.overrideWith((ref) => true)],
    );
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);
    final actual = router.configuration.routes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toList(growable: false);

    expect(actual, declaredPaths);
    expect(actual.toSet(), hasLength(actual.length));
  });

  test('legacy and retired entry points preserve frozen redirects', () {
    const expectedRedirects = <String, String>{
      '/routine-wizard': '/plan-library',
      '/workout': '/training',
      '/workouts': '/training',
      '/food/ai': '/food',
      '/settings/profile': '/profile',
      '/meal-planner': '/food',
      '/weekly-report': '/progress',
      '/travel-mode': '/training',
    };
    expect(compatibilityRouteRedirects, expectedRedirects);

    final container = ProviderContainer(
      overrides: [onboardingCompletedProvider.overrideWith((ref) => true)],
    );
    addTearDown(container.dispose);
    final routes = <String, GoRoute>{
      for (final route
          in container.read(appRouterProvider).configuration.routes)
        if (route is GoRoute) route.path: route,
    };

    for (final entry in expectedRedirects.entries) {
      expect(compatibilityRouteRedirect(entry.key), entry.value);
      expect(
        routes[entry.key]?.redirect,
        isNotNull,
        reason: '${entry.key} must remain a declared compatibility route',
      );
    }
    expect(compatibilityRouteRedirect('/unknown'), isNull);
  });

  test(
    'onboarding redirect truth table remains synchronous and fail-closed',
    () {
      const locations = <String>['/', '/food', '/training', '/onboarding'];
      for (final location in locations) {
        expect(
          onboardingGateRedirect(
            onboardingCompleted: false,
            location: location,
          ),
          location == '/onboarding' ? isNull : '/onboarding',
        );
        expect(
          onboardingGateRedirect(onboardingCompleted: true, location: location),
          location == '/onboarding' ? '/' : isNull,
        );
      }
    },
  );

  test(
    'query and activity parsers preserve accepted and rejected payloads',
    () {
      expect(parseFoodRouteDate('2026-09-01'), DateTime(2026, 9, 1));
      expect(parseFoodRouteDate('2026-02-29'), isNull);
      expect(parseFoodRouteDate('2026-9-1'), isNull);
      expect(parseFoodRouteDate(''), isNull);
      expect(parseFoodRouteDate(null), isNull);

      expect(parseFoodRouteMealType('Breakfast'), 'breakfast');
      expect(parseFoodRouteMealType('snacks'), 'snack');
      expect(parseFoodRouteMealType(' supper '), isNull);
      expect(parseFoodRouteMealType(null), isNull);

      expect(parsePositiveRouteId('1'), 1);
      expect(parsePositiveRouteId('9223372036854775807'), 9223372036854775807);
      expect(parsePositiveRouteId('0'), isNull);
      expect(parsePositiveRouteId('-1'), isNull);
      expect(parsePositiveRouteId('1.0'), isNull);
      expect(parsePositiveRouteId(''), isNull);
      expect(parsePositiveRouteId(null), isNull);

      expect(parseManualActivityRouteType(null), B02ActivityType.running);
      expect(parseManualActivityRouteType('cycling'), B02ActivityType.cycling);
      expect(
        parseManualActivityRouteType('mobility'),
        B02ActivityType.mobility,
      );
      expect(parseManualActivityRouteType('strength'), isNull);
      expect(parseManualActivityRouteType('legacy'), isNull);
      expect(parseManualActivityRouteType('unknown'), isNull);
    },
  );

  test('notification payloads retain factual destination semantics', () {
    expect(NotificationService.destinationForPayload('workout'), '/training');
    expect(
      NotificationService.destinationForPayload('meal_lunch'),
      '/food?mealType=lunch',
    );
    expect(
      NotificationService.destinationForPayload('meal_dinner'),
      '/food?mealType=dinner',
    );
    expect(NotificationService.destinationForPayload('meal_'), '/food');
    expect(NotificationService.destinationForPayload('evening_nudge'), '/');
    expect(
      NotificationService.destinationForPayload('weekly_report'),
      '/progress',
    );
    expect(NotificationService.destinationForPayload('unknown'), isNull);
    expect(NotificationService.destinationForPayload(''), isNull);
  });
}
