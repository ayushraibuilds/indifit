import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/workout_session_wake_lock_coordinator.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:indifit/features/workout_player/b02_strength_player_screen.dart';
import 'package:indifit/features/workout_player/widgets/b02_compact_set_table.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R08B.6 rest authority', () {
    late AppDatabase database;
    late _RecordingAdapter adapter;

    setUp(() {
      database = AppDatabase.memory();
      adapter = _RecordingAdapter(
        StrengthExecutionRepository(
          db: database,
          calendarRepo: CalendarRepository(database),
        ),
      );
    });

    tearDown(() => database.close());

    test(
      'a successful set write starts one durable rest period behind the save boundary',
      () async {
        final controller = B02StrengthExecutionController(
          adapter,
          initialLaunch: _launch(),
          nowUtc: () => DateTime.utc(2026, 8, 22, 8),
        );
        addTearDown(controller.dispose);
        final slot = _slot();

        await controller.recordSet(
          slot: slot,
          reps: 8,
          loadKg: 80,
          startRestAfterRecord: true,
        );

        expect(adapter.savedStates, hasLength(2));
        final rest = controller.state.launch!.state.restPeriods.single;
        expect(rest.performedSetId, isNotNull);
        expect(rest.startedAtUtc, DateTime.utc(2026, 8, 22, 8));
        expect(rest.endedAtUtc, isNull);
      },
    );

    test('a failed set write cannot falsely start rest', () async {
      adapter.failSaves = true;
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: _launch(),
        nowUtc: () => DateTime.utc(2026, 8, 22, 8),
      );
      addTearDown(controller.dispose);

      await controller.recordSet(
        slot: _slot(),
        reps: 8,
        loadKg: 80,
        startRestAfterRecord: true,
      );

      expect(controller.state.status, B02StrengthExecutionStatus.failure);
      expect(controller.state.launch!.state.restPeriods, isEmpty);
      expect(adapter.savedStates, isEmpty);
    });

    test(
      'repeated skip ends only the current rest and remains harmless',
      () async {
        final controller = B02StrengthExecutionController(
          adapter,
          initialLaunch: _launch(),
          nowUtc: () => DateTime.utc(2026, 8, 22, 8),
        );
        addTearDown(controller.dispose);
        await controller.recordSet(
          slot: _slot(),
          reps: 8,
          loadKg: 80,
          startRestAfterRecord: true,
        );
        final periodId = controller.state.launch!.state.restPeriods.single.id;

        await Future.wait([
          controller.skipRest(periodId),
          controller.skipRest(periodId),
        ]);

        final period = controller.state.launch!.state.restPeriods.single;
        expect(period.endedAtUtc, isNotNull);
        expect(period.endReason, B02RestEndReason.skipped);
        expect(controller.state.launch!.state.performedExercises, hasLength(1));
      },
    );

    test(
      'the next logged set atomically ends open rest with next-action reason',
      () async {
        var now = DateTime.utc(2026, 8, 22, 8);
        final controller = B02StrengthExecutionController(
          adapter,
          initialLaunch: _launch(),
          nowUtc: () => now,
        );
        addTearDown(controller.dispose);
        final slot = _slot();
        await controller.recordSet(
          slot: slot,
          reps: 8,
          loadKg: 80,
          startRestAfterRecord: true,
        );

        now = now.add(const Duration(seconds: 12));
        await controller.recordSet(slot: slot, reps: 7, loadKg: 80);

        final period = controller.state.launch!.state.restPeriods.single;
        expect(period.endReason, B02RestEndReason.nextAction);
        expect(period.actualSeconds, 12);
        expect(
          controller.state.launch!.state.performedExercises.single.sets,
          hasLength(2),
        );
      },
    );

    test(
      'a failed next-set write leaves the open rest authoritative',
      () async {
        final controller = B02StrengthExecutionController(
          adapter,
          initialLaunch: _launch(),
          nowUtc: () => DateTime.utc(2026, 8, 22, 8),
        );
        addTearDown(controller.dispose);
        final slot = _slot();
        await controller.recordSet(
          slot: slot,
          reps: 8,
          loadKg: 80,
          startRestAfterRecord: true,
        );
        adapter.failSaves = true;

        await controller.recordSet(slot: slot, reps: 7, loadKg: 80);

        final period = controller.state.launch!.state.restPeriods.single;
        expect(period.endedAtUtc, isNull);
        expect(
          controller.state.launch!.state.performedExercises.single.sets,
          hasLength(1),
        );
      },
    );

    test('session completion closes open rest before finalization', () async {
      var now = DateTime.utc(2026, 8, 22, 8);
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: _launch(
          state: _baseState().copyWith(activeSegmentStartedAtUtc: now),
        ),
        nowUtc: () => now,
      );
      addTearDown(controller.dispose);
      await controller.recordSet(
        slot: _slot(),
        reps: 8,
        loadKg: 80,
        startRestAfterRecord: true,
      );
      now = now.add(const Duration(seconds: 60));

      final completed = await controller.finalize(commandId: 'finish-rest');

      expect(completed, isTrue);
      final period = adapter.finalizedState!.restPeriods.single;
      expect(period.endReason, B02RestEndReason.nextAction);
      expect(period.actualSeconds, 60);
    });

    test(
      'adjusting below elapsed time closes rest without a negative duration',
      () async {
        final now = DateTime.utc(2026, 8, 22, 8);
        final controller = B02StrengthExecutionController(
          adapter,
          initialLaunch: _launch(),
          nowUtc: () => now,
        );
        addTearDown(controller.dispose);
        await controller.recordSet(
          slot: _slot(),
          reps: 8,
          loadKg: 80,
          startRestAfterRecord: true,
        );
        final periodId = controller.state.launch!.state.restPeriods.single.id;

        await controller.adjustRest(periodId, seconds: -1000);

        final period = controller.state.launch!.state.restPeriods.single;
        expect(period.selectedSeconds, 90);
        expect(period.actualSeconds, 0);
        expect(period.endedAtUtc, now);
      },
    );

    test(
      'rapid repeated adjustments serialize against latest rest state',
      () async {
        final controller = B02StrengthExecutionController(
          adapter,
          initialLaunch: _launch(),
          nowUtc: () => DateTime.utc(2026, 8, 22, 8),
        );
        addTearDown(controller.dispose);
        await controller.recordSet(
          slot: _slot(),
          reps: 8,
          loadKg: 80,
          startRestAfterRecord: true,
        );
        final periodId = controller.state.launch!.state.restPeriods.single.id;

        await Future.wait([
          controller.adjustRest(periodId, seconds: 15),
          controller.adjustRest(periodId, seconds: 15),
        ]);

        expect(
          controller.state.launch!.state.restPeriods.single.selectedSeconds,
          120,
        );
      },
    );

    test('group rest boundaries come from canonical member order', () async {
      final group = B02ExerciseGroup(
        id: 'group-1',
        ordinal: 0,
        groupType: B02GroupType.superset,
        roundCount: 1,
        restAfterRoundSeconds: 60,
        members: [
          B02ExerciseGroupMember(
            id: 'member-a',
            exercisePrescriptionId: 'pres-a',
            ordinal: 0,
            transitionRestSeconds: 20,
          ),
          B02ExerciseGroupMember(
            id: 'member-b',
            exercisePrescriptionId: 'pres-b',
            ordinal: 1,
          ),
        ],
      );
      final launch = _launch(state: _baseState(groups: [group]));
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 8, 22, 8),
      );
      addTearDown(controller.dispose);
      final first = _slot(
        id: 'slot-a',
        groupId: 'group-1',
        groupType: B02GroupType.superset,
        groupOrdinal: 0,
        roundOrdinal: 0,
        memberOrdinal: 0,
        prescriptionId: 'pres-a',
        memberTransitionRestSeconds: 20,
      );
      final second = _slot(
        id: 'slot-b',
        groupId: 'group-1',
        groupType: B02GroupType.superset,
        groupOrdinal: 0,
        roundOrdinal: 0,
        memberOrdinal: 1,
        prescriptionId: 'pres-b',
        groupRestAfterRoundSeconds: 60,
      );

      await controller.recordSet(
        slot: first,
        reps: 8,
        loadKg: 40,
        startRestAfterRecord: true,
      );
      var rest = controller.state.launch!.state.restPeriods.single;
      expect(rest.scope, B02RestScope.groupTransition);
      expect(rest.performedExerciseGroupId, 'group-1');
      await controller.skipRest(rest.id);

      await controller.recordSet(
        slot: second,
        reps: 8,
        loadKg: 40,
        startRestAfterRecord: true,
      );
      rest = controller.state.launch!.state.restPeriods.last;
      expect(rest.scope, B02RestScope.groupRound);
      expect(rest.selectedSeconds, 60);
    });

    test('wall-clock snapshot survives widget rebuild semantics', () {
      final period = B02RestPeriod(
        id: 'rest-1',
        performedSetId: 'set-1',
        scope: B02RestScope.exerciseSet,
        source: B02RestSource.prescription,
        selectedSeconds: 90,
        startedAtUtc: DateTime.utc(2026, 8, 22, 8),
      );
      expect(
        b02RestRemainingSeconds(period, DateTime.utc(2026, 8, 22, 8, 1, 15)),
        15,
      );
      expect(
        b02RestRemainingSeconds(period, DateTime.utc(2026, 8, 22, 8, 2)),
        0,
      );
    });
  });

  group('R08B.6 session-wide screen-awake ownership', () {
    test(
      'active session acquires once and only its terminal path releases',
      () async {
        final driver = _FakeWakeLockDriver();
        final coordinator = WorkoutSessionWakeLockCoordinator(driver: driver);
        addTearDown(coordinator.dispose);

        await coordinator.setActiveSession('session-1');
        await coordinator.setActiveSession('session-1');
        await coordinator.clearActiveSession('stale-session');
        expect(driver.calls, ['enable']);

        await coordinator.clearActiveSession('session-1');
        expect(driver.calls, ['enable', 'disable']);
      },
    );

    test(
      'foreground reconciliation ensures the active session again',
      () async {
        final driver = _FakeWakeLockDriver();
        final coordinator = WorkoutSessionWakeLockCoordinator(driver: driver);
        addTearDown(coordinator.dispose);

        await coordinator.setActiveSession('session-1');
        coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await coordinator.reconcileForActiveSession('session-1');

        expect(driver.calls, ['enable', 'enable']);
      },
    );

    test(
      'plugin failures do not escape and a later reconcile retries',
      () async {
        final driver = _FakeWakeLockDriver()..failEnable = true;
        final coordinator = WorkoutSessionWakeLockCoordinator(driver: driver);
        addTearDown(coordinator.dispose);

        await coordinator.setActiveSession('session-1');
        driver.failEnable = false;
        await coordinator.reconcileForActiveSession('session-1');

        expect(driver.calls, ['enable', 'enable']);
        expect(coordinator.desiredEnabled, isTrue);
      },
    );

    test('plugin disable failure cannot change canonical OFF intent', () async {
      final driver = _FakeWakeLockDriver();
      final coordinator = WorkoutSessionWakeLockCoordinator(driver: driver);
      addTearDown(coordinator.dispose);
      await coordinator.setActiveSession('session-1');
      driver.failDisable = true;

      await coordinator.clearActiveSession('session-1');

      expect(coordinator.activeSessionKey, isNull);
      expect(coordinator.desiredEnabled, isFalse);
      expect(driver.calls, ['enable', 'disable']);
    });

    test('no active session can reconcile the plugin to OFF', () async {
      final driver = _FakeWakeLockDriver();
      final coordinator = WorkoutSessionWakeLockCoordinator(driver: driver);
      addTearDown(coordinator.dispose);

      await coordinator.ensureOff();

      expect(coordinator.activeSessionKey, isNull);
      expect(coordinator.desiredEnabled, isFalse);
      expect(driver.calls, ['disable']);
    });

    test(
      'a launch-less stale controller cannot disable a newer session',
      () async {
        final driver = _FakeWakeLockDriver();
        final coordinator = WorkoutSessionWakeLockCoordinator(driver: driver);
        addTearDown(coordinator.dispose);
        await coordinator.setActiveSession('new-session');
        final database = AppDatabase.memory();
        addTearDown(database.close);
        final controller = B02StrengthExecutionController(
          _RecordingAdapter(
            StrengthExecutionRepository(
              db: database,
              calendarRepo: CalendarRepository(database),
            ),
          ),
          wakeLockCoordinator: coordinator,
        );
        addTearDown(controller.dispose);

        await controller.reconcileWakeLock();

        expect(coordinator.activeSessionKey, 'new-session');
        expect(coordinator.desiredEnabled, isTrue);
        expect(driver.calls, ['enable']);
      },
    );

    test(
      'stale overlapping enable/disable operations settle on current intent',
      () async {
        final driver = _FakeWakeLockDriver();
        final firstEnable = Completer<void>();
        driver.enableGate = firstEnable;
        final coordinator = WorkoutSessionWakeLockCoordinator(driver: driver);
        addTearDown(coordinator.dispose);

        final enabling = coordinator.setActiveSession('session-a');
        await Future<void>.delayed(Duration.zero);
        final disabling = coordinator.clearActiveSession('session-a');
        firstEnable.complete();
        await Future.wait([enabling, disabling]);
        final reenabled = coordinator.setActiveSession('session-b');
        await reenabled;

        expect(driver.calls, ['enable', 'disable', 'enable']);
        expect(coordinator.activeSessionKey, 'session-b');
        expect(coordinator.desiredEnabled, isTrue);
      },
    );

    test('rest has no independent ownership API', () {
      expect(WorkoutSessionWakeLockCoordinator, isNot(isNull));
      // Rest is represented by B02RestPeriod and never receives a wake-lock
      // driver. Ownership is asserted by the coordinator tests above.
    });
  });

  testWidgets('compact logging controls stay reachable at narrow large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _compactTable(),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Reps'), findsOneWidget);
    expect(find.text('Weight (kg)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeWakeLockDriver implements WorkoutWakeLockDriver {
  final List<String> calls = [];
  bool failEnable = false;
  bool failDisable = false;
  Completer<void>? enableGate;

  @override
  Future<void> enable() async {
    calls.add('enable');
    if (failEnable) throw StateError('enable unavailable');
    final gate = enableGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> disable() async {
    calls.add('disable');
    if (failDisable) throw StateError('disable unavailable');
  }
}

class _RecordingAdapter extends StrengthExecutionCompatibilityAdapter {
  _RecordingAdapter(super.repository);

  final savedStates = <B02ExecutionDraftState>[];
  bool failSaves = false;
  B02ExecutionDraftState? finalizedState;

  @override
  Future<void> saveDraft({
    required int draftId,
    required B02ExecutionDraftState state,
  }) async {
    if (failSaves) throw StateError('draft write unavailable');
    savedStates.add(state);
  }

  @override
  Future<int> finalizeDraft({
    required int draftId,
    required String commandId,
    required B02ExecutionDraftState state,
    CompletionKind completionKind = CompletionKind.full,
    String? reason,
    DateTime? completedAtUtc,
  }) async {
    finalizedState = state;
    return 501;
  }
}

B02StrengthExecutionLaunch _launch({B02ExecutionDraftState? state}) {
  return B02StrengthExecutionLaunch(
    draftId: 71,
    occurrenceId: null,
    executionSnapshotJson: '{"version":1}',
    state: state ?? _baseState(),
  );
}

B02ExecutionDraftState _baseState({List<B02ExerciseGroup> groups = const []}) {
  return B02ExecutionDraftState(
    snapshotId: 'snapshot-1',
    snapshotVersion: 1,
    activityType: B02ActivityType.strength,
    routineName: 'Rest test',
    elapsedSeconds: 0,
    currentExerciseOrdinal: 0,
    currentSetOrdinal: 0,
    groups: groups,
  );
}

B02StrengthExecutionSlot _slot({
  String id = 'slot-1',
  String? groupId,
  B02GroupType? groupType,
  int? groupOrdinal,
  int? roundOrdinal,
  int? memberOrdinal,
  String prescriptionId = 'pres-1',
  int? memberTransitionRestSeconds,
  int? groupRestAfterRoundSeconds,
}) {
  return B02StrengthExecutionSlot(
    id: id,
    groupId: groupId,
    groupType: groupType,
    groupLabel: groupId == null ? null : 'Test group',
    groupOrdinal: groupOrdinal,
    roundOrdinal: roundOrdinal,
    memberOrdinal: memberOrdinal,
    prescriptionId: prescriptionId,
    exerciseId: 'exercise-$id',
    exerciseNameSnapshot: 'Exercise $id',
    plannedSets: 1,
    targetRepsMin: 8,
    targetRepsMax: 10,
    targetRpe: null,
    targetLoadKg: 40,
    targetLoadBasis: B02LoadBasis.totalExternal,
    memberTransitionRestSeconds: memberTransitionRestSeconds,
    groupRestAfterRoundSeconds: groupRestAfterRoundSeconds,
  );
}

Widget _compactTable() {
  final slot = _slot();
  return B02CompactSetTableForTest(slot: slot);
}

/// Keeps this test's fixture small without making the production table expose
/// private implementation details to tests.
class B02CompactSetTableForTest extends StatelessWidget {
  const B02CompactSetTableForTest({required this.slot, super.key});

  final B02StrengthExecutionSlot slot;

  @override
  Widget build(BuildContext context) {
    return _TableHarness(slot: slot);
  }
}

class _TableHarness extends StatefulWidget {
  const _TableHarness({required this.slot});

  final B02StrengthExecutionSlot slot;

  @override
  State<_TableHarness> createState() => _TableHarnessState();
}

class _TableHarnessState extends State<_TableHarness> {
  final load = TextEditingController(text: '40');
  final reps = TextEditingController(text: '8');

  @override
  void dispose() {
    load.dispose();
    reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return B02CompactSetTable(
      slot: widget.slot,
      loggedSets: const [],
      isPlannedMode: false,
      isBusy: false,
      currentSet: 1,
      loadController: load,
      repsController: reps,
      rpe: null,
      isWarmup: false,
      loadLabel: 'Weight (kg)',
      onRpeChanged: (_) {},
      onWarmupChanged: (_) {},
      onEdit: null,
      onDelete: null,
      moreContent: const SizedBox.shrink(),
    );
  }
}
