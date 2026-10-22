import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/auto_backup_service.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../settings_controller.dart';

/// Takes a fresh recovery copy now. Replaced in tests.
final freshBackupProvider = Provider<Future<AutoBackupOutcome> Function()>(
  (ref) =>
      () => AutoBackupService(ref.read(databaseProvider)).runAutoBackup(),
);

/// Saves a fresh recovery copy before data is replaced (R-06), and waits for
/// it. Returns whether to go on: true when the copy was saved (or nothing
/// changed since the last one), or when the user chose to continue without
/// one after it failed.
Future<bool> ensureFreshBackup(BuildContext context, WidgetRef ref) async {
  final outcome = await ref.read(freshBackupProvider)();
  if (outcome != AutoBackupOutcome.failed) return true;
  if (!context.mounted) return false;
  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Continue without a fresh backup?'),
      content: Text(
        "IndiFit couldn't save a recovery copy of your current data. "
        'If you go on, the data on this device now can’t be brought back.',
        style: B05Typography.body(dialogCtx),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogCtx, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return proceed ?? false;
}

/// Exports a backup file the user keeps. Replaced in tests.
typedef BackupFileExport = Future<SettingsExportStatus?> Function();

/// Before an erase (N14-13). An automatic copy would be erased with
/// everything else, so this offers a backup file the user saves somewhere
/// they choose. Returns whether to go on to the erase confirmation: after a
/// file was shared, or when the user chose to erase without one.
Future<bool> offerBackupBeforeErase(
  BuildContext context, {
  required BackupFileExport export,
}) async {
  final choice = await showDialog<_EraseCopyChoice>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Keep a copy before erasing?'),
      content: Text(
        'Erasing also deletes the recovery copies on this phone. Export a '
        'backup file to keep your data somewhere you choose.',
        style: B05Typography.body(dialogCtx),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, _EraseCopyChoice.skip),
          child: const Text('Erase without a copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogCtx, _EraseCopyChoice.export),
          child: const Text('Export backup file'),
        ),
      ],
    ),
  );
  switch (choice) {
    case null:
      return false;
    case _EraseCopyChoice.skip:
      return true;
    case _EraseCopyChoice.export:
      // Erase goes on only once the file has been handed over.
      return await export() == SettingsExportStatus.shared;
  }
}

enum _EraseCopyChoice { export, skip }
