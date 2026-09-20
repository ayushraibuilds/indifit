import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/legacy_program_compatibility_adapter.dart';
import '../backup/cloud_backup_envelope_manager.dart';
import '../capabilities/account_capability.dart';
import '../capabilities/connected_status.dart';
import '../capabilities/network_capability.dart';
import '../capabilities/sync_capability.dart';
import '../outbox/outbox_operation.dart';
import '../outbox/outbox_repository.dart';
import '../utils/app_logger.dart';
import 'hlc_timestamp.dart';
import 'sync_api_client.dart';
import 'sync_conflict_resolver.dart';
import 'sync_mutation.dart';
import 'sync_tombstone_store.dart';

/// Central synchronization engine implementing [SyncCapability].
///
/// Optional per-mutation envelope encryption (SYNC-01A §5.1 blind relay):
/// pass both [envelopeManager] and [syncEncryptionSecret] to encrypt
/// non-delete mutation payloads before they reach the relay and to decrypt
/// incoming envelopes before applying them. When [syncEncryptionSecret] is
/// null the service keeps today's exact plaintext behavior; that null-secret
/// fallback exists for local dev/test only — production activation stays
/// Disabled-gated per the post-V1 roadmap, so plaintext-by-default is staged,
/// not shipped.
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
    CloudBackupEnvelopeManager? envelopeManager,
    String? syncEncryptionSecret,
  })  : _db = db,
        _prefs = prefs,
        _account = account,
        _network = network,
        _outbox = outbox,
        _apiClient = apiClient,
        _conflictResolver = conflictResolver,
        _envelopeManager = envelopeManager,
        _syncSecret = syncEncryptionSecret,
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
  final CloudBackupEnvelopeManager? _envelopeManager;
  final String? _syncSecret;

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
    // Invariant: Bundled catalog starter programs can never be mutated or deleted across devices.
    if (SyncConflictResolver.isCatalogProgramId(mutation.entityId)) {
      return;
    }
    // Invariant: Achievements are strictly insert-only (no deletion tombstones).
    if (mutation.isDeleted &&
        (mutation.payload?['entity_type'] == 'achievement' ||
            mutation.entityId.startsWith('achievement:'))) {
      return;
    }
    // Invariant: Non-allowlisted or denylisted preferences are rejected at capture.
    if (mutation.domain == SyncDomain.preferences) {
      final entityType = mutation.payload?['entity_type'] as String?;
      if (entityType != 'user_profile' &&
          entityType != 'achievement' &&
          !mutation.entityId.startsWith('achievement:') &&
          mutation.entityId != 'user_profile') {
        final settingKey = (mutation.payload?['key'] as String?) ?? mutation.entityId;
        if (!SyncConflictResolver.isSettingKeySyncable(settingKey)) {
          return;
        }
      }
    }

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
    // Blind-relay encryption: non-delete payloads are sealed into a
    // per-mutation envelope when a sync secret is configured. Deletes stay
    // payload-free per the SyncMutation assert. When no secret is configured
    // the mutation is enqueued exactly as today (plaintext dev/test fallback).
    var effectiveMutation = mutation;
    if (mutation.type != SyncMutationType.delete &&
        _syncSecret != null &&
        mutation.payload != null) {
      final mutationId = '${mutation.entityId}:${mutation.hlc}';
      final envelope = (_envelopeManager ?? CloudBackupEnvelopeManager())
          .encryptMutation(
        mutationId: mutationId,
        plaintextJson: jsonEncode(mutation.payload),
        kmsKeyWrappingSecret: _syncSecret,
      );
      effectiveMutation = SyncMutation(
        entityId: mutation.entityId,
        domain: mutation.domain,
        type: mutation.type,
        hlc: mutation.hlc,
        encryptedEnvelope: <String, dynamic>{
          'mutation_id': envelope.snapshotId,
          'ciphertext_base64': base64Encode(envelope.ciphertextBytes),
          'wrapped_key_base64': base64Encode(envelope.wrappedKeyBytes),
          'sha256_checksum': envelope.sha256Checksum,
        },
      );
    }
    final op = OutboxOperation(
      operationId: 'sync_${mutation.entityId}_${mutation.hlc}',
      idempotencyKey: 'idem_${mutation.entityId}_${mutation.hlc}',
      domain: _toOutboxDomain(mutation.domain),
      action: 'sync_mutation',
      entityId: mutation.entityId,
      payload: effectiveMutation.toJson(),
      createdAtUtc: now,
      scheduledAtUtc: now,
    );
    await _outbox.enqueue(op);

    // Notify status listeners
    final status = await getStatus();
    _statusController.add(status);
  }

  // --- Capture-Side Domain Enqueue Helpers ---

  Future<void> recordNutritionLogMutation(SyncMutation mutation) => recordLocalMutation(mutation);

  /// Records a custom food mutation.
  ///
  /// Capture-side rename convention: Because FoodItems lacks an opaque UUID column
  /// in schema v22 and matching relies on single-candidate name matching, food
  /// renames must be emitted as a delete-old-name mutation followed by a
  /// create-new-name mutation pair. Renaming in-place in an update mutation
  /// cannot converge across peers under name-based identity.
  Future<void> recordCustomFoodMutation(SyncMutation mutation) => recordLocalMutation(mutation);
  Future<void> recordMealTemplateMutation(SyncMutation mutation) => recordLocalMutation(mutation);
  Future<void> recordGoalVersionMutation(SyncMutation mutation) => recordLocalMutation(mutation);
  Future<void> recordRoutineMutation(SyncMutation mutation) => recordLocalMutation(mutation);
  Future<void> recordEquipmentProfileMutation(SyncMutation mutation) => recordLocalMutation(mutation);
  Future<void> recordProfileMutation(SyncMutation mutation) => recordLocalMutation(mutation);

  Future<void> recordSettingMutation(SyncMutation mutation) async {
    final key = (mutation.payload?['key'] as String?) ?? mutation.entityId;
    if (!SyncConflictResolver.isSettingKeySyncable(key)) {
      return;
    }
    await recordLocalMutation(mutation);
  }

  Future<void> recordAchievementMutation(SyncMutation mutation) async {
    if (mutation.isDeleted) return;
    await recordLocalMutation(mutation);
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
  ///
  /// Encrypted mutations (non-null [SyncMutation.encryptedEnvelope]) are
  /// decrypted with the configured sync secret before any of the steps below.
  /// Without a secret, or when decryption/decoding fails, the mutation is
  /// skipped (fail closed): never fabricated, never thrown out of apply.
  Future<void> _applyRemoteMutation(SyncMutation remote) async {
    (await clock).receive(remote.hlc);

    var effective = remote;
    if (remote.encryptedEnvelope != null) {
      if (_syncSecret == null) {
        AppLogger.warning(
          'Skipping encrypted sync mutation ${remote.entityId}: no sync secret configured.',
          'SyncService',
        );
        return;
      }
      try {
        final wire = remote.encryptedEnvelope!;
        final envelope = CloudBackupEncryptedEnvelope(
          // snapshotId == mutationId on the sync path (see encryptMutation).
          snapshotId: wire['mutation_id'] as String,
          ciphertextBytes: base64Decode(wire['ciphertext_base64'] as String),
          wrappedKeyBytes: base64Decode(wire['wrapped_key_base64'] as String),
          sha256Checksum: wire['sha256_checksum'] as String,
          byteSize: 0,
          // Unused on the sync path (sync AAD carries no version component).
          schemaVersion: 0,
          backupFormatVersion: 0,
          createdAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        final plaintextJson =
            (_envelopeManager ?? CloudBackupEnvelopeManager()).decryptMutation(
          envelope: envelope,
          kmsKeyWrappingSecret: _syncSecret,
        );
        final decoded = jsonDecode(plaintextJson);
        if (decoded is! Map<String, dynamic>) {
          AppLogger.warning(
            'Skipping encrypted sync mutation ${remote.entityId}: decrypted payload is not a JSON object.',
            'SyncService',
          );
          return;
        }
        effective = SyncMutation(
          entityId: remote.entityId,
          domain: remote.domain,
          type: remote.type,
          hlc: remote.hlc,
          payload: decoded,
        );
      } catch (e) {
        AppLogger.warning(
          'Skipping encrypted sync mutation ${remote.entityId}: decrypt/decode failed ($e).',
          'SyncService',
        );
        return;
      }
    }

    // Persistent anti-resurrection: a stored tombstone dominating this write
    // extinguishes it even across restarts (relay replay, reinstall restore).
    if (await _tombstones.isExtinguished(
      effective.entityId,
      effective.domain,
      effective.hlc,
    )) {
      return;
    }
    // Incoming deletes are journaled before application for the same reason.
    if (effective.isDeleted) {
      await _tombstones.recordTombstone(
        SyncTombstone(
          entityId: effective.entityId,
          domain: effective.domain,
          deletedAtHlc: effective.hlc,
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
      if (local.entityId != effective.entityId || local.domain != effective.domain) {
        continue;
      }
      final result = _conflictResolver.reconcile(local: local, incoming: effective);
      if (!result.wasLocalOverwritten) return; // Local wins; keep local.
      break;
    }

    switch (effective.domain) {
      case SyncDomain.weights:
        await _applyWeightMutation(effective);
      case SyncDomain.workouts:
        await _applyWorkoutMutation(effective);
      case SyncDomain.nutritionLogs:
        await _applyNutritionLogMutation(effective);
      case SyncDomain.nutritionRecipes:
        await _applyNutritionRecipeMutation(effective);
      case SyncDomain.programs:
        await _applyProgramMutation(effective);
      case SyncDomain.preferences:
        await _applyPreferenceMutation(effective);
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
    // UUID identity, mirroring the workout/food paths: the opaque entityId is
    // the stable cross-device identity and is never coerced into the local
    // autoincrement id.
    //
    // INTEGRATION NOTE (Agent A, v22 migration): this requires the nullable
    // `uuid` TEXT column on BodyMeasurements (same pattern as the existing
    // nullable uuid columns on WorkoutSessions/FoodLogs) plus drift codegen.
    // Until `tbl.uuid` exists, these references do not compile; integration
    // follows that codegen. Do not work around it (no synthetic ids).
    if (remote.isDeleted) {
      // Delete by stable UUID when present; fall back to legacy int id.
      final deletedByUuid = await (_db.delete(_db.bodyMeasurements)
            ..where((tbl) => tbl.uuid.equals(remote.entityId)))
          .go();
      if (deletedByUuid == 0) {
        await (_db.delete(_db.bodyMeasurements)
              ..where((tbl) => tbl.id.equals(int.tryParse(remote.entityId) ?? -1)))
            .go();
      }
      return;
    }

    final payload = remote.payload;
    if (payload == null) return;
    final weightRaw = payload['weight_kg'];
    if (weightRaw == null) return; // Never fabricate 0.0 for unknown weight.
    final weightKg = (weightRaw as num).toDouble();
    final recordedAt = _eventTimeOrHlcFallback(
      payload,
      const ['recorded_at', 'recordedAt'],
      remote.hlc,
    );

    // Look up by uuid first so re-delivery updates instead of duplicating.
    final existingByUuid = await (_db.select(_db.bodyMeasurements)
          ..where((tbl) => tbl.uuid.equals(remote.entityId)))
        .getSingleOrNull();
    if (existingByUuid != null) {
      await (_db.update(_db.bodyMeasurements)
            ..where((tbl) => tbl.uuid.equals(remote.entityId)))
          .write(BodyMeasurementsCompanion(
        weight: Value(weightKg),
        recordedAt: Value(recordedAt),
        isSynced: const Value(true),
      ));
      return;
    }

    await _db.into(_db.bodyMeasurements).insert(
          BodyMeasurementsCompanion.insert(
            weight: Value(weightKg),
            recordedAt: Value(recordedAt),
            isSynced: const Value(true),
            uuid: Value(remote.entityId),
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
    final payload = remote.payload;
    final entityType = payload?['entity_type'] as String?;

    if (entityType == 'custom_food' || payload?['is_custom'] == true) {
      await _applyCustomFoodMutation(remote);
      return;
    }

    if (entityType == 'goal_version' || remote.entityId.startsWith('goal_version:')) {
      await _applyGoalVersionMutation(remote);
      return;
    }

    // Standard FoodLog mutation
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

  /// Applies a custom food mutation using zero-drift single-candidate name matching.
  ///
  /// Invariants & Operational Rules (Schema v22):
  /// - The local autoincrement ID is never matched across peers.
  /// - Matches custom foods (`isCustom == true`) by case-insensitive name.
  /// - Ambiguity guard: If 0 or >1 candidates match on write, inserts as a new row.
  /// - Delete guard: Deletion only proceeds if exactly 1 candidate matches (ambiguous deletions no-op).
  /// - Capture-side rename convention: Renames must be emitted as delete-old-name +
  ///   create-new-name mutation pairs. Renaming in-place in an update mutation
  ///   cannot converge across peers under name-based identity.
  /// - Tracked follow-up: Schema v23 will introduce `FoodItems.uuid` (nullable, minted on
  ///   create, backfilled opportunistically); applicator will match UUID-first with
  ///   single-candidate name fallback retained for pre-v23 rows.
  Future<void> _applyCustomFoodMutation(SyncMutation remote) async {
    final payload = remote.payload;
    final foodName = (payload?['name'] as String? ?? '').trim();

    if (remote.isDeleted) {
      // Single-candidate case-insensitive name match
      if (foodName.isNotEmpty) {
        final matches = await (_db.select(_db.foodItems)
              ..where((t) => t.isCustom.equals(true) & t.name.lower().equals(foodName.toLowerCase())))
            .get();
        if (matches.length == 1) {
          await (_db.delete(_db.foodItems)..where((t) => t.id.equals(matches.first.id))).go();
        }
      }
      return;
    }

    if (payload == null || foodName.isEmpty) return;

    final calories = (payload['calories'] as num?)?.toInt() ?? 0;
    final proteinG = (payload['protein_g'] as num?)?.toDouble() ?? 0.0;
    final carbsG = (payload['carbs_g'] as num?)?.toDouble() ?? 0.0;
    final fatG = (payload['fat_g'] as num?)?.toDouble() ?? 0.0;
    final fiberG = (payload['fiber_g'] as num?)?.toDouble();
    final servingSize = (payload['serving_size'] as num?)?.toDouble() ?? 100.0;
    final servingUnit = (payload['serving_unit'] as String?) ?? 'g';
    final category = (payload['category'] as String?) ?? 'custom';

    // Single-candidate case-insensitive name match fallback
    final matches = await (_db.select(_db.foodItems)
          ..where((t) => t.isCustom.equals(true) & t.name.lower().equals(foodName.toLowerCase())))
        .get();

    if (matches.length == 1) {
      await (_db.update(_db.foodItems)..where((t) => t.id.equals(matches.first.id))).write(
        FoodItemsCompanion(
          name: Value(foodName),
          calories: Value(calories),
          proteinG: Value(proteinG),
          carbsG: Value(carbsG),
          fatG: Value(fatG),
          fiberG: Value(fiberG),
          servingSize: Value(servingSize),
          servingUnit: Value(servingUnit),
          category: Value(category),
        ),
      );
      return;
    }

    // 0 or >1 candidates: insert as new custom food (avoids mismerging distinct foods)
    await _db.into(_db.foodItems).insert(FoodItemsCompanion.insert(
          name: foodName,
          calories: calories,
          proteinG: proteinG,
          carbsG: carbsG,
          fatG: fatG,
          fiberG: Value(fiberG),
          servingSize: servingSize,
          servingUnit: servingUnit,
          category: category,
          isCustom: const Value(true),
        ));
  }

  Future<void> _applyGoalVersionMutation(SyncMutation remote) async {
    if (remote.isDeleted) return; // Invariant: Append-only historical truth
    final payload = remote.payload;
    if (payload == null) return;

    final goalType = payload['goal_type'] as String?;
    final effectiveFrom = payload['effective_from_local_date'] as String?;
    if (goalType == null || effectiveFrom == null) {
      AppLogger.warning(
        'Skipping invalid goal version mutation ${remote.entityId}: missing required goal_type or effective_from_local_date.',
        'SyncService',
      );
      return;
    }

    final versionId = remote.entityId.replaceFirst('goal_version:', '');
    final userId = payload['user_id'] as String? ?? 'default';
    final versionNumber = (payload['version_number'] as num?)?.toInt() ?? 1;
    final targetSource = payload['target_source'] as String? ?? 'user_set';
    final calorieTarget = (payload['calorie_target_kcal'] as num?)?.toInt();
    final proteinTarget = (payload['protein_target_g'] as num?)?.toDouble();
    final carbsTarget = (payload['carbs_target_g'] as num?)?.toDouble();
    final fatTarget = (payload['fat_target_g'] as num?)?.toDouble();
    final timezoneId = payload['timezone_id'] as String? ?? 'UTC';

    await _db.into(_db.nutritionGoalVersions).insertOnConflictUpdate(
          NutritionGoalVersionsCompanion.insert(
            id: versionId,
            userId: userId,
            versionNumber: versionNumber,
            goalType: goalType,
            targetSource: targetSource,
            calorieTargetKcal: Value(calorieTarget),
            proteinTargetG: Value(proteinTarget),
            carbsTargetG: Value(carbsTarget),
            fatTargetG: Value(fatTarget),
            effectiveFromLocalDate: effectiveFrom,
            timezoneId: timezoneId,
            createdAtUtc: Value(
              _eventTimeOrHlcFallback(
                payload,
                const ['created_at_utc', 'createdAtUtc'],
                remote.hlc,
              ),
            ),
          ),
        );
  }

  Future<void> _applyNutritionRecipeMutation(SyncMutation remote) async {
    final payload = remote.payload;
    final entityType = payload?['entity_type'] as String?;

    if (entityType == 'recipe' || remote.entityId.startsWith('recipe:')) {
      await _applyNutritionRecipeEntityMutation(remote);
      return;
    }

    // Default: meal_templates & items
    await _applyMealTemplateMutation(remote);
  }

  Future<void> _applyMealTemplateMutation(SyncMutation remote) async {
    final payload = remote.payload;
    String name = (payload?['name'] as String? ?? '').trim();
    int? intId = (payload?['id'] as num?)?.toInt() ?? int.tryParse(remote.entityId);

    if (intId == null && remote.entityId.contains(':')) {
      final colonIdx = remote.entityId.indexOf(':');
      final prefixId = int.tryParse(remote.entityId.substring(0, colonIdx));
      if (prefixId != null) {
        intId = prefixId;
        if (name.isEmpty) {
          name = remote.entityId.substring(colonIdx + 1).trim();
        }
      }
    }
    if (name.isEmpty) {
      name = remote.entityId.trim();
    }

    if (remote.isDeleted) {
      // Invariant: conjunctive id+name match for delete; never OR
      final template = intId != null
          ? await (_db.select(_db.mealTemplates)
                ..where((t) => t.id.equals(intId!) & t.name.equals(name)))
              .getSingleOrNull()
          : await (_db.select(_db.mealTemplates)
                ..where((t) => t.name.equals(name)))
              .getSingleOrNull();

      if (template != null) {
        await (_db.delete(_db.mealTemplateItems)..where((t) => t.templateId.equals(template.id))).go();
        await (_db.delete(_db.mealTemplates)..where((t) => t.id.equals(template.id))).go();
      }
      return;
    }

    if (payload == null) return;
    final mealType = payload['default_meal_type'] as String? ?? 'breakfast';
    final items = payload['items'] as List<dynamic>? ?? [];

    await _db.transaction(() async {
      // Invariant: conjunctive id+name match for update; mismatch inserts new (never OR)
      final existing = intId != null
          ? await (_db.select(_db.mealTemplates)
                ..where((t) => t.id.equals(intId!) & t.name.equals(name)))
              .getSingleOrNull()
          : await (_db.select(_db.mealTemplates)
                ..where((t) => t.name.equals(name)))
              .getSingleOrNull();

      int templateId;
      if (existing != null) {
        templateId = existing.id;
        await (_db.update(_db.mealTemplates)..where((t) => t.id.equals(templateId))).write(
          MealTemplatesCompanion(name: Value(name), defaultMealType: Value(mealType)),
        );
        await (_db.delete(_db.mealTemplateItems)..where((t) => t.templateId.equals(templateId))).go();
      } else {
        templateId = await _db.into(_db.mealTemplates).insert(
          MealTemplatesCompanion.insert(name: name, defaultMealType: Value(mealType)),
        );
      }
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        await _db.into(_db.mealTemplateItems).insert(MealTemplateItemsCompanion.insert(
              templateId: templateId,
              name: itemMap['name'] as String? ?? 'Item',
              calories: (itemMap['calories'] as num?)?.toInt() ?? 0,
              proteinG: (itemMap['protein_g'] as num?)?.toDouble() ?? 0.0,
              carbsG: (itemMap['carbs_g'] as num?)?.toDouble() ?? 0.0,
              fatG: (itemMap['fat_g'] as num?)?.toDouble() ?? 0.0,
              servingLogged: (itemMap['serving_logged'] as num?)?.toDouble() ?? 1.0,
              servingUnit: itemMap['serving_unit'] as String? ?? 'serving',
            ));
      }
    });
  }

  Future<void> _applyNutritionRecipeEntityMutation(SyncMutation remote) async {
    final payload = remote.payload;
    final recipeId = remote.entityId.replaceFirst('recipe:', '');

    if (remote.isDeleted) {
      await (_db.update(_db.nutritionRecipes)..where((t) => t.id.equals(recipeId))).write(
        const NutritionRecipesCompanion(lifecycle: Value('deleted')),
      );
      return;
    }

    if (payload == null) return;
    final name = payload['name'] as String? ?? 'Recipe';
    final description = payload['description'] as String?;
    final userId = payload['user_id'] as String? ?? 'user';
    final lifecycle = payload['lifecycle'] as String? ?? 'active';
    final now = DateTime.now().toUtc();

    await _db.into(_db.nutritionRecipes).insertOnConflictUpdate(
          NutritionRecipesCompanion.insert(
            id: recipeId,
            userId: userId,
            name: name,
            description: Value(description),
            lifecycle: lifecycle,
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> _applyProgramMutation(SyncMutation remote) async {
    // 1. Published catalog program guard:
    // Bundled catalog programs are immutable static app assets.
    // Drop ALL mutations (both writes and deletes) targeting catalog IDs.
    if (SyncConflictResolver.isCatalogProgramId(remote.entityId)) {
      return;
    }

    final payload = remote.payload;
    final entityType = payload?['entity_type'] as String?;

    // 2. Equipment profile check:
    if (entityType == 'equipment_profile' || remote.entityId.startsWith('eq_profile:')) {
      await _applyEquipmentProfileMutation(remote);
      return;
    }

    // 3. Workout Routine with child days and exercises:
    await _applyRoutineMutation(remote);
  }

  Future<void> _applyRoutineMutation(SyncMutation remote) async {
    final payload = remote.payload;
    String name = (payload?['name'] as String? ?? '').trim();
    int? intId = (payload?['id'] as num?)?.toInt() ?? int.tryParse(remote.entityId);

    if (intId == null && remote.entityId.contains(':')) {
      final colonIdx = remote.entityId.indexOf(':');
      final prefixId = int.tryParse(remote.entityId.substring(0, colonIdx));
      if (prefixId != null) {
        intId = prefixId;
        if (name.isEmpty) {
          name = remote.entityId.substring(colonIdx + 1).trim();
        }
      }
    }
    if (name.isEmpty) {
      name = remote.entityId.trim();
    }

    if (remote.isDeleted) {
      // Invariant: conjunctive id+name match for delete; never OR
      final routine = intId != null
          ? await (_db.select(_db.workoutRoutines)
                ..where((t) => t.id.equals(intId!) & t.name.equals(name)))
              .getSingleOrNull()
          : await (_db.select(_db.workoutRoutines)
                ..where((t) => t.name.equals(name)))
              .getSingleOrNull();

      if (routine != null) {
        await _db.transaction(() async {
          await (_db.delete(_db.legacyRoutineProgramMappings)..where((t) => t.legacyRoutineId.equals(routine.id))).go();
          final days = await (_db.select(_db.routineDays)..where((t) => t.routineId.equals(routine.id))).get();
          for (final d in days) {
            await (_db.delete(_db.routineExercises)..where((t) => t.dayId.equals(d.id))).go();
          }
          await (_db.delete(_db.routineDays)..where((t) => t.routineId.equals(routine.id))).go();
          await (_db.delete(_db.workoutRoutines)..where((t) => t.id.equals(routine.id))).go();
        });
      }
      return;
    }

    if (payload == null) return;
    final goal = payload['goal'] as String? ?? 'General';
    final notes = payload['notes'] as String?;
    final daysData = payload['days'] as List<dynamic>? ?? [];

    await _db.transaction(() async {
      // Invariant: conjunctive id+name match for update; mismatch inserts new (never OR)
      final existing = intId != null
          ? await (_db.select(_db.workoutRoutines)
                ..where((t) => t.id.equals(intId!) & t.name.equals(name)))
              .getSingleOrNull()
          : await (_db.select(_db.workoutRoutines)
                ..where((t) => t.name.equals(name)))
              .getSingleOrNull();

      int targetRoutineId;
      if (existing != null) {
        targetRoutineId = existing.id;
        await (_db.update(_db.workoutRoutines)..where((t) => t.id.equals(targetRoutineId))).write(
          WorkoutRoutinesCompanion(
            name: Value(name),
            goal: Value(goal),
            notes: Value(notes),
          ),
        );
        final existingDays = await (_db.select(_db.routineDays)..where((t) => t.routineId.equals(targetRoutineId))).get();
        for (final d in existingDays) {
          await (_db.delete(_db.routineExercises)..where((t) => t.dayId.equals(d.id))).go();
        }
        await (_db.delete(_db.routineDays)..where((t) => t.routineId.equals(targetRoutineId))).go();
      } else {
        targetRoutineId = await _db.into(_db.workoutRoutines).insert(
              WorkoutRoutinesCompanion.insert(
                name: name,
                goal: goal,
                notes: Value(notes),
              ),
            );
      }

      for (final dayObj in daysData) {
        final dayMap = dayObj as Map<String, dynamic>;
        final dayId = await _db.into(_db.routineDays).insert(
              RoutineDaysCompanion.insert(
                routineId: targetRoutineId,
                dayOfWeek: (dayMap['day_of_week'] as num?)?.toInt() ?? 1,
                name: dayMap['name'] as String? ?? 'Day',
                isRestDay: Value((dayMap['is_rest_day'] as bool?) ?? false),
              ),
            );
        final exList = dayMap['exercises'] as List<dynamic>? ?? [];
        for (int i = 0; i < exList.length; i++) {
          final exMap = exList[i] as Map<String, dynamic>;
          await _db.into(_db.routineExercises).insert(
                RoutineExercisesCompanion.insert(
                  dayId: dayId,
                  exerciseName: exMap['name'] as String? ?? 'Exercise',
                  sets: (exMap['sets'] as num?)?.toInt() ?? 3,
                  repsRange: exMap['reps_range'] as String? ?? '8-12',
                  orderIndex: i,
                ),
              );
        }
      }

      // Re-sync B01 legacy import adapter snapshot
      await LegacyProgramCompatibilityAdapter(_db).syncLegacyRoutineToImportVersion(targetRoutineId);
    });
  }

  Future<void> _applyEquipmentProfileMutation(SyncMutation remote) async {
    final profileId = remote.entityId.replaceFirst('eq_profile:', '');

    if (remote.isDeleted) {
      await (_db.delete(_db.equipmentProfileItems)..where((t) => t.equipmentProfileId.equals(profileId))).go();
      await (_db.delete(_db.equipmentProfiles)..where((t) => t.id.equals(profileId))).go();
      return;
    }

    final payload = remote.payload;
    if (payload == null) return;

    final name = payload['name'] as String? ?? 'Equipment Profile';
    final defaultWeightInc = (payload['default_weight_increment_kg'] as num?)?.toDouble();
    final items = payload['items'] as List<dynamic>? ?? [];
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      final existing = await (_db.select(_db.equipmentProfiles)..where((t) => t.id.equals(profileId))).getSingleOrNull();
      if (existing != null) {
        await (_db.update(_db.equipmentProfiles)..where((t) => t.id.equals(profileId))).write(
          EquipmentProfilesCompanion(
            name: Value(name),
            defaultWeightIncrementKg: Value(defaultWeightInc),
            updatedAtUtc: Value(now),
          ),
        );
        await (_db.delete(_db.equipmentProfileItems)..where((t) => t.equipmentProfileId.equals(profileId))).go();
      } else {
        await _db.into(_db.equipmentProfiles).insert(
              EquipmentProfilesCompanion.insert(
                id: profileId,
                name: name,
                defaultWeightIncrementKg: Value(defaultWeightInc),
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
      }

      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        final itemCode = itemMap['equipment_code'] as String? ?? 'unknown';
        final itemId = '${profileId}_$itemCode';
        await _db.into(_db.equipmentProfileItems).insert(
              EquipmentProfileItemsCompanion.insert(
                id: itemId,
                equipmentProfileId: profileId,
                equipmentCode: itemCode,
                isAvailable: Value((itemMap['is_available'] as bool?) ?? true),
                weightIncrementKg: Value((itemMap['weight_increment_kg'] as num?)?.toDouble()),
              ),
            );
      }
    });
  }

  Future<void> _applyPreferenceMutation(SyncMutation remote) async {
    final payload = remote.payload;
    final entityType = payload?['entity_type'] as String?;

    // 1. Achievements (insert-only, earliest-wins, no tombstones)
    if (entityType == 'achievement' || remote.entityId.startsWith('achievement:')) {
      await _applyAchievementMutation(remote);
      return;
    }

    // 2. User Profile (14 fields mirrored to UserProfiles and SharedPreferences)
    if (entityType == 'user_profile' || remote.entityId == 'user_profile') {
      await _applyUserProfileMutation(remote);
      return;
    }

    // 3. User Settings allowlist enforcement
    await _applyUserSettingMutation(remote);
  }

  Future<void> _applyAchievementMutation(SyncMutation remote) async {
    // Invariant: strictly insert-only. Remote deletions are ignored.
    if (remote.isDeleted) return;
    final payload = remote.payload;
    final badgeId = (payload?['achievement_id'] as String?) ?? remote.entityId.replaceFirst('achievement:', '');
    if (badgeId.isEmpty) return;

    // Note: If 'unlocked_at' is absent in the payload, HLC timestamp fallback is
    // used. This is bounded-harmless: HLC reflects causal event time, cannot
    // precede an earlier recorded local unlock timestamp, and
    // unlockedAt.isBefore(existing.unlockedAt) protects historical truth.
    final unlockedAt = _eventTimeOrHlcFallback(payload, const ['unlocked_at', 'unlockedAt'], remote.hlc);
    final existing = await (_db.select(_db.achievementUnlocks)..where((t) => t.achievementId.equals(badgeId))).getSingleOrNull();
    if (existing != null) {
      if (unlockedAt.isBefore(existing.unlockedAt)) {
        await (_db.update(_db.achievementUnlocks)..where((t) => t.id.equals(existing.id))).write(
          AchievementUnlocksCompanion(unlockedAt: Value(unlockedAt)),
        );
      }
    } else {
      await _db.into(_db.achievementUnlocks).insert(
            AchievementUnlocksCompanion.insert(
              achievementId: badgeId,
              unlockedAt: Value(unlockedAt),
            ),
          );
    }
  }

  Future<void> _applyUserProfileMutation(SyncMutation remote) async {
    if (remote.isDeleted) return; // Profiles are not deleted via sync
    final payload = remote.payload;
    if (payload == null) return;

    final existingProfile = await (_db.select(_db.userProfiles)..limit(1)).getSingleOrNull();
    final now = DateTime.now().toUtc();

    if (existingProfile != null) {
      await (_db.update(_db.userProfiles)..where((t) => t.id.equals(existingProfile.id))).write(
        UserProfilesCompanion(
          name: payload['name'] != null ? Value(payload['name'] as String) : const Value.absent(),
          age: payload['age'] != null ? Value((payload['age'] as num).toInt()) : const Value.absent(),
          height: payload['height'] != null ? Value((payload['height'] as num).toDouble()) : const Value.absent(),
          weight: payload['weight'] != null ? Value((payload['weight'] as num).toDouble()) : const Value.absent(),
          sex: payload['sex'] != null ? Value(payload['sex'] as String) : const Value.absent(),
          activityLevel: payload['activity_level'] != null ? Value(payload['activity_level'] as String) : const Value.absent(),
          goal: payload['goal'] != null ? Value(payload['goal'] as String) : const Value.absent(),
          dietPreference: payload['diet_preference'] != null ? Value(payload['diet_preference'] as String) : const Value.absent(),
          calorieGoal: payload['calorie_goal'] != null ? Value((payload['calorie_goal'] as num).toInt()) : const Value.absent(),
          proteinGoal: payload['protein_goal'] != null ? Value((payload['protein_goal'] as num).toDouble()) : const Value.absent(),
          carbsGoal: payload['carbs_goal'] != null ? Value((payload['carbs_goal'] as num).toDouble()) : const Value.absent(),
          fatGoal: payload['fat_goal'] != null ? Value((payload['fat_goal'] as num).toDouble()) : const Value.absent(),
          equipmentAccess: payload['equipment_access'] != null ? Value(payload['equipment_access'] as String) : const Value.absent(),
          injuriesLimitations: payload['injuries_limitations'] != null ? Value(payload['injuries_limitations'] as String) : const Value.absent(),
          updatedAt: Value(now),
        ),
      );
    } else {
      await _db.into(_db.userProfiles).insert(
            UserProfilesCompanion.insert(
              name: Value(payload['name'] as String? ?? ''),
              age: Value((payload['age'] as num?)?.toInt() ?? 25),
              height: Value((payload['height'] as num?)?.toDouble() ?? 170.0),
              weight: Value((payload['weight'] as num?)?.toDouble() ?? 70.0),
              sex: Value(payload['sex'] as String? ?? 'male'),
              activityLevel: Value(payload['activity_level'] as String? ?? 'moderate'),
              goal: Value(payload['goal'] as String? ?? 'maintain'),
              dietPreference: Value(payload['diet_preference'] as String? ?? 'balanced'),
              calorieGoal: Value((payload['calorie_goal'] as num?)?.toInt() ?? 2000),
              proteinGoal: Value((payload['protein_goal'] as num?)?.toDouble() ?? 140.0),
              carbsGoal: Value((payload['carbs_goal'] as num?)?.toDouble() ?? 220.0),
              fatGoal: Value((payload['fat_goal'] as num?)?.toDouble() ?? 60.0),
              equipmentAccess: Value(payload['equipment_access'] as String? ?? 'full_gym'),
              injuriesLimitations: Value(payload['injuries_limitations'] as String? ?? ''),
              updatedAt: Value(now),
            ),
          );
    }

    // Mirror to SharedPreferences
    if (payload['name'] != null) await _prefs.setString('user_name', payload['name'] as String);
    if (payload['age'] != null) await _prefs.setInt('user_age', (payload['age'] as num).toInt());
    if (payload['height'] != null) await _prefs.setDouble('user_height', (payload['height'] as num).toDouble());
    if (payload['weight'] != null) {
      final w = (payload['weight'] as num).toDouble();
      await _prefs.setDouble('user_weight', w);
      await _prefs.setDouble('current_weight', w);
    }
    if (payload['sex'] != null) await _prefs.setString('user_sex', payload['sex'] as String);
    if (payload['activity_level'] != null) await _prefs.setString('user_activity_level', payload['activity_level'] as String);
    if (payload['goal'] != null) await _prefs.setString('user_goal', payload['goal'] as String);
    if (payload['diet_preference'] != null) await _prefs.setString('user_diet_preference', payload['diet_preference'] as String);
    if (payload['calorie_goal'] != null) await _prefs.setInt('calorie_goal', (payload['calorie_goal'] as num).toInt());
    if (payload['protein_goal'] != null) await _prefs.setDouble('protein_goal', (payload['protein_goal'] as num).toDouble());
    if (payload['carbs_goal'] != null) await _prefs.setDouble('carbs_goal', (payload['carbs_goal'] as num).toDouble());
    if (payload['fat_goal'] != null) await _prefs.setDouble('fat_goal', (payload['fat_goal'] as num).toDouble());
  }

  Future<void> _applyUserSettingMutation(SyncMutation remote) async {
    final settingKey = (remote.payload?['key'] as String?) ?? remote.entityId;
    if (!SyncConflictResolver.isSettingKeySyncable(settingKey)) {
      // Invariant: Non-allowlisted or denylisted settings are rejected.
      return;
    }

    if (remote.isDeleted) {
      await (_db.delete(_db.userSettings)..where((t) => t.key.equals(settingKey))).go();
      await _prefs.remove(settingKey);
      return;
    }

    final payload = remote.payload;
    if (payload == null || !payload.containsKey('value')) return;

    final rawVal = payload['value'];
    final strValue = rawVal.toString();

    await _db.into(_db.userSettings).insertOnConflictUpdate(
          UserSettingsCompanion(
            key: Value(settingKey),
            value: Value(strValue),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    if (rawVal is int) {
      await _prefs.setInt(settingKey, rawVal);
    } else if (rawVal is double) {
      await _prefs.setDouble(settingKey, rawVal);
    } else if (rawVal is bool) {
      await _prefs.setBool(settingKey, rawVal);
    } else {
      await _prefs.setString(settingKey, strValue);
    }
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
