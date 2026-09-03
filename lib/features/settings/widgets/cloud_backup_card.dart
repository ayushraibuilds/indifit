import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/capabilities/capabilities_registry.dart';
import '../../../core/theme/b05_semantic_colors.dart';
import '../../../core/widgets/b05_accessibility_primitives.dart';

/// Settings card for managing Encrypted Cloud Backups.
class CloudBackupCard extends ConsumerStatefulWidget {
  const CloudBackupCard({super.key});

  @override
  ConsumerState<CloudBackupCard> createState() => _CloudBackupCardState();
}

class _CloudBackupCardState extends ConsumerState<CloudBackupCard> {
  bool _isBackingUp = false;

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? context.b05Colors.danger.container
            : context.b05Colors.surface,
      ),
    );
  }

  Future<void> _handleBackUpNow() async {
    final capability = ref.read(cloudBackupCapabilityProvider);

    setState(() => _isBackingUp = true);
    try {
      final success = await capability.createAndUploadSnapshot(isManual: true);
      ref.invalidate(cloudBackupStatusProvider);
      if (success) {
        _showSnack('Cloud backup completed.');
      } else {
        _showSnack('Could not complete cloud backup. Please check your connection.', isError: true);
      }
    } catch (e) {
      _showSnack('Cloud backup failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _showHistoryDialog(List<RemoteBackupSnapshotMetadata> snapshots) async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Cloud backup history'),
        content: SizedBox(
          width: double.maxFinite,
          child: snapshots.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: B05Layout.space16),
                  child: Text('No cloud backups stored.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: snapshots.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (ctx, index) {
                    final s = snapshots[index];
                    final dateStr = s.createdAtUtc.toLocal().toString().split('.').first;
                    final sizeKb = (s.byteSize / 1024).toStringAsFixed(1);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s.deviceId} • $sizeKb KB'),
                      trailing: TextButton(
                        child: const Text('Restore'),
                        onPressed: () async {
                          Navigator.pop(dialogCtx);
                          await _confirmAndRestore(s.snapshotId, dateStr);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          if (snapshots.isNotEmpty)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: dialogCtx.b05Colors.danger.foreground,
              ),
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _confirmAndDeleteAll();
              },
              child: const Text('Delete all backups'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndRestore(String snapshotId, String dateStr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore cloud backup?'),
        content: Text(
          'Restoring the snapshot from $dateStr will replace your current data on this device. Existing data is not merged.\n\nAre you sure you want to proceed?',
          style: const TextStyle(height: 1.4),
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
            child: const Text('Restore now'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final capability = ref.read(cloudBackupCapabilityProvider);

    try {
      await capability.restoreCloudSnapshot(snapshotId);
      ref.invalidate(cloudBackupStatusProvider);
      _showSnack('Cloud backup restored successfully.');
    } catch (e) {
      _showSnack('Restore failed: $e', isError: true);
    }
  }

  Future<void> _confirmAndDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all cloud backups?'),
        content: const Text(
          'This will permanently delete all your cloud backup snapshots from the remote server. Your local data on this device will not be deleted.',
          style: TextStyle(height: 1.4),
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
            child: const Text('Delete all'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final capability = ref.read(cloudBackupCapabilityProvider);

    try {
      await capability.deleteAllRemoteSnapshots();
      ref.invalidate(cloudBackupStatusProvider);
      _showSnack('All cloud backups have been deleted.');
    } catch (e) {
      _showSnack('Failed to delete cloud backups: $e', isError: true);
    }
  }

  Future<void> _handleViewHistory() async {
    final capability = ref.read(cloudBackupCapabilityProvider);

    try {
      final snapshots = await capability.listRemoteSnapshots();
      if (mounted) {
        await _showHistoryDialog(snapshots);
      }
    } catch (e) {
      _showSnack('Could not fetch cloud backup history.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(cloudBackupStatusProvider);
    final colors = context.b05Colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Encrypted cloud backup', style: B05Typography.title(context)),
        const SizedBox(height: B05Layout.space4),
        Text(
          'Back up your fitness records and settings securely to IndiFit Cloud using end-to-end encryption. Snapshots are unreadable by anyone without your credentials.',
          style: B05Typography.body(context),
        ),
        const SizedBox(height: B05Layout.space12),
        statusAsync.when(
          data: (status) => _buildStatusContent(context, status),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: B05Layout.space8),
            child: Text('Checking cloud backup status...'),
          ),
          error: (_, _) => Text(
            'Unable to load cloud backup status.',
            style: TextStyle(color: colors.danger.foreground),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusContent(BuildContext context, ConnectedStatusState status) {
    final colors = context.b05Colors;

    final (icon, labelColor) = switch (status.status) {
      ConnectedStatus.synced => (Icons.check_circle_rounded, colors.success.foreground),
      ConnectedStatus.pending || ConnectedStatus.inFlight => (Icons.hourglass_top_rounded, colors.warning.foreground),
      ConnectedStatus.offline => (Icons.cloud_off_rounded, colors.textSecondary),
      _ => (Icons.cloud_queue_rounded, colors.textPrimary),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: labelColor),
            const SizedBox(width: B05Layout.space8),
            Expanded(
              child: Text(
                status.displayMessage,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: B05Layout.space12),
        Wrap(
          spacing: B05Layout.space8,
          runSpacing: B05Layout.space8,
          children: [
            B05ActionButton(
              emphasis: B05ActionEmphasis.primary,
              icon: _isBackingUp ? Icons.hourglass_empty_rounded : Icons.cloud_upload_rounded,
              label: _isBackingUp ? 'Backing up...' : 'Back up now',
              hint: 'Create an encrypted cloud backup snapshot now.',
              onPressed: _isBackingUp ? null : _handleBackUpNow,
            ),
            B05ActionButton(
              emphasis: B05ActionEmphasis.secondary,
              icon: Icons.history_rounded,
              label: 'Cloud history',
              hint: 'View stored cloud snapshots and restore.',
              onPressed: _handleViewHistory,
            ),
          ],
        ),
      ],
    );
  }
}
