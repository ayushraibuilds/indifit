import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

import '../utils/app_logger.dart';
import '../utils/encryption_helper.dart';
import 'backup_schema.dart';
import 'backup_v10.dart';
import 'backup_v8.dart';
import 'backup_v9.dart';

class BackupInspectionResult {
  final BackupEnvelope envelope;
  final BackupData backupData;
  final bool isEncrypted;
  final String profileName;
  final int schemaVersion;
  final String timestamp;
  final Map<String, int> tableCounts;
  final BackupV8Data? backupV8Data;
  final BackupV9Data? backupV9Data;
  final BackupV10Data? backupV10Data;
  final Map<String, dynamic> payload;

  BackupInspectionResult({
    required this.envelope,
    required this.backupData,
    required this.isEncrypted,
    required this.profileName,
    required this.schemaVersion,
    required this.timestamp,
    required this.tableCounts,
    this.backupV8Data,
    this.backupV9Data,
    this.backupV10Data,
    required this.payload,
  });
}

class PickedBackupFile {
  final String name;
  final String content;

  const PickedBackupFile({required this.name, required this.content});
}

class BackupFileAdapter {
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50MB max limit

  /// Lets the platform document picker supply a backup without ever exposing
  /// arbitrary filesystem paths to widgets. A user cancellation is represented
  /// by null; malformed files throw a [FormatException] before inspection.
  static Future<PickedBackupFile?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['indifit-backup', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final selected = result.files.single;
    final lowerName = selected.name.toLowerCase();
    if (!lowerName.endsWith('.indifit-backup') &&
        !lowerName.endsWith('.json')) {
      throw const FormatException(
        'Choose an IndiFit .indifit-backup or .json backup file.',
      );
    }

    final bytes =
        selected.bytes ??
        (selected.path == null
            ? null
            : await File(selected.path!).readAsBytes());
    if (bytes == null) {
      throw const FormatException(
        'The selected backup file could not be read.',
      );
    }
    if (bytes.length > maxFileSizeBytes) {
      throw const FormatException('File exceeds maximum size limit of 50MB.');
    }

    try {
      return PickedBackupFile(
        name: selected.name,
        content: utf8.decode(bytes, allowMalformed: false),
      );
    } on FormatException {
      throw const FormatException('Backup files must be UTF-8 text.');
    }
  }

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
      // Create envelope from a raw versioned payload.
      if ((parsedJson['version'] as num?)?.toInt() ==
          BackupV10Data.currentVersion) {
        final v10 = BackupV10Data.fromJson(parsedJson);
        envelope = BackupEnvelope(
          version: v10.version,
          schemaVersion: v10.schemaVersion,
          timestamp: v10.timestamp,
          isEncrypted: false,
          checksum: sha256.convert(utf8.encode(rawContent)).toString(),
          profileName: v10.legacy.userProfile?.name ?? 'User Profile',
          tableCounts: {
            for (final entry in v10.b05.tables.entries)
              entry.key: entry.value.length,
          },
          payload: rawContent,
        );
      } else if ((parsedJson['version'] as num?)?.toInt() ==
          BackupV9Data.currentVersion) {
        final v9 = BackupV9Data.fromJson(parsedJson);
        envelope = BackupEnvelope(
          version: v9.version,
          schemaVersion: v9.schemaVersion,
          timestamp: v9.timestamp,
          isEncrypted: false,
          checksum: sha256.convert(utf8.encode(rawContent)).toString(),
          profileName: v9.legacy.userProfile?.name ?? 'User Profile',
          tableCounts: {
            for (final entry in v9.adaptiveCoaching.tables.entries)
              entry.key: entry.value.length,
          },
          payload: rawContent,
        );
      } else if ((parsedJson['version'] as num?)?.toInt() ==
          BackupV8Data.currentVersion) {
        final v8 = BackupV8Data.fromJson(parsedJson);
        envelope = BackupEnvelope(
          version: v8.version,
          schemaVersion: v8.schemaVersion,
          timestamp: v8.timestamp,
          isEncrypted: false,
          checksum: sha256.convert(utf8.encode(rawContent)).toString(),
          profileName: v8.legacy.userProfile?.name ?? 'User Profile',
          tableCounts: {
            for (final entry in v8.nutrition.tables.entries)
              entry.key: entry.value.length,
          },
          payload: rawContent,
        );
      } else {
        envelope = BackupEnvelope.create(
          data: BackupData.fromJson(parsedJson),
          payloadText: rawContent,
          isEncrypted: false,
        );
      }
    }

    String jsonPayload = envelope.payload;
    if (envelope.isEncrypted) {
      if (password == null || password.isEmpty) {
        throw const FormatException(
          'ENCRYPTED_BACKUP_PASSWORD_REQUIRED: Backup file is encrypted.',
        );
      }
      try {
        jsonPayload = EncryptionHelper.decrypt(envelope.payload, password);
      } catch (e) {
        throw FormatException(
          'Incorrect encryption password or corrupted payload: $e',
        );
      }
    }

    final payloadMap = jsonDecode(jsonPayload) as Map<String, dynamic>;
    final backupV10Data = envelope.version == BackupV10Data.currentVersion
        ? BackupV10Data.fromJson(payloadMap)
        : null;
    final backupV9Data = envelope.version == BackupV9Data.currentVersion
        ? BackupV9Data.fromJson(payloadMap)
        : null;
    final backupV8Data = envelope.version == BackupV8Data.currentVersion
        ? BackupV8Data.fromJson(payloadMap)
        : null;
    final backupData =
        backupV10Data?.legacy ??
        backupV9Data?.legacy ??
        backupV8Data?.legacy ??
        BackupData.fromJson(payloadMap);
    if (envelope.version !=
        (backupV10Data?.version ??
            backupV9Data?.version ??
            backupV8Data?.version ??
            backupData.version)) {
      throw const FormatException(
        'Backup envelope version does not match its payload version.',
      );
    }

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
              ...?backupV8Data?.nutrition.tables.map(
                (key, rows) => MapEntry(key, rows.length),
              ),
              ...?backupV9Data?.adaptiveCoaching.tables.map(
                (key, rows) => MapEntry(key, rows.length),
              ),
              ...?backupV10Data?.b05.tables.map(
                (key, rows) => MapEntry(key, rows.length),
              ),
            },
      backupV8Data: backupV8Data,
      backupV9Data: backupV9Data,
      backupV10Data: backupV10Data,
      payload: payloadMap,
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

  /// Exports a schema-v17 Backup-v8 payload while retaining the same envelope
  /// checksum and optional encryption protocol as legacy exports.
  static String exportV8ToEnvelopeJson({
    required BackupV8Data data,
    String? password,
  }) {
    final rawDataJson = jsonEncode(data.toJson());
    var finalPayload = rawDataJson;
    var isEncrypted = false;
    if (password != null && password.isNotEmpty) {
      finalPayload = EncryptionHelper.encrypt(rawDataJson, password);
      isEncrypted = true;
    }
    final checksum = sha256.convert(utf8.encode(finalPayload)).toString();
    final legacyEnvelope = BackupEnvelope.create(
      data: data.legacy,
      payloadText: finalPayload,
      isEncrypted: isEncrypted,
    );
    final counts = <String, int>{
      ...legacyEnvelope.tableCounts,
      for (final entry in data.nutrition.tables.entries)
        entry.key: entry.value.length,
    };
    final envelope = BackupEnvelope(
      version: data.version,
      schemaVersion: data.schemaVersion,
      timestamp: data.timestamp,
      isEncrypted: isEncrypted,
      checksum: checksum,
      profileName: data.legacy.userProfile?.name ?? 'User Profile',
      tableCounts: counts,
      payload: finalPayload,
    );
    return jsonEncode(envelope.toJson());
  }

  /// Exports the schema-v18 Backup-v9 payload with the same checksum and
  /// optional encryption protocol used by the earlier envelope versions.
  static String exportV9ToEnvelopeJson({
    required BackupV9Data data,
    String? password,
  }) {
    final rawDataJson = jsonEncode(data.toJson());
    var finalPayload = rawDataJson;
    var isEncrypted = false;
    if (password != null && password.isNotEmpty) {
      finalPayload = EncryptionHelper.encrypt(rawDataJson, password);
      isEncrypted = true;
    }
    final checksum = sha256.convert(utf8.encode(finalPayload)).toString();
    final legacyEnvelope = BackupEnvelope.create(
      data: data.legacy,
      payloadText: finalPayload,
      isEncrypted: isEncrypted,
    );
    final counts = <String, int>{
      ...legacyEnvelope.tableCounts,
      for (final entry in data.nutrition.tables.entries)
        entry.key: entry.value.length,
      for (final entry in data.adaptiveCoaching.tables.entries)
        entry.key: entry.value.length,
    };
    final envelope = BackupEnvelope(
      version: data.version,
      schemaVersion: data.schemaVersion,
      timestamp: data.timestamp,
      isEncrypted: isEncrypted,
      checksum: checksum,
      profileName: data.legacy.userProfile?.name ?? 'User Profile',
      tableCounts: counts,
      payload: finalPayload,
    );
    return jsonEncode(envelope.toJson());
  }

  /// Exports the schema-v19-or-newer Backup-v10 payload, including only
  /// portable B05 preferences and content progress in the envelope counts.
  static String exportV10ToEnvelopeJson({
    required BackupV10Data data,
    String? password,
  }) {
    final rawDataJson = jsonEncode(data.toJson());
    var finalPayload = rawDataJson;
    var isEncrypted = false;
    if (password != null && password.isNotEmpty) {
      finalPayload = EncryptionHelper.encrypt(rawDataJson, password);
      isEncrypted = true;
    }
    final checksum = sha256.convert(utf8.encode(finalPayload)).toString();
    final legacyEnvelope = BackupEnvelope.create(
      data: data.legacy,
      payloadText: finalPayload,
      isEncrypted: isEncrypted,
    );
    final counts = <String, int>{
      ...legacyEnvelope.tableCounts,
      for (final entry in data.nutrition.tables.entries)
        entry.key: entry.value.length,
      for (final entry in data.adaptiveCoaching.tables.entries)
        entry.key: entry.value.length,
      for (final entry in data.b05.tables.entries)
        entry.key: entry.value.length,
    };
    final envelope = BackupEnvelope(
      version: data.version,
      schemaVersion: data.schemaVersion,
      timestamp: data.timestamp,
      isEncrypted: isEncrypted,
      checksum: checksum,
      profileName: data.legacy.userProfile?.name ?? 'User Profile',
      tableCounts: counts,
      payload: finalPayload,
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
