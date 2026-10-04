part of '../app_database.dart';

/// The database file in the app documents folder. SQLite may keep `-wal`,
/// `-shm` or `-journal` files beside it.
const kDatabaseFileName = 'indifit.db';
const kDatabaseSidecarSuffixes = ['-wal', '-shm', '-journal'];

LazyDatabase _openConnection() {
  final token = AppDatabase.rootIsolateToken ?? RootIsolateToken.instance;
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    await PlatformStorageProtection.protectSensitivePath(dbFolder.path);
    final file = File(p.join(dbFolder.path, kDatabaseFileName));
    for (final suffix in const ['', ...kDatabaseSidecarSuffixes]) {
      final existingFile = File('${file.path}$suffix');
      if (await existingFile.exists()) {
        await PlatformStorageProtection.protectSensitivePath(existingFile.path);
      }
    }
    return NativeDatabase.createInBackground(
      file,
      isolateSetup: token != null
          ? () => BackgroundIsolateBinaryMessenger.ensureInitialized(token)
          : null,
    );
  });
}
