import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class BackupRestoreCard extends StatelessWidget {
  final VoidCallback onExport;
  final VoidCallback onRestore;

  const BackupRestoreCard({
    super.key,
    required this.onExport,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Export JSON Database
        ElevatedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Export Local Backup (Encrypted)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary.withOpacity(0.12),
            foregroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 12),

        // Restore JSON Database
        ElevatedButton.icon(
          onPressed: onRestore,
          icon: const Icon(Icons.upload_rounded, color: Colors.blueAccent),
          label: const Text('Restore Database from Backup'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent.withOpacity(0.12),
            foregroundColor: Colors.blueAccent,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blueAccent.withOpacity(0.2)),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}
