import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/services/local_timezone_service.dart';
import 'package:indifit/core/widgets/skeleton_loader.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/plan_library_read_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/training/plan_library_screen.dart';

final now = DateTime.utc(2026, 8, 24, 10);
late AppDatabase db;
late ProgramRepository programs;
late LocalScheduleDateService dates;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    db = AppDatabase.memory();
    programs = ProgramRepository(db);
    dates = LocalScheduleDateService(nowUtc: () => now);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('r08c3-exercise'),
            name: 'Goblet Squat',
            muscleGroups: 'Legs',
            equipment: 'Dumbbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Rushing',
          ),
        );
  });

  tearDown(() => db.close());

  test(
    'read model exposes canonical plan metadata and active pointer',
    () async {
      await createPublishedPlan(
        'Plan A',
        goal: 'Strength',
        notes: 'A simple two-day schedule.',
      );
      final planB = await createPublishedPlan('Plan B');
      await setActive(planB);

      final snapshot = await PlanLibraryReadRepository(db).read();

      expect(snapshot.entries, hasLength(2));
      expect(snapshot.entries.first.version.id, planB);
      expect(snapshot.entries.first.isActive, isTrue);
      expect(snapshot.entries.first.metadata.weekCount, 2);
      expect(snapshot.entries.first.metadata.sessionCount, 4);
      expect(snapshot.entries.first.metadata.exerciseCount, 4);
      expect(snapshot.entries.first.metadata.trainingDaysPerWeek, 2);
      expect(snapshot.entries.first.metadata.blockNames, ['Base block']);
      expect(snapshot.entries.last.program.name, 'Plan A');
    },
  );

  test('empty library stays empty and does not invent plan metadata', () async {
    final snapshot = await PlanLibraryReadRepository(db).read();

    expect(snapshot.entries, isEmpty);
    expect(snapshot.activeProgramVersionId, isNull);
  });

  test('invalid active pointer fails closed', () async {
    final versionId = await createPublishedPlan('Archived active plan');
    await (db.update(db.programVersions)
          ..where((row) => row.id.equals(versionId)))
        .write(const ProgramVersionsCompanion(status: Value('archived')));
    await (db.update(
      db.trainingPlanSettings,
    )..where((row) => row.id.equals(1))).write(
      TrainingPlanSettingsCompanion(
        activeProgramVersionId: Value(versionId),
        updatedAtUtc: Value(now),
      ),
    );

    await expectLater(
      PlanLibraryReadRepository(db).read(),
      throwsA(isA<StateError>()),
    );
  });

  test('published plan copy and activation preserve the canonical source', () async {
    final sourceVersionId = await createPublishedPlan('Canonical source');
    final copiedVersionId = await programs.copyToNewDraftVersion(sourceVersionId);
    final activation = ProgramActivationCoordinator(
      db,
      dates: dates,
      nowUtc: () => now,
    );

    await activation.activate(
      ActivateProgramVersionCommand(
        programVersionId: copiedVersionId,
        commandId: 'r08c3-activate-copied',
        activationLocalDate: '2026-08-24',
        timezoneId: 'Asia/Kolkata',
      ),
    );

    final versions = await db.select(db.programVersions).get();
    final source = versions.singleWhere((version) => version.id == sourceVersionId);
    final copied = versions.singleWhere(
      (version) => version.id == copiedVersionId,
    );
    final settings = (await db.select(db.trainingPlanSettings).get()).single;
    expect(source.status, 'published');
    expect(copied.status, 'published');
    expect(settings.activeProgramVersionId, copiedVersionId);
    expect(
      await db.select(db.scheduledSessionOccurrences).get(),
      hasLength(4),
    );
  });

  test('switch activation retains prior occurrence history', () async {
    final currentSourceVersionId = await createPublishedPlan('Current source');
    final currentVersionId = await programs.copyToNewDraftVersion(
      currentSourceVersionId,
    );
    final nextSourceVersionId = await createPublishedPlan('Next source');
    final nextVersionId = await programs.copyToNewDraftVersion(
      nextSourceVersionId,
    );
    final activation = ProgramActivationCoordinator(
      db,
      dates: dates,
      nowUtc: () => now,
    );

    await activation.activate(
      ActivateProgramVersionCommand(
        programVersionId: currentVersionId,
        commandId: 'r08c3-activate-current',
        activationLocalDate: '2026-08-24',
        timezoneId: 'Asia/Kolkata',
      ),
    );
    await activation.activate(
      ActivateProgramVersionCommand(
        programVersionId: nextVersionId,
        commandId: 'r08c3-activate-next',
        activationLocalDate: '2026-08-24',
        timezoneId: 'Asia/Kolkata',
      ),
    );

    final settings = (await db.select(db.trainingPlanSettings).get()).single;
    expect(settings.activeProgramVersionId, nextVersionId);
    expect(
      await db.select(db.scheduledSessionOccurrences).get(),
      hasLength(8),
    );
  });

  testWidgets('populated library marks the active plan and supports search', (
    tester,
  ) async {
    late String planA;
    await tester.runAsync(() async {
      planA = await createPublishedPlan('Plan A');
      await createPublishedPlan('Plan B', goal: 'Mobility');
      await setActive(planA);
    });

    await pumpApp(tester, const PlanLibraryScreen());

    expect(find.text('Current plan'), findsWidgets);
    expect(find.text('Plan A'), findsWidgets);
    expect(find.text('Plan B'), findsOneWidget);
    expect(find.text('Use this plan'), findsNothing);
    expect(find.text('Difficulty'), findsNothing);
    expect(find.text('Rating'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Mobility');
    await tester.pump();
    expect(find.text('Plan B'), findsOneWidget);
    expect(find.text('Plan A'), findsNothing);
  });

  testWidgets('detail screen exposes the schedule and current-plan state', (
    tester,
  ) async {
    late String versionId;
    late ProgramDetailAggregate detail;
    await tester.runAsync(() async {
      versionId = await createPublishedPlan(
        'Strength Plan',
        goal: 'Strength',
        notes: 'Build a steady base.',
      );
      await setActive(versionId);
      detail = (await programs.getProgramVersionDetail(versionId))!;
    });

    await pumpApp(
      tester,
      PlanLibraryDetailScreen(programId: detail.program.id),
    );

    expect(find.text('Strength Plan'), findsWidgets);
    expect(find.text('Current plan'), findsWidgets);
    expect(find.text('Plan structure'), findsOneWidget);
    expect(find.text('Goblet Squat'), findsNothing);
    expect(find.text('Use this plan'), findsNothing);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.textContaining('Goblet Squat'), findsWidgets);
    expect(find.text('Difficulty'), findsNothing);
  });

  testWidgets(
    'using a published plan copies then activates through B01 authority',
    (tester) async {
      late PlanLibrarySnapshot snapshot;
      await tester.runAsync(() async {
        await createPublishedPlan('Use Me');
        snapshot = await PlanLibraryReadRepository(db).read();
      });
      final sourceEntry = snapshot.entries.single;
      final copyRepo = _CopyingProgramRepository(db, 'copied-version');
      final activation = _ImmediateActivationCoordinator(
        db,
        dates: dates,
        onActivate: (command) {},
      );

      await pumpApp(
        tester,
        PlanLibraryDetailScreen(programId: sourceEntry.program.id),
        extraOverrides: [
          planLibrarySnapshotProvider.overrideWith(
            (ref) async => snapshot,
          ),
          programRepositoryProvider.overrideWithValue(copyRepo),
          programActivationCoordinatorProvider.overrideWithValue(activation),
          workoutRepositoryProvider.overrideWithValue(
            _StaticWorkoutRepository(db, null),
          ),
          calendarReadRepositoryProvider.overrideWithValue(
            _StaticCalendarReadRepository(
              db,
              dates: dates,
              snapshot: const CalendarReadSnapshot(
                rangeOccurrences: [],
                overdueOccurrences: [],
                activeProgramVersionId: null,
                activeProgramName: null,
              ),
            ),
          ),
        ],
      );
      await tester.tap(find.text('Use this plan'));
      await tester.pump();

      expect(copyRepo.copiedSourceVersionId, sourceEntry.version.id);
      expect(activation.activatedCommand?.programVersionId, 'copied-version');
      expect(find.text('This is now your current plan.'), findsOneWidget);
    },
  );

  testWidgets(
    'switching plans confirms then retains the canonical occurrence history',
    (tester) async {
      late PlanLibrarySnapshot snapshot;
      await tester.runAsync(() async {
        final currentVersionId = await createPublishedPlan('Current Plan');
        await createPublishedPlan('Next Plan');
        await setActive(currentVersionId);
        snapshot = await PlanLibraryReadRepository(db).read();
      });
      final nextEntry = snapshot.entries.firstWhere(
        (entry) => entry.program.name == 'Next Plan',
      );
      final copyRepo = _CopyingProgramRepository(db, 'switched-version');
      final activation = _ImmediateActivationCoordinator(
        db,
        dates: dates,
        onActivate: (command) {},
      );

      await pumpApp(
        tester,
        PlanLibraryDetailScreen(programId: nextEntry.program.id),
        extraOverrides: [
          planLibrarySnapshotProvider.overrideWith(
            (ref) async => snapshot,
          ),
          programRepositoryProvider.overrideWithValue(copyRepo),
          programActivationCoordinatorProvider.overrideWithValue(activation),
          workoutRepositoryProvider.overrideWithValue(
            _StaticWorkoutRepository(db, null),
          ),
          calendarReadRepositoryProvider.overrideWithValue(
            _StaticCalendarReadRepository(
              db,
              dates: dates,
              snapshot: CalendarReadSnapshot(
                rangeOccurrences: const [],
                overdueOccurrences: const [],
                activeProgramVersionId: snapshot.activeProgramVersionId,
                activeProgramName: 'Current Plan',
              ),
            ),
          ),
        ],
      );
      await tester.tap(find.text('Use this plan'));
      await tester.pump();
      expect(find.text('Switch current plan?'), findsOneWidget);
      await tester.tap(find.text('Switch plan'));
      await tester.pump();
      expect(copyRepo.copiedSourceVersionId, nextEntry.version.id);
      expect(activation.activatedCommand?.programVersionId, 'switched-version');
    },
  );

  testWidgets(
    'active workout draft blocks plan use with truthful recovery copy',
    (tester) async {
      late PlanLibrarySnapshot snapshot;
      await tester.runAsync(() async {
        await createPublishedPlan('Blocked Plan');
        snapshot = await PlanLibraryReadRepository(db).read();
      });
      final entry = snapshot.entries.single;

      await pumpApp(
        tester,
        PlanLibraryDetailScreen(programId: entry.program.id),
        extraOverrides: [
          planLibrarySnapshotProvider.overrideWith(
            (ref) async => snapshot,
          ),
          workoutRepositoryProvider.overrideWithValue(
            _StaticWorkoutRepository(
              db,
              WorkoutDraft(
                id: 1,
                routineName: 'Active workout',
                currentExerciseIndex: 0,
                currentSetIndex: 0,
                elapsedSeconds: 30,
                loggedSetsJson: '[]',
                updatedAt: now,
                draftSchemaVersion: 1,
                activityType: 'strength',
                executionStateJson: '{}',
              ),
            ),
          ),
        ],
      );
      await tester.tap(find.text('Use this plan'));
      await tester.pump();

      expect(
        find.text(
          'Finish or discard your active workout before starting another.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'loading, empty, error, narrow width, large text, and semantics are intentional',
    (tester) async {
      await pumpApp(
        tester,
        const PlanLibraryScreen(),
        extraOverrides: [
          planLibrarySnapshotProvider.overrideWith(
            (ref) => Completer<PlanLibrarySnapshot>().future,
          ),
        ],
      );
      expect(find.byType(SkeletonList), findsOneWidget);

      await pumpApp(
        tester,
        const PlanLibraryScreen(),
        extraOverrides: [
          planLibrarySnapshotProvider.overrideWith(
            (ref) async => throw StateError('test'),
          ),
        ],
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.text('Plans are unavailable'), findsOneWidget);

      await pumpApp(
        tester,
        const PlanLibraryScreen(),
        mediaQuery: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
      );
      expect(find.text('No saved plans yet'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Build your own plan'), findsWidgets);
      semantics.dispose();
    },
  );
}

Future<String> createPublishedPlan(
  String name, {
  String? goal,
  String? notes,
}) async {
  final programId = await programs.createProgram(
    name: name,
    goal: goal,
    notes: notes,
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
                  name: '$name · Monday',
                  ordinal: 0,
                  plannedWeekday: DateTime.monday,
                  prescriptions: [
                    ExercisePrescriptionInput(
                      exerciseId: 'r08c3-exercise',
                      exerciseNameSnapshot: 'Goblet Squat',
                      plannedSets: 3,
                      repsRange: '8-10',
                      ordinal: 0,
                    ),
                  ],
                ),
                SessionTemplateInput(
                  name: '$name · Thursday',
                  ordinal: 1,
                  plannedWeekday: DateTime.thursday,
                  prescriptions: [
                    ExercisePrescriptionInput(
                      exerciseId: 'r08c3-exercise',
                      exerciseNameSnapshot: 'Goblet Squat',
                      plannedSets: 3,
                      repsRange: '8-10',
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
  final version = (await programs.getVersionsForProgram(programId)).single;
  await (db.update(
    db.programVersions,
  )..where((row) => row.id.equals(version.id))).write(
    ProgramVersionsCompanion(
      status: const Value('published'),
      publishedAtUtc: Value(now),
    ),
  );
  return version.id;
}

Future<void> setActive(String versionId) async {
  await (db.update(
    db.trainingPlanSettings,
  )..where((row) => row.id.equals(1))).write(
    TrainingPlanSettingsCompanion(
      activeProgramVersionId: Value(versionId),
      activeSinceLocalDate: const Value('2026-08-24'),
      activeSinceTimezoneId: const Value('Asia/Kolkata'),
      updatedAtUtc: Value(now),
    ),
  );
}

Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> extraOverrides = const [],
  MediaQueryData? mediaQuery,
}) async {
  final activation = ProgramActivationCoordinator(
    db,
    dates: dates,
    nowUtc: () => now,
  );
  final app = ProviderScope(
    key: UniqueKey(),
    overrides: [
      databaseProvider.overrideWithValue(db),
      programRepositoryProvider.overrideWithValue(programs),
      localScheduleDateServiceProvider.overrideWithValue(dates),
      localTimezoneServiceProvider.overrideWithValue(
        LocalTimezoneService(dates: dates, read: () async => 'Asia/Kolkata'),
      ),
      calendarReadRepositoryProvider.overrideWithValue(
        CalendarReadRepository(db, dates: dates),
      ),
      programActivationCoordinatorProvider.overrideWithValue(activation),
      ...extraOverrides,
    ],
    child: MaterialApp(
      home: mediaQuery == null
          ? child
          : MediaQuery(data: mediaQuery, child: child),
    ),
  );
  await tester.runAsync(() => tester.pumpWidget(app));
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

class _CopyingProgramRepository extends ProgramRepository {
  _CopyingProgramRepository(super.db, this.copiedVersionId);

  final String copiedVersionId;
  String? copiedSourceVersionId;

  @override
  Future<String> copyToNewDraftVersion(String sourceVersionId) async {
    copiedSourceVersionId = sourceVersionId;
    return copiedVersionId;
  }
}

class _ImmediateActivationCoordinator extends ProgramActivationCoordinator {
  _ImmediateActivationCoordinator(
    super.db, {
    required super.dates,
    required this.onActivate,
  }) : super(nowUtc: () => now);

  final void Function(ActivateProgramVersionCommand command) onActivate;
  ActivateProgramVersionCommand? activatedCommand;

  @override
  Future<ActivationResult> activate(
    ActivateProgramVersionCommand command,
  ) async {
    activatedCommand = command;
    onActivate(command);
    return ActivationResult(
      programVersionId: command.programVersionId,
      occurrences: const [],
      wasIdempotent: false,
    );
  }
}

class _StaticCalendarReadRepository extends CalendarReadRepository {
  _StaticCalendarReadRepository(
    super.db, {
    required super.dates,
    required this.snapshot,
  });

  final CalendarReadSnapshot snapshot;

  @override
  Future<CalendarReadSnapshot> readSnapshot({
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) async => snapshot;
}

class _StaticWorkoutRepository extends WorkoutRepository {
  _StaticWorkoutRepository(super.db, this.draft);

  final WorkoutDraft? draft;

  @override
  Future<WorkoutDraft?> getActiveDraft() async => draft;
}
