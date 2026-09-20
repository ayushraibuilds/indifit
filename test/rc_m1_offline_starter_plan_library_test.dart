import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/calendar_read_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/repositories/equipment_preference_repository.dart';
import 'package:indifit/data/repositories/plan_library_read_repository.dart';
import 'package:indifit/data/repositories/program_activation_coordinator.dart';
import 'package:indifit/data/repositories/program_repository.dart';
import 'package:indifit/data/repositories/workout_execution_compatibility_adapter.dart';
import 'package:indifit/features/training/plan_library_screen.dart';

import 'support/indifit_test_harness.dart';

final _now = DateTime.utc(2026, 9, 1, 8);

void main() {
  initializeIndiFitTestHarness();

  late TestDatabaseScope scope;
  late AppDatabase db;
  late ProgramRepository programs;
  late LocalScheduleDateService dates;

  setUp(() {
    setIndiFitTestPreferences({'onboarding_skipped': true});
    scope = registerTestDatabaseScope();
    db = scope.create();
    programs = ProgramRepository(db);
    dates = LocalScheduleDateService(nowUtc: () => _now);
  });

  test(
    'fresh install exposes eight reviewed plans without network access',
    () async {
      final snapshot = await HttpOverrides.runZoned(
        () => PlanLibraryReadRepository(db, programs: programs).read(),
        createHttpClient: (_) => throw StateError(
          'The bundled starter catalogue attempted network access.',
        ),
      );

      expect(snapshot.entries, hasLength(8));
      expect(snapshot.activeProgramVersionId, isNull);
      expect(
        snapshot.entries.map((entry) => entry.starterPlan?.id).toSet(),
        hasLength(8),
      );
      expect(
        snapshot.entries.map((entry) => entry.program.id).toSet(),
        hasLength(8),
      );
      expect(
        snapshot.entries.map((entry) => entry.version.id).toSet(),
        hasLength(8),
      );
      expect(snapshot.entries, everyElement(_isReadyBundledPlan));

      final secondSnapshot = await PlanLibraryReadRepository(
        db,
        programs: programs,
      ).read();
      expect(secondSnapshot.entries, hasLength(8));
      expect(await db.select(db.programs).get(), hasLength(8));
      expect(await db.select(db.programVersions).get(), hasLength(8));
    },
  );

  test(
    'every bundled prescription resolves to the canonical exercise UUID',
    () async {
      final snapshot = await PlanLibraryReadRepository(
        db,
        programs: programs,
      ).read();
      final exerciseRows = await db.select(db.exercises).get();
      final canonicalIds = exerciseRows
          .map((exercise) => exercise.stableId)
          .whereType<String>()
          .toSet();

      for (final entry in snapshot.entries) {
        expect(entry.detail.blocks, isNotEmpty, reason: entry.program.name);
        expect(entry.detail.weeks, hasLength(4), reason: entry.program.name);
        expect(
          entry.metadata.trainingDaysPerWeek,
          entry.starterPlan!.daysPerWeek,
          reason: entry.program.name,
        );
        for (final prescription in entry.detail.exercisePrescriptions) {
          expect(
            prescription.exerciseId,
            isNotNull,
            reason: entry.program.name,
          );
          expect(
            canonicalIds,
            contains(prescription.exerciseId),
            reason:
                '${entry.program.name}: ${prescription.exerciseNameSnapshot}',
          );
        }
      }
    },
  );

  testWidgets('Gym, Home and day-count discovery remain useful', (
    tester,
  ) async {
    final snapshot = await tester.runAsync(
      () => PlanLibraryReadRepository(db, programs: programs).read(),
    );
    await _pumpLibrary(tester, db: db, programs: programs, snapshot: snapshot!);

    expect(find.text('Build your own plan'), findsOneWidget);
    expect(find.text('Beginner — 3-Day Full Body'), findsOneWidget);
    expect(find.text('Bodyweight Basics'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Gym'));
    await tester.pump();
    expect(find.text('Beginner — 3-Day Full Body'), findsOneWidget);
    expect(find.text('5-Day Hypertrophy Split'), findsOneWidget);
    expect(find.text('Bodyweight Basics'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Home'));
    await tester.pump();
    expect(find.text('Bodyweight Basics'), findsOneWidget);
    expect(find.text('Dumbbell Full Body — 3 Day'), findsOneWidget);
    expect(find.text('4-Day Upper / Lower'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Limited equipment'));
    await tester.pump();
    expect(find.text('Minimal Equipment — 3 Day'), findsOneWidget);
    expect(find.text('Bodyweight Basics'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All equipment'));
    await tester.tap(find.widgetWithText(ChoiceChip, '4 days'));
    await tester.pump();
    expect(find.text('4-Day Upper / Lower'), findsOneWidget);
    expect(find.text('Beginner — 3-Day Full Body'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile equipment only highlights a deterministic default', (
    tester,
  ) async {
    final snapshot = await tester.runAsync(
      () => PlanLibraryReadRepository(db, programs: programs).read(),
    );
    await _pumpLibrary(
      tester,
      db: db,
      programs: programs,
      snapshot: snapshot!,
      profile: const UserProfileState(
        isLoaded: true,
        hasProfile: true,
        calorieGoal: 2000,
        proteinGoal: 120,
        carbsGoal: 230,
        fatGoal: 65,
        currentWeight: 70,
        equipmentAccess: 'dumbbells',
      ),
    );

    expect(find.text('Recommended for you'), findsOneWidget);
    expect(find.text('Dumbbell Full Body — 3 Day'), findsOneWidget);
    expect(find.text('Browse plans'), findsWidgets);
  });

  testWidgets('preview reveals canonical structure without activation', (
    tester,
  ) async {
    final snapshot = await tester.runAsync(
      () => PlanLibraryReadRepository(db, programs: programs).read(),
    );
    final entry = snapshot!.entries.firstWhere(
      (item) => item.starterPlan?.id == 'beginner-full-body-3-day',
    );

    await _pumpLibrary(
      tester,
      db: db,
      programs: programs,
      snapshot: snapshot,
      child: PlanLibraryDetailScreen(programId: entry.program.id),
    );

    expect(find.text('Use this plan'), findsOneWidget);
    expect(find.text('Full gym'), findsOneWidget);
    expect(find.text('Plan structure'), findsOneWidget);
    expect(find.text('Leg Press'), findsNothing);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Leg Press'), findsWidgets);

    final activeVersionId = await tester.runAsync(() async {
      final settings = (await db.select(db.trainingPlanSettings).get()).single;
      return settings.activeProgramVersionId;
    });
    expect(activeVersionId, isNull);
  });

  test(
    'activation creates ordinary B01 calendar state and starts B02 flow',
    () => HttpOverrides.runZoned(
      () async {
        final snapshot = await PlanLibraryReadRepository(
          db,
          programs: programs,
        ).read();
        final source = snapshot.entries.firstWhere(
          (entry) => entry.starterPlan?.id == 'beginner-full-body-3-day',
        );
        final userVersion = await programs.copyToNewDraftVersion(
          source.version.id,
        );
        final activation = ProgramActivationCoordinator(
          db,
          dates: dates,
          nowUtc: () => _now,
        );

        final result = await activation.activate(
          ActivateProgramVersionCommand(
            programVersionId: userVersion,
            commandId: 'rc-m1-offline-activate',
            activationLocalDate: '2026-09-01',
            timezoneId: 'Asia/Kolkata',
          ),
        );

        expect(result.occurrences, hasLength(12));
        final calendar = await CalendarReadRepository(db, dates: dates)
            .readSnapshot(
              startLocalDate: '2026-09-01',
              endLocalDate: '2026-10-31',
              timezoneId: 'Asia/Kolkata',
            );
        expect(calendar.activeProgramVersionId, userVersion);
        expect(calendar.activeProgramName, 'Beginner — 3-Day Full Body');
        expect(calendar.rangeOccurrences, hasLength(12));
        expect(
          calendar.rangeOccurrences.any((item) => item.isNextRequired),
          isTrue,
        );

        final execution = WorkoutExecutionCompatibilityAdapter(
          db: db,
          calendarRepo: CalendarRepository(
            db,
            dates: dates,
            nowUtc: () => _now,
          ),
          preferenceRepo: ExercisePreferenceRepository(db),
        );
        final launch = await execution.startScheduledOccurrence(
          occurrenceId: result.occurrences.first.id,
          commandId: 'rc-m1-offline-start',
          confirmedOutsideEffectiveDate: true,
        );
        expect(launch.exercises, isNotEmpty);
        expect(launch.exercises.first.exerciseName, 'Leg Press');
        expect(
          (await db.select(db.workoutDrafts).get())
              .single
              .scheduledOccurrenceId,
          result.occurrences.first.id,
        );
      },
      createHttpClient: (_) {
        throw StateError('Offline plan activation attempted network access.');
      },
    ),
  );

  test(
    'customizing a selected copy cannot mutate its bundled source',
    () async {
      final snapshot = await PlanLibraryReadRepository(
        db,
        programs: programs,
      ).read();
      final source = snapshot.entries.firstWhere(
        (entry) => entry.starterPlan?.id == 'dumbbell-full-body-3-day',
      );
      final originalSource = await programs.getProgramVersionDetail(
        source.version.id,
      );
      final userVersion = await programs.copyToNewDraftVersion(
        source.version.id,
      );
      final exercise = source.starterPlan!.sessions.first.exercises.first;

      await programs.updateDraftVersion(
        userVersion,
        blocks: [
          ProgramBlockInput(
            name: 'My changes',
            ordinal: 0,
            weeks: [
              ProgramWeekInput(
                ordinalInBlock: 0,
                programWeekOrdinal: 0,
                templates: [
                  SessionTemplateInput(
                    name: 'My workout',
                    ordinal: 0,
                    plannedWeekday: DateTime.saturday,
                    prescriptions: [
                      ExercisePrescriptionInput(
                        exerciseId: exercise.exerciseId,
                        exerciseNameSnapshot: exercise.canonicalName,
                        plannedSets: 2,
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

      final sourceAfter = await programs.getProgramVersionDetail(
        source.version.id,
      );
      final copyAfter = await programs.getProgramVersionDetail(userVersion);
      expect(
        sourceAfter!.exercisePrescriptions.length,
        originalSource!.exercisePrescriptions.length,
      );
      expect(sourceAfter.weeks, hasLength(4));
      expect(copyAfter!.weeks, hasLength(1));
      expect(copyAfter.exercisePrescriptions, hasLength(1));
    },
  );

  testWidgets('fresh Plan Library light golden', (tester) async {
    final snapshot = await tester.runAsync(
      () => PlanLibraryReadRepository(db, programs: programs).read(),
    );
    await _pumpGolden(
      tester,
      db: db,
      programs: programs,
      snapshot: snapshot!,
      theme: AppTheme.lightTheme,
      fileName: 'rc_m1_plan_library_fresh_light.png',
    );
  });

  testWidgets('Gym Plan Library dark golden', (tester) async {
    final snapshot = await tester.runAsync(
      () => PlanLibraryReadRepository(db, programs: programs).read(),
    );
    await _pumpGolden(
      tester,
      db: db,
      programs: programs,
      snapshot: snapshot!,
      theme: AppTheme.darkTheme,
      fileName: 'rc_m1_plan_library_gym_dark.png',
      prepare: (tester) async {
        await tester.tap(find.widgetWithText(ChoiceChip, 'Gym'));
        await tester.pump();
      },
    );
  });

  testWidgets('Home Plan Library compact golden', (tester) async {
    final snapshot = await tester.runAsync(
      () => PlanLibraryReadRepository(db, programs: programs).read(),
    );
    await _pumpGolden(
      tester,
      db: db,
      programs: programs,
      snapshot: snapshot!,
      theme: AppTheme.lightTheme,
      size: const Size(320, 568),
      fileName: 'rc_m1_plan_library_home_compact.png',
      prepare: (tester) async {
        await tester.tap(find.widgetWithText(ChoiceChip, 'Home'));
        await tester.pump();
      },
    );
  });

  testWidgets('starter plan preview dark golden', (tester) async {
    final snapshot = await tester.runAsync(
      () => PlanLibraryReadRepository(db, programs: programs).read(),
    );
    final entry = snapshot!.entries.firstWhere(
      (item) => item.starterPlan?.id == 'beginner-full-body-3-day',
    );
    await _pumpGolden(
      tester,
      db: db,
      programs: programs,
      snapshot: snapshot,
      theme: AppTheme.darkTheme,
      child: PlanLibraryDetailScreen(programId: entry.program.id),
      fileName: 'rc_m1_plan_preview_dark.png',
    );
  });
}

Matcher get _isReadyBundledPlan => predicate<PlanLibraryEntry>((entry) {
  return entry.isBundled &&
      entry.isReadyToUse &&
      entry.detail.weeks.isNotEmpty &&
      entry.detail.sessionTemplates.isNotEmpty &&
      entry.detail.exercisePrescriptions.isNotEmpty;
});

Future<void> _pumpLibrary(
  WidgetTester tester, {
  required AppDatabase db,
  required ProgramRepository programs,
  required PlanLibrarySnapshot snapshot,
  UserProfileState profile = const UserProfileState(
    isLoaded: true,
    hasProfile: false,
    calorieGoal: 2000,
    proteinGoal: 120,
    carbsGoal: 230,
    fatGoal: 65,
    currentWeight: 70,
  ),
  Widget child = const PlanLibraryScreen(),
  ThemeData? theme,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        programRepositoryProvider.overrideWithValue(programs),
        planLibrarySnapshotProvider.overrideWith((ref) async => snapshot),
        userProfileProvider.overrideWith(
          (ref) => _StaticProfileNotifier(profile),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(theme: theme, home: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpGolden(
  WidgetTester tester, {
  required AppDatabase db,
  required ProgramRepository programs,
  required PlanLibrarySnapshot snapshot,
  required ThemeData theme,
  required String fileName,
  Widget child = const PlanLibraryScreen(),
  Size size = const Size(390, 844),
  Future<void> Function(WidgetTester tester)? prepare,
}) async {
  await _pumpLibrary(
    tester,
    db: db,
    programs: programs,
    snapshot: snapshot,
    theme: theme,
    child: child,
    size: size,
  );
  if (prepare != null) {
    await prepare(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }
  await expectLater(
    find.byType(Scaffold).first,
    matchesGoldenFile('goldens/$fileName'),
  );
  expect(tester.takeException(), isNull);
}

class _StaticProfileNotifier extends UserProfileNotifier {
  _StaticProfileNotifier(UserProfileState value) : super() {
    state = value;
  }

  @override
  Future<void> loadProfile() => Future<void>.value();
}
