import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/auto_backup_service.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

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
