import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/nutrition_legacy_read_models.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/features/dashboard/widgets/today_usual_meal_card.dart';
import 'package:indifit/features/food_log/usual_meal.dart';
import 'package:indifit/features/food_log/usual_thali.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// UF-1: "Your usual breakfast" for every meal slot.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  String day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> logDay(
    RealCatalogue c,
    DateTime date,
    List<String> names, {
    String meal = 'breakfast',
  }) async {
    final foods = LoggedRecords.coordinatorFor(c);
    var minute = 0;
    for (final name in names) {
      final option = (await c.catalog.getOption(await c.foodId(name)))!;
      await foods.finalize(
        userId: kLocalNutritionUserScopeId,
        preview: await foods.preview(
          option: option,
          quantity: option.defaultLoggingQuantity,
        ),
        mealCategory: meal,
        // 08:00 IST.
        loggedAt: DateTime.utc(date.year, date.month, date.day, 2, 30 + minute),
        localDate: day(date),
        timezoneId: loggedRecordsTimezone,
        commandId: 'uf1-${day(date)}-$meal-$name',
        consumptionId: 'uf1-${day(date)}-$meal-$name',
      );
      minute++;
    }
  }

  NutritionReadModelRepository readModels(RealCatalogue c) =>
      NutritionReadModelRepository(
        db: c.db,
        registry: c.registry,
        canonicalRepository: c.consumption,
        legacyUserId: kLocalNutritionUserScopeId,
      );

  Future<List<NutritionHistoricalReadRecord>> history(RealCatalogue c) =>
      readModels(c).listHistory(
        userId: kLocalNutritionUserScopeId,
        fromUtc: DateTime.utc(2026, 9, 1),
        toUtc: DateTime.utc(2026, 12, 1),
      );

  final base = DateTime(2026, 10, 10);
  const roti = loggedRecordsRoti;
  const dal = loggedRecordsDal;

  group('detection', () {
    late RealCatalogue c;
    setUp(() async => c = await RealCatalogue.open());
    tearDown(() => c.close());

    test('the same foods on 4 days of a slot are usual', () async {
      for (var i = 0; i < 4; i++) {
        await logDay(c, base.add(Duration(days: i)), [roti, dal]);
      }
      final usual = UsualMealFinder.find(await history(c), slot: 'breakfast')!;
      expect(usual.days, 4);
      expect(usual.names, [roti, dal]);
      expect(usual.title, '$roti + $dal');
      expect(usual.mealCategory, 'breakfast');
      expect(usual.records, hasLength(2));
      expect(usual.records.first.localDate, '2026-10-13');
      final sum = usual.records
          .map((r) => r.totals.facts['energy']!.point!.value.asDouble)
          .reduce((a, b) => a + b);
      expect(usual.kcal, sum);
      // Other slots have no usual.
      expect(UsualMealFinder.find(await history(c), slot: 'lunch'), isNull);
    });

    test('3 days is not usual yet', () async {
      for (var i = 0; i < 3; i++) {
        await logDay(c, base.add(Duration(days: i)), [roti, dal]);
      }
      expect(UsualMealFinder.find(await history(c), slot: 'breakfast'), isNull);
    });

    test('a day with a different set of foods does not count', () async {
      for (var i = 0; i < 3; i++) {
        await logDay(c, base.add(Duration(days: i)), [roti, dal]);
      }
      await logDay(c, base.add(const Duration(days: 3)), [roti]);
      expect(UsualMealFinder.find(await history(c), slot: 'breakfast'), isNull);
    });

    test('the order foods were logged in does not matter', () async {
      for (var i = 0; i < 4; i++) {
        await logDay(c, base.add(Duration(days: i)), [dal, roti]);
      }
      expect(
        UsualMealFinder.find(await history(c), slot: 'breakfast')!.days,
        4,
      );
    });

    test('snack rows count together as the snack slot', () async {
      for (var i = 0; i < 4; i++) {
        await logDay(c, base.add(Duration(days: i)), [
          roti,
        ], meal: i.isEven ? 'evening_snack' : 'snack');
      }
      final usual = UsualMealFinder.find(await history(c), slot: 'snack')!;
      expect(usual.days, 4);
      expect(usual.mealCategory, 'snack');
    });

    test('the window is 14 days', () {
      expect(UsualMealFinder.window, const Duration(days: 14));
      expect(UsualMealFinder.minimumDays, 4);
    });
  });

  test('the slot follows the Today hero time rule', () {
    expect(UsualMealFinder.slotAt(DateTime(2026, 10, 18, 8)), 'breakfast');
    expect(UsualMealFinder.slotAt(DateTime(2026, 10, 18, 13)), 'lunch');
    expect(UsualMealFinder.slotAt(DateTime(2026, 10, 18, 17)), 'snack');
    expect(UsualMealFinder.slotAt(DateTime(2026, 10, 18, 20)), 'dinner');
    expect(UsualMealFinder.slotOf('morning_snack'), 'snack');
  });

  group('Today card', () {
    testWidgets('shows, logs with Undo, and hides once breakfast is logged', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, c.db));
      final now = DateTime.now();
      final morning = DateTime(now.year, now.month, now.day, 8);
      await tester.runAsync(() async {
        for (var i = 1; i <= 4; i++) {
          await logDay(c, morning.subtract(Duration(days: i)), [roti, dal]);
        }
      });
      Future<List<NutritionHistoricalReadRecord>> todayRecords() async =>
          (await readModels(c).dailyTotals(
            userId: kLocalNutritionUserScopeId,
            localDate: day(morning),
          )).records;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...loggedRecordsOverrides(c),
            nutritionThaliRepositoryProvider.overrideWith(
              (ref) async => c.thali,
            ),
            nutritionRecipeLogCoordinatorProvider.overrideWith(
              (ref) async => c.recipeLogging,
            ),
            usualThaliProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: TodayUsualMealCard(now: () => morning)),
          ),
        ),
      );
      await settleLoggedRecords(tester);
      expect(find.text('Your usual breakfast'), findsOneWidget);
      expect(find.textContaining('$roti + $dal'), findsOneWidget);
      expect(find.textContaining('kcal'), findsOneWidget);

      await tester.tap(find.byKey(const Key('today_usual_meal_log')));
      await settleLoggedRecords(tester, rounds: 10);
      expect(find.textContaining('Added your usual: $roti + $dal'), findsOne);
      expect((await tester.runAsync(todayRecords))!, hasLength(2));
      // Breakfast now has food: the card steps aside.
      expect(find.byKey(const Key('today_usual_meal')), findsNothing);

      await tester.tap(find.text('Undo'));
      await settleLoggedRecords(tester, rounds: 10);
      expect((await tester.runAsync(todayRecords))!, isEmpty);
      expect(find.byKey(const Key('today_usual_meal')), findsOneWidget);
    });

    testWidgets('anything else logged in the slot hides it', (tester) async {
      final c = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, c.db));
      final now = DateTime.now();
      final morning = DateTime(now.year, now.month, now.day, 8);
      await tester.runAsync(() async {
        for (var i = 1; i <= 4; i++) {
          await logDay(c, morning.subtract(Duration(days: i)), [roti, dal]);
        }
        await logDay(c, morning, [dal]);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...loggedRecordsOverrides(c),
            usualThaliProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            home: Scaffold(body: TodayUsualMealCard(now: () => morning)),
          ),
        ),
      );
      await settleLoggedRecords(tester);
      expect(find.byKey(const Key('today_usual_meal')), findsNothing);
      expect(find.byKey(const Key('today_usual_thali')), findsNothing);
    });
  });
}
