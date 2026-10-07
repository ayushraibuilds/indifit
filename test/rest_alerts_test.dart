import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/rest_alert_permission_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PR-D: the one-time rest alert permission ask (audit R-02).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R-02 rest alert permission ask', () {
    late AppDatabase database;
    late StrengthExecutionCompatibilityAdapter adapter;
    late int requests;
    late int settingsOpened;
    late List<RestAlertPrompt> prompts;
    bool? canExact;

    RestAlertPermissionService newService() {
      final service = RestAlertPermissionService(
        requestNotifications: () async {
          requests++;
          return true;
        },
        notificationsGranted: () async => false,
        canScheduleExactAlarms: () async => canExact,
        openExactAlarmSettings: () async => settingsOpened++,
      );
      service.registerPresenter((prompt) async {
        prompts.add(prompt);
        return true;
      });
      return service;
    }

    Future<void> restOnce(
      RestAlertPermissionService service, {
      int draftId = 1,
    }) async {
      final controller = B02StrengthExecutionController(
        adapter,
        initialLaunch: _launch(draftId),
        nowUtc: () => DateTime.utc(2026, 10, 7, 10),
        restAlerts: service,
      );
      addTearDown(controller.dispose);
      await controller.recordSet(
        slot: _slot(),
        reps: 8,
        loadKg: 40,
        startRestAfterRecord: true,
      );
      expect(controller.state.launch!.state.restPeriods, isNotEmpty);
      // The ask runs outside the rest queue; let it finish.
      await pumpEventQueue();
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      database = AppDatabase.memory();
      adapter = _MemoryAdapter(
        StrengthExecutionRepository(
          db: database,
          calendarRepo: CalendarRepository(database),
        ),
      );
      requests = 0;
      settingsOpened = 0;
      prompts = [];
      canExact = null;
    });

    tearDown(() => database.close());

    test(
      'asks exactly once: first rest only, not later rests or workouts',
      () async {
        final service = newService();

        await restOnce(service);
        expect(requests, 1);
        expect(prompts, [RestAlertPrompt.notifications]);

        // A later rest in the same workout.
        final controller = B02StrengthExecutionController(
          adapter,
          initialLaunch: _launch(1),
          nowUtc: () => DateTime.utc(2026, 10, 7, 10),
          restAlerts: service,
        );
        addTearDown(controller.dispose);
        await controller.recordSet(
          slot: _slot(),
          reps: 8,
          loadKg: 40,
          startRestAfterRecord: true,
        );
        final open = controller.state.launch!.state.restPeriods.single;
        await controller.skipRest(open.id);
        await controller.recordSet(
          slot: _slot(),
          reps: 8,
          loadKg: 40,
          startRestAfterRecord: true,
        );
        await pumpEventQueue();
        expect(controller.state.launch!.state.restPeriods, hasLength(2));
        expect(requests, 1);

        // A later workout after an app restart reads the stored flag.
        await restOnce(newService(), draftId: 2);
        expect(requests, 1);
        expect(prompts, [RestAlertPrompt.notifications]);
      },
    );

    test('"Not now" still counts as asked', () async {
      final service = RestAlertPermissionService(
        requestNotifications: () async {
          requests++;
          return true;
        },
        notificationsGranted: () async => false,
        canScheduleExactAlarms: () async => null,
        openExactAlarmSettings: () async {},
      )..registerPresenter((prompt) async => false);

      await restOnce(service);
      await restOnce(service, draftId: 2);
      expect(requests, 0);
    });

    test(
      'without exact alarms, offers precise alerts once on a later rest',
      () async {
        canExact = false;
        final service = newService();

        await restOnce(service);
        expect(prompts, [RestAlertPrompt.notifications]);
        expect(settingsOpened, 0);

        await restOnce(service, draftId: 2);
        expect(prompts, [
          RestAlertPrompt.notifications,
          RestAlertPrompt.preciseAlarms,
        ]);
        expect(settingsOpened, 1);

        await restOnce(service, draftId: 3);
        expect(prompts, hasLength(2));
        expect(settingsOpened, 1);
        expect(requests, 1);
      },
    );
  });
}

class _MemoryAdapter extends StrengthExecutionCompatibilityAdapter {
  _MemoryAdapter(super.repository);

  @override
  Future<void> saveDraft({
    required int draftId,
    required B02ExecutionDraftState state,
  }) async {}
}

B02StrengthExecutionSlot _slot() {
  return const B02StrengthExecutionSlot(
    id: 'slot-1',
    groupId: null,
    groupType: null,
    groupLabel: null,
    groupOrdinal: null,
    roundOrdinal: null,
    memberOrdinal: null,
    prescriptionId: 'pres-slot-1',
    exerciseId: 'exercise-slot-1',
    exerciseNameSnapshot: 'Bench press',
    plannedSets: 3,
    targetRepsMin: 8,
    targetRepsMax: 10,
    targetRpe: null,
    targetLoadKg: 40,
    targetLoadBasis: B02LoadBasis.totalExternal,
    prescribedRestSeconds: 90,
  );
}

B02StrengthExecutionLaunch _launch(int draftId) {
  return B02StrengthExecutionLaunch(
    draftId: draftId,
    occurrenceId: null,
    executionSnapshotJson: '{}',
    state: B02ExecutionDraftState(
      snapshotId: 'snap-$draftId',
      snapshotVersion: 1,
      activityType: B02ActivityType.strength,
      routineName: 'Test routine',
      elapsedSeconds: 0,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
    ),
  );
}
