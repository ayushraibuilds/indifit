import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/encryption_helper.dart';
import '../../onboarding/onboarding_screen.dart';
import '../health_sync_hub_screen.dart';
import '../regional_food_packs_screen.dart';
import '../settings_controller.dart';
import 'backup_restore_card.dart';
import 'privacy_disclosure_card.dart';
import 'settings_reminder_toggle.dart';

class DataManagementSection extends ConsumerWidget {
  const DataManagementSection({super.key});

  void _showExportDialog(BuildContext context, WidgetRef ref) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Export & Encrypt Backup'),
        backgroundColor: AppColors.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a password to protect your backup file. If you leave this blank, the backup will be exported in plain text.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final password = passwordController.text;
              Navigator.pop(dialogCtx);
              final error = await ref.read(settingsControllerProvider.notifier).performExport(password);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: AppColors.danger),
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

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restore Database Backup'),
        backgroundColor: AppColors.surface,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the backup text block below:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: backupController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Paste JSON or encrypted text string...',
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              final backup = backupController.text.trim();
              final password = passwordController.text;
              if (backup.isEmpty) return;

              Map<String, dynamic> data;
              try {
                final decrypted = EncryptionHelper.decrypt(backup, password);
                data = jsonDecode(decrypted) as Map<String, dynamic>;
              } catch (e) {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Decryption Failed'),
                      backgroundColor: AppColors.surface,
                      content: const Text(
                        'Unable to decrypt backup. Please check your password and verify that the backup string is not corrupted.',
                        style: TextStyle(height: 1.4),
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

              final exportedAtStr = data['exported_at'] ?? 'Unknown';
              String formattedDate = exportedAtStr;
              try {
                final date = DateTime.parse(exportedAtStr);
                formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
              } catch (_) {}

              final foodItemsCount = (data['food_items'] as List?)?.length ?? 0;
              final foodLogsCount = (data['food_logs'] as List?)?.length ?? 0;
              final workoutSessionsCount = (data['workout_sessions'] as List?)?.length ?? 0;
              final workoutSetsCount = (data['workout_sets'] as List?)?.length ?? 0;
              final measurementsCount = (data['body_measurements'] as List?)?.length ?? 0;
              final routinesCount = (data['workout_routines'] as List?)?.length ?? 0;

              if (context.mounted) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm Restore Overwrite'),
                    backgroundColor: AppColors.surface,
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WARNING: Restoring will completely overwrite your current local database with this backup.',
                          style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Text('Backup Date: $formattedDate', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('• $foodItemsCount Food Items', style: const TextStyle(fontSize: 12)),
                        Text('• $foodLogsCount Food Logs', style: const TextStyle(fontSize: 12)),
                        Text('• $workoutSessionsCount Workout Sessions', style: const TextStyle(fontSize: 12)),
                        Text('• $workoutSetsCount Workout Sets', style: const TextStyle(fontSize: 12)),
                        Text('• $routinesCount Routines', style: const TextStyle(fontSize: 12)),
                        Text('• $measurementsCount Body Measurements', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Overwrite & Restore'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  Navigator.pop(dialogCtx);
                  await ref.read(settingsControllerProvider.notifier).performRestore(data);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Database restored successfully!')),
                    );
                  }
                }
              }
            },
            child: const Text('Inspect Backup'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAllData(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Local Data?'),
        backgroundColor: AppColors.surface,
        content: const Text(
          'This action is irreversible. All your logged meals, workout sessions, custom foods, and body measurements will be permanently wiped from this device.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wipe Data'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref.read(settingsControllerProvider.notifier).deleteAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All local data wiped.')),
        );
      }
    }
  }

  void _resetOnboarding(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Onboarding Wizard?'),
        backgroundColor: AppColors.surface,
        content: const Text(
          'This will reset your onboarding completion flag and return you to the setup wizard to re-enter your goals.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', false);

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
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
                color: Colors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storage_rounded, color: Colors.teal, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data & Privacy Management',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage local backups, exports, and offline settings',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
          iconColor: Colors.cyan,
          title: 'No Backend Mode',
          subtitle: 'Disable all cloud features and backups',
          value: state.offlineOnly,
          onChanged: (val) => controller.toggleOfflineOnly(val),
        ),
        const SizedBox(height: 12),

        // Crash Reporting Toggle
        SettingsReminderToggle(
          icon: Icons.bug_report_rounded,
          iconColor: Colors.amber,
          title: 'Anonymous Crash Reporting',
          subtitle: 'Send sanitized telemetry to help fix crashes. Zero food/body data is ever included.',
          value: state.crashReportingEnabled,
          onChanged: (val) => controller.toggleCrashReporting(val),
        ),
        const SizedBox(height: 12),

        // Health Sync Hub button
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HealthSyncHubScreen()),
            );
          },
          icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
          label: const Text('Apple Health & Health Connect Sync'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
            foregroundColor: Colors.redAccent,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 12),

        // Regional Food Packs button
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RegionalFoodPacksScreen()),
            );
          },
          icon: const Icon(Icons.restaurant_menu_rounded, color: Colors.teal),
          label: const Text('Regional Food Packs'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.withValues(alpha: 0.12),
            foregroundColor: Colors.teal,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.teal.withValues(alpha: 0.2)),
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

        // Export CSV button
        ElevatedButton.icon(
          onPressed: () async {
            await controller.exportCsvData();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Food & Workout data copied as CSV to clipboard!')),
              );
            }
          },
          icon: const Icon(Icons.table_chart_rounded, color: AppColors.primary),
          label: const Text('Export Food & Workout Data (CSV)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            foregroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 16),

        const PrivacyDisclosureCard(),
        const SizedBox(height: 16),

        // Reset Onboarding Button
        ElevatedButton.icon(
          onPressed: () => _resetOnboarding(context),
          icon: const Icon(Icons.refresh_rounded, color: Colors.orangeAccent),
          label: const Text('Reset Onboarding Wizard'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent.withValues(alpha: 0.12),
            foregroundColor: Colors.orangeAccent,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.2)),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 12),

        // Delete All Data Button
        ElevatedButton.icon(
          onPressed: () => _confirmDeleteAllData(context, ref),
          icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
          label: const Text('Wipe All Local Data'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger.withValues(alpha: 0.12),
            foregroundColor: AppColors.danger,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.2)),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}
