import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/crash_reporting_service.dart';
import '../../core/utils/app_logger.dart';
import '../database/app_database.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

enum HealthCategory {
  steps,
  activeEnergy,
  sleep,
  workoutImport,
  workoutExport,
  weightExport,
}

class HealthDataSummary {
  final int steps;
  final double activeCalories;
  final double sleepHours;
  final bool isConnected;
  final bool isError;
  final String? statusMessage;
  final Map<HealthCategory, bool> categoryStates;
  final int skippedDuplicatesCount;

  const HealthDataSummary({
    this.steps = 0,
    this.activeCalories = 0.0,
    this.sleepHours = 0.0,
    this.isConnected = false,
    this.isError = false,
    this.statusMessage,
    this.categoryStates = const {},
    this.skippedDuplicatesCount = 0,
  });
}

class HealthService {
  final Health _health;

  HealthService([Health? health]) : _health = health ?? Health();

  static const Map<HealthCategory, String> categoryPrefKeys = {
    HealthCategory.steps: 'health_category_steps',
    HealthCategory.activeEnergy: 'health_category_active_energy',
    HealthCategory.sleep: 'health_category_sleep',
    HealthCategory.workoutImport: 'health_category_workout_import',
    HealthCategory.workoutExport: 'health_category_workout_export',
    HealthCategory.weightExport: 'health_category_weight_export',
  };

  static List<HealthDataType> _getTypesForCategory(HealthCategory category) {
    return switch (category) {
      HealthCategory.steps => [HealthDataType.STEPS],
      HealthCategory.activeEnergy => [HealthDataType.ACTIVE_ENERGY_BURNED],
      HealthCategory.sleep => [HealthDataType.SLEEP_SESSION],
      HealthCategory.workoutImport => [HealthDataType.WORKOUT],
      HealthCategory.workoutExport => [HealthDataType.WORKOUT],
      HealthCategory.weightExport => [HealthDataType.WEIGHT],
    };
  }

  static List<HealthDataAccess> _getPermissionsForCategory(
    HealthCategory category,
  ) {
    return switch (category) {
      HealthCategory.workoutExport ||
      HealthCategory.weightExport => [HealthDataAccess.WRITE],
      _ => [HealthDataAccess.READ],
    };
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('health_last_sync_time');
  }

  Future<void> setLastSyncTime([DateTime? time]) async {
    final prefs = await SharedPreferences.getInstance();
    final t = time ?? DateTime.now();
    await prefs.setString('health_last_sync_time', t.toIso8601String());
  }

  Future<bool> getCategoryState(HealthCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    final key = categoryPrefKeys[category]!;
    return prefs.getBool(key) ?? true;
  }

  Future<void> setCategoryState(HealthCategory category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final key = categoryPrefKeys[category]!;
    await prefs.setBool(key, enabled);
  }

  Future<Map<HealthCategory, bool>> getAllCategoryStates() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <HealthCategory, bool>{};
    for (final cat in HealthCategory.values) {
      final key = categoryPrefKeys[cat]!;
      result[cat] = prefs.getBool(key) ?? true;
    }
    return result;
  }

  /// Request category-specific native SDK permissions
  Future<bool> requestCategoryPermissions(HealthCategory category) async {
    final types = _getTypesForCategory(category);
    final perms = _getPermissionsForCategory(category);
    return _ensurePermissions(types, perms);
  }

  /// Request all enabled category permissions
  Future<bool> requestPermissions() async {
    final states = await getAllCategoryStates();
    final types = <HealthDataType>[];
    final perms = <HealthDataAccess>[];

    for (final cat in HealthCategory.values) {
      if (states[cat] == true) {
        types.addAll(_getTypesForCategory(cat));
        perms.addAll(_getPermissionsForCategory(cat));
      }
    }

    if (types.isEmpty) return true;
    return _ensurePermissions(types, perms);
  }

  Future<bool> _ensurePermissions(
    List<HealthDataType> types,
    List<HealthDataAccess> permissions,
  ) async {
    try {
      await _health.configure();
      bool? hasPermissions = await _health.hasPermissions(
        types,
        permissions: permissions,
      );
      if (hasPermissions != true) {
        return await _health.requestAuthorization(
          types,
          permissions: permissions,
        );
      }
      return true;
    } catch (e, st) {
      AppLogger.warning('Health permission request failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'health permission request error',
      );
      return false;
    }
  }

  /// Fetch today's health metrics respecting active category toggles
  Future<HealthDataSummary> fetchTodayHealthData() async {
    try {
      await _health.configure();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final categoryStates = await getAllCategoryStates();

      int steps = 0;
      double activeCals = 0.0;
      double sleepMinutes = 0.0;

      // 1. Steps
      if (categoryStates[HealthCategory.steps] == true) {
        final stepAuthorized = await _ensurePermissions(
          [HealthDataType.STEPS],
          [HealthDataAccess.READ],
        );
        if (stepAuthorized) {
          steps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;
        }
      }

      // 2. Active Energy Burned
      if (categoryStates[HealthCategory.activeEnergy] == true) {
        final energyAuthorized = await _ensurePermissions(
          [HealthDataType.ACTIVE_ENERGY_BURNED],
          [HealthDataAccess.READ],
        );
        if (energyAuthorized) {
          final data = await _health.getHealthDataFromTypes(
            startTime: midnight,
            endTime: now,
            types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          );
          for (final point in data) {
            final val = point.value;
            if (val is NumericHealthValue) {
              activeCals += val.numericValue.toDouble();
            }
          }
        }
      }

      // 3. Sleep Session
      if (categoryStates[HealthCategory.sleep] == true) {
        final sleepAuthorized = await _ensurePermissions(
          [HealthDataType.SLEEP_SESSION],
          [HealthDataAccess.READ],
        );
        if (sleepAuthorized) {
          final data = await _health.getHealthDataFromTypes(
            startTime: midnight,
            endTime: now,
            types: [HealthDataType.SLEEP_SESSION],
          );
          for (final point in data) {
            sleepMinutes += point.dateTo
                .difference(point.dateFrom)
                .inMinutes
                .toDouble();
          }
        }
      }

      await setLastSyncTime(now);

      return HealthDataSummary(
        steps: steps,
        activeCalories: activeCals,
        sleepHours: sleepMinutes / 60.0,
        isConnected: true,
        categoryStates: categoryStates,
      );
    } catch (e) {
      return HealthDataSummary(
        isConnected: false,
        isError: true,
        statusMessage: 'Health sync unavailable: $e',
      );
    }
  }

  /// Import outdoor activities with provenance tracking and duplicate prevention
  Future<List<Map<String, dynamic>>> importOutdoorActivities([AppDatabase? db]) async {
    try {
      final categoryStates = await getAllCategoryStates();
      if (categoryStates[HealthCategory.workoutImport] != true) return [];

      final authorized = await _ensurePermissions(
        [HealthDataType.WORKOUT],
        [HealthDataAccess.READ],
      );
      if (!authorized) return [];

      final now = DateTime.now();
      final startTime = now.subtract(const Duration(days: 7));

      final data = await _health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );

      final List<Map<String, dynamic>> activities = [];

      for (final p in data) {
        final val = p.value;
        if (val is WorkoutHealthValue) {
          final typeStr = val.workoutActivityType.name.toLowerCase();
          if (typeStr.contains('walking') || typeStr.contains('running')) {
            final duration = p.dateTo.difference(p.dateFrom).inMinutes;
            final cals = val.totalEnergyBurned ?? 0;
            final fingerprint =
                '${p.dateFrom.toIso8601String()}_${typeStr}_${cals}_$duration';

            // Idempotency check: Skip if fingerprint exists in HealthProvenances or source is indifit_app
            if (db != null) {
              final existing = await (db.select(db.healthProvenances)
                    ..where((tbl) => tbl.fingerprint.equals(fingerprint)))
                  .getSingleOrNull();

              if (existing != null || p.sourceName == 'indifit_app') {
                continue;
              }
            }

            activities.add({
              'title': typeStr.contains('running')
                  ? 'Outdoor Run'
                  : 'Outdoor Walk',
              'durationMinutes': duration,
              'calories': cals,
              'date': p.dateFrom,
              'fingerprint': fingerprint,
              'sourceName': p.sourceName,
            });
          }
        }
      }

      return activities;
    } catch (e, st) {
      AppLogger.warning('importOutdoorActivities failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'importOutdoorActivities error',
      );
      return [];
    }
  }

  /// Write logged workout session to HealthKit / Health Connect with origin tag
  Future<bool> writeWorkoutSession({
    required String title,
    required int durationMinutes,
    required int caloriesBurned,
    required DateTime startTime,
  }) async {
    try {
      final categoryStates = await getAllCategoryStates();
      if (categoryStates[HealthCategory.workoutExport] != true) return false;

      final authorized = await _ensurePermissions(
        [HealthDataType.WORKOUT],
        [HealthDataAccess.WRITE],
      );
      if (!authorized) return false;

      final endTime = startTime.add(Duration(minutes: durationMinutes));
      return await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
        title: '$title (IndiFit)',
        start: startTime,
        end: endTime,
        totalEnergyBurned: caloriesBurned,
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      );
    } catch (e, st) {
      AppLogger.warning('writeWorkoutSession failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'writeWorkoutSession error',
      );
      return false;
    }
  }

  /// Write body weight log measurement to HealthKit / Health Connect
  Future<bool> writeBodyWeight(double weightKg, [DateTime? timestamp]) async {
    try {
      final categoryStates = await getAllCategoryStates();
      if (categoryStates[HealthCategory.weightExport] != true) return false;

      final authorized = await _ensurePermissions(
        [HealthDataType.WEIGHT],
        [HealthDataAccess.WRITE],
      );
      if (!authorized) return false;

      final time = timestamp ?? DateTime.now();
      return await _health.writeHealthData(
        value: weightKg,
        type: HealthDataType.WEIGHT,
        startTime: time,
        endTime: time,
        unit: HealthDataUnit.KILOGRAM,
      );
    } catch (e, st) {
      AppLogger.warning('writeBodyWeight failed: $e');
      CrashReportingService.recordCrash(e, st, reason: 'writeBodyWeight error');
      return false;
    }
  }
}
