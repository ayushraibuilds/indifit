import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/navigation/app_navigation.dart';

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
}
