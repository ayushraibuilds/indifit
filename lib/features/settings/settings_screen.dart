import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/health_provider.dart';
import '../../core/di/theme_provider.dart';
import '../../core/di/user_profile_provider.dart';
import '../../core/presentation/diet_preference_presentation.dart';
import '../../core/presentation/secondary_presentation.dart';
import '../../core/theme/b05_semantic_colors.dart';
import '../../core/widgets/b05_accessibility_primitives.dart';
import '../../core/widgets/consumer_task_primitives.dart';
import '../../core/widgets/indi_fit_bottom_sheet.dart';
import '../dashboard/widgets/dashboard_module_customization_panel.dart';
import '../education/learn_screen.dart';
import '../equipment/equipment_profiles_screen.dart';
import '../media/b05_playlist_launcher.dart';
import '../profile/profile_screen.dart';
import 'data_management_sub_screen.dart';
import 'health_sync_hub_screen.dart';
import 'household_measures_screen.dart';
import 'notification_settings_screen.dart';
import 'nutrition_constraints_screen.dart';
import 'nutrition_goals_sub_screen.dart';
import 'nutrition_targets_hub_screen.dart';
import 'regional_food_packs_screen.dart';
import 'settings_controller.dart';
import 'unit_preference.dart';
import 'water_settings_sub_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final profile = ref.watch(userProfileProvider);
    final themeMode = ref.watch(themeModeProvider);
    final units = ref.watch(unitPreferenceProvider);
    final healthSummary = ref.watch(healthStateProvider).summary;
    final playlistAvailable = ref
        .watch(b05PlaylistProviderRegistryProvider)
        .providers
        .isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings.loading
          ? const Padding(
              padding: EdgeInsets.all(B05Layout.space16),
              child: ConsumerStatusRow(
                label: 'Loading settings',
                detail: 'Getting your preferences ready.',
                loading: true,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                B05Layout.space16,
                B05Layout.space12,
                B05Layout.space16,
                B05Layout.space32,
              ),
              children: [
                _SectionLabel('PROFILE'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal details',
                      summary: profile.userName?.trim().isNotEmpty == true
                          ? profile.userName!.trim()
                          : 'Add your name and measurements',
                      onTap: () => _push(
                        context,
                        const ProfileScreen(focus: ProfileEditorFocus.personal),
                      ),
                    ),
                    _SettingsRow(
                      icon: Icons.flag_outlined,
                      title: 'Goal',
                      summary: profile.hasProfile
                          ? SecondaryConsumerCopy.goal(profile.userGoal)
                          : 'Complete your profile',
                      onTap: () => _push(
                        context,
                        const ProfileScreen(focus: ProfileEditorFocus.goal),
                      ),
                    ),
                    _SettingsRow(
                      icon: Icons.restaurant_outlined,
                      title: 'Nutrition preferences',
                      summary: profile.hasProfile
                          ? _dietLabel(profile.dietPreference)
                          : 'Choose a dietary pattern',
                      onTap: () =>
                          _push(context, const NutritionConstraintsScreen()),
                    ),
                    _SettingsRow(
                      icon: Icons.directions_run_outlined,
                      title: 'Training preferences',
                      summary: profile.hasProfile
                          ? SecondaryConsumerCopy.activity(
                              profile.userActivityLevel,
                            )
                          : 'Complete your profile',
                      onTap: () => _push(
                        context,
                        const ProfileScreen(focus: ProfileEditorFocus.training),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: B05Layout.space20),
                _SectionLabel('CONNECTIONS'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.favorite_border_rounded,
                      title: 'Health integration',
                      summary: healthSummary.isConnected
                          ? 'Connected'
                          : 'Not connected',
                      onTap: () => _push(context, const HealthSyncHubScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: B05Layout.space20),
                _SectionLabel('APP'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      summary: _themeLabel(themeMode),
                      onTap: () => _showThemePicker(context, ref, themeMode),
                    ),
                    _SettingsRow(
                      icon: Icons.straighten_outlined,
                      title: 'Units',
                      summary: units,
                      onTap: () => _showUnitPicker(context, ref, units),
                    ),
                    _SettingsRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      summary: 'Reminders and summaries',
                      onTap: () =>
                          _push(context, const NotificationSettingsScreen()),
                    ),
                    _SettingsRow(
                      icon: Icons.dashboard_customize_outlined,
                      title: 'Customize Today',
                      summary: 'Choose what appears on your home screen',
                      onTap: () => showIndiFitBottomSheet<void>(
                        context: context,
                        semanticLabel: 'Customize Today',
                        builder: (_) => const Padding(
                          padding: EdgeInsets.all(B05Layout.space16),
                          child: DashboardModuleCustomizationPanel(),
                        ),
                      ),
                    ),
                    _SettingsRow(
                      icon: Icons.water_drop_outlined,
                      title: 'Hydration',
                      summary: 'Water goal and glass size',
                      onTap: () =>
                          _push(context, const WaterSettingsSubScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: B05Layout.space20),
                _SectionLabel('LEARN'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.menu_book_outlined,
                      title: 'Learn',
                      summary: 'Short, optional guides',
                      onTap: () => _push(context, const LearnScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: B05Layout.space20),
                _SectionLabel('ADVANCED'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.local_drink_outlined,
                      title: 'Household measures',
                      summary: 'Cups, bowls, and personal measures',
                      onTap: () =>
                          _push(context, const HouseholdMeasuresScreen()),
                    ),
                    _SettingsRow(
                      icon: Icons.fitness_center_outlined,
                      title: 'Equipment profiles',
                      summary: 'Used when building a plan',
                      onTap: () =>
                          _push(context, const EquipmentProfilesScreen()),
                    ),
                    if (playlistAvailable)
                      _SettingsRow(
                        icon: Icons.music_note_outlined,
                        title: 'Workout playlist',
                        summary: 'Optional music for workouts',
                        onTap: () =>
                            _push(context, const B05PlaylistSettingsScreen()),
                      ),
                    _SettingsRow(
                      icon: Icons.restaurant_menu_outlined,
                      title: 'Food library',
                      summary: 'Regional food packs',
                      onTap: () =>
                          _push(context, const RegionalFoodPacksScreen()),
                    ),
                    _SettingsRow(
                      icon: Icons.track_changes_outlined,
                      title: 'Nutrition targets',
                      summary: 'Review or adjust your targets',
                      onTap: () =>
                          _push(context, const NutritionTargetsHubScreen()),
                    ),
                    _SettingsRow(
                      icon: Icons.auto_graph_outlined,
                      title: 'Goals & adaptive coaching',
                      summary: 'Manage goals and coaching preferences',
                      onTap: () =>
                          _push(context, const NutritionGoalsSubScreen()),
                    ),
                    _SettingsRow(
                      icon: Icons.sd_storage_outlined,
                      title: 'Data and backup',
                      summary: 'Export, restore, and offline options',
                      onTap: () =>
                          _push(context, const DataManagementSubScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: B05Layout.space24),
                const _MedicalDisclaimerCard(),
              ],
            ),
    );
  }

  static String _dietLabel(String value) {
    final option = DietPreferencePresentation.optionForUiValue(
      DietPreferencePresentation.uiValueFor(value),
    );
    if (option == null) return 'Choose a dietary pattern';
    return option.label.split(' (').first;
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  static Future<void> _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Appearance')),
            for (final mode in ThemeMode.values)
              RadioListTile<ThemeMode>(
                title: Text(_themeLabel(mode)),
                value: mode,
                // ignore: deprecated_member_use
                groupValue: current,
                // ignore: deprecated_member_use
                onChanged: (value) {
                  if (value == null) return;
                  ref.read(themeModeProvider.notifier).setThemeMode(value);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showUnitPicker(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Units')),
            for (final unit in const ['Metric', 'Imperial'])
              RadioListTile<String>(
                title: Text(unit),
                subtitle: Text(
                  unit == 'Metric' ? 'kg, cm, and mL' : 'lb, in, and fl oz',
                ),
                value: unit,
                // ignore: deprecated_member_use
                groupValue: current,
                // ignore: deprecated_member_use
                onChanged: (value) {
                  if (value == null) return;
                  ref.read(unitPreferenceProvider.notifier).setUnits(value);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      left: B05Layout.space4,
      bottom: B05Layout.space8,
    ),
    child: Text(
      label,
      style: B05Typography.caption(context).copyWith(
        color: context.b05Colors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: .8,
      ),
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => B05Surface(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1)
            Divider(height: 1, color: context.b05Colors.border),
        ],
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.summary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title, $summary',
    onTap: onTap,
    child: ListTile(
      minVerticalPadding: B05Layout.space8,
      leading: Icon(icon, color: context.b05Colors.action),
      title: Text(title, style: B05Typography.label(context)),
      subtitle: Text(summary, style: B05Typography.caption(context)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class _MedicalDisclaimerCard extends StatelessWidget {
  const _MedicalDisclaimerCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.b05Colors;
    return B05Surface(
      tone: B05SurfaceTone.inset,
      child: Semantics(
        container: true,
        label: 'Health and safety information',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  color: colors.danger.foreground,
                ),
                const SizedBox(width: B05Layout.space8),
                Text('Health and safety', style: B05Typography.label(context)),
              ],
            ),
            const SizedBox(height: B05Layout.space8),
            Text(
              'IndiFit provides general fitness information, not medical advice. Check with a clinician before changing exercise or diet for a medical condition.',
              style: B05Typography.caption(context),
            ),
          ],
        ),
      ),
    );
  }
}
