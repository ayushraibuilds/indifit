import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/router/route_not_found_screen.dart';
import 'package:indifit/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer onboardedContainer() {
    final container = ProviderContainer(
      overrides: [onboardingCompletedProvider.overrideWith((ref) => true)],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('an unknown location shows the fallback, which leads home', (
    tester,
  ) async {
    final container = onboardedContainer();
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    router.go('/does-not-exist?id=42');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RouteNotFoundScreen), findsOneWidget);
    expect(find.text("That page isn't available"), findsOneWidget);

    await tester.tap(find.text('Go to Today'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.byType(RouteNotFoundScreen), findsNothing);
  });

  test('every notification destination is a registered route', () {
    final router = onboardedContainer().read(appRouterProvider);
    const payloads = [
      'workout',
      'meal_breakfast',
      'meal_lunch',
      'meal_dinner',
      'meal_snack',
      'meal_',
      'evening_nudge',
      'weekly_report',
      'water',
    ];
    for (final payload in payloads) {
      final destination = NotificationService.destinationForPayload(payload);
      expect(destination, isNotNull, reason: payload);
      final match = router.configuration.findMatch(destination!);
      expect(match.isError, isFalse, reason: '$payload -> $destination');
    }
  });

  test('the matcher itself reports unknown paths as errors', () {
    final router = onboardedContainer().read(appRouterProvider);
    expect(router.configuration.findMatch('/does-not-exist').isError, isTrue);
  });
}
