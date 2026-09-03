import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../capabilities/account_capability.dart';
import '../capabilities/cloud_backup_capability.dart';
import '../capabilities/connected_status.dart';
import '../capabilities/network_capability.dart';
import '../outbox/outbox_operation.dart';
import '../outbox/outbox_repository.dart';
import 'backup_v10.dart';
import 'cloud_backup_api_client.dart';
import 'cloud_backup_api_contract.dart';
import 'cloud_backup_envelope_manager.dart';

/// Central service engine implementing [CloudBackupCapability].
///
/// Coordinates V10 export, client-side AES-256-GCM envelope encryption,
/// content fingerprint deduplication, background outbox queuing, and
/// remote REST dispatch.
class CloudBackupService implements CloudBackupCapability {
  static const String lastSuccessKey = 'cloud_backup_last_success_utc';
  static const String lastFingerprintKey = 'cloud_backup_last_fingerprint_v1';
  static const String wifiOnlyPrefKey = 'cloud_backup_wifi_only';

  final AppDatabase _db;
  final SharedPreferences _prefs;
  final CloudBackupEnvelopeManager _envelopeManager;
  final AccountCapability _account;
  final NetworkCapability _network;
  final OutboxRepository _outbox;
  final CloudBackupApiClient _apiClient;
  final String _kmsSecret;

  CloudBackupService({
    required AppDatabase db,
    required SharedPreferences prefs,
    CloudBackupEnvelopeManager? envelopeManager,
    AccountCapability? account,
    NetworkCapability? network,
    OutboxRepository? outbox,
    CloudBackupApiClient? apiClient,
    String? kmsSecret,
  })  : _db = db,
        _prefs = prefs,
        _envelopeManager = envelopeManager ?? CloudBackupEnvelopeManager(),
        _account = account ?? const NoOpAccountCapability(),
        _network = network ?? const OfflineNetworkCapability(),
        _outbox = outbox ?? InMemoryOutboxRepository(),
        _apiClient = apiClient ?? InMemoryCloudBackupApiClient(),
        _kmsSecret = kmsSecret ?? 'default-local-device-kms-secret';

  DateTime? get lastSuccessUtc {
    final raw = _prefs.getString(lastSuccessKey);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  String? get lastFingerprint => _prefs.getString(lastFingerprintKey);

  @override
  Future<ConnectedStatusState> getStatus() async {
    final isAuth = await _account.isAuthenticated;
    if (!isAuth) {
      return const ConnectedStatusState(
        status: ConnectedStatus.authenticationRequired,
      );
    }

    final pendingOps = await _outbox.getPendingOperations();
    final backupPendingCount = pendingOps
        .where((op) => op.domain == OutboxDomain.backup)
        .length;

    if (backupPendingCount > 0) {
      if (!_network.isConnected) {
        return ConnectedStatusState.offline(
          lastSuccessUtc: lastSuccessUtc,
          pendingCount: backupPendingCount,
        );
      }
      return ConnectedStatusState.pending(
        count: backupPendingCount,
        lastSuccessUtc: lastSuccessUtc,
      );
    }

    if (!_network.isConnected) {
      return ConnectedStatusState.offline(
        lastSuccessUtc: lastSuccessUtc,
      );
    }

    if (lastSuccessUtc != null) {
      return ConnectedStatusState.synced(lastSuccessUtc: lastSuccessUtc);
    }

    return const ConnectedStatusState.neverConfigured();
  }

  /// Exports current local database to V10 format, encrypts the payload,
  /// and either uploads immediately (if [isManual] and connected) or queues
  /// into the durable outbox for background delivery.
  @override
  Future<bool> createAndUploadSnapshot({
    bool isManual = false,
    bool isWeeklyMilestone = false,
  }) async {
    final isAuth = await _account.isAuthenticated;
    if (!isAuth) {
      return false;
    }

    // 1. Export database to canonical V10 JSON
    final backupData = await BackupV10Data.createFromDatabase(_db, _prefs);
    final dataMap = backupData.toJson();
    final plaintextJson = jsonEncode(dataMap);

    // 2. Check content-stable fingerprint (excluding snapshot timestamp) to avoid redundant uploads
    final currentFingerprint = computeContentFingerprint(dataMap);
    if (currentFingerprint == lastFingerprint && lastSuccessUtc != null) {
      // Content unchanged, skip upload
      return true;
    }

    // 3. Encrypt snapshot locally using AES-256-GCM envelope
    final now = DateTime.now().toUtc();
    final snapshotId = 'snap-${now.millisecondsSinceEpoch}';
    final envelope = _envelopeManager.encryptSnapshot(
      snapshotId: snapshotId,
      plaintextJson: plaintextJson,
      kmsKeyWrappingSecret: _kmsSecret,
      schemaVersion: _db.schemaVersion,
      backupFormatVersion: BackupV10Data.currentVersion,
    );

    final deviceName = await _account.deviceId;
    final uploadRequest = CloudBackupSnapshotUploadRequest(
      snapshotId: snapshotId,
      ciphertextBase64: base64.encode(envelope.ciphertextBytes),
      wrappedKeyBase64: base64.encode(envelope.wrappedKeyBytes),
      sha256Checksum: envelope.sha256Checksum,
      byteSize: envelope.byteSize,
      schemaVersion: envelope.schemaVersion,
      backupFormatVersion: envelope.backupFormatVersion,
      deviceName: deviceName,
      isWeeklyMilestone: isWeeklyMilestone,
    );

    // 4. Check network policy
    final wifiOnly = _prefs.getBool(wifiOnlyPrefKey) ?? false;
    final canConnect = _network.canExecuteOperation(requireWifi: wifiOnly);

    if (isManual && canConnect) {
      try {
        await _apiClient.uploadSnapshot(uploadRequest);
        await _recordSuccessfulUpload(now, currentFingerprint);
        return true;
      } catch (_) {
        // Fall back to outbox queueing on unexpected failure
      }
    }

    // 5. Enqueue in Outbox for guaranteed background delivery
    final outboxOp = OutboxOperation(
      operationId: 'op-$snapshotId',
      idempotencyKey: 'backup:$snapshotId:upload',
      domain: OutboxDomain.backup,
      action: 'upload_snapshot',
      entityId: snapshotId,
      payload: uploadRequest.toJson(),
      createdAtUtc: now,
      scheduledAtUtc: now,
    );
    await _outbox.enqueue(outboxOp);
    return true;
  }

  /// Processes a background outbox operation for cloud backup.
  Future<bool> processOutboxBackup(OutboxOperation operation) async {
    if (operation.domain != OutboxDomain.backup) return false;

    final request = CloudBackupSnapshotUploadRequest.fromJson(operation.payload);
    await _outbox.markInFlight(operation.operationId);

    try {
      await _apiClient.uploadSnapshot(request);
      await _outbox.markSucceeded(operation.operationId);

      final now = DateTime.now().toUtc();
      final fingerprint = request.sha256Checksum;
      await _recordSuccessfulUpload(now, fingerprint);
      return true;
    } catch (e) {
      final isRetryable = e is! FormatException;
      await _outbox.markFailed(
        operation.operationId,
        error: e.toString(),
        isRetryable: isRetryable,
      );
      return false;
    }
  }

  Future<void> _recordSuccessfulUpload(DateTime timestamp, String fingerprint) async {
    await _prefs.setString(lastSuccessKey, timestamp.toIso8601String());
    await _prefs.setString(lastFingerprintKey, fingerprint);
  }

  @override
  Future<bool> uploadSnapshot({
    required String snapshotId,
    required List<int> encryptedBytes,
    required Map<String, dynamic> metadata,
  }) async {
    final request = CloudBackupSnapshotUploadRequest(
      snapshotId: snapshotId,
      ciphertextBase64: base64.encode(encryptedBytes),
      wrappedKeyBase64: metadata['wrappedKeyBase64'] as String? ?? '',
      sha256Checksum: metadata['sha256Checksum'] as String? ?? '',
      byteSize: encryptedBytes.length,
      schemaVersion: metadata['schemaVersion'] as int? ?? 20,
      backupFormatVersion: metadata['backupFormatVersion'] as int? ?? 10,
      deviceName: metadata['deviceName'] as String? ?? 'device',
      isWeeklyMilestone: metadata['isWeeklyMilestone'] as bool? ?? false,
    );

    try {
      await _apiClient.uploadSnapshot(request);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<RemoteBackupSnapshotMetadata>> listRemoteSnapshots() async {
    try {
      final response = await _apiClient.listSnapshots();
      return response.snapshots
          .map(
            (s) => RemoteBackupSnapshotMetadata(
              snapshotId: s.snapshotId,
              createdAtUtc: s.createdAtUtc,
              byteSize: s.byteSize,
              schemaVersion: s.schemaVersion,
              backupFormatVersion: s.backupFormatVersion,
              deviceId: s.deviceName,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<int>?> downloadSnapshot(String snapshotId) async {
    try {
      final envelope = await _apiClient.downloadSnapshot(snapshotId);
      return envelope?.ciphertextBytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteRemoteSnapshot(String snapshotId) async {
    await _apiClient.deleteSnapshot(snapshotId);
  }

  /// Downloads and decrypts an encrypted snapshot from cloud storage.
  /// Throws [FormatException] if the snapshot is not found, checksum fails, or decryption fails.
  Future<Map<String, dynamic>> downloadAndDecryptSnapshot(String snapshotId) async {
    final envelope = await _apiClient.downloadSnapshot(snapshotId);
    if (envelope == null) {
      throw FormatException('Cloud backup snapshot "$snapshotId" was not found on the server.');
    }

    final plaintextJson = _envelopeManager.decryptSnapshot(
      envelope: envelope,
      kmsKeyWrappingSecret: _kmsSecret,
    );

    final decoded = jsonDecode(plaintextJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Decrypted cloud backup payload is not a valid JSON object.');
    }
    return decoded;
  }

  /// Atomically restores a cloud backup snapshot into the local SQLite database.
  /// Pre-validates decryption and schema before any database mutation.
  @override
  Future<void> restoreCloudSnapshot(String snapshotId) async {
    final payload = await downloadAndDecryptSnapshot(snapshotId);

    // Perform atomic transaction restore into local SQLite
    await BackupV10Data.fromJson(payload).restoreToDatabase(_db, _prefs);

    // Record restore timestamp and updated content fingerprint
    final now = DateTime.now().toUtc();
    final fingerprint = computeContentFingerprint(payload);
    await _recordSuccessfulUpload(now, fingerprint);
  }

  /// Deletes all cloud backup snapshots for the user (GDPR right to erasure).
  @override
  Future<void> deleteAllRemoteSnapshots() async {
    await _apiClient.deleteAllSnapshots();
    await _prefs.remove(lastSuccessKey);
    await _prefs.remove(lastFingerprintKey);
  }

  /// Computes a deterministic SHA-256 fingerprint of the backup data payload,
  /// ignoring the top-level snapshot generation timestamp.
  static String computeContentFingerprint(Map<String, dynamic> json) {
    final stablePayload = Map<String, dynamic>.from(json)..remove('timestamp');
    final stableJson = jsonEncode(stablePayload);
    return sha256.convert(utf8.encode(stableJson)).toString();
  }
}
