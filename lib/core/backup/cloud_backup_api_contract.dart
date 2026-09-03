/// REST API contract and data models for IndiFit Cloud Backup endpoints.
library;

/// Request payload for uploading an encrypted backup snapshot.
class CloudBackupSnapshotUploadRequest {
  const CloudBackupSnapshotUploadRequest({
    required this.snapshotId,
    required this.ciphertextBase64,
    required this.wrappedKeyBase64,
    required this.sha256Checksum,
    required this.byteSize,
    required this.schemaVersion,
    required this.backupFormatVersion,
    required this.deviceName,
    this.isWeeklyMilestone = false,
  });

  final String snapshotId;
  final String ciphertextBase64;
  final String wrappedKeyBase64;
  final String sha256Checksum;
  final int byteSize;
  final int schemaVersion;
  final int backupFormatVersion;
  final String deviceName;
  final bool isWeeklyMilestone;

  Map<String, dynamic> toJson() => {
        'snapshotId': snapshotId,
        'ciphertextBase64': ciphertextBase64,
        'wrappedKeyBase64': wrappedKeyBase64,
        'sha256Checksum': sha256Checksum,
        'byteSize': byteSize,
        'schemaVersion': schemaVersion,
        'backupFormatVersion': backupFormatVersion,
        'deviceName': deviceName,
        'isWeeklyMilestone': isWeeklyMilestone,
      };

  factory CloudBackupSnapshotUploadRequest.fromJson(Map<String, dynamic> json) {
    return CloudBackupSnapshotUploadRequest(
      snapshotId: json['snapshotId'] as String,
      ciphertextBase64: json['ciphertextBase64'] as String,
      wrappedKeyBase64: json['wrappedKeyBase64'] as String,
      sha256Checksum: json['sha256Checksum'] as String,
      byteSize: json['byteSize'] as int,
      schemaVersion: json['schemaVersion'] as int,
      backupFormatVersion: json['backupFormatVersion'] as int,
      deviceName: json['deviceName'] as String,
      isWeeklyMilestone: json['isWeeklyMilestone'] as bool? ?? false,
    );
  }
}

/// Metadata summary of a stored cloud backup snapshot.
class CloudBackupSnapshotSummary {
  const CloudBackupSnapshotSummary({
    required this.snapshotId,
    required this.createdAtUtc,
    required this.byteSize,
    required this.schemaVersion,
    required this.backupFormatVersion,
    required this.deviceName,
    this.isWeeklyMilestone = false,
  });

  final String snapshotId;
  final DateTime createdAtUtc;
  final int byteSize;
  final int schemaVersion;
  final int backupFormatVersion;
  final String deviceName;
  final bool isWeeklyMilestone;

  Map<String, dynamic> toJson() => {
        'snapshotId': snapshotId,
        'createdAtUtc': createdAtUtc.toIso8601String(),
        'byteSize': byteSize,
        'schemaVersion': schemaVersion,
        'backupFormatVersion': backupFormatVersion,
        'deviceName': deviceName,
        'isWeeklyMilestone': isWeeklyMilestone,
      };

  factory CloudBackupSnapshotSummary.fromJson(Map<String, dynamic> json) {
    return CloudBackupSnapshotSummary(
      snapshotId: json['snapshotId'] as String,
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
      byteSize: json['byteSize'] as int,
      schemaVersion: json['schemaVersion'] as int,
      backupFormatVersion: json['backupFormatVersion'] as int,
      deviceName: json['deviceName'] as String,
      isWeeklyMilestone: json['isWeeklyMilestone'] as bool? ?? false,
    );
  }
}

/// Response returned by GET /v1/backup/snapshots.
class CloudBackupListResponse {
  const CloudBackupListResponse({
    required this.snapshots,
    required this.totalCount,
    required this.totalStorageBytes,
  });

  final List<CloudBackupSnapshotSummary> snapshots;
  final int totalCount;
  final int totalStorageBytes;

  Map<String, dynamic> toJson() => {
        'snapshots': snapshots.map((s) => s.toJson()).toList(),
        'totalCount': totalCount,
        'totalStorageBytes': totalStorageBytes,
      };

  factory CloudBackupListResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['snapshots'] as List)
        .map((item) => CloudBackupSnapshotSummary.fromJson(item as Map<String, dynamic>))
        .toList();
    return CloudBackupListResponse(
      snapshots: list,
      totalCount: json['totalCount'] as int,
      totalStorageBytes: json['totalStorageBytes'] as int,
    );
  }
}

/// Evaluates snapshot retention policy according to the 5 daily + 3 weekly milestone rule (8 total max).
class CloudBackupRetentionPolicy {
  static const int maxDailyCount = 5;
  static const int maxWeeklyCount = 3;
  static const int maxTotalCount = 8;

  /// Given a list of existing snapshots ordered newest to oldest, returns the list of
  /// snapshot IDs that should be pruned/deleted.
  static List<String> identifySnapshotsToPrune(List<CloudBackupSnapshotSummary> existing) {
    final dailySnapshots = existing.where((s) => !s.isWeeklyMilestone).toList();
    final weeklySnapshots = existing.where((s) => s.isWeeklyMilestone).toList();

    final toPrune = <String>[];

    // Prune excess daily snapshots beyond 5 (oldest first)
    if (dailySnapshots.length > maxDailyCount) {
      final excessDaily = dailySnapshots.sublist(maxDailyCount);
      toPrune.addAll(excessDaily.map((s) => s.snapshotId));
    }

    // Prune excess weekly snapshots beyond 3 (oldest first)
    if (weeklySnapshots.length > maxWeeklyCount) {
      final excessWeekly = weeklySnapshots.sublist(maxWeeklyCount);
      toPrune.addAll(excessWeekly.map((s) => s.snapshotId));
    }

    // If still above 8 total, prune remaining oldest
    final remaining = existing.where((s) => !toPrune.contains(s.snapshotId)).toList();
    if (remaining.length > maxTotalCount) {
      final excess = remaining.sublist(maxTotalCount);
      toPrune.addAll(excess.map((s) => s.snapshotId));
    }

    return toPrune;
  }
}
