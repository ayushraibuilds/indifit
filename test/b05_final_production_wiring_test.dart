import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/presentation/consumer_date_label.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/features/food_log/food_contextual_action_controller.dart';
import 'package:indifit/features/food_log/food_log_surface.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // R07F-0: Outfit is bundled; no runtime font fetching configuration.

  testWidgets(
    'live Today food route preserves past/today/future dates and mutates B03 logs',
    (tester) async {
      final database = AppDatabase.memory();
      final repository = FoodRepository(database);
      final today = DateTime.now();
      final past = DateTime(today.year, today.month, today.day - 1);
      final current = DateTime(today.year, today.month, today.day);
      final future = DateTime(today.year, today.month, today.day + 1);
      late List<FoodLog> initialLogs;

      await tester.runAsync(() async {
        await repository.logFoodEntry(
          name: 'Oats',
          calories: 250,
          proteinG: 10,
          carbsG: 40,
          fatG: 5,
          servingLogged: 1,
          servingUnit: 'bowl',
          mealType: 'breakfast',
          loggedAt: DateTime(past.year, past.month, past.day, 8),
        );
        initialLogs = await database.select(database.foodLogs).get();
      });

      // The gateway below is the real B03 repository boundary (not a fake
      // test gateway); contextual actions remain covered by their own Today
      // surface tests. Exercise writes before mounting the indexed shell so
      // its offstage read subscriptions cannot contend with this fixture.
      final gateway = FoodRepositoryContextualActionGateway(repository);
      final source = initialLogs.single;
      late List<FoodLog> rowsAfterCopy;
      await tester.runAsync(() async {
        await gateway.copy(
          source: source,
          targetDate: source.loggedAt,
          targetMealType: source.mealType,
        );
        rowsAfterCopy = await database.select(database.foodLogs).get();
      });
      expect(rowsAfterCopy, hasLength(2));

      // Edit records the durable B03 correction, then delete removes the
      // source row. B03 currently has no reversible-delete boundary.
      await tester.runAsync(() async {
        await gateway.edit(
          id: source.id,
          values: const FoodLogEditValues(
            name: 'Overnight oats',
            calories: 260,
            proteinG: 11,
            carbsG: 42,
            fatG: 5,
            servingLogged: 1,
          ),
        );
        await gateway.delete(source);
      });
      late List<FoodLog> rowsAfterDelete;
      await tester.runAsync(() async {
        rowsAfterDelete = await database.select(database.foodLogs).get();
      });
      expect(rowsAfterDelete, hasLength(1));
      late List<NutritionUserCorrection> corrections;
      await tester.runAsync(() async {
        corrections = await database
            .select(database.nutritionUserCorrections)
            .get();
      });
      expect(corrections, hasLength(1));

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          userProfileProvider.overrideWith((ref) => _LoadedProfileNotifier()),
          // R07F-0: the router gate is synchronous; it is seeded from
          // SharedPreferences in main() and must be seeded here too.
          onboardingCompletedProvider.overrideWith((ref) => true),
          foodRepositoryProvider.overrideWithValue(repository),
          foodLogsForDayProvider.overrideWith((ref, date) {
            final isPast =
                date.year == past.year &&
                date.month == past.month &&
                date.day == past.day;
            return Future.value(isPast ? initialLogs : const <FoodLog>[]);
          }),
        ],
      );
      final router = container.read(appRouterProvider);
      addTearDown(() async {
        // `/food` is hosted by the indexed app shell. Unmount every tab before
        // closing the shared database so offstage dashboard subscriptions can
        // cancel cleanly.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        router.dispose();
        container.dispose();
        // Drift's watched-query close can wait on the Flutter fake-async zone.
        // Disposal above releases every listener; let the native close finish
        // without holding the test teardown open.
        unawaited(database.close());
      });

      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      router.go(_foodLocation(past));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
          ),
        ),
      );
      await _pumpSettled(tester);
      await _expectLoggingDate(tester, past);
      expect(find.byType(FoodSearchScreen), findsOneWidget);
      expect(find.text('Log breakfast'), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );

      for (final date in [current, future]) {
        router.go(_foodLocation(date));
        await _pumpSettled(tester);
        await _expectLoggingDate(tester, date);
      }
    },
  );

  test(
    'food route date parser keeps local civil days and rejects invalid dates',
    () {
      expect(parseFoodRouteDate('2026-08-06'), DateTime(2026, 8, 6));
      expect(parseFoodRouteDate('2026-02-30'), isNull);
      expect(parseFoodRouteDate('2026-8-6'), isNull);
      expect(parseFoodRouteDate(null), isNull);
    },
  );
}

class _LoadedProfileNotifier extends UserProfileNotifier {
  _LoadedProfileNotifier() : super() {
    state = const UserProfileState(
      isLoaded: true,
      hasProfile: true,
      calorieGoal: 2000,
      proteinGoal: 120,
      carbsGoal: 230,
      fatGoal: 65,
      currentWeight: 74.5,
    );
  }

  @override
  Future<void> loadProfile() async {}
}

String _foodLocation(DateTime date) {
  final value =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return Uri(
    path: '/food',
    queryParameters: {'mealType': 'breakfast', 'date': value},
  ).toString();
}

Future<void> _expectLoggingDate(WidgetTester tester, DateTime date) async {
  final label = ConsumerDateLabel.dateTime(date, today: DateTime.now());
  expect(
    find.descendant(
      of: find.byType(FoodSearchScreen),
      matching: find.text(label),
    ),
    findsOneWidget,
  );
}

Future<void> _pumpSettled(WidgetTester tester) async {
  // The live route contains a long-lived database watch and therefore is not
  // compatible with pumpAndSettle's "no scheduled frames" termination rule.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
