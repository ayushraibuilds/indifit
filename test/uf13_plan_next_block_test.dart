import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart' hide Table, Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/di/core_providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/plan_library_read_repository.dart';
import 'package:indifit/data/repositories/plan_next_block_repository.dart';
import 'package:indifit/data/repositories/plan_schedule_reader.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_lifecycle_repository.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/features/training/plan_finished_choices.dart';
import 'package:indifit/features/training/training_plan_lifecycle_controller.dart';
import 'package:indifit/features/training/training_providers.dart';

/// UF-13: what happens after the last workout of a plan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Thursday 15 Oct 2026, India.
  final now = DateTime.utc(2026, 10, 15, 5);
  const ist = 'Asia/Kolkata';
  late AppDatabase db;
  late ProgramRepository programs;
  late LocalScheduleDateService dates;
  late PlanNextBlockRepository nextBlock;
  late ProgramActivationCoordinator activation;
  late ProgramLifecycleRepository lifecycle;

  const exercises = {
    'exercise-squat': 'Back Squat',
    'exercise-curl': 'Biceps Curl',
    'exercise-bench': 'Bench Press',
    'exercise-row': 'Barbell Row',
  };

  setUp(() async {
    db = AppDatabase.memory();
    programs = ProgramRepository(db);
    dates = LocalScheduleDateService(nowUtc: () => now);
    nextBlock = PlanNextBlockRepository(db, programs: programs, dates: dates);
    activation = ProgramActivationCoordinator(
      db,
      dates: dates,
      nowUtc: () => now,
    );
    lifecycle = ProgramLifecycleRepository(db, nowUtc: () => now);
    for (final entry in exercises.entries) {
      await db
          .into(db.exercises)
          .insert(
            ExercisesCompanion.insert(
              stableId: Value(entry.key),
              name: entry.value,
              muscleGroups: 'Legs',
              equipment: 'Barbell',
              difficulty: 'Intermediate',
              formCues: 'Brace',
              commonMistakes: 'None',
            ),
          );
    }
  });

  tearDown(() => db.close());

  ExercisePrescriptionInput prescription(String id, int ordinal) =>
      ExercisePrescriptionInput(
        exerciseId: id,
        exerciseNameSnapshot: exercises[id]!,
        plannedSets: 3,
        repsRange: '5',
        ordinal: ordinal,
      );

  /// One week: Monday squat then curl, Wednesday bench then row.
  Future<List<ScheduledSessionOccurrence>> activatePlan() async {
    final programId = await programs.createProgram(
      name: 'Strength Block',
      blocks: [
        ProgramBlockInput(
          name: 'Block 1',
          ordinal: 0,
          weeks: [
            ProgramWeekInput(
              name: 'Week 1',
              ordinalInBlock: 0,
              programWeekOrdinal: 0,
              templates: [
                SessionTemplateInput(
                  name: 'Lower',
                  ordinal: 0,
                  plannedWeekday: DateTime.monday,
                  prescriptions: [
                    prescription('exercise-squat', 0),
                    prescription('exercise-curl', 1),
                  ],
                ),
                SessionTemplateInput(
                  name: 'Upper',
                  ordinal: 1,
                  plannedWeekday: DateTime.wednesday,
                  prescriptions: [
                    prescription('exercise-bench', 0),
                    prescription('exercise-row', 1),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    final versionId = (await programs.getVersionsForProgram(
      programId,
    )).single.id;
    return (await activation.activate(
      ActivateProgramVersionCommand(
        programVersionId: versionId,
        commandId: 'activate-block-1',
        activationLocalDate: '2026-10-12',
        timezoneId: ist,
        trainingWeekdays: const [DateTime.monday, DateTime.wednesday],
      ),
    )).occurrences;
  }

  Future<void> complete(String occurrenceId) =>
      (db.update(
        db.scheduledSessionOccurrences,
      )..where((table) => table.id.equals(occurrenceId))).write(
        const ScheduledSessionOccurrencesCompanion(status: Value('completed')),
      );

  /// Logs one session for [occurrence]: per exercise, working sets with
  /// [loads] against that exercise's prescription.
  Future<void> logSession(
    ScheduledSessionOccurrence occurrence,
    Map<String, List<double?>> loadsByExercise,
  ) async {
    final sessionId = await db
        .into(db.workoutSessions)
        .insert(
          WorkoutSessionsCompanion.insert(
            name: 'Session',
            totalVolume: 0,
            durationSeconds: 60,
            estimatedCalories: 10,
            completedAt: Value(now),
            scheduledOccurrenceId: Value(occurrence.id),
          ),
        );
    var ordinal = 0;
    for (final entry in loadsByExercise.entries) {
      final exerciseId = entry.key;
      final loads = entry.value;
      final prescriptionId =
          (await (db.select(db.exercisePrescriptions)..where(
                    (table) =>
                        table.sessionTemplateId.equals(
                          occurrence.sessionTemplateId,
                        ) &
                        table.exerciseId.equals(exerciseId),
                  ))
                  .getSingle())
              .id;
      final performedId = 'performed-$exerciseId-$sessionId';
      await db
          .into(db.performedExercises)
          .insert(
            PerformedExercisesCompanion.insert(
              id: performedId,
              sessionId: sessionId,
              sourceExercisePrescriptionId: Value(prescriptionId),
              ordinal: ordinal++,
              actualExerciseId: exerciseId,
              actualExerciseNameSnapshot: exercises[exerciseId]!,
              status: const Value('completed'),
            ),
          );
      for (var i = 0; i < loads.length; i++) {
        await db
            .into(db.performedSets)
            .insert(
              PerformedSetsCompanion.insert(
                id: '$performedId-$i',
                performedExerciseId: performedId,
                ordinal: i,
                role: 'working',
                actualLoadKg: Value(loads[i]),
                actualLoadBasis: Value(
                  loads[i] == null ? 'bodyweight' : 'totalExternal',
                ),
                actualReps: const Value(5),
              ),
            );
      }
    }
  }

  group('Plan finished', () {
    test('not while a workout is still ahead', () async {
      final rows = await activatePlan();
      await complete(rows.first.id);
      // Wednesday's workout was rescheduled past today.
      await (db.update(
        db.scheduledSessionOccurrences,
      )..where((table) => table.id.equals(rows.last.id))).write(
        const ScheduledSessionOccurrencesCompanion(
          effectiveLocalDate: Value('2026-10-16'),
        ),
      );
      expect(
        await nextBlock.readFinished(todayLocalDate: '2026-10-15'),
        isNull,
      );
    });

    test('once the last workout is done', () async {
      final rows = await activatePlan();
      for (final row in rows) {
        await complete(row.id);
      }
      final finished = await nextBlock.readFinished(
        todayLocalDate: '2026-10-15',
      );
      expect(finished, isNotNull);
      expect(finished!.planName, 'Strength Block');
      expect(finished.completedCount, 2);
      expect(finished.schedule!.trainingWeekdays, [1, 3]);
    });

    test('once its end date passes with a workout left undone', () async {
      final rows = await activatePlan();
      await complete(rows.first.id);
      // Wednesday 14 Oct is behind Thursday 15 Oct and never started.
      final finished = await nextBlock.readFinished(
        todayLocalDate: '2026-10-15',
      );
      expect(finished, isNotNull);
      expect(finished!.completedCount, 1);
    });
  });

  group('the three choices', () {
    Future<FinishedPlanState> finishWithLogs() async {
      final rows = await activatePlan();
      final lower = rows.firstWhere((row) => row.sessionOrdinal == 0);
      final upper = rows.firstWhere((row) => row.sessionOrdinal == 1);
      await logSession(lower, {
        'exercise-squat': [90, 100, 95],
        'exercise-curl': [20, 22.5],
      });
      // Bench was logged without a weight; row is not a main lift.
      await logSession(upper, {
        'exercise-bench': [null, null],
        'exercise-row': [60],
      });
      for (final row in rows) {
        await complete(row.id);
      }
      return (await nextBlock.readFinished(todayLocalDate: '2026-10-15'))!;
    }

    Future<Map<String, ScheduledSessionOccurrence>> snapshotRows() async => {
      for (final row in await db.select(db.scheduledSessionOccurrences).get())
        row.id: row,
    };

    test('+2.5 kg applies only to main lifts with a logged weight', () async {
      final finished = await finishWithLogs();
      expect(finished.increases.map((lift) => lift.exerciseId), [
        'exercise-squat',
      ]);
      expect(finished.increases.single.lastTopKg, 100);
      expect(finished.increases.single.nextTargetKg, 102.5);
      expect(
        finished.increaseRule,
        "+2.5 kg on back squat from last block's top sets",
      );
    });

    test('repeat as it is keeps targets and history', () async {
      final finished = await finishWithLogs();
      final history = await snapshotRows();
      final draft = await nextBlock.prepareNextBlock(
        finishedVersionId: finished.programVersionId,
      );
      final result = await nextBlock.startNextBlock(
        lifecycle: lifecycle,
        activation: activation,
        draftVersionId: draft,
        commandId: 'next-block',
        startLocalDate: '2026-10-15',
        timezoneId: ist,
        trainingWeekdays: const [DateTime.monday, DateTime.wednesday],
      );

      expect(result.programVersionId, draft);
      expect(result.occurrences.map((row) => row.effectiveLocalDate), [
        '2026-10-15',
        '2026-10-19',
      ]);
      final settings = await db.select(db.trainingPlanSettings).getSingle();
      expect(settings.activeProgramVersionId, draft);
      final after = await snapshotRows();
      for (final entry in history.entries) {
        expect(after[entry.key], entry.value, reason: 'history changed');
      }
      final nextSets = await db.select(db.strengthSetPrescriptions).get();
      expect(nextSets, isEmpty);
    });

    test('repeat with +2.5 kg sets only the main lift targets', () async {
      final finished = await finishWithLogs();
      final history = await snapshotRows();
      final draft = await nextBlock.prepareNextBlock(
        finishedVersionId: finished.programVersionId,
        increases: finished.increases,
      );
      await nextBlock.startNextBlock(
        lifecycle: lifecycle,
        activation: activation,
        draftVersionId: draft,
        commandId: 'next-block-heavier',
        startLocalDate: '2026-10-19',
        timezoneId: ist,
        trainingWeekdays: const [DateTime.monday, DateTime.wednesday],
      );

      final detail = (await programs.getProgramVersionDetail(draft))!;
      final byExercise = {
        for (final p in detail.exercisePrescriptions) p.exerciseId: p,
      };
      final sets = await db.select(db.strengthSetPrescriptions).get();
      final squatSets = sets
          .where(
            (set) =>
                set.exercisePrescriptionId == byExercise['exercise-squat']!.id,
          )
          .toList();
      expect(squatSets, hasLength(3));
      expect(squatSets.map((set) => set.targetLoadKg).toSet(), {102.5});
      expect(squatSets.first.loadBasis, 'totalExternal');
      // Bench had no weight, row and curl are not main lifts.
      expect(
        sets.where(
          (set) =>
              set.exercisePrescriptionId != byExercise['exercise-squat']!.id,
        ),
        isEmpty,
      );
      final after = await snapshotRows();
      for (final entry in history.entries) {
        expect(after[entry.key], entry.value, reason: 'history changed');
      }
    });

    test('a failed start leaves the finished plan current', () async {
      final finished = await finishWithLogs();
      final draft = await nextBlock.prepareNextBlock(
        finishedVersionId: finished.programVersionId,
      );
      await expectLater(
        nextBlock.startNextBlock(
          lifecycle: lifecycle,
          activation: activation,
          draftVersionId: draft,
          commandId: 'next-block-bad',
          startLocalDate: '2026-10-15',
          timezoneId: ist,
          trainingWeekdays: const [],
        ),
        throwsA(isA<ActivationRejectedException>()),
      );
      final settings = await db.select(db.trainingPlanSettings).getSingle();
      expect(settings.activeProgramVersionId, finished.programVersionId);
    });

    test('picking the next plan finishes this one first', () async {
      final finished = await finishWithLogs();
      await lifecycle.endActivePlan(
        const EndActivePlanCommand(
          outcome: PlanEndOutcome.finished,
          commandId: 'pick-next',
        ),
      );
      final settings = await db.select(db.trainingPlanSettings).getSingle();
      expect(settings.activeProgramVersionId, isNull);
      expect(settings.lastEndedProgramVersionId, finished.programVersionId);
      expect(settings.lastEndedOutcome, 'finished');
    });
  });

  group('Plan finished choices', () {
    const squat = MainLiftIncrease(
      exerciseId: 'exercise-squat',
      name: 'Back Squat',
      lastTopKg: 100,
      loadBasis: 'totalExternal',
    );
    FinishedPlanState finishedState({List<MainLiftIncrease>? increases}) =>
        FinishedPlanState(
          programVersionId: 'finished-version',
          planName: 'Full Body',
          completedCount: 12,
          increases: increases ?? const [squat],
          schedule: const PlanScheduleShape(
            trainingWeekdays: [1, 3, 5],
            firstLocalDate: '2026-09-21',
          ),
        );

    late _RecordingNextBlock fake;
    late _RecordingLifecycle lifecycleFake;
    late int changed;

    Future<void> pumpChoices(
      WidgetTester tester,
      FinishedPlanState state,
    ) async {
      fake = _RecordingNextBlock(db, programs, dates);
      lifecycleFake = _RecordingLifecycle(lifecycle);
      changed = 0;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: SingleChildScrollView(
                child: PlanFinishedChoices(
                  finished: state,
                  onChanged: () => changed++,
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/plan-library',
            builder: (context, routerState) =>
                Scaffold(body: Text('library ${routerState.uri}')),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            localScheduleDateServiceProvider.overrideWithValue(dates),
            localTimezoneServiceProvider.overrideWithValue(
              LocalTimezoneService(read: () async => ist),
            ),
            planNextBlockRepositoryProvider.overrideWithValue(fake),
            trainingPlanLifecycleControllerProvider.overrideWithValue(
              lifecycleFake,
            ),
            planLibraryReadRepositoryProvider.overrideWithValue(
              _NoEntryLibrary(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> confirmStartSheet(WidgetTester tester) async {
      await tester.pumpAndSettle();
      expect(find.text('When do you want to start?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan_start_confirm')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the three choices and names the rule', (tester) async {
      await pumpChoices(tester, finishedState());
      expect(find.text('Plan finished'), findsOneWidget);
      expect(find.text('Repeat as it is'), findsOneWidget);
      expect(find.text('Repeat with +2.5 kg on main lifts'), findsOneWidget);
      expect(find.text('Pick the next plan'), findsOneWidget);
      expect(
        find.text("+2.5 kg on back squat from last block's top sets"),
        findsOneWidget,
      );
    });

    testWidgets('repeat as it is reuses the start sheet', (tester) async {
      await pumpChoices(tester, finishedState());
      await tester.tap(find.byKey(const ValueKey('plan_finished_repeat')));
      await confirmStartSheet(tester);
      expect(fake.preparedIncreases, isEmpty);
      expect(fake.startedOn, '2026-10-15');
      expect(fake.startedWeekdays, [1, 3, 5]);
      expect(changed, 1);
    });

    testWidgets('repeat with +2.5 kg carries the main-lift targets', (
      tester,
    ) async {
      await pumpChoices(tester, finishedState());
      await tester.tap(
        find.byKey(const ValueKey('plan_finished_repeat_heavier')),
      );
      await confirmStartSheet(tester);
      expect(fake.preparedIncreases, [squat]);
      expect(fake.startedOn, '2026-10-15');
      expect(changed, 1);
    });

    testWidgets('+2.5 kg is unavailable without a logged main-lift weight', (
      tester,
    ) async {
      await pumpChoices(tester, finishedState(increases: const []));
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('plan_finished_repeat_heavier')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text('Needs a logged weight on a main lift.'),
        findsOneWidget,
      );
    });

    testWidgets('pick the next plan finishes it and opens the library', (
      tester,
    ) async {
      await pumpChoices(tester, finishedState());
      await tester.tap(find.byKey(const ValueKey('plan_finished_pick_next')));
      await tester.pumpAndSettle();
      expect(lifecycleFake.finished, 1);
      expect(fake.preparedIncreases, isNull);
      expect(find.text('library /plan-library?days=3'), findsOneWidget);
    });
  });
}

class _RecordingNextBlock extends PlanNextBlockRepository {
  _RecordingNextBlock(
    super.db,
    ProgramRepository programs,
    LocalScheduleDateService dates,
  ) : super(programs: programs, dates: dates);

  List<MainLiftIncrease>? preparedIncreases;
  String? startedOn;
  List<int>? startedWeekdays;

  @override
  Future<String> prepareNextBlock({
    required String finishedVersionId,
    List<MainLiftIncrease> increases = const [],
  }) async {
    preparedIncreases = increases;
    return 'next-draft';
  }

  @override
  Future<ActivationResult> startNextBlock({
    required ProgramLifecycleRepository lifecycle,
    required ProgramActivationCoordinator activation,
    required String draftVersionId,
    required String commandId,
    required String startLocalDate,
    required String timezoneId,
    List<int>? trainingWeekdays,
  }) async {
    startedOn = startLocalDate;
    startedWeekdays = trainingWeekdays;
    return ActivationResult(
      programVersionId: draftVersionId,
      occurrences: const [],
      wasIdempotent: false,
    );
  }
}

class _RecordingLifecycle extends TrainingPlanLifecycleController {
  _RecordingLifecycle(super.repository);

  var finished = 0;

  @override
  Future<EndActivePlanResult> finishPlan() async {
    finished++;
    return const EndActivePlanResult(
      programVersionId: 'finished-version',
      outcome: PlanEndOutcome.finished,
      cancelledOccurrenceIds: [],
      wasIdempotent: false,
    );
  }
}

class _NoEntryLibrary implements PlanLibraryReadRepository {
  @override
  Future<PlanLibraryEntry?> readVersion(String versionId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
