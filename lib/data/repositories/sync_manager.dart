import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/di/providers.dart';
import '../database/app_database.dart';

final syncManagerProvider = Provider<SyncManager>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncManager(db);
});

class SyncManager {
  final AppDatabase _db;
  bool _syncing = false;

  SyncManager(this._db) {
    // Listen to network changes to automatically trigger sync
    Connectivity().onConnectivityChanged.listen((result) {
      if (result.contains(ConnectivityResult.mobile) || result.contains(ConnectivityResult.wifi)) {
        triggerSync();
      }
    });
  }

  // Trigger synchronization from local Drift DB to Supabase Cloud
  Future<void> triggerSync() async {
    if (_syncing) return;
    
    // Check if user enabled No Backend Mode (offline_only)
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineOnly = prefs.getBool('offline_only') ?? false;
      if (offlineOnly) {
        debugPrint("Offline-only mode is active. Sync bypassed.");
        return;
      }
    } catch (e) {
      // SharedPreferences error fallback
    }
    
    String? userId;
    try {
      // Accessing client throws StateError if Supabase is not initialized
      final client = Supabase.instance.client;
      userId = client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint("No authenticated user found. Sync bypassed.");
        return;
      }
    } catch (e) {
      return; // Bypassed
    }

    _syncing = true;
    debugPrint("Offline-first sync triggered for user $userId...");

    try {
      // 1. Sync food logs
      await _syncFoodLogs(userId);

      // 2. Sync workout sessions
      await _syncWorkoutSessions(userId);
      
      debugPrint("Offline-first sync completed successfully.");
    } catch (e) {
      debugPrint("Sync failed: $e");
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncFoodLogs(String userId) async {
    final client = Supabase.instance.client;
    
    // Get unsynced food logs
    final unsynced = await (_db.select(_db.foodLogs)..where((tbl) => tbl.isSynced.equals(false))).get();
    
    if (unsynced.isEmpty) return;

    final List<Map<String, dynamic>> payload = unsynced.map((log) {
      return {
        'id': log.id,
        'user_id': userId,
        'name': log.name,
        'calories': log.calories,
        'protein_g': log.proteinG,
        'carbs_g': log.carbsG,
        'fat_g': log.fatG,
        'serving_logged': log.servingLogged,
        'serving_unit': log.servingUnit,
        'meal_type': log.mealType,
        'logged_at': log.loggedAt.toIso8601String(),
      };
    }).toList();

    // Upsert to Supabase
    await client.from('food_logs').upsert(payload);

    // Update locally as synced
    for (final log in unsynced) {
      await (_db.update(_db.foodLogs)..where((tbl) => tbl.id.equals(log.id)))
          .write(const FoodLogsCompanion(isSynced: Value(true)));
    }
  }

  Future<void> _syncWorkoutSessions(String userId) async {
    final client = Supabase.instance.client;

    // Get unsynced workout sessions
    final unsynced = await (_db.select(_db.workoutSessions)..where((tbl) => tbl.isSynced.equals(false))).get();

    if (unsynced.isEmpty) return;

    for (final session in unsynced) {
      // Fetch sets associated with this session
      final sets = await (_db.select(_db.workoutSets)..where((tbl) => tbl.sessionId.equals(session.id))).get();

      // Upload session to Supabase
      final sessionResponse = await client.from('workout_sessions').upsert({
        'id': session.id,
        'user_id': userId,
        'name': session.name,
        'total_volume': session.totalVolume,
        'duration_seconds': session.durationSeconds,
        'estimated_calories': session.estimatedCalories,
        'completed_at': session.completedAt.toIso8601String(),
      }).select().single();

      final syncedSessionId = sessionResponse['id'] as int;

      // Upload sets to Supabase
      if (sets.isNotEmpty) {
        final List<Map<String, dynamic>> setsPayload = sets.map((set) {
          return {
            'id': set.id,
            'session_id': syncedSessionId,
            'exercise_name': set.exerciseName,
            'weight': set.weight,
            'reps': set.reps,
            'set_number': set.setNumber,
            'is_pr': set.isPr,
          };
        }).toList();

        await client.from('workout_sets').upsert(setsPayload);
      }

      // Mark locally as synced
      await (_db.update(_db.workoutSessions)..where((tbl) => tbl.id.equals(session.id)))
          .write(const WorkoutSessionsCompanion(isSynced: Value(true)));
    }
  }
}
