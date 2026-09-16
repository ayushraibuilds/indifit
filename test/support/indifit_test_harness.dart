import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/core_providers.dart';
import 'package:indifit/core/services/app_preferences_service.dart';
import 'package:indifit/core/services/workout_session_wake_lock_coordinator.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Installs the Flutter services binding required by database seeders and
/// platform-channel fakes used in IndiFit tests.
void initializeIndiFitTestHarness() {
  TestWidgetsFlutterBinding.ensureInitialized();
}

/// Replaces the process-local SharedPreferences test store with [values].
///
/// Call this in `setUp` or at the start of a test that reads preferences. The
/// replacement is deliberate: callers never inherit values from an earlier
/// test in the same isolate.
void setIndiFitTestPreferences([
  Map<String, Object> values = const <String, Object>{},
]) {
  initializeIndiFitTestHarness();
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(values));
}

/// Creates a [ProviderContainer] pre-wired with a mock [SharedPreferences] and
/// [AppPreferencesService], plus any caller-specified [overrides].
Future<ProviderContainer> createIndiFitTestPreferencesContainer({
  Map<String, Object> initialValues = const <String, Object>{},
  List<Override> overrides = const [],
}) async {
  setIndiFitTestPreferences(initialValues);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appPreferencesServiceProvider.overrideWithValue(
        AppPreferencesService(prefs),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// A deterministic screen-awake driver for tests that exercise workout
/// lifecycle policy without exercising the platform plugin itself.
class TestWorkoutWakeLockDriver implements WorkoutWakeLockDriver {
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enable() async {
    enableCalls += 1;
  }

  @override
  Future<void> disable() async {
    disableCalls += 1;
  }
}

/// Creates a test-owned wake-lock coordinator and disposes it automatically.
WorkoutSessionWakeLockCoordinator createTestWorkoutWakeLockCoordinator({
  TestWorkoutWakeLockDriver? driver,
}) {
  initializeIndiFitTestHarness();
  final coordinator = WorkoutSessionWakeLockCoordinator(
    driver: driver ?? TestWorkoutWakeLockDriver(),
  );
  addTearDown(coordinator.dispose);
  return coordinator;
}

/// Owns all in-memory databases opened by one test or one explicit test group.
///
/// Drift warns whenever the same generated database class is instantiated more
/// than once, even when a backup/restore test intentionally uses independent
/// in-memory executors. This scope suppresses that warning only while it opens
/// the second and later database it owns. A database leaked outside the scope
/// still produces Drift's warning.
class TestDatabaseScope {
  TestDatabaseScope() {
    initializeIndiFitTestHarness();
  }

  final List<AppDatabase> _databases = <AppDatabase>[];
  bool _closed = false;

  bool get isClosed => _closed;

  AppDatabase create({int? schemaVersionOverride}) => open(
    () => AppDatabase.memory(schemaVersionOverride: schemaVersionOverride),
  );

  /// Opens and owns a database produced by a specialized test fixture.
  ///
  /// Use this for historical-schema fixtures whose factory cannot be expressed
  /// through [AppDatabase.memory]. The factory runs inside the same narrowly
  /// scoped Drift warning policy as [create].
  AppDatabase open(AppDatabase Function() factory) {
    if (_closed) {
      throw StateError('This test database scope is already closed.');
    }

    final previousWarningSetting =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    if (_databases.isNotEmpty) {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    }

    try {
      final database = factory();
      _databases.add(database);
      return database;
    } finally {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases =
          previousWarningSetting;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    for (final database in _databases.reversed) {
      await database.close();
    }
    _databases.clear();
  }
}

/// Creates a database scope owned by the currently running test.
///
/// The scope is closed automatically after the test. For databases shared by
/// an explicit `setUpAll`, construct [TestDatabaseScope] directly and close it
/// from the matching `tearDownAll`.
TestDatabaseScope registerTestDatabaseScope() {
  final scope = TestDatabaseScope();
  addTearDown(scope.close);
  return scope;
}
