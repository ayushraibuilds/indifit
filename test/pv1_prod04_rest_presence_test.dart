import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/rest_presence_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestRestPresenceDriver implements RestPresenceDriver {
  final List<Map<String, dynamic>> ongoingCalls = [];
  final List<Map<String, dynamic>> expiredCalls = [];
  final List<int> cancelledIds = [];
  final List<Map<String, dynamic>> scheduledExactCalls = [];
  bool canScheduleExactResult = false;
  int hapticCalls = 0;

  @override
  Future<bool> scheduleExactExpiryAlarm({
    required int id,
    required DateTime expiryUtc,
    required String exerciseName,
    required String channelId,
    required String channelName,
  }) async {
    if (!canScheduleExactResult) return false;
    scheduledExactCalls.add({
      'id': id,
      'expiryUtc': expiryUtc,
      'exerciseName': exerciseName,
      'channelId': channelId,
      'channelName': channelName,
    });
    return true;
  }

  @override
  Future<void> showOngoingRestNotification({
    required int id,
    required String exerciseName,
    required int remainingSeconds,
    required int totalSeconds,
    required String channelId,
    required String channelName,
    DateTime? expiryUtc,
  }) async {
    ongoingCalls.add({
      'id': id,
      'exerciseName': exerciseName,
      'remainingSeconds': remainingSeconds,
      'totalSeconds': totalSeconds,
      'channelId': channelId,
      'expiryUtc': expiryUtc?.toIso8601String(),
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
      SharedPreferences.setMockInitialValues({});
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
      // Chronometer expiry rides along for the native countdown.
      expect(
        call['expiryUtc'],
        currentTime.add(const Duration(seconds: 90)).toIso8601String(),
      );
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
      SharedPreferences.setMockInitialValues({});
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

  group('PV1-PROD-04 Stage 1b: Exact alarm anchor, single-writer rule & headless persistence', () {
    late TestRestPresenceDriver driver;
    late DateTime currentTime;
    late RestPresenceService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
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

    test('RestAnchorRecord roundtrips to and from json', () {
      final record = RestAnchorRecord(
        periodId: 'p-1',
        exerciseName: 'Bench Press',
        startedAtUtc: currentTime,
        baseTargetSeconds: 90,
        accumulatedExtraSeconds: 30,
        hasExactAlarmAnchor: true,
      );

      final json = record.toJson();
      final restored = RestAnchorRecord.fromJson(json);

      expect(restored.periodId, 'p-1');
      expect(restored.exerciseName, 'Bench Press');
      expect(restored.startedAtUtc, currentTime);
      expect(restored.baseTargetSeconds, 90);
      expect(restored.accumulatedExtraSeconds, 30);
      expect(restored.totalTargetSeconds, 120);
      expect(restored.expiryUtc, currentTime.add(const Duration(seconds: 120)));
      expect(restored.hasExactAlarmAnchor, true);
    });

    test('startRest schedules exact alarm when capability is granted and persists anchor', () async {
      driver.canScheduleExactResult = true;

      await service.startRest(
        periodId: 'p-exact',
        exerciseName: 'Deadlift',
        targetSeconds: 120,
        startedAtUtc: currentTime,
      );

      expect(service.hasExactAlarmAnchor, true);
      expect(driver.scheduledExactCalls, hasLength(1));
      final call = driver.scheduledExactCalls.first;
      expect(call['id'], RestPresenceService.expiredNotificationId);
      expect(call['exerciseName'], 'Deadlift');
      expect(call['channelId'], RestPresenceService.channelId);
      expect(call['expiryUtc'], currentTime.add(const Duration(seconds: 120)));

      // Verify anchor record persisted in prefs
      final anchor = await RestPresenceService.loadAnchorRecord();
      expect(anchor, isNotNull);
      expect(anchor!.periodId, 'p-exact');
      expect(anchor.hasExactAlarmAnchor, true);
    });

    test('single-writer rule: onRestElapsed suppresses Dart alert when exact alarm was scheduled', () async {
      driver.canScheduleExactResult = true;

      await service.startRest(
        periodId: 'p-exact-2',
        exerciseName: 'Squat',
        targetSeconds: 90,
        startedAtUtc: currentTime,
      );

      await service.onRestElapsed(periodId: 'p-exact-2');

      expect(service.state, RestPresenceState.expired);
      // Verify ongoing was cancelled
      expect(driver.cancelledIds, contains(RestPresenceService.ongoingNotificationId));
      // Single-writer: Dart alert suppressed because exact alarm owns the alert!
      expect(driver.expiredCalls, isEmpty);
      // Haptics still triggered
      expect(driver.hapticCalls, 1);
      // Anchor record cleared
      expect(await RestPresenceService.loadAnchorRecord(), isNull);
    });

    test('single-writer rule: onRestElapsed posts fallback 999 when exact alarm was NOT scheduled', () async {
      driver.canScheduleExactResult = false;

      await service.startRest(
        periodId: 'p-fallback',
        exerciseName: 'Overhead Press',
        targetSeconds: 60,
        startedAtUtc: currentTime,
      );

      expect(service.hasExactAlarmAnchor, false);
      expect(driver.scheduledExactCalls, isEmpty);

      await service.onRestElapsed(periodId: 'p-fallback');

      expect(service.state, RestPresenceState.expired);
      // Fallback: Dart posts notification 999
      expect(driver.expiredCalls, hasLength(1));
      expect(driver.expiredCalls.first['id'], RestPresenceService.expiredNotificationId);
      expect(driver.hapticCalls, 1);
    });

    test('anchor invariant: (re)scheduled on start/adjust and cancelled on cancel/cleanup', () async {
      driver.canScheduleExactResult = true;

      await service.startRest(
        periodId: 'p-inv',
        exerciseName: 'Pull-up',
        targetSeconds: 60,
        startedAtUtc: currentTime,
      );
      expect(driver.scheduledExactCalls, hasLength(1));

      // Re-schedule when target duration adjusted
      await service.startRest(
        periodId: 'p-inv',
        exerciseName: 'Pull-up',
        targetSeconds: 90,
        startedAtUtc: currentTime,
        accumulatedExtraSeconds: 30,
      );
      expect(driver.scheduledExactCalls, hasLength(2));
      expect(driver.scheduledExactCalls.last['expiryUtc'], currentTime.add(const Duration(seconds: 90)));

      // Cancel cancels both ongoing and exact alarm ID 999
      await service.cancelRest(periodId: 'p-inv');
      expect(driver.cancelledIds, contains(RestPresenceService.ongoingNotificationId));
      expect(driver.cancelledIds, contains(RestPresenceService.expiredNotificationId));
      expect(await RestPresenceService.loadAnchorRecord(), isNull);
    });

    test('handleAction rest_add_30s with registered callback invokes delegate', () async {
      String? adjustedPeriod;
      int? adjustedDelta;
      service.registerActionDelegate(
        onAdjust: (p, delta) {
          adjustedPeriod = p;
          adjustedDelta = delta;
        },
        onSkip: (_) {},
      );

      await service.startRest(
        periodId: 'p-action',
        exerciseName: 'Dip',
        targetSeconds: 60,
        startedAtUtc: currentTime,
      );

      await service.handleAction('rest_add_30s');

      expect(adjustedPeriod, 'p-action');
      expect(adjustedDelta, 30);
    });

    test('handleAction rest_skip with registered callback invokes delegate', () async {
      String? skippedPeriod;
      service.registerActionDelegate(
        onAdjust: (p, s) {},
        onSkip: (p) => skippedPeriod = p,
      );

      await service.startRest(
        periodId: 'p-skip',
        exerciseName: 'Dip',
        targetSeconds: 60,
        startedAtUtc: currentTime,
      );

      await service.handleAction('rest_skip');

      expect(skippedPeriod, 'p-skip');
    });

    test('handleAction with no registered callback writes pending intent without touching mirror', () async {
      // No callback registered
      await service.startRest(
        periodId: 'p-no-callback',
        exerciseName: 'Row',
        targetSeconds: 60,
        startedAtUtc: currentTime,
      );

      await service.handleAction('rest_add_30s');

      // Mirror targetDurationSeconds is unchanged in-memory (anti-slop rule)
      expect(service.targetDurationSeconds, 60);

      // Pending intent written to prefs
      final intent = await RestPresenceService.loadAndClearPendingIntent();
      expect(intent, isNotNull);
      expect(intent!.action, 'adjust_30s');
      expect(intent.periodId, 'p-no-callback');
      expect(intent.accumulatedExtraSeconds, 30);
    });

    test('handleBackgroundAction rest_add_30s performs read-modify-write on accumulated delta', () async {
      // Mock platform channel for flutter_local_notifications calls
      final platformCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              platformCalls.add(call);
              return true;
            },
          );

      // Save initial anchor record
      final initialAnchor = RestAnchorRecord(
        periodId: 'p-bg',
        exerciseName: 'Squat',
        startedAtUtc: DateTime.now().toUtc(),
        baseTargetSeconds: 60,
        accumulatedExtraSeconds: 0,
        hasExactAlarmAnchor: true,
      );
      await RestPresenceService.saveAnchorRecord(initialAnchor);

      // Simulate background action tap
      const response = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
        actionId: 'rest_add_30s',
      );

      await RestPresenceService.handleBackgroundAction(response);

      // Verify updated anchor has accumulatedExtraSeconds = 30
      final updatedAnchor = await RestPresenceService.loadAnchorRecord();
      expect(updatedAnchor, isNotNull);
      expect(updatedAnchor!.accumulatedExtraSeconds, 30);
      expect(updatedAnchor.totalTargetSeconds, 90);

      // Verify pending intent was written
      final intent = await RestPresenceService.loadAndClearPendingIntent();
      expect(intent, isNotNull);
      expect(intent!.action, 'adjust_30s');
      expect(intent.accumulatedExtraSeconds, 30);

      // Verify second background tap increments delta to 60 (read-modify-write)
      await RestPresenceService.handleBackgroundAction(response);
      final secondAnchor = await RestPresenceService.loadAnchorRecord();
      expect(secondAnchor!.accumulatedExtraSeconds, 60);
      expect(secondAnchor.totalTargetSeconds, 120);
    });

    test('handleBackgroundAction rest_skip clears anchor, cancels notifications, and writes intent', () async {
      final platformCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              platformCalls.add(call);
              return true;
            },
          );

      final initialAnchor = RestAnchorRecord(
        periodId: 'p-skip-bg',
        exerciseName: 'Bench',
        startedAtUtc: DateTime.now().toUtc(),
        baseTargetSeconds: 60,
        accumulatedExtraSeconds: 0,
      );
      await RestPresenceService.saveAnchorRecord(initialAnchor);

      const response = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
        actionId: 'rest_skip',
      );

      await RestPresenceService.handleBackgroundAction(response);

      // Anchor cleared
      expect(await RestPresenceService.loadAnchorRecord(), isNull);

      // Pending intent written
      final intent = await RestPresenceService.loadAndClearPendingIntent();
      expect(intent, isNotNull);
      expect(intent!.action, 'skip');
      expect(intent.periodId, 'p-skip-bg');

      // Verified 998 and 999 cancellation called
      final cancelled = platformCalls
          .where((c) => c.method == 'cancel')
          .map((c) => (c.arguments as Map)['id'] as int)
          .toSet();
      expect(cancelled, contains(RestPresenceService.ongoingNotificationId));
      expect(cancelled, contains(RestPresenceService.expiredNotificationId));
    });
  });

  group('PV1-PROD-04 Stage 2: Controller wiring, resume reconciliation & silent restart', () {
    late AppDatabase database;
    late StrengthExecutionRepository repo;
    late _RecordingAdapter adapter;
    late TestRestPresenceDriver driver;
    late RestPresenceService presenceService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
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

    test('action tap rest_add_30s routes to controller and adjusts draft in SQLite', () async {
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

      // Simulate tapping +30s action
      await presenceService.handleAction('rest_add_30s');

      // Verify draft state in controller has updated duration
      final period = controller.state.launch!.state.restPeriods.single;
      expect(period.selectedSeconds, 120);
    });

    test('action tap rest_skip routes to controller and marks rest skipped in draft', () async {
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

      // Simulate tapping Skip action
      await presenceService.handleAction('rest_skip');

      expect(presenceService.isActive, false);
      final period = controller.state.launch!.state.restPeriods.single;
      expect(period.endedAtUtc, isNotNull);
      expect(period.endReason, B02RestEndReason.skipped);
    });

    test('controller dispose unregisters action delegate preventing stale callback invocation', () async {
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

      controller.dispose();

      // Tap action after dispose
      await presenceService.handleAction('rest_add_30s');

      // Does not throw and does not invoke disposed controller
      expect(presenceService.onAdjustRestRequested, isNull);
      expect(presenceService.onSkipRestRequested, isNull);
    });

    test('reconcilePendingRestIntent applies pending adjust_30s intent to active draft', () async {
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

      // Simulate a pending intent recorded while in background
      await RestPresenceService.savePendingIntent(
        RestPresenceIntent(
          action: 'adjust_30s',
          periodId: periodId,
          accumulatedExtraSeconds: 30,
          timestampUtc: DateTime.utc(2026, 9, 5, 10, 0, 10),
        ),
      );

      await controller.reconcilePendingRestIntent();

      // Draft updated to 90 + 30 = 120s
      final period = controller.state.launch!.state.restPeriods.single;
      expect(period.selectedSeconds, 120);

      // Pending intent consumed
      expect(await RestPresenceService.loadAndClearPendingIntent(), isNull);
    });

    test('restart-after-anchor suppresses Dart alert while completing draft state silently', () async {
      var clockTime = DateTime.utc(2026, 9, 5, 10, 0);
      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => clockTime,
        restPresence: presenceService,
      );
      addTearDown(controller.dispose);

      final slot = _createSlot(exerciseName: 'Bench Press', prescribedRest: 60);
      await controller.recordSet(
        slot: slot,
        reps: 8,
        loadKg: 80,
        startRestAfterRecord: true,
      );

      final periodId = controller.state.launch!.state.restPeriods.single.id;

      // Simulate that anchor was scheduled and hasExactAlarmAnchor == true in prefs
      await RestPresenceService.saveAnchorRecord(
        RestAnchorRecord(
          periodId: periodId,
          exerciseName: 'Bench Press',
          startedAtUtc: clockTime,
          baseTargetSeconds: 60,
          accumulatedExtraSeconds: 0,
          hasExactAlarmAnchor: true,
        ),
      );

      // Advance clock past duration (rest expired while process was backgrounded/sleeping)
      clockTime = clockTime.add(const Duration(seconds: 70));

      // Reconcile on resume
      await controller.reconcilePendingRestIntent();

      // Draft completed as elapsed
      final period = controller.state.launch!.state.restPeriods.single;
      expect(period.endedAtUtc, isNotNull);
      expect(period.endReason, B02RestEndReason.elapsed);

      // Single-writer check: Dart alert was SUPPRESSED because exact alarm anchor fired it!
      expect(driver.expiredCalls, isEmpty);
    });
  });

  group('PV1-PROD-04 Stage 3: Full-system regression & edge-case acceptance', () {
    late AppDatabase database;
    late StrengthExecutionRepository repo;
    late _RecordingAdapter adapter;
    late TestRestPresenceDriver driver;
    late RestPresenceService presenceService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
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

    test('pending skip intent received in background reconciles on resume and marks draft rest skipped', () async {
      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 9, 5, 10, 0),
        restPresence: presenceService,
      );
      addTearDown(controller.dispose);

      final slot = _createSlot(exerciseName: 'Overhead Press', prescribedRest: 90);
      await controller.recordSet(
        slot: slot,
        reps: 6,
        loadKg: 50,
        startRestAfterRecord: true,
      );

      final periodId = controller.state.launch!.state.restPeriods.single.id;

      // Simulate headless isolate writing skip intent
      await RestPresenceService.savePendingIntent(
        RestPresenceIntent(
          action: 'skip',
          periodId: periodId,
          timestampUtc: DateTime.utc(2026, 9, 5, 10, 0, 15),
        ),
      );

      await controller.reconcilePendingRestIntent();

      final period = controller.state.launch!.state.restPeriods.single;
      expect(period.endedAtUtc, isNotNull);
      expect(period.endReason, B02RestEndReason.skipped);
      expect(await RestPresenceService.loadAndClearPendingIntent(), isNull);
    });

    test('multiple background +30s taps accumulate delta and reconcile cleanly into draft on resume', () async {
      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 9, 5, 10, 0),
        restPresence: presenceService,
      );
      addTearDown(controller.dispose);

      final slot = _createSlot(exerciseName: 'Deadlift', prescribedRest: 120);
      await controller.recordSet(
        slot: slot,
        reps: 5,
        loadKg: 140,
        startRestAfterRecord: true,
      );

      final periodId = controller.state.launch!.state.restPeriods.single.id;

      // Simulate 3 headless +30s taps (+90s total)
      await RestPresenceService.savePendingIntent(
        RestPresenceIntent(
          action: 'adjust_30s',
          periodId: periodId,
          accumulatedExtraSeconds: 90,
          timestampUtc: DateTime.utc(2026, 9, 5, 10, 0, 20),
        ),
      );

      await controller.reconcilePendingRestIntent();

      final period = controller.state.launch!.state.restPeriods.single;
      expect(period.selectedSeconds, 210); // 120 + 90 = 210s
      expect(await RestPresenceService.loadAndClearPendingIntent(), isNull);
    });

    test('fallback path: rest elapsing in background without exact alarm triggers fallback 999 upon resume reconciliation', () async {
      var clockTime = DateTime.utc(2026, 9, 5, 10, 0);
      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => clockTime,
        restPresence: presenceService,
      );
      addTearDown(controller.dispose);

      final slot = _createSlot(exerciseName: 'Barbell Row', prescribedRest: 60);
      await controller.recordSet(
        slot: slot,
        reps: 10,
        loadKg: 70,
        startRestAfterRecord: true,
      );

      final periodId = controller.state.launch!.state.restPeriods.single.id;

      // Simulate fallback anchor where exact alarm could not be scheduled
      await RestPresenceService.saveAnchorRecord(
        RestAnchorRecord(
          periodId: periodId,
          exerciseName: 'Barbell Row',
          startedAtUtc: clockTime,
          baseTargetSeconds: 60,
          accumulatedExtraSeconds: 0,
          hasExactAlarmAnchor: false,
        ),
      );

      // Advance clock past duration
      clockTime = clockTime.add(const Duration(seconds: 65));

      await controller.reconcilePendingRestIntent();

      final period = controller.state.launch!.state.restPeriods.single;
      expect(period.endedAtUtc, isNotNull);
      expect(period.endReason, B02RestEndReason.elapsed);

      // Single-writer fallback rule: because exact alarm anchor was false, Dart posts 999!
      expect(driver.expiredCalls, hasLength(1));
      expect(driver.expiredCalls.single['id'], RestPresenceService.expiredNotificationId);
    });

    test('reconcilePendingRestIntent is a safe no-op when no rest period is active', () async {
      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 9, 5, 10, 0),
        restPresence: presenceService,
      );
      addTearDown(controller.dispose);

      // No rest period started
      await controller.reconcilePendingRestIntent();

      expect(controller.state.launch!.state.restPeriods, isEmpty);
    });

    test('reconcilePendingRestIntent handles corrupted preferences gracefully without throwing', () async {
      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 9, 5, 10, 0),
        restPresence: presenceService,
      );
      addTearDown(controller.dispose);

      final slot = _createSlot(exerciseName: 'Bench Press', prescribedRest: 60);
      await controller.recordSet(
        slot: slot,
        reps: 8,
        loadKg: 80,
        startRestAfterRecord: true,
      );

      // Corrupt the pending intent pref key with non-JSON content
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_rest_intent', '{malformed_json_not_valid');

      // Reconcile must not throw and fail closed
      await expectLater(controller.reconcilePendingRestIntent(), completes);
    });

    test('adjustRest below elapsed cancels scheduled 999 anchor and alerts immediately via Dart', () async {
      var clockTime = DateTime.utc(2026, 9, 5, 10, 0);
      driver.canScheduleExactResult = true;

      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => clockTime,
        restPresence: presenceService,
      );
      addTearDown(controller.dispose);

      final slot = _createSlot(exerciseName: 'Bench Press', prescribedRest: 120);
      await controller.recordSet(
        slot: slot,
        reps: 8,
        loadKg: 80,
        startRestAfterRecord: true,
      );

      final periodId = controller.state.launch!.state.restPeriods.single.id;
      expect(presenceService.isActive, true);
      expect(presenceService.hasExactAlarmAnchor, true);

      // Advance clock 40 seconds
      clockTime = clockTime.add(const Duration(seconds: 40));

      // Decrement rest by 90 seconds (120 - 90 = 30s <= 40s elapsed -> willElapse == true)
      await controller.adjustRest(periodId, seconds: -90);

      // Verify the old 999 anchor scheduled for original +120s was cancelled
      expect(driver.cancelledIds, contains(RestPresenceService.expiredNotificationId));

      // Verify Dart alerted immediately (silentCompletion: false)
      expect(driver.expiredCalls, hasLength(1));
      expect(driver.expiredCalls.single['id'], RestPresenceService.expiredNotificationId);
      expect(driver.hapticCalls, greaterThanOrEqualTo(1));
    });

    test('reconcilePendingRestIntent discards intent when periodId does not match active rest period', () async {
      final launch = _createLaunch();
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: launch,
        nowUtc: () => DateTime.utc(2026, 9, 5, 10, 0),
        restPresence: presenceService,
      );
      addTearDown(controller.dispose);

      final slot = _createSlot(exerciseName: 'Squat', prescribedRest: 90);
      await controller.recordSet(
        slot: slot,
        reps: 5,
        loadKg: 100,
        startRestAfterRecord: true,
      );

      final activePeriod = controller.state.launch!.state.restPeriods.single;

      // Save orphaned intent from an unrelated past workout / different period
      await RestPresenceService.savePendingIntent(
        RestPresenceIntent(
          action: 'skip',
          periodId: 'stale-period-from-yesterday',
          timestampUtc: DateTime.utc(2026, 9, 4, 10, 0),
        ),
      );

      await controller.reconcilePendingRestIntent();

      // Active period must be completely untouched (not skipped!)
      final periodAfter = controller.state.launch!.state.restPeriods.single;
      expect(periodAfter.id, activePeriod.id);
      expect(periodAfter.endedAtUtc, isNull);
      expect(periodAfter.selectedSeconds, 90);

      // Orphaned intent consumed and cleared
      expect(await RestPresenceService.loadAndClearPendingIntent(), isNull);
    });

    test('cancelRest and cleanup clear pending intent from SharedPreferences', () async {
      await presenceService.startRest(
        periodId: 'p-clear-test',
        exerciseName: 'Dips',
        targetSeconds: 60,
      );

      await RestPresenceService.savePendingIntent(
        RestPresenceIntent(
          action: 'adjust_30s',
          periodId: 'p-clear-test',
          accumulatedExtraSeconds: 30,
          timestampUtc: DateTime.now().toUtc(),
        ),
      );

      // cancelRest clears pending intent
      await presenceService.cancelRest();
      expect(await RestPresenceService.loadAndClearPendingIntent(), isNull);

      // cleanup also clears pending intent
      await RestPresenceService.savePendingIntent(
        RestPresenceIntent(
          action: 'adjust_30s',
          periodId: 'p-clear-test-2',
          accumulatedExtraSeconds: 30,
          timestampUtc: DateTime.now().toUtc(),
        ),
      );
      await presenceService.cleanup();
      expect(await RestPresenceService.loadAndClearPendingIntent(), isNull);
    });

    test('handleBackgroundAction updates hasExactAlarmAnchor from reschedule capability return', () async {
      final platformCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async {
              platformCalls.add(call);
              // canScheduleExactNotifications returns false (e.g. revoked in system settings)
              if (call.method == 'canScheduleExactNotifications') {
                return false;
              }
              return true;
            },
          );

      // Initial anchor had exact alarm
      final initialAnchor = RestAnchorRecord(
        periodId: 'p-revoked',
        exerciseName: 'Bench',
        startedAtUtc: DateTime.now().toUtc(),
        baseTargetSeconds: 60,
        accumulatedExtraSeconds: 0,
        hasExactAlarmAnchor: true,
      );
      await RestPresenceService.saveAnchorRecord(initialAnchor);

      const response = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
        actionId: 'rest_add_30s',
      );

      await RestPresenceService.handleBackgroundAction(response);

      // Rescheduled anchor persisted hasExactAlarmAnchor = false
      final updatedAnchor = await RestPresenceService.loadAnchorRecord();
      expect(updatedAnchor, isNotNull);
      expect(updatedAnchor!.hasExactAlarmAnchor, false);
    });
  });
}
