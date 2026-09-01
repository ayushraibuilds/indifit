import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  test(
    'database scope owns multiple independent executors without noise',
    () async {
      final messages = <String>[];
      final previousDebugPrint = driftRuntimeOptions.debugPrint;
      final previousWarningSetting =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.debugPrint = messages.add;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;

      final scope = TestDatabaseScope();
      try {
        final source = scope.open(() => AppDatabase.memory());
        final target = scope.create();

        expect(
          await source.customSelect('SELECT 1 AS value').get(),
          hasLength(1),
        );
        expect(
          await target.customSelect('SELECT 1 AS value').get(),
          hasLength(1),
        );
        expect(
          messages.where((message) => message.contains('multiple times')),
          isEmpty,
        );

        await scope.close();
        expect(scope.isClosed, isTrue);
        expect(() => scope.create(), throwsStateError);
      } finally {
        await scope.close();
        driftRuntimeOptions.debugPrint = previousDebugPrint;
        driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            previousWarningSetting;
      }
    },
  );

  test('preference seeding replaces rather than inherits test state', () async {
    setIndiFitTestPreferences(<String, Object>{'first': true});
    expect((await SharedPreferences.getInstance()).getBool('first'), isTrue);

    setIndiFitTestPreferences(<String, Object>{'second': 2});
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('first'), isNull);
    expect(preferences.getInt('second'), 2);
  });

  test(
    'wake-lock fake records lifecycle intent without a platform channel',
    () async {
      final driver = TestWorkoutWakeLockDriver();
      final coordinator = createTestWorkoutWakeLockCoordinator(driver: driver);

      await coordinator.setActiveSession('test-session');
      await coordinator.clearActiveSession('test-session');

      expect(driver.enableCalls, 1);
      expect(driver.disableCalls, 1);
    },
  );
}
