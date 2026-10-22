import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/config/app_preferences_keys.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/services/notification_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/adaptive_tdee_models.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/progress_dashboard_models.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/dashboard/check_in_reminder.dart';
import 'package:indifit/features/dashboard/weigh_in_reminder.dart';
import 'package:indifit/features/dashboard/widgets/today_check_in_card.dart';
import 'package:indifit/features/dashboard/widgets/today_weigh_in_chip.dart';
import 'package:indifit/features/progress/progress_screen.dart';
import 'package:indifit/features/progress/training_bests.dart';
import 'package:indifit/features/progress/weekly_check_in.dart';
import 'package:indifit/features/progress/weekly_check_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UR-29 / UF-18 morning weigh-in and UF-15 the Sunday check-in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('weigh-in chip rules', () {
    bool show({
      int hour = 8,
      int weekday = DateTime.monday,
      List<int> days = WeighInReminder.everyDay,
      String? dismissed,
      bool weighed = false,
      bool canLog = true,
    }) {
      // 19 Oct 2026 is a Monday.
      final now = DateTime(2026, 10, 18 + weekday, hour);
      return WeighInReminder.shouldShow(
        localNow: now,
        todayLocalDate: '2026-10-${18 + weekday}',
        days: days,
        dismissedDate: dismissed,
        weighedToday: weighed,
        canLog: canLog,
      );
    }

    test('shows every morning until noon by default', () {
      expect(show(), isTrue);
      expect(show(hour: 11), isTrue);
      expect(show(hour: 12), isFalse);
      expect(show(weekday: DateTime.sunday), isTrue);
    });

    test('hides once weighed, after "Not today", or when it cannot log', () {
      expect(show(weighed: true), isFalse);
      expect(show(dismissed: '2026-10-19'), isFalse);
      // Yesterday's "Not today" doesn't carry over.
      expect(show(dismissed: '2026-10-18'), isTrue);
      expect(show(canLog: false), isFalse);
    });

    test('only on the chosen weigh-in days', () {
      expect(show(days: const [1, 4]), isTrue);
      expect(show(weekday: DateTime.tuesday, days: const [1, 4]), isFalse);
      expect(show(days: const []), isFalse);
    });

    test('weigh-in days default to every day and read back', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(WeighInReminder.days(prefs), WeighInReminder.everyDay);
      await WeighInReminder.setDays(prefs, [6, 1, 1]);
      expect(WeighInReminder.days(prefs), [1, 6]);
    });

    test('weigh-in prefs round-trip through a backup and restore', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final prefs = await SharedPreferences.getInstance();
      await WeighInReminder.setDays(prefs, [2, 4, 6]);
      await WeighInReminder.dismissFor(prefs, '2026-10-19');
      final restored = BackupData.fromJson(
        (await BackupData.createFromDatabase(db, prefs)).toJson(),
      );
      SharedPreferences.setMockInitialValues({});
      final fresh = await SharedPreferences.getInstance();
      await restored.restoreToDatabase(db, fresh);
      expect(WeighInReminder.days(fresh), [2, 4, 6]);
      expect(
        fresh.getString(AppPreferenceKeys.prefWeighInDismissedDate),
        '2026-10-19',
      );
    });
  });

  group('weigh-in chip on Today', () {
    late AppDatabase db;
    late SharedPreferences prefs;
    setUp(() async {
      db = AppDatabase.memory();
      prefs = await SharedPreferences.getInstance();
    });
    tearDown(() => db.close());

    ProviderContainer container(DateTime now) {
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          localTimezoneServiceProvider.overrideWithValue(
            LocalTimezoneService(read: () async => 'Asia/Kolkata'),
          ),
          weighInClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('shows in the morning, hides after a weigh-in', () async {
      // The device clock is local; Kolkata's date must match it here.
      final now = DateTime.now();
      final morning = DateTime(now.year, now.month, now.day, 8);
      final c = container(morning);
      expect(await c.read(weighInChipVisibleProvider.future), isTrue);
      await c
          .read(workoutRepositoryProvider)
          .logWeightAndSyncProfile(weight: 72.5);
      c.read(weighInRevisionProvider.notifier).state++;
      expect(await c.read(weighInChipVisibleProvider.future), isFalse);
    });

    test('afternoon and "Not today" hide it', () async {
      final now = DateTime.now();
      final c = container(DateTime(now.year, now.month, now.day, 14));
      expect(await c.read(weighInChipVisibleProvider.future), isFalse);
      final morning = container(DateTime(now.year, now.month, now.day, 8));
      final today = LocalScheduleDateService().localDateFor(
        DateTime(now.year, now.month, now.day, 8).toUtc(),
        'Asia/Kolkata',
      );
      await WeighInReminder.dismissFor(prefs, today);
      expect(await morning.read(weighInChipVisibleProvider.future), isFalse);
    });

    testWidgets('the chip offers Log weight and Not today', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weighInChipVisibleProvider.overrideWith((ref) async => true),
          ],
          child: const MaterialApp(home: Scaffold(body: TodayWeighInChip())),
        ),
      );
      await tester.pump();
      expect(find.text('Morning weigh-in'), findsOneWidget);
      expect(find.text('Log weight'), findsOneWidget);
      expect(find.text('Not today'), findsOneWidget);
    });
  });

  group('calibration line after a weigh-in', () {
    AdaptiveTdeeEstimate estimate(AdaptiveTdeeConfidence confidence, int w) =>
        AdaptiveTdeeEstimate(
          currentTdeeKcal: 2200,
          baselineTdeeKcal: 2200,
          currentScaleWeightKg: 70,
          trendWeightKg: 70,
          confidence: confidence,
          confidenceMessage: '',
          loggedFoodDaysInWindow: 7,
          loggedWeightDaysInWindow: w,
          totalObservedFoodDays: 7,
          policyVersion: 'v1',
          history: const [],
        );

    test('counts the weigh-ins the engine still needs', () {
      // The engine's moderate rule needs 5 weigh-in days.
      expect(
        weighInLoggedMessage(estimate(AdaptiveTdeeConfidence.calibrating, 2)),
        'Weight logged. 3 more weigh-ins to calibrate your expenditure.',
      );
      expect(
        weighInLoggedMessage(estimate(AdaptiveTdeeConfidence.calibrating, 4)),
        'Weight logged. 1 more weigh-in to calibrate your expenditure.',
      );
      expect(
        weighInLoggedMessage(estimate(AdaptiveTdeeConfidence.moderate, 6)),
        'Weight logged.',
      );
      // Calibrating for want of food days, not weigh-ins: no count.
      expect(
        weighInLoggedMessage(estimate(AdaptiveTdeeConfidence.calibrating, 5)),
        'Weight logged.',
      );
    });
  });

  group('Sunday check-in', () {
    final dates = LocalScheduleDateService();
    const weekStart = '2026-10-12';
    const weekEnd = '2026-10-18';

    TrainingBest best(String name, double kg, int reps) {
      TrainingBestsSetFact fact(double load) => TrainingBestsSetFact(
        setId: '$name-$load',
        exerciseId: name,
        exerciseName: name,
        basis: B02LoadBasis.totalExternal,
        loadKg: load,
        reps: reps,
        performedAt: DateTime.utc(2026, 10, 14),
      );
      return TrainingBest(
        kind: TrainingBestKind.heaviest,
        set: fact(kg),
        previous: fact(kg - 2.5),
      );
    }

    test('the week is this one on Sunday, else the last full week', () {
      expect(WeeklyCheckIn.weekStartFor('2026-10-18', dates), weekStart);
      expect(WeeklyCheckIn.weekStartFor('2026-10-19', dates), weekStart);
      expect(WeeklyCheckIn.weekStartFor('2026-10-21', dates), weekStart);
    });

    test('a week with nothing logged says so', () {
      final checkIn = WeeklyCheckIn.build(
        const WeeklyCheckInInputs(
          weekStart: weekStart,
          weekEnd: weekEnd,
          workoutLocalDates: [],
          goal: 3,
        ),
      );
      expect(checkIn.workoutsDone, 0);
      expect(checkIn.bestSet, isNull);
      expect(checkIn.daysLogged, 0);
      expect(checkIn.averageProteinG, isNull);
      expect(checkIn.weightChangeKg, isNull);
      final facts = WeeklyCheckInFacts(checkIn, 'kg');
      expect(facts.workouts, '0/3 workouts');
      expect(facts.best, 'No new bests this week');
      expect(facts.protein, isNull);
      expect(facts.weight, 'No weigh-ins this week');
      expect(facts.nextWeek, 'No training days scheduled');
    });

    test('one weigh-in gives no trend', () {
      final checkIn = WeeklyCheckIn.build(
        WeeklyCheckInInputs(
          weekStart: weekStart,
          weekEnd: weekEnd,
          workoutLocalDates: const [],
          goal: 3,
          weighIns: [
            CheckInWeighIn(
              localDate: '2026-10-14',
              recordedAt: DateTime.utc(2026, 10, 14, 2),
              weightKg: 71,
            ),
          ],
        ),
      );
      expect(checkIn.weighInDays, 1);
      expect(checkIn.weightChangeKg, isNull);
      expect(
        WeeklyCheckInFacts(checkIn, 'kg').weight,
        '1 weigh-in: log another for a trend',
      );
    });

    test('a full week counts only Mon–Sun', () {
      final checkIn = WeeklyCheckIn.build(
        WeeklyCheckInInputs(
          weekStart: weekStart,
          weekEnd: weekEnd,
          workoutLocalDates: const [
            '2026-10-11', // the Sunday before
            '2026-10-12',
            '2026-10-15',
            '2026-10-18',
            '2026-10-19', // next week
          ],
          goal: 3,
          bests: [best('Squat', 80, 5), best('Bench', 60, 5)],
          proteinByLoggedDay: const {
            '2026-10-12': 90,
            '2026-10-13': 70,
            '2026-10-14': null, // logged, protein unknown
            '2026-10-20': 200,
          },
          weighIns: [
            CheckInWeighIn(
              localDate: '2026-10-12',
              recordedAt: DateTime.utc(2026, 10, 12, 2),
              weightKg: 72,
            ),
            CheckInWeighIn(
              localDate: '2026-10-18',
              recordedAt: DateTime.utc(2026, 10, 18, 2),
              weightKg: 71.6,
            ),
            // The day's last weigh-in is its value.
            CheckInWeighIn(
              localDate: '2026-10-18',
              recordedAt: DateTime.utc(2026, 10, 18, 3),
              weightKg: 71.4,
            ),
          ],
          nextWeekTrainingDates: const ['2026-10-21', '2026-10-19'],
        ),
      );
      expect(checkIn.workoutsDone, 3);
      expect(checkIn.bestSet!.exerciseName, 'Squat');
      expect(checkIn.newBests, 2);
      expect(checkIn.daysLogged, 3);
      expect(checkIn.proteinDays, 2);
      expect(checkIn.averageProteinG, 80);
      expect(checkIn.firstWeightKg, 72);
      expect(checkIn.lastWeightKg, 71.4);
      expect(checkIn.weightChangeKg, closeTo(-0.6, 1e-9));
      expect(checkIn.nextWeekTrainingDates, ['2026-10-19', '2026-10-21']);
      final facts = WeeklyCheckInFacts(checkIn, 'kg');
      expect(facts.workouts, '3/3 workouts');
      expect(facts.protein, '80 g protein a day');
      expect(facts.nextWeek, 'Mon · Wed');
      expect(weeklyCheckInShareText(checkIn, 'kg'), isNot(contains('null')));
    });

    testWidgets('the screen shows each stat, sparse data included', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final checkIn = WeeklyCheckIn.build(
        const WeeklyCheckInInputs(
          weekStart: weekStart,
          weekEnd: weekEnd,
          workoutLocalDates: ['2026-10-13'],
          goal: 3,
        ),
      );
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
      expect(find.text('12–18 Oct'), findsOneWidget);
      expect(find.text('1/3 workouts'), findsWidgets);
      expect(find.text('No weigh-ins this week'), findsWidgets);
      expect(find.text('No protein logged this week'), findsOneWidget);
      expect(find.byKey(const Key('weekly_check_in_share')), findsOneWidget);
    });
  });

  group('check-in entry points (R-5)', () {
    // Sun 18 Oct 2026 and the days around it, on the device clock.
    DateTime at(int day, int hour, [int minute = 0]) =>
        DateTime(2026, 10, day, hour, minute);
    final ist = LocalTimezoneService(read: () async => 'Asia/Kolkata');

    test('the Today card shows Sunday 12:00 to Monday 12:00', () {
      expect(CheckInReminder.titleAt(at(17, 13)), isNull); // Saturday
      expect(CheckInReminder.titleAt(at(18, 11, 59)), isNull);
      expect(CheckInReminder.titleAt(at(18, 12)), "This week's check-in");
      expect(CheckInReminder.titleAt(at(18, 23, 59)), "This week's check-in");
      expect(CheckInReminder.titleAt(at(19, 0)), "Last week's check-in");
      expect(CheckInReminder.titleAt(at(19, 11, 59)), "Last week's check-in");
      expect(CheckInReminder.titleAt(at(19, 12)), isNull);
      expect(CheckInReminder.titleAt(at(20, 9)), isNull); // Tuesday
    });

    test('Sunday and the Monday after are one check-in week', () async {
      final sunday = await checkInWeekStart(at(18, 13), ist);
      expect(sunday, '2026-10-12');
      expect(await checkInWeekStart(at(19, 9), ist), sunday);
      expect(await checkInWeekStart(at(25, 13), ist), '2026-10-19');
    });

    test('"Not now" hides it for that week only', () {
      String? title(DateTime now) => CheckInReminder.title(
        localNow: now,
        weekStart: now.day < 25 ? '2026-10-12' : '2026-10-19',
        dismissedWeek: '2026-10-12',
      );
      expect(title(at(18, 13)), isNull);
      expect(title(at(19, 9)), isNull);
      expect(title(at(25, 13)), "This week's check-in");
    });

    test('the dismissed week round-trips through a backup', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final prefs = await SharedPreferences.getInstance();
      await CheckInReminder.dismissFor(prefs, '2026-10-12');
      final restored = BackupData.fromJson(
        (await BackupData.createFromDatabase(db, prefs)).toJson(),
      );
      SharedPreferences.setMockInitialValues({});
      final fresh = await SharedPreferences.getInstance();
      await restored.restoreToDatabase(db, fresh);
      expect(
        fresh.getString(AppPreferenceKeys.prefCheckInDismissedWeek),
        '2026-10-12',
      );
    });

    final checkIn = WeeklyCheckIn.build(
      const WeeklyCheckInInputs(
        weekStart: '2026-10-12',
        weekEnd: '2026-10-18',
        workoutLocalDates: ['2026-10-13'],
        goal: 3,
      ),
    );

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
    }

    Future<SharedPreferences> pumpToday(
      WidgetTester tester,
      DateTime now, {
      SharedPreferences? prefs,
    }) async {
      prefs ??= (await tester.runAsync(SharedPreferences.getInstance))!;
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            localTimezoneServiceProvider.overrideWithValue(ist),
            weighInClockProvider.overrideWithValue(() => now),
            weeklyCheckInProvider.overrideWith((ref) async => checkIn),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: TodayCheckInCard()),
          ),
        ),
      );
      await settle(tester);
      return prefs;
    }

    testWidgets('Today: opens the check-in on Sunday afternoon', (
      tester,
    ) async {
      await pumpToday(tester, at(18, 15));
      expect(find.text("This week's check-in"), findsOneWidget);
      await tester.tap(find.byKey(const Key('today_check_in_open')));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyCheckInScreen), findsOneWidget);
      expect(find.text('12–18 Oct'), findsOneWidget);
    });

    testWidgets('Today: "Not now" on Sunday hides it on Monday too', (
      tester,
    ) async {
      final prefs = await pumpToday(tester, at(18, 15));
      await tester.tap(find.byKey(const Key('today_check_in_not_now')));
      await settle(tester);
      expect(find.byKey(const Key('today_check_in')), findsNothing);
      await pumpToday(tester, at(19, 9), prefs: prefs);
      expect(find.byKey(const Key('today_check_in')), findsNothing);
      await pumpToday(tester, at(25, 15), prefs: prefs);
      expect(find.text("This week's check-in"), findsOneWidget);
    });

    testWidgets('Today: Monday morning says last week, then goes', (
      tester,
    ) async {
      await pumpToday(tester, at(19, 9));
      expect(find.text("Last week's check-in"), findsOneWidget);
      await pumpToday(tester, at(19, 13));
      expect(find.byKey(const Key('today_check_in')), findsNothing);
    });

    for (final withData in [false, true]) {
      testWidgets(
        'Progress: the check-in row shows ${withData ? 'with' : 'without'} data',
        (tester) async {
          tester.view.physicalSize = const Size(390, 2400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                weeklyCheckInProvider.overrideWith((ref) async => checkIn),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: Scaffold(
                  body: ProgressScreen(
                    preview: ProgressDashboardSnapshot(
                      nowUtc: DateTime.utc(2026, 10, 20, 6),
                      timezoneId: 'Asia/Kolkata',
                      todayLocalDate: '2026-10-20',
                      measurements: const [],
                      workouts: [
                        if (withData)
                          ProgressWorkoutRecord(
                            id: 1,
                            name: 'Workout 1',
                            completedAtUtc: DateTime.utc(2026, 10, 19, 6),
                            localDate: '2026-10-19',
                            activityType: 'strength',
                            totalVolumeKg: 3000,
                            volumeIsTrustworthy: true,
                          ),
                      ],
                      weeklyTrainedDates: {if (withData) '2026-10-19'},
                      strengthSets: const [],
                      muscleBalance: null,
                      unavailableSections: const {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final row = find.byKey(const Key('progress_check_in_row'));
          expect(row, findsOneWidget);
          expect(find.text("This week's check-in"), findsOneWidget);
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(find.byType(WeeklyCheckInScreen), findsOneWidget);
        },
      );
    }
  });

  test('the weekly progress reminder opens the check-in', () {
    expect(
      NotificationService.destinationForPayload('weekly_report'),
      '/weekly-check-in',
    );
  });
}
