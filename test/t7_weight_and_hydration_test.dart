import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/di/providers.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/health_service.dart';
import 'package:indifit/data/repositories/workout_repository.dart';
import 'package:indifit/features/dashboard/dashboard_controller.dart';
import 'package:indifit/features/dashboard/widgets/log_weight_bottom_sheet.dart';
import 'package:indifit/features/settings/unit_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

class _UnlockedWorkoutRepository extends WorkoutRepository {
  _UnlockedWorkoutRepository(super.db);

  @override
  Future<WeightLogStatus> getWeightLogStatus() async =>
      WeightLogStatus(canLog: true, isEditingToday: false, daysUntilUnlock: 0);
}

class _DelayedStatusWorkoutRepository extends WorkoutRepository {
  final Completer<WeightLogStatus> statusCompleter;
  _DelayedStatusWorkoutRepository(super.db, {required this.statusCompleter});

  @override
  Future<WeightLogStatus> getWeightLogStatus() => statusCompleter.future;
}

class _MockHealthService extends HealthService {
  @override
  Future<bool> writeBodyWeight(double weightKg, [DateTime? timestamp]) async =>
      true;
}

class _MockFailingWorkoutRepository extends WorkoutRepository {
  _MockFailingWorkoutRepository(super.db);

  @override
  Future<int> logBodyMeasurement({
    double? weight,
    double? waist,
    double? chest,
    double? arms,
  }) async {
    throw Exception('Simulated Database Write Failure');
  }

  @override
  Future<int> logWeightAndSyncProfile({required double weight}) async {
    throw Exception('Simulated Database Write Failure');
  }

  @override
  Future<WeightLogStatus> getWeightLogStatus() async =>
      WeightLogStatus(canLog: true, isEditingToday: false, daysUntilUnlock: 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ════════════════════════════════════════════════════════════════
  // Weight Logging Correctness
  // ════════════════════════════════════════════════════════════════
  group('Task T7: Weight Logging Correctness', () {
    late AppDatabase db;
    late _MockHealthService mockHealth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.memory();
      mockHealth = _MockHealthService();
    });

    tearDown(() async {
      await db.close();
    });

    // 1. Save is disabled while lock status is loading
    testWidgets('1. Save is disabled while lock status is loading', (
      tester,
    ) async {
      final statusCompleter = Completer<WeightLogStatus>();
      final delayedRepo = _DelayedStatusWorkoutRepository(
        db,
        statusCompleter: statusCompleter,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutRepositoryProvider.overrideWithValue(delayedRepo),
            healthServiceProvider.overrideWithValue(mockHealth),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LogWeightBottomSheet(
                currentWeight: 75.0,
                onSave: (w) async {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(
        button.onPressed,
        isNull,
        reason: 'Save button must be disabled while lock status is loading',
      );
      expect(find.text('Checking Status...'), findsOneWidget);

      statusCompleter.complete(
        WeightLogStatus(
          canLog: true,
          isEditingToday: false,
          daysUntilUnlock: 0,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final enabledButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(
        enabledButton.onPressed,
        isNotNull,
        reason: 'Save button becomes enabled after status loads',
      );
    });

    // 2. A fast double tap causes only one save operation
    testWidgets('2. A fast double tap causes only one save operation', (
      tester,
    ) async {
      int saveCount = 0;
      final saveCompleter = Completer<void>();
      addTearDown(() {
        if (!saveCompleter.isCompleted) saveCompleter.complete();
      });

      final unlockedRepo = _UnlockedWorkoutRepository(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutRepositoryProvider.overrideWithValue(unlockedRepo),
            healthServiceProvider.overrideWithValue(mockHealth),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LogWeightBottomSheet(
                currentWeight: 75.0,
                onSave: (w) async {
                  saveCount++;
                  await saveCompleter.future;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);
      final btn = tester.widget<ElevatedButton>(buttonFinder);
      expect(
        btn.onPressed,
        isNotNull,
        reason: 'Button should be enabled after status loads',
      );

      await tester.tap(buttonFinder);
      await tester.pump();

      await tester.tap(buttonFinder);
      await tester.pump();

      expect(
        saveCount,
        equals(1),
        reason: 'Double tap must trigger onSave exactly once',
      );

      saveCompleter.complete();
      await tester.pump(const Duration(milliseconds: 100));
    });

    // 3. The caller awaits the save operation
    test('3. The caller awaits the save operation', () async {
      bool onSaveFinished = false;
      final unlockedRepo = _UnlockedWorkoutRepository(db);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          workoutRepositoryProvider.overrideWithValue(unlockedRepo),
          healthServiceProvider.overrideWithValue(mockHealth),
        ],
      );

      final controller = container.read(dashboardControllerProvider.notifier);
      // Wait for the constructor's fire-and-forget loadStateData() to finish
      await controller.loadStateData();

      final updateFuture = controller.updateWeight(80.0).then((_) {
        onSaveFinished = true;
      });

      expect(onSaveFinished, isFalse);
      await updateFuture;
      expect(onSaveFinished, isTrue);

      // Do NOT dispose — the constructor's fire-and-forget loadStateData()
      // may still have microtasks queued. The tearDown closes the DB.
    });

    // 4. Successful database write updates profile/cache state
    test('4. Successful database write updates profile/cache state', () async {
      final unlockedRepo = _UnlockedWorkoutRepository(db);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          workoutRepositoryProvider.overrideWithValue(unlockedRepo),
          healthServiceProvider.overrideWithValue(mockHealth),
        ],
      );

      final controller = container.read(dashboardControllerProvider.notifier);
      await controller.loadStateData();

      await controller.updateWeight(82.5);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('current_weight'), equals(82.5));

      final profileState = container.read(userProfileProvider);
      expect(profileState.currentWeight, equals(82.5));

      final measurements = await db.select(db.bodyMeasurements).get();
      expect(measurements.length, equals(1));
      expect(measurements.first.weight, equals(82.5));
    });

    // 5. Failed database write does not update profile/cache state
    test(
      '5. Failed database write does not update profile/cache state',
      () async {
        final failingRepo = _MockFailingWorkoutRepository(db);

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            workoutRepositoryProvider.overrideWithValue(failingRepo),
            healthServiceProvider.overrideWithValue(mockHealth),
          ],
        );

        final controller = container.read(dashboardControllerProvider.notifier);
        await controller.loadStateData();

        final initialWeight = container.read(userProfileProvider).currentWeight;

        bool threwException = false;
        try {
          await controller.updateWeight(95.0);
        } catch (_) {
          threwException = true;
        }

        expect(
          threwException,
          isTrue,
          reason: 'Failed DB write must propagate the exception',
        );

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getDouble('current_weight'),
          isNot(equals(95.0)),
          reason: 'SharedPreferences must not be updated on DB failure',
        );

        final profileState = container.read(userProfileProvider);
        expect(
          profileState.currentWeight,
          equals(initialWeight),
          reason: 'Profile state must not be updated on DB failure',
        );
      },
    );

    // 6. Rate-limited or locked save performs no writes
    test('6. Rate-limited or locked save performs no writes', () async {
      final workoutRepo = WorkoutRepository(db);

      // Insert a single entry from 3 days ago.
      // The latest entry is 3 days old (within 7-day window, not today),
      // so getWeightLogStatus() returns canLog: false.
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
      await db
          .into(db.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              weight: const Value(74.0),
              recordedAt: Value(threeDaysAgo),
            ),
          );

      bool threwStateError = false;
      try {
        await workoutRepo.logBodyMeasurement(weight: 78.0);
      } on StateError catch (_) {
        threwStateError = true;
      }

      expect(
        threwStateError,
        isTrue,
        reason: 'logBodyMeasurement must throw StateError when locked',
      );
    });

    // 6a. A Progress body measurement must not erase today's weight entry.
    test(
      '6a. Body measurement preserves an existing same-day weight',
      () async {
        final workoutRepo = WorkoutRepository(db);
        await db
            .into(db.bodyMeasurements)
            .insert(
              BodyMeasurementsCompanion.insert(
                weight: const Value(82.0),
                recordedAt: Value(DateTime.now()),
              ),
            );

        await workoutRepo.logBodyMeasurement(waist: 82.5);

        final measurements = await db.select(db.bodyMeasurements).get();
        expect(measurements, hasLength(1));
        expect(measurements.single.weight, 82.0);
        expect(measurements.single.waist, 82.5);
      },
    );

    test('6b. Weight preserves existing same-day body measurements', () async {
      final workoutRepo = WorkoutRepository(db);
      await db
          .into(db.bodyMeasurements)
          .insert(
            BodyMeasurementsCompanion.insert(
              waist: const Value(82.5),
              chest: const Value(101.0),
              recordedAt: Value(DateTime.now()),
            ),
          );

      await workoutRepo.logWeightAndSyncProfile(weight: 82.0);

      final measurements = await db.select(db.bodyMeasurements).get();
      expect(measurements, hasLength(1));
      expect(measurements.single.weight, 82.0);
      expect(measurements.single.waist, 82.5);
      expect(measurements.single.chest, 101.0);
    });

    test(
      '6c. Persistence rejects non-finite and out-of-range weights',
      () async {
        final workoutRepo = WorkoutRepository(db);
        for (final invalid in [
          double.nan,
          double.infinity,
          double.negativeInfinity,
          minimumLoggedWeightKg - 0.1,
          maximumLoggedWeightKg + 0.1,
        ]) {
          await expectLater(
            workoutRepo.logWeightAndSyncProfile(weight: invalid),
            throwsArgumentError,
          );
        }
        expect(await db.select(db.bodyMeasurements).get(), isEmpty);
      },
    );

    // 7. Bottom sheet closes only after successful persistence
    testWidgets('7. Bottom sheet closes only after successful persistence', (
      tester,
    ) async {
      final saveCompleter = Completer<void>();
      addTearDown(() {
        if (!saveCompleter.isCompleted) saveCompleter.complete();
      });

      final unlockedRepo = _UnlockedWorkoutRepository(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutRepositoryProvider.overrideWithValue(unlockedRepo),
            healthServiceProvider.overrideWithValue(mockHealth),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => LogWeightBottomSheet.show(
                    context,
                    75.0,
                    (w) async => await saveCompleter.future,
                  ),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pump(); // Start animation
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // Finish open animation + status load

      expect(find.byType(LogWeightBottomSheet), findsOneWidget);

      // Tap the save button (last ElevatedButton in the tree)
      final saveButton = find.byType(ElevatedButton).last;
      await tester.tap(saveButton);
      await tester.pump();

      // Sheet must remain visible while save is in progress
      expect(find.byType(LogWeightBottomSheet), findsOneWidget);

      // Complete the save
      saveCompleter.complete();
      await tester.pump(); // Process future resolution + Navigator.pop
      await tester.pump(); // Process route transition start
      await tester.pump(
        const Duration(seconds: 1),
      ); // Complete dismiss animation

      // Sheet must now be gone
      expect(find.byType(LogWeightBottomSheet), findsNothing);
    });

    // 8. Failed save leaves UI recoverable and exposes error
    testWidgets('8. Failed save leaves UI recoverable and exposes error', (
      tester,
    ) async {
      final unlockedRepo = _UnlockedWorkoutRepository(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutRepositoryProvider.overrideWithValue(unlockedRepo),
            healthServiceProvider.overrideWithValue(mockHealth),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LogWeightBottomSheet(
                currentWeight: 75.0,
                onSave: (w) async {
                  throw Exception('Database Write Exception');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LogWeightBottomSheet), findsOneWidget);
      expect(
        find.text('Weight could not be saved. Try again.'),
        findsOneWidget,
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(
        button.onPressed,
        isNotNull,
        reason: 'Save button must be recoverable after failure',
      );
    });

    testWidgets('invalid weight input exposes validation without saving', (
      tester,
    ) async {
      final unlockedRepo = _UnlockedWorkoutRepository(db);
      var saveCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutRepositoryProvider.overrideWithValue(unlockedRepo),
            healthServiceProvider.overrideWithValue(mockHealth),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LogWeightBottomSheet(
                currentWeight: 75.0,
                onSave: (w) async => saveCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'NaN');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(saveCalled, isFalse);
      expect(
        find.text('Enter a weight between 20 and 350 kg.'),
        findsOneWidget,
      );
      expect(find.byType(LogWeightBottomSheet), findsOneWidget);
    });

    testWidgets('imperial input converts once and persists canonical kg', (
      tester,
    ) async {
      final unlockedRepo = _UnlockedWorkoutRepository(db);
      SharedPreferences.setMockInitialValues({
        UnitPreferenceNotifier.key: UnitPreferenceNotifier.imperial,
      });
      double? savedKilograms;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutRepositoryProvider.overrideWithValue(unlockedRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LogWeightBottomSheet(
                currentWeight: 100,
                onSave: (value) async => savedKilograms = value,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.widgetWithText(TextField, 'Weight (lb)'), findsOneWidget);
      expect(find.text('+0.5 lb'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '220.5');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(savedKilograms, closeTo(100.017, 0.002));
    });
  });

  // ════════════════════════════════════════════════════════════════
  // Hydration Correctness
  // ════════════════════════════════════════════════════════════════
  group('Task T7: Hydration Correctness', () {
    late AppDatabase db;
    late WorkoutRepository workoutRepo;
    late _MockHealthService mockHealth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.memory();
      workoutRepo = WorkoutRepository(db);
      mockHealth = _MockHealthService();
    });

    tearDown(() async {
      await db.close();
    });

    // 9. Weekly progress reads the canonical hydration value
    test(
      '9. Weekly progress reads canonical hydration value (water_logged)',
      () async {
        SharedPreferences.setMockInitialValues({
          'weekly_action_type': 'water_intake',
          'weekly_action_text': 'Drink 8 glasses',
          'weekly_action_target': 1,
          'water_goal': 8,
          'water_logged': 8,
        });

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            workoutRepositoryProvider.overrideWithValue(workoutRepo),
            healthServiceProvider.overrideWithValue(mockHealth),
          ],
        );

        final controller = container.read(dashboardControllerProvider.notifier);
        // Let the constructor's loadStateData() complete before proceeding
        await controller.loadStateData();

        // Now explicitly call the method under test
        await controller.loadWeeklyActionProgress();

        final state = container.read(dashboardControllerProvider);
        expect(
          state.weeklyActionProgress,
          equals(1),
          reason: 'Weekly progress must read water_logged, not water_glasses',
        );
      },
    );

    // 10. Hydration actions and weekly calculations use same key
    test(
      '10. Hydration actions and weekly calculations use the same key',
      () async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            workoutRepositoryProvider.overrideWithValue(workoutRepo),
            healthServiceProvider.overrideWithValue(mockHealth),
          ],
        );

        final waterNotifier = container.read(waterProvider.notifier);
        // WaterNotifier.loadState() is async from the constructor; await it
        await waterNotifier.loadState();
        await waterNotifier.logWater(8);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt('water_logged'),
          equals(8),
          reason: 'WaterNotifier must write to water_logged',
        );

        await prefs.setString('weekly_action_type', 'water_intake');
        await prefs.setString('weekly_action_text', 'Drink 8 glasses');
        await prefs.setInt('weekly_action_target', 1);
        await prefs.setInt('water_goal', 8);

        final dashController = container.read(
          dashboardControllerProvider.notifier,
        );
        await dashController.loadStateData();
        await dashController.loadWeeklyActionProgress();

        final dashState = container.read(dashboardControllerProvider);
        expect(
          dashState.weeklyActionProgress,
          equals(1),
          reason:
              'Weekly action must read the same water_logged key that WaterNotifier writes',
        );
      },
    );

    // 11. Existing hydration data remains readable after the fix
    test(
      '11. Existing hydration data remains readable after the fix',
      () async {
        SharedPreferences.setMockInitialValues({
          'water_logged': 5,
          'water_goal': 8,
          'water_glass_size': 250,
        });

        final container = ProviderContainer();
        final waterNotifier = container.read(waterProvider.notifier);
        // WaterNotifier constructor calls loadState() fire-and-forget;
        // explicitly await it so the SharedPreferences values are loaded.
        await waterNotifier.loadState();

        final waterState = container.read(waterProvider);
        expect(
          waterState.waterLogged,
          equals(5),
          reason: 'Existing water_logged data must remain readable',
        );
      },
    );

    test(
      '12. Failed profile update mid-transaction rolls back body measurement creation',
      () async {
        await db
            .into(db.userProfiles)
            .insert(UserProfilesCompanion.insert(weight: const Value(74.0)));
        await db.customStatement('''
          CREATE TRIGGER fail_weight_profile_update
          BEFORE UPDATE OF weight ON user_profiles
          BEGIN
            SELECT RAISE(ABORT, 'simulated profile update failure');
          END;
        ''');

        final workoutRepo = WorkoutRepository(db);
        await expectLater(
          workoutRepo.logWeightAndSyncProfile(weight: 99.0),
          throwsA(isA<Exception>()),
        );

        final measurements = await db.select(db.bodyMeasurements).get();
        final profiles = await db.select(db.userProfiles).get();
        expect(measurements, isEmpty);
        expect(
          profiles.single.weight,
          equals(74.0),
          reason: 'Profile must remain unchanged when the transaction fails.',
        );
      },
    );
  });
}
