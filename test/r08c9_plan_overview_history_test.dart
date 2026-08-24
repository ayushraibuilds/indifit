import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_execution_compatibility_read_repository.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/plan_library_read_repository.dart';
import 'package:indifit/data/repositories/plan_overview_read_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/features/training/plan_library_screen.dart';
import 'package:indifit/features/training/workout_history_screen.dart';

final _now = DateTime.utc(2026, 8, 24, 10);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProgramRepository programs;
  late LocalScheduleDateService dates;

  setUp(() async {
    db = AppDatabase.memory();
    programs = ProgramRepository(db);
    dates = LocalScheduleDateService(nowUtc: () => _now);
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('c9-exercise'),
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
    'reads the exact requested version instead of the library preference',
    () async {
      final publishedVersionId = await _createPublishedPlan(
        programs,
        db,
        name: 'Versioned plan',
      );
      final draftVersionId = await programs.copyToNewDraftVersion(
        publishedVersionId,
      );

      final exact = await PlanLibraryReadRepository(
        db,
      ).readVersion(draftVersionId);
      final library = await PlanLibraryReadRepository(db).read();

      expect(exact, isNotNull);
      expect(exact!.version.id, draftVersionId);
      expect(exact.version.status, 'draft');
      expect(library.entries.single.version.id, publishedVersionId);
    },
  );

  test(
    'overview joins planned history by exact occurrence and leaves independent activity out',
    () async {
      final sourceVersionId = await _createPublishedPlan(
        programs,
        db,
        name: 'Plan with history',
      );
      final versionId = await programs.copyToNewDraftVersion(sourceVersionId);
      final activation = ProgramActivationCoordinator(
        db,
        dates: dates,
        nowUtc: () => _now,
      );
      await activation.activate(
        ActivateProgramVersionCommand(
          programVersionId: versionId,
          commandId: 'c9-activate',
          activationLocalDate: '2026-08-24',
          timezoneId: 'Asia/Kolkata',
        ),
      );

      final calendar = CalendarReadRepository(db, dates: dates);
      final occurrence = (await calendar.readOccurrencesForVersion(
        programVersionId: versionId,
        timezoneId: 'Asia/Kolkata',
      )).single;
      await (db.update(
        db.scheduledSessionOccurrences,
      )..where((row) => row.id.equals(occurrence.occurrence.id))).write(
        const ScheduledSessionOccurrencesCompanion(
          status: Value('partiallyCompleted'),
          progressionDisposition: Value('pending'),
        ),
      );
      final plannedSessionId = await _insertHistory(
        db,
        name: 'Plan with history · Monday',
        completionKind: 'partial',
        scheduledOccurrenceId: occurrence.occurrence.id,
      );
      await _insertHistory(db, name: 'Independent workout');
      await _insertHistory(db, name: 'Morning run', activityType: 'running');

      final snapshot = await PlanOverviewReadRepository(
        plans: PlanLibraryReadRepository(db),
        calendar: calendar,
        history: B02ExecutionCompatibilityReadRepository(db),
      ).read(versionId: versionId, timezoneId: 'Asia/Kolkata');

      expect(snapshot, isNotNull);
      expect(snapshot!.isCurrent, isTrue);
      expect(
        snapshot.occurrences.single.occurrence.id,
        occurrence.occurrence.id,
      );
      expect(snapshot.completedOccurrences, hasLength(1));
      expect(snapshot.history, hasLength(1));
      expect(snapshot.history.single.sessionId, plannedSessionId);
      expect(snapshot.history.single.isPartial, isTrue);
      expect(
        snapshot.history.single.scheduledOccurrenceId,
        occurrence.occurrence.id,
      );
    },
  );

  testWidgets('library opens the exact version-scoped overview route', (
    tester,
  ) async {
    late String versionId;
    late PlanLibraryEntry entry;
    await tester.runAsync(() async {
      versionId = await _createPublishedPlan(programs, db, name: 'Route plan');
      entry = (await PlanLibraryReadRepository(db).readVersion(versionId))!;
    });
    final snapshot = PlanLibrarySnapshot(
      entries: [entry],
      activeProgramVersionId: null,
    );
    final router = GoRouter(
      initialLocation: '/plan-library',
      routes: [
        GoRoute(
          path: '/plan-library',
          builder: (context, state) => const PlanLibraryScreen(),
        ),
        GoRoute(
          path: '/plan-overview/:versionId',
          builder: (context, state) =>
              Text('overview route ${state.pathParameters['versionId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planLibrarySnapshotProvider.overrideWith((ref) async => snapshot),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpFuture(tester);
    await tester.tap(find.byType(PlanLibraryCard));
    await _pumpRoute(tester);

    expect(find.text('overview route $versionId'), findsOneWidget);
  });

  testWidgets(
    'overview keeps current state, routes edit/calendar/history, and stays usable at text scale',
    (tester) async {
      late String versionId;
      late PlanLibraryEntry entry;
      await tester.runAsync(() async {
        versionId = await _createPublishedPlan(
          programs,
          db,
          name: 'Overview plan',
        );
        await _setActive(db, versionId);
        entry = (await PlanLibraryReadRepository(db).readVersion(versionId))!;
      });
      final occurrence = _testOccurrence(entry);
      final history = _historyItem(
        id: 7,
        name: 'Overview plan · Monday',
        scheduledOccurrenceId: occurrence.occurrence.id,
        completionKind: 'partial',
      );
      final snapshot = PlanOverviewSnapshot(
        entry: entry,
        occurrences: [occurrence],
        history: [history],
      );
      final router = GoRouter(
        initialLocation: '/plan-overview/$versionId',
        routes: [
          GoRoute(
            path: '/plan-overview/:versionId',
            builder: (context, state) => PlanOverviewScreen(
              versionId: state.pathParameters['versionId'],
            ),
          ),
          GoRoute(
            path: '/program-author',
            builder: (context, state) =>
                Text('builder ${state.uri.queryParameters['versionId']}'),
          ),
          GoRoute(
            path: '/calendar',
            builder: (context, state) =>
                Text('calendar ${state.uri.queryParameters['date']}'),
          ),
          GoRoute(
            path: '/workout-history/:sessionId',
            builder: (context, state) =>
                Text('history ${state.pathParameters['sessionId']}'),
          ),
          GoRoute(
            path: '/workout-history',
            builder: (context, state) => const Text('all history'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            planOverviewSnapshotProvider(
              versionId,
            ).overrideWith((ref) async => snapshot),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: child!,
            ),
          ),
        ),
      );
      await _pumpFuture(tester);

      expect(find.text('Plan overview'), findsOneWidget);
      expect(find.text('Current plan'), findsWidgets);
      expect(find.text('Plan progress'), findsOneWidget);
      expect(find.text('Workouts from this plan'), findsOneWidget);
      expect(find.textContaining('partially completed'), findsWidgets);
      expect(find.textContaining('Calories'), findsNothing);
      expect(find.textContaining('PR'), findsNothing);
      expect(tester.takeException(), isNull);

      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Edit plan'), findsOneWidget);
      semantics.dispose();

      await tester.ensureVisible(find.text('Edit plan'));
      await tester.pump();
      await tester.tap(find.text('Edit plan'));
      await _pumpRoute(tester);
      expect(find.text('builder $versionId'), findsOneWidget);

      router.go('/plan-overview/$versionId');
      await _pumpRoute(tester);
      await tester.ensureVisible(find.text('Open in calendar'));
      await tester.pump();
      await tester.tap(find.text('Open in calendar'));
      await _pumpRoute(tester);
      expect(find.textContaining('calendar '), findsOneWidget);

      router.go('/plan-overview/$versionId');
      await _pumpRoute(tester);
      await tester.ensureVisible(find.text('View details'));
      await tester.pump();
      await tester.tap(find.text('View details'));
      await _pumpRoute(tester);
      expect(find.text('history 7'), findsOneWidget);
    },
  );

  testWidgets(
    'missing overview fails closed and history preserves source facts',
    (tester) async {
      const missingVersionId = 'missing-version';
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            planOverviewSnapshotProvider(
              missingVersionId,
            ).overrideWith((ref) async => null),
            workoutHistoryItemsProvider.overrideWith(
              (ref) async => [
                _historyItem(
                  id: 1,
                  name: 'Planned day',
                  scheduledOccurrenceId: 'occurrence-1',
                ),
                _historyItem(
                  id: 2,
                  name: 'Independent day',
                  completionKind: 'partial',
                ),
                _historyItem(
                  id: 3,
                  name: 'Morning run',
                  activityType: B02ActivityType.running,
                ),
              ],
            ),
          ],
          child: MaterialApp(
            home: const PlanOverviewScreen(versionId: missingVersionId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Plan unavailable'), findsOneWidget);
      expect(find.text('Canonical'), findsNothing);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutHistoryItemsProvider.overrideWith(
              (ref) async => [
                _historyItem(
                  id: 1,
                  name: 'Planned day',
                  scheduledOccurrenceId: 'occurrence-1',
                ),
                _historyItem(
                  id: 2,
                  name: 'Independent day',
                  completionKind: 'partial',
                ),
                _historyItem(
                  id: 3,
                  name: 'Morning run',
                  activityType: B02ActivityType.running,
                ),
              ],
            ),
          ],
          key: UniqueKey(),
          child: const MaterialApp(home: WorkoutHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Planned workout'), findsOneWidget);
      expect(find.textContaining('Independent workout'), findsOneWidget);
      expect(find.textContaining('Logged activity'), findsOneWidget);
      expect(find.textContaining('Partially completed'), findsOneWidget);
      expect(find.textContaining('Calories'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpFuture(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

Future<String> _createPublishedPlan(
  ProgramRepository programs,
  AppDatabase db, {
  required String name,
}) async {
  final programId = await programs.createProgram(
    name: name,
    notes: 'A factual plan note.',
    blocks: [
      ProgramBlockInput(
        name: 'Base block',
        ordinal: 0,
        weeks: [
          ProgramWeekInput(
            name: 'Week 1',
            ordinalInBlock: 0,
            programWeekOrdinal: 0,
            templates: [
              SessionTemplateInput(
                name: '$name · Monday',
                ordinal: 0,
                plannedWeekday: DateTime.monday,
                prescriptions: [
                  ExercisePrescriptionInput(
                    exerciseId: 'c9-exercise',
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
      publishedAtUtc: Value(_now),
    ),
  );
  return version.id;
}

Future<void> _setActive(AppDatabase db, String versionId) async {
  await (db.update(
    db.trainingPlanSettings,
  )..where((row) => row.id.equals(1))).write(
    TrainingPlanSettingsCompanion(
      activeProgramVersionId: Value(versionId),
      activeSinceLocalDate: const Value('2026-08-24'),
      activeSinceTimezoneId: const Value('Asia/Kolkata'),
      updatedAtUtc: Value(_now),
    ),
  );
}

Future<int> _insertHistory(
  AppDatabase db, {
  required String name,
  String activityType = 'strength',
  String completionKind = 'full',
  String? scheduledOccurrenceId,
}) {
  return db
      .into(db.workoutSessions)
      .insert(
        WorkoutSessionsCompanion.insert(
          name: name,
          totalVolume: 0,
          durationSeconds: 1800,
          estimatedCalories: 0,
          completedAt: Value(_now),
          scheduledOccurrenceId: Value<String?>(scheduledOccurrenceId),
          completionKind: Value(completionKind),
          activityType: Value(activityType),
        ),
      );
}

CalendarOccurrenceReadItem _testOccurrence(PlanLibraryEntry entry) {
  final block = ProgramBlock(
    id: 'c9-block',
    programVersionId: entry.version.id,
    ordinal: 0,
    name: 'Base block',
  );
  final week = ProgramWeek(
    id: 'c9-week',
    programVersionId: entry.version.id,
    programBlockId: block.id,
    ordinalInBlock: 0,
    programWeekOrdinal: 0,
    isDeload: false,
    name: 'Week 1',
  );
  final template = SessionTemplate(
    id: 'c9-template',
    programWeekId: week.id,
    ordinal: 0,
    name: 'Overview plan · Monday',
    plannedWeekday: DateTime.monday,
    activityType: 'strength',
  );
  final occurrence = ScheduledSessionOccurrence(
    id: 'c9-occurrence',
    programVersionId: entry.version.id,
    sessionTemplateId: template.id,
    programBlockOrdinal: 0,
    programWeekOrdinal: 0,
    sessionOrdinal: 0,
    repeatOrdinal: 0,
    originalLocalDate: '2026-08-24',
    originalTimezoneId: 'Asia/Kolkata',
    effectiveLocalDate: '2026-08-24',
    effectiveTimezoneId: 'Asia/Kolkata',
    status: 'completed',
    progressionDisposition: 'satisfied',
    createdAtUtc: _now,
  );
  return CalendarOccurrenceReadItem(
    occurrence: occurrence,
    template: template,
    week: week,
    block: block,
    version: entry.version,
    program: entry.program,
    prescriptions: const [],
    isOverdue: false,
    isDeload: false,
    isNextRequired: false,
  );
}

B02ActivityHistoryItem _historyItem({
  required int id,
  required String name,
  B02ActivityType activityType = B02ActivityType.strength,
  String? scheduledOccurrenceId,
  String completionKind = 'full',
}) => B02ActivityHistoryItem(
  sessionId: id,
  name: name,
  activityType: activityType,
  recordKind: B02HistoryRecordKind.canonical,
  completedAt: _now,
  durationSeconds: 1800,
  completionKind: completionKind,
  scheduledOccurrenceId: scheduledOccurrenceId,
  legacySetCount: 0,
  performedExerciseCount: activityType == B02ActivityType.strength ? 1 : 0,
  performedGroupCount: 0,
  cardioIntervalCount: 0,
  hasCardioDetail: false,
  hasMobilityDetail: false,
);
