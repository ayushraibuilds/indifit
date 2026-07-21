import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/di/providers.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/encryption_helper.dart';
import '../../core/utils/csv_exporter.dart';
import '../../data/database/app_database.dart';
import 'health_sync_hub_screen.dart';
import 'widgets/backup_restore_card.dart';
import 'widgets/privacy_disclosure_card.dart';
import '../onboarding/onboarding_screen.dart';

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
  int _waterGoal = 8;
  int _glassSize = 250;
  final TextEditingController _waterGoalController = TextEditingController();
  final TextEditingController _glassSizeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _waterGoalController.dispose();
    _glassSizeController.dispose();
    super.dispose();
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
      _waterGoal = prefs.getInt('water_goal') ?? 8;
      _waterGoalController.text = _waterGoal.toString();
      _glassSize = prefs.getInt('water_glass_size') ?? 250;
      _glassSizeController.text = _glassSize.toString();
      _loading = false;
    });
  }

  Future<void> _exportData() async {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export & Encrypt Backup'),
        backgroundColor: AppColors.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a password to protect your backup file. If you leave this blank, the backup will be exported in plain text.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Backup Password (Optional)',
                hintText: 'Leave empty for no encryption',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final password = passwordController.text;
              Navigator.pop(context); // Close dialog
              await _performExport(password);
            },
            child: const Text('Export Backup'),
          ),
        ],
      ),
    );
  }

  Future<void> _performExport(String password) async {
    setState(() => _loading = true);
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
        'version': 2,
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
          'food_item_id': l.foodItemId,
          'name': l.name,
          'calories': l.calories,
          'protein_g': l.proteinG,
          'carbs_g': l.carbsG,
          'fat_g': l.fatG,
          'serving_logged': l.servingLogged,
          'serving_unit': l.servingUnit,
          'meal_type': l.mealType,
          'meal_group_id': l.mealGroupId,
          'uuid': l.uuid,
          'logged_at': l.loggedAt.toIso8601String(),
        }).toList(),
        'workout_sessions': sessions.map((s) => {
          'id': s.id,
          'name': s.name,
          'total_volume': s.totalVolume,
          'duration_seconds': s.durationSeconds,
          'estimated_calories': s.estimatedCalories,
          'uuid': s.uuid,
          'completed_at': s.completedAt.toIso8601String(),
        }).toList(),
        'workout_sets': sets.map((s) => {
          'session_id': s.sessionId,
          'exercise_name': s.exerciseName,
          'weight': s.weight,
          'reps': s.reps,
          'set_number': s.setNumber,
          'is_pr': s.isPr,
          'rpe': s.rpe,
          'is_warm_up': s.isWarmUp,
          'set_notes': s.setNotes,
          'uuid': s.uuid,
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
      final finalString = EncryptionHelper.encrypt(jsonString, password);
      await Clipboard.setData(ClipboardData(text: finalString));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(password.isEmpty 
              ? 'Data copied to clipboard! Opening share menu...' 
              : 'Password-encrypted backup copied to clipboard! Opening share menu...'
            ),
            backgroundColor: AppColors.success,
          ),
        );
        await _shareBackupFile(finalString, password.isNotEmpty);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export data: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _shareBackupFile(String backupText, bool isEncrypted) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final fileName = isEncrypted ? 'indifit_backup_$dateStr.enc' : 'indifit_backup_$dateStr.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(backupText);

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], subject: 'IndiFit Health Backup');
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share file: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _exportCsvData() async {
    final db = ref.read(databaseProvider);
    final foodLogs = await db.select(db.foodLogs).get();
    final foodCsv = CsvExporter.exportFoodLogsToCsv(foodLogs);

    final sessions = await db.select(db.workoutSessions).get();
    final sets = await db.select(db.workoutSets).get();
    final workoutCsv = CsvExporter.exportWorkoutSessionsToCsv(sessions, sets);

    final fullCsv = "=== FOOD LOGS ===\n$foodCsv\n\n=== WORKOUT SESSIONS ===\n$workoutCsv";
    await Clipboard.setData(ClipboardData(text: fullCsv));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Food & Workout data copied as CSV to clipboard!')),
      );
    }
  }

  Future<void> _showRestoreDialog() async {
    final backupController = TextEditingController();
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database Backup'),
        backgroundColor: AppColors.surface,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the backup text block below:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: backupController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Paste backup string here...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Decryption Password (if encrypted)',
                  hintText: 'Leave blank if unencrypted',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              final backup = backupController.text.trim();
              final password = passwordController.text;
              if (backup.isEmpty) return;

              // 1. Try to decrypt and parse the backup
              Map<String, dynamic> data;
              try {
                final decrypted = EncryptionHelper.decrypt(backup, password);
                data = jsonDecode(decrypted) as Map<String, dynamic>;
              } catch (e) {
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Decryption Failed'),
                      backgroundColor: AppColors.surface,
                      content: const Text(
                        'Unable to decrypt backup. Please check your password and verify that the backup string is not corrupted.',
                        style: TextStyle(height: 1.4),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
                return;
              }

              // 2. Extract stats for Restore Preview
              final version = data['version'] ?? 1;
              final exportedAtStr = data['exported_at'] ?? 'Unknown';
              String formattedDate = exportedAtStr;
              try {
                final date = DateTime.parse(exportedAtStr);
                formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
              } catch (_) {}

              final foodItemsCount = (data['food_items'] as List?)?.length ?? 0;
              final foodLogsCount = (data['food_logs'] as List?)?.length ?? 0;
              final workoutSessionsCount = (data['workout_sessions'] as List?)?.length ?? 0;
              final workoutSetsCount = (data['workout_sets'] as List?)?.length ?? 0;
              final measurementsCount = (data['body_measurements'] as List?)?.length ?? 0;
              final routinesCount = (data['workout_routines'] as List?)?.length ?? 0;

              // 3. Show Destructive Restore Confirmation with Preview Stats
              if (context.mounted) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Destructive Restore?'),
                    backgroundColor: AppColors.surface,
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BACKUP FILE PREVIEW',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('• Backup Version: $version', style: const TextStyle(fontSize: 12)),
                                Text('• Created: $formattedDate', style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 6),
                                const Divider(height: 12),
                                const SizedBox(height: 6),
                                const Text('Records to Restore:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('• Food Items: $foodItemsCount', style: const TextStyle(fontSize: 12)),
                                Text('• Food Logs: $foodLogsCount', style: const TextStyle(fontSize: 12)),
                                Text('• Workout Sessions: $workoutSessionsCount ($workoutSetsCount sets)', style: const TextStyle(fontSize: 12)),
                                Text('• Body Measurements: $measurementsCount', style: const TextStyle(fontSize: 12)),
                                Text('• Workout Routines: $routinesCount', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'WARNING: Restoring this backup will permanently overwrite all your current local food logs, workout history, routines, and body measurements. This action is destructive and cannot be undone.\n\nAre you sure you want to proceed?',
                            style: TextStyle(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete & Overwrite'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  Navigator.pop(context); // Close backup restore dialog
                  await _performRestore(backup, password);
                }
              }
            },
            child: const Text('Restore Data'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRestore(String backupText, String password) async {
    setState(() => _loading = true);
    try {
      String jsonText;
      try {
        jsonText = EncryptionHelper.decrypt(backupText, password);
      } catch (e) {
        throw const FormatException('Decryption failed. Check if password is correct.');
      }

      final db = ref.read(databaseProvider);
      final data = jsonDecode(jsonText);

      await db.transaction(() async {
        // Clear all tables in child-first order to prevent foreign key violations
        await db.delete(db.workoutSets).go();
        await db.delete(db.workoutSessions).go();
        await db.delete(db.routineExercises).go();
        await db.delete(db.routineDays).go();
        await db.delete(db.workoutRoutines).go();
        await db.delete(db.foodLogs).go();
        await db.delete(db.foodItems).go();
        await db.delete(db.bodyMeasurements).go();

        // Restore food items
        if (data['food_items'] != null) {
          for (final item in data['food_items']) {
            await db.into(db.foodItems).insert(FoodItemsCompanion.insert(
              name: item['name'],
              nameHindi: Value(item['name_hindi']),
              calories: (item['calories'] as num).toInt(),
              proteinG: (item['protein_g'] as num).toDouble(),
              carbsG: (item['carbs_g'] as num).toDouble(),
              fatG: (item['fat_g'] as num).toDouble(),
              fiberG: Value(item['fiber_g'] != null ? (item['fiber_g'] as num).toDouble() : null),
              servingSize: (item['serving_size'] as num).toDouble(),
              servingUnit: item['serving_unit'],
              category: item['category'] ?? 'General',
              isCustom: Value(item['is_custom'] ?? false),
            ));
          }
        }

        // Restore food logs
        if (data['food_logs'] != null) {
          for (final item in data['food_logs']) {
            await db.into(db.foodLogs).insert(FoodLogsCompanion.insert(
              foodItemId: Value(item['food_item_id']),
              name: item['name'],
              calories: (item['calories'] as num).toInt(),
              proteinG: (item['protein_g'] as num).toDouble(),
              carbsG: (item['carbs_g'] as num).toDouble(),
              fatG: (item['fat_g'] as num).toDouble(),
              servingLogged: (item['serving_logged'] as num).toDouble(),
              servingUnit: item['serving_unit'],
              mealType: item['meal_type'],
              mealGroupId: Value(item['meal_group_id']),
              uuid: Value(item['uuid'] ?? const Uuid().v4()),
              loggedAt: Value(DateTime.parse(item['logged_at'])),
            ));
          }
        }

        // Restore sessions
        if (data['workout_sessions'] != null) {
          for (final item in data['workout_sessions']) {
            await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
              id: Value(item['id']),
              name: item['name'] ?? item['routine_name'] ?? 'Workout Session',
              totalVolume: item['total_volume'] != null ? (item['total_volume'] as num).toDouble() : 0.0,
              durationSeconds: item['duration_seconds'] != null ? (item['duration_seconds'] as num).toInt() : 0,
              estimatedCalories: item['estimated_calories'] != null ? (item['estimated_calories'] as num).toInt() : 0,
              uuid: Value(item['uuid'] ?? const Uuid().v4()),
              completedAt: Value(DateTime.parse(item['completed_at'])),
            ));
          }
        }

        // Restore sets
        if (data['workout_sets'] != null) {
          for (final item in data['workout_sets']) {
            await db.into(db.workoutSets).insert(WorkoutSetsCompanion.insert(
              sessionId: item['session_id'],
              exerciseName: item['exercise_name'],
              weight: (item['weight'] as num).toDouble(),
              reps: (item['reps'] as num).toInt(),
              setNumber: (item['set_number'] as num).toInt(),
              isPr: Value(item['is_pr'] ?? false),
              rpe: Value(item['rpe'] != null ? (item['rpe'] as num).toInt() : null),
              isWarmUp: Value(item['is_warm_up'] ?? false),
              setNotes: Value(item['set_notes']),
              uuid: Value(item['uuid'] ?? const Uuid().v4()),
            ));
          }
        }

        // Restore body measurements
        if (data['body_measurements'] != null) {
          for (final item in data['body_measurements']) {
            await db.into(db.bodyMeasurements).insert(BodyMeasurementsCompanion.insert(
              weight: Value(item['weight'] != null ? (item['weight'] as num).toDouble() : null),
              waist: Value(item['waist'] != null ? (item['waist'] as num).toDouble() : null),
              chest: Value(item['chest'] != null ? (item['chest'] as num).toDouble() : null),
              arms: Value(item['arms'] != null ? (item['arms'] as num).toDouble() : null),
              recordedAt: Value(DateTime.parse(item['recorded_at'])),
            ));
          }
        }

        // Restore routines
        if (data['workout_routines'] != null) {
          for (final item in data['workout_routines']) {
            await db.into(db.workoutRoutines).insert(WorkoutRoutinesCompanion.insert(
              id: Value(item['id']),
              name: item['name'],
              goal: item['goal'],
              notes: Value(item['notes']),
              createdAt: Value(DateTime.parse(item['created_at'])),
            ));
          }
        }

        // Restore routine days
        if (data['routine_days'] != null) {
          for (final item in data['routine_days']) {
            await db.into(db.routineDays).insert(RoutineDaysCompanion.insert(
              id: Value(item['id']),
              routineId: item['routine_id'],
              dayOfWeek: (item['day_of_week'] as num).toInt(),
              name: item['name'],
              isRestDay: Value(item['is_rest_day'] ?? false),
            ));
          }
        }

        // Restore routine exercises
        if (data['routine_exercises'] != null) {
          for (final item in data['routine_exercises']) {
            await db.into(db.routineExercises).insert(RoutineExercisesCompanion.insert(
              dayId: item['day_id'],
              exerciseName: item['exercise_name'],
              sets: (item['sets'] as num).toInt(),
              repsRange: item['reps_range'],
              orderIndex: (item['order_index'] as num).toInt(),
            ));
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database successfully restored!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore backup: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Local Data?'),
        backgroundColor: AppColors.surface,
        content: const Text(
          'WARNING: This will permanently wipe all your logged meals, workout history, routines, and custom body measurements from this device. This action cannot be undone.\n\nAre you sure you want to proceed?',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _loading = true);
      try {
        final db = ref.read(databaseProvider);
        await db.transaction(() async {
          // Clear all tables in child-first order
          await db.delete(db.workoutSets).go();
          await db.delete(db.workoutSessions).go();
          await db.delete(db.routineExercises).go();
          await db.delete(db.routineDays).go();
          await db.delete(db.workoutRoutines).go();
          await db.delete(db.foodLogs).go();
          await db.delete(db.foodItems).go();
          await db.delete(db.bodyMeasurements).go();
        });

        // Reset water provider too
        final currentWater = ref.read(waterProvider).waterLogged;
        await ref.read(waterProvider.notifier).logWater(-currentWater);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All local data wiped successfully.'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear database: $e'), backgroundColor: AppColors.danger),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  Future<void> _resetOnboarding() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Onboarding?'),
        backgroundColor: AppColors.surface,
        content: const Text(
          'This will clear your onboarding preferences, target calorie calculations, and default goals. You will be redirected to the onboarding wizard to recalculate them.\n\nDo you want to proceed?',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', false);
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          (route) => false,
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
                  const SizedBox(height: 16),

                  // Daily Water Goal Input
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Water Goal',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Target glasses of water per day (250ml each)',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: _waterGoalController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                              onChanged: (val) async {
                                final parsed = int.tryParse(val) ?? 8;
                                if (parsed > 0 && parsed <= 40) {
                                  await ref.read(waterProvider.notifier).updateGoal(parsed);
                                  setState(() {
                                    _waterGoal = parsed;
                                  });
                                }
                              },
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Serving (Glass) Size',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Custom volume size per glass of water logged (ml)',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: _glassSizeController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                              onChanged: (val) async {
                                final parsed = int.tryParse(val) ?? 250;
                                if (parsed >= 50 && parsed <= 2000) {
                                  await ref.read(waterProvider.notifier).updateGlassSize(parsed);
                                  setState(() {
                                    _glassSize = parsed;
                                  });
                                }
                              },
                            ),
                          )
                        ],
                      ),
                    ),
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

                  // Health Sync Hub button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HealthSyncHubScreen()),
                      );
                    },
                    icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
                    label: const Text('Apple Health & Health Connect Sync'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.12),
                      foregroundColor: Colors.redAccent,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Export / Restore Database Card
                  BackupRestoreCard(
                    onExport: _exportData,
                    onRestore: _showRestoreDialog,
                  ),
                  const SizedBox(height: 8),

                  ElevatedButton.icon(
                    onPressed: _exportCsvData,
                    icon: const Icon(Icons.table_chart_rounded, color: AppColors.primary),
                    label: const Text('Export Food & Workout Data (CSV)'),
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
                  const SizedBox(height: 16),

                  // Data Explanation Box
                  const PrivacyDisclosureCard(),
                  const SizedBox(height: 16),

                  // Reset Onboarding Button
                  ElevatedButton.icon(
                    onPressed: _resetOnboarding,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.orangeAccent),
                    label: const Text('Reset Onboarding Wizard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent.withOpacity(0.12),
                      foregroundColor: Colors.orangeAccent,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.orangeAccent.withOpacity(0.2)),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Delete All Data Button
                  ElevatedButton.icon(
                    onPressed: _deleteAllData,
                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                    label: const Text('Wipe All Local Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger.withOpacity(0.12),
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.danger.withOpacity(0.2)),
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

                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showLicensePage(
                          context: context,
                          applicationName: 'IndiFit',
                          applicationVersion: '1.0.0',
                          applicationIcon: const Icon(Icons.fitness_center_rounded, size: 32, color: AppColors.primary),
                        );
                      },
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      label: const Text('Open Source Licenses & Attributions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

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
