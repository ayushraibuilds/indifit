import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/app_database.dart';
import '../backup/backup_v10.dart';
import '../utils/app_logger.dart';

class AutoBackupService {
  final AppDatabase _db;

  AutoBackupService(this._db);

  static Future<void> performBackup(AppDatabase db) async {
    final service = AutoBackupService(db);
    await service.runAutoBackup();
  }

  Future<void> runAutoBackup() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docDir.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final prefs = await SharedPreferences.getInstance();
      final backupData = await BackupV10Data.createFromDatabase(_db, prefs);
      final jsonStr = jsonEncode(backupData.toJson());

      // Rotate existing backups (1 -> 2, 2 -> 3)
      final f3 = File('${backupDir.path}/indifit_auto_backup_3.json');
      final f2 = File('${backupDir.path}/indifit_auto_backup_2.json');
      final f1 = File('${backupDir.path}/indifit_auto_backup_1.json');

      if (await f2.exists()) {
        await f2.copy(f3.path);
      }
      if (await f1.exists()) {
        await f1.copy(f2.path);
      }

      await f1.writeAsString(jsonStr, flush: true);
      AppLogger.info(
        'Auto-backup snapshot created successfully',
        'AutoBackupService',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Auto-backup snapshot failed',
        e,
        stackTrace,
        'AutoBackupService',
      );
    }
  }

  static Future<String?> getLatestSnapshotContent() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docDir.path}/backups');
      final f1 = File('${backupDir.path}/indifit_auto_backup_1.json');
      if (await f1.exists()) {
        return await f1.readAsString();
      }
    } catch (e) {
      AppLogger.warning('Failed to read auto backup snapshot: $e');
    }
    return null;
  }
}
