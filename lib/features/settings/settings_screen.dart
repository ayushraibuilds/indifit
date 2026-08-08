import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/theme_provider.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../media/b05_playlist_launcher.dart';
import '../profile/profile_screen.dart';
import 'data_management_sub_screen.dart';
import 'health_sync_hub_screen.dart';
import 'household_measures_screen.dart';
import 'notification_settings_screen.dart';
import 'nutrition_constraints_screen.dart';
import 'nutrition_goals_sub_screen.dart';
import 'regional_food_packs_screen.dart';
import 'settings_controller.dart';
import 'water_settings_sub_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.b05Colors;
    final state = ref.watch(settingsControllerProvider);
    final currentThemeMode = ref.watch(themeModeProvider);
    final playlistRegistryAvailable = ref
        .watch(b05PlaylistProviderRegistryProvider)
        .providers
        .isNotEmpty;
    final playlistAvailable = playlistRegistryAvailable;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Theme Picker Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                color: colors.action,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Appearance Theme',
                                style: B05Typography.title(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.system,
                                  label: Text('System'),
                                  icon: Icon(
                                    Icons.settings_suggest_rounded,
                                    size: 16,
                                  ),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.light,
                                  label: Text('Light'),
                                  icon: Icon(
                                    Icons.light_mode_rounded,
                                    size: 16,
                                  ),
                                ),
                                ButtonSegment<ThemeMode>(
                                  value: ThemeMode.dark,
                                  label: Text('Dark'),
                                  icon: Icon(Icons.dark_mode_rounded, size: 16),
                                ),
                              ],
                              selected: {currentThemeMode},
                              onSelectionChanged:
                                  (Set<ThemeMode> newSelection) {
                                    if (newSelection.isNotEmpty) {
                                      ref
                                          .read(themeModeProvider.notifier)
                                          .setThemeMode(newSelection.first);
                                    }
                                  },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Settings Group List
                  Text(
                    'PREFERENCES & DATA',
                    style: B05Typography.label(context).copyWith(
                      color: colors.textSecondary,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    child: Column(
                      children: [
                        _buildSettingTile(
                          context,
                          icon: Icons.person_outline_rounded,
                          iconColor: colors.action,
                          title: 'My Profile',
                          subtitle:
                              'Body measurements, goals, diet & equipment',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          ),
                        ),
                        if (playlistAvailable) ...[
                          Divider(height: 1, color: colors.border),
                          _buildSettingTile(
                            context,
                            icon: Icons.music_note_outlined,
                            iconColor: colors.action,
                            title: 'Workout Playlist',
                            subtitle:
                                'Save a playlist for quick workout launch',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const B05PlaylistSettingsScreen(),
                              ),
                            ),
                          ),
                        ],
                        Divider(height: 1, color: colors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.health_and_safety_outlined,
                          iconColor: colors.warning.foreground,
                          title: 'Food preferences',
                          subtitle:
                              'Choose foods and ingredients to handle carefully',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const NutritionConstraintsScreen(),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: colors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.notifications_none_rounded,
                          iconColor: colors.warning.foreground,
                          title: 'Notifications & Reminders',
                          subtitle:
                              'Meal reminders, workout alarms & summaries',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const NotificationSettingsScreen(),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: colors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.water_drop_outlined,
                          iconColor: colors.info.foreground,
                          title: 'Hydration & Water Goal',
                          subtitle:
                              'Daily target, glass volume & intake history',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WaterSettingsSubScreen(),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: colors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.local_drink_outlined,
                          iconColor: colors.info.foreground,
                          title: 'Household Measures',
                          subtitle:
                              'Manage personal vessels and measured volume capacity',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HouseholdMeasuresScreen(),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: colors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.restaurant_menu_rounded,
                          iconColor: colors.breakfast.foreground,
                          title: 'Regional Food Packs',
                          subtitle:
                              'Bengali, Gujarati, Punjabi & South Indian items',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegionalFoodPacksScreen(),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: colors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.restaurant_menu_rounded,
                          iconColor: colors.action,
                          title: 'Nutrition & Macro Goals',
                          subtitle:
                              'View calculated recommendations & customize targets',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NutritionGoalsSubScreen(),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: colors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.favorite_border_rounded,
                          iconColor: colors.danger.foreground,
                          title: 'Health Sync Hub',
                          subtitle: 'Connect Health Connect / Apple Health',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HealthSyncHubScreen(),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: colors.border),
                        _buildSettingTile(
                          context,
                          icon: Icons.sd_storage_outlined,
                          iconColor: colors.success.foreground,
                          title: 'Data & Auto-Backup',
                          subtitle: 'CSV export, SQLite backups & offline mode',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DataManagementSubScreen(),
                            ),
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
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: context.b05Colors.textSecondary, fontSize: 11),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.b05Colors.textDisabled,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

class _MedicalDisclaimerCard extends StatelessWidget {
  const _MedicalDisclaimerCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.danger.container,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.health_and_safety_rounded,
                color: colors.danger.foreground,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health & Safety Disclaimer',
                    style: B05Typography.title(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'IndiFit is for informational purposes only.',
                    style: B05Typography.body(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        B05Surface(
          child: Text(
            'IndiFit provides general fitness tracking, local AI exercise/food estimation, and routine planning tools. We do not provide medical advice or therapy. Consult a physician before starting any workout program or altering your diet. Always exercise caution, maintain proper form, and stop immediately if you experience pain. Nutritional estimations are generated locally and might contain variations or inaccuracies; do not rely on them for severe food allergies or medical diagnoses.',
            style: B05Typography.body(context).copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}
