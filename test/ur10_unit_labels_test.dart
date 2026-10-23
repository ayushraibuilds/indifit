import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/typed_quantities.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/nutrition_read_model_repository.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/dashboard/widgets/today_module_widgets.dart';
import 'package:indifit/features/food_log/food_search_screen.dart';
import 'package:indifit/features/food_log/log_confirmation.dart';
import 'package:indifit/features/food_log/thali/circular_thali_plate.dart';
import 'package:indifit/features/food_log/thali/thali_builder_screen.dart';
import 'package:indifit/features/food_log/thali/thali_quantity_label.dart';
import 'package:indifit/features/progress/training_bests.dart';
import 'package:indifit/features/progress/weekly_check_in.dart';
import 'package:indifit/features/progress/weekly_check_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// UR-10 / UR-50: one unit-label path, and no internal ids on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuantityFormatter labels every unit in plain words', () {
    String format(String amount, QuantityUnit unit, {String? measure}) =>
        QuantityFormatter.format(
          Quantity(
            amount: QuantityAmount.fromString(amount),
            unit: unit,
            context: QuantityContext(
              householdMeasure: measure == null
                  ? null
                  : HouseholdMeasureReference(measureType: measure),
            ),
          ),
        );

    test('metric units use symbols', () {
      expect(format('150', QuantityUnit.gram), '150 g');
      expect(format('1', QuantityUnit.gram), '1 g');
      expect(format('5', QuantityUnit.milligram), '5 mg');
      expect(format('2', QuantityUnit.kilogram), '2 kg');
      expect(format('200', QuantityUnit.millilitre), '200 ml');
      expect(format('1.5', QuantityUnit.litre), '1.5 L');
    });

    test('counts are singular for one and plural otherwise', () {
      expect(format('1', QuantityUnit.piece), '1 piece');
      expect(format('2', QuantityUnit.piece), '2 pieces');
      expect(format('0.5', QuantityUnit.piece), '0.5 pieces');
      String label(QuantityUnit unit, String amount) =>
          QuantityFormatter.unitLabel(
            unit,
            amount: QuantityAmount.fromString(amount),
          );
      expect(label(QuantityUnit.serving, '1'), 'serving');
      expect(label(QuantityUnit.serving, '3'), 'servings');
      expect(label(QuantityUnit.unknown, '1'), 'serving');
      expect(label(QuantityUnit.legacy, '2'), 'servings');
    });

    test('household measures name the vessel, never the id', () {
      const katori = 'household_measure_katori_v1';
      expect(
        format('1', QuantityUnit.householdReference, measure: katori),
        '1 katori',
      );
      expect(
        format('2', QuantityUnit.householdReference, measure: katori),
        '2 katori',
      );
      expect(
        format(
          '1',
          QuantityUnit.householdReference,
          measure: 'household_measure_glass_v2',
        ),
        '1 glass',
      );
      expect(
        format(
          '2',
          QuantityUnit.householdReference,
          measure: 'household_measure_glass_v1',
        ),
        '2 glass',
      );
      expect(
        format(
          '3',
          QuantityUnit.householdReference,
          measure: 'household_measure_roti_v1',
        ),
        '3 pieces',
      );
      expect(
        QuantityFormatter.unitLabel(QuantityUnit.householdReference),
        'measure',
      );
    });

    test('every unit has a label', () {
      for (final unit in QuantityUnit.values) {
        final label = QuantityFormatter.unitLabel(unit);
        expect(label, isNotEmpty, reason: '$unit');
        expect(label, isNot(contains('_')), reason: '$unit');
      }
    });

    test('stored units from older records read the same way', () {
      expect(QuantityFormatter.formatStored('150', 'mass_gram'), '150 g');
      expect(QuantityFormatter.formatStored('2', 'pieces'), '2 pieces');
      expect(
        QuantityFormatter.formatStored('1', 'household_measure_katori_v1'),
        '1 katori',
      );
      expect(QuantityFormatter.formatStored('1.0', 'grams'), '1 g');
    });

    test('the thali labels come from the same place', () {
      expect(thaliQuantityLabel(katori(1)), '1 katori');
      expect(
        thaliQuantityLabel(
          Quantity.fromNum(amount: 2, unit: QuantityUnit.piece),
        ),
        '2 pieces',
      );
      expect(
        thaliQuantityLabel(
          Quantity.fromNum(amount: 150, unit: QuantityUnit.gram),
        ),
        '150 g',
      );
    });
  });

  group('no internal id reaches the screen', () {
    late RealCatalogue catalogue;

    setUp(() => SharedPreferences.setMockInitialValues({}));

    final internal = RegExp(r'household_measure|_v\d\b|::|food-seed-');

    void expectNoInternalText(WidgetTester tester) {
      final leaks = [
        for (final widget in tester.widgetList<Text>(find.byType(Text)))
          if (internal.hasMatch(
            widget.data ?? widget.textSpan?.toPlainText() ?? '',
          ))
            widget.data ?? widget.textSpan!.toPlainText(),
        for (final widget in tester.widgetList<RichText>(find.byType(RichText)))
          if (internal.hasMatch(widget.text.toPlainText()))
            widget.text.toPlainText(),
      ];
      expect(leaks, isEmpty);
    }

    // A thali, a recipe, an AI estimate and a household-unit food, in one
    // lunch (LoggedRecords), on every screen that names them.
    late LoggedRecords logged;

    Future<void> pump(
      WidgetTester tester,
      Widget home, {
      bool realRecents = false,
      List<Override> extra = const [],
    }) async {
      if (tester.view.physicalSize.width != 430) {
        tester.view.physicalSize = const Size(402, 1800);
      }
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      catalogue = (await tester.runAsync(RealCatalogue.open))!;
      addTearDown(() => closeWidgetTestDatabase(tester, catalogue.db));
      logged = (await tester.runAsync(() => LoggedRecords.log(catalogue)))!;
      if (realRecents) {
        // A second dal makes it Frequent: only direct foods count.
        await tester.runAsync(() async {
          final foods = LoggedRecords.coordinatorFor(catalogue);
          final option = (await catalogue.catalog.getOption(
            await catalogue.foodId(loggedRecordsDal),
          ))!;
          await foods.finalize(
            userId: kLocalNutritionUserScopeId,
            preview: await foods.preview(
              option: option,
              quantity: option.defaultLoggingQuantity,
            ),
            mealCategory: 'dinner',
            loggedAt: DateTime.utc(2026, 10, 8, 14),
            localDate: loggedRecordsDate,
            timezoneId: loggedRecordsTimezone,
            commandId: 'fixture-direct-again',
            consumptionId: 'fixture-direct-again',
          );
        });
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...loggedRecordsOverrides(catalogue, realRecents: realRecents),
            ...extra,
          ],
          child: MaterialApp(theme: AppTheme.lightTheme, home: home),
        ),
      );
      await settleLoggedRecords(tester);
    }

    testWidgets('the meal page', (tester) async {
      await pump(
        tester,
        FoodMealDetailScreen(
          mealType: 'lunch',
          selectedDate: DateTime(2026, 10, 8),
        ),
      );
      expect(find.textContaining('1 katori'), findsWidgets);
      // Thali and recipe rows show their items when expanded (UR-40).
      for (final toggle
          in find.byIcon(Icons.expand_more_rounded).evaluate().toList()) {
        await tester.tap(find.byWidget(toggle.widget));
      }
      await tester.pump();
      expect(find.textContaining('2 pieces'), findsWidgets);
      expect(find.text('Home dal'), findsOneWidget);
      expectNoInternalText(tester);
    });

    testWidgets('the diary', (tester) async {
      await pump(
        tester,
        FoodDiaryScreen(
          selectedDate: DateTime(2026, 10, 8),
          today: DateTime(2026, 10, 8),
        ),
      );
      expect(find.textContaining('Lunch'), findsWidgets);
      expectNoInternalText(tester);
    });
    testWidgets('Today', (tester) async {
      await pump(tester, const SizedBox());
      final daily = (await tester.runAsync(
        () =>
            NutritionReadModelRepository(
              db: catalogue.db,
              registry: catalogue.registry,
              canonicalRepository: catalogue.consumption,
              legacyUserId: kLocalNutritionUserScopeId,
            ).dailyTotals(
              userId: kLocalNutritionUserScopeId,
              localDate: loggedRecordsDate,
            ),
      ))!;
      final meals = TodayNutritionPresentation.from(
        TodayDomainRead.available(daily),
        loading: false,
      ).meals;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TodayMealsModule(
                meals: meals,
                loading: false,
                unavailable: false,
                onLogMeal: (_) {},
                onRetry: () {},
                selectedDate: DateTime(2026, 10, 8),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Lunch'), findsWidgets);
      expectNoInternalText(tester);
    });

    testWidgets('search Recents and Frequent', (tester) async {
      await pump(
        tester,
        FoodSearchScreen(
          mealType: 'lunch',
          selectedDate: DateTime(2026, 10, 8),
        ),
        realRecents: true,
      );
      expect(find.text('Recent'), findsWidgets);
      expect(find.text('Frequent'), findsOneWidget);
      expectNoInternalText(tester);
    });

    testWidgets('the log confirmation card', (tester) async {
      late BuildContext host;
      await pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      for (final snapshot in logged.bySource.values) {
        showFoodLogConfirmation(host, snapshot, onUndo: () {}, haptic: false);
        await settleLoggedRecords(tester, rounds: 3);
        expect(find.textContaining('Added'), findsWidgets);
        expectNoInternalText(tester);
        ScaffoldMessenger.of(host).removeCurrentSnackBar();
        await tester.pump(const Duration(seconds: 5));
      }
    });

    testWidgets('the thali list and plate', (tester) async {
      tester.view.physicalSize = const Size(430, 1800);
      await pump(
        tester,
        const SizedBox(),
        extra: [
          nutritionThaliRepositoryProvider.overrideWith(
            (ref) async => catalogue.thali,
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...loggedRecordsOverrides(catalogue),
            nutritionThaliRepositoryProvider.overrideWith(
              (ref) async => catalogue.thali,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ThaliBuilderScreen(
              mealCategory: 'lunch',
              initialThaliId: logged.bySource['thali']!.thaliId,
              selectedDate: DateTime(2026, 10, 8),
            ),
          ),
        ),
      );
      await settleLoggedRecords(tester, rounds: 10);
      expect(find.byType(CircularThaliPlate), findsOneWidget);
      expectNoInternalText(tester);
      await tester.tap(find.byKey(const Key('thali_view_mode_list')));
      await settleLoggedRecords(tester);
      expect(find.textContaining(loggedRecordsRoti), findsWidgets);
      expectNoInternalText(tester);
    });

    testWidgets('the weekly check-in', (tester) async {
      TrainingBest best(String id, String name, double kg) {
        TrainingBestsSetFact fact(double load) => TrainingBestsSetFact(
          setId: 'set::$id-$load',
          exerciseId: id,
          exerciseName: name,
          basis: B02LoadBasis.totalExternal,
          loadKg: load,
          reps: 5,
          performedAt: DateTime.utc(2026, 10, 14),
        );
        return TrainingBest(
          kind: TrainingBestKind.heaviest,
          set: fact(kg),
          previous: fact(kg - 2.5),
        );
      }

      final checkIn = WeeklyCheckIn.build(
        WeeklyCheckInInputs(
          weekStart: '2026-10-12',
          weekEnd: '2026-10-18',
          workoutLocalDates: const ['2026-10-12', '2026-10-15'],
          goal: 3,
          bests: [best('exercise_squat_v2', 'Squat', 80)],
          proteinByLoggedDay: const {'2026-10-12': 90},
          weighIns: [
            CheckInWeighIn(
              localDate: '2026-10-12',
              recordedAt: DateTime.utc(2026, 10, 12, 2),
              weightKg: 72,
            ),
          ],
          nextWeekTrainingDates: const ['2026-10-19'],
        ),
      );
      tester.view.physicalSize = const Size(402, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weeklyCheckInProvider.overrideWith((ref) async => checkIn),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WeeklyCheckInScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Squat'), findsWidgets);
      expectNoInternalText(tester);
    });
  });
}
