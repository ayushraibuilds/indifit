import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../data/database/app_database.dart';
import '../utils/app_logger.dart';

class AutoBackupService {
  final AppDatabase _db;

  AutoBackupService(this._db);

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

      final backupData = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'food_logs': foodLogs.map((f) => {
          'name': f.name,
          'calories': f.calories,
          'protein_g': f.proteinG,
          'carbs_g': f.carbsG,
          'fat_g': f.fatG,
          'serving_logged': f.servingLogged,
          'serving_unit': f.servingUnit,
          'meal_type': f.mealType,
          'logged_at': f.loggedAt.toIso8601String(),
        }).toList(),
        'workout_sessions': workoutSessions.map((s) => {
          'id': s.id,
          'routine_name': s.routineName,
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
        }).toList(),
        'body_measurements': bodyMeasurements.map((m) => {
          'recorded_at': m.recordedAt.toIso8601String(),
          'weight': m.weight,
          'waist': m.waist,
          'chest': m.chest,
          'arms': m.arms,
          'thighs': m.thighs,
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
