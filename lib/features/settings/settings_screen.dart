import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import 'settings_controller.dart';
import 'widgets/data_management_section.dart';
import 'widgets/notification_settings_section.dart';
import 'widgets/water_settings_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : const SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NotificationSettingsSection(),
                  SizedBox(height: 24),
                  Divider(color: AppColors.border),
                  SizedBox(height: 24),
                  WaterSettingsSection(),
                  SizedBox(height: 24),
                  Divider(color: AppColors.border),
                  SizedBox(height: 24),
                  DataManagementSection(),
                  SizedBox(height: 32),
                  _MedicalDisclaimerCard(),
                ],
              ),
            ),
    );
  }
}

class _MedicalDisclaimerCard extends StatelessWidget {
  const _MedicalDisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.health_and_safety_rounded, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health & Safety Disclaimer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'IndiFit is for informational purposes only.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Text(
            'IndiFit provides general fitness tracking, local AI exercise/food estimation, and routine planning tools. We do not provide medical advice or therapy. Consult a physician before starting any workout program or altering your diet. Always exercise caution, maintain proper form, and stop immediately if you experience pain. Nutritional estimations are generated locally and might contain variations or inaccuracies; do not rely on them for severe food allergies or medical diagnoses.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
