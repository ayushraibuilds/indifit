import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/training_day_schedule.dart';
import 'package:indifit/core/utils/weekly_training_goal_calculator.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/plan_schedule_reader.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/features/training/plan_start_sheet.dart';

/// UR-20 / UF-11: start a plan today or on its first day, on the user's
/// training days, and shift the plan when a workout starts early.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProgramRepository programs;

  setUp(() async {
    db = AppDatabase.memory();
    programs = ProgramRepository(db);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('exercise-squat-v1'),
            name: 'Back Squat',
            muscleGroups: 'Legs',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Knees in',
          ),
        );
  });

  tearDown(() => db.close());

  /// Two weeks of Full Body A/B/C on Monday, Wednesday and Friday.
  Future<String> createPlan() async {
    const weekdays = [DateTime.monday, DateTime.wednesday, DateTime.friday];
    final programId = await programs.createProgram(
      name: 'Full Body',
      blocks: [
        ProgramBlockInput(
          name: 'Block 1',
          ordinal: 0,
          weeks: [
            for (var week = 0; week < 2; week++)
              ProgramWeekInput(
                name: 'Week ${week + 1}',
                ordinalInBlock: week,
                programWeekOrdinal: week,
                templates: [
                  for (var i = 0; i < 3; i++)
                    SessionTemplateInput(
                      name: 'Full Body ${'ABC'[i]}',
                      ordinal: i,
                      plannedWeekday: weekdays[i],
                      prescriptions: const [
                        ExercisePrescriptionInput(
                          exerciseId: 'exercise-squat-v1',
                          exerciseNameSnapshot: 'Back Squat',
                          plannedSets: 3,
                          repsRange: '5',
                          ordinal: 0,
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ],
    );
    return (await programs.getVersionsForProgram(programId)).single.id;
  }

  LocalScheduleDateService datesAt(DateTime nowUtc) =>
      LocalScheduleDateService(nowUtc: () => nowUtc);

  Future<List<ScheduledSessionOccurrence>> activate({
    required DateTime nowUtc,
    required String startLocalDate,
    required String timezoneId,
    List<int>? trainingWeekdays,
  }) async {
    final coordinator = ProgramActivationCoordinator(
      db,
      dates: datesAt(nowUtc),
      nowUtc: () => nowUtc,
    );
    final result = await coordinator.activate(
      ActivateProgramVersionCommand(
        programVersionId: await createPlan(),
        commandId: 'activate-1',
        activationLocalDate: startLocalDate,
        timezoneId: timezoneId,
        trainingWeekdays: trainingWeekdays,
      ),
    );
    return result.occurrences;
  }

  Future<List<ScheduledSessionOccurrence>> planRows() async {
    final rows = await db.select(db.scheduledSessionOccurrences).get();
    return rows..sort((a, b) {
      final byWeek = a.programWeekOrdinal.compareTo(b.programWeekOrdinal);
      return byWeek == 0
          ? a.sessionOrdinal.compareTo(b.sessionOrdinal)
          : byWeek;
    });
  }

  List<String> datesOf(Iterable<ScheduledSessionOccurrence> rows) =>
      rows.map((row) => row.effectiveLocalDate).toList();

  // Saturday 17 Oct 2026, mid-morning in India.
  final saturdayIst = DateTime.utc(2026, 10, 17, 5);
  const ist = 'Asia/Kolkata';
  const monWedFri = [DateTime.monday, DateTime.wednesday, DateTime.friday];

  group('choosing when to start', () {
    test('starting today puts the first workout today', () async {
      final rows = await activate(
        nowUtc: saturdayIst,
        startLocalDate: '2026-10-17',
        timezoneId: ist,
        trainingWeekdays: monWedFri,
      );
      expect(datesOf(rows), [
        '2026-10-17',
        '2026-10-19',
        '2026-10-21',
        '2026-10-23',
        '2026-10-26',
        '2026-10-28',
      ]);
      expect(rows.map((row) => row.status).toSet(), {'planned'});
    });

    test('starting on the first training day keeps the plan days', () async {
      final rows = await activate(
        nowUtc: saturdayIst,
        startLocalDate: '2026-10-19',
        timezoneId: ist,
        trainingWeekdays: monWedFri,
      );
      expect(datesOf(rows), [
        '2026-10-19',
        '2026-10-21',
        '2026-10-23',
        '2026-10-26',
        '2026-10-28',
        '2026-10-30',
      ]);
    });

    test('custom training days are used and remembered', () async {
      const tueThuSat = [
        DateTime.tuesday,
        DateTime.thursday,
        DateTime.saturday,
      ];
      final first = TrainingDaySchedule.firstTrainingDayOnOrAfter(
        dates: datesAt(saturdayIst),
        timezoneId: ist,
        fromLocalDate: '2026-10-17',
        weekdays: tueThuSat,
      );
      expect(first, '2026-10-17');
      final rows = await activate(
        nowUtc: saturdayIst,
        startLocalDate: first,
        timezoneId: ist,
        trainingWeekdays: tueThuSat,
      );
      expect(datesOf(rows), [
        '2026-10-17',
        '2026-10-20',
        '2026-10-22',
        '2026-10-24',
        '2026-10-27',
        '2026-10-29',
      ]);
      final shape = await PlanScheduleReader(
        db,
        datesAt(saturdayIst),
      ).read(rows.first.programVersionId);
      expect(shape!.trainingWeekdays, tueThuSat);
      expect(shape.firstLocalDate, '2026-10-17');
      expect(shape.sessionsPerWeek, 3);
    });

    test('a plan without chosen days reads its planned weekdays', () async {
      final rows = await activate(
        nowUtc: saturdayIst,
        startLocalDate: '2026-10-17',
        timezoneId: ist,
      );
      final shape = await PlanScheduleReader(
        db,
        datesAt(saturdayIst),
      ).read(rows.first.programVersionId);
      expect(shape!.trainingWeekdays, monWedFri);
      expect(shape.firstLocalDate, '2026-10-19');
    });

    test('a non-IST zone keeps civil weekdays across a DST change', () async {
      // US clocks go back on Sunday 1 Nov 2026.
      final rows = await activate(
        nowUtc: DateTime.utc(2026, 10, 31, 15),
        startLocalDate: '2026-10-31',
        timezoneId: 'America/New_York',
        trainingWeekdays: monWedFri,
      );
      expect(datesOf(rows), [
        '2026-10-31',
        '2026-11-02',
        '2026-11-04',
        '2026-11-06',
        '2026-11-09',
        '2026-11-11',
      ]);
      final dates = datesAt(DateTime.utc(2026, 10, 31, 15));
      for (final row in rows.skip(1)) {
        expect(
          monWedFri,
          contains(dates.weekday(row.effectiveLocalDate, 'America/New_York')),
        );
      }
    });
  });

  testWidgets('the start sheet asks when and which days', (tester) async {
    PlanStartChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              choice = await showPlanStartSheet(
                context,
                planName: 'Full Body',
                todayLocalDate: '2026-10-17',
                timezoneId: ist,
                dates: datesAt(saturdayIst),
                planWeekdays: monWedFri,
                sessionsPerWeek: 3,
              );
            },
            child: const Text('Use this plan'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Use this plan'));
    await tester.pumpAndSettle();

    expect(find.text('When do you want to start?'), findsOneWidget);
    expect(find.text('Which days do you train?'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Mon, 19 Oct'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('plan_start_today')))
          .selected,
      isTrue,
    );

    // Exactly the plan's three days are needed.
    await tester.tap(find.byKey(const ValueKey('plan_start_day_3')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('plan_start_confirm')),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('(2 picked)'), findsOneWidget);

    // Saturday is a training day now, so the plan's first day is today.
    await tester.tap(find.byKey(const ValueKey('plan_start_day_6')));
    await tester.pump();
    expect(find.byKey(const ValueKey('plan_start_first_day')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plan_start_confirm')));
    await tester.pumpAndSettle();
    expect(choice!.startLocalDate, '2026-10-17');
    expect(choice!.trainingWeekdays, [1, 5, 6]);
  });

  testWidgets('choosing the first day starts the plan then', (tester) async {
    PlanStartChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              choice = await showPlanStartSheet(
                context,
                planName: 'Full Body',
                todayLocalDate: '2026-10-17',
                timezoneId: ist,
                dates: datesAt(saturdayIst),
                planWeekdays: monWedFri,
                sessionsPerWeek: 3,
              );
            },
            child: const Text('Use this plan'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Use this plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan_start_first_day')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan_start_confirm')));
    await tester.pumpAndSettle();
    expect(choice!.startLocalDate, '2026-10-19');
    expect(choice!.trainingWeekdays, monWedFri);
  });

  group('starting a workout early', () {
    late CalendarRepository calendar;

    Future<List<ScheduledSessionOccurrence>> activateFromMonday() async {
      calendar = CalendarRepository(
        db,
        dates: datesAt(saturdayIst),
        nowUtc: () => saturdayIst,
      );
      return activate(
        nowUtc: saturdayIst,
        startLocalDate: '2026-10-19',
        timezoneId: ist,
        trainingWeekdays: monWedFri,
      );
    }

    Future<void> startEarly(String occurrenceId, String commandId) async {
      final row = (await calendar.getOccurrence(occurrenceId))!;
      await calendar.start(
        StartOccurrenceCommand(
          occurrenceId: occurrenceId,
          commandId: commandId,
          expectedStatus: OccurrenceStatus.values.firstWhere(
            (status) => status.dbValue == row.status,
          ),
          confirmedOutsideEffectiveDate: true,
        ),
      );
    }

    Future<OccurrenceMutationResult> discard(
      String occurrenceId,
      String commandId,
    ) => calendar.discardStarted(
      DiscardStartedOccurrenceCommand(
        occurrenceId: occurrenceId,
        commandId: commandId,
        expectedStatus: OccurrenceStatus.inProgress,
      ),
    );

    const planDays = [
      '2026-10-19',
      '2026-10-21',
      '2026-10-23',
      '2026-10-26',
      '2026-10-28',
      '2026-10-30',
    ];

    Future<List<OccurrenceEvent>> revertEvents() async =>
        (await db.select(db.occurrenceEvents).get())
            .where((event) => event.reason == 'Early start discarded')
            .toList();

    group('then discarding it (R-7)', () {
      test('puts it and the shifted plan back on their days', () async {
        final rows = await activateFromMonday();
        await startEarly(rows.first.id, 'start-early');
        final result = await discard(rows.first.id, 'discard');

        expect(result.occurrence.effectiveLocalDate, '2026-10-19');
        expect(result.event.afterLocalDate, '2026-10-19');
        final after = await planRows();
        expect(datesOf(after), planDays);
        expect(after.map((row) => row.status).toSet(), {'planned'});
        final reverts = await revertEvents();
        expect(reverts, hasLength(5));
        for (final event in reverts) {
          expect(event.eventType, 'rescheduled');
          expect(event.commandId, 'discard');
        }
      });

      test('leaves a workout moved after the shift where it is', () async {
        final rows = await activateFromMonday();
        await startEarly(rows.first.id, 'start-early');
        // C was shifted to Wed 21; the user then moves it to Thu 22.
        await calendar.reschedule(
          RescheduleOccurrenceCommand(
            occurrenceId: rows[2].id,
            commandId: 'move-c',
            expectedStatus: OccurrenceStatus.rescheduled,
            effectiveLocalDate: '2026-10-22',
            effectiveTimezoneId: ist,
            confirmed: true,
          ),
        );
        await discard(rows.first.id, 'discard');

        final after = await planRows();
        expect(after[2].effectiveLocalDate, '2026-10-22');
        expect(after[2].status, 'rescheduled');
        expect(datesOf([after[0], after[1], ...after.skip(3)]), [
          planDays[0],
          planDays[1],
          ...planDays.skip(3),
        ]);
        expect(await revertEvents(), hasLength(4));
      });

      test('a second discard changes nothing', () async {
        final rows = await activateFromMonday();
        await startEarly(rows.first.id, 'start-early');
        await discard(rows.first.id, 'discard');
        final once = datesOf(await planRows());
        final eventsOnce = await db.select(db.occurrenceEvents).get();

        final replay = await discard(rows.first.id, 'discard');
        expect(replay.wasIdempotent, isTrue);
        await expectLater(
          discard(rows.first.id, 'discard-2'),
          throwsA(isA<InvalidOccurrenceTransitionException>()),
        );
        expect(datesOf(await planRows()), once);
        expect(
          await db.select(db.occurrenceEvents).get(),
          hasLength(eventsOnce.length),
        );
      });

      test('a workout started on its own day is discarded as before', () async {
        final monday = DateTime.utc(2026, 10, 19, 5);
        final rows = await activate(
          nowUtc: monday,
          startLocalDate: '2026-10-19',
          timezoneId: ist,
          trainingWeekdays: monWedFri,
        );
        calendar = CalendarRepository(
          db,
          dates: datesAt(monday),
          nowUtc: () => monday,
        );
        await calendar.start(
          StartOccurrenceCommand(
            occurrenceId: rows.first.id,
            commandId: 'start',
            expectedStatus: OccurrenceStatus.planned,
          ),
        );
        final result = await discard(rows.first.id, 'discard');

        expect(result.occurrence.status, 'planned');
        expect(datesOf(await planRows()), planDays);
        expect(await revertEvents(), isEmpty);
      });

      test('works outside India', () async {
        // Saturday 31 Oct, afternoon in New York; the plan starts Mon 2 Nov.
        final saturdayNy = DateTime.utc(2026, 10, 31, 18);
        const ny = 'America/New_York';
        final rows = await activate(
          nowUtc: saturdayNy,
          startLocalDate: '2026-11-02',
          timezoneId: ny,
          trainingWeekdays: monWedFri,
        );
        calendar = CalendarRepository(
          db,
          dates: datesAt(saturdayNy),
          nowUtc: () => saturdayNy,
        );
        final planned = datesOf(await planRows());
        await startEarly(rows.first.id, 'start-early');
        expect((await planRows()).first.effectiveLocalDate, '2026-10-31');
        await discard(rows.first.id, 'discard');

        final after = await planRows();
        expect(datesOf(after), planned);
        expect(after.map((row) => row.effectiveTimezoneId).toSet(), {ny});
        expect(after.map((row) => row.status).toSet(), {'planned'});
      });
    });

    test(
      'moves it to today and shifts only later unstarted workouts',
      () async {
        final rows = await activateFromMonday();
        await startEarly(rows.first.id, 'start-early');

        final after = await planRows();
        expect(after.first.status, 'inProgress');
        expect(after.first.effectiveLocalDate, '2026-10-17');
        expect(datesOf(after.skip(1)), [
          '2026-10-19',
          '2026-10-21',
          '2026-10-23',
          '2026-10-26',
          '2026-10-28',
        ]);
        // Original dates are history; only effective dates move.
        expect(after.map((row) => row.originalLocalDate).toList(), [
          '2026-10-19',
          '2026-10-21',
          '2026-10-23',
          '2026-10-26',
          '2026-10-28',
          '2026-10-30',
        ]);
        expect(after.skip(1).map((row) => row.status).toSet(), {'rescheduled'});
      },
    );

    test('repeating it is a no-op', () async {
      final rows = await activateFromMonday();
      await startEarly(rows.first.id, 'start-early');
      final once = datesOf(await planRows());
      final eventsOnce = await db.select(db.occurrenceEvents).get();

      // The same command again is idempotent.
      await startEarly(rows.first.id, 'start-early');
      expect(datesOf(await planRows()), once);
      expect(
        await db.select(db.occurrenceEvents).get(),
        hasLength(eventsOnce.length),
      );

      // Discarding puts the plan back (R-7); starting B early then lays A
      // and the rest from Monday.
      await discard(rows.first.id, 'discard');
      await startEarly(rows[1].id, 'start-early-again');
      final again = await planRows();
      expect(again[1].effectiveLocalDate, '2026-10-17');
      expect(again[0].effectiveLocalDate, '2026-10-19');
      expect(datesOf(again.skip(2)), [
        '2026-10-21',
        '2026-10-23',
        '2026-10-26',
        '2026-10-28',
      ]);
    });

    test('never moves finished, partial or skipped workouts', () async {
      final rows = await activateFromMonday();
      await calendar.skip(
        SkipOccurrenceCommand(
          occurrenceId: rows[2].id,
          commandId: 'skip-c',
          expectedStatus: OccurrenceStatus.planned,
          disposition: SkipDisposition.advance,
        ),
      );
      await (db.update(
        db.scheduledSessionOccurrences,
      )..where((table) => table.id.equals(rows[3].id))).write(
        const ScheduledSessionOccurrencesCompanion(status: Value('completed')),
      );
      await (db.update(
        db.scheduledSessionOccurrences,
      )..where((table) => table.id.equals(rows[4].id))).write(
        const ScheduledSessionOccurrencesCompanion(
          status: Value('partiallyCompleted'),
        ),
      );
      final before = {for (final row in await planRows()) row.id: row};
      final eventsBefore = {
        for (final id in [rows[2].id, rows[3].id, rows[4].id])
          id: await calendar.getOccurrenceHistory(id),
      };

      await startEarly(rows.first.id, 'start-early');

      final after = {for (final row in await planRows()) row.id: row};
      for (final id in [rows[2].id, rows[3].id, rows[4].id]) {
        expect(after[id], before[id], reason: 'history row $id changed');
        expect(
          await calendar.getOccurrenceHistory(id),
          hasLength(eventsBefore[id]!.length),
        );
      }
      // The unstarted ones still shift, in order, onto training days.
      expect(after[rows[1].id]!.effectiveLocalDate, '2026-10-19');
      expect(after[rows[5].id]!.effectiveLocalDate, '2026-10-21');
    });
  });

  group('first-week goal', () {
    final dates = LocalScheduleDateService();

    WeeklyTrainingGoalStatus planWeek({
      required int completed,
      required int goal,
      String weekStart = '2026-10-12',
    }) => WeeklyTrainingGoalStatus(
      weekStartLocalDate: weekStart,
      completed: completed,
      goal: goal,
      weeksInARow: 0,
      source: WeeklyTrainingGoalSource.plan,
    );

    test('is pro-rated in the week the plan starts', () {
      final status = WeeklyTrainingGoalCalculator.withPlanSchedule(
        planWeek(completed: 0, goal: 1),
        sessionsPerWeek: 3,
        planFirstLocalDate: '2026-10-17',
        dates: dates,
      );
      expect(status.goal, 1);
      expect(status.planFullWeeksFromLocalDate, '2026-10-19');
      expect(
        WeeklyTrainingGoalCopy.planPace(status),
        '3 a week from Mon, 19 Oct',
      );
      expect(
        WeeklyTrainingGoalCopy.summary(status),
        '0 of 1 workouts this week · 3 a week from Mon, 19 Oct',
      );
    });

    test('a plan started on a Sunday counts that one workout', () async {
      final sunday = DateTime.utc(2026, 10, 18, 5);
      final rows = await activate(
        nowUtc: sunday,
        startLocalDate: '2026-10-18',
        timezoneId: ist,
        trainingWeekdays: monWedFri,
      );
      final thisWeek = rows
          .where((row) => row.effectiveLocalDate.compareTo('2026-10-18') <= 0)
          .length;
      expect(thisWeek, 1);
      final shape = await PlanScheduleReader(
        db,
        datesAt(sunday),
      ).read(rows.first.programVersionId);
      final status = WeeklyTrainingGoalCalculator.withPlanSchedule(
        planWeek(completed: 1, goal: thisWeek),
        sessionsPerWeek: shape!.sessionsPerWeek,
        planFirstLocalDate: shape.firstLocalDate,
        dates: dates,
      );
      expect(
        WeeklyTrainingGoalCopy.summary(status),
        'Week goal done · 1 of 1 workouts this week · 3 a week from Mon, 19 Oct',
      );
    });

    test('says when a plan that starts next week begins', () {
      final status = WeeklyTrainingGoalCalculator.withPlanSchedule(
        const WeeklyTrainingGoalStatus(
          weekStartLocalDate: '2026-10-12',
          completed: 0,
          goal: 3,
          weeksInARow: 0,
          source: WeeklyTrainingGoalSource.user,
        ),
        sessionsPerWeek: 3,
        planFirstLocalDate: '2026-10-19',
        dates: dates,
      );
      expect(status.goal, 3);
      expect(
        WeeklyTrainingGoalCopy.planPace(status),
        'Plan starts Mon, 19 Oct · 3 a week',
      );
    });

    test('a full plan week has no pace line', () {
      final status = WeeklyTrainingGoalCalculator.withPlanSchedule(
        planWeek(completed: 1, goal: 3, weekStart: '2026-10-19'),
        sessionsPerWeek: 3,
        planFirstLocalDate: '2026-10-17',
        dates: dates,
      );
      expect(WeeklyTrainingGoalCopy.planPace(status), isNull);
    });
  });
}
