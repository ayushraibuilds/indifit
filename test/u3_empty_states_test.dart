import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/presentation/ui_art.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/consumer_task_primitives.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_execution_compatibility_read_repository.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:indifit/features/food_log/saved_meals_screen.dart';
import 'package:indifit/features/food_log/saved_recipe_log_screen.dart';
import 'package:indifit/features/progress/weekly_check_in.dart';
import 'package:indifit/features/progress/weekly_check_in_screen.dart';
import 'package:indifit/features/training/workout_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// U-3: empty states with art and one action. (Progress before any data
/// is covered by ux_r05_progress_test and ux_r07e_progress_insights_test.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A router whose `/training` is a marker page, so "Start a workout" can
  /// be seen to route there.
  Widget routed(Widget home, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => home),
              GoRoute(
                path: '/training',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('Training Tab'))),
              ),
            ],
          ),
        ),
      );

  testWidgets('the shared widget shows art in place of the icon', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductEmptyState(
            art: UiArt.mealLunch,
            title: 'Nothing yet',
            message: 'It will show here.',
            action: () => tapped++,
            actionLabel: 'Log your first meal',
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('product_empty_state_art')), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    await tester.tap(find.text('Log your first meal'));
    expect(tapped, 1);
  });

  group('Food diary day', () {
    Future<RealCatalogue> pump(WidgetTester tester, DateTime day) async {
      tester.view.physicalSize = const Size(402, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, c.db));
      await tester.runAsync(() => LoggedRecords.log(c, only: {'direct_food'}));
      await tester.pumpWidget(
        ProviderScope(
          overrides: loggedRecordsOverrides(c),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: FoodDiaryScreen(
              selectedDate: day,
              today: DateTime(2026, 10, 9),
            ),
          ),
        ),
      );
      await settleLoggedRecords(tester);
      return c;
    }

    testWidgets('an empty day offers "Log your first meal"', (tester) async {
      await pump(tester, DateTime(2026, 10, 9));
      expect(find.byKey(const Key('food_diary_empty_day')), findsOneWidget);
      expect(find.text('Nothing logged on this day'), findsOneWidget);
      await tester.tap(find.text('Log your first meal'));
      await tester.pumpAndSettle();
      // Food search for the meal now, as "Add food" opens.
      expect(find.byType(FoodSearchScreen), findsOneWidget);
    });

    testWidgets('a day with food hides it', (tester) async {
      await pump(tester, DateTime(2026, 10, 8));
      expect(find.byKey(const Key('food_diary_empty_day')), findsNothing);
    });
  });

  group('Training history', () {
    final item = B02ActivityHistoryItem(
      sessionId: 1,
      name: 'Push Day',
      activityType: B02ActivityType.strength,
      recordKind: B02HistoryRecordKind.canonical,
      completedAt: DateTime.utc(2026, 10, 20, 9),
      durationSeconds: 2700,
      scheduledOccurrenceId: null,
      legacySetCount: 0,
      performedExerciseCount: 2,
      performedGroupCount: 0,
      cardioIntervalCount: 0,
      hasCardioDetail: false,
      hasMobilityDetail: false,
    );

    testWidgets('no workouts → "Start a workout" opens Training', (
      tester,
    ) async {
      await tester.pumpWidget(
        routed(
          const WorkoutHistoryScreen(),
          overrides: [
            workoutHistoryItemsProvider.overrideWith((ref) async => const []),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workout_history_empty')), findsOneWidget);
      await tester.tap(find.text('Start a workout'));
      await tester.pumpAndSettle();
      expect(find.text('Training Tab'), findsOneWidget);
    });

    testWidgets('a saved workout hides it', (tester) async {
      await tester.pumpWidget(
        routed(
          const WorkoutHistoryScreen(),
          overrides: [
            workoutHistoryItemsProvider.overrideWith((ref) async => [item]),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workout_history_empty')), findsNothing);
      expect(find.text('Push Day'), findsOneWidget);
    });
  });

  group('Weekly check-in', () {
    WeeklyCheckIn week({int workouts = 0}) => WeeklyCheckIn(
      weekStart: '2026-10-19',
      weekEnd: '2026-10-25',
      workoutsDone: workouts,
      goal: 3,
      bestSet: null,
      newBests: 0,
      daysLogged: 0,
      averageProteinG: null,
      proteinDays: 0,
      weighInDays: 0,
      firstWeightKg: null,
      lastWeightKg: null,
      nextWeekTrainingDates: const [],
    );

    testWidgets('no data → "Start a workout" opens Training', (tester) async {
      await tester.pumpWidget(
        routed(
          const WeeklyCheckInScreen(),
          overrides: [
            weeklyCheckInProvider.overrideWith((ref) async => week()),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weekly_check_in_empty')), findsOneWidget);
      expect(find.byKey(const Key('weekly_check_in_share')), findsNothing);
      await tester.tap(find.text('Start a workout'));
      await tester.pumpAndSettle();
      expect(find.text('Training Tab'), findsOneWidget);
    });

    testWidgets('a workout this week hides it', (tester) async {
      await tester.pumpWidget(
        routed(
          const WeeklyCheckInScreen(),
          overrides: [
            weeklyCheckInProvider.overrideWith(
              (ref) async => week(workouts: 1),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weekly_check_in_empty')), findsNothing);
      expect(find.byType(WeeklyCheckInView), findsOneWidget);
    });
  });

  group('food screens with a real catalogue', () {
    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(402, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, c.db));
      await tester.pumpWidget(
        ProviderScope(
          overrides: loggedRecordsOverrides(c),
          child: MaterialApp(theme: AppTheme.lightTheme, home: home),
        ),
      );
      await settleLoggedRecords(tester);
    }

    testWidgets('search Recent with no history focuses the search box', (
      tester,
    ) async {
      await pump(tester, const FoodSearchScreen(mealType: 'lunch'));
      expect(find.byKey(const Key('food_search_recent_empty')), findsOneWidget);
      final field = find.byType(TextField).first;
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
      await tester.tap(find.text('Log your first meal'));
      await tester.pump();
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
    });

    testWidgets('saved meals and recipes show art when empty', (tester) async {
      await pump(tester, const SavedMealsScreen(mealType: 'lunch'));
      expect(find.text('No saved meals yet'), findsOneWidget);
      expect(find.byKey(const Key('product_empty_state_art')), findsOneWidget);
      expect(find.text('Create saved meal'), findsOneWidget);

      await pump(tester, const SavedRecipeLogScreen(mealType: 'lunch'));
      expect(find.text('No saved recipes yet'), findsOneWidget);
      expect(find.byKey(const Key('product_empty_state_art')), findsOneWidget);
      expect(find.text('Create recipe'), findsOneWidget);
    });
  });
}
