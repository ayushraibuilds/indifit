import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/privacy/privacy_policy.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart'
    hide NutritionConsumptionSnapshot;
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';

class _TestFoodRepo extends FoodRepository {
  _TestFoodRepo(super.database);

  @override
  Future<List<FoodItem>> getRecentFoods(int limit) async => const [];

  @override
  Future<List<FoodLog>> getLastLoggedMeal(String mealType) async => const [];
}

Widget _recentList({VoidCallback? onPhotoMeal}) => MaterialApp(
  home: Scaffold(
    body: FoodSearchRecentList(
      loadingRecent: false,
      onRetryRecent: () {},
      canonicalRecentResults: const [],
      recentResults: const [],
      canonicalRecentItemBuilder: (ctx, item) => const SizedBox(),
      recentItemBuilder: (ctx, item) => const SizedBox(),
      onOpenSavedMeals: () {},
      onOpenSavedRecipes: () {},
      onOpenBarcode: () {},
      onDescribeMeal: () {},
      onPhotoMeal: onPhotoMeal,
    ),
  ),
);

/// The Food landing inside a router, with AI allowed or not. Returns the
/// location the photo route was opened with, if it was.
Future<ValueNotifier<Uri?>> _pumpFoodLanding(
  WidgetTester tester, {
  required bool aiAllowed,
}) async {
  final db = AppDatabase.memory();
  addTearDown(db.close);
  final registry = NutrientRegistry.fromAssetFileSync(
    'assets/data/nutrient_registry.json',
  );
  final opened = ValueNotifier<Uri?>(null);
  final router = GoRouter(
    initialLocation: '/food',
    routes: [
      GoRoute(
        path: '/food',
        builder: (context, state) => FoodSearchScreen(
          mealType: 'breakfast',
          selectedDate: DateTime(2026, 10, 5),
        ),
      ),
      GoRoute(
        path: '/food/photo',
        builder: (context, state) {
          opened.value = state.uri;
          return const Scaffold(body: Text('photo screen'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        privacyPolicyProvider.overrideWith(
          (ref) => PrivacyPolicyNotifier()
            ..state = PrivacyPolicy(
              isOfflineOnly: false,
              isTelemetryEnabled: false,
              connectedAiEnabled: aiAllowed,
            ),
        ),
        localTimezoneServiceProvider.overrideWithValue(
          LocalTimezoneService(read: () async => 'Asia/Kolkata'),
        ),
        nutritionRegistryProvider.overrideWith((ref) async => registry),
        foodRepositoryProvider.overrideWithValue(_TestFoodRepo(db)),
        canonicalRecentFoodsProvider.overrideWith((ref) async => const []),
        foodLogsForDayProvider.overrideWith((ref, date) async => []),
        canonicalFoodRecordsForDayProvider.overrideWith(
          (ref, date) async => [],
        ),
        foodDiaryReadModelProvider.overrideWith((ref, date) async {
          final totals = NutrientAggregationService.aggregate(
            registry: registry,
            contributions: const <NutrientContribution>[],
            requestedNutrientIds: registry.definitions
                .map((definition) => definition.id)
                .toSet(),
          );
          return FoodDiaryReadModel(
            daily: NutritionDailyReadModel(
              userId: kLocalNutritionUserScopeId,
              localDate: '2026-10-05',
              records: const [],
              recordIds: const [],
              totals: totals,
              sourceCounts: const {},
              issues: const [],
            ),
          );
        }),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  tester.testTextInput.hide();
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return opened;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Meal photo shows as a chip and a Beta card when offered', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_recentList(onPhotoMeal: () => taps++));
    await tester.pumpAndSettle();

    expect(find.text('Meal photo'), findsOneWidget);
    expect(find.text('Meal photo (Beta)'), findsOneWidget);

    await tester.tap(find.text('Meal photo'));
    await tester.ensureVisible(find.text('Meal photo (Beta)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meal photo (Beta)'));
    expect(taps, 2);
  });

  testWidgets('Meal photo is absent when not offered', (tester) async {
    await tester.pumpWidget(_recentList());
    await tester.pumpAndSettle();

    expect(find.text('Meal photo'), findsNothing);
    expect(find.text('Meal photo (Beta)'), findsNothing);
  });

  testWidgets('Food landing opens the photo tool with its meal and date', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    final opened = await _pumpFoodLanding(tester, aiAllowed: true);

    await tester.tap(find.text('Meal photo'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('photo screen'), findsOneWidget);
    expect(opened.value?.path, '/food/photo');
    expect(opened.value?.queryParameters, {
      'mealType': 'breakfast',
      'date': '2026-10-05',
    });
  });

  testWidgets('Food landing hides the photo tool when AI is off', (
    tester,
  ) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await _pumpFoodLanding(tester, aiAllowed: false);

    expect(find.text('Meal photo'), findsNothing);
    expect(find.text('Meal photo (Beta)'), findsNothing);
  });
}
