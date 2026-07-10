import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/providers.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/colors.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _remindWorkout = false;
  bool _remindMeals = false;
  bool _remindWater = false;
  bool _remindEvening = false;
  bool _remindWeekly = false;
  bool _offlineOnly = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _remindWorkout = prefs.getBool(NotificationService.prefRemindWorkout) ?? false;
      _remindMeals = prefs.getBool(NotificationService.prefRemindMeals) ?? false;
      _remindWater = prefs.getBool(NotificationService.prefRemindWater) ?? false;
      _remindEvening = prefs.getBool(NotificationService.prefRemindEvening) ?? false;
      _remindWeekly = prefs.getBool(NotificationService.prefRemindWeekly) ?? false;
      _offlineOnly = prefs.getBool('offline_only') ?? false;
      _loading = false;
    });
  }

  Future<void> _exportData() async {
    try {
      final db = ref.read(databaseProvider);
      
      final foodItems = await db.select(db.foodItems).get();
      final foodLogs = await db.select(db.foodLogs).get();
      final sessions = await db.select(db.workoutSessions).get();
      final sets = await db.select(db.workoutSets).get();
      final measurements = await db.select(db.bodyMeasurements).get();
      final routines = await db.select(db.workoutRoutines).get();
      final routineDays = await db.select(db.routineDays).get();
      final routineExercises = await db.select(db.routineExercises).get();

      final exportMap = {
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'food_items': foodItems.map((f) => {
          'name': f.name,
          'name_hindi': f.nameHindi,
          'calories': f.calories,
          'protein_g': f.proteinG,
          'carbs_g': f.carbsG,
          'fat_g': f.fatG,
          'fiber_g': f.fiberG,
          'serving_size': f.servingSize,
          'serving_unit': f.servingUnit,
          'category': f.category,
          'is_custom': f.isCustom,
        }).toList(),
        'food_logs': foodLogs.map((l) => {
          'name': l.name,
          'calories': l.calories,
          'protein_g': l.proteinG,
          'carbs_g': l.carbsG,
          'fat_g': l.fatG,
          'serving_logged': l.servingLogged,
          'serving_unit': l.servingUnit,
          'meal_type': l.mealType,
          'logged_at': l.loggedAt.toIso8601String(),
        }).toList(),
        'workout_sessions': sessions.map((s) => {
          'id': s.id,
          'name': s.name,
          'total_volume': s.totalVolume,
          'duration_seconds': s.durationSeconds,
          'estimated_calories': s.estimatedCalories,
          'completed_at': s.completedAt.toIso8601String(),
        }).toList(),
        'workout_sets': sets.map((s) => {
          'session_id': s.sessionId,
          'exercise_name': s.exerciseName,
          'weight': s.weight,
          'reps': s.reps,
          'set_number': s.setNumber,
          'is_pr': s.isPr,
        }).toList(),
        'body_measurements': measurements.map((m) => {
          'weight': m.weight,
          'waist': m.waist,
          'chest': m.chest,
          'arms': m.arms,
          'recorded_at': m.recordedAt.toIso8601String(),
        }).toList(),
        'workout_routines': routines.map((r) => {
          'id': r.id,
          'name': r.name,
          'goal': r.goal,
          'notes': r.notes,
          'created_at': r.createdAt.toIso8601String(),
        }).toList(),
        'routine_days': routineDays.map((d) => {
          'id': d.id,
          'routine_id': d.routineId,
          'day_of_week': d.dayOfWeek,
          'name': d.name,
          'is_rest_day': d.isRestDay,
        }).toList(),
        'routine_exercises': routineExercises.map((e) => {
          'day_id': e.dayId,
          'exercise_name': e.exerciseName,
          'sets': e.sets,
          'reps_range': e.repsRange,
          'order_index': e.orderIndex,
        }).toList(),
      };

      final jsonString = jsonEncode(exportMap);
      await Clipboard.setData(ClipboardData(text: jsonString));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data successfully exported and copied to clipboard!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export data: $e')),
        );
      }
    }
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

                  // Section header
                  _buildSectionHeader(
                    Icons.security_rounded,
                    'Privacy & Data Management',
                    'Manage your local data. Everything remains on your device.',
                  ),
                  const SizedBox(height: 16),

                  // Offline Toggle
                  _buildReminderToggle(
                    icon: Icons.cloud_off_rounded,
                    iconColor: Colors.cyan,
                    title: 'No Backend Mode',
                    subtitle: 'Disable all cloud features and backups',
                    value: _offlineOnly,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('offline_only', val);
                      setState(() => _offlineOnly = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Export JSON Database
                  ElevatedButton.icon(
                    onPressed: _exportData,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Export Local Database (JSON)'),
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

                  const SizedBox(height: 32),

                  // Section header
                  _buildSectionHeader(
                    Icons.health_and_safety_rounded,
                    'Health & Safety Disclaimer',
                    'IndiFit is for informational purposes only.',
                  ),
                  const SizedBox(height: 16),

                  // Medical Disclaimer Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
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
