import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/b02_strength_execution_repository.dart';
import 'package:indifit/data/repositories/calendar_repository.dart';
import 'package:indifit/features/workout_player/b02_strength_execution_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late B02StrengthExecutionController controller;

  setUp(() {
    db = AppDatabase.memory();
    controller = B02StrengthExecutionController(
      StrengthExecutionCompatibilityAdapter(
        StrengthExecutionRepository(
          db: db,
          calendarRepo: CalendarRepository(db),
        ),
      ),
    );
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test('exposes ready, partial, failure and recovery states', () async {
    expect(controller.state.status, B02StrengthExecutionStatus.loading);

    await controller.startUnscheduled(
      routineName: 'Offline press',
      executionSnapshotJson: '{"version":1,"routineName":"Offline press"}',
    );
    expect(controller.state.status, B02StrengthExecutionStatus.ready);
    final launch = controller.state.launch!;

    await controller.saveDraft(launch.state);
    expect(controller.state.status, B02StrengthExecutionStatus.partial);
    expect(controller.state.launch!.draftId, launch.draftId);

    expect(await controller.finalize(commandId: 'finish-invalid'), isFalse);
    expect(controller.state.status, B02StrengthExecutionStatus.failure);
    expect(controller.state.launch, isNotNull);
    expect(controller.state.errorMessage, contains('could not be saved'));

    await controller.startUnscheduled(
      routineName: 'Broken',
      executionSnapshotJson: 'not-json',
    );
    expect(controller.state.status, B02StrengthExecutionStatus.recovery);
    expect(controller.state.errorMessage, contains('reopened'));
  });

  test(
    'persists foreground wall-clock duration and excludes background',
    () async {
      var now = DateTime.utc(2026, 8, 11, 10);
      controller.dispose();
      controller = B02StrengthExecutionController(
        StrengthExecutionCompatibilityAdapter(
          StrengthExecutionRepository(
            db: db,
            calendarRepo: CalendarRepository(db),
          ),
        ),
        nowUtc: () => now,
      );
      await controller.startUnscheduled(
        routineName: 'Timed quick workout',
        executionSnapshotJson:
            '{"version":1,"routineName":"Timed quick workout"}',
      );

      now = now.add(const Duration(seconds: 65));
      await controller.pauseElapsed();
      expect(controller.state.launch!.state.elapsedSeconds, 65);

      now = now.add(const Duration(minutes: 20));
      await controller.resumeElapsed();
      now = now.add(const Duration(seconds: 10));
      await controller.saveDraft(controller.state.launch!.state);
      expect(controller.state.launch!.state.elapsedSeconds, 75);
    },
  );
}
