import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/b05_accessibility_primitives.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/features/food_log/food_contextual_actions.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';

class _TestFoodRepo extends FoodRepository {
  _TestFoodRepo(super.database);

  @override
  Future<List<FoodItem>> getRecentFoods(int limit) async => const [];

  @override
  Future<List<FoodLog>> getLastLoggedMeal(String mealType) async => const [];
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R08D.8 — Food Release-Surface Cleanup', () {
    testWidgets('FoodSearchScreen has Scan barcode but no Describe with AI or Photo estimate', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      final db = AppDatabase.memory();
      addTearDown(db.close);

      final registry = NutrientRegistry.fromAssetFileSync(
        'assets/data/nutrient_registry.json',
      );

      await tester.pumpWidget(
        _wrap(
          const FoodSearchScreen(
            mealType: 'breakfast',
            selectedDate: null,
          ),
          overrides: [
            databaseProvider.overrideWithValue(db),
            localTimezoneServiceProvider.overrideWithValue(
              LocalTimezoneService(read: () async => 'Asia/Kolkata'),
            ),
            nutritionRegistryProvider.overrideWith((ref) async => registry),
            foodRepositoryProvider.overrideWithValue(_TestFoodRepo(db)),
            canonicalRecentFoodsProvider.overrideWith((ref) async => const []),
            foodLogsForDayProvider.overrideWith((ref, date) async => []),
            canonicalFoodRecordsForDayProvider.overrideWith((ref, date) async => []),
            foodDiaryReadModelProvider.overrideWith((ref, date) async {
              final totals = NutrientAggregationService.aggregate(
                registry: registry,
                contributions: const <NutrientContribution>[],
                requestedNutrientIds: registry.definitions
                    .map((definition) => definition.id)
                    .toSet(),
              );
              final localDate =
                  '${date.year.toString().padLeft(4, '0')}-'
                  '${date.month.toString().padLeft(2, '0')}-'
                  '${date.day.toString().padLeft(2, '0')}';
              return FoodDiaryReadModel(
                daily: NutritionDailyReadModel(
                  userId: kLocalNutritionUserScopeId,
                  localDate: localDate,
                  records: const [],
                  recordIds: const [],
                  totals: totals,
                  sourceCounts: const {},
                  issues: const [],
                ),
              );
            }),
          ],
        ),
      );
      tester.testTextInput.hide();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Functional surfaces must be present
      expect(find.text('Saved meals'), findsOneWidget);
      expect(find.text('Saved recipes'), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pump();
      expect(find.text('Scan barcode'), findsOneWidget);
      expect(find.text('Scan nutrition label'), findsOneWidget);
      expect(find.text('Describe meal'), findsOneWidget);

      // Unavailable AI/Photo surfaces must be absent
      expect(find.text('Describe with AI'), findsNothing);
      expect(find.text('Photo estimate'), findsNothing);
    });



    test('Router configuration redirects dead routes /food/ai and /meal-planner to /food', () {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          foodRepositoryProvider.overrideWithValue(_TestFoodRepo(db)),
          onboardingCompletedProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      final routes = router.configuration.routes;

      final foodAiRoute = routes.firstWhere(
        (r) => r is GoRoute && r.path == '/food/ai',
      ) as GoRoute;
      expect(foodAiRoute.redirect, isNotNull);

      final mealPlannerRoute = routes.firstWhere(
        (r) => r is GoRoute && r.path == '/meal-planner',
      ) as GoRoute;
      expect(mealPlannerRoute.redirect, isNotNull);
    });

    testWidgets('B05ActionButton supports danger emphasis and danger container styling', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: B05ActionButton(
              label: 'Delete entry',
              icon: Icons.delete_outline,
              emphasis: B05ActionEmphasis.danger,
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final btn = find.widgetWithText(FilledButton, 'Delete entry');
      expect(btn, findsOneWidget);

      final filledButton = tester.widget<FilledButton>(btn);
      final style = filledButton.style!;
      expect(style.backgroundColor?.resolve({}), isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FoodContextualActions uses danger emphasis for delete menu action and clear dialog copy', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      final db = AppDatabase.memory();
      addTearDown(db.close);

      final testLog = FoodLog(
        id: 1,
        name: 'Oats & Milk',
        calories: 250,
        proteinG: 12,
        carbsG: 40,
        fatG: 5,
        mealType: 'breakfast',
        loggedAt: DateTime(2026, 8, 24, 8, 30),
        servingLogged: 1.0,
        servingUnit: 'serving',
        isSynced: false,
      );

      await tester.pumpWidget(
        _wrap(
          Scaffold(
            body: FoodContextualActions(
              log: testLog,
            ),
          ),
          overrides: [
            databaseProvider.overrideWithValue(db),
            foodRepositoryProvider.overrideWithValue(_TestFoodRepo(db)),
          ],
        ),
      );
      await tester.pump();

      // Delete button on the card should have danger emphasis
      final deleteAction = find.widgetWithText(B05ActionButton, 'Delete food');
      expect(deleteAction, findsOneWidget);

      final actionWidget = tester.widget<B05ActionButton>(deleteAction);
      expect(actionWidget.emphasis, B05ActionEmphasis.danger);
    });


  });
}
