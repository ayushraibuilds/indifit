import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

class HealthDataSummary {
  final int steps;
  final double activeCalories;
  final double sleepHours;
  final bool isConnected;
  final String? statusMessage;

  const HealthDataSummary({
    this.steps = 0,
    this.activeCalories = 0.0,
    this.sleepHours = 0.0,
    this.isConnected = false,
    this.statusMessage,
  });
}

class HealthService {
  final Health _health;

  HealthService([Health? health]) : _health = health ?? Health();

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_SESSION,
  ];

  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  /// Request permissions from the native Health OS SDK
  Future<bool> requestPermissions() async {
    try {
      await _health.configure();
      bool? hasPermissions = await _health.hasPermissions(_types, permissions: _permissions);
      if (hasPermissions != true) {
        bool authorized = await _health.requestAuthorization(_types, permissions: _permissions);
        return authorized;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetch today's step count, active calories burned, and sleep hours
  Future<HealthDataSummary> fetchTodayHealthData() async {
    try {
      await _health.configure();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      bool? hasPermissions = await _health.hasPermissions(_types, permissions: _permissions);
      if (hasPermissions != true) {
        return const HealthDataSummary(
          isConnected: false,
          statusMessage: 'Permissions not granted. Tap Connect to enable health sync.',
        );
      }

      int steps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;

      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataType.SLEEP_SESSION],
      );

      double activeCals = 0.0;
      double sleepMinutes = 0.0;

      for (var point in healthData) {
        if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          final val = point.value;
          if (val is NumericHealthValue) {
            activeCals += val.numericValue.toDouble();
          }
        } else if (point.type == HealthDataType.SLEEP_SESSION) {
          sleepMinutes += point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
        }
      }

      return HealthDataSummary(
        steps: steps,
        activeCalories: activeCals,
        sleepHours: sleepMinutes / 60.0,
        isConnected: true,
      );
    } catch (e) {
      return HealthDataSummary(
        isConnected: false,
        statusMessage: 'Health sync unavailable: $e',
      );
    }
  }

  /// Write logged workout session to HealthKit / Health Connect
  Future<bool> writeWorkoutSession({
    required String title,
    required int durationMinutes,
    required int caloriesBurned,
    required DateTime startTime,
  }) async {
    try {
      final endTime = startTime.add(Duration(minutes: durationMinutes));
      return await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
        title: title,
        start: startTime,
        end: endTime,
        totalEnergyBurned: caloriesBurned,
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      );
    } catch (_) {
      return false;
    }
  }

  /// Write body weight log measurement to HealthKit / Health Connect
  Future<bool> writeBodyWeight(double weightKg, [DateTime? timestamp]) async {
    try {
      final time = timestamp ?? DateTime.now();
      return await _health.writeHealthData(
        value: weightKg,
        type: HealthDataType.WEIGHT,
        startTime: time,
        endTime: time,
        unit: HealthDataUnit.KILOGRAM,
      );
    } catch (_) {
      return false;
    }
  }
}
