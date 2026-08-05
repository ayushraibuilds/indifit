import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../test/fixtures/b03_migration_backup_harness.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final databaseFile = File(B03V16Fixture.completeFixturePath);
  final backupFile = File(B03BackupV7Fixture.completeFixturePath);
  if (databaseFile.existsSync()) databaseFile.deleteSync();
  if (backupFile.existsSync()) backupFile.deleteSync();

  await B03V16Fixture.createGoldenFile(databaseFile);
  await B03BackupV7Fixture.createGoldenFile(backupFile, databaseFile);
}
