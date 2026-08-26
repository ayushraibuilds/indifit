import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backup/backup_file_adapter.dart';
import '../../../core/presentation/product_failure_presentation.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auto_backup_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../onboarding/onboarding_screen.dart';
import '../health_sync_hub_screen.dart';
import '../settings_controller.dart';
import 'backup_restore_card.dart';
import 'privacy_disclosure_card.dart';
import 'settings_reminder_toggle.dart';

class DataManagementSection extends ConsumerWidget {
  const DataManagementSection({super.key});

  /// Keeps the synchronous router gate in sync with persisted onboarding
  /// state after restore/erase flows rewrite the preference.
  Future<void> _syncOnboardingGate(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    ref.read(onboardingCompletedProvider.notifier).state =
        prefs.getBool('onboarding_completed') ?? false;
  }

  void _showExportDialog(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Export & Encrypt Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a password to protect your backup file. If you leave this blank, the backup will be exported in plain text.',
              style: TextStyle(
                fontSize: 12,
                color: dialogCtx.b05Colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Backup Password (Optional)',
                hintText: 'Leave empty for no encryption',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final password = passwordController.text;
              Navigator.pop(dialogCtx);
              final error = await ref
                  .read(settingsControllerProvider.notifier)
                  .performExport(password);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: context.b05Colors.danger.indicator,
                  ),
                );
              }
            },
            child: const Text('Export Backup'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, WidgetRef ref) {
    final backupController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedFileContent;
    String? selectedFileName;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Restore a backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose an IndiFit backup file. You can also paste an older IndiFit export below.',
                  style: TextStyle(
                    fontSize: 12,
                    color: dialogCtx.b05Colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      final selected = await BackupFileAdapter.pickBackupFile();
                      if (selected != null && context.mounted) {
                        setDialogState(() {
                          selectedFileName = selected.name;
                          selectedFileContent = selected.content;
                        });
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'The backup file could not be opened. Try again.',
                            ),
                            backgroundColor: context.b05Colors.danger.indicator,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Choose Backup File'),
                ),
                if (selectedFileName != null) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (innerCtx) => Text(
                      'Selected: $selectedFileName',
                      style: TextStyle(
                        fontSize: 12,
                        color: innerCtx.b05Colors.success.indicator,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: backupController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Optional: paste an older IndiFit export…',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Decryption Password (if encrypted)',
                    hintText: 'Leave blank if unencrypted',
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
              style: FilledButton.styleFrom(
                backgroundColor: dialogCtx.b05Colors.danger.container,
                foregroundColor: dialogCtx.b05Colors.danger.foreground,
              ),
              onPressed: () async {
                final rawContent =
                    selectedFileContent ?? backupController.text.trim();
                final password = passwordController.text;
                if (rawContent.isEmpty) return;

                BackupInspectionResult result;
                try {
                  result = await BackupFileAdapter.inspectBackupContent(
                    rawContent,
                    password: password.isEmpty ? null : password,
                  );
                } catch (_) {
                  if (context.mounted) {
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Backup Inspection Failed'),
                        content: Text(
                          ProductFailurePresentation.fromCode(
                            'backup_inspection_failed',
                          ).message,
                          style: const TextStyle(height: 1.4),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                }

                if (context.mounted) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Restore Inspection Preview'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WARNING: Restoring will replace the data currently on this device.',
                            style: TextStyle(
                              color: ctx.b05Colors.danger.indicator,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Profile: ${result.profileName}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Export Date: ${result.timestamp}'),
                          Text(
                            'Encrypted: ${result.isEncrypted ? "Yes (SHA256 Verified)" : "No"}',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Items in backup:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: ctx.b05Colors.textSecondary,
                            ),
                          ),
                          ...result.tableCounts.entries.map(
                            (e) => Text(
                              '• ${e.key}: ${e.value} items',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: ctx.b05Colors.danger.container,
                            foregroundColor: ctx.b05Colors.danger.foreground,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Restore backup'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    Navigator.pop(dialogCtx);
                    try {
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .performRestore(result.payload);
                      await _syncOnboardingGate(ref);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Backup restored successfully.'),
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Restore failed. Your existing data was not changed.',
                            ),
                            backgroundColor: context.b05Colors.danger.indicator,
                          ),
                        );
                      }
                    }
                  }
                }
              },
              child: const Text('Inspect Backup'),
            ),
          ],
        ),
      ),
    );
  }

  void _restoreFromAutoBackup(BuildContext context, WidgetRef ref) async {
    final rawSnapshot = await AutoBackupService.getLatestSnapshotContent();
    if (rawSnapshot == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No recent automatic backup snapshot found.'),
            backgroundColor: context.b05Colors.danger.indicator,
          ),
        );
      }
      return;
    }

    try {
      final inspection = await BackupFileAdapter.inspectBackupContent(
        rawSnapshot,
      );
      if (!context.mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Auto-Backup Snapshot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Restore from your most recent automatic background snapshot?',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Profile: ${inspection.profileName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Snapshot Date: ${inspection.timestamp}'),
              const SizedBox(height: 8),
              ...inspection.tableCounts.entries.map(
                (e) => Text(
                  '• ${e.key}: ${e.value} items',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore Snapshot'),
            ),
          ],
        ),
      );

      if (confirm == true && context.mounted) {
        await ref
            .read(settingsControllerProvider.notifier)
            .performRestore(inspection.payload);
        await _syncOnboardingGate(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Auto-backup restored successfully!')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Automatic restore failed. Try again.'),
            backgroundColor: context.b05Colors.danger.indicator,
          ),
        );
      }
    }
  }

  void _confirmDeleteAllData(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Local Data?'),
        content: const Text(
          'This action is irreversible. All your logged meals, workout sessions, custom foods, and body measurements will be permanently wiped from this device.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.b05Colors.danger.container,
              foregroundColor: context.b05Colors.danger.foreground,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wipe Data'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref.read(settingsControllerProvider.notifier).deleteAllData();
      await _syncOnboardingGate(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All local data wiped.')));
      }
    }
  }

  void _resetOnboarding(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Onboarding Wizard?'),
        content: const Text(
          'This will reset your onboarding completion flag and return you to the setup wizard to re-enter your goals.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', false);
      ref.read(onboardingCompletedProvider.notifier).state = false;

      if (context.mounted) {
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.b05Colors.selected,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.storage_rounded,
                color: context.b05Colors.success.indicator,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data & Privacy Management',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage local backups, exports, and offline settings',
                    style: TextStyle(
                      color: context.b05Colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Offline Mode Toggle
        SettingsReminderToggle(
          icon: Icons.cloud_off_rounded,
          iconColor: context.b05Colors.info.indicator,
          title: 'No Backend Mode',
          subtitle: 'Disable all cloud features and backups',
          value: state.offlineOnly,
          onChanged: (val) => controller.toggleOfflineOnly(val),
        ),
        const SizedBox(height: 12),

        // Crash Reporting Toggle
        SettingsReminderToggle(
          icon: Icons.bug_report_rounded,
          iconColor: context.b05Colors.warning.indicator,
          title: 'Anonymous Crash Reporting',
          subtitle:
              'Send sanitized telemetry to help fix crashes. Zero food/body data is ever included.',
          value: state.crashReportingEnabled,
          onChanged: (val) => controller.toggleCrashReporting(val),
        ),
        const SizedBox(height: 12),

        // Health Sync Hub button
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HealthSyncHubScreen(),
              ),
            );
          },
          icon: Icon(
            Icons.favorite_rounded,
            color: context.b05Colors.danger.indicator,
          ),
          label: const Text('Apple Health & Health Connect Sync'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.b05Colors.danger.container,
            foregroundColor: context.b05Colors.danger.foreground,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: context.b05Colors.danger.indicator.withValues(
                  alpha: 0.2,
                ),
              ),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 12),

        // Export / Restore Database Card
        BackupRestoreCard(
          onExport: () => _showExportDialog(context, ref),
          onRestore: () => _showRestoreDialog(context, ref),
        ),
        const SizedBox(height: 8),

        // Restore Auto-Backup Snapshot button
        ElevatedButton.icon(
          onPressed: () => _restoreFromAutoBackup(context, ref),
          icon: Icon(
            Icons.history_rounded,
            color: context.b05Colors.info.indicator,
          ),
          label: const Text('Restore Recent Auto-Backup Snapshot'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.b05Colors.info.container,
            foregroundColor: context.b05Colors.info.foreground,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: context.b05Colors.info.indicator.withValues(alpha: 0.2),
              ),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 8),

        // Export CSV button
        ElevatedButton.icon(
          onPressed: () async {
            await controller.exportCsvData();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Food & Workout data copied as CSV to clipboard!',
                  ),
                ),
              );
            }
          },
          icon: Icon(
            Icons.table_chart_rounded,
            color: context.b05Colors.action,
          ),
          label: const Text('Export Food & Workout Data (CSV)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.b05Colors.selected,
            foregroundColor: context.b05Colors.action,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: context.b05Colors.action.withValues(alpha: 0.2),
              ),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 16),

        const PrivacyDisclosureCard(),
        const SizedBox(height: 16),

        // Reset Onboarding Button
        ElevatedButton.icon(
          onPressed: () => _resetOnboarding(context, ref),
          icon: Icon(
            Icons.refresh_rounded,
            color: context.b05Colors.warning.indicator,
          ),
          label: const Text('Reset Onboarding Wizard'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.b05Colors.warning.container,
            foregroundColor: context.b05Colors.warning.foreground,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: context.b05Colors.warning.indicator.withValues(
                  alpha: 0.2,
                ),
              ),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 12),

        // Delete All Data Button
        ElevatedButton.icon(
          onPressed: () => _confirmDeleteAllData(context, ref),
          icon: Icon(
            Icons.delete_forever_rounded,
            color: context.b05Colors.danger.indicator,
          ),
          label: const Text('Wipe All Local Data'),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.b05Colors.danger.container,
            foregroundColor: context.b05Colors.danger.foreground,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: context.b05Colors.danger.indicator.withValues(
                  alpha: 0.2,
                ),
              ),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}
