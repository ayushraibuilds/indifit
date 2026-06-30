import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _remindWorkout = true;
  bool _remindMeals = true;
  bool _remindWater = true;
  bool _remindEvening = true;
  bool _remindWeekly = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _remindWorkout = prefs.getBool(NotificationService.prefRemindWorkout) ?? true;
      _remindMeals = prefs.getBool(NotificationService.prefRemindMeals) ?? true;
      _remindWater = prefs.getBool(NotificationService.prefRemindWater) ?? true;
      _remindEvening = prefs.getBool(NotificationService.prefRemindEvening) ?? true;
      _remindWeekly = prefs.getBool(NotificationService.prefRemindWeekly) ?? true;
      _loading = false;
    });
  }

  Future<void> _onToggleChanged(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    // Reschedule all reminders based on updated prefs
    await NotificationService.scheduleAllReminders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  _buildSectionHeader(
                    Icons.notifications_active_rounded,
                    'Notification Reminders',
                    'Gentle reminders to keep you on track. We keep it minimal — no spam.',
                  ),
                  const SizedBox(height: 16),

                  // Workout reminder
                  _buildReminderToggle(
                    icon: Icons.fitness_center_rounded,
                    iconColor: Colors.orange,
                    title: 'Workout Reminder',
                    subtitle: 'Daily at 7:30 AM — Start your training',
                    value: _remindWorkout,
                    onChanged: (val) {
                      setState(() => _remindWorkout = val);
                      _onToggleChanged(NotificationService.prefRemindWorkout, val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Meal logging reminders
                  _buildReminderToggle(
                    icon: Icons.restaurant_rounded,
                    iconColor: Colors.green,
                    title: 'Meal Logging',
                    subtitle: 'Post-lunch (1:30 PM) & post-dinner (8:30 PM)',
                    value: _remindMeals,
                    onChanged: (val) {
                      setState(() => _remindMeals = val);
                      _onToggleChanged(NotificationService.prefRemindMeals, val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Water intake reminders
                  _buildReminderToggle(
                    icon: Icons.water_drop_rounded,
                    iconColor: Colors.blue,
                    title: 'Water Intake',
                    subtitle: 'Twice daily (11 AM & 4 PM) — gentle hydration nudge',
                    value: _remindWater,
                    onChanged: (val) {
                      setState(() => _remindWater = val);
                      _onToggleChanged(NotificationService.prefRemindWater, val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Evening nudge
                  _buildReminderToggle(
                    icon: Icons.bedtime_rounded,
                    iconColor: Colors.purple,
                    title: 'Evening Log Nudge',
                    subtitle: '9:15 PM — "Did you log today?" Keep your streak alive',
                    value: _remindEvening,
                    onChanged: (val) {
                      setState(() => _remindEvening = val);
                      _onToggleChanged(NotificationService.prefRemindEvening, val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Weekly AI report
                  _buildReminderToggle(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: AppColors.primary,
                    title: 'Weekly AI Report',
                    subtitle: 'Sunday 10 AM — Personalized weekly fitness summary',
                    value: _remindWeekly,
                    onChanged: (val) {
                      setState(() => _remindWeekly = val);
                      _onToggleChanged(NotificationService.prefRemindWeekly, val);
                    },
                  ),

                  const SizedBox(height: 32),

                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'IndiFit sends at most 6 notifications per day. We deliberately skip breakfast reminders and limit water nudges to avoid overwhelming you. All data stays on your device.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // App version
                  Center(
                    child: Text(
                      'IndiFit v1.0.0 • Offline-First Fitness',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildReminderToggle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: value ? iconColor.withOpacity(0.04) : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? iconColor.withOpacity(0.2) : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),

          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Toggle switch
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: iconColor,
          ),
        ],
      ),
    );
  }
}
