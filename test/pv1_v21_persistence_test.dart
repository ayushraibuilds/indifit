import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/capabilities/sync_capability.dart';
import 'package:indifit/core/catalog/food_catalog_models.dart';
import 'package:indifit/core/catalog/food_catalog_service.dart';
import 'package:indifit/core/catalog/remote_food_cache_store.dart';
import 'package:indifit/core/outbox/outbox.dart';
import 'package:indifit/core/sync/hlc_timestamp.dart';
import 'package:indifit/core/sync/sync_mutation.dart';
import 'package:indifit/core/sync/sync_tombstone_store.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/repositories/food_api_service.dart';

import 'support/indifit_test_harness.dart';

class _CountingFoodApiService extends FoodApiService {
  _CountingFoodApiService({this.barcodeProduct});

  final FoodApiResult? barcodeProduct;
  int remoteCalls = 0;

  @override
  Future<List<FoodApiResult>> searchOnline(String query, {dynamic cancelToken}) async {
    remoteCalls++;
    return const [];
  }

  @override
  Future<FoodApiResult?> fetchByBarcode(String barcode) async {
    remoteCalls++;
    return barcodeProduct;
  }
}

RemoteFoodCandidate _candidate(String id, String barcode) => RemoteFoodCandidate(
      id: id,
      provider: FoodCatalogProvider.openFoodFacts,
      providerId: barcode,
      name: 'Test Food $id',
      barcode: barcode,
      category: 'general',
      caloriesPer100g: 100.0,
      proteinPer100g: 5.0,
      carbsPer100g: 10.0,
      fatPer100g: 2.0,
      servingOptions: const [
        ServingOption(unitName: '100g', gramWeight: 100.0, isDefault: true),
      ],
      provenance: FoodProvenance(
        provider: FoodCatalogProvider.openFoodFacts,
        attributionText: 'Source: Open Food Facts (ODbL)',
        license: 'ODbL',
        fetchedAtUtc: DateTime.utc(2026, 9, 4),
      ),
    );

OutboxOperation _op(String id, String key, {DateTime? at}) {
  final now = at ?? DateTime.now().toUtc();
  return OutboxOperation(
    operationId: id,
    idempotencyKey: key,
    domain: OutboxDomain.backup,
    action: 'upload_snapshot',
    entityId: id,
    payload: const {'a': 1},
    createdAtUtc: now,
    scheduledAtUtc: now,
  );
}

void main() {
  initializeIndiFitTestHarness();

  group('PV1-V21: Drift outbox repository (durable spool)', () {
    test('Lifecycle round-trips through SQLite', () async {
      final db = registerTestDatabaseScope().create();
      final repo = DriftOutboxRepository(db);

      await repo.enqueue(_op('op-1', 'k-1'));
      expect(await repo.getPendingOperations(), hasLength(1));

      await repo.markInFlight('op-1');
      var op = await repo.getOperationById('op-1');
      expect(op!.state, OutboxState.inFlight);
      expect(op.attemptCount, 1);

      await repo.markFailed('op-1', error: 'nope', isRetryable: true);
      op = await repo.getOperationById('op-1');
      expect(op!.state, OutboxState.transientFailure);
      expect(op.lastError, 'nope');

      await repo.markSucceeded('op-1');
      op = await repo.getOperationById('op-1');
      expect(op!.state, OutboxState.succeeded);
      expect(op.lastError, isNull);
    });

    test('Rows survive repository recreation on the same database', () async {
      final db = registerTestDatabaseScope().create();
      await DriftOutboxRepository(db).enqueue(_op('op-x', 'k-x'));

      // A new repository object over the same database sees the row:
      // this is the process-death survival property the in-memory
      // implementation cannot provide.
      final reopened = DriftOutboxRepository(db);
      expect(await reopened.getPendingOperations(), hasLength(1));
      expect(
        await reopened.watchPendingCount().first,
        1,
      );
    });

    test('Stale inFlight rows become redeliverable after the lease', () async {
      final db = registerTestDatabaseScope().create();
      final repo = DriftOutboxRepository(db);
      final now = DateTime.now().toUtc();
      OutboxOperation build(String id, DateTime attempt) => OutboxOperation(
            operationId: id,
            idempotencyKey: 'k-$id',
            domain: OutboxDomain.backup,
            action: 'upload_snapshot',
            entityId: id,
            payload: const {},
            createdAtUtc: attempt,
            scheduledAtUtc: attempt,
            state: OutboxState.inFlight,
            lastAttemptUtc: attempt,
          );

      // Pre-crash dispatch stuck 20 minutes ago.
      await repo.enqueue(build('op-stuck', now.subtract(const Duration(minutes: 20))));
      // Live dispatch inside its lease.
      await repo.enqueue(build('op-live', now));

      final pending = await repo.getPendingOperations();
      expect(pending.map((o) => o.operationId), contains('op-stuck'));
      expect(pending.map((o) => o.operationId), isNot(contains('op-live')));
    });

    test('Dedup, cancel, and completion-time prune match the contract', () async {
      final db = registerTestDatabaseScope().create();
      final repo = DriftOutboxRepository(db);
      final now = DateTime.now().toUtc();

      await repo.enqueue(_op('op-a', 'same'));
      await repo.markSucceeded('op-a');
      await repo.enqueue(_op('op-b', 'same'));
      expect(await repo.getOperationById('op-b'), isNotNull);

      await repo.enqueue(_op('op-a', 'other-key'));
      expect((await repo.getOperationById('op-a'))!.idempotencyKey, 'same');

      await repo.enqueue(_op('op-c', 'k-c'));
      await repo.cancel('op-c');
      expect(
        (await repo.getPendingOperations()).any((o) => o.operationId == 'op-c'),
        isFalse,
      );

      final old = now.subtract(const Duration(days: 8));
      await repo.enqueue(_op('op-old', 'k-old', at: old));
      await repo.markSucceeded('op-old');
      // Backdate completion to prove prune uses completion, not creation.
      await (db.update(db.outboxEntries)
            ..where((t) => t.operationId.equals('op-old')))
          .write(OutboxEntriesCompanion(lastAttemptUtc: Value(old)));
      expect(await repo.pruneCompleted(olderThan: const Duration(days: 7)), 1);
      expect(await repo.getOperationById('op-old'), isNull);
    });
  });

  group('PV1-V21: Tombstone store (persistent anti-resurrection)', () {
    test('Newest tombstone wins; extinction check follows HLC', () async {
      final db = registerTestDatabaseScope().create();
      final store = DriftSyncTombstoneStore(db);
      const hlc1 = HlcTimestamp(millis: 1000, counter: 0, nodeId: 'a');
      const hlc2 = HlcTimestamp(millis: 2000, counter: 0, nodeId: 'a');

      await store.recordTombstone(SyncTombstone(
        entityId: 'e1',
        domain: SyncDomain.workouts,
        deletedAtHlc: hlc1,
        createdAtUtc: DateTime.utc(2026, 9, 4),
      ));
      // Older tombstone never regresses the stored HLC.
      await store.recordTombstone(SyncTombstone(
        entityId: 'e1',
        domain: SyncDomain.workouts,
        deletedAtHlc: const HlcTimestamp(millis: 500, counter: 0, nodeId: 'a'),
        createdAtUtc: DateTime.utc(2026, 9, 4),
      ));
      var stored = await store.getTombstone('e1', SyncDomain.workouts);
      expect(stored!.deletedAtHlc, hlc1);

      expect(await store.isExtinguished('e1', SyncDomain.workouts, hlc1), isTrue);
      expect(
        await store.isExtinguished(
          'e1',
          SyncDomain.workouts,
          const HlcTimestamp(millis: 1500, counter: 0, nodeId: 'a'),
        ),
        isFalse,
      );

      await store.recordTombstone(SyncTombstone(
        entityId: 'e1',
        domain: SyncDomain.workouts,
        deletedAtHlc: hlc2,
        createdAtUtc: DateTime.utc(2026, 9, 4),
      ));
      stored = await store.getTombstone('e1', SyncDomain.workouts);
      expect(stored!.deletedAtHlc, hlc2);
    });

    test('Expired tombstones compact after retention', () async {
      final db = registerTestDatabaseScope().create();
      final store = DriftSyncTombstoneStore(db);
      await store.recordTombstone(SyncTombstone(
        entityId: 'old',
        domain: SyncDomain.weights,
        deletedAtHlc: const HlcTimestamp(millis: 1, counter: 0, nodeId: 'a'),
        createdAtUtc: DateTime.now().toUtc().subtract(const Duration(days: 40)),
      ));
      expect(await store.pruneExpired(), 1);
      expect(await store.getTombstone('old', SyncDomain.weights), isNull);
    });
  });

  group('PV1-V21: Tier-1 food cache (TTL + offline reuse)', () {
    test('Barcode reuse without network; stale rows fail closed', () async {
      final db = registerTestDatabaseScope().create();
      final store = DriftRemoteFoodCacheStore(db);

      await store.putCandidate(_candidate('off_1', '111'));
      expect((await store.getByBarcode('111'))!.id, 'off_1');

      // Stale fixture evicts on read (14d TTL).
      await store.putCandidate(
        _candidate('off_old', '222'),
        fetchedAtUtc: DateTime.now().toUtc().subtract(const Duration(days: 20)),
      );
      expect(await store.getByBarcode('222'), isNull);
      expect(await store.getCandidate('off_old'), isNull);

      // Corrupt JSON evicts instead of throwing.
      await db.into(db.cachedRemoteFoods).insert(
            CachedRemoteFoodsCompanion.insert(
              candidateId: 'off_broken',
              candidateJson: 'not-json{{{',
            ),
          );
      expect(await store.getCandidate('off_broken'), isNull);

      expect(await store.pruneStale(), 0);
    });

    test('Catalog service reuses persistent cache across instances', () async {
      final db = registerTestDatabaseScope().create();
      final api = _CountingFoodApiService(
        barcodeProduct: FoodApiResult(
          name: 'Persisted Milk',
          calories: 60.0,
          protein: 3.0,
          carbs: 5.0,
          fat: 3.0,
          servingSize: 100.0,
          servingUnit: 'ml',
          barcode: '333',
          providerId: '333',
        ),
      );
      // First instance resolves remotely and persists.
      final first = FoodCatalogService(
        foodApiService: api,
        persistentCache: DriftRemoteFoodCacheStore(db),
      );
      final resolved = await first.lookupByBarcode('333');
      expect(resolved, isNotNull);
      expect(api.remoteCalls, 1);

      // A fresh instance over the same database answers from SQLite
      // with zero network calls (restart survival).
      final second = FoodCatalogService(
        foodApiService: api,
        persistentCache: DriftRemoteFoodCacheStore(db),
      );
      final reused = await second.lookupByBarcode('333');
      expect(reused, isNotNull);
      expect(reused!.name, 'Persisted Milk');
      expect(api.remoteCalls, 1);
      expect(
        (await second.getRecentCachedCandidates()).map((c) => c.id),
        contains('off_333'),
      );
    });
  });

  group('PV1-V21: v20 to v21 migration', () {
    test('Upgrade creates connected-work tables and preserves rows', () async {
      final dir = Directory.systemTemp.createTempSync('indifit-v20-to-v21-');
      try {
        final file = File('${dir.path}/v20.db');

        // Build a genuine v20 on-disk file: fresh create, one user row in an
        // untouched table, then remove the v21 tables and stamp version 20.
        final v20 = AppDatabase.executor(NativeDatabase(file));
        try {
          await v20.customSelect('SELECT 1').get();
          await v20.into(v20.foodLogs).insert(
                FoodLogsCompanion.insert(
                  name: 'Migration Marker Dal',
                  calories: 100,
                  proteinG: 5.0,
                  carbsG: 10.0,
                  fatG: 2.0,
                  servingLogged: 1.0,
                  servingUnit: 'katori',
                  mealType: 'lunch',
                ),
              );
          await v20.customStatement('DROP TABLE outbox_entries');
          await v20.customStatement('DROP TABLE tombstone_entries');
          await v20.customStatement('DROP TABLE cached_remote_foods');
          await v20.customStatement('PRAGMA user_version = 20');
        } finally {
          await v20.close();
        }

        // Reopen: onUpgrade must run the v21 step and nothing else destructive.
        final migrated = AppDatabase.executor(NativeDatabase(file));
        try {
          await migrated.customSelect('SELECT 1').get();
          final version = await migrated
              .customSelect('PRAGMA user_version')
              .getSingle();
          expect(version.read<int>('user_version'), 21);
          for (final table in [
            'outbox_entries',
            'tombstone_entries',
            'cached_remote_foods'
          ]) {
            final found = await migrated
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'",
                )
                .get();
            expect(found, hasLength(1), reason: 'missing $table');
          }
          // Pre-existing user data survives the upgrade.
          final logs = await migrated.select(migrated.foodLogs).get();
          expect(logs.map((l) => l.name), contains('Migration Marker Dal'));
          // New tables accept writes immediately after upgrade.
          await DriftOutboxRepository(migrated).enqueue(
            _op('op-post-migrate', 'k-post-migrate'),
          );
          expect(
            await DriftOutboxRepository(migrated).getPendingOperations(),
            hasLength(1),
          );
        } finally {
          await migrated.close();
        }
      } finally {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });
  });
}
