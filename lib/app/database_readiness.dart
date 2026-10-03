import 'dart:io';

import 'package:drift/native.dart' show SqliteException;
// Only for the type check: drift wraps errors from its background isolate.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/di/core_providers.dart';
import '../core/services/crash_reporting_service.dart';
import '../core/utils/app_logger.dart';
import '../data/database/app_database.dart';

/// Completes once the database is open: migrations and the per-launch repairs
/// in `beforeOpen` have run. Fails if it can't be opened. There is no timeout,
/// on purpose: a slow upgrade must show "getting your data ready", never an
/// error (an export taken mid-migration would be half-migrated).
final databaseReadyProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  try {
    await db.customSelect('SELECT 1').get();
  } on Object catch (error, stackTrace) {
    AppLogger.error('Database could not be opened', error, stackTrace);
    CrashReportingService.recordCrash(
      error,
      stackTrace,
      reason: 'Database open failed',
    );
    rethrow;
  }
});

/// Why the database couldn't be opened, in terms the recovery screen can act on.
enum DatabaseOpenFailure { storageFull, other }

DatabaseOpenFailure classifyDatabaseOpenFailure(Object error) {
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  // SQLITE_FULL is 13; extended codes keep it in the low byte.
  if (cause is SqliteException && (cause.extendedResultCode & 0xff) == 13) {
    return DatabaseOpenFailure.storageFull;
  }
  if (cause is FileSystemException && cause.osError?.errorCode == 28) {
    return DatabaseOpenFailure.storageFull; // ENOSPC
  }
  return DatabaseOpenFailure.other;
}

/// The database file plus whichever SQLite sidecar files exist, for export.
Future<List<File>> existingDatabaseFiles() async {
  final folder = await getApplicationDocumentsDirectory();
  final main = File(p.join(folder.path, kDatabaseFileName));
  return [
    for (final suffix in ['', ...kDatabaseSidecarSuffixes])
      if (await File('${main.path}$suffix').exists())
        File('${main.path}$suffix'),
  ];
}
