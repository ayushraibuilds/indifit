import 'dart:async';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../capabilities/account_capability.dart';
import '../capabilities/connected_status.dart';
import '../capabilities/network_capability.dart';
import '../capabilities/sync_capability.dart';
import '../outbox/outbox_operation.dart';
import '../outbox/outbox_repository.dart';
import 'hlc_timestamp.dart';
import 'sync_api_client.dart';
import 'sync_conflict_resolver.dart';
import 'sync_mutation.dart';
import 'sync_tombstone_store.dart';

/// Central synchronization engine implementing [SyncCapability].
class SyncService implements SyncCapability {
  SyncService({
    required AppDatabase db,
    required SharedPreferences prefs,
    required AccountCapability account,
    required NetworkCapability network,
    required OutboxRepository outbox,
    required SyncApiClient apiClient,
    SyncConflictResolver conflictResolver = const SyncConflictResolver(),
    DriftSyncTombstoneStore? tombstones,
    this.deviceId,
  })  : _db = db,
        _prefs = prefs,
        _account = account,
        _network = network,
        _outbox = outbox,
        _apiClient = apiClient,
        _conflictResolver = conflictResolver,
        _tombstones = tombstones ?? DriftSyncTombstoneStore(db);

  final AppDatabase _db;
  final SharedPreferences _prefs;
  final AccountCapability _account;
  final NetworkCapability _network;
  final OutboxRepository _outbox;
  final SyncApiClient _apiClient;
  final String? deviceId;
  final SyncConflictResolver _conflictResolver;
  final DriftSyncTombstoneStore _tombstones;

  final _statusController = StreamController<ConnectedStatusState>.broadcast();

  String get _deviceNamespace => deviceId != null ? '_$deviceId' : '';
  String get lastSyncedHlcKey => 'sync_last_synced_hlc${_deviceNamespace}_v1';
  String get lastSyncTimestampKey => 'sync_last_sync_timestamp${_deviceNamespace}_utc_v1';

  HlcClock? _clock;

  /// Lazily initializes or returns the local [HlcClock] bound to this device.
  Future<HlcClock> get clock async {
    if (_clock != null) return _clock!;
    final devId = deviceId ?? await _account.deviceId;
    final lastHlc = lastSyncedHlc;
    _clock = HlcClock(
      nodeId: devId,
      initialMillis: lastHlc?.millis,
      initialCounter: lastHlc?.counter ?? 0,
    );
    return _clock!;
  }

  /// The highest HLC timestamp successfully processed and applied locally.
  HlcTimestamp? get lastSyncedHlc {
    final raw = _prefs.getString(lastSyncedHlcKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return HlcTimestamp.fromString(raw);
    } catch (_) {
      return null;
    }
  }

  /// Timestamp of the last successful sync cycle in UTC.
  DateTime? get lastSyncTimestampUtc {
    final raw = _prefs.getString(lastSyncTimestampKey);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  @override
  Stream<ConnectedStatusState> get onStatusChanged => _statusController.stream;

  @override
  Future<ConnectedStatusState> getStatus() async {
    final isAuth = await _account.isAuthenticated;
    if (!isAuth) {
      return const ConnectedStatusState(
        status: ConnectedStatus.authenticationRequired,
      );
    }

    final pendingOps = await _outbox.getPendingOperations();
    final syncPendingCount =
        pendingOps.where((op) => op.action == 'sync_mutation').length;

    if (syncPendingCount > 0) {
      if (!_network.isConnected) {
        return ConnectedStatusState.offline(
          lastSuccessUtc: lastSyncTimestampUtc,
          pendingCount: syncPendingCount,
        );
      }
      return ConnectedStatusState.pending(
        count: syncPendingCount,
        lastSuccessUtc: lastSyncTimestampUtc,
      );
    }

    if (!_network.isConnected) {
      return ConnectedStatusState.offline(
        lastSuccessUtc: lastSyncTimestampUtc,
      );
    }

    if (lastSyncTimestampUtc != null) {
      return ConnectedStatusState.synced(lastSuccessUtc: lastSyncTimestampUtc);
    }

    return const ConnectedStatusState.neverConfigured();
  }

  static OutboxDomain _toOutboxDomain(SyncDomain domain) => switch (domain) {
        SyncDomain.workouts => OutboxDomain.workout,
        SyncDomain.nutritionLogs || SyncDomain.nutritionRecipes => OutboxDomain.food,
        SyncDomain.weights => OutboxDomain.weight,
        SyncDomain.programs => OutboxDomain.plan,
        SyncDomain.preferences => OutboxDomain.setting,
      };

  /// Records a local mutation, enqueues it in the durable outbox, and attempts an immediate push if online.
  Future<void> recordLocalMutation(SyncMutation mutation) async {
    final now = DateTime.now().toUtc();
    // Local deletes leave a tombstone first so replayed or late remote writes
    // cannot resurrect the row after restart (anti-resurrection).
    if (mutation.isDeleted) {
      await _tombstones.recordTombstone(
        SyncTombstone(
          entityId: mutation.entityId,
          domain: mutation.domain,
          deletedAtHlc: mutation.hlc,
          createdAtUtc: now,
        ),
      );
    }
    final op = OutboxOperation(
      operationId: 'sync_${mutation.entityId}_${mutation.hlc}',
      idempotencyKey: 'idem_${mutation.entityId}_${mutation.hlc}',
      domain: _toOutboxDomain(mutation.domain),
      action: 'sync_mutation',
      entityId: mutation.entityId,
      payload: mutation.toJson(),
      createdAtUtc: now,
      scheduledAtUtc: now,
    );
    await _outbox.enqueue(op);

    // Notify status listeners
    final status = await getStatus();
    _statusController.add(status);
  }

  @override
  Future<List<SyncDomainResult>> triggerSync({List<SyncDomain>? domains}) async {
    final isAuth = await _account.isAuthenticated;
    if (!isAuth) {
      return [
        const SyncDomainResult(
          domain: SyncDomain.workouts,
          success: false,
          errorMessage: 'Authentication required.',
        ),
      ];
    }

    if (!_network.isConnected) {
      return [
        const SyncDomainResult(
          domain: SyncDomain.workouts,
          success: false,
          errorMessage: 'Device is offline.',
        ),
      ];
    }

    final activeDomains = domains ?? SyncDomain.values;
    final results = <SyncDomainResult>[];

    try {
      // 1. Flush local outbox mutations (PUSH)
      final pendingOps = await _outbox.getPendingOperations();
      final syncOps = pendingOps
          .where((op) => op.action == 'sync_mutation')
          .toList();

      var pushedCount = 0;
      if (syncOps.isNotEmpty) {
        final mutations = <SyncMutation>[];
        for (final op in syncOps) {
          mutations.add(SyncMutation.fromJson(op.payload));
        }

        final pushResp = await _apiClient.pushMutations(mutations);
        for (final op in syncOps) {
          await _outbox.markSucceeded(op.operationId);
        }
        pushedCount = pushResp.acceptedCount;
      }

      // 2. Pull remote delta mutations (PULL, follow pagination)
      var since = lastSyncedHlc ?? const HlcTimestamp(millis: 0, counter: 0, nodeId: 'initial');
      var pulledCount = 0;
      HlcTimestamp? latestSeen;
      while (true) {
        final pullResp = await _apiClient.pullDeltas(sinceHlc: since, limit: 100);
        for (final remoteMutation in pullResp.mutations) {
          if (!activeDomains.contains(remoteMutation.domain)) continue;
          await _applyRemoteMutation(remoteMutation);
          pulledCount++;
        }
        if (pullResp.latestHlc != null) {
          latestSeen = pullResp.latestHlc;
          since = pullResp.latestHlc!;
        }
        // Maintain HLC causality even for skipped-domain pages.
        if (pullResp.latestHlc != null) {
          (await clock).receive(pullResp.latestHlc!);
        }
        if (!pullResp.hasMore || pullResp.mutations.isEmpty) break;
      }

      // 3. Update sync cursors
      final nowUtc = DateTime.now().toUtc();
      await _prefs.setString(lastSyncTimestampKey, nowUtc.toIso8601String());
      if (latestSeen != null) {
        await _prefs.setString(lastSyncedHlcKey, latestSeen.toString());
      }

      for (final d in activeDomains) {
        results.add(
          SyncDomainResult(
            domain: d,
            success: true,
            recordsSent: pushedCount,
            recordsReceived: pulledCount,
          ),
        );
      }
    } catch (e) {
      for (final d in activeDomains) {
        results.add(
          SyncDomainResult(
            domain: d,
            success: false,
            errorMessage: e.toString(),
          ),
        );
      }
    }

    final status = await getStatus();
    _statusController.add(status);

    return results;
  }

  /// Reconciles and applies an incoming remote mutation into local SQLite.
  ///
  /// Pending local outbox ops for the same entity win reconciliation via
  /// [SyncConflictResolver]; only the resolver winner is applied. HLC causality
  /// is maintained on every remote observation.
  Future<void> _applyRemoteMutation(SyncMutation remote) async {
    (await clock).receive(remote.hlc);

    // Persistent anti-resurrection: a stored tombstone dominating this write
    // extinguishes it even across restarts (relay replay, reinstall restore).
    if (await _tombstones.isExtinguished(
      remote.entityId,
      remote.domain,
      remote.hlc,
    )) {
      return;
    }
    // Incoming deletes are journaled before application for the same reason.
    if (remote.isDeleted) {
      await _tombstones.recordTombstone(
        SyncTombstone(
          entityId: remote.entityId,
          domain: remote.domain,
          deletedAtHlc: remote.hlc,
          createdAtUtc: DateTime.now().toUtc(),
        ),
      );
    }

    // Reconcile against queued local mutations for the same entity so a
    // concurrent local edit is not blindly overwritten.
    final pendingOps = await _outbox.getPendingOperations(limit: 200);
    for (final op in pendingOps) {
      if (op.action != 'sync_mutation') continue;
      SyncMutation? local;
      try {
        local = SyncMutation.fromJson(op.payload);
      } catch (_) {
        continue;
      }
      if (local.entityId != remote.entityId || local.domain != remote.domain) {
        continue;
      }
      final result = _conflictResolver.reconcile(local: local, incoming: remote);
      if (!result.wasLocalOverwritten) return; // Local wins; keep local.
      break;
    }

    switch (remote.domain) {
      case SyncDomain.weights:
        await _applyWeightMutation(remote);
      case SyncDomain.workouts:
        await _applyWorkoutMutation(remote);
      case SyncDomain.nutritionLogs:
        await _applyNutritionLogMutation(remote);
      case SyncDomain.nutritionRecipes:
      case SyncDomain.programs:
      case SyncDomain.preferences:
        // Deferred domains: no canonical writer yet. Cursor still advances
        // (see triggerSync) so sync converges; writers land with their
        // domain packages. Never silently fabricate rows for them.
        break;
    }
  }

  DateTime _eventTimeOrHlcFallback(Map<String, dynamic>? payload, List<String> keys, HlcTimestamp hlc) {
    if (payload != null) {
      for (final key in keys) {
        final raw = payload[key];
        if (raw is String && raw.isNotEmpty) {
          final parsed = DateTime.tryParse(raw);
          if (parsed != null) return parsed;
        }
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(hlc.millis, isUtc: true);
  }

  Future<void> _applyWeightMutation(SyncMutation remote) async {
    if (remote.isDeleted) {
      await (_db.delete(_db.bodyMeasurements)
            ..where((tbl) => tbl.id.equals(int.tryParse(remote.entityId) ?? -1)))
          .go();
      return;
    }

    final payload = remote.payload;
    if (payload == null) return;
    final weightRaw = payload['weight_kg'];
    if (weightRaw == null) return; // Never fabricate 0.0 for unknown weight.
    final weightKg = (weightRaw as num).toDouble();

    await _db.into(_db.bodyMeasurements).insertOnConflictUpdate(
          BodyMeasurementsCompanion(
            weight: Value(weightKg),
            recordedAt: Value(_eventTimeOrHlcFallback(
              payload,
              const ['recorded_at', 'recordedAt'],
              remote.hlc,
            )),
            isSynced: const Value(true),
          ),
        );
  }

  Future<void> _applyWorkoutMutation(SyncMutation remote) async {
    if (remote.isDeleted) {
      // Delete by stable UUID when present; fall back to legacy int id.
      final deletedByUuid = await (_db.delete(_db.workoutSessions)
            ..where((tbl) => tbl.uuid.equals(remote.entityId)))
          .go();
      if (deletedByUuid == 0) {
        await (_db.delete(_db.workoutSessions)
              ..where((tbl) => tbl.id.equals(int.tryParse(remote.entityId) ?? -1)))
            .go();
      }
      return;
    }

    final payload = remote.payload;
    if (payload == null) return;

    final sessionName = payload['name'] as String? ?? 'Workout';
    final completedAt = _eventTimeOrHlcFallback(
      payload,
      const ['completed_at', 'completedAt'],
      remote.hlc,
    );
    final totalVolume = (payload['total_volume'] as num?)?.toDouble();
    final durationSeconds = (payload['duration_seconds'] as num?)?.toInt();
    final estimatedCalories = (payload['estimated_calories'] as num?)?.toInt();

    // Preserve global UUID identity; never coerce UUIDs into autoincrement ids.
    final existingByUuid = await (_db.select(_db.workoutSessions)
          ..where((tbl) => tbl.uuid.equals(remote.entityId)))
        .getSingleOrNull();
    if (existingByUuid != null) {
      await (_db.update(_db.workoutSessions)
            ..where((tbl) => tbl.uuid.equals(remote.entityId)))
          .write(WorkoutSessionsCompanion(
        name: Value(sessionName),
        completedAt: Value(completedAt),
        totalVolume: totalVolume != null ? Value(totalVolume) : const Value.absent(),
        durationSeconds: durationSeconds != null ? Value(durationSeconds) : const Value.absent(),
        estimatedCalories: estimatedCalories != null ? Value(estimatedCalories) : const Value.absent(),
        isSynced: const Value(true),
      ));
      return;
    }

    await _db.into(_db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            name: sessionName,
            totalVolume: totalVolume ?? 0.0,
            durationSeconds: durationSeconds ?? 0,
            estimatedCalories: estimatedCalories ?? 0,
            completedAt: Value(completedAt),
            isSynced: const Value(true),
            uuid: Value(remote.entityId),
          ),
        );
  }

  Future<void> _applyNutritionLogMutation(SyncMutation remote) async {
    if (remote.isDeleted) {
      final deletedByUuid = await (_db.delete(_db.foodLogs)
            ..where((tbl) => tbl.uuid.equals(remote.entityId)))
          .go();
      if (deletedByUuid == 0) {
        await (_db.delete(_db.foodLogs)
              ..where((tbl) => tbl.id.equals(int.tryParse(remote.entityId) ?? -1)))
            .go();
      }
      return;
    }

    final payload = remote.payload;
    if (payload == null) return;
    final caloriesRaw = payload['calories'];
    if (caloriesRaw == null) return; // Never fabricate 0 kcal.

    final foodName = payload['name'] as String? ?? 'Food';
    final calories = (caloriesRaw as num).toInt();
    final mealType = payload['meal_type'] as String? ?? 'snack';
    final loggedAt = _eventTimeOrHlcFallback(
      payload,
      const ['logged_at', 'loggedAt'],
      remote.hlc,
    );

    final existingByUuid = await (_db.select(_db.foodLogs)
          ..where((tbl) => tbl.uuid.equals(remote.entityId)))
        .getSingleOrNull();
    if (existingByUuid != null) {
      await (_db.update(_db.foodLogs)
            ..where((tbl) => tbl.uuid.equals(remote.entityId)))
          .write(FoodLogsCompanion(
        name: Value(foodName),
        calories: Value(calories),
        mealType: Value(mealType),
        loggedAt: Value(loggedAt),
        isSynced: const Value(true),
      ));
      return;
    }

    await _db.into(_db.foodLogs).insert(
          FoodLogsCompanion.insert(
            name: foodName,
            calories: calories,
            proteinG: ((payload['protein_g'] as num?)?.toDouble()) ?? 0.0,
            carbsG: ((payload['carbs_g'] as num?)?.toDouble()) ?? 0.0,
            fatG: ((payload['fat_g'] as num?)?.toDouble()) ?? 0.0,
            servingLogged: ((payload['serving_logged'] as num?)?.toDouble()) ?? 1.0,
            servingUnit: payload['serving_unit'] as String? ?? 'serving',
            mealType: mealType,
            loggedAt: Value(loggedAt),
            isSynced: const Value(true),
            uuid: Value(remote.entityId),
          ),
        );
  }

  @override
  Future<List<SyncMutation>> pullDeltas({
    required HlcTimestamp sinceHlc,
    int limit = 100,
  }) async {
    final resp = await _apiClient.pullDeltas(sinceHlc: sinceHlc, limit: limit);
    return resp.mutations;
  }

  @override
  Future<bool> pushMutations(List<SyncMutation> mutations) async {
    final resp = await _apiClient.pushMutations(mutations);
    return resp.acceptedCount > 0;
  }

  void dispose() {
    _statusController.close();
  }
}
