import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/rest_presence_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';

class TestRestPresenceDriver implements RestPresenceDriver {
  final List<Map<String, dynamic>> ongoingCalls = [];
  final List<Map<String, dynamic>> expiredCalls = [];
  final List<int> cancelledIds = [];
  int hapticCalls = 0;

  @override
  Future<void> showOngoingRestNotification({
    required int id,
    required String exerciseName,
    required int remainingSeconds,
    required int totalSeconds,
    required String channelId,
    required String channelName,
  }) async {
    ongoingCalls.add({
      'id': id,
      'exerciseName': exerciseName,
      'remainingSeconds': remainingSeconds,
      'totalSeconds': totalSeconds,
      'channelId': channelId,
    });
  }

  @override
  Future<void> showRestExpiredNotification({
    required int id,
    required String exerciseName,
    required String channelId,
    required String channelName,
  }) async {
    expiredCalls.add({
      'id': id,
      'exerciseName': exerciseName,
      'channelId': channelId,
    });
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> triggerHapticFeedback() async {
    hapticCalls++;
  }
}

class _RecordingAdapter extends StrengthExecutionCompatibilityAdapter {
  _RecordingAdapter(super.repository);

  final savedStates = <B02ExecutionDraftState>[];

  @override
  Future<void> saveDraft({
    required int draftId,
    required B02ExecutionDraftState state,
  }) async {
    savedStates.add(state);
  }
}

B02StrengthExecutionSlot _createSlot({
  String id = 'slot-1',
  String exerciseName = 'Bench Press',
  int prescribedRest = 90,
}) {
  return B02StrengthExecutionSlot(
    id: id,
    groupId: null,
    groupType: null,
    groupLabel: null,
    groupOrdinal: null,
    roundOrdinal: null,
    memberOrdinal: null,
    prescriptionId: 'pres-$id',
    exerciseId: 'exercise-$id',
    exerciseNameSnapshot: exerciseName,
    plannedSets: 3,
    targetRepsMin: 8,
    targetRepsMax: 10,
    targetRpe: null,
    targetLoadKg: 40,
    targetLoadBasis: B02LoadBasis.totalExternal,
    prescribedRestSeconds: prescribedRest,
  );
}

B02StrengthExecutionLaunch _createLaunch() {
  return B02StrengthExecutionLaunch(
    draftId: 1,
    occurrenceId: null,
    executionSnapshotJson: '{}',
    state: B02ExecutionDraftState(
      snapshotId: 'snap-1',
      snapshotVersion: 1,
      activityType: B02ActivityType.strength,
      routineName: 'Test Routine',
      elapsedSeconds: 0,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PV1-PROD-04: RestPresenceService lifecycle & state machine', () {
    late TestRestPresenceDriver driver;
    late DateTime currentTime;
    late RestPresenceService service;

    setUp(() {
      driver = TestRestPresenceDriver();
      currentTime = DateTime.utc(2026, 9, 5, 10, 0, 0);
      service = RestPresenceService(
        driver: driver,
        nowUtc: () => currentTime,
      );
    });

    tearDown(() async {
      await service.cleanup();
    });

    test('initial state is idle and has no active rest period', () {
      expect(service.state, RestPresenceState.idle);
      expect(service.isActive, false);
      expect(service.currentPeriodId, isNull);
      expect(service.remainingSeconds, 0);
    });

    test('startRest transitions to active and posts ongoing notification', () async {
      await service.startRest(
        periodId: 'rest-1',
        exerciseName: 'Bench Press',
        targetSeconds: 90,
        startedAtUtc: currentTime,
      );

      expect(service.state, RestPresenceState.active);
      expect(service.isActive, true);
      expect(service.currentPeriodId, 'rest-1');
      expect(service.currentExerciseName, 'Bench Press');
      expect(service.targetDurationSeconds, 90);
      expect(service.remainingSeconds, 90);

      expect(driver.ongoingCalls, hasLength(1));
      final call = driver.ongoingCalls.first;
      expect(call['id'], RestPresenceService.ongoingNotificationId);
      expect(call['exerciseName'], 'Bench Press');
      expect(call['remainingSeconds'], 90);
      expect(call['totalSeconds'], 90);
      expect(call['channelId'], RestPresenceService.channelId);
    });

    test('remainingSeconds accurately reflects wall-clock elapsed time', () async {
      await service.startRest(
        periodId: 'rest-2',
        exerciseName: 'Squat',
        targetSeconds: 120,
        startedAtUtc: currentTime,
      );

      expect(service.remainingSeconds, 120);

      // Advance clock by 45 seconds
      currentTime = currentTime.add(const Duration(seconds: 45));
      expect(service.remainingSeconds, 75);

      // Advance clock past target
      currentTime = currentTime.add(const Duration(seconds: 80));
      expect(service.remainingSeconds, 0);
    });

    test('onRestElapsed cancels ongoing, fires expired alert, and triggers haptics', () async {
      await service.startRest(
        periodId: 'rest-3',
        exerciseName: 'Overhead Press',
        targetSeconds: 60,
        startedAtUtc: currentTime,
      );

      await service.onRestElapsed(periodId: 'rest-3');

      expect(service.state, RestPresenceState.expired);
      expect(service.isActive, false);

      // Verify ongoing notification 998 was cancelled
      expect(driver.cancelledIds, contains(RestPresenceService.ongoingNotificationId));

      // Verify expired notification 999 was shown
      expect(driver.expiredCalls, hasLength(1));
      final expiredCall = driver.expiredCalls.first;
      expect(expiredCall['id'], RestPresenceService.expiredNotificationId);
      expect(expiredCall['exerciseName'], 'Overhead Press');
      expect(expiredCall['channelId'], RestPresenceService.channelId);

      // Verify haptic feedback triggered
      expect(driver.hapticCalls, 1);
    });

    test('cancelRest cancels ongoing notification and clears state', () async {
      await service.startRest(
        periodId: 'rest-4',
        exerciseName: 'Barbell Row',
        targetSeconds: 90,
        startedAtUtc: currentTime,
      );

      await service.cancelRest(periodId: 'rest-4');

      expect(service.state, RestPresenceState.cancelled);
      expect(service.isActive, false);
      expect(service.currentPeriodId, isNull);
      expect(driver.cancelledIds, contains(RestPresenceService.ongoingNotificationId));
    });

    test('cleanup resets all state and cancels ongoing and expired notifications', () async {
      await service.startRest(
        periodId: 'rest-5',
        exerciseName: 'Pull-up',
        targetSeconds: 60,
        startedAtUtc: currentTime,
      );

      await service.cleanup();

      expect(service.state, RestPresenceState.idle);
      expect(service.isActive, false);
      expect(service.currentPeriodId, isNull);
      expect(driver.cancelledIds, contains(RestPresenceService.ongoingNotificationId));
      expect(driver.cancelledIds, contains(RestPresenceService.expiredNotificationId));
    });

    test('cleanupStaleNotifications cancels ongoing notification', () async {
      await RestPresenceService.cleanupStaleNotifications(driver);
      expect(driver.cancelledIds, contains(RestPresenceService.ongoingNotificationId));
    });
  });

  group('PV1-PROD-04: Controller rest-presence integration', () {
    late AppDatabase database;
    late StrengthExecutionRepository repo;
    late _RecordingAdapter adapter;
    late TestRestPresenceDriver driver;
    late RestPresenceService presenceService;

    setUp(() {
      database = AppDatabase.memory();
      repo = StrengthExecutionRepository(
        db: database,
        calendarRepo: CalendarRepository(database),
      );
      adapter = _RecordingAdapter(repo);
      driver = TestRestPresenceDriver();
      presenceService = RestPresenceService(
        driver: driver,
        nowUtc: () => DateTime.utc(2026, 9, 5, 10, 0),
      );
    });

    tearDown(() async {
      await presenceService.cleanup();
      await database.close();
    });

    test('recording a set with startRestAfterRecord starts rest presence', () async {
      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 9, 5, 10, 0),
        restPresence: presenceService,
      );
      addTearDown(controller.dispose);

      final slot = _createSlot(exerciseName: 'Bench Press', prescribedRest: 90);

      await controller.recordSet(
        slot: slot,
        reps: 8,
        loadKg: 80,
        startRestAfterRecord: true,
      );

      expect(presenceService.isActive, true);
      expect(presenceService.currentExerciseName, 'Bench Press');
      expect(driver.ongoingCalls, isNotEmpty);
      expect(driver.ongoingCalls.last['id'], RestPresenceService.ongoingNotificationId);
    });

    test('skipRest cancels active rest presence', () async {
      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 9, 5, 10, 0),
        restPresence: presenceService,
      );
      addTearDown(controller.dispose);

      final slot = _createSlot(exerciseName: 'Bench Press', prescribedRest: 90);

      await controller.recordSet(
        slot: slot,
        reps: 8,
        loadKg: 80,
        startRestAfterRecord: true,
      );
      expect(presenceService.isActive, true);

      final periodId = controller.state.launch!.state.restPeriods.single.id;
      await controller.skipRest(periodId);

      expect(presenceService.isActive, false);
      expect(driver.cancelledIds, contains(RestPresenceService.ongoingNotificationId));
    });

    test('completeRest completes rest presence with expiry alert and haptics', () async {
      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 9, 5, 10, 0),
        restPresence: presenceService,
      );
      addTearDown(controller.dispose);

      final slot = _createSlot(exerciseName: 'Bench Press', prescribedRest: 90);

      await controller.recordSet(
        slot: slot,
        reps: 8,
        loadKg: 80,
        startRestAfterRecord: true,
      );
      final periodId = controller.state.launch!.state.restPeriods.single.id;

      await controller.completeRest(periodId);

      expect(presenceService.state, RestPresenceState.expired);
      expect(driver.expiredCalls, isNotEmpty);
      expect(driver.hapticCalls, 1);
    });

    test('controller dispose triggers rest presence cleanup', () async {
      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 9, 5, 10, 0),
        restPresence: presenceService,
      );

      final slot = _createSlot(exerciseName: 'Bench Press', prescribedRest: 90);

      await controller.recordSet(
        slot: slot,
        reps: 8,
        loadKg: 80,
        startRestAfterRecord: true,
      );
      expect(presenceService.isActive, true);

      controller.dispose();

      expect(presenceService.state, RestPresenceState.idle);
      expect(driver.cancelledIds, contains(RestPresenceService.ongoingNotificationId));
    });
  });
}
