import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';
import '../data_export_status.dart';
import '../settings_controller.dart';
import 'backup_export_flow.dart';

/// The plain answer to "what happens to my data on a new phone?" (N14-02).
/// Must match doc/privacy_policy.md; see test/backup_disclosure_test.dart.
const kNewPhoneStartsEmpty =
    'A new phone, reinstall or factory reset starts empty unless you export.';

/// "Your data, your phone" (U-1): where data lives, the last export date and
/// a way to export. Shown in Settings → Manage your data and on onboarding's
/// last step.
class YourDataCard extends ConsumerWidget {
  const YourDataCard({super.key, this.showExportAction = true});

  /// Onboarding leaves the button out: nothing has been logged yet.
  final bool showExportAction;

  static String lastExportLabel(DateTime? at) =>
      'Last export: ${at == null ? 'Never' : DateFormat('d MMM yyyy').format(at)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.b05Colors;
    final lastExportAt = ref.watch(dataExportStatusProvider).lastExportAt;
    final busy = ref.watch(settingsControllerProvider).loading;
    return B05Surface(
      key: const Key('your_data_card'),
      padding: const EdgeInsets.all(B05Layout.space16),
      showBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.phone_iphone_rounded,
                color: colors.info.indicator,
                size: B05Layout.iconMedium,
              ),
              const SizedBox(width: B05Layout.space8),
              Expanded(
                child: Text(
                  'Your data, your phone',
                  style: B05Typography.title(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: B05Layout.space8),
          Text(
            'Everything you log is stored only on this phone. It isn’t '
            'included in iCloud or Google backups and doesn’t move to a new '
            'phone by itself. $kNewPhoneStartsEmpty',
            style: B05Typography.body(context),
          ),
          const SizedBox(height: B05Layout.space12),
          Text(
            lastExportLabel(lastExportAt),
            key: const Key('your_data_last_export'),
            style: B05Typography.label(context),
          ),
          const SizedBox(height: B05Layout.space12),
          if (showExportAction)
            B05ActionButton(
              emphasis: B05ActionEmphasis.secondary,
              icon: Icons.ios_share_rounded,
              label: 'Export now',
              hint: 'Create a backup file and choose where to save it.',
              onPressed: busy ? null : () => showBackupExportFlow(context, ref),
            )
          else
            Text(
              'You can export any time from Settings → Manage your data.',
              style: B05Typography.body(context),
            ),
        ],
      ),
    );
  }
}

/// The export reminder after a saved workout (FT-1). Renders nothing unless
/// [exportReminderDueProvider] says it is due.
class ExportReminderCard extends ConsumerWidget {
  const ExportReminderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(exportReminderDueProvider).valueOrNull ?? false;
    if (!due) return const SizedBox.shrink();
    final busy = ref.watch(settingsControllerProvider).loading;
    return Padding(
      padding: const EdgeInsets.only(top: B05Layout.space24),
      child: B05Surface(
        key: const Key('export_reminder_card'),
        padding: const EdgeInsets.all(B05Layout.space16),
        showBorder: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Keep a copy of your progress',
              style: B05Typography.title(context),
            ),
            const SizedBox(height: B05Layout.space8),
            Text(
              'IndiFit has no cloud backup. $kNewPhoneStartsEmpty',
              style: B05Typography.body(context),
            ),
            const SizedBox(height: B05Layout.space12),
            Row(
              children: [
                Expanded(
                  child: B05ActionButton(
                    icon: Icons.ios_share_rounded,
                    label: 'Export now',
                    hint: 'Create a backup file and choose where to save it.',
                    onPressed: busy
                        ? null
                        : () => showBackupExportFlow(context, ref),
                  ),
                ),
                const SizedBox(width: B05Layout.space8),
                TextButton(
                  onPressed: () => ref
                      .read(dataExportStatusProvider.notifier)
                      .snoozeReminder(),
                  child: const Text('Later'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
