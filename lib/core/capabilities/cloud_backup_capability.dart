import 'connected_status.dart';

/// Metadata for a verified remote encrypted backup snapshot.
class RemoteBackupSnapshotMetadata {
  const RemoteBackupSnapshotMetadata({
    required this.snapshotId,
    required this.createdAtUtc,
    required this.byteSize,
    required this.schemaVersion,
    required this.backupFormatVersion,
    this.deviceId,
  });

  final String snapshotId;
  final DateTime createdAtUtc;
  final int byteSize;
  final int schemaVersion;
  final int backupFormatVersion;
  final String? deviceId;
}

/// Abstract contract for automatic encrypted cloud backup.
///
/// Invariant: Cloud backup uploads immutable serialized snapshots produced by
/// the verified local backup codecs (v5–v10). Manual export and restore always
/// remain available independently of this capability.
abstract class CloudBackupCapability {
  /// Current operational status of cloud backup.
  Future<ConnectedStatusState> getStatus();

  /// Uploads an immutable encrypted backup snapshot payload.
  Future<bool> uploadSnapshot({
    required String snapshotId,
    required List<int> encryptedBytes,
    required Map<String, dynamic> metadata,
  });

  /// Lists eligible remote backup snapshots for the current user/key.
  Future<List<RemoteBackupSnapshotMetadata>> listRemoteSnapshots();

  /// Downloads an encrypted snapshot by ID for local verification and restore.
  Future<List<int>?> downloadSnapshot(String snapshotId);

  /// Deletes a specific remote snapshot by ID.
  Future<void> deleteRemoteSnapshot(String snapshotId);
}

/// Default disabled implementation when cloud backup is not enabled.
class DisabledCloudBackupCapability implements CloudBackupCapability {
  const DisabledCloudBackupCapability();

  @override
  Future<ConnectedStatusState> getStatus() async =>
      const ConnectedStatusState.neverConfigured();

  @override
  Future<bool> uploadSnapshot({
    required String snapshotId,
    required List<int> encryptedBytes,
    required Map<String, dynamic> metadata,
  }) async =>
      false;

  @override
  Future<List<RemoteBackupSnapshotMetadata>> listRemoteSnapshots() async =>
      const [];

  @override
  Future<List<int>?> downloadSnapshot(String snapshotId) async => null;

  @override
  Future<void> deleteRemoteSnapshot(String snapshotId) async {}
}
