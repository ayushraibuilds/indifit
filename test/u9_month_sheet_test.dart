import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrition_household_measures.dart';
import 'package:indifit/core/presentation/consumer_date_label.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/core/widgets/indifit_month_sheet.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/features/activity/b02_activity_creation_screen.dart';
import 'package:indifit/features/calendar/calendar_controller.dart';
import 'package:indifit/features/calendar/calendar_read_model.dart';
import 'package:indifit/features/calendar/program_calendar_screen.dart';
import 'package:indifit/features/dashboard/widgets/dashboard_date_bar.dart';
import 'package:indifit/features/dashboard/widgets/today_header_widgets.dart';
import 'package:indifit/features/food_log/food_diary_screen.dart';
import 'package:indifit/features/food_log/widgets/quick_add_macros_sheet.dart';
import 'package:indifit/features/workout_player/widgets/manual_log_sheet.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/logged_records.dart';
import 'support/real_catalogue.dart';
import 'support/widget_test_database.dart';

/// U-9: one month sheet for picking a day to view or log.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  String iso(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
  Finder dayCell(DateTime day) =>
      find.byKey(ValueKey('indifit_month_day_${iso(day)}'));

  group('IndiFitMonthSheet', () {
    final today = DateTime(2026, 10, 24);
    late List<DateTime> loaded;
    DateTime? picked;
    var closed = false;

    Future<void> open(WidgetTester tester) async {
      loaded = [];
      picked = null;
      closed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  picked = await showIndiFitMonthSheet(
                    context,
                    initialDay: DateTime(2026, 10, 10),
                    today: today,
                    marks: (month) async {
                      loaded.add(month);
                      return month.month == 10
                          ? IndiFitMonthMarks(
                              foodDays: {
                                DateTime(2026, 10, 5),
                                DateTime(2026, 10, 10),
                              },
                              workoutDays: {
                                DateTime(2026, 10, 10),
                                DateTime(2026, 10, 12),
                              },
                            )
                          : IndiFitMonthMarks.none;
                    },
                  );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('dots for food and workouts, today marked', (tester) async {
      await open(tester);
      expect(find.text('October 2026'), findsOneWidget);
      expect(loaded, [DateTime(2026, 10)]);
      expect(
        find.byKey(const ValueKey('indifit_month_food_2026-10-05')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('indifit_month_food_2026-10-10')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('indifit_month_food_2026-10-12')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('indifit_month_workout_2026-10-10')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('indifit_month_workout_2026-10-12')),
        findsOne,
      );
      expect(find.bySemanticsLabel('Sat, 24 Oct, today'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Sat, 10 Oct, food logged, workout saved'),
        findsOneWidget,
      );
    });

    testWidgets('future days are disabled', (tester) async {
      await open(tester);
      expect(
        find.bySemanticsLabel('Sun, 25 Oct, not available'),
        findsOneWidget,
      );
      await tester.tap(dayCell(DateTime(2026, 10, 25)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('indifit_month_sheet')), findsOneWidget);
      expect(closed, isFalse);
      // The last month is the current one.
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('indifit_month_next')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('pages between months by arrow and by swipe', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('indifit_month_previous')));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      expect(loaded, contains(DateTime(2026, 9)));
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('August 2026'), findsOneWidget);
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      await tester.tap(dayCell(DateTime(2026, 9, 3)));
      await tester.pumpAndSettle();
      expect(picked, DateTime(2026, 9, 3));
    });

    testWidgets('returns the picked day', (tester) async {
      await open(tester);
      await tester.tap(dayCell(DateTime(2026, 10, 12)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('indifit_month_sheet')), findsNothing);
      expect(picked, DateTime(2026, 10, 12));
    });
  });

  test('food dots count active logs only', () async {
    final c = await RealCatalogue.open();
    addTearDown(c.db.close);
    final foods = LoggedRecords.coordinatorFor(c);
    final option = (await c.catalog.getOption(
      await c.foodId('Moong Dal Chilka (Cooked)'),
    ))!;
    Future<String> log(String localDate, int month, int day) async {
      final snapshot = await foods.finalize(
        userId: kLocalNutritionUserScopeId,
        preview: await foods.preview(
          option: option,
          quantity: option.defaultLoggingQuantity,
        ),
        mealCategory: 'lunch',
        loggedAt: DateTime.utc(2026, month, day, 7),
        localDate: localDate,
        timezoneId: loggedRecordsTimezone,
        commandId: 'u9-$localDate',
        consumptionId: 'u9-$localDate',
      );
      return snapshot.id;
    }

    await log('2026-10-05', 10, 5);
    final undone = await log('2026-10-12', 10, 12);
    await log('2026-11-01', 11, 1);
    await c.consumption.retractConsumption(
      userId: kLocalNutritionUserScopeId,
      snapshotId: undone,
      expectedLocalDate: '2026-10-12',
      expectedMealCategory: 'lunch',
      commandId: 'u9-undo',
    );
    expect(
      await c.consumption.activeLocalDates(
        userId: kLocalNutritionUserScopeId,
        fromLocalDate: '2026-10-01',
        toLocalDate: '2026-10-31',
      ),
      {'2026-10-05'},
    );
  });

  group('food pickers stop at today', () {
    final now = DateTime.now();

    Future<void> open(WidgetTester tester, Widget home, Finder opener) async {
      final db = AppDatabase.memory();
      addTearDown(() => closeWidgetTestDatabase(tester, db));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(theme: AppTheme.lightTheme, home: home),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(opener);
      await tester.tap(opener);
      await tester.pumpAndSettle();
    }

    testWidgets('Today header', (tester) async {
      await open(
        tester,
        Scaffold(
          body: TodayHeader(
            userName: 'Asha',
            streakCount: 0,
            selectedDate: now,
            referenceNow: now,
            onOpenSettings: () {},
            onDateChanged: (_) {},
          ),
        ),
        find.bySemanticsLabel('Choose a date'),
      );
      await expectCappedAtToday(tester);
    });

    testWidgets('Food diary date bar, arrows included', (tester) async {
      await open(
        tester,
        Scaffold(
          body: DashboardDateBar(selectedDate: now, onDateChanged: (_) {}),
        ),
        find.byKey(const ValueKey('dashboard-date-bar-selected-date')),
      );
      await expectCappedAtToday(tester);
      Navigator.of(tester.element(find.byType(IndiFitMonthSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Later dates unavailable'), findsOneWidget);
    });

    testWidgets('Food diary', (tester) async {
      await open(
        tester,
        FoodDiaryScreen(selectedDate: now),
        find.byKey(const ValueKey('food_diary_pick_day')),
      );
      await expectCappedAtToday(tester);
    });

    testWidgets('Quick add (was 30 days ahead)', (tester) async {
      await open(
        tester,
        Scaffold(
          body: QuickAddMacrosSheet(initialMealType: 'lunch', targetDate: now),
        ),
        find.text(DateFormat('d MMM').format(now)),
      );
      await expectCappedAtToday(tester);
    });
  });

  group('each replaced picker returns the picked day', () {
    // The first of this month is always pickable and on the first page.
    final now = DateTime.now();
    final first = DateTime(now.year, now.month);

    Future<void> pick(WidgetTester tester, Finder opener) async {
      await tester.ensureVisible(opener);
      await tester.tap(opener);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('indifit_month_sheet')), findsOneWidget);
      await tester.tap(dayCell(first));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('indifit_month_sheet')), findsNothing);
    }

    Widget app(Widget home, {List<Override> overrides = const []}) =>
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(theme: AppTheme.lightTheme, home: home),
        );

    testWidgets('Today header date line', (tester) async {
      DateTime? changed;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: TodayHeader(
              userName: 'Asha',
              streakCount: 0,
              selectedDate: now,
              referenceNow: now,
              onOpenSettings: () {},
              onDateChanged: (day) => changed = day,
            ),
          ),
        ),
      );
      await pick(tester, find.bySemanticsLabel('Choose a date'));
      expect(changed, first);
    });

    testWidgets('dashboard date bar', (tester) async {
      DateTime? changed;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: DashboardDateBar(
              selectedDate: now,
              onDateChanged: (day) => changed = day,
            ),
          ),
        ),
      );
      await pick(
        tester,
        find.byKey(const ValueKey('dashboard-date-bar-selected-date')),
      );
      expect(changed, first);
    });

    group('with a database', () {
      late AppDatabase db;
      setUp(() => db = AppDatabase.memory());

      testWidgets('Food diary', (tester) async {
        addTearDown(() => closeWidgetTestDatabase(tester, db));
        await tester.pumpWidget(
          app(
            FoodDiaryScreen(selectedDate: now),
            overrides: [databaseProvider.overrideWithValue(db)],
          ),
        );
        await tester.pumpAndSettle();
        await pick(tester, find.byKey(const ValueKey('food_diary_pick_day')));
        expect(
          tester
              .widget<TodayWeekStrip>(find.byType(TodayWeekStrip))
              .selectedDate,
          first,
        );
      });

      testWidgets('Quick add', (tester) async {
        addTearDown(() => closeWidgetTestDatabase(tester, db));
        await tester.pumpWidget(
          app(
            Scaffold(
              body: QuickAddMacrosSheet(
                initialMealType: 'lunch',
                targetDate: now,
              ),
            ),
            overrides: [databaseProvider.overrideWithValue(db)],
          ),
        );
        await tester.pumpAndSettle();
        await pick(tester, find.text(DateFormat('d MMM').format(now)));
        expect(find.text(DateFormat('d MMM').format(first)), findsOneWidget);
      });

      testWidgets('manual workout log', (tester) async {
        addTearDown(() => closeWidgetTestDatabase(tester, db));
        await tester.pumpWidget(
          app(
            Scaffold(body: ManualLogSheet(selectedDate: now)),
            overrides: [databaseProvider.overrideWithValue(db)],
          ),
        );
        await tester.pumpAndSettle();
        await pick(tester, find.textContaining('Workout date, '));
        expect(
          find.text('Workout date, ${ConsumerDateLabel.dateTime(first)}'),
          findsOneWidget,
        );
      });

      testWidgets('manual activity', (tester) async {
        addTearDown(() => closeWidgetTestDatabase(tester, db));
        await tester.pumpWidget(
          app(
            B02ActivityCreationScreen(
              initialType: B02ActivityType.running,
              selectedDate: now,
            ),
            overrides: [databaseProvider.overrideWithValue(db)],
          ),
        );
        await tester.pumpAndSettle();
        await pick(tester, find.textContaining('Activity date · '));
        expect(
          find.text('Activity date · ${ConsumerDateLabel.dateTime(first)}'),
          findsOneWidget,
        );
      });
    });

    testWidgets('training calendar', (tester) async {
      final controller = _CalendarStub(
        CalendarUiState(
          selectedLocalDate: iso(now),
          timezoneId: 'UTC',
          view: CalendarView.day,
        ),
      );
      await tester.pumpWidget(
        app(
          const ProgramCalendarScreen(),
          overrides: [
            calendarControllerProvider.overrideWith((_) => controller),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await pick(tester, find.byIcon(Icons.calendar_today_outlined).first);
      expect(controller.selected, iso(first));
    });
  });
}

/// The month sheet is open on this month with nothing after today: no next
/// month, and tomorrow (when it is in this month) can't be picked.
Future<void> expectCappedAtToday(WidgetTester tester) async {
  expect(find.byKey(const Key('indifit_month_sheet')), findsOneWidget);
  expect(
    tester
        .widget<IconButton>(find.byKey(const Key('indifit_month_next')))
        .onPressed,
    isNull,
  );
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (tomorrow.month != now.month) return;
  final key =
      'indifit_month_day_${tomorrow.year.toString().padLeft(4, '0')}-'
      '${tomorrow.month.toString().padLeft(2, '0')}-'
      '${tomorrow.day.toString().padLeft(2, '0')}';
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('indifit_month_sheet')), findsOneWidget);
}

class _CalendarStub extends StateNotifier<CalendarUiState>
    implements CalendarController {
  _CalendarStub(super.initial);

  String? selected;

  @override
  CalendarUiState get currentState => state;

  @override
  Future<void> selectDate(String localDate) async {
    selected = localDate;
    state = state.copyWith(selectedLocalDate: localDate);
  }

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
