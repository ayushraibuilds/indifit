import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/capabilities/capabilities_registry.dart';
import 'package:indifit/core/outbox/outbox.dart';
import 'package:indifit/data/repositories/food_repository.dart';
import 'package:indifit/data/repositories/plan_library_read_repository.dart';
import 'package:indifit/data/repositories/program_repository.dart';

import 'support/indifit_test_harness.dart';

void main() {
  initializeIndiFitTestHarness();

  group('PV1-NET-01: Offline-Core Matrix & Capability Isolation', () {
    test(
      'Core domain operations execute offline with zero network dependency',
      () async {
        final scope = registerTestDatabaseScope();
        final db = scope.create();
        final foodRepo = FoodRepository(db);
        final programRepo = ProgramRepository(db);

        // Exercise core local food write
        final entryId = await foodRepo.logFoodEntry(
          name: 'Offline Banana',
          calories: 105,
          proteinG: 1.3,
          carbsG: 27.0,
          fatG: 0.3,
          servingLogged: 1,
          servingUnit: 'medium',
          mealType: 'snack',
        );
        expect(entryId, greaterThan(0));

        final logs = await db.select(db.foodLogs).get();
        expect(logs, hasLength(1));
        expect(logs.first.name, 'Offline Banana');

        // Exercise core local plan library read
        final library = await PlanLibraryReadRepository(
          db,
          programs: programRepo,
        ).read();
        expect(library.entries, hasLength(8));
      },
    );

    test('All default capability drivers provide safe offline fallbacks', () async {
      const account = NoOpAccountCapability();
      expect(await account.isAuthenticated, isFalse);
      expect(await account.currentUserId, isNull);
      expect(await account.deviceId, isNotEmpty);

      const network = OfflineNetworkCapability();
      expect(network.isConnected, isFalse);
      expect(network.canExecuteOperation(), isFalse);

      const backup = DisabledCloudBackupCapability();
      final backupStatus = await backup.getStatus();
      expect(backupStatus.status, ConnectedStatus.neverConfigured);
      expect(backupStatus.canPerformLocalActions, isTrue);

      const sync = DisabledSyncCapability();
      final syncStatus = await sync.getStatus();
      expect(syncStatus.status, ConnectedStatus.neverConfigured);

      const catalogue = DisabledRemoteCatalogueCapability();
      expect(catalogue.isAvailable, isFalse);
      expect(await catalogue.searchFoods('apple'), isEmpty);
      expect(await catalogue.lookupBarcode('123456789'), isNull);

      const download = DisabledContentDownloadCapability();
      expect(download.isConfigured, isFalse);
      expect(
        await download.downloadAsset(
          assetId: '1',
          sourceUrl: 'https://example.com/asset.png',
          localDestinationPath: '/tmp/test.png',
        ),
        isFalse,
      );

      const ai = DisabledAiAssistanceCapability();
      expect(ai.isEnabled, isFalse);
      final aiResult = await ai.parseMealDescription('2 eggs and toast');
      expect(aiResult.success, isFalse);

      const integration = DisabledIntegrationCapability();
      expect(
        await integration.isAuthorized(IntegrationPlatform.appleHealth),
        isFalse,
      );

      const diagnostics = NoOpDiagnosticsCapability();
      expect(diagnostics.isEnabled, isFalse);

      const entitlement = FullLocalEntitlementCapability();
      expect(entitlement.isFeatureAccessible('any_feature'), isTrue);
    });

    test('Status tokens provide user-friendly copy without implementation jargon', () {
      final forbiddenTerms = ['drift', 'sqlite', 'uuid', 'exception', 'error_code', 'table'];

      for (final status in ConnectedStatus.values) {
        final state = ConnectedStatusState(
          status: status,
          pendingOperationsCount: 3,
        );

        // Crucial invariant: local actions are ALWAYS permitted
        expect(state.canPerformLocalActions, isTrue);

        final message = state.displayMessage.toLowerCase();
        for (final forbidden in forbiddenTerms) {
          expect(
            message.contains(forbidden),
            isFalse,
            reason: 'Display copy "$message" contains internal term "$forbidden"',
          );
        }
      }
    });

    test('ConnectedStatusState correctly describes singular vs plural pending updates', () {
      const singular = ConnectedStatusState.pending(count: 1);
      expect(singular.displayMessage, '1 update waiting to sync');

      const plural = ConnectedStatusState.pending(count: 5);
      expect(plural.displayMessage, '5 updates waiting to sync');

      const offlineWithPending = ConnectedStatusState.offline(pendingCount: 4);
      expect(offlineWithPending.displayMessage, 'Offline — updates will sync when connected');

      const offlineClean = ConnectedStatusState.offline(pendingCount: 0);
      expect(offlineClean.displayMessage, 'Offline');
    });
  });

  group('PV1-NET-01: Durable Outbox State Machine & Retry Policy', () {
    test('Outbox operation records lifecycle transitions cleanly', () async {
      final repo = InMemoryOutboxRepository(
        retryPolicy: const OutboxRetryPolicy(
          initialDelay: Duration(seconds: 1),
          backoffMultiplier: 2.0,
          maxAttempts: 3,
        ),
      );
      addTearDown(repo.dispose);

      final now = DateTime.now().toUtc();
      final op = OutboxOperation(
        operationId: 'op-001',
        idempotencyKey: 'workout:session-123:sync',
        domain: OutboxDomain.workout,
        action: 'sync_session',
        entityId: 'session-123',
        payload: {'reps': 10, 'weight': 80},
        createdAtUtc: now,
        scheduledAtUtc: now,
      );

      await repo.enqueue(op);
      var pending = await repo.getPendingOperations();
      expect(pending, hasLength(1));
      expect(pending.first.state, OutboxState.pending);

      // Transition to in-flight
      await repo.markInFlight('op-001');
      var updated = await repo.getOperationById('op-001');
      expect(updated!.state, OutboxState.inFlight);
      expect(updated.attemptCount, 1);

      // Transient failure should schedule backoff retry
      await repo.markFailed(
        'op-001',
        error: 'SocketException: Connection refused',
        isRetryable: true,
      );
      updated = await repo.getOperationById('op-001');
      expect(updated!.state, OutboxState.transientFailure);
      expect(updated.lastError, contains('Connection refused'));
      expect(updated.scheduledAtUtc.isAfter(now), isTrue);

      // Success transitions to terminal succeeded
      await repo.markSucceeded('op-001');
      updated = await repo.getOperationById('op-001');
      expect(updated!.state, OutboxState.succeeded);
      expect(updated.isTerminal, isTrue);
    });

    test('Outbox deduplicates identical idempotency keys', () async {
      final repo = InMemoryOutboxRepository();
      addTearDown(repo.dispose);

      final now = DateTime.now().toUtc();
      final op1 = OutboxOperation(
        operationId: 'op-101',
        idempotencyKey: 'food:entry-999:log',
        domain: OutboxDomain.food,
        action: 'log',
        entityId: '999',
        payload: {'calories': 200},
        createdAtUtc: now,
        scheduledAtUtc: now,
      );

      final op2 = OutboxOperation(
        operationId: 'op-102',
        idempotencyKey: 'food:entry-999:log', // Same idempotency key!
        domain: OutboxDomain.food,
        action: 'log',
        entityId: '999',
        payload: {'calories': 200},
        createdAtUtc: now,
        scheduledAtUtc: now,
      );

      await repo.enqueue(op1);
      await repo.enqueue(op2);

      final pending = await repo.getPendingOperations();
      expect(pending, hasLength(1));
      expect(pending.first.operationId, 'op-101');
    });

    test('Outbox retry policy differentiates transient from permanent errors', () {
      const policy = OutboxRetryPolicy();

      // Transient errors
      expect(policy.isRetryable(const SocketException('Host not found')), isTrue);
      expect(policy.isRetryable(const HttpException('503 Service Unavailable')), isTrue);
      expect(policy.isRetryable('TimeoutException after 0:00:10.000000'), isTrue);

      // Permanent errors
      expect(policy.isRetryable(const FormatException('Unexpected token')), isFalse);
      expect(policy.isRetryable('400 Bad Request: Malformed JSON payload'), isFalse);
      expect(policy.isRetryable('401 Unauthorized: Session revoked'), isFalse);
    });

    test('Exhausted attempts transition to permanent failure', () async {
      final repo = InMemoryOutboxRepository(
        retryPolicy: const OutboxRetryPolicy(maxAttempts: 2),
      );
      addTearDown(repo.dispose);

      final now = DateTime.now().toUtc();
      final op = OutboxOperation(
        operationId: 'op-max-retry',
        idempotencyKey: 'weight:log-1:sync',
        domain: OutboxDomain.weight,
        action: 'sync',
        entityId: '1',
        payload: {'kg': 75.0},
        createdAtUtc: now,
        scheduledAtUtc: now,
      );

      await repo.enqueue(op);

      // Attempt 1
      await repo.markInFlight('op-max-retry');
      await repo.markFailed('op-max-retry', error: 'Timeout', isRetryable: true);
      var current = await repo.getOperationById('op-max-retry');
      expect(current!.state, OutboxState.transientFailure);

      // Attempt 2 (reaches maxAttempts: 2)
      await repo.markInFlight('op-max-retry');
      await repo.markFailed('op-max-retry', error: 'Timeout again', isRetryable: true);
      current = await repo.getOperationById('op-max-retry');
      expect(current!.state, OutboxState.permanentFailure);
      expect(current.isTerminal, isTrue);
    });
  });
}
