import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../backup/backup_file_adapter.dart';
import '../backup/backup_v10.dart';
import '../config/app_preferences_keys.dart';
import '../utils/app_logger.dart';
import 'auto_backup_secret_store.dart';
import 'platform_storage_protection.dart';

class AutoBackupService {
  static const String _lastContentFingerprintKey =
      AppPreferenceKeys.autoBackupLastContentFingerprintV2;

  final AppDatabase _db;
  final AutoBackupSecretStore _secretStore;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final SharedPreferences? _prefs;

  AutoBackupService(
    this._db, {
    SharedPreferences? prefs,
    AutoBackupSecretStore secretStore = const SecureAutoBackupSecretStore(),
    Future<Directory> Function() documentsDirectoryProvider =
        getApplicationDocumentsDirectory,
  }) : _prefs = prefs,
       _secretStore = secretStore,
       _documentsDirectoryProvider = documentsDirectoryProvider;

  static Future<void> performBackup(AppDatabase db, [SharedPreferences? prefs]) async {
    await AutoBackupService(db, prefs: prefs).runAutoBackup();
  }

  Future<void> runAutoBackup() async {
    try {
      final docDir = await _documentsDirectoryProvider();
      final backupDir = Directory('${docDir.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      await PlatformStorageProtection.protectSensitivePath(backupDir.path);

      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final backupData = await BackupV10Data.createFromDatabase(_db, prefs);
      final contentFingerprint = _contentFingerprint(backupData.toJson());

      final f3 = File('${backupDir.path}/indifit_auto_backup_3.json');
      final f2 = File('${backupDir.path}/indifit_auto_backup_2.json');
      final f1 = File('${backupDir.path}/indifit_auto_backup_1.json');
      for (final existingBackup in [f1, f2, f3]) {
        if (await existingBackup.exists()) {
          await PlatformStorageProtection.protectSensitivePath(
            existingBackup.path,
          );
        }
      }

      final lastFingerprint = prefs.getString(_lastContentFingerprintKey);
      if (lastFingerprint == contentFingerprint &&
          await f1.exists() &&
          await _isEncryptedEnvelope(f1)) {
        AppLogger.info(
          'Auto-backup skipped because local data is unchanged',
          'AutoBackupService',
        );
        return;
      }

      final deviceSecret = await _secretStore.readOrCreate();
      final envelopeJson =
          await BackupFileAdapter.exportV10ToDeviceRecoveryEnvelopeJson(
            data: backupData,
            deviceSecret: deviceSecret,
          );

      if (await f2.exists()) {
        await f2.copy(f3.path);
      }
      if (await f1.exists()) {
        await f1.copy(f2.path);
      }
      await f1.writeAsString(envelopeJson, flush: true);
      await prefs.setString(_lastContentFingerprintKey, contentFingerprint);
      AppLogger.info(
        'Encrypted auto-backup snapshot created successfully',
        'AutoBackupService',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Auto-backup snapshot failed',
        error,
        stackTrace,
        'AutoBackupService',
      );
    }
  }

  /// Returns the newest readable recovery payload as plaintext in memory.
  /// Files remain encrypted at rest; legacy plaintext snapshots are still
  /// accepted so an upgrade never destroys the user's recovery path.
  static Future<String?> getLatestSnapshotContent({
    AutoBackupSecretStore secretStore = const SecureAutoBackupSecretStore(),
    Future<Directory> Function() documentsDirectoryProvider =
        getApplicationDocumentsDirectory,
  }) async {
    try {
      final docDir = await documentsDirectoryProvider();
      final backupDir = Directory('${docDir.path}/backups');
      String? deviceSecret;
      try {
        deviceSecret = await secretStore.read();
      } catch (error) {
        AppLogger.warning('Failed to read automatic-backup device key: $error');
      }

      for (var index = 1; index <= 3; index++) {
        final file = File('${backupDir.path}/indifit_auto_backup_$index.json');
        if (!await file.exists()) continue;
        try {
          final rawContent = await file.readAsString();
          final encrypted = _rawContentIsEncryptedEnvelope(rawContent);
          if (encrypted && (deviceSecret == null || deviceSecret.isEmpty)) {
            continue;
          }
          final inspection = await BackupFileAdapter.inspectBackupContent(
            rawContent,
            password: encrypted ? deviceSecret : null,
          );
          return jsonEncode(inspection.payload);
        } catch (error) {
          AppLogger.warning(
            'Automatic backup $index is unreadable; trying older copy: $error',
          );
        }
      }
    } catch (error) {
      AppLogger.warning('Failed to read auto backup snapshot: $error');
    }
    return null;
  }

  static String _contentFingerprint(Map<String, dynamic> json) {
    // Backup-v10's top-level timestamp records when the snapshot was made,
    // not a user-data change. Preserve every nested timestamp because those
    // may be authoritative row data that must trigger a new recovery copy.
    final stablePayload = Map<String, dynamic>.from(json)..remove('timestamp');
    final stableJson = jsonEncode(stablePayload);
    return sha256.convert(utf8.encode(stableJson)).toString();
  }

  static Future<bool> _isEncryptedEnvelope(File file) async {
    try {
      return _rawContentIsEncryptedEnvelope(await file.readAsString());
    } catch (_) {
      return false;
    }
  }

  static bool _rawContentIsEncryptedEnvelope(String rawContent) {
    try {
      final json = jsonDecode(rawContent);
      return json is Map<String, dynamic> &&
          json['format_identifier'] == 'INDIFIT_BACKUP_ENVELOPE' &&
          json['is_encrypted'] == true;
    } catch (_) {
      return false;
    }
  }
}
