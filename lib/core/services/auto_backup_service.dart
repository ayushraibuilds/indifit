import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../data/database/app_database.dart';
import '../utils/app_logger.dart';

class AutoBackupService {
  final AppDatabase _db;

  AutoBackupService(this._db);

  static Future<void> performBackup(AppDatabase db) async {
    final service = AutoBackupService(db);
    await service.runAutoBackup();
  }

  Future<void> runAutoBackup() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docDir.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final foodLogs = await _db.select(_db.foodLogs).get();
      final workoutSessions = await _db.select(_db.workoutSessions).get();
      final workoutSets = await _db.select(_db.workoutSets).get();
      final bodyMeasurements = await _db.select(_db.bodyMeasurements).get();

      final foodItems = await _db.select(_db.foodItems).get();
      final workoutRoutines = await _db.select(_db.workoutRoutines).get();
      final routineDays = await _db.select(_db.routineDays).get();
      final routineExercises = await _db.select(_db.routineExercises).get();

      final backupData = {
        'version': 2,
        'timestamp': DateTime.now().toIso8601String(),
        'food_items': foodItems.where((f) => f.isCustom).map((f) => {
          'id': f.id,
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
        'food_logs': foodLogs.map((f) => {
          'food_item_id': f.foodItemId,
          'name': f.name,
          'calories': f.calories,
          'protein_g': f.proteinG,
          'carbs_g': f.carbsG,
          'fat_g': f.fatG,
          'serving_logged': f.servingLogged,
          'serving_unit': f.servingUnit,
          'meal_type': f.mealType,
          'meal_group_id': f.mealGroupId,
          'uuid': f.uuid,
          'logged_at': f.loggedAt.toIso8601String(),
        }).toList(),
        'workout_sessions': workoutSessions.map((s) => {
          'id': s.id,
          'name': s.name,
          'routine_name': s.name,
          'total_volume': s.totalVolume,
          'duration_seconds': s.durationSeconds,
          'estimated_calories': s.estimatedCalories,
          'uuid': s.uuid,
          'completed_at': s.completedAt.toIso8601String(),
        }).toList(),
        'workout_sets': workoutSets.map((s) => {
          'session_id': s.sessionId,
          'exercise_name': s.exerciseName,
          'weight': s.weight,
          'reps': s.reps,
          'set_number': s.setNumber,
          'is_pr': s.isPr,
          'is_warmup': s.isWarmUp,
          'rpe': s.rpe,
          'set_notes': s.setNotes,
          'uuid': s.uuid,
        }).toList(),
        'body_measurements': bodyMeasurements.map((m) => {
          'recorded_at': m.recordedAt.toIso8601String(),
          'weight': m.weight,
          'waist': m.waist,
          'chest': m.chest,
          'arms': m.arms,
        }).toList(),
        'workout_routines': workoutRoutines.map((r) => {
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
          'id': e.id,
          'day_id': e.dayId,
          'exercise_name': e.exerciseName,
          'sets': e.sets,
          'reps_range': e.repsRange,
          'order_index': e.orderIndex,
        }).toList(),
      };

      final jsonStr = jsonEncode(backupData);
      
      // Rotate existing backups (1 -> 2, 2 -> 3)
      final f3 = File('${backupDir.path}/indifit_auto_backup_3.json');
      final f2 = File('${backupDir.path}/indifit_auto_backup_2.json');
      final f1 = File('${backupDir.path}/indifit_auto_backup_1.json');

      if (await f2.exists()) {
        await f2.copy(f3.path);
      }
      if (await f1.exists()) {
        await f1.copy(f2.path);
      }

      await f1.writeAsString(jsonStr);
      AppLogger.info('Auto-backup snapshot created successfully', 'AutoBackupService');
    } catch (e, stackTrace) {
      AppLogger.error('Auto-backup snapshot failed', e, stackTrace, 'AutoBackupService');
    }
  }
}
