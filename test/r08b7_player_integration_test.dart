import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/fixtures/exercise_display_muscles.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/b07_exercise_context_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/data/services/b02_strength_execution_draft_service.dart';
import 'package:indifit/features/media/b05_exercise_visual_registry.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_player_screen.dart';
import 'package:indifit/features/workout_player/widgets/b07_exercise_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late StrengthExecutionRepository executions;

  setUp(() async {
    database = AppDatabase.memory();
    executions = StrengthExecutionRepository(
      db: database,
      calendarRepo: CalendarRepository(database),
      nowUtc: () => DateTime.utc(2026, 8, 22, 8),
    );
    await _insertExercise(database, 'exercise-a', 'Exercise A', 'Chest');
    await _insertExercise(database, 'exercise-b', 'Exercise B', 'Back');
  });

  tearDown(() => database.close());

  testWidgets('Quick mounts the shared B.7 context panel', (tester) async {
    _setViewport(tester);
    final quick = (await tester.runAsync(() => _quickLaunch(executions)))!;
    final quickRepository = _RecordingB07ContextRepository(
      database,
      _contexts(),
    );
    await _pumpPlayer(tester, quick, executions, quickRepository);

    expect(find.byType(B07ExerciseContextPanel), findsOneWidget);
    final quickPanel = tester.widget<B07ExerciseContextPanel>(
      find.byType(B07ExerciseContextPanel),
    );
    expect(quickPanel.canonicalExerciseId, 'exercise-a');
    expect(quickRepository.requestedIds, contains('exercise-a'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Planned mounts the shared B.7 context panel', (tester) async {
    _setViewport(tester);
    final planned = (await tester.runAsync(() => _plannedLaunch(executions)))!;
    final plannedRepository = _RecordingB07ContextRepository(
      database,
      _contexts(),
    );
    await _pumpPlayer(tester, planned, executions, plannedRepository);

    expect(find.byType(B07ExerciseContextPanel), findsOneWidget);
    final plannedPanel = tester.widget<B07ExerciseContextPanel>(
      find.byType(B07ExerciseContextPanel),
    );
    expect(plannedPanel.canonicalExerciseId, 'exercise-a');
    expect(plannedPanel.exerciseNameSnapshot, 'Exercise A');
    expect(planned.occurrenceId, 'occurrence-b07');
    expect(plannedRepository.requestedIds, contains('exercise-a'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'actual UUID drives the panel and ticker rebuilds do not re-resolve it',
    (tester) async {
      _setViewport(tester);
      final launch = (await tester.runAsync(() => _quickLaunch(executions)))!;
      final repository = _RecordingB07ContextRepository(database, _contexts());
      final controller = await _pumpPlayer(
        tester,
        launch,
        executions,
        repository,
      );

      final slot = controller.state.slots.single;
      final panel = tester.widget<B07ExerciseContextPanel>(
        find.byType(B07ExerciseContextPanel),
      );
      expect(panel.canonicalExerciseId, 'exercise-a');
      expect(panel.exerciseNameSnapshot, 'Exercise A');

      final loadField = find.byKey(ValueKey('compact-load-${slot.id}'));
      final repsField = find.byKey(ValueKey('compact-reps-${slot.id}'));
      await tester.enterText(loadField, '72');
      await tester.enterText(repsField, '8');
      final resolutionsBeforeTicker = repository.requestedIds.length;
      for (var tick = 0; tick < 4; tick++) {
        await tester.pump(const Duration(seconds: 1));
      }

      expect(repository.requestedIds.length, resolutionsBeforeTicker);
      expect(tester.widget<TextFormField>(loadField).controller!.text, '72');
      expect(tester.widget<TextFormField>(repsField).controller!.text, '8');
      expect(
        find.byKey(const ValueKey('b07-context:exercise-a')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('B.4 replacement rebinds the mounted panel from A to B', (
    tester,
  ) async {
    _setViewport(tester);
    final launch = (await tester.runAsync(
      () => _quickLaunch(executions, snapshotId: 'replacement'),
    ))!;
    final repository = _RecordingB07ContextRepository(database, _contexts());
    final reboundLaunch = (await tester.runAsync(
      () => _replacementLaunch(executions, launch),
    ))!;
    await _pumpPlayer(tester, reboundLaunch, executions, repository);

    expect(reboundLaunch.draftId, launch.draftId);
    expect(
      reboundLaunch.state.performedExercises.single.actualExerciseId,
      'exercise-b',
    );
    expect(find.byKey(const ValueKey('b07-context:exercise-a')), findsNothing);
    expect(
      find.byKey(const ValueKey('b07-context:exercise-b')),
      findsOneWidget,
    );
    final rebound = tester.widget<B07ExerciseContextPanel>(
      find.byKey(const ValueKey('b07-context:exercise-b')),
    );
    expect(rebound.canonicalExerciseId, 'exercise-b');
    expect(rebound.exerciseNameSnapshot, 'Exercise B');
    expect(repository.requestedIds, contains('exercise-b'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing RepDB media falls back without blocking logging or rest',
    (tester) async {
      _setViewport(tester);
      final launch = (await tester.runAsync(
        () => _quickLaunch(executions, snapshotId: 'b07-rest'),
      ))!;
      final repository = _RecordingB07ContextRepository(database, _contexts());
      final controller = await _pumpPlayer(
        tester,
        launch,
        executions,
        repository,
        textScale: 1.8,
        theme: AppTheme.darkTheme,
      );
      final slot = controller.state.slots.single;
      await tester.runAsync(
        () => controller.recordSet(
          slot: slot,
          reps: 8,
          loadKg: 60,
          actualLoadBasis: B02LoadBasis.totalExternal,
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => controller.beginRest(slot, selectedSeconds: 120),
      );
      await tester.pump(const Duration(milliseconds: 40));

      expect(find.text('REST'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(B07ExerciseContextPanel),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(B07ExerciseContextPanel), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.textContaining('assets/generated/repdb'), findsNothing);
      expect(find.textContaining('FileSystemException'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('context resolution does not reset focused logging fields', (
    tester,
  ) async {
    _setViewport(tester);
    final launch = (await tester.runAsync(
      () => _quickLaunch(executions, snapshotId: 'async-context'),
    ))!;
    final pending = Completer<B07ExerciseContextResult>();
    final repository = _RecordingB07ContextRepository(
      database,
      _contexts(),
      pending: {'exercise-a': pending.future},
    );
    final controller = await _pumpPlayer(
      tester,
      launch,
      executions,
      repository,
    );
    final slot = controller.state.slots.single;
    final loadField = find.byKey(ValueKey('compact-load-${slot.id}'));
    final repsField = find.byKey(ValueKey('compact-reps-${slot.id}'));

    await tester.enterText(loadField, '91');
    await tester.enterText(repsField, '6');
    pending.complete(_contexts()['exercise-a']!);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));

    expect(tester.widget<TextFormField>(loadField).controller!.text, '91');
    expect(tester.widget<TextFormField>(repsField).controller!.text, '6');
    expect(controller.state.launch!.draftId, launch.draftId);
    expect(find.byType(B07ExerciseContextPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _RecordingB07ContextRepository extends B07ExerciseContextRepository {
  _RecordingB07ContextRepository(
    super.database,
    this.results, {
    this.pending = const {},
  });

  final Map<String, B07ExerciseContextResult> results;
  final Map<String, Future<B07ExerciseContextResult>> pending;
  final requestedIds = <String>[];

  @override
  Future<B07ExerciseContextResult> resolve(String canonicalExerciseId) {
    requestedIds.add(canonicalExerciseId);
    return pending[canonicalExerciseId] ??
        Future.value(
          results[canonicalExerciseId] ??
              const B07ExerciseContextResult.unavailable(),
        );
  }
}

Map<String, B07ExerciseContextResult> _contexts() {
  return {
    'exercise-a': _contextResult(
      id: 'exercise-a',
      name: 'Exercise A',
      muscleGroups: 'Chest,Triceps',
      cue: 'A cue',
    ),
    'exercise-b': _contextResult(
      id: 'exercise-b',
      name: 'Exercise B',
      muscleGroups: 'Back,Biceps',
      cue: 'B cue',
    ),
  };
}

B07ExerciseContextResult _contextResult({
  required String id,
  required String name,
  required String muscleGroups,
  required String cue,
}) {
  return B07ExerciseContextResult.available(
    B07ExerciseContext(
      canonicalExerciseId: id,
      canonicalName: name,
      equipment: 'Barbell',
      displayMuscles: ExerciseDisplayMuscles.fromMuscleGroups(muscleGroups),
      formCues: [cue],
      commonMistakes: const [],
    ),
  );
}

Future<B02StrengthExecutionController> _pumpPlayer(
  WidgetTester tester,
  B02StrengthExecutionLaunch launch,
  StrengthExecutionRepository executions,
  _RecordingB07ContextRepository repository, {
  ThemeData? theme,
  double textScale = 1,
}) async {
  final controller = B02StrengthExecutionController(
    StrengthExecutionCompatibilityAdapter(executions),
    initialLaunch: launch,
    nowUtc: () => DateTime.utc(2026, 8, 22, 8),
  );
  await tester.runAsync(controller.loadSlots);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(repository.database),
        b02StrengthExecutionScreenControllerProvider.overrideWith(
          (ref, _) => controller,
        ),
        b07ExerciseContextRepositoryProvider.overrideWithValue(repository),
        b05ExerciseVisualRegistryProvider.overrideWith(
          (ref) async => const B05ExerciseVisualRegistry.empty(),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData.fromView(tester.view).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: B02StrengthPlayerScreen(
            launch: launch,
            nowUtc: () => DateTime.utc(2026, 8, 22, 8),
          ),
        ),
      ),
    ),
  );
  for (var pump = 0; pump < 8; pump++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pump(const Duration(milliseconds: 100));
  return controller;
}

Future<B02StrengthExecutionLaunch> _quickLaunch(
  StrengthExecutionRepository executions, {
  String snapshotId = 'quick-integration',
}) async {
  final launch = await executions.startUnscheduledDraft(
    routineName: 'Quick workout',
    snapshotId: snapshotId,
    executionSnapshotJson: jsonEncode({
      'version': 1,
      'routineName': 'Quick workout',
      'prescriptions': [
        {
          'id': 'quick:exercise-a',
          'exerciseId': 'exercise-a',
          'exerciseNameSnapshot': 'Exercise A',
          'plannedSets': 1,
          'repsRange': '8-10',
        },
      ],
    }),
  );
  return launch;
}

Future<B02StrengthExecutionLaunch> _plannedLaunch(
  StrengthExecutionRepository executions,
) async {
  final launch = await _quickLaunch(executions, snapshotId: 'b07-planned');
  final prepared = await executions.prepareExecution(launch);
  return B02StrengthExecutionLaunch(
    draftId: launch.draftId,
    occurrenceId: 'occurrence-b07',
    executionSnapshotJson: launch.executionSnapshotJson,
    state: prepared.state,
  );
}

Future<B02StrengthExecutionLaunch> _replacementLaunch(
  StrengthExecutionRepository executions,
  B02StrengthExecutionLaunch launch,
) async {
  final prepared = await executions.prepareExecution(launch);
  final slot = (await executions.readExecutionSlots(launch)).single;
  final replaced = const B02StrengthExecutionDraftService().replaceExercise(
    state: prepared.state,
    slot: slot,
    actualExerciseId: 'exercise-b',
    actualExerciseNameSnapshot: 'Exercise B',
    substitutionReason: 'User-selected replacement',
  );
  return launch.copyWith(state: replaced);
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _insertExercise(
  AppDatabase database,
  String stableId,
  String name,
  String muscleGroups,
) async {
  await database
      .into(database.exercises)
      .insert(
        ExercisesCompanion.insert(
          stableId: Value(stableId),
          name: name,
          muscleGroups: muscleGroups,
          equipment: 'Barbell',
          difficulty: 'Intermediate',
          formCues: '',
          commonMistakes: '',
        ),
      );
}
