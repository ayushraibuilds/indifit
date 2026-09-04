import 'dart:convert';
import 'dart:typed_data';

import 'cloud_backup_api_contract.dart';
import 'cloud_backup_envelope_manager.dart';

/// Abstract client for communicating with the IndiFit Cloud Backup REST service.
abstract class CloudBackupApiClient {
  /// Uploads an encrypted backup snapshot payload and metadata.
  Future<CloudBackupSnapshotSummary> uploadSnapshot(
    CloudBackupSnapshotUploadRequest request, {
    String? authToken,
  });

  /// Lists all stored backup snapshots for the authenticated user.
  Future<CloudBackupListResponse> listSnapshots({String? authToken});

  /// Downloads the encrypted envelope by snapshot ID.
  Future<CloudBackupEncryptedEnvelope?> downloadSnapshot(
    String snapshotId, {
    String? authToken,
  });

  /// Deletes a specific snapshot by ID.
  Future<void> deleteSnapshot(String snapshotId, {String? authToken});

  /// Deletes all cloud backups for the user.
  Future<void> deleteAllSnapshots({String? authToken});
}

/// In-memory mock API client implementing server-side 5+3 retention pruning
/// and error simulation for tests and standalone operation.
class InMemoryCloudBackupApiClient implements CloudBackupApiClient {
  InMemoryCloudBackupApiClient({
    this.simulateNetworkFailure = false,
    this.simulateServerUnavailable = false,
  });

  bool simulateNetworkFailure;
  bool simulateServerUnavailable;

  final Map<String, CloudBackupEncryptedEnvelope> _storedEnvelopes = {};
  final List<CloudBackupSnapshotSummary> _summaries = [];

  void _checkSimulatedErrors() {
    if (simulateNetworkFailure) {
      throw const FormatException('Simulated network failure: connection refused');
    }
    if (simulateServerUnavailable) {
      throw const FormatException('Simulated HTTP 503: Service Temporarily Unavailable');
    }
  }

  @override
  Future<CloudBackupSnapshotSummary> uploadSnapshot(
    CloudBackupSnapshotUploadRequest request, {
    String? authToken,
  }) async {
    _checkSimulatedErrors();

    final ciphertextBytes = Uint8List.fromList(
      base64.decode(request.ciphertextBase64),
    );
    final wrappedKeyBytes = Uint8List.fromList(
      base64.decode(request.wrappedKeyBase64),
    );

    final envelope = CloudBackupEncryptedEnvelope(
      snapshotId: request.snapshotId,
      ciphertextBytes: ciphertextBytes,
      wrappedKeyBytes: wrappedKeyBytes,
      sha256Checksum: request.sha256Checksum,
      byteSize: request.byteSize,
      schemaVersion: request.schemaVersion,
      backupFormatVersion: request.backupFormatVersion,
      createdAtUtc: DateTime.now().toUtc(),
    );

    // Idempotent upsert: retrying the same snapshotId must not duplicate rows.
    final existingIndex =
        _summaries.indexWhere((s) => s.snapshotId == request.snapshotId);
    if (existingIndex != -1) {
      _storedEnvelopes[request.snapshotId] = envelope;
      return _summaries[existingIndex];
    }

    _storedEnvelopes[request.snapshotId] = envelope;

    final summary = CloudBackupSnapshotSummary(
      snapshotId: request.snapshotId,
      createdAtUtc: envelope.createdAtUtc,
      byteSize: request.byteSize,
      schemaVersion: request.schemaVersion,
      backupFormatVersion: request.backupFormatVersion,
      deviceName: request.deviceName,
      isWeeklyMilestone: request.isWeeklyMilestone,
    );

    // Insert at front (newest first)
    _summaries.insert(0, summary);

    // Execute server-side 5+3 retention pruning
    final toPrune = CloudBackupRetentionPolicy.identifySnapshotsToPrune(_summaries);
    for (final pruneId in toPrune) {
      _storedEnvelopes.remove(pruneId);
      _summaries.removeWhere((s) => s.snapshotId == pruneId);
    }

    return summary;
  }

  @override
  Future<CloudBackupListResponse> listSnapshots({String? authToken}) async {
    _checkSimulatedErrors();

    final totalBytes = _summaries.fold<int>(0, (sum, s) => sum + s.byteSize);
    return CloudBackupListResponse(
      snapshots: List.unmodifiable(_summaries),
      totalCount: _summaries.length,
      totalStorageBytes: totalBytes,
    );
  }

  @override
  Future<CloudBackupEncryptedEnvelope?> downloadSnapshot(
    String snapshotId, {
    String? authToken,
  }) async {
    _checkSimulatedErrors();
    return _storedEnvelopes[snapshotId];
  }

  @override
  Future<void> deleteSnapshot(String snapshotId, {String? authToken}) async {
    _checkSimulatedErrors();
    _storedEnvelopes.remove(snapshotId);
    _summaries.removeWhere((s) => s.snapshotId == snapshotId);
  }

  @override
  Future<void> deleteAllSnapshots({String? authToken}) async {
    _checkSimulatedErrors();
    _storedEnvelopes.clear();
    _summaries.clear();
  }

  void clear() {
    _storedEnvelopes.clear();
    _summaries.clear();
  }
}
