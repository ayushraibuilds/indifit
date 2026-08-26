import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/backup/backup_file_adapter.dart';
import '../../../core/presentation/product_failure_presentation.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/auto_backup_service.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../../onboarding/onboarding_screen.dart';
import '../settings_controller.dart';
import 'backup_restore_card.dart';
import 'privacy_disclosure_card.dart';
import 'settings_reminder_toggle.dart';

class DataManagementSection extends ConsumerWidget {
  const DataManagementSection({super.key});

  Future<void> _syncOnboardingGate(WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    ref.read(onboardingCompletedProvider.notifier).state =
        prefs.getBool('onboarding_completed') ?? false;
  }

  Future<void> _showExportDialog(BuildContext context, WidgetRef ref) async {
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
              onPressed: () =>
                  Navigator.pop(dialogCtx, passwordController.text),
              child: const Text('Create backup'),
            ),
          ],
        ),
      );

      if (password == null || !context.mounted) return;
      final result = await ref
          .read(settingsControllerProvider.notifier)
          .performExport(password);
      if (!context.mounted) return;

      final message = switch (result.status) {
        SettingsExportStatus.shared =>
          'Sharing completed. Check the destination you chose before relying on this backup.',
        SettingsExportStatus.cancelled =>
          result.message ?? 'No backup was shared.',
        SettingsExportStatus.failed =>
          result.message ??
              ProductFailurePresentation.fromCode(
                'backup_export_failed',
              ).message,
      };
      _showSnack(
        context,
        message,
        error: result.status == SettingsExportStatus.failed,
      );
    } finally {
      passwordController.dispose();
    }
  }

  Future<void> _showRestoreDialog(BuildContext context, WidgetRef ref) async {
    final pasteController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedFileContent;
    String? selectedFileName;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            title: const Text('Restore a backup'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose an IndiFit backup file, or restore an older IndiFit export. The backup will be checked before anything on this device changes.',
                    style: B05Typography.body(dialogCtx),
                  ),
                  const SizedBox(height: B05Layout.space12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final selected =
                            await BackupFileAdapter.pickBackupFile();
                        if (selected != null && dialogCtx.mounted) {
                          setDialogState(() {
                            selectedFileName = selected.name;
                            selectedFileContent = selected.content;
                          });
                        }
                      } catch (_) {
                        if (context.mounted) {
                          _showSnack(
                            context,
                            'The backup file could not be opened. Try again.',
                            error: true,
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Choose a backup file'),
                  ),
                  if (selectedFileName != null) ...[
                    const SizedBox(height: B05Layout.space8),
                    Text(
                      'Selected: $selectedFileName',
                      style: TextStyle(
                        color: dialogCtx.b05Colors.success.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: B05Layout.space12),
                  TextField(
                    controller: pasteController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Paste an older IndiFit export if needed',
                    ),
                  ),
                  const SizedBox(height: B05Layout.space12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password, if protected',
                      hintText: 'Leave blank if no password was used',
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
                onPressed: () async {
                  final rawContent =
                      selectedFileContent ?? pasteController.text.trim();
                  if (rawContent.isEmpty) {
                    if (context.mounted) {
                      _showSnack(
                        context,
                        'Choose a backup file or paste an export first.',
                        error: true,
                      );
                    }
                    return;
                  }

                  BackupInspectionResult inspection;
                  try {
                    inspection = await BackupFileAdapter.inspectBackupContent(
                      rawContent,
                      password: passwordController.text.isEmpty
                          ? null
                          : passwordController.text,
                    );
                  } catch (_) {
                    if (context.mounted) {
                      await _showInspectionFailure(context);
                    }
                    return;
                  }

                  if (!context.mounted) return;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (confirmCtx) => AlertDialog(
                      title: const Text('Review before restoring'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restoring replaces the supported data currently on this device. Existing data is not merged.',
                              style: TextStyle(
                                color: confirmCtx.b05Colors.danger.foreground,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: B05Layout.space12),
                            Text('Profile: ${inspection.profileName}'),
                            Text(
                              'Created: ${_formatBackupTimestamp(confirmCtx, inspection.timestamp)}',
                            ),
                            Text(
                              'Password protected: ${inspection.isEncrypted ? 'Yes' : 'No'}',
                            ),
                            ..._backupCountRows(confirmCtx, inspection),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(confirmCtx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                confirmCtx.b05Colors.danger.container,
                            foregroundColor:
                                confirmCtx.b05Colors.danger.foreground,
                          ),
                          onPressed: () => Navigator.pop(confirmCtx, true),
                          child: const Text('Restore backup'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed != true || !context.mounted) return;
                  Navigator.pop(dialogCtx);
                  try {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .performRestore(inspection.payload);
                    await _syncOnboardingGate(ref);
                    if (context.mounted) {
                      _showSnack(context, 'Backup restored.');
                    }
                  } catch (_) {
                    if (context.mounted) {
                      _showSnack(
                        context,
                        'The backup could not be restored. Your existing data was not changed.',
                        error: true,
                      );
                    }
                  }
                },
                child: const Text('Inspect backup'),
              ),
            ],
          ),
        ),
      );
    } finally {
      pasteController.dispose();
      passwordController.dispose();
    }
  }

  Future<void> _showInspectionFailure(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Backup unavailable'),
        content: Text(
          ProductFailurePresentation.fromCode(
            'backup_inspection_failed',
          ).message,
          style: B05Typography.body(dialogCtx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreFromAutoBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final rawSnapshot = await AutoBackupService.getLatestSnapshotContent();
    if (!context.mounted) return;
    if (rawSnapshot == null) {
      _showSnack(context, 'No recent local snapshot is available.');
      return;
    }

    try {
      final inspection = await BackupFileAdapter.inspectBackupContent(
        rawSnapshot,
      );
      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Restore recent snapshot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This replaces the supported data currently on this device with the latest local snapshot.',
                  style: B05Typography.body(dialogCtx),
                ),
                const SizedBox(height: B05Layout.space12),
                Text('Profile: ${inspection.profileName}'),
                Text(
                  'Created: ${_formatBackupTimestamp(dialogCtx, inspection.timestamp)}',
                ),
                ..._backupCountRows(dialogCtx, inspection),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dialogCtx.b05Colors.danger.container,
                foregroundColor: dialogCtx.b05Colors.danger.foreground,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Restore snapshot'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;
      await ref
          .read(settingsControllerProvider.notifier)
          .performRestore(inspection.payload);
      await _syncOnboardingGate(ref);
      if (context.mounted) {
        _showSnack(context, 'Local snapshot restored.');
      }
    } catch (_) {
      if (context.mounted) {
        _showSnack(
          context,
          'The local snapshot could not be restored. Your existing data was not changed.',
          error: true,
        );
      }
    }
  }

  Future<void> _resetOnboarding(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Start setup again?'),
        content: const Text(
          'This only resets setup so you can review your goals and preferences. It does not delete logged data or backups.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Start setup again'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', false);
      ref.read(onboardingCompletedProvider.notifier).state = false;
    } catch (_) {
      if (context.mounted) {
        _showSnack(
          context,
          'Setup could not be reset. Your data was not changed.',
          error: true,
        );
      }
      return;
    }

    if (context.mounted) {
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final isBusy = state.loading;
    final colors = context.b05Colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review what stays on this device, make a copy when you need one, and choose which optional features can connect elsewhere.',
          style: B05Typography.body(context),
        ),
        const SizedBox(height: B05Layout.space24),
        _sectionHeading(context, 'Backup'),
        B05Surface(
          tone: B05SurfaceTone.section,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Backups include supported IndiFit records and settings. Photos and other device files are not included.',
                style: B05Typography.body(context),
              ),
              const SizedBox(height: B05Layout.space16),
              BackupRestoreCard(
                onExport: isBusy ? null : () => _showExportDialog(context, ref),
                onRestore: isBusy
                    ? null
                    : () => _showRestoreDialog(context, ref),
              ),
              const SizedBox(height: B05Layout.space16),
              Divider(color: context.b05Colors.border),
              const SizedBox(height: B05Layout.space12),
              Text('Automatic backup', style: B05Typography.title(context)),
              const SizedBox(height: B05Layout.space4),
              Text(
                'A local snapshot is created on this device when the app starts. Up to three snapshots are kept. A snapshot may be unavailable if creation did not finish.',
                style: B05Typography.body(context),
              ),
              const SizedBox(height: B05Layout.space8),
              B05ActionButton(
                emphasis: B05ActionEmphasis.secondary,
                icon: Icons.history_rounded,
                label: 'Restore recent snapshot',
                hint: 'Inspect and restore the latest local snapshot.',
                onPressed: isBusy
                    ? null
                    : () => _restoreFromAutoBackup(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space24),
        _sectionHeading(context, 'Export'),
        B05Surface(
          tone: B05SurfaceTone.section,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Copy a summary of logged food and workouts as CSV. This is a summary, not a full backup.',
                style: B05Typography.body(context),
              ),
              const SizedBox(height: B05Layout.space12),
              B05ActionButton(
                emphasis: B05ActionEmphasis.secondary,
                icon: Icons.content_copy_rounded,
                label: 'Copy food & workout CSV',
                hint: 'Copy logged food and workout rows to the clipboard.',
                onPressed: isBusy
                    ? null
                    : () async {
                        final error = await ref
                            .read(settingsControllerProvider.notifier)
                            .exportCsvData();
                        if (!context.mounted) return;
                        _showSnack(
                          context,
                          error ?? 'Food and workout CSV copied.',
                          error: error != null,
                        );
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: B05Layout.space24),
        _sectionHeading(context, 'Privacy'),
        SettingsReminderToggle(
          icon: Icons.cloud_off_rounded,
          iconColor: context.b05Colors.info.indicator,
          title: 'Offline mode',
          subtitle:
              'Block app-initiated online requests, photo uploads, online food search and crash reporting.',
          value: state.offlineOnly,
          requestNotificationPermission: false,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .toggleOfflineOnly(value),
        ),
        const SizedBox(height: B05Layout.space12),
        SettingsReminderToggle(
          icon: Icons.bug_report_outlined,
          iconColor: context.b05Colors.warning.indicator,
          title: 'Share crash diagnostics',
          subtitle: 'Optional and off by default. Offline mode turns this off.',
          value: state.crashReportingEnabled,
          requestNotificationPermission: false,
          onChanged: (value) => ref
              .read(settingsControllerProvider.notifier)
              .toggleCrashReporting(value),
        ),
        const SizedBox(height: B05Layout.space12),
        PrivacyDisclosureCard(
          offlineOnly: state.offlineOnly,
          crashReportingEnabled: state.crashReportingEnabled,
        ),
        const SizedBox(height: B05Layout.space24),

        _SectionHeader(title: 'DANGER ZONE'),
        B05Surface(
          tone: B05SurfaceTone.inset,
          showBorder: true,
          padding: const EdgeInsets.all(B05Layout.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colors.danger.foreground,
                    size: B05Layout.iconLarge,
                  ),
                  const SizedBox(width: B05Layout.space8),
                  Expanded(
                    child: Text(
                      'Irreversible actions',
                      style: B05Typography.title(
                        context,
                      ).copyWith(color: colors.danger.foreground),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: B05Layout.space8),
              Text(
                'These actions affect your local app data. Please review carefully before proceeding.',
                style: B05Typography.caption(context),
              ),
              const SizedBox(height: B05Layout.space16),
              Divider(color: colors.border),
              const SizedBox(height: B05Layout.space12),
              Text(
                'Reset onboarding wizard',
                style: B05Typography.label(context),
              ),
              const SizedBox(height: B05Layout.space4),
              Text(
                'Re-run setup to re-enter your goals and profile. Your logged meal and workout history remains safe.',
                style: B05Typography.caption(context),
              ),
              const SizedBox(height: B05Layout.space12),
              Align(
                alignment: Alignment.centerLeft,
                child: B05ActionButton(
                  icon: Icons.refresh_rounded,
                  label: 'Start setup again',
                  hint: 'Confirm before reopening setup.',
                  emphasis: B05ActionEmphasis.secondary,
                  onPressed: isBusy
                      ? null
                      : () => _resetOnboarding(context, ref),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _sectionHeading(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: B05Layout.space8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(
          color: context.b05Colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static void _showSnack(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? context.b05Colors.danger.indicator : null,
      ),
    );
  }

  static String _formatBackupTimestamp(
    BuildContext context,
    String rawTimestamp,
  ) {
    final parsed = DateTime.tryParse(rawTimestamp)?.toLocal();
    if (parsed == null) return 'Date unavailable';
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(parsed);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(parsed));
    return '$date, $time';
  }

  static List<Widget> _backupCountRows(
    BuildContext context,
    BackupInspectionResult inspection,
  ) {
    const labels = <String, String>{
      'food_logs': 'Logged food',
      'workout_sessions': 'Workouts',
      'workout_sets': 'Workout sets',
      'body_measurements': 'Body measurements',
      'daily_hydrations': 'Water entries',
      'achievement_unlocks': 'Achievements',
      'dashboard_module_preferences': 'Dashboard preferences',
      'education_content_progress': 'Learning progress',
      'media_pack_preferences': 'Media preferences',
      'workout_playlist_preferences': 'Music preference',
    };
    final seen = <String>{};
    final rows = <Widget>[];
    for (final entry in inspection.tableCounts.entries) {
      final label = labels[entry.key];
      if (label == null || !seen.add(label)) continue;
      rows.add(Text('$label: ${entry.value}'));
    }
    if (rows.isEmpty) return const [];
    return [
      const SizedBox(height: B05Layout.space12),
      Text('Included records', style: B05Typography.label(context)),
      ...rows,
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: B05Layout.space4,
        bottom: B05Layout.space8,
      ),
      child: Text(
        title,
        style: B05Typography.caption(context).copyWith(
          color: context.b05Colors.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
