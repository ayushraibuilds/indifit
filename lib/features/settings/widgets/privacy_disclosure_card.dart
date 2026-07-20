import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class PrivacyDisclosureCard extends StatelessWidget {
  const PrivacyDisclosureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.privacy_tip_rounded, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text('Where is my data stored?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Local Data Only: All food databases, logged meals, active workouts, training routines, and weight measurements are stored offline-first inside a local SQLite (Drift) database on this device. They are never uploaded or shared.\n\n'
            '• Cloud Sync: IndiFit v1 runs completely offline-first on your device. Cloud synchronization is planned for a future release.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}
