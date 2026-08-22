import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v10.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/legacy_program_compatibility_adapter.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_lifecycle_repository.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/features/calendar/occurrence_actions_sheet.dart'
    show occurrenceEventLabel;
import 'package:indifit/features/training/training_screen.dart'
    show
        TrainingScreen,
        TrainingLandingSnapshot,
        trainingLandingSnapshotProvider,
        trainingWeekDaySemanticLabel,
        trainingWeekEmptyDayLabel;
import 'package:indifit/features/workout_player/routine_display_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 3, 4, 8);
  late AppDatabase db;
  late LocalScheduleDateService dates;
  late ProgramRepository programs;
  late ProgramActivationCoordinator activation;
  late ProgramLifecycleRepository lifecycle;

  setUp(() async {
    db = AppDatabase.memory();
    dates = LocalScheduleDateService(nowUtc: () => now);
    programs = ProgramRepository(db);
    activation = ProgramActivationCoordinator(
      db,
      dates: dates,
      nowUtc: () => now,
    );
    lifecycle = ProgramLifecycleRepository(db, nowUtc: () => now);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('r07f-exercise'),
            name: 'R07F Squat',
            muscleGroups: 'Legs',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Rounding',
          ),
        );
  });

  tearDown(() => db.close());

  Future<String> createDraftProgram({String name = 'Lifecycle Plan'}) async {
    final programId = await programs.createProgram(
      name: name,
      blocks: [
        ProgramBlockInput(
          name: 'Main block',
          ordinal: 0,
          weeks: [
            for (var week = 0; week < 5; week++)
              ProgramWeekInput(
                name: 'Week ${week + 1}',
                ordinalInBlock: week,
                programWeekOrdinal: week,
                templates: [
                  SessionTemplateInput(
                    name: 'Workout ${week + 1}',
                    ordinal: 0,
                    plannedWeekday: DateTime.monday,
                    prescriptions: const [
                      ExercisePrescriptionInput(
                        exerciseId: 'r07f-exercise',
                        exerciseNameSnapshot: 'R07F Squat',
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

  Future<List<ScheduledSessionOccurrence>> activate(String versionId) async {
    return (await activation.activate(
      ActivateProgramVersionCommand(
        programVersionId: versionId,
        commandId: 'activate::$versionId',
        activationLocalDate: '2026-03-02',
        timezoneId: 'Asia/Kolkata',
      ),
    )).occurrences;
  }

  Future<void> setStatus(
    String occurrenceId,
    String status, {
    String disposition = 'pending',
  }) async {
    await (db.update(
      db.scheduledSessionOccurrences,
    )..where((table) => table.id.equals(occurrenceId))).write(
      ScheduledSessionOccurrencesCompanion(
        status: Value(status),
        progressionDisposition: Value(disposition),
        terminalAtUtc: Value(now),
      ),
    );
  }

  test(
    'Finish preserves terminal history and removes active future work',
    () async {
      final versionId = await createDraftProgram();
      final occurrences = await activate(versionId);
      await setStatus(occurrences[0].id, 'completed', disposition: 'satisfied');
      await setStatus(occurrences[1].id, 'partiallyCompleted');
      await setStatus(occurrences[2].id, 'skipped', disposition: 'bypassed');
      await setStatus(occurrences[3].id, 'cancelled');

      final result = await lifecycle.endActivePlan(
        const EndActivePlanCommand(
          outcome: PlanEndOutcome.finished,
          commandId: 'finish::1',
        ),
      );

      expect(result.wasIdempotent, isFalse);
      expect(result.cancelledOccurrenceIds, [occurrences[4].id]);
      final rows = await db.select(db.scheduledSessionOccurrences).get();
      expect(
        {for (final row in rows) row.id: row.status},
        {
          occurrences[0].id: 'completed',
          occurrences[1].id: 'partiallyCompleted',
          occurrences[2].id: 'skipped',
          occurrences[3].id: 'cancelled',
          occurrences[4].id: 'cancelled',
        },
      );
      final settings = await db.select(db.trainingPlanSettings).getSingle();
      expect(settings.activeProgramVersionId, isNull);
      expect(settings.lastEndedProgramVersionId, versionId);
      expect(settings.lastEndedOutcome, 'finished');
      expect(settings.lastEndedCommandId, 'finish::1');
      expect(
        (await db.select(db.occurrenceEvents).get())
            .where((event) => event.eventType == 'planFinished')
            .length,
        1,
      );

      final snapshot = await CalendarReadRepository(db, dates: dates)
          .readSnapshot(
            startLocalDate: '2026-03-01',
            endLocalDate: '2026-04-30',
            timezoneId: 'Asia/Kolkata',
          );
      expect(snapshot.activeProgramVersionId, isNull);
      expect(snapshot.activeProgramName, isNull);
      expect(snapshot.lastEndedProgramName, 'Lifecycle Plan');
      expect(snapshot.lastEndedOutcome, 'finished');
      expect(
        snapshot.rangeOccurrences.every(
          (item) =>
              item.occurrence.status == 'completed' ||
              item.occurrence.status == 'partiallyCompleted' ||
              item.occurrence.status == 'skipped' ||
              item.occurrence.status == 'cancelled',
        ),
        isTrue,
      );
      expect(snapshot.overdueOccurrences, isEmpty);
    },
  );

  test('Finish is idempotent and command IDs cannot change outcome', () async {
    final versionId = await createDraftProgram();
    final occurrences = await activate(versionId);
    final command = const EndActivePlanCommand(
      outcome: PlanEndOutcome.left,
      commandId: 'leave::retry',
    );
    final first = await lifecycle.endActivePlan(command);
    final retry = await lifecycle.endActivePlan(command);
    expect(first.wasIdempotent, isFalse);
    expect(retry.wasIdempotent, isTrue);
    expect(retry.cancelledOccurrenceIds, [
      ...occurrences.map((occurrence) => occurrence.id),
    ]);
    await expectLater(
      lifecycle.endActivePlan(
        const EndActivePlanCommand(
          outcome: PlanEndOutcome.finished,
          commandId: 'leave::retry',
        ),
      ),
      throwsA(isA<PlanEndCommandConflictException>()),
    );
    expect(await db.select(db.occurrenceEvents).get(), hasLength(10));
  });

  test('linked draft and stale in-progress work block plan ending', () async {
    final versionId = await createDraftProgram();
    final occurrences = await activate(versionId);
    await db
        .into(db.workoutDrafts)
        .insert(
          WorkoutDraftsCompanion.insert(
            routineName: 'Workout 1',
            currentExerciseIndex: 0,
            currentSetIndex: 0,
            elapsedSeconds: 10,
            loggedSetsJson: jsonEncode(const {}),
            scheduledOccurrenceId: Value(occurrences.first.id),
          ),
        );

    await expectLater(
      lifecycle.endActivePlan(
        const EndActivePlanCommand(
          outcome: PlanEndOutcome.finished,
          commandId: 'finish::draft',
        ),
      ),
      throwsA(isA<PlanEndBlockedException>()),
    );
    expect(
      (await db.select(db.trainingPlanSettings).getSingle())
          .activeProgramVersionId,
      versionId,
    );

    await db.delete(db.workoutDrafts).go();
    await setStatus(occurrences.first.id, 'inProgress');
    await expectLater(
      lifecycle.endActivePlan(
        const EndActivePlanCommand(
          outcome: PlanEndOutcome.left,
          commandId: 'leave::stale',
        ),
      ),
      throwsA(isA<PlanEndBlockedException>()),
    );
  });

  test(
    'new activation clears ended marker and legacy fallback stays suppressed',
    () async {
      final firstVersion = await createDraftProgram();
      await activate(firstVersion);
      await lifecycle.endActivePlan(
        const EndActivePlanCommand(
          outcome: PlanEndOutcome.left,
          commandId: 'leave::marker',
        ),
      );
      await db
          .into(db.workoutRoutines)
          .insert(
            WorkoutRoutinesCompanion.insert(name: 'Legacy', goal: 'Strength'),
          );
      final adapter = LegacyProgramCompatibilityAdapter(db);
      expect(
        (await adapter.resolveActivePlanSelection()).type,
        ActivePlanType.none,
      );

      final secondVersion = await createDraftProgram(name: 'Next Plan');
      await activate(secondVersion);
      final settings = await db.select(db.trainingPlanSettings).getSingle();
      expect(settings.activeProgramVersionId, secondVersion);
      expect(settings.lastEndedProgramVersionId, isNull);
      expect(settings.lastEndedOutcome, isNull);
    },
  );

  test(
    'Backup-v10 carries ended-plan metadata through generated singleton JSON',
    () async {
      final versionId = await createDraftProgram();
      await activate(versionId);
      await lifecycle.endActivePlan(
        const EndActivePlanCommand(
          outcome: PlanEndOutcome.finished,
          commandId: 'finish::backup',
        ),
      );

      final backup = await BackupV10Data.createFromDatabase(db);
      expect(backup.schemaVersion, 20);
      final json = backup.toJson();
      final settingsJson = (json['training_plan_settings'] as List).single;
      expect(settingsJson['lastEndedOutcome'], 'finished');
      final legacyJson = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      final legacySettings = Map<String, dynamic>.from(settingsJson)
        ..remove('lastEndedProgramVersionId')
        ..remove('lastEndedOutcome')
        ..remove('lastEndedAtUtc')
        ..remove('lastEndedCommandId');
      legacyJson['training_plan_settings'] = [legacySettings];
      final legacyDecoded = BackupV10Data.fromJson(legacyJson);
      expect(
        legacyDecoded.legacy.trainingPlanSettings!.lastEndedOutcome,
        isNull,
      );
      final decoded = BackupV10Data.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(
        decoded.legacy.trainingPlanSettings!.lastEndedProgramVersionId,
        versionId,
      );
      expect(
        decoded.legacy.trainingPlanSettings!.lastEndedCommandId,
        'finish::backup',
      );
    },
  );

  test(
    'a stale occurrence cannot start after an explicit plan switch',
    () async {
      final firstVersion = await createDraftProgram(name: 'First Plan');
      final oldOccurrences = await activate(firstVersion);
      final secondVersion = await createDraftProgram(name: 'Second Plan');
      await activate(secondVersion);

      final calendar = CalendarRepository(db, dates: dates, nowUtc: () => now);
      await expectLater(
        calendar.start(
          StartOccurrenceCommand(
            occurrenceId: oldOccurrences.first.id,
            commandId: 'start::stale',
            expectedStatus: OccurrenceStatus.planned,
            confirmedOutsideEffectiveDate: true,
          ),
        ),
        throwsA(isA<InvalidOccurrenceTransitionException>()),
      );
      expect(
        (await calendar.getOccurrence(oldOccurrences.first.id))!.status,
        'planned',
      );
    },
  );

  test(
    'review R07F-1: skip, cancel, and reschedule also reject inactive-plan occurrences',
    () async {
      final firstVersion = await createDraftProgram(name: 'First Plan');
      final oldOccurrences = await activate(firstVersion);
      final secondVersion = await createDraftProgram(name: 'Second Plan');
      await activate(secondVersion);

      final calendar = CalendarRepository(db, dates: dates, nowUtc: () => now);
      final stale = oldOccurrences.first;
      await expectLater(
        calendar.skip(
          SkipOccurrenceCommand(
            occurrenceId: stale.id,
            commandId: 'skip::stale',
            expectedStatus: OccurrenceStatus.planned,
            disposition: SkipDisposition.keepPending,
          ),
        ),
        throwsA(isA<InvalidOccurrenceTransitionException>()),
      );
      await expectLater(
        calendar.cancel(
          CancelOccurrenceCommand(
            occurrenceId: stale.id,
            commandId: 'cancel::stale',
            expectedStatus: OccurrenceStatus.planned,
          ),
        ),
        throwsA(isA<InvalidOccurrenceTransitionException>()),
      );
      await expectLater(
        calendar.reschedule(
          RescheduleOccurrenceCommand(
            occurrenceId: stale.id,
            commandId: 'reschedule::stale',
            expectedStatus: OccurrenceStatus.planned,
            effectiveLocalDate: '2026-03-09',
            effectiveTimezoneId: 'Asia/Kolkata',
            confirmed: true,
          ),
        ),
        throwsA(isA<InvalidOccurrenceTransitionException>()),
      );
      // The stale row is left completely untouched.
      final after = (await calendar.getOccurrence(stale.id))!;
      expect(after.status, 'planned');
      expect(after.effectiveLocalDate, stale.effectiveLocalDate);
      final events = await (db.select(
        db.occurrenceEvents,
      )..where((table) => table.occurrenceId.equals(stale.id))).get();
      expect(
        events.where((event) => event.commandId.contains('stale')),
        isEmpty,
      );
    },
  );

  test(
    'review R07F-1: occurrence history labels split camelCase event types',
    () {
      expect(occurrenceEventLabel('planFinished'), 'Plan Finished');
      expect(occurrenceEventLabel('planLeft'), 'Plan Left');
      expect(occurrenceEventLabel('startDiscarded'), 'Start Discarded');
      expect(occurrenceEventLabel('repeatCreated'), 'Repeat Created');
      expect(occurrenceEventLabel('skipped'), 'Skipped');
      expect(
        occurrenceEventLabel('activationCancelled'),
        'Activation Cancelled',
      );
    },
  );

  test(
    'review R07F-1: week strip stays neutral on days without a scheduled workout',
    () {
      // B01 records no explicit rest evidence, so an empty day must not
      // infer recovery intent (spec §38: neutral wording only).
      expect(trainingWeekEmptyDayLabel, 'no workout scheduled');
      expect(trainingWeekEmptyDayLabel.contains('recovery'), isFalse);
      expect(
        trainingWeekDaySemanticLabel(
          'Tuesday',
          3,
          trainingWeekEmptyDayLabel,
          null,
        ),
        'Tuesday, 3: no workout scheduled',
      );
      expect(
        trainingWeekDaySemanticLabel('Monday', 2, 'scheduled', 'Workout 1'),
        'Monday, 2: scheduled, Workout 1',
      );
      // Terminal and in-progress days keep their truthful states.
      expect(
        trainingWeekDaySemanticLabel('Wednesday', 4, 'in progress', null),
        'Wednesday, 4: in progress',
      );
      expect(
        trainingWeekDaySemanticLabel('Friday', 6, 'partially completed', null),
        'Friday, 6: partially completed',
      );
    },
  );

  testWidgets('active plan surface exposes explicit Finish and Leave actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ActiveProgramManagementSurface(
            planName: 'Lifecycle Plan',
            onOpenCalendar: () {},
            onChangePlan: () {},
            onFinishPlan: () {},
            onLeavePlan: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Plan actions'));
    await tester.pumpAndSettle();
    expect(find.text('Finish plan'), findsOneWidget);
    expect(find.text('Leave plan'), findsOneWidget);
  });

  testWidgets('ended plan landing state keeps history and a next action', (
    tester,
  ) async {
    const ended = TrainingLandingSnapshot(
      localDate: '2026-03-04',
      timezoneId: 'Asia/Kolkata',
      todayWorkout: null,
      upcoming: [],
      recentSessions: [],
      activeProgramName: null,
      lastEndedProgramName: 'Lifecycle Plan',
      lastEndedOutcome: 'finished',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingLandingSnapshotProvider.overrideWith((ref) async => ended),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const TrainingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set up your training plan'), findsOneWidget);
    expect(find.text('Choose a plan'), findsOneWidget);
    expect(find.text('Quick Workout'), findsOneWidget);
    expect(find.textContaining('saved in history'), findsOneWidget);
  });
}
