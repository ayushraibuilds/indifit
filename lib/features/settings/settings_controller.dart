import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/encryption_helper.dart';
import '../../core/utils/csv_exporter.dart';
import '../../data/database/app_database.dart';

class SettingsState {
  final bool remindWorkout;
  final bool remindMeals;
  final bool remindWater;
  final bool remindEvening;
  final bool remindWeekly;
  final bool offlineOnly;
  final bool loading;
  final int waterGoal;
  final int glassSize;

  const SettingsState({
    this.remindWorkout = false,
    this.remindMeals = false,
    this.remindWater = false,
    this.remindEvening = false,
    this.remindWeekly = false,
    this.offlineOnly = false,
    this.loading = true,
    this.waterGoal = 8,
    this.glassSize = 250,
  });

  SettingsState copyWith({
    bool? remindWorkout,
    bool? remindMeals,
    bool? remindWater,
    bool? remindEvening,
    bool? remindWeekly,
    bool? offlineOnly,
    bool? loading,
    int? waterGoal,
    int? glassSize,
  }) {
    return SettingsState(
      remindWorkout: remindWorkout ?? this.remindWorkout,
      remindMeals: remindMeals ?? this.remindMeals,
      remindWater: remindWater ?? this.remindWater,
      remindEvening: remindEvening ?? this.remindEvening,
      remindWeekly: remindWeekly ?? this.remindWeekly,
      offlineOnly: offlineOnly ?? this.offlineOnly,
      loading: loading ?? this.loading,
      waterGoal: waterGoal ?? this.waterGoal,
      glassSize: glassSize ?? this.glassSize,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  final Ref _ref;

  SettingsController(this._ref) : super(const SettingsState()) {
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      remindWorkout: prefs.getBool(NotificationService.prefRemindWorkout) ?? false,
      remindMeals: prefs.getBool(NotificationService.prefRemindMeals) ?? false,
      remindWater: prefs.getBool(NotificationService.prefRemindWater) ?? false,
      remindEvening: prefs.getBool(NotificationService.prefRemindEvening) ?? false,
      remindWeekly: prefs.getBool(NotificationService.prefRemindWeekly) ?? false,
      offlineOnly: prefs.getBool('offline_only') ?? false,
      waterGoal: prefs.getInt('water_goal') ?? 8,
      glassSize: prefs.getInt('water_glass_size') ?? 250,
      loading: false,
    );
  }

  Future<void> toggleReminder(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    await NotificationService.scheduleAllReminders();
    await loadPreferences();
  }

  Future<void> toggleOfflineOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_only', value);
    state = state.copyWith(offlineOnly: value);
  }

  Future<void> updateWaterGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_goal', goal);
    await _ref.read(waterProvider.notifier).updateGoal(goal);
    state = state.copyWith(waterGoal: goal);
  }

  Future<void> updateGlassSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('water_glass_size', size);
    await _ref.read(waterProvider.notifier).updateGlassSize(size);
    state = state.copyWith(glassSize: size);
  }

  Future<String?> performExport(String password) async {
    state = state.copyWith(loading: true);
    try {
      final db = _ref.read(databaseProvider);

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
        }).toList(),
        'routine_exercises': routineExercises.map((e) => {
          'id': e.id,
          'day_id': e.dayId,
          'exercise_name': e.exerciseName,
          'sets': e.sets,
          'reps_range': e.repsRange,
          'order_index': e.orderIndex,
        }).toList(),
      };

      final jsonStr = jsonEncode(exportMap);
      final finalData = EncryptionHelper.encrypt(jsonStr, password);

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final file = File('${tempDir.path}/indifit_backup_$dateStr.json');
      await file.writeAsString(finalData);

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], subject: 'IndiFit Health Backup');

      if (await file.exists()) {
        await file.delete();
      }
      return null;
    } catch (e) {
      return 'Failed to export backup: $e';
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> performRestore(Map<String, dynamic> data) async {
    state = state.copyWith(loading: true);
    try {
      final db = _ref.read(databaseProvider);

      await db.delete(db.foodLogs).go();
      await db.delete(db.foodItems).go();
      await db.delete(db.workoutSets).go();
      await db.delete(db.workoutSessions).go();
      await db.delete(db.bodyMeasurements).go();
      await db.delete(db.routineExercises).go();
      await db.delete(db.routineDays).go();
      await db.delete(db.workoutRoutines).go();

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
            servingSize: item['serving_size'] != null ? (item['serving_size'] as num).toDouble() : 100.0,
            servingUnit: item['serving_unit'] ?? 'g',
            category: item['category'] ?? 'General',
            isCustom: Value(item['is_custom'] ?? false),
          ));
        }
      }

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
            servingUnit: item['serving_unit'] ?? 'g',
            mealType: item['meal_type'] ?? 'lunch',
            mealGroupId: Value(item['meal_group_id']),
            uuid: Value(item['uuid'] ?? const Uuid().v4()),
            loggedAt: Value(DateTime.parse(item['logged_at'])),
          ));
        }
      }

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

      if (data['workout_routines'] != null) {
        for (final item in data['workout_routines']) {
          await db.into(db.workoutRoutines).insert(WorkoutRoutinesCompanion.insert(
            id: Value(item['id']),
            name: item['name'],
            goal: item['goal']?.toString() ?? 'General Fitness',
            notes: Value(item['notes']?.toString()),
            createdAt: Value(item['created_at'] != null ? DateTime.parse(item['created_at']) : DateTime.now()),
          ));
        }
      }

      if (data['routine_days'] != null) {
        for (final item in data['routine_days']) {
          await db.into(db.routineDays).insert(RoutineDaysCompanion.insert(
            id: Value(item['id']),
            routineId: item['routine_id'],
            dayOfWeek: item['day_of_week'],
            name: item['name'],
          ));
        }
      }

      if (data['routine_exercises'] != null) {
        for (final item in data['routine_exercises']) {
          await db.into(db.routineExercises).insert(RoutineExercisesCompanion.insert(
            id: Value(item['id']),
            dayId: item['day_id'] ?? item['routine_day_id'] ?? 0,
            exerciseName: item['exercise_name'],
            sets: item['sets'],
            repsRange: item['reps_range'],
            orderIndex: item['order_index'],
          ));
        }
      }
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> exportCsvData() async {
    final db = _ref.read(databaseProvider);
    final foodLogs = await db.select(db.foodLogs).get();
    final foodCsv = CsvExporter.exportFoodLogsToCsv(foodLogs);

    final sessions = await db.select(db.workoutSessions).get();
    final sets = await db.select(db.workoutSets).get();
    final workoutCsv = CsvExporter.exportWorkoutSessionsToCsv(sessions, sets);

    final fullCsv = "=== FOOD LOGS ===\n$foodCsv\n\n=== WORKOUT SESSIONS ===\n$workoutCsv";
    await Clipboard.setData(ClipboardData(text: fullCsv));
  }

  Future<void> deleteAllData() async {
    final db = _ref.read(databaseProvider);
    await db.delete(db.foodLogs).go();
    await db.delete(db.foodItems).go();
    await db.delete(db.workoutSets).go();
    await db.delete(db.workoutSessions).go();
    await db.delete(db.bodyMeasurements).go();
    await db.delete(db.routineExercises).go();
    await db.delete(db.routineDays).go();
    await db.delete(db.workoutRoutines).go();
  }
}

final settingsControllerProvider = StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController(ref);
});
