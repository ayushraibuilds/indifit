import 'package:flutter/material.dart';

import '../../../core/widgets/b05_accessibility_primitives.dart';

class BackupRestoreCard extends StatelessWidget {
  final VoidCallback? onExport;
  final VoidCallback? onRestore;

  const BackupRestoreCard({
    super.key,
    required this.onExport,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        B05ActionButton(
          emphasis: B05ActionEmphasis.primary,
          icon: Icons.ios_share_rounded,
          label: 'Create and share backup',
          hint: 'Create a backup file and choose where to share it.',
          onPressed: onExport,
        ),
        const SizedBox(height: B05Layout.space8),

        B05ActionButton(
          emphasis: B05ActionEmphasis.secondary,
          icon: Icons.upload_file_rounded,
          label: 'Restore a backup',
          hint:
              'Choose a backup to inspect before replacing data on this device.',
          onPressed: onRestore,
        ),
      ],
    );
  }
}
