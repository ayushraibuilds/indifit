import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/navigation/app_navigation.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'primary Training handoff replaces the current top-level destination',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () => goToTrainingTab(context),
                child: const Text('Resume workout'),
              ),
            ),
          ),
          GoRoute(
            path: trainingTabRoute,
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Training'))),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume workout'));
      await tester.pumpAndSettle();

      expect(find.text('Training'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, trainingTabRoute);
      expect(router.canPop(), isFalse);
    },
  );

  testWidgets(
    'legacy workout entry points resolve to reviewed Training surfaces',
    (tester) async {
      final container = ProviderContainer(
        overrides: [onboardingCompletedProvider.overrideWith((ref) => true)],
      );
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      addTearDown(router.dispose);

      final routes = router.configuration.routes.whereType<GoRoute>();
      final workout = routes.singleWhere((route) => route.path == '/workout');
      final routineWizard = routes.singleWhere(
        (route) => route.path == '/routine-wizard',
      );

      expect(workout.redirect, isNotNull);
      expect(routineWizard.redirect, isNotNull);
      expect(NotificationService.destinationForPayload('workout'), '/training');

      router.go('/workout');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(router.routeInformationProvider.value.uri.path, '/training');
      router.go('/routine-wizard');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(router.routeInformationProvider.value.uri.path, '/plan-library');
    },
  );
}
