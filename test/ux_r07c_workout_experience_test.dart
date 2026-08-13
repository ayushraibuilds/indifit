import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/services/b02_rest_recommendation_service.dart';
import 'package:indifit/data/services/b02_strength_execution_draft_service.dart';
import 'package:indifit/features/exercise_library/exercise_details_sheet.dart';
import 'package:indifit/features/exercise_library/exercise_history_screen.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_player_screen.dart';
import 'package:indifit/features/workout_player/quick_workout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;
  late StrengthExecutionRepository executions;

  setUp(() async {
    db = AppDatabase.memory();
    executions = StrengthExecutionRepository(
      db: db,
      calendarRepo: CalendarRepository(db),
      nowUtc: () => DateTime.utc(2026, 8, 13, 8),
    );
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            stableId: const Value('r07c-bench'),
            name: 'Bench press',
            muscleGroups: 'Chest,Triceps',
            equipment: 'Barbell',
            difficulty: 'Intermediate',
            formCues: 'Brace your feet\nKeep the bar path controlled',
            commonMistakes: 'Bouncing the bar',
          ),
        );
  });

  tearDown(() => db.close());

  testWidgets('R07C Quick player makes Log set the primary action', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final launch = (await tester.runAsync(() => _launch(executions)))!;
    await _pumpPlayer(tester, launch, executions, AppTheme.lightTheme);

    expect(find.text('Log set'), findsOneWidget);
    expect(find.text('Suggested'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(B02StrengthPlayerScreen),
      matchesGoldenFile('goldens/ux_r07c_quick_player.png'),
    );
  });

  testWidgets('R07C planned player keeps target context quiet and reachable', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final launch =
        (await tester.runAsync(() => _launchPlannedLike(executions)))!;
    await _pumpPlayer(tester, launch, executions, AppTheme.lightTheme);

    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text('Log set'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(B02StrengthPlayerScreen),
      matchesGoldenFile('goldens/ux_r07c_planned_player.png'),
    );
    await tester.scrollUntilVisible(
      find.text('Review and finish'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Review and finish'), findsOneWidget);
  });

  testWidgets('R07C rest surface keeps wall-clock controls visible', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final launch =
        (await tester.runAsync(() => _launchWithRest(executions)))!;
    await _pumpPlayer(tester, launch, executions, AppTheme.darkTheme);

    expect(find.text('REST'), findsOneWidget);
    expect(find.text('−15 sec'), findsOneWidget);
    expect(find.text('+15 sec'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(B02StrengthPlayerScreen),
      matchesGoldenFile('goldens/ux_r07c_rest_state.png'),
    );
  });

  testWidgets('R07C exercise Guide stays concise and Performance is explicit', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final exercises =
        (await tester.runAsync(() => db.select(db.exercises).get()))!;
    final exercise = exercises.firstWhere((value) => value.name == 'Bench press');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: ExerciseDetailsSheet(exercise: exercise)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('GUIDE'), findsOneWidget);
    expect(find.text('PERFORMANCE'), findsOneWidget);
    expect(find.text('Exercise education'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ExerciseDetailsSheet),
      matchesGoldenFile('goldens/ux_r07c_guide.png'),
    );
  });

  testWidgets('R07C Performance empty state does not invent a chart', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: R07CPerformanceEmptyState()),
      ),
    );
    await tester.pump();

    expect(find.text('No performance logged yet'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(R07CPerformanceEmptyState),
      matchesGoldenFile('goldens/ux_r07c_performance_empty.png'),
    );
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

Future<void> _pumpPlayer(
  WidgetTester tester,
  B02StrengthExecutionLaunch launch,
  StrengthExecutionRepository executions,
  ThemeData theme,
) async {
  final controller = B02StrengthExecutionController(
    StrengthExecutionCompatibilityAdapter(executions),
    initialLaunch: launch,
  );
  await tester.runAsync(controller.loadSlots);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        b02StrengthExecutionScreenControllerProvider.overrideWith(
          (ref, _) => controller,
        ),
      ],
      child: MaterialApp(theme: theme, home: B02StrengthPlayerScreen(launch: launch)),
    ),
  );
  for (var pump = 0; pump < 8; pump++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<B02StrengthExecutionLaunch> _launch(
  StrengthExecutionRepository executions,
) async {
  var launch = await executions.startUnscheduledDraft(
    routineName: 'Quick workout',
    executionSnapshotJson: quickWorkoutSnapshotJson('Quick workout'),
    snapshotId: 'r07c-quick-player',
  );
  launch = await executions.addUnscheduledExercise(
    launch: launch,
    exerciseId: 'r07c-bench',
    exerciseName: 'Bench press',
  );
  final prepared = await executions.prepareExecution(launch);
  return launch.copyWith(state: prepared.state);
}

Future<B02StrengthExecutionLaunch> _launchWithRest(
  StrengthExecutionRepository executions,
) async {
  final launch = await _launch(executions);
  final prepared = await executions.prepareExecution(launch);
  final slot = (await executions.readExecutionSlots(launch)).single;
  final logged = const B02StrengthExecutionDraftService().recordSet(
    state: prepared.state,
    slot: slot,
    reps: 8,
    loadKg: 60,
    actualLoadBasis: B02LoadBasis.totalExternal,
    useSlotPrescription: false,
  );
  final resting = const B02RestDraftCoordinator().begin(
    logged,
    B02RestPeriod(
      id: 'rest:${slot.id}:0',
      performedSetId: logged.performedExercises.single.sets.single.id,
      scope: B02RestScope.exerciseSet,
      recommendedSeconds: 120,
      selectedSeconds: 120,
      source: B02RestSource.automatic,
      startedAtUtc: DateTime.now().toUtc().subtract(const Duration(seconds: 28)),
    ),
  );
  return launch.copyWith(state: resting);
}

Future<B02StrengthExecutionLaunch> _launchPlannedLike(
  StrengthExecutionRepository executions,
) async {
  final snapshot = jsonEncode({
    'version': 1,
    'routineName': 'Planned push',
    'groups': [
      {
        'id': 'r07c-group',
        'groupType': 'superset',
        'ordinal': 0,
        'roundCount': 1,
        'members': [
          {'exercisePrescriptionId': 'r07c-prescription', 'ordinal': 0},
        ],
      },
    ],
    'prescriptions': [
      {
        'id': 'r07c-prescription',
        'exerciseId': 'r07c-bench',
        'exerciseNameSnapshot': 'Bench press',
        'plannedSets': 3,
        'repsRange': '8-10',
        'targetLoadKg': 60,
        'loadBasis': 'totalExternal',
      },
    ],
  });
  final launch = await executions.startUnscheduledDraft(
    routineName: 'Planned push',
    executionSnapshotJson: snapshot,
    snapshotId: 'r07c-planned-player',
  );
  final prepared = await executions.prepareExecution(launch);
  return B02StrengthExecutionLaunch(
    draftId: launch.draftId,
    occurrenceId: 'r07c-planned-occurrence',
    executionSnapshotJson: launch.executionSnapshotJson,
    state: prepared.state,
  );
}
