import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/theme/colors.dart';
import '../settings_controller.dart';
import 'settings_reminder_toggle.dart';

class NotificationSettingsSection extends ConsumerWidget {
  const NotificationSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notification Reminders',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Gentle reminders to keep you on track. We keep it minimal — no spam.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsReminderToggle(
          icon: Icons.fitness_center_rounded,
          iconColor: Colors.orange,
          title: 'Workout Reminder',
          subtitle: 'Daily at 7:30 AM — Start your training',
          value: state.remindWorkout,
          onChanged: (val) => controller.toggleReminder(NotificationService.prefRemindWorkout, val),
        ),
        const SizedBox(height: 12),
        SettingsReminderToggle(
          icon: Icons.restaurant_rounded,
          iconColor: Colors.green,
          title: 'Meal Logging',
          subtitle: 'Post-lunch (1:30 PM) & post-dinner (8:30 PM)',
          value: state.remindMeals,
          onChanged: (val) => controller.toggleReminder(NotificationService.prefRemindMeals, val),
        ),
        const SizedBox(height: 12),
        SettingsReminderToggle(
          icon: Icons.water_drop_rounded,
          iconColor: Colors.blue,
          title: 'Water Intake',
          subtitle: 'Twice daily (11 AM & 4 PM) — gentle hydration nudge',
          value: state.remindWater,
          onChanged: (val) => controller.toggleReminder(NotificationService.prefRemindWater, val),
        ),
        const SizedBox(height: 12),
        SettingsReminderToggle(
          icon: Icons.bedtime_rounded,
          iconColor: Colors.purple,
          title: 'Evening Log Nudge',
          subtitle: '9:15 PM — "Did you log today?" Keep your streak alive',
          value: state.remindEvening,
          onChanged: (val) => controller.toggleReminder(NotificationService.prefRemindEvening, val),
        ),
        const SizedBox(height: 12),
        SettingsReminderToggle(
          icon: Icons.auto_awesome_rounded,
          iconColor: AppColors.primary,
          title: 'Weekly AI Report',
          subtitle: 'Sunday 10 AM — Personalized weekly fitness summary',
          value: state.remindWeekly,
          onChanged: (val) => controller.toggleReminder(NotificationService.prefRemindWeekly, val),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.do_not_disturb_on_rounded, color: Colors.indigo, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Quiet Hours',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Switch(
                      value: state.quietHoursEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) => controller.updateQuietHours(enabled: val),
                    ),
                  ],
                ),
                if (state.quietHoursEnabled) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'No notification alerts will sound during these hours:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: state.quietHoursStart,
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: List.generate(24, (h) => DropdownMenuItem(value: h, child: Text(_formatHour(h)))),
                          onChanged: (val) => controller.updateQuietHours(start: val),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: state.quietHoursEnd,
                          decoration: const InputDecoration(
                            labelText: 'End Time',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: List.generate(24, (h) => DropdownMenuItem(value: h, child: Text(_formatHour(h)))),
                          onChanged: (val) => controller.updateQuietHours(end: val),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatHour(int h) {
    if (h == 0) return '12:00 AM';
    if (h == 12) return '12:00 PM';
    if (h < 12) return '$h:00 AM';
    return '${h - 12}:00 PM';
  }
}

