import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/nutrients.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/repositories/training_next_action_resolver.dart';
import 'package:indifit/features/dashboard/today_consumer_presentation.dart';
import 'package:indifit/features/dashboard/today_presentation_types.dart';
import 'package:indifit/features/dashboard/today_surface_controller.dart';
import 'package:indifit/features/training/training_screen.dart';

void main() {
  final now = DateTime.utc(2026, 3, 2, 10);
  late AppDatabase db;
  late LocalScheduleDateService dates;
  late ProgramRepository programs;
  late ProgramActivationCoordinator activation;

  setUp(() async {
    db = AppDatabase.memory();
    dates = LocalScheduleDateService(nowUtc: () => now);
    programs = ProgramRepository(db);
    activation = ProgramActivationCoordinator(
      db,
      dates: dates,
      nowUtc: () => now,
    );
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('r08a2-squat'),
            name: 'R08A.2 Squat',
            muscleGroups: 'Legs',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Rounding',
          ),
        );
  });

  tearDown(() => db.close());

  Future<String> createPlan(String name) async {
    final programId = await programs.createProgram(
      name: name,
      blocks: [
        ProgramBlockInput(
          name: 'Base block',
          ordinal: 0,
          weeks: [
            for (var week = 0; week < 2; week++)
              ProgramWeekInput(
                name: 'Week ${week + 1}',
                ordinalInBlock: week,
                programWeekOrdinal: week,
                templates: [
                  SessionTemplateInput(
                    name: '$name · workout ${week + 1}',
                    ordinal: 0,
                    plannedWeekday: DateTime.monday,
                    prescriptions: const [
                      ExercisePrescriptionInput(
                        exerciseId: 'r08a2-squat',
                        exerciseNameSnapshot: 'R08A.2 Squat',
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

  Future<CalendarReadSnapshot> readCalendar() {
    return CalendarReadRepository(db, dates: dates).readSnapshot(
      startLocalDate: '2026-03-02',
      endLocalDate: '2026-03-16',
      timezoneId: 'Asia/Kolkata',
    );
  }

  Future<void> completeOccurrence(String occurrenceId) async {
    await (db.update(
      db.scheduledSessionOccurrences,
    )..where((table) => table.id.equals(occurrenceId))).write(
      ScheduledSessionOccurrencesCompanion(
        status: const Value('completed'),
        progressionDisposition: const Value('satisfied'),
        terminalAtUtc: Value(now),
      ),
    );
  }

  test(
    'one resolver keeps Today and Training on the same current/next ID',
    () async {
      final versionId = await createPlan('Resolver plan');
      await activation.activate(
        ActivateProgramVersionCommand(
          programVersionId: versionId,
          commandId: 'activate::resolver',
          activationLocalDate: '2026-03-02',
          timezoneId: 'Asia/Kolkata',
        ),
      );

      final before = await readCalendar();
      final beforeResolution = resolveTrainingNextAction(
        snapshot: before,
        localDate: '2026-03-02',
      );
      expect(beforeResolution.todayOccurrence, isNotNull);
      expect(
        beforeResolution.currentOrNextOccurrenceId,
        beforeResolution.todayOccurrence!.occurrence.id,
      );

      final rolloverResolution = resolveTrainingNextAction(
        snapshot: before,
        localDate: '2026-03-09',
      );
      expect(
        rolloverResolution.overdueOccurrence!.occurrence.id,
        beforeResolution.todayOccurrence!.occurrence.id,
      );
      expect(
        rolloverResolution.nextOccurrence!.occurrence.id,
        beforeResolution.todayOccurrence!.occurrence.id,
      );
      final rolloverToday = TodaySurfaceSnapshot(
        selectedDate: DateTime(2026, 3, 9),
        localDate: '2026-03-09',
        timezoneId: 'Asia/Kolkata',
        calendar: TodayDomainRead.available(before),
        progress: const TodayDomainRead.unavailable('not needed'),
        nutrition: const TodayDomainRead.unavailable('not needed'),
      );
      expect(
        todayFocusPresentation(
          dateRelation: TodayDateRelation.today,
          snapshot: rolloverToday,
        ).title,
        startsWith('Overdue:'),
      );

      await completeOccurrence(beforeResolution.todayOccurrence!.occurrence.id);
      final after = await readCalendar();
      final afterResolution = resolveTrainingNextAction(
        snapshot: after,
        localDate: '2026-03-02',
      );

      expect(afterResolution.todayOccurrence, isNull);
      expect(afterResolution.todayCompletedOccurrence, isNotNull);
      expect(afterResolution.nextOccurrence, isNotNull);
      expect(
        afterResolution.nextOccurrence!.occurrence.effectiveLocalDate,
        '2026-03-09',
      );
      expect(
        afterResolution.currentOrNextOccurrenceId,
        afterResolution.nextOccurrence!.occurrence.id,
      );

      final today = TodaySurfaceSnapshot(
        selectedDate: DateTime(2026, 3, 2),
        localDate: '2026-03-02',
        timezoneId: 'Asia/Kolkata',
        calendar: TodayDomainRead.available(after),
        progress: const TodayDomainRead.unavailable('not needed'),
        nutrition: const TodayDomainRead.unavailable('not needed'),
      );
      final todayResolution = today.nextActionResolution!;
      final focus = todayFocusPresentation(
        dateRelation: TodayDateRelation.today,
        snapshot: today,
      );

      expect(
        todayResolution.currentOrNextOccurrenceId,
        afterResolution.currentOrNextOccurrenceId,
      );
      expect(focus.workout, isNull);
      expect(focus.title, 'Workout complete today');

      final unknownDraft = TodaySurfaceSnapshot(
        selectedDate: DateTime(2026, 3, 2),
        localDate: '2026-03-02',
        timezoneId: 'Asia/Kolkata',
        calendar: TodayDomainRead.available(after),
        progress: const TodayDomainRead.unavailable('not needed'),
        nutrition: const TodayDomainRead.unavailable('not needed'),
        activeDraft: const TodayDomainRead<WorkoutDraft?>.unavailable(
          'draft read failed',
        ),
      );
      expect(
        todayFocusPresentation(
          dateRelation: TodayDateRelation.today,
          snapshot: unknownDraft,
        ).state,
        TodayPresentationState.unavailable,
      );
    },
  );

  test(
    'activation, plan switch, draft changes, and completion invalidate Training',
    () async {
      final planA = await createPlan('Plan A');
      final planB = await createPlan('Plan B');
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          localScheduleDateServiceProvider.overrideWithValue(dates),
          localTimezoneServiceProvider.overrideWithValue(
            LocalTimezoneService(
              read: () async => 'Asia/Kolkata',
              dates: dates,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen<AsyncValue<TrainingLandingSnapshot>>(
        trainingLandingSnapshotProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(keepAlive.close);

      final empty = await _waitForTraining(
        container,
        (snapshot) => snapshot.activeProgramName == null,
      );
      expect(empty.todayWorkout, isNull);

      final activationA = _waitForTraining(
        container,
        (snapshot) => snapshot.activeProgramName == 'Plan A',
      );
      await activation.activate(
        ActivateProgramVersionCommand(
          programVersionId: planA,
          commandId: 'activate::a',
          activationLocalDate: '2026-03-02',
          timezoneId: 'Asia/Kolkata',
        ),
      );
      final activeA = await activationA;
      expect(activeA.todayWorkout!.program.name, 'Plan A');

      final activationB = _waitForTraining(
        container,
        (snapshot) => snapshot.activeProgramName == 'Plan B',
      );
      await activation.activate(
        ActivateProgramVersionCommand(
          programVersionId: planB,
          commandId: 'activate::b',
          activationLocalDate: '2026-03-02',
          timezoneId: 'Asia/Kolkata',
        ),
      );
      final activeB = await activationB;
      expect(activeB.todayWorkout!.program.name, 'Plan B');
      expect(activeB.todayWorkout!.program.name, isNot('Plan A'));

      final draftChange = _waitForTraining(
        container,
        (snapshot) =>
            snapshot.activeStrengthDraft?.routineName == 'Active B02 draft',
      );
      await db
          .into(db.workoutDrafts)
          .insert(
            WorkoutDraftsCompanion.insert(
              routineName: 'Active B02 draft',
              currentExerciseIndex: 0,
              currentSetIndex: 0,
              elapsedSeconds: 15,
              loggedSetsJson: '{}',
              activityType: const Value('strength'),
              executionStateJson: const Value('{}'),
            ),
          );
      expect(
        (await draftChange).activeStrengthDraft!.routineName,
        'Active B02 draft',
      );

      final completionChange = _waitForTraining(
        container,
        (snapshot) =>
            snapshot.activeStrengthDraft == null &&
            snapshot.todayWorkout?.occurrence.status == 'completed',
      );
      await db.delete(db.workoutDrafts).go();
      final current = activeB.todayWorkout!;
      await completeOccurrence(current.occurrence.id);
      final completed = await completionChange;
      expect(completed.todayWorkout!.occurrence.status, 'completed');
      expect(completed.upcoming, hasLength(1));
      expect(completed.upcoming.single.program.name, 'Plan B');
    },
  );

  test(
    'activation, plan switch, and completion invalidate the Today provider',
    () async {
      final planA = await createPlan('Today A');
      final planB = await createPlan('Today B');
      final selectedDate = DateTime(2026, 3, 2);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          localScheduleDateServiceProvider.overrideWithValue(dates),
          localTimezoneServiceProvider.overrideWithValue(
            LocalTimezoneService(
              read: () async => 'Asia/Kolkata',
              dates: dates,
            ),
          ),
          nutritionRegistryProvider.overrideWith(
            (_) async => NutrientRegistry.fromAssetFileSync(
              'assets/data/nutrient_registry.json',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen<AsyncValue<TodaySurfaceSnapshot>>(
        todaySurfaceSnapshotProvider(selectedDate),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(keepAlive.close);

      final empty = await _waitForToday(
        container,
        selectedDate,
        (snapshot) => snapshot.calendar.value?.activeProgramName == null,
      );
      expect(empty.nextActionResolution?.todayOccurrence, isNull);

      final activationA = _waitForToday(
        container,
        selectedDate,
        (snapshot) =>
            snapshot.calendar.value?.activeProgramName == 'Today A' &&
            snapshot.nextActionResolution?.todayOccurrence != null,
      );
      await activation.activate(
        ActivateProgramVersionCommand(
          programVersionId: planA,
          commandId: 'activate::today-a',
          activationLocalDate: '2026-03-02',
          timezoneId: 'Asia/Kolkata',
        ),
      );
      final activeA = await activationA;
      expect(
        activeA.nextActionResolution!.todayOccurrence!.program.name,
        'Today A',
      );

      final activationB = _waitForToday(
        container,
        selectedDate,
        (snapshot) =>
            snapshot.calendar.value?.activeProgramName == 'Today B' &&
            snapshot.nextActionResolution?.todayOccurrence != null,
      );
      await activation.activate(
        ActivateProgramVersionCommand(
          programVersionId: planB,
          commandId: 'activate::today-b',
          activationLocalDate: '2026-03-02',
          timezoneId: 'Asia/Kolkata',
        ),
      );
      final activeB = await activationB;
      expect(
        activeB.nextActionResolution!.todayOccurrence!.program.name,
        'Today B',
      );
      expect(
        activeB.nextActionResolution!.todayOccurrence!.program.name,
        isNot('Today A'),
      );
      final trainingActiveB = await container.read(
        trainingLandingSnapshotProvider.future,
      );
      expect(
        trainingActiveB.todayWorkout!.occurrence.id,
        activeB.nextActionResolution!.todayOccurrence!.occurrence.id,
      );

      final occurrenceId =
          activeB.nextActionResolution!.todayOccurrence!.occurrence.id;
      final completion = _waitForToday(
        container,
        selectedDate,
        (snapshot) =>
            snapshot.nextActionResolution?.todayOccurrence == null &&
            snapshot.nextActionResolution?.todayCompletedOccurrence != null,
      );
      await completeOccurrence(occurrenceId);
      final completed = await completion;
      expect(completed.nextActionResolution!.todayOccurrence, isNull);
      expect(
        completed.nextActionResolution!.todayCompletedOccurrence!.occurrence.id,
        occurrenceId,
      );
      expect(
        completed.nextActionResolution!.currentOrNextOccurrenceId,
        completed.nextActionResolution!.nextOccurrence!.occurrence.id,
      );
      final trainingCompleted = await container.read(
        trainingLandingSnapshotProvider.future,
      );
      expect(
        trainingCompleted.upcoming.single.occurrence.id,
        completed.nextActionResolution!.nextOccurrence!.occurrence.id,
      );
    },
  );

  test(
    'historical incomplete history does not create a Resume action',
    () async {
      final versionId = await createPlan('History plan');
      await activation.activate(
        ActivateProgramVersionCommand(
          programVersionId: versionId,
          commandId: 'activate::history',
          activationLocalDate: '2026-03-02',
          timezoneId: 'Asia/Kolkata',
        ),
      );
      await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: 'Historical incomplete workout',
              totalVolume: 0,
              durationSeconds: 120,
              estimatedCalories: 0,
              completedAt: Value(DateTime.utc(2026, 3, 1, 10)),
              completionKind: const Value('partial'),
              activityType: const Value('strength'),
              activitySchemaVersion: const Value(1),
            ),
          );
      final snapshot = await readCalendar();
      final resolution = resolveTrainingNextAction(
        snapshot: snapshot,
        localDate: '2026-03-02',
        activeDraft: null,
      );
      expect(resolution.hasResumableDraft, isFalse);
      expect(resolution.currentOccurrence, isNull);
      expect(resolution.todayOccurrence, isNotNull);
    },
  );
}

Future<TrainingLandingSnapshot> _waitForTraining(
  ProviderContainer container,
  bool Function(TrainingLandingSnapshot) matches,
) async {
  final completer = Completer<TrainingLandingSnapshot>();
  late final ProviderSubscription<AsyncValue<TrainingLandingSnapshot>>
  subscription;
  subscription = container.listen<AsyncValue<TrainingLandingSnapshot>>(
    trainingLandingSnapshotProvider,
    (_, next) {
      final value = next.asData?.value;
      if (value != null && matches(value) && !completer.isCompleted) {
        completer.complete(value);
      }
    },
    fireImmediately: true,
  );
  try {
    return await completer.future.timeout(const Duration(seconds: 2));
  } finally {
    subscription.close();
  }
}

Future<TodaySurfaceSnapshot> _waitForToday(
  ProviderContainer container,
  DateTime selectedDate,
  bool Function(TodaySurfaceSnapshot) matches,
) async {
  final completer = Completer<TodaySurfaceSnapshot>();
  late final ProviderSubscription<AsyncValue<TodaySurfaceSnapshot>>
  subscription;
  subscription = container.listen<AsyncValue<TodaySurfaceSnapshot>>(
    todaySurfaceSnapshotProvider(selectedDate),
    (_, next) {
      final value = next.asData?.value;
      if (value != null && matches(value) && !completer.isCompleted) {
        completer.complete(value);
      }
    },
    fireImmediately: true,
  );
  try {
    return await completer.future.timeout(const Duration(seconds: 3));
  } finally {
    subscription.close();
  }
}
