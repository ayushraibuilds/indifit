import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/router/app_router.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_activity_session_repository.dart';
import 'package:indifit/data/repositories/b02_execution_compatibility_read_repository.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/exercise_picker_repository.dart';
import 'package:indifit/data/services/b02_activity_form_service.dart';
import 'package:indifit/features/activity/b02_activity_creation_screen.dart';
import 'package:indifit/features/exercise_picker/exercise_picker.dart';
import 'package:indifit/features/workout_player/widgets/manual_log_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StrengthExecutionRepository strength;
  late ActivitySessionRepository activities;

  setUp(() async {
    db = AppDatabase.memory();
    await db.select(db.workoutSessions).get();
    strength = StrengthExecutionRepository(
      db: db,
      calendarRepo: CalendarRepository(db),
    );
    activities = ActivitySessionRepository(db);
  });

  tearDown(() => db.close());

  Future<void> seedExercise({
    String id = 'c7-bench',
    String name = 'Bench Press',
  }) async {
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: Value(id),
            name: name,
            muscleGroups: 'Chest',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace',
            commonMistakes: 'Bounce',
          ),
        );
  }

  B02PerformedExerciseDraft manualExercise({
    String id = 'c7-bench',
    String name = 'Bench Press',
  }) => B02PerformedExerciseDraft(
    id: id,
    ordinal: 0,
    actualExerciseId: id,
    actualExerciseNameSnapshot: name,
    status: 'completed',
    sets: [
      B02PerformedSet(
        id: '$id-set-0',
        performedExerciseId: id,
        ordinal: 0,
        role: B02SetRole.warmup,
        actualLoadKg: 30,
        actualLoadBasis: B02LoadBasis.totalExternal,
        actualReps: 8,
      ),
      B02PerformedSet(
        id: '$id-set-1',
        performedExerciseId: id,
        ordinal: 1,
        role: B02SetRole.working,
        actualLoadKg: 60,
        actualLoadBasis: B02LoadBasis.totalExternal,
        actualReps: 8,
        actualRpe: 8,
      ),
    ],
  );

  group('R08C.7 manual completed strength', () {
    test('saves exact performed graph and selected historical date', () async {
      await seedExercise();
      final completedAt = DateTime.utc(2026, 8, 8, 12);

      final sessionId = await strength.saveManualCompletedWorkout(
        routineName: 'Saturday strength',
        durationSeconds: 2700,
        completedAtUtc: completedAt,
        performedExercises: [manualExercise()],
        idempotencyKey: 'c7-submit-1',
      );

      final session = await (db.select(
        db.workoutSessions,
      )..where((table) => table.id.equals(sessionId))).getSingle();
      expect(session.activityType, B02ActivityType.strength.dbValue);
      expect(session.scheduledOccurrenceId, isNull);
      expect(session.executionSnapshotJson, isNotNull);
      expect(session.estimatedCalories, 0);
      expect(session.completedAt.toUtc(), completedAt);
      expect(await db.select(db.workoutDrafts).get(), isEmpty);

      final exercises = await (db.select(
        db.performedExercises,
      )..where((table) => table.sessionId.equals(sessionId))).get();
      final sets =
          await (db.select(db.performedSets)..where(
                (table) =>
                    table.performedExerciseId.equals(exercises.single.id),
              ))
              .get();
      expect(exercises.single.actualExerciseId, 'c7-bench');
      expect(exercises.single.actualExerciseNameSnapshot, 'Bench Press');
      expect(sets.map((set) => set.role), ['warmup', 'working']);
      expect(sets.map((set) => set.actualReps), [8, 8]);
      expect(sets.singleWhere((set) => set.role == 'working').actualRpe, 8);

      final history = await B02ExecutionCompatibilityReadRepository(
        db,
      ).readStrengthSession(sessionId);
      expect(history, isNotNull);
      expect(history!.scheduledOccurrenceId, isNull);
      expect(history.exercises.single.actualExerciseId, 'c7-bench');
      expect(history.exercises.single.sets, hasLength(2));
    });

    test(
      'repeated submission with one key returns one completed record',
      () async {
        await seedExercise();
        final arguments = <String, dynamic>{
          'routineName': 'Repeated manual entry',
          'durationSeconds': 1800,
          'completedAtUtc': DateTime.utc(2026, 8, 9, 12),
          'performedExercises': [manualExercise()],
          'idempotencyKey': 'c7-repeat',
        };
        final ids = await Future.wait([
          strength.saveManualCompletedWorkout(
            routineName: arguments['routineName'] as String,
            durationSeconds: arguments['durationSeconds'] as int,
            completedAtUtc: arguments['completedAtUtc'] as DateTime,
            performedExercises:
                arguments['performedExercises']
                    as List<B02PerformedExerciseDraft>,
            idempotencyKey: arguments['idempotencyKey'] as String,
          ),
          strength.saveManualCompletedWorkout(
            routineName: arguments['routineName'] as String,
            durationSeconds: arguments['durationSeconds'] as int,
            completedAtUtc: arguments['completedAtUtc'] as DateTime,
            performedExercises:
                arguments['performedExercises']
                    as List<B02PerformedExerciseDraft>,
            idempotencyKey: arguments['idempotencyKey'] as String,
          ),
        ]);
        expect(ids[0], ids[1]);
        expect(await db.select(db.workoutSessions).get(), hasLength(1));
        expect(await db.select(db.performedExercises).get(), hasLength(1));
        expect(await db.select(db.performedSets).get(), hasLength(2));
      },
    );

    test('malformed or untrusted exercise identity fails closed', () async {
      await seedExercise();
      expect(
        strength.saveManualCompletedWorkout(
          routineName: 'Unknown exercise',
          durationSeconds: 1200,
          completedAtUtc: DateTime.utc(2026, 8, 10, 12),
          performedExercises: [
            manualExercise(id: 'not-in-catalog', name: 'Bench Press'),
          ],
          idempotencyKey: 'c7-invalid',
        ),
        throwsA(isA<B02StrengthExecutionException>()),
      );
      expect(await db.select(db.workoutSessions).get(), isEmpty);
      expect(await db.select(db.performedExercises).get(), isEmpty);
    });

    test('activity history route refuses strength records', () async {
      await seedExercise();
      final sessionId = await strength.saveManualCompletedWorkout(
        routineName: 'Strength belongs in workout history',
        durationSeconds: 1200,
        completedAtUtc: DateTime.utc(2026, 8, 10, 12),
        performedExercises: [manualExercise()],
        idempotencyKey: 'c7-strength-history-boundary',
      );

      expect(await activities.readTypedActivity(sessionId), isNull);
    });
  });

  group('R08C.7 Other Activity', () {
    test(
      'direct manual activity preserves supported fields without a draft',
      () async {
        final detail = B02CardioSessionDetail(
          activityType: B02ActivityType.running,
          durationSeconds: 2100,
          distanceMetres: 4200,
          isIntervalWorkout: true,
          inputMode: B02InputMode.manual,
          intervals: [
            B02CardioInterval(
              id: 'c7-work',
              ordinal: 0,
              segmentType: B02CardioSegmentType.work,
              durationSeconds: 300,
            ),
          ],
        );
        final completedAt = DateTime.utc(2026, 8, 11, 12);

        final sessionId = await activities.saveManualActivity(
          routineName: 'Park run',
          activityType: B02ActivityType.running,
          cardioDetail: detail,
          completedAtUtc: completedAt,
          idempotencyKey: 'c7-activity-1',
        );
        final record = await activities.readTypedActivity(sessionId);

        expect(record, isNotNull);
        expect(record!.source, B02ActivitySource.manual);
        expect(record.completedAtUtc, completedAt);
        expect(record.cardioDetail!.distanceMetres, 4200);
        expect(record.cardioIntervals.single.durationSeconds, 300);
        expect(record.providerEstimatedCaloriesKcal, isNull);
        expect(await db.select(db.workoutDrafts).get(), isEmpty);
        expect(
          (await db.select(db.workoutSessions).get())
              .single
              .scheduledOccurrenceId,
          isNull,
        );
        expect(await db.select(db.performedExercises).get(), isEmpty);
        expect(await db.select(db.performedSets).get(), isEmpty);
      },
    );

    test('unsupported activity type and malformed duration are rejected', () {
      expect(
        activities.saveManualActivity(
          routineName: 'Invalid',
          activityType: B02ActivityType.strength,
          completedAtUtc: DateTime.utc(2026, 8, 12, 12),
          idempotencyKey: 'c7-bad-type',
        ),
        throwsA(isA<B02ValidationException>()),
      );
      expect(
        () => B02CardioSessionDetail(
          activityType: B02ActivityType.walking,
          durationSeconds: 0,
          inputMode: B02InputMode.manual,
        ),
        throwsA(isA<B02ValidationException>()),
      );
    });

    test(
      'separate interval activities use collision-safe interval IDs',
      () async {
        const form = B02ActivityFormService();
        final first = form.build(
          activityType: B02ActivityType.running,
          durationSeconds: 1200,
          isIntervalWorkout: true,
          workSeconds: 60,
          recoverySeconds: 30,
          intervalIdPrefix: 'c7-interval-a',
        );
        final second = form.build(
          activityType: B02ActivityType.running,
          durationSeconds: 1200,
          isIntervalWorkout: true,
          workSeconds: 60,
          recoverySeconds: 30,
          intervalIdPrefix: 'c7-interval-b',
        );

        await activities.saveManualActivity(
          routineName: 'Intervals A',
          activityType: B02ActivityType.running,
          cardioDetail: first.cardioDetail,
          completedAtUtc: DateTime.utc(2026, 8, 12, 12),
          idempotencyKey: 'c7-interval-session-a',
        );
        await activities.saveManualActivity(
          routineName: 'Intervals B',
          activityType: B02ActivityType.running,
          cardioDetail: second.cardioDetail,
          completedAtUtc: DateTime.utc(2026, 8, 13, 12),
          idempotencyKey: 'c7-interval-session-b',
        );

        final intervals = await db.select(db.cardioIntervals).get();
        expect(intervals, hasLength(4));
        expect(intervals.map((interval) => interval.id).toSet(), hasLength(4));
      },
    );

    test(
      'malformed typed activity without modality detail fails closed',
      () async {
        final sessionId = await db
            .into(db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                name: 'Malformed run',
                totalVolume: 0,
                durationSeconds: 600,
                estimatedCalories: 0,
                completedAt: Value(DateTime.utc(2026, 8, 14, 12)),
                uuid: const Value('c7-malformed-run'),
                activityType: const Value('running'),
              ),
            );

        expect(await activities.readTypedActivity(sessionId), isNull);
      },
    );
  });

  group('R08C.7 route parsing', () {
    test('manual activity type parsing rejects misleading fallbacks', () {
      expect(parseManualActivityRouteType(null), B02ActivityType.running);
      expect(parseManualActivityRouteType('cycling'), B02ActivityType.cycling);
      expect(parseManualActivityRouteType('not-a-type'), isNull);
      expect(parseManualActivityRouteType('strength'), isNull);
      expect(parseManualActivityRouteType('legacy'), isNull);
    });
  });

  group('R08C.7 presentation', () {
    testWidgets(
      'manual workout form remains usable at narrow width and text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: MaterialApp(
                theme: AppTheme.darkTheme,
                home: Scaffold(
                  body: ManualLogSheet(selectedDate: DateTime(2026, 8, 8)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Log Completed Workout'), findsOneWidget);
        expect(find.text('Duration (min)'), findsOneWidget);
        expect(find.text('Save Workout Session'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'Workout date')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Other Activity form exposes no calories or unsupported metric',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: B02ActivityCreationScreen(
                initialType: B02ActivityType.running,
                selectedDate: DateTime(2026, 8, 8),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Record something you already did'), findsOneWidget);
        expect(find.text('Calories'), findsNothing);
        expect(find.text('Training load'), findsNothing);
        expect(find.text('Start activity'), findsNothing);
        expect(find.text('Save activity'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('removing set four restores the exercise removal anchor', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: ManualLogSheet(
                  selectedDate: DateTime(2026, 8, 8),
                  initialExercises: const [
                    ExercisePickerSelection(
                      exerciseId: 'c7-bench',
                      exerciseNameSnapshot: 'Bench Press',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );

      final repsFields = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Reps',
      );
      expect(repsFields, findsNWidgets(3));
      await tester.enterText(repsFields.first, '8');
      await tester.tap(find.text('Add Set'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      expect(repsFields, findsNWidgets(4));

      await tester.tap(find.byTooltip('Remove set 4').hitTestable());
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );

      expect(repsFields, findsNWidgets(3));
      expect(
        (tester.widget<TextField>(repsFields.first).controller!).text,
        '8',
      );
      expect(
        find.byTooltip('Remove Bench Press').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shared picker supports multi-select for manual workouts', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ExercisePicker(
                selectionContext: const ExerciseLibraryPickerContext(
                  title: 'Add exercises',
                ),
                repository: ExercisePickerRepository.fromSource(
                  const _C7ExerciseSource(),
                ),
                allowMultiple: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Browse all exercises'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bench Press'));
      await tester.pump();

      expect(find.text('Done (1)'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'Bench Press.*Selected')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

final class _C7ExerciseSource implements ExerciseCatalogSource {
  const _C7ExerciseSource();

  static const exercise = Exercise(
    id: 1,
    stableId: 'c7-bench',
    name: 'Bench Press',
    muscleGroups: 'Chest',
    equipment: 'Barbell',
    difficulty: 'Intermediate',
    formCues: 'Brace',
    commonMistakes: 'Bounce',
    isCustom: false,
  );

  @override
  Future<List<Exercise>> readAll() async => const [exercise];

  @override
  Future<Exercise?> readByStableId(String stableId) async =>
      stableId.trim() == exercise.stableId ? exercise : null;

  @override
  Future<List<Exercise>> readRecent() async => const [];
}
