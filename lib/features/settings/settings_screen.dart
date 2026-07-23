import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/theme_provider.dart';
import '../../core/theme/colors.dart';
import 'data_management_sub_screen.dart';
import 'health_sync_hub_screen.dart';
import 'notification_settings_screen.dart';
import 'regional_food_packs_screen.dart';
import 'settings_controller.dart';
import 'water_settings_sub_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Theme Picker Card (Item 13)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.palette_outlined, color: AppColors.primary, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Appearance Theme',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.brightness_auto_rounded, size: 16),
                                  label: Text('System'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode_rounded, size: 16),
                                  label: Text('Light'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_rounded, size: 16),
                                  label: Text('Dark'),
                                ),
                              ],
                              selected: {themeMode},
                              onSelectionChanged: (Set<ThemeMode> newSelection) {
                                ref.read(themeModeProvider.notifier).setThemeMode(newSelection.first);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Settings Group List
                  const Text(
                    'PREFERENCES & DATA',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    child: Column(
                      children: [
                        _buildSettingTile(
                          context,
                          icon: Icons.notifications_none_rounded,
                          iconColor: Colors.amber,
                          title: 'Notifications & Reminders',
                          subtitle: 'Meal reminders, workout alarms & summaries',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.water_drop_outlined,
                          iconColor: Colors.lightBlue,
                          title: 'Hydration & Water Goal',
                          subtitle: 'Daily target, glass volume & intake history',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const WaterSettingsSubScreen()),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.restaurant_menu_rounded,
                          iconColor: Colors.orange,
                          title: 'Regional Food Packs',
                          subtitle: 'Bengali, Gujarati, Punjabi & South Indian items',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegionalFoodPacksScreen()),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.favorite_border_rounded,
                          iconColor: Colors.pink,
                          title: 'Health Sync Hub',
                          subtitle: 'Connect Health Connect / Apple Health',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const HealthSyncHubScreen()),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.sd_storage_outlined,
                          iconColor: Colors.green,
                          title: 'Data & Auto-Backup',
                          subtitle: 'CSV export, SQLite backups & offline mode',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DataManagementSubScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const _MedicalDisclaimerCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
      onTap: onTap,
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
                color: Colors.red.withOpacity(0.12),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'IndiFit is for informational purposes only.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
