part of '../app_database.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    await PlatformStorageProtection.protectSensitivePath(dbFolder.path);
    final file = File(p.join(dbFolder.path, 'indifit.db'));
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final existingFile = File('${file.path}$suffix');
      if (await existingFile.exists()) {
        await PlatformStorageProtection.protectSensitivePath(existingFile.path);
      }
    }
    return NativeDatabase.createInBackground(file);
  });
}
