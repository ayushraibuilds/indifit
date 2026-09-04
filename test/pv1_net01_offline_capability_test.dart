import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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

      const catalogue = DisabledFoodCatalogCapability();
      final page = await catalogue.searchRemoteFoods('apple');
      expect(page.items, isEmpty);
      expect(await catalogue.lookupByBarcode('123456789'), isNull);

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

    test('markSucceeded clears stale lastError', () async {
      final repo = InMemoryOutboxRepository();
      addTearDown(repo.dispose);

      final now = DateTime.now().toUtc();
      await repo.enqueue(OutboxOperation(
        operationId: 'op-err-clear',
        idempotencyKey: 'k-err-clear',
        domain: OutboxDomain.food,
        action: 'log',
        entityId: 'e1',
        payload: const {},
        createdAtUtc: now,
        scheduledAtUtc: now,
      ));
      await repo.markInFlight('op-err-clear');
      await repo.markFailed('op-err-clear', error: 'boom', isRetryable: true);
      var op = await repo.getOperationById('op-err-clear');
      expect(op!.lastError, 'boom');

      await repo.markSucceeded('op-err-clear');
      op = await repo.getOperationById('op-err-clear');
      expect(op!.state, OutboxState.succeeded);
      expect(op.lastError, isNull);
    });

    test('Terminal entries do not block re-enqueue; operationId never overwritten', () async {
      final repo = InMemoryOutboxRepository();
      addTearDown(repo.dispose);

      final now = DateTime.now().toUtc();
      OutboxOperation build(String opId, String key) => OutboxOperation(
            operationId: opId,
            idempotencyKey: key,
            domain: OutboxDomain.food,
            action: 'log',
            entityId: 'e1',
            payload: const {},
            createdAtUtc: now,
            scheduledAtUtc: now,
          );

      await repo.enqueue(build('op-a', 'same-key'));
      await repo.markSucceeded('op-a');

      // Same logical key after terminal success is accepted again.
      await repo.enqueue(build('op-b', 'same-key'));
      expect(await repo.getOperationById('op-b'), isNotNull);

      // Same operationId with different content never overwrites the row.
      await repo.enqueue(build('op-a', 'different-key'));
      final original = await repo.getOperationById('op-a');
      expect(original!.idempotencyKey, 'same-key');
      expect(original.state, OutboxState.succeeded);
    });

    test('cancel drops pending work; prune uses completion time', () async {
      final repo = InMemoryOutboxRepository();
      addTearDown(repo.dispose);

      final now = DateTime.now().toUtc();
      final eightDaysAgo = now.subtract(const Duration(days: 8));
      OutboxOperation build(String opId, DateTime created) => OutboxOperation(
            operationId: opId,
            idempotencyKey: 'k-$opId',
            domain: OutboxDomain.plan,
            action: 'sync',
            entityId: opId,
            payload: const {},
            createdAtUtc: created,
            scheduledAtUtc: created,
          );

      // Cancelled op leaves the pending set.
      await repo.enqueue(build('op-cancel', now));
      await repo.cancel('op-cancel');
      expect(
        (await repo.getPendingOperations()).any((o) => o.operationId == 'op-cancel'),
        isFalse,
      );

      // Old creation but recent completion is retained (7d retention).
      await repo.enqueue(build('op-recent-done', eightDaysAgo));
      await repo.markSucceeded('op-recent-done');

      // Old creation AND old completion is pruned.
      await repo.enqueue(OutboxOperation(
        operationId: 'op-old-done',
        idempotencyKey: 'k-op-old-done',
        domain: OutboxDomain.plan,
        action: 'sync',
        entityId: 'op-old-done',
        payload: const {},
        createdAtUtc: eightDaysAgo,
        scheduledAtUtc: eightDaysAgo,
        state: OutboxState.succeeded,
        lastAttemptUtc: eightDaysAgo,
      ));

      final pruned = await repo.pruneCompleted(olderThan: const Duration(days: 7));
      expect(pruned, 1);
      expect(await repo.getOperationById('op-old-done'), isNull);
      expect(await repo.getOperationById('op-recent-done'), isNotNull);
    });

    test('watchPendingCount replays the current count to new subscribers', () async {
      final repo = InMemoryOutboxRepository();
      addTearDown(repo.dispose);

      final now = DateTime.now().toUtc();
      for (var i = 0; i < 2; i++) {
        await repo.enqueue(OutboxOperation(
          operationId: 'op-w-$i',
          idempotencyKey: 'k-w-$i',
          domain: OutboxDomain.weight,
          action: 'sync',
          entityId: '$i',
          payload: const {},
          createdAtUtc: now,
          scheduledAtUtc: now,
        ));
      }

      // New subscriber immediately sees the current count (no silent drop).
      expect(await repo.watchPendingCount().first, 2);

      await repo.markSucceeded('op-w-0');
      expect(await repo.watchPendingCount().first, 1);
    });

    test('fromJson refuses to resurrect corrupt rows', () {
      Map<String, dynamic> base() => {
            'operationId': 'op-x',
            'idempotencyKey': 'k-x',
            'domain': 'food',
            'action': 'log',
            'entityId': 'e',
            'payload': <String, dynamic>{},
            'createdAtUtc': '2026-09-03T00:00:00.000Z',
            'scheduledAtUtc': '2026-09-03T00:00:00.000Z',
            'state': 'pending',
            'attemptCount': 0,
          };

      final unknownDomain = base()..['domain'] = 'teleportation';
      expect(() => OutboxOperation.fromJson(unknownDomain), throwsFormatException);

      final unknownState = base()..['state'] = 'vibing';
      expect(() => OutboxOperation.fromJson(unknownState), throwsFormatException);

      final missingField = base()..remove('entityId');
      expect(() => OutboxOperation.fromJson(missingField), throwsFormatException);

      // Round-trip of a valid row still works.
      expect(OutboxOperation.fromJson(base()).operationId, 'op-x');
    });

    test('Retry policy honors sub-second delays deterministically', () {
      const policy = OutboxRetryPolicy(
        initialDelay: Duration(milliseconds: 1500),
        backoffMultiplier: 2.0,
        jitterFraction: 0.0,
      );
      // 1500ms base honoured at ms precision (old code truncated to 1s via
      // inSeconds). The 1s floor only applies to sub-second totals.
      expect(
        policy.computeDelay(1, random: math.Random(42)),
        const Duration(milliseconds: 1500),
      );
      expect(
        policy.computeDelay(2, random: math.Random(42)),
        const Duration(milliseconds: 3000),
      );
      // Seeded RNG makes the delay reproducible.
      expect(
        const OutboxRetryPolicy().computeDelay(1, random: math.Random(7)),
        const OutboxRetryPolicy().computeDelay(1, random: math.Random(7)),
      );
      // Typed transient failures retry; 500 stays permanent by design.
      expect(policy.isRetryable(TimeoutException('t')), isTrue);
      expect(policy.isRetryable('408 Request Timeout'), isTrue);
      expect(policy.isRetryable('500 Internal Server Error'), isFalse);
    });

    test('TestableNetworkCapability gates wifi policy and offline fail-closed', () {
      final network = TestableNetworkCapability(initialConnected: true);
      expect(network.canExecuteOperation(), isTrue);
      expect(network.canExecuteOperation(requireWifi: true), isTrue);

      network.setConnected(true, NetworkTransportType.cellular);
      expect(network.canExecuteOperation(), isTrue);
      expect(network.canExecuteOperation(requireWifi: true), isFalse);

      // Failing-adapter injection: offline blocks dispatch without gating reads.
      network.setConnected(false);
      expect(network.isConnected, isFalse);
      expect(network.canExecuteOperation(), isFalse);
      expect(network.canExecuteOperation(requireWifi: true), isFalse);
    });

    test('NoOpAccountCapability honors an injected device id', () async {
      const account = NoOpAccountCapability(defaultDeviceId: 'device-xyz');
      expect(await account.deviceId, 'device-xyz');
      expect(await account.isAuthenticated, isFalse);
    });

    test('ConnectedStatusState copyWith clears optional fields; pending(0) is singular', () {
      const state = ConnectedStatusState(
        status: ConnectedStatus.pending,
        pendingOperationsCount: 2,
        customMessage: 'stale',
        lastSuccessUtc: null,
      );
      final cleared = state.copyWith(clearCustomMessage: true);
      expect(cleared.customMessage, isNull);
      expect(cleared.pendingOperationsCount, 2);

      const zero = ConnectedStatusState.pending(count: 0);
      expect(zero.displayMessage, '1 update waiting to sync');
    });
  });
}
