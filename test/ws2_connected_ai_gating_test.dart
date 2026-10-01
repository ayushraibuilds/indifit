import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/features/food_log/widgets/food_search_recent_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WS2: Connected AI Gating', () {
    testWidgets(
      'FoodSearchRecentList hides Describe meal and Scan label when callbacks are null',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FoodSearchRecentList(
                loadingRecent: false,
                onRetryRecent: () {},
                canonicalRecentResults: const [],
                recentResults: const [],
                canonicalRecentItemBuilder: (_, __) => const SizedBox(),
                recentItemBuilder: (_, __) => const SizedBox(),
                onOpenSavedMeals: () {},
                onOpenSavedRecipes: () {},
                onOpenBarcode: () {},
                onScanNutritionLabel: null,
                onDescribeMeal: null,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Describe meal'), findsNothing);
        expect(find.text('Scan label'), findsNothing);
        expect(find.text('Scan nutrition label'), findsNothing);
        expect(find.text('Scan barcode'), findsWidgets);
      },
    );

    testWidgets(
      'FoodSearchRecentList shows Describe meal and Scan label when callbacks are provided',
      (tester) async {
        bool describeCalled = false;
        bool scanLabelCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FoodSearchRecentList(
                loadingRecent: false,
                onRetryRecent: () {},
                canonicalRecentResults: const [],
                recentResults: const [],
                canonicalRecentItemBuilder: (_, __) => const SizedBox(),
                recentItemBuilder: (_, __) => const SizedBox(),
                onOpenSavedMeals: () {},
                onOpenSavedRecipes: () {},
                onOpenBarcode: () {},
                onScanNutritionLabel: () {
                  scanLabelCalled = true;
                },
                onDescribeMeal: () {
                  describeCalled = true;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Describe meal'), findsWidgets);
        expect(find.text('Scan label'), findsOneWidget);
        expect(find.text('Scan nutrition label'), findsOneWidget);

        await tester.tap(find.text('Scan label'));
        expect(scanLabelCalled, isTrue);

        await tester.tap(find.text('Describe meal').first);
        expect(describeCalled, isTrue);
      },
    );

    testWidgets('AI routes redirect to /food when AI is disallowed', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          onboardingCompletedProvider.overrideWith((ref) => true),
          privacyPolicyProvider.overrideWith(
            (ref) => PrivacyPolicyNotifier()
              ..state = const PrivacyPolicy(
                isOfflineOnly: false,
                isTelemetryEnabled: false,
                connectedAiEnabled: false,
              ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Navigate to /food/describe -> should redirect to /food
      router.go('/food/describe');
      await tester.pump(const Duration(milliseconds: 100));
      expect(router.routeInformationProvider.value.uri.path, equals('/food'));

      // Navigate to /food/label-ocr -> should redirect to /food
      router.go('/food/label-ocr');
      await tester.pump(const Duration(milliseconds: 100));
      expect(router.routeInformationProvider.value.uri.path, equals('/food'));

      // Navigate to /food/photo -> should redirect to /food
      router.go('/food/photo');
      await tester.pump(const Duration(milliseconds: 100));
      expect(router.routeInformationProvider.value.uri.path, equals('/food'));
    });
  });
}
