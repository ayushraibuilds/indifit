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
    this.deviceId,
  })  : _db = db,
        _prefs = prefs,
        _account = account,
        _network = network,
        _outbox = outbox,
        _apiClient = apiClient,
        _conflictResolver = conflictResolver;

  final AppDatabase _db;
  final SharedPreferences _prefs;
  final AccountCapability _account;
  final NetworkCapability _network;
  final OutboxRepository _outbox;
  final SyncApiClient _apiClient;
  final String? deviceId;
  // ignore: unused_field
  final SyncConflictResolver _conflictResolver;

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

      // 2. Pull remote delta mutations (PULL)
      final since = lastSyncedHlc ?? const HlcTimestamp(millis: 0, counter: 0, nodeId: 'initial');
      final pullResp = await _apiClient.pullDeltas(sinceHlc: since);

      var pulledCount = 0;
      for (final remoteMutation in pullResp.mutations) {
        if (!activeDomains.contains(remoteMutation.domain)) continue;
        await _applyRemoteMutation(remoteMutation);
        pulledCount++;
      }

      // 3. Update sync cursors
      final nowUtc = DateTime.now().toUtc();
      await _prefs.setString(lastSyncTimestampKey, nowUtc.toIso8601String());
      if (pullResp.latestHlc != null) {
        await _prefs.setString(lastSyncedHlcKey, pullResp.latestHlc!.toString());
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
  Future<void> _applyRemoteMutation(SyncMutation remote) async {
    switch (remote.domain) {
      case SyncDomain.weights:
        await _applyWeightMutation(remote);
      case SyncDomain.workouts:
        await _applyWorkoutMutation(remote);
      case SyncDomain.nutritionLogs:
        await _applyNutritionLogMutation(remote);
      default:
        break;
    }
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

    final weightKg = (payload['weight_kg'] as num?)?.toDouble() ?? 0.0;

    await _db.into(_db.bodyMeasurements).insertOnConflictUpdate(
          BodyMeasurementsCompanion(
            id: remote.entityId.length <= 9 && int.tryParse(remote.entityId) != null
                ? Value(int.parse(remote.entityId))
                : const Value.absent(),
            weight: Value(weightKg),
            recordedAt: Value(DateTime.now()),
            isSynced: const Value(true),
          ),
        );
  }

  Future<void> _applyWorkoutMutation(SyncMutation remote) async {
    if (remote.isDeleted) {
      await (_db.delete(_db.workoutSessions)
            ..where((tbl) => tbl.id.equals(int.tryParse(remote.entityId) ?? -1)))
          .go();
      return;
    }

    final payload = remote.payload;
    if (payload == null) return;

    final sessionName = payload['name'] as String? ?? 'Workout';
    final completedAt = payload['completed_at'] != null
        ? DateTime.parse(payload['completed_at'] as String)
        : DateTime.now();

    await _db.into(_db.workoutSessions).insertOnConflictUpdate(
          WorkoutSessionsCompanion(
            id: remote.entityId.length <= 9 && int.tryParse(remote.entityId) != null
                ? Value(int.parse(remote.entityId))
                : const Value.absent(),
            name: Value(sessionName),
            completedAt: Value(completedAt),
            totalVolume: const Value(0.0),
            durationSeconds: const Value(0),
            estimatedCalories: const Value(0),
          ),
        );
  }

  Future<void> _applyNutritionLogMutation(SyncMutation remote) async {
    if (remote.isDeleted) {
      await (_db.delete(_db.foodLogs)
            ..where((tbl) => tbl.id.equals(int.tryParse(remote.entityId) ?? -1)))
          .go();
      return;
    }

    final payload = remote.payload;
    if (payload == null) return;

    final foodName = payload['name'] as String? ?? 'Food';
    final calories = (payload['calories'] as num?)?.toInt() ?? 0;
    final mealType = payload['meal_type'] as String? ?? 'snack';

    await _db.into(_db.foodLogs).insertOnConflictUpdate(
          FoodLogsCompanion(
            id: remote.entityId.length <= 9 && int.tryParse(remote.entityId) != null
                ? Value(int.parse(remote.entityId))
                : const Value.absent(),
            name: Value(foodName),
            calories: Value(calories),
            mealType: Value(mealType),
            loggedAt: Value(DateTime.now()),
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
