import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/core/theme/app_theme.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/models/b02_previous_performance_models.dart';
import 'package:indifit/data/repositories/b02_previous_performance_repository.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/exercise_picker/exercise_picker_models.dart';
import 'package:indifit/features/workout_player/b02_previous_performance_integration.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_player_screen.dart';

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
    await _insertExercise(database, 'exercise-a', 'Exercise A');
    await _insertExercise(database, 'exercise-b', 'Exercise B');
    await _insertExercise(database, 'exercise-c', 'Exercise C');
  });

  tearDown(() => database.close());

  test(
    'B.3 coordinator uses exact context and presents factual evidence',
    () async {
      B02PreviousPerformanceQuery? captured;
      final coordinator = B02PreviousPerformanceLookupCoordinator(
        resolve: (query) async {
          captured = query;
          return _availablePerformance(
            exerciseId: 'exercise-a',
            loadKg: 80,
            reps: 8,
          );
        },
      );
      final key = _key('exercise-a');

      await coordinator.request(
        key: key,
        query: B02PreviousPerformanceQuery(
          canonicalExerciseId: 'exercise-a',
          setContext: const B02PreviousPerformanceSetContext(
            role: B02SetRole.working,
            loadBasis: B02LoadBasis.totalExternal,
            effortMode: B02EffortMode.standard,
          ),
          asOfUtc: DateTime.utc(2026, 8, 22),
        ),
        onAccepted: (_) {},
      );

      expect(captured!.canonicalExerciseId, 'exercise-a');
      expect(captured!.setContext.loadBasis, B02LoadBasis.totalExternal);
      expect(captured!.setContext.role, B02SetRole.working);
      expect(
        B02PreviousPerformancePresentation.lastTime(coordinator.activeResult),
        '80 kg × 8 reps',
      );
      expect(
        B02PreviousPerformancePresentation.lastTime(coordinator.activeResult),
        isNot(contains('Recommended')),
      );
    },
  );

  test('late B.3 result cannot replace a newer exercise context', () async {
    final aResult = Completer<B02PreviousExercisePerformance>();
    final bResult = Completer<B02PreviousExercisePerformance>();
    final accepted = <String>[];
    final coordinator = B02PreviousPerformanceLookupCoordinator(
      resolve: (query) => query.canonicalExerciseId == 'exercise-a'
          ? aResult.future
          : bResult.future,
    );

    final aRequest = coordinator.request(
      key: _key('exercise-a'),
      query: _query('exercise-a'),
      onAccepted: (result) => accepted.add(result.canonicalExerciseId!),
    );
    final bRequest = coordinator.request(
      key: _key('exercise-b'),
      query: _query('exercise-b'),
      onAccepted: (result) => accepted.add(result.canonicalExerciseId!),
    );

    aResult.complete(
      _availablePerformance(exerciseId: 'exercise-a', loadKg: 80, reps: 8),
    );
    await aRequest;
    expect(accepted, isEmpty);

    bResult.complete(
      _availablePerformance(exerciseId: 'exercise-b', loadKg: 55, reps: 10),
    );
    await bRequest;

    expect(accepted, ['exercise-b']);
    expect(coordinator.activeResult!.canonicalExerciseId, 'exercise-b');
  });

  test('an in-flight exact context remains usable after A to B to A', () async {
    final aResult = Completer<B02PreviousExercisePerformance>();
    final bResult = Completer<B02PreviousExercisePerformance>();
    final accepted = <String>[];
    final coordinator = B02PreviousPerformanceLookupCoordinator(
      resolve: (query) => query.canonicalExerciseId == 'exercise-a'
          ? aResult.future
          : bResult.future,
    );

    final aRequest = coordinator.request(
      key: _key('exercise-a'),
      query: _query('exercise-a'),
      onAccepted: (result) => accepted.add(result.canonicalExerciseId!),
    );
    unawaited(
      coordinator.request(
        key: _key('exercise-b'),
        query: _query('exercise-b'),
        onAccepted: (result) => accepted.add(result.canonicalExerciseId!),
      ),
    );
    await coordinator.request(
      key: _key('exercise-a'),
      query: _query('exercise-a'),
      onAccepted: (result) => accepted.add(result.canonicalExerciseId!),
    );

    aResult.complete(
      _availablePerformance(exerciseId: 'exercise-a', loadKg: 80, reps: 8),
    );
    await aRequest;

    expect(accepted, ['exercise-a']);
    expect(coordinator.activeResult!.canonicalExerciseId, 'exercise-a');
    bResult.complete(
      _availablePerformance(exerciseId: 'exercise-b', loadKg: 55, reps: 10),
    );
  });

  test('safe-prefill claim is one-time even across rebuilds', () {
    final coordinator = B02PreviousPerformanceLookupCoordinator(
      resolve: (_) async =>
          _availablePerformance(exerciseId: 'exercise-a', loadKg: 80, reps: 8),
    );
    final key = _key('exercise-a');

    expect(coordinator.claimPrefill(key), isTrue);
    expect(coordinator.claimPrefill(key), isFalse);
  });

  test(
    'Quick replacement keeps the same draft and occurrence-less origin',
    () async {
      final launch = await _quickLaunch(executions);
      final controller = B02StrengthExecutionController(
        StrengthExecutionCompatibilityAdapter(executions),
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 8, 22, 8),
      );
      await controller.loadSlots();
      final slot = controller.state.slots.single;
      final target = QuickExerciseReplacementTarget(
        draftId: launch.draftId,
        slotId: slot.id,
        currentPerformedExerciseId: slot.exerciseId!,
        currentExerciseNameSnapshot: slot.exerciseNameSnapshot,
      );

      final compatibility = await controller.readCompatibility(target: target);
      expect(compatibility.knowledge, CanonicalReplacementKnowledge.known);
      expect(
        compatibility.forExerciseId('exercise-b').state,
        CanonicalReplacementCandidateState.allowed,
      );

      await controller.commit(
        target: target,
        selection: const ExercisePickerSelection(
          exerciseId: 'exercise-b',
          exerciseNameSnapshot: 'Exercise B',
        ),
      );

      expect(controller.state.launch!.draftId, launch.draftId);
      expect(controller.state.launch!.occurrenceId, isNull);
      expect(controller.state.slots.single.id, slot.id);
      expect(
        controller
            .state
            .launch!
            .state
            .performedExercises
            .single
            .actualExerciseId,
        'exercise-b',
      );
      expect(await database.select(database.workoutDrafts).get(), hasLength(1));

      final reboundTarget = QuickExerciseReplacementTarget(
        draftId: launch.draftId,
        slotId: slot.id,
        currentPerformedExerciseId: 'exercise-b',
        currentExerciseNameSnapshot: 'Exercise B',
      );
      await controller.commit(
        target: reboundTarget,
        selection: const ExercisePickerSelection(
          exerciseId: 'exercise-a',
          exerciseNameSnapshot: 'Exercise A',
        ),
      );
      expect(
        controller
            .state
            .launch!
            .state
            .performedExercises
            .single
            .actualExerciseId,
        'exercise-a',
      );
    },
  );

  test('Planned replacement preserves the typed occurrence identity', () async {
    final quickLaunch = await _quickLaunch(
      executions,
      snapshotId: 'planned-like',
    );
    final plannedLaunch = B02StrengthExecutionLaunch(
      draftId: quickLaunch.draftId,
      occurrenceId: 'occurrence-42',
      executionSnapshotJson: quickLaunch.executionSnapshotJson,
      state: quickLaunch.state,
    );
    final controller = B02StrengthExecutionController(
      StrengthExecutionCompatibilityAdapter(executions),
      initialLaunch: plannedLaunch,
      nowUtc: () => DateTime.utc(2026, 8, 22, 8),
    );
    await controller.loadSlots();
    final slot = controller.state.slots.single;
    final target = PlannedExerciseReplacementTarget(
      draftId: plannedLaunch.draftId,
      scheduledOccurrenceId: 'occurrence-42',
      slotId: slot.id,
      expectedExerciseId: slot.exerciseId!,
      currentPerformedExerciseId: slot.exerciseId!,
      currentExerciseNameSnapshot: slot.exerciseNameSnapshot,
    );

    await controller.commit(
      target: target,
      selection: const ExercisePickerSelection(
        exerciseId: 'exercise-b',
        exerciseNameSnapshot: 'Exercise B',
      ),
    );

    expect(controller.state.launch!.draftId, plannedLaunch.draftId);
    expect(controller.state.launch!.occurrenceId, 'occurrence-42');
    expect(
      controller.state.launch!.state.performedExercises.single.actualExerciseId,
      'exercise-b',
    );
  });

  test(
    'replacement is fail-closed and logged evidence cannot be reassigned',
    () async {
      final launch = await _quickLaunch(executions);
      final controller = B02StrengthExecutionController(
        StrengthExecutionCompatibilityAdapter(executions),
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 8, 22, 8),
      );
      await controller.loadSlots();
      final slot = controller.state.slots.single;
      final target = QuickExerciseReplacementTarget(
        draftId: launch.draftId,
        slotId: slot.id,
        currentPerformedExerciseId: slot.exerciseId!,
        currentExerciseNameSnapshot: slot.exerciseNameSnapshot,
      );
      final malformed = QuickExerciseReplacementTarget(
        draftId: launch.draftId + 1,
        slotId: slot.id,
        currentPerformedExerciseId: slot.exerciseId!,
        currentExerciseNameSnapshot: slot.exerciseNameSnapshot,
      );

      expect(
        (await controller.readCompatibility(target: malformed)).knowledge,
        CanonicalReplacementKnowledge.unknown,
      );

      await controller.recordSet(slot: slot, reps: 8, loadKg: 60);
      final locked = await controller.readCompatibility(target: target);
      expect(
        locked.forExerciseId('exercise-b').state,
        CanonicalReplacementCandidateState.unavailable,
      );
      expect(
        locked.forExerciseId('exercise-b').unavailableReason,
        CanonicalReplacementUnavailableReason.loggedEvidenceLocked,
      );
      await expectLater(
        controller.commit(
          target: target,
          selection: const ExercisePickerSelection(
            exerciseId: 'exercise-b',
            exerciseNameSnapshot: 'Exercise B',
          ),
        ),
        throwsA(isA<B02ValidationException>()),
      );
      expect(
        controller
            .state
            .launch!
            .state
            .performedExercises
            .single
            .actualExerciseId,
        'exercise-a',
      );
    },
  );

  test('replacement rejects a mismatched canonical name snapshot', () async {
    final launch = await _quickLaunch(executions);
    final controller = B02StrengthExecutionController(
      StrengthExecutionCompatibilityAdapter(executions),
      initialLaunch: launch,
    );
    await controller.loadSlots();
    final slot = controller.state.slots.single;
    final target = QuickExerciseReplacementTarget(
      draftId: launch.draftId,
      slotId: slot.id,
      currentPerformedExerciseId: slot.exerciseId!,
      currentExerciseNameSnapshot: slot.exerciseNameSnapshot,
    );

    await expectLater(
      controller.commit(
        target: target,
        selection: const ExercisePickerSelection(
          exerciseId: 'exercise-b',
          exerciseNameSnapshot: 'Exercise C',
        ),
      ),
      throwsA(isA<B02ValidationException>()),
    );
    expect(controller.state.launch!.state.performedExercises, isEmpty);
  });

  test('replacement rebinds previous-performance lookup to the new actual exercise', () async {
    final launch = await _quickLaunch(executions, snapshotId: 'history-rebind');
    final controller = B02StrengthExecutionController(
      StrengthExecutionCompatibilityAdapter(executions),
      initialLaunch: launch,
    );
    await controller.loadSlots();
    final slot = controller.state.slots.single;
    final queriedIds = <String?>[];
    final lookup = B02PreviousPerformanceLookupCoordinator(
      resolve: (query) async {
        queriedIds.add(query.canonicalExerciseId);
        return _availablePerformance(
          exerciseId: query.canonicalExerciseId!,
          loadKg: query.canonicalExerciseId == 'exercise-b' ? 55 : 80,
          reps: query.canonicalExerciseId == 'exercise-b' ? 10 : 8,
        );
      },
    );

    await lookup.request(
      key: _key('exercise-a'),
      query: _query('exercise-a'),
      onAccepted: (_) {},
    );
    final target = QuickExerciseReplacementTarget(
      draftId: launch.draftId,
      slotId: slot.id,
      currentPerformedExerciseId: 'exercise-a',
      currentExerciseNameSnapshot: 'Exercise A',
    );
    await controller.commit(
      target: target,
      selection: const ExercisePickerSelection(
        exerciseId: 'exercise-b',
        exerciseNameSnapshot: 'Exercise B',
      ),
    );
    await lookup.request(
      key: _key('exercise-b'),
      query: _query('exercise-b'),
      onAccepted: (_) {},
    );

    expect(queriedIds, ['exercise-a', 'exercise-b']);
    expect(lookup.activeResult!.canonicalExerciseId, 'exercise-b');
    expect(controller.state.launch!.draftId, launch.draftId);
    expect(
      controller.state.launch!.state.performedExercises.single.actualExerciseId,
      'exercise-b',
    );
  });

  testWidgets(
    'player exposes factual Last time evidence and preserves typed input',
    (tester) async {
      final launch = (await tester.runAsync(
        () => _launchWithHistoryContext(executions),
      ))!;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final previous = _FakePreviousPerformanceRepository(
        database,
        _availablePerformance(exerciseId: 'exercise-a', loadKg: 80, reps: 8),
      );
      final controller = B02StrengthExecutionController(
        StrengthExecutionCompatibilityAdapter(executions),
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 8, 22, 8),
      );
      await tester.runAsync(controller.loadSlots);
      final slot = controller.state.slots.single;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            b02StrengthExecutionScreenControllerProvider.overrideWith(
              (ref, _) => controller,
            ),
            b02PreviousPerformanceRepositoryProvider.overrideWithValue(
              previous,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: B02StrengthPlayerScreen(
              launch: launch,
              nowUtc: () => DateTime.utc(2026, 8, 22, 8),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(previous.queries.single.canonicalExerciseId, 'exercise-a');
      expect(find.text('Last time'), findsOneWidget);
      expect(find.text('80 kg × 8 reps'), findsOneWidget);
      expect(find.text('Recommended'), findsNothing);

      final loadField = find.byKey(ValueKey('compact-load-${slot.id}'));
      expect(tester.widget<TextFormField>(loadField).controller!.text, '80.0');

      await tester.tap(find.byTooltip('Exercise actions'));
      await tester.pump();
      expect(find.text('Replace exercise'), findsOneWidget);
      Navigator.of(tester.element(find.text('Replace exercise'))).pop();
      await tester.pump();

      await tester.enterText(loadField, '90');
      await tester.pump();
      expect(tester.widget<TextFormField>(loadField).controller!.text, '90');
    },
  );

  testWidgets('late history prefill cannot overwrite a field the user typed', (
    tester,
  ) async {
    final launch = (await tester.runAsync(
      () => _launchWithHistoryContext(executions, snapshotId: 'race-case'),
    ))!;
    final result = _availablePerformance(
      exerciseId: 'exercise-a',
      loadKg: 80,
      reps: 8,
    );
    final resultCompleter = Completer<B02PreviousExercisePerformance>();
    final previous = _FakePreviousPerformanceRepository(
      database,
      result,
      delayedResult: resultCompleter,
    );
    final controller = B02StrengthExecutionController(
      StrengthExecutionCompatibilityAdapter(executions),
      initialLaunch: launch,
      nowUtc: () => DateTime.utc(2026, 8, 22, 8),
    );
    await tester.runAsync(controller.loadSlots);
    final slot = controller.state.slots.single;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          b02StrengthExecutionScreenControllerProvider.overrideWith(
            (ref, _) => controller,
          ),
          b02PreviousPerformanceRepositoryProvider.overrideWithValue(previous),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: B02StrengthPlayerScreen(launch: launch),
        ),
      ),
    );
    await tester.pump();
    final loadField = find.byKey(ValueKey('compact-load-${slot.id}'));
    await tester.enterText(loadField, '90');
    resultCompleter.complete(result);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(tester.widget<TextFormField>(loadField).controller!.text, '90');
  });
}

class _FakePreviousPerformanceRepository
    extends B02PreviousPerformanceRepository {
  _FakePreviousPerformanceRepository(
    super.database,
    this.result, {
    this.delayedResult,
  });

  final B02PreviousExercisePerformance result;
  final Completer<B02PreviousExercisePerformance>? delayedResult;
  final queries = <B02PreviousPerformanceQuery>[];

  @override
  Future<B02PreviousExercisePerformance> resolve(
    B02PreviousPerformanceQuery query,
  ) {
    queries.add(query);
    return delayedResult?.future ?? Future.value(result);
  }
}

B02PreviousPerformanceRequestKey _key(String exerciseId) {
  return B02PreviousPerformanceRequestKey(
    slotId: 'slot-a',
    actualExerciseId: exerciseId,
    role: B02SetRole.working,
    loadBasis: B02LoadBasis.totalExternal,
    effortMode: B02EffortMode.standard,
    endedAtFailure: false,
  );
}

B02PreviousPerformanceQuery _query(String exerciseId) {
  return B02PreviousPerformanceQuery(
    canonicalExerciseId: exerciseId,
    setContext: const B02PreviousPerformanceSetContext(
      role: B02SetRole.working,
      loadBasis: B02LoadBasis.totalExternal,
    ),
    asOfUtc: DateTime.utc(2026, 8, 22),
  );
}

B02PreviousExercisePerformance _availablePerformance({
  required String exerciseId,
  required double loadKg,
  required int reps,
}) {
  const sessionId = 42;
  const performedExerciseId = 'history-performed-exercise-a';
  const performedSetId = 'history-set-a';
  final set = B02PreviousPerformanceSet(
    performedSetId: performedSetId,
    ordinal: 0,
    role: B02SetRole.working,
    loadBasis: B02LoadBasis.totalExternal,
    actualLoadKg: loadKg,
    actualReps: reps,
    actualRpe: null,
    effortMode: B02EffortMode.standard,
    endedAtFailure: false,
    assistanceMode: null,
    assistanceKg: null,
    tempoEccentricSeconds: null,
    tempoBottomPauseSeconds: null,
    tempoConcentricSeconds: null,
    tempoLockoutPauseSeconds: null,
    pausedRepPosition: null,
    pausedRepSeconds: null,
    hasTechniqueSegments: false,
  );
  return B02PreviousExercisePerformance.available(
    canonicalExerciseId: exerciseId,
    sessionId: sessionId,
    sessionName: 'Previous workout',
    completedAtUtc: DateTime.utc(2026, 8, 20),
    occurrences: [
      B02PreviousPerformanceOccurrence(
        performedExerciseId: performedExerciseId,
        exerciseOrdinal: 0,
        actualExerciseId: exerciseId,
        actualExerciseNameSnapshot: exerciseId == 'exercise-b'
            ? 'Exercise B'
            : 'Exercise A',
        status: 'completed',
        expectedExerciseId: exerciseId,
        sourceExercisePrescriptionId: null,
        substitutionReason: null,
        sets: [set],
      ),
    ],
    safePrefill: B02PreviousPerformancePrefill(
      sessionId: sessionId,
      performedExerciseId: performedExerciseId,
      performedSetId: performedSetId,
      setOrdinal: 0,
      role: B02SetRole.working,
      loadBasis: B02LoadBasis.totalExternal,
      loadKg: loadKg,
      reps: reps,
      rpe: null,
    ),
  );
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

Future<B02StrengthExecutionLaunch> _launchWithHistoryContext(
  StrengthExecutionRepository executions, {
  String snapshotId = 'history-context',
}) async {
  final launch = await executions.startUnscheduledDraft(
    routineName: 'Quick workout',
    snapshotId: snapshotId,
    executionSnapshotJson: jsonEncode({
      'version': 1,
      'routineName': 'Quick workout',
      'prescriptions': const <Map<String, dynamic>>[],
    }),
  );
  final withExercise = await executions.addUnscheduledExercise(
    launch: launch,
    exerciseId: 'exercise-a',
    exerciseName: 'Exercise A',
    repsRange: '8-10',
  );
  final snapshot =
      jsonDecode(withExercise.executionSnapshotJson) as Map<String, dynamic>;
  final prescriptions = (snapshot['prescriptions'] as List)
      .map((raw) => Map<String, dynamic>.from(raw as Map))
      .toList();
  prescriptions.single['loadBasis'] = B02LoadBasis.totalExternal.dbValue;
  final updated = withExercise.copyWith(
    executionSnapshotJson: jsonEncode({
      ...snapshot,
      'prescriptions': prescriptions,
    }),
  );
  final prepared = await executions.prepareExecution(updated);
  return updated.copyWith(state: prepared.state);
}

Future<void> _insertExercise(
  AppDatabase database,
  String stableId,
  String name,
) async {
  await database
      .into(database.exercises)
      .insert(
        ExercisesCompanion.insert(
          stableId: Value(stableId),
          name: name,
          muscleGroups: 'Chest',
          equipment: 'Barbell',
          difficulty: 'Intermediate',
          formCues: '',
          commonMistakes: '',
        ),
      );
}
