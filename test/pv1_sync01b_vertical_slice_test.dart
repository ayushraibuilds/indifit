import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/capabilities/account_capability.dart';
import 'package:indifit/core/capabilities/network_capability.dart';
import 'package:indifit/core/capabilities/sync_capability.dart';
import 'package:indifit/core/outbox/outbox.dart';
import 'package:indifit/core/sync/hlc_timestamp.dart';
import 'package:indifit/core/sync/sync_api_client.dart';
import 'package:indifit/core/sync/sync_mutation.dart';
import 'package:indifit/core/sync/sync_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/indifit_test_harness.dart';

class _FakeAccount implements AccountCapability {
  _FakeAccount({required this.nodeId});

  final String nodeId;

  @override
  Future<bool> get isAuthenticated async => true;

  @override
  Future<String?> get currentUserId async => 'sync-user-42';

  @override
  Future<String> get deviceId async => nodeId;

  @override
  Stream<AccountSession?> get onSessionChanged => Stream.value(
        AccountSession(
          userId: 'sync-user-42',
          deviceId: nodeId,
          displayName: 'Sync User',
        ),
      );

  @override
  Future<void> signOut() async {}

  @override
  Future<void> requestAccountDeletion() async {}
}

void main() {
  initializeIndiFitTestHarness();

  group('PV1-SYNC-01B: Multi-Device Sync Vertical Slice', () {
    late SharedPreferences prefsA;
    late SharedPreferences prefsB;

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      setIndiFitTestPreferences({});
      prefsA = await SharedPreferences.getInstance();
      prefsB = await SharedPreferences.getInstance();
    });

    test('Two devices converge across push and pull deltas', () async {
      final sharedRelay = InMemorySyncApiClient();

      // Device A setup
      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final networkA = TestableNetworkCapability(initialConnected: true);
      final outboxA = InMemoryOutboxRepository();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: networkA,
        outbox: outboxA,
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      // Device B setup
      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final networkB = TestableNetworkCapability(initialConnected: true);
      final outboxB = InMemoryOutboxRepository();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: networkB,
        outbox: outboxB,
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // 1. Device A records a weight measurement locally
      const weightHlc = HlcTimestamp(millis: 1000, counter: 0, nodeId: 'device-A');
      const mutationA = SyncMutation(
        entityId: '101',
        domain: SyncDomain.weights,
        type: SyncMutationType.insert,
        hlc: weightHlc,
        payload: {'weight_kg': 72.5, 'date': '2026-09-03'},
      );

      await serviceA.recordLocalMutation(mutationA);

      // Device A syncs (pushes to relay)
      final resultsA = await serviceA.triggerSync();
      expect(resultsA.every((r) => r.success), isTrue);
      expect(sharedRelay.totalStoredCount, 1);

      // 2. Device B has no weight yet
      var weightsB = await dbB.select(dbB.bodyMeasurements).get();
      expect(weightsB, isEmpty);

      // Device B syncs (pulls from relay)
      final resultsB = await serviceB.triggerSync();
      expect(resultsB.every((r) => r.success), isTrue);

      // 3. Verify Device B applied the record into local SQLite.
      // Global entity identity is opaque (UUID); local autoincrement ids are
      // never coerced from remote ids (that caused cross-device collisions).
      weightsB = await dbB.select(dbB.bodyMeasurements).get();
      expect(weightsB, hasLength(1));
      expect(weightsB.first.weight, 72.5);
    });

    test('Offline queueing survives until network reconnection', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scope = registerTestDatabaseScope();
      final db = scope.create();
      final network = TestableNetworkCapability(initialConnected: false); // OFFLINE
      final outbox = InMemoryOutboxRepository();

      final service = SyncService(
        db: db,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'offline-device'),
        network: network,
        outbox: outbox,
        apiClient: sharedRelay,
      );

      // Record while offline
      const hlc = HlcTimestamp(millis: 2000, counter: 0, nodeId: 'offline-device');
      const mutation = SyncMutation(
        entityId: '201',
        domain: SyncDomain.weights,
        type: SyncMutationType.insert,
        hlc: hlc,
        payload: {'weight_kg': 80.0, 'date': '2026-09-03'},
      );
      await service.recordLocalMutation(mutation);

      // Status reflects offline pending operations
      final statusOffline = await service.getStatus();
      expect(statusOffline.status.name, 'offline');
      expect(statusOffline.pendingOperationsCount, 1);

      // Trigger sync while offline fails safely
      final offlineResults = await service.triggerSync();
      expect(offlineResults.first.success, isFalse);
      expect(offlineResults.first.errorMessage, 'Device is offline.');
      expect(sharedRelay.totalStoredCount, 0);

      // Reconnect network
      network.setConnected(true);

      // Trigger sync online
      final onlineResults = await service.triggerSync();
      expect(onlineResults.every((r) => r.success), isTrue);
      expect(sharedRelay.totalStoredCount, 1);

      // Status transitions to synced
      final statusOnline = await service.getStatus();
      expect(statusOnline.status.name, 'synced');
    });

    test('Tombstone deletion propagates and removes record from peer device', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // 1. Create and sync initial workout session
      const createHlc = HlcTimestamp(millis: 3000, counter: 0, nodeId: 'device-A');
      const createMutation = SyncMutation(
        entityId: '301',
        domain: SyncDomain.workouts,
        type: SyncMutationType.insert,
        hlc: createHlc,
        payload: {'name': 'Morning Chest Day', 'completed_at': '2026-09-03T07:00:00Z'},
      );
      await serviceA.recordLocalMutation(createMutation);
      await serviceA.triggerSync();

      // Device B receives the workout
      await serviceB.triggerSync();
      var sessionsB = await dbB.select(dbB.workoutSessions).get();
      expect(sessionsB, hasLength(1));
      expect(sessionsB.first.name, 'Morning Chest Day');

      // 2. Device A deletes the workout (tombstone)
      const deleteHlc = HlcTimestamp(millis: 4000, counter: 0, nodeId: 'device-A');
      const deleteMutation = SyncMutation(
        entityId: '301',
        domain: SyncDomain.workouts,
        type: SyncMutationType.delete,
        hlc: deleteHlc,
      );
      await serviceA.recordLocalMutation(deleteMutation);
      await serviceA.triggerSync();

      // Device B pulls tombstone
      await serviceB.triggerSync();

      // 3. Verify record is extinguished on Device B
      sessionsB = await dbB.select(dbB.workoutSessions).get();
      expect(sessionsB, isEmpty);
    });

    test('Family 3: Food logs push/pull convergence and tombstone deletion', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // 1. Device A logs food
      const logHlc = HlcTimestamp(millis: 5000, counter: 0, nodeId: 'device-A');
      const mutationA = SyncMutation(
        entityId: 'food-log-1',
        domain: SyncDomain.nutritionLogs,
        type: SyncMutationType.insert,
        hlc: logHlc,
        payload: {
          'name': 'Paneer Bhurji',
          'calories': 350,
          'protein_g': 22.0,
          'carbs_g': 8.0,
          'fat_g': 25.0,
          'meal_type': 'lunch',
          'logged_at': '2026-09-03T13:00:00Z',
        },
      );
      await serviceA.recordNutritionLogMutation(mutationA);
      await serviceA.triggerSync();

      // Device B pulls food log
      await serviceB.triggerSync();
      var logsB = await dbB.select(dbB.foodLogs).get();
      expect(logsB, hasLength(1));
      expect(logsB.first.name, 'Paneer Bhurji');
      expect(logsB.first.calories, 350);
      expect(logsB.first.proteinG, 22.0);

      // 2. Device A deletes food log
      const deleteHlc = HlcTimestamp(millis: 6000, counter: 0, nodeId: 'device-A');
      const deleteMutation = SyncMutation(
        entityId: 'food-log-1',
        domain: SyncDomain.nutritionLogs,
        type: SyncMutationType.delete,
        hlc: deleteHlc,
      );
      await serviceA.recordNutritionLogMutation(deleteMutation);
      await serviceA.triggerSync();

      await serviceB.triggerSync();
      logsB = await dbB.select(dbB.foodLogs).get();
      expect(logsB, isEmpty);
    });

    test('Family 3: Custom food sync, single-candidate update, and ambiguous multi-candidate separation', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // 1. Device A creates a custom food
      const foodHlc = HlcTimestamp(millis: 7000, counter: 0, nodeId: 'device-A');
      const customFoodMutation = SyncMutation(
        entityId: 'custom-food-101',
        domain: SyncDomain.nutritionLogs,
        type: SyncMutationType.insert,
        hlc: foodHlc,
        payload: {
          'entity_type': 'custom_food',
          'name': 'Besan Cheela',
          'calories': 180,
          'protein_g': 10.0,
          'carbs_g': 24.0,
          'fat_g': 5.0,
          'serving_size': 1.0,
          'serving_unit': 'piece',
          'category': 'snack',
        },
      );
      await serviceA.recordCustomFoodMutation(customFoodMutation);
      await serviceA.triggerSync();

      // Device B pulls custom food
      await serviceB.triggerSync();
      var foodsB = await (dbB.select(dbB.foodItems)..where((t) => t.isCustom.equals(true))).get();
      expect(foodsB, hasLength(1));
      expect(foodsB.first.name, 'Besan Cheela');
      expect(foodsB.first.calories, 180);

      // 2. Single candidate update from Device A (updating calories to 200)
      const updateHlc = HlcTimestamp(millis: 8000, counter: 0, nodeId: 'device-A');
      const updateMutation = SyncMutation(
        entityId: 'custom-food-101',
        domain: SyncDomain.nutritionLogs,
        type: SyncMutationType.update,
        hlc: updateHlc,
        payload: {
          'entity_type': 'custom_food',
          'name': 'Besan Cheela',
          'calories': 200,
          'protein_g': 12.0,
          'carbs_g': 24.0,
          'fat_g': 6.0,
          'serving_size': 1.0,
          'serving_unit': 'piece',
          'category': 'snack',
        },
      );
      await serviceA.recordCustomFoodMutation(updateMutation);
      await serviceA.triggerSync();

      await serviceB.triggerSync();
      foodsB = await (dbB.select(dbB.foodItems)..where((t) => t.isCustom.equals(true))).get();
      expect(foodsB, hasLength(1)); // Updated in-place, not duplicated!
      expect(foodsB.first.calories, 200);
      expect(foodsB.first.proteinG, 12.0);

      // 3. Ambiguity separation: If Device B manually has 2 items with same name,
      // a new sync insert does not blindly merge into one of them.
      await dbB.into(dbB.foodItems).insert(FoodItemsCompanion.insert(
            name: 'Besan Cheela',
            calories: 250,
            proteinG: 14.0,
            carbsG: 30.0,
            fatG: 8.0,
            servingSize: 2.0,
            servingUnit: 'piece',
            category: 'snack',
            isCustom: const Value(true),
          ));
      foodsB = await (dbB.select(dbB.foodItems)..where((t) => t.isCustom.equals(true))).get();
      expect(foodsB, hasLength(2));

      // New incoming mutation with different entityId
      const separateHlc = HlcTimestamp(millis: 9000, counter: 0, nodeId: 'device-A');
      const separateMutation = SyncMutation(
        entityId: 'custom-food-102',
        domain: SyncDomain.nutritionLogs,
        type: SyncMutationType.insert,
        hlc: separateHlc,
        payload: {
          'entity_type': 'custom_food',
          'name': 'Besan Cheela',
          'calories': 190,
          'protein_g': 11.0,
          'carbs_g': 25.0,
          'fat_g': 5.5,
          'serving_size': 1.0,
          'serving_unit': 'piece',
          'category': 'snack',
        },
      );
      await serviceA.recordCustomFoodMutation(separateMutation);
      await serviceA.triggerSync();

      await serviceB.triggerSync();
      foodsB = await (dbB.select(dbB.foodItems)..where((t) => t.isCustom.equals(true))).get();
      expect(foodsB, hasLength(3)); // Ambiguity preserved; inserts new row instead of mismerging
    });

    test('Family 3: Meal templates and template items transactional convergence and cascade tombstone', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // 1. Device A creates meal template with 2 items
      const mealHlc = HlcTimestamp(millis: 10000, counter: 0, nodeId: 'device-A');
      const mealMutation = SyncMutation(
        entityId: 'High Protein Lunch',
        domain: SyncDomain.nutritionRecipes,
        type: SyncMutationType.insert,
        hlc: mealHlc,
        payload: {
          'name': 'High Protein Lunch',
          'default_meal_type': 'lunch',
          'items': [
            {
              'name': 'Paneer Raw',
              'calories': 260,
              'protein_g': 18.0,
              'carbs_g': 4.0,
              'fat_g': 20.0,
              'serving_logged': 100.0,
              'serving_unit': 'g'
            },
            {
              'name': 'Brown Rice',
              'calories': 150,
              'protein_g': 3.5,
              'carbs_g': 32.0,
              'fat_g': 1.0,
              'serving_logged': 150.0,
              'serving_unit': 'g'
            },
          ],
        },
      );
      await serviceA.recordMealTemplateMutation(mealMutation);
      await serviceA.triggerSync();

      // Device B pulls meal template
      await serviceB.triggerSync();
      final templatesB = await dbB.select(dbB.mealTemplates).get();
      expect(templatesB, hasLength(1));
      expect(templatesB.first.name, 'High Protein Lunch');

      final itemsB = await (dbB.select(dbB.mealTemplateItems)..where((t) => t.templateId.equals(templatesB.first.id))).get();
      expect(itemsB, hasLength(2));
      expect(itemsB.map((i) => i.name), containsAll(['Paneer Raw', 'Brown Rice']));

      // 2. Device A deletes meal template (cascade tombstone)
      const delHlc = HlcTimestamp(millis: 11000, counter: 0, nodeId: 'device-A');
      const delMealMutation = SyncMutation(
        entityId: 'High Protein Lunch',
        domain: SyncDomain.nutritionRecipes,
        type: SyncMutationType.delete,
        hlc: delHlc,
      );
      await serviceA.recordMealTemplateMutation(delMealMutation);
      await serviceA.triggerSync();

      await serviceB.triggerSync();
      expect(await dbB.select(dbB.mealTemplates).get(), isEmpty);
      expect(await dbB.select(dbB.mealTemplateItems).get(), isEmpty);
    });

    test('Family 3: Goal versions append-convergent synchronization', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      const gvHlc1 = HlcTimestamp(millis: 12000, counter: 0, nodeId: 'device-A');
      const goalMutation1 = SyncMutation(
        entityId: 'goal_version:v1-uuid',
        domain: SyncDomain.nutritionLogs,
        type: SyncMutationType.insert,
        hlc: gvHlc1,
        payload: {
          'entity_type': 'goal_version',
          'user_id': 'user-42',
          'version_number': 1,
          'goal_type': 'loss',
          'target_source': 'user_set',
          'calorie_target_kcal': 1800,
          'protein_target_g': 150.0,
          'carbs_target_g': 180.0,
          'fat_target_g': 50.0,
          'effective_from_local_date': '2026-09-01',
          'timezone_id': 'Asia/Kolkata',
        },
      );
      await serviceA.recordGoalVersionMutation(goalMutation1);
      await serviceA.triggerSync();

      await serviceB.triggerSync();
      var goalsB = await dbB.select(dbB.nutritionGoalVersions).get();
      expect(goalsB, hasLength(1));
      expect(goalsB.first.id, 'v1-uuid');
      expect(goalsB.first.calorieTargetKcal, 1800);

      // Append second goal version from Device B
      const gvHlc2 = HlcTimestamp(millis: 13000, counter: 0, nodeId: 'device-B');
      const goalMutation2 = SyncMutation(
        entityId: 'goal_version:v2-uuid',
        domain: SyncDomain.nutritionLogs,
        type: SyncMutationType.insert,
        hlc: gvHlc2,
        payload: {
          'entity_type': 'goal_version',
          'user_id': 'user-42',
          'version_number': 2,
          'goal_type': 'maintenance',
          'target_source': 'user_set',
          'calorie_target_kcal': 2200,
          'protein_target_g': 160.0,
          'carbs_target_g': 230.0,
          'fat_target_g': 65.0,
          'effective_from_local_date': '2026-09-10',
          'timezone_id': 'Asia/Kolkata',
        },
      );
      await serviceB.recordGoalVersionMutation(goalMutation2);
      await serviceB.triggerSync();

      await serviceA.triggerSync();
      var goalsA = await dbA.select(dbA.nutritionGoalVersions).get();
      expect(goalsA, hasLength(2));
      goalsB = await dbB.select(dbB.nutritionGoalVersions).get();
      expect(goalsB, hasLength(2));
    });

    test('Family 4: Workout routine with nested days/exercises convergence and B01 legacy adapter sync', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // Device A creates routine with 2 days, each with exercises
      const routineHlc = HlcTimestamp(millis: 14000, counter: 0, nodeId: 'device-A');
      const routineMutation = SyncMutation(
        entityId: 'Upper Lower Split',
        domain: SyncDomain.programs,
        type: SyncMutationType.insert,
        hlc: routineHlc,
        payload: {
          'name': 'Upper Lower Split',
          'goal': 'Hypertrophy',
          'notes': '4 days per week',
          'days': [
            {
              'day_of_week': 1,
              'name': 'Upper Body',
              'is_rest_day': false,
              'exercises': [
                {'name': 'Barbell Bench Press', 'sets': 4, 'reps_range': '8-10'},
                {'name': 'Bent Over Row', 'sets': 4, 'reps_range': '8-10'},
              ],
            },
            {
              'day_of_week': 2,
              'name': 'Lower Body',
              'is_rest_day': false,
              'exercises': [
                {'name': 'Barbell Squat', 'sets': 4, 'reps_range': '6-8'},
              ],
            },
          ],
        },
      );
      await serviceA.recordRoutineMutation(routineMutation);
      await serviceA.triggerSync();

      // Device B pulls routine
      await serviceB.triggerSync();
      final routinesB = await dbB.select(dbB.workoutRoutines).get();
      expect(routinesB, hasLength(1));
      expect(routinesB.first.name, 'Upper Lower Split');

      final daysB = await (dbB.select(dbB.routineDays)..where((t) => t.routineId.equals(routinesB.first.id))).get();
      expect(daysB, hasLength(2));

      final exercisesB = await dbB.select(dbB.routineExercises).get();
      expect(exercisesB, hasLength(3));

      // Verify B01 legacy import compatibility adapter synced into Programs & ProgramVersions!
      final b01ProgramsB = await dbB.select(dbB.programs).get();
      expect(b01ProgramsB, isNotEmpty);
      final b01VersionsB = await dbB.select(dbB.programVersions).get();
      expect(b01VersionsB, isNotEmpty);
      expect(b01VersionsB.first.origin, 'legacyImport');

      // Delete routine
      const delRoutineHlc = HlcTimestamp(millis: 15000, counter: 0, nodeId: 'device-A');
      const delRoutineMutation = SyncMutation(
        entityId: 'Upper Lower Split',
        domain: SyncDomain.programs,
        type: SyncMutationType.delete,
        hlc: delRoutineHlc,
      );
      await serviceA.recordRoutineMutation(delRoutineMutation);
      await serviceA.triggerSync();

      await serviceB.triggerSync();
      expect(await dbB.select(dbB.workoutRoutines).get(), isEmpty);
      expect(await dbB.select(dbB.routineDays).get(), isEmpty);
      expect(await dbB.select(dbB.routineExercises).get(), isEmpty);
    });

    test('Family 4: Equipment profile with items convergence and cascade tombstone', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      const eqHlc = HlcTimestamp(millis: 16000, counter: 0, nodeId: 'device-A');
      const eqMutation = SyncMutation(
        entityId: 'eq_profile:garage-gym',
        domain: SyncDomain.programs,
        type: SyncMutationType.insert,
        hlc: eqHlc,
        payload: {
          'entity_type': 'equipment_profile',
          'name': 'Garage Gym',
          'default_weight_increment_kg': 2.5,
          'items': [
            {'equipment_code': 'barbell', 'is_available': true, 'weight_increment_kg': 2.5},
            {'equipment_code': 'pullup_bar', 'is_available': true},
          ],
        },
      );
      await serviceA.recordEquipmentProfileMutation(eqMutation);
      await serviceA.triggerSync();

      await serviceB.triggerSync();
      final profilesB = await dbB.select(dbB.equipmentProfiles).get();
      expect(profilesB, hasLength(1));
      expect(profilesB.first.id, 'garage-gym');
      expect(profilesB.first.name, 'Garage Gym');

      final itemsB = await (dbB.select(dbB.equipmentProfileItems)..where((t) => t.equipmentProfileId.equals('garage-gym'))).get();
      expect(itemsB, hasLength(2));

      // Tombstone deletion
      const delEqHlc = HlcTimestamp(millis: 17000, counter: 0, nodeId: 'device-A');
      const delEqMutation = SyncMutation(
        entityId: 'eq_profile:garage-gym',
        domain: SyncDomain.programs,
        type: SyncMutationType.delete,
        hlc: delEqHlc,
      );
      await serviceA.recordEquipmentProfileMutation(delEqMutation);
      await serviceA.triggerSync();

      await serviceB.triggerSync();
      expect(await dbB.select(dbB.equipmentProfiles).get(), isEmpty);
      expect(await dbB.select(dbB.equipmentProfileItems).get(), isEmpty);
    });

    test('Family 4: Bundled catalog program tombstone immunity guard', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // Seed catalog starter plan in Device B database
      await dbB.into(dbB.programs).insert(
            ProgramsCompanion.insert(
              id: 'offline-starter::beginner-full-body-3-day',
              name: 'Beginner — 3-Day Full Body',
              createdAtUtc: DateTime.utc(2026, 9, 1),
            ),
          );
      await dbB.into(dbB.programVersions).insert(
            ProgramVersionsCompanion.insert(
              id: 'offline-starter::beginner-full-body-3-day::v1',
              programId: 'offline-starter::beginner-full-body-3-day',
              versionNumber: 1,
              status: 'published',
              origin: const Value('user'),
              createdAtUtc: DateTime.utc(2026, 9, 1),
            ),
          );

      // Device A attempts to record and push a delete mutation for catalog plan
      const rogueDelHlc = HlcTimestamp(millis: 18000, counter: 0, nodeId: 'device-A');
      const rogueDelMutation = SyncMutation(
        entityId: 'offline-starter::beginner-full-body-3-day',
        domain: SyncDomain.programs,
        type: SyncMutationType.delete,
        hlc: rogueDelHlc,
      );

      // 1. Capture guard drops it before outbox
      await serviceA.recordLocalMutation(rogueDelMutation);
      expect(sharedRelay.totalStoredCount, 0);

      // 2. Even if a rogue relay carried the deletion directly:
      await sharedRelay.pushMutations([rogueDelMutation]);
      expect(sharedRelay.totalStoredCount, 1);

      // Device B pulls and applies deltas:
      await serviceB.triggerSync();

      // Verify the catalog program was NOT deleted on Device B
      final progB = await (dbB.select(dbB.programs)
            ..where((t) => t.id.equals('offline-starter::beginner-full-body-3-day')))
          .getSingleOrNull();
      expect(progB, isNotNull);
      expect(progB!.name, 'Beginner — 3-Day Full Body');
    });

    test('Family 4: UserProfiles 14-field convergence and SharedPreferences mirroring', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      const profileHlc = HlcTimestamp(millis: 19000, counter: 0, nodeId: 'device-A');
      const profileMutation = SyncMutation(
        entityId: 'user_profile',
        domain: SyncDomain.preferences,
        type: SyncMutationType.update,
        hlc: profileHlc,
        payload: {
          'entity_type': 'user_profile',
          'name': 'Rahul Sharma',
          'age': 28,
          'height': 175.5,
          'weight': 74.0,
          'sex': 'male',
          'activity_level': 'very_active',
          'goal': 'muscle_gain',
          'diet_preference': 'vegetarian',
          'calorie_goal': 2600,
          'protein_goal': 165.0,
          'carbs_goal': 320.0,
          'fat_goal': 70.0,
          'equipment_access': 'full_gym',
          'injuries_limitations': 'none',
        },
      );
      await serviceA.recordProfileMutation(profileMutation);
      await serviceA.triggerSync();

      await serviceB.triggerSync();
      final profilesB = await dbB.select(dbB.userProfiles).get();
      expect(profilesB, hasLength(1));
      expect(profilesB.first.name, 'Rahul Sharma');
      expect(profilesB.first.age, 28);
      expect(profilesB.first.height, 175.5);
      expect(profilesB.first.weight, 74.0);
      expect(profilesB.first.calorieGoal, 2600);
      expect(profilesB.first.proteinGoal, 165.0);

      // Verify SharedPreferences mirror
      expect(prefsB.getString('user_name'), 'Rahul Sharma');
      expect(prefsB.getInt('user_age'), 28);
      expect(prefsB.getDouble('user_height'), 175.5);
      expect(prefsB.getDouble('user_weight'), 74.0);
      expect(prefsB.getInt('calorie_goal'), 2600);
      expect(prefsB.getDouble('protein_goal'), 165.0);
    });

    test('Family 4: Settings allowlist enforcement (allowlisted keys converge; denylisted keys dropped)', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // 1. Allowlisted setting: display_units
      const unitHlc = HlcTimestamp(millis: 20000, counter: 0, nodeId: 'device-A');
      const unitMutation = SyncMutation(
        entityId: 'display_units',
        domain: SyncDomain.preferences,
        type: SyncMutationType.update,
        hlc: unitHlc,
        payload: {'key': 'display_units', 'value': 'Imperial'},
      );
      await serviceA.recordSettingMutation(unitMutation);

      // Allowlisted setting: water_goal
      const waterHlc = HlcTimestamp(millis: 20001, counter: 0, nodeId: 'device-A');
      const waterMutation = SyncMutation(
        entityId: 'water_goal',
        domain: SyncDomain.preferences,
        type: SyncMutationType.update,
        hlc: waterHlc,
        payload: {'key': 'water_goal', 'value': 10},
      );
      await serviceA.recordSettingMutation(waterMutation);

      // 2. Denylisted setting: notification reminder
      const reminderHlc = HlcTimestamp(millis: 20002, counter: 0, nodeId: 'device-A');
      const reminderMutation = SyncMutation(
        entityId: 'pref_remind_workout',
        domain: SyncDomain.preferences,
        type: SyncMutationType.update,
        hlc: reminderHlc,
        payload: {'key': 'pref_remind_workout', 'value': true},
      );
      await serviceA.recordSettingMutation(reminderMutation);

      // Device A pushes
      await serviceA.triggerSync();

      // Verify outbox / relay only got the 2 allowlisted keys
      expect(sharedRelay.totalStoredCount, 2);

      // Device B pulls
      await serviceB.triggerSync();

      // Device B receives allowlisted settings
      final settingUnits = await (dbB.select(dbB.userSettings)..where((t) => t.key.equals('display_units'))).getSingleOrNull();
      expect(settingUnits, isNotNull);
      expect(settingUnits!.value, 'Imperial');
      expect(prefsB.getString('display_units'), 'Imperial');

      final settingWater = await (dbB.select(dbB.userSettings)..where((t) => t.key.equals('water_goal'))).getSingleOrNull();
      expect(settingWater, isNotNull);
      expect(settingWater!.value, '10');
      expect(prefsB.getInt('water_goal'), 10);

      // Denylisted setting never made it to DB or prefs
      final settingReminder = await (dbB.select(dbB.userSettings)..where((t) => t.key.equals('pref_remind_workout'))).getSingleOrNull();
      expect(settingReminder, isNull);
    });

    test('Family 4: Achievement unlock earliest-wins and insert-only delete immunity', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // Device A unlocks badge at t = 2026-09-05
      const achHlcA = HlcTimestamp(millis: 21000, counter: 0, nodeId: 'device-A');
      const mutationA = SyncMutation(
        entityId: 'achievement:first_workout',
        domain: SyncDomain.preferences,
        type: SyncMutationType.insert,
        hlc: achHlcA,
        payload: {
          'entity_type': 'achievement',
          'achievement_id': 'first_workout',
          'unlocked_at': '2026-09-05T10:00:00Z',
        },
      );
      await serviceA.recordAchievementMutation(mutationA);
      await serviceA.triggerSync();

      // Device B already unlocked earlier at t = 2026-09-02 locally
      await dbB.into(dbB.achievementUnlocks).insert(
            AchievementUnlocksCompanion.insert(
              achievementId: 'first_workout',
              unlockedAt: Value(DateTime.parse('2026-09-02T08:00:00Z')),
            ),
          );

      // Device B pulls from Device A
      await serviceB.triggerSync();

      // Earliest timestamp wins: Device B keeps 2026-09-02
      var unlockB = await (dbB.select(dbB.achievementUnlocks)..where((t) => t.achievementId.equals('first_workout'))).getSingle();
      expect(unlockB.unlockedAt.toUtc(), DateTime.parse('2026-09-02T08:00:00Z'));

      // Device B pushes its earlier unlock to Device A
      const achHlcB = HlcTimestamp(millis: 22000, counter: 0, nodeId: 'device-B');
      const mutationB = SyncMutation(
        entityId: 'achievement:first_workout',
        domain: SyncDomain.preferences,
        type: SyncMutationType.insert,
        hlc: achHlcB,
        payload: {
          'entity_type': 'achievement',
          'achievement_id': 'first_workout',
          'unlocked_at': '2026-09-02T08:00:00Z',
        },
      );
      await serviceB.recordAchievementMutation(mutationB);
      await serviceB.triggerSync();

      await serviceA.triggerSync();
      var unlockA = await (dbA.select(dbA.achievementUnlocks)..where((t) => t.achievementId.equals('first_workout'))).getSingle();
      expect(unlockA.unlockedAt.toUtc(), DateTime.parse('2026-09-02T08:00:00Z'));

      // Delete immunity: Attempting to record or apply deletion is a no-op
      const delAchHlc = HlcTimestamp(millis: 23000, counter: 0, nodeId: 'device-A');
      const delAchMutation = SyncMutation(
        entityId: 'achievement:first_workout',
        domain: SyncDomain.preferences,
        type: SyncMutationType.delete,
        hlc: delAchHlc,
      );

      // Capture guard drops it:
      await serviceA.recordAchievementMutation(delAchMutation);

      // Direct relay injection drops it on apply:
      await sharedRelay.pushMutations([delAchMutation]);
      await serviceB.triggerSync();

      unlockB = await (dbB.select(dbB.achievementUnlocks)..where((t) => t.achievementId.equals('first_workout'))).getSingle();
      expect(unlockB, isNotNull); // Unaffected by deletion!
    });

    test('Family 3: Divergent autoincrement ID sequences for custom food prevent mismerge', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // Device B independently creates custom food at local id = 1: "Eggs Scrambled"
      final bFoodId = await dbB.into(dbB.foodItems).insert(
            FoodItemsCompanion.insert(
              name: 'Eggs Scrambled',
              calories: 180,
              proteinG: 12.0,
              carbsG: 2.0,
              fatG: 14.0,
              servingSize: 2.0,
              servingUnit: 'egg',
              category: 'breakfast',
              isCustom: const Value(true),
            ),
          );
      expect(bFoodId, isPositive);

      // Device A creates custom food at local id = 1: "Paneer Tikka"
      const foodHlc = HlcTimestamp(millis: 30000, counter: 0, nodeId: 'device-A');
      const mutationA = SyncMutation(
        entityId: 'cf-uuid-paneer',
        domain: SyncDomain.nutritionLogs,
        type: SyncMutationType.insert,
        hlc: foodHlc,
        payload: {
          'entity_type': 'custom_food',
          'uuid': 'cf-uuid-paneer',
          'name': 'Paneer Tikka',
          'calories': 260,
          'protein_g': 18.0,
          'carbs_g': 6.0,
          'fat_g': 19.0,
          'serving_size': 100.0,
          'serving_unit': 'g',
          'category': 'dinner',
        },
      );
      await serviceA.recordCustomFoodMutation(mutationA);
      await serviceA.triggerSync();

      // Device B pulls mutation from Device A
      await serviceB.triggerSync();

      // Device B now has BOTH foods: "Eggs Scrambled" at bFoodId, and "Paneer Tikka" as a separate row.
      // Row bFoodId ("Eggs Scrambled") was NOT overwritten!
      final foodsB = await (dbB.select(dbB.foodItems)..where((t) => t.isCustom.equals(true))).get();
      expect(foodsB, hasLength(2));

      final eggs = foodsB.firstWhere((f) => f.id == bFoodId);
      expect(eggs.name, 'Eggs Scrambled');
      expect(eggs.calories, 180);

      final paneer = foodsB.firstWhere((f) => f.name == 'Paneer Tikka');
      expect(paneer.id, isNot(bFoodId));
      expect(paneer.calories, 260);

      // Device A updates "Paneer Tikka"
      const updateHlc = HlcTimestamp(millis: 31000, counter: 0, nodeId: 'device-A');
      const updateMutation = SyncMutation(
        entityId: 'cf-uuid-paneer',
        domain: SyncDomain.nutritionLogs,
        type: SyncMutationType.update,
        hlc: updateHlc,
        payload: {
          'entity_type': 'custom_food',
          'uuid': 'cf-uuid-paneer',
          'name': 'Paneer Tikka',
          'calories': 280,
          'protein_g': 20.0,
          'carbs_g': 6.0,
          'fat_g': 21.0,
          'serving_size': 100.0,
          'serving_unit': 'g',
          'category': 'dinner',
        },
      );
      await serviceA.recordCustomFoodMutation(updateMutation);
      await serviceA.triggerSync();

      await serviceB.triggerSync();

      // Updates Paneer Tikka in place; Eggs Scrambled remains untouched
      final eggsAfter = await (dbB.select(dbB.foodItems)..where((t) => t.id.equals(bFoodId))).getSingle();
      expect(eggsAfter.name, 'Eggs Scrambled');
      expect(eggsAfter.calories, 180);

      final paneerAfter = await (dbB.select(dbB.foodItems)..where((t) => t.name.equals('Paneer Tikka'))).getSingle();
      expect(paneerAfter.calories, 280);
    });

    test('Family 3: Divergent autoincrement ID sequences for meal templates prevent mismerge via conjunctive id+name', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // Device B independently has meal template id = 1: "Quick Oatmeal"
      final bTplId = await dbB.into(dbB.mealTemplates).insert(
            MealTemplatesCompanion.insert(
              name: 'Quick Oatmeal',
              defaultMealType: const Value('breakfast'),
            ),
          );
      expect(bTplId, 1);
      await dbB.into(dbB.mealTemplateItems).insert(
            MealTemplateItemsCompanion.insert(
              templateId: 1,
              name: 'Oats',
              calories: 150,
              proteinG: 5.0,
              carbsG: 27.0,
              fatG: 3.0,
              servingLogged: 40.0,
              servingUnit: 'g',
            ),
          );

      // Device A sends meal template with id = 1 and name = "High Protein Lunch"
      const tplHlc = HlcTimestamp(millis: 32000, counter: 0, nodeId: 'device-A');
      const tplMutation = SyncMutation(
        entityId: '1:High Protein Lunch',
        domain: SyncDomain.nutritionRecipes,
        type: SyncMutationType.insert,
        hlc: tplHlc,
        payload: {
          'id': 1,
          'name': 'High Protein Lunch',
          'default_meal_type': 'lunch',
          'items': [
            {
              'name': 'Tofu Stir Fry',
              'calories': 200,
              'protein_g': 16.0,
              'carbs_g': 8.0,
              'fat_g': 12.0,
              'serving_logged': 150.0,
              'serving_unit': 'g',
            },
          ],
        },
      );
      await serviceA.recordMealTemplateMutation(tplMutation);
      await serviceA.triggerSync();

      // Device B pulls: conjunctive (id == 1 && name == 'High Protein Lunch') does NOT match 'Quick Oatmeal'
      // Inserts as new template at id = 2; row 1 is untouched!
      await serviceB.triggerSync();

      final templatesB = await dbB.select(dbB.mealTemplates).get();
      expect(templatesB, hasLength(2));

      final oatB = templatesB.firstWhere((t) => t.id == 1);
      expect(oatB.name, 'Quick Oatmeal');

      final lunchB = templatesB.firstWhere((t) => t.name == 'High Protein Lunch');
      expect(lunchB.id, isNot(1));

      // Device B's original template items are intact
      final oatItems = await (dbB.select(dbB.mealTemplateItems)..where((t) => t.templateId.equals(1))).get();
      expect(oatItems, hasLength(1));
      expect(oatItems.first.name, 'Oats');

      // Device A deletes "1:High Protein Lunch" (target id=1, name='High Protein Lunch')
      // Mismatch: id 1 on Device B is "Quick Oatmeal", so conjunctive delete does NOT delete id 1.
      const delTplHlc = HlcTimestamp(millis: 33000, counter: 0, nodeId: 'device-A');
      const delTplMutation = SyncMutation(
        entityId: '1:High Protein Lunch',
        domain: SyncDomain.nutritionRecipes,
        type: SyncMutationType.delete,
        hlc: delTplHlc,
      );
      await serviceA.recordMealTemplateMutation(delTplMutation);
      await serviceA.triggerSync();

      await serviceB.triggerSync();

      // "Quick Oatmeal" at id = 1 remains completely intact
      final oatStillThere = await (dbB.select(dbB.mealTemplates)..where((t) => t.id.equals(1))).getSingleOrNull();
      expect(oatStillThere, isNotNull);
      expect(oatStillThere!.name, 'Quick Oatmeal');
    });

    test('Family 4: Divergent autoincrement ID sequences for workout routines prevent mismerge via conjunctive id+name', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // Device B independently creates routine id = 1: "Leg Hypertrophy"
      final bRoutineId = await dbB.into(dbB.workoutRoutines).insert(
            WorkoutRoutinesCompanion.insert(
              name: 'Leg Hypertrophy',
              goal: 'hypertrophy',
              notes: const Value('Heavy squat focus'),
            ),
          );
      expect(bRoutineId, 1);

      // Device A sends routine with id = 1: "Upper Body Strength"
      const routineHlc = HlcTimestamp(millis: 34000, counter: 0, nodeId: 'device-A');
      const routineMutation = SyncMutation(
        entityId: '1:Upper Body Strength',
        domain: SyncDomain.programs,
        type: SyncMutationType.insert,
        hlc: routineHlc,
        payload: {
          'id': 1,
          'name': 'Upper Body Strength',
          'goal': 'strength',
          'days': [
            {
              'day_of_week': 1,
              'name': 'Bench Focus',
              'is_rest_day': false,
              'exercises': [
                {'name': 'Bench Press', 'sets': 5, 'reps_range': '5'},
              ],
            },
          ],
        },
      );
      await serviceA.recordRoutineMutation(routineMutation);
      await serviceA.triggerSync();

      // Device B pulls: conjunctive (id == 1 && name == 'Upper Body Strength') does not match 'Leg Hypertrophy'
      // Inserts as new routine at id = 2; row 1 is untouched!
      await serviceB.triggerSync();

      final routinesB = await dbB.select(dbB.workoutRoutines).get();
      expect(routinesB, hasLength(2));

      final legB = routinesB.firstWhere((r) => r.id == 1);
      expect(legB.name, 'Leg Hypertrophy');

      final upperB = routinesB.firstWhere((r) => r.name == 'Upper Body Strength');
      expect(upperB.id, isNot(1));

      // Device A deletes "1:Upper Body Strength"
      // Conjunctive match prevents deleting row 1 ("Leg Hypertrophy") on Device B
      const delRoutineHlc = HlcTimestamp(millis: 35000, counter: 0, nodeId: 'device-A');
      const delRoutineMutation = SyncMutation(
        entityId: '1:Upper Body Strength',
        domain: SyncDomain.programs,
        type: SyncMutationType.delete,
        hlc: delRoutineHlc,
      );
      await serviceA.recordRoutineMutation(delRoutineMutation);
      await serviceA.triggerSync();

      await serviceB.triggerSync();

      // "Leg Hypertrophy" at id = 1 remains completely intact
      final legStillThere = await (dbB.select(dbB.workoutRoutines)..where((t) => t.id.equals(1))).getSingleOrNull();
      expect(legStillThere, isNotNull);
      expect(legStillThere!.name, 'Leg Hypertrophy');
    });

    test('Family 4: Non-delete catalog program mutation is rejected and creates no garbage routines', () async {
      final sharedRelay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = SyncService(
        db: dbA,
        prefs: prefsA,
        account: _FakeAccount(nodeId: 'device-A'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-A',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = SyncService(
        db: dbB,
        prefs: prefsB,
        account: _FakeAccount(nodeId: 'device-B'),
        network: TestableNetworkCapability(initialConnected: true),
        outbox: InMemoryOutboxRepository(),
        apiClient: sharedRelay,
        deviceId: 'device-B',
      );

      // Attempt capture of a write mutation targeting an offline-starter catalog ID
      const catHlc = HlcTimestamp(millis: 36000, counter: 0, nodeId: 'device-A');
      const catMutation = SyncMutation(
        entityId: 'offline-starter::strength-foundations',
        domain: SyncDomain.programs,
        type: SyncMutationType.insert,
        hlc: catHlc,
        payload: {
          'name': 'Tampered Starter Plan',
          'goal': 'strength',
        },
      );
      await serviceA.recordLocalMutation(catMutation);
      await serviceA.triggerSync();

      // Directly inject into shared relay to simulate a malicious or rogue peer
      await sharedRelay.pushMutations([catMutation]);

      // Device B pulls
      await serviceB.triggerSync();

      // Verify no garbage routines or programs were created
      final routinesB = await dbB.select(dbB.workoutRoutines).get();
      expect(routinesB, isEmpty);

      final matchingRoutines = await (dbB.select(dbB.workoutRoutines)
            ..where((t) => t.name.contains('offline-starter') | t.name.contains('Tampered')))
          .get();
      expect(matchingRoutines, isEmpty);
    });
  });
}
