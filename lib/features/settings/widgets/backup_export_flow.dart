import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/product_failure_presentation.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../settings_controller.dart';

/// The encrypted backup export through the share sheet, shared by
/// Settings → Manage your data, the "Your data, your phone" card and the
/// export reminder. Returns the outcome, or null when cancelled before
/// sharing.
Future<SettingsExportStatus?> showBackupExportFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  final passwordController = TextEditingController();
  try {
    final password = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Create a backup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creates an IndiFit backup file and opens your device’s sharing options. It is kept temporarily while you choose where to save it. Add a password if you want the file protected.',
                style: B05Typography.body(dialogCtx),
              ),
              const SizedBox(height: B05Layout.space16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Optional password',
                  hintText: 'Leave blank for an unprotected file',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, passwordController.text),
            child: const Text('Create backup'),
          ),
        ],
      ),
    );

    if (password == null || !context.mounted) return null;
    final result = await ref
        .read(settingsControllerProvider.notifier)
        .performExport(password);
    if (!context.mounted) return result.status;

    final message = switch (result.status) {
      SettingsExportStatus.shared =>
        'Sharing completed. Check the destination you chose before relying on this backup.',
      SettingsExportStatus.cancelled =>
        result.message ?? 'No backup was shared.',
      SettingsExportStatus.unavailable =>
        result.message ??
            'Sharing is unavailable on this device. No backup was shared.',
      SettingsExportStatus.failed =>
        result.message ??
            ProductFailurePresentation.fromCode('backup_export_failed').message,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            result.status == SettingsExportStatus.unavailable ||
                result.status == SettingsExportStatus.failed
            ? context.b05Colors.danger.indicator
            : null,
      ),
    );
    return result.status;
  } finally {
    passwordController.dispose();
  }
}
