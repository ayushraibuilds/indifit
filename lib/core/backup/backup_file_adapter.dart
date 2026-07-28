import 'dart:convert';
import 'dart:io';

import '../utils/app_logger.dart';
import '../utils/encryption_helper.dart';
import 'backup_schema.dart';

class BackupInspectionResult {
  final BackupEnvelope envelope;
  final BackupData backupData;
  final bool isEncrypted;
  final String profileName;
  final int schemaVersion;
  final String timestamp;
  final Map<String, int> tableCounts;

  BackupInspectionResult({
    required this.envelope,
    required this.backupData,
    required this.isEncrypted,
    required this.profileName,
    required this.schemaVersion,
    required this.timestamp,
    required this.tableCounts,
  });
}

class BackupFileAdapter {
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50MB max limit

  /// Reads and inspects a `.indifit-backup` or `.json` file content platform-safely.
  /// Throws [FormatException] if validation fails.
  static Future<BackupInspectionResult> inspectBackupContent(
    String rawContent, {
    String? password,
  }) async {
    if (rawContent.length > maxFileSizeBytes) {
      throw const FormatException('File exceeds maximum size limit of 50MB.');
    }

    dynamic parsedJson;
    try {
      parsedJson = jsonDecode(rawContent);
    } catch (e) {
      throw FormatException('Invalid JSON payload in backup file: $e');
    }

    if (parsedJson is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup payload format.');
    }

    BackupEnvelope envelope;
    if (parsedJson.containsKey('format_identifier') &&
        parsedJson['format_identifier'] == 'INDIFIT_BACKUP_ENVELOPE') {
      envelope = BackupEnvelope.fromJson(parsedJson);
    } else {
      // Create envelope from legacy raw json payload
      final legacyData = BackupData.fromJson(parsedJson);
      envelope = BackupEnvelope.create(
        data: legacyData,
        payloadText: rawContent,
        isEncrypted: false,
      );
    }

    String jsonPayload = envelope.payload;
    if (envelope.isEncrypted) {
      if (password == null || password.isEmpty) {
        throw const FormatException(
          'ENCRYPTED_BACKUP_PASSWORD_REQUIRED: Backup file is encrypted.',
        );
      }
      try {
        jsonPayload = EncryptionHelper.decrypt(
          envelope.payload,
          password,
        );
      } catch (e) {
        throw FormatException(
          'Incorrect encryption password or corrupted payload: $e',
        );
      }
    }

    final payloadMap = jsonDecode(jsonPayload) as Map<String, dynamic>;
    final backupData = BackupData.fromJson(payloadMap);

    return BackupInspectionResult(
      envelope: envelope,
      backupData: backupData,
      isEncrypted: envelope.isEncrypted,
      profileName: envelope.profileName.isNotEmpty
          ? envelope.profileName
          : (backupData.userProfile?.name ?? 'User Profile'),
      schemaVersion: envelope.schemaVersion,
      timestamp: envelope.timestamp,
      tableCounts: envelope.tableCounts.isNotEmpty
          ? envelope.tableCounts
          : {
              'food_logs': backupData.foodLogs.length,
              'workout_sessions': backupData.workoutSessions.length,
              'workout_sets': backupData.workoutSets.length,
              'body_measurements': backupData.bodyMeasurements.length,
              'daily_hydrations': backupData.dailyHydrations.length,
              'achievement_unlocks': backupData.achievementUnlocks.length,
            },
    );
  }

  /// Exports BackupData into a formatted .indifit-backup JSON string envelope.
  static String exportToEnvelopeJson({
    required BackupData data,
    String? password,
  }) {
    final rawDataJson = jsonEncode(data.toJson());
    String finalPayload = rawDataJson;
    bool isEncrypted = false;

    if (password != null && password.isNotEmpty) {
      finalPayload = EncryptionHelper.encrypt(rawDataJson, password);
      isEncrypted = true;
    }

    final envelope = BackupEnvelope.create(
      data: data,
      payloadText: finalPayload,
      isEncrypted: isEncrypted,
    );

    return jsonEncode(envelope.toJson());
  }

  /// Helper to safely clean up temporary export files
  static Future<void> cleanupTempFile(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.warning('Temp backup file cleanup error: $e');
    }
  }
}
