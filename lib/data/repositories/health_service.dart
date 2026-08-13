import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/crash_reporting_service.dart';
import '../../core/utils/app_logger.dart';
import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import 'b02_health_activity_repository.dart';

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

enum HealthRecoveryMetricStatus { known, missing, unknown, invalid }

enum HealthRecoveryMetricPermission { granted, denied, unavailable, unknown }

enum HealthRecoveryMetricFreshness { fresh, stale, unknown }

/// Privacy-minimized recovery evidence read from the platform health source.
/// This is a B02/provider read boundary; B04 maps it into its own immutable
/// observation envelope without storing the raw platform payload.
class HealthRecoveryMetricRead {
  final String kind;
  final HealthRecoveryMetricStatus status;
  final HealthRecoveryMetricPermission permission;
  final HealthRecoveryMetricFreshness freshness;
  final double? value;
  final String unit;
  final DateTime? observedAtUtc;
  final String source;
  final String provenance;
  final String? providerExternalId;
  final String? sourceVersion;
  final DateTime? evidenceTimestampUtc;

  const HealthRecoveryMetricRead({
    required this.kind,
    required this.status,
    required this.permission,
    required this.freshness,
    required this.value,
    required this.unit,
    required this.observedAtUtc,
    required this.source,
    required this.provenance,
    required this.providerExternalId,
    required this.sourceVersion,
    required this.evidenceTimestampUtc,
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

    for (final cat in HealthCategory.values) {
      if (states[cat] == true) {
        final granted = await requestCategoryPermissions(cat);
        if (!granted) return false;
      }
    }

    return true;
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
      rethrow;
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

  /// Reads only the reviewed recovery metrics needed by B04. The method
  /// returns typed unavailable states instead of treating permission failures
  /// or empty provider data as numeric zero.
  Future<List<HealthRecoveryMetricRead>> readRecoveryMetrics({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    if (!startUtc.isUtc || !endUtc.isUtc || !endUtc.isAfter(startUtc)) {
      throw ArgumentError(
        'Recovery health windows must be ordered UTC instants.',
      );
    }
    return [
      await _readRecoveryMetric(
        kind: 'sleep_duration',
        type: HealthDataType.SLEEP_SESSION,
        unit: 'hours',
        startUtc: startUtc,
        endUtc: endUtc,
        category: HealthCategory.sleep,
        aggregate: (points) => points.fold<double>(
          0,
          (total, point) =>
              total + point.dateTo.difference(point.dateFrom).inMinutes / 60,
        ),
      ),
      await _readRecoveryMetric(
        kind: 'resting_heart_rate',
        type: HealthDataType.RESTING_HEART_RATE,
        unit: 'bpm',
        startUtc: startUtc,
        endUtc: endUtc,
        aggregate: (points) {
          final ordered = [...points]
            ..sort((left, right) => left.dateTo.compareTo(right.dateTo));
          final latest = ordered.isEmpty ? null : ordered.last;
          final value = latest?.value;
          return value is NumericHealthValue
              ? value.numericValue.toDouble()
              : null;
        },
      ),
    ];
  }

  Future<HealthRecoveryMetricRead> _readRecoveryMetric({
    required String kind,
    required HealthDataType type,
    required String unit,
    required DateTime startUtc,
    required DateTime endUtc,
    HealthCategory? category,
    required double? Function(List<HealthDataPoint>) aggregate,
  }) async {
    final source = 'health:${type.name.toLowerCase()}';
    final disabled = category != null && !(await getCategoryState(category));
    if (disabled) {
      return HealthRecoveryMetricRead(
        kind: kind,
        status: HealthRecoveryMetricStatus.missing,
        permission: HealthRecoveryMetricPermission.unavailable,
        freshness: HealthRecoveryMetricFreshness.unknown,
        value: null,
        unit: unit,
        observedAtUtc: null,
        source: source,
        provenance: '$source:disabled',
        providerExternalId: null,
        sourceVersion: 'health-read-v1',
        evidenceTimestampUtc: null,
      );
    }
    try {
      await _health.configure();
      final authorized = await _ensurePermissions(
        [type],
        [HealthDataAccess.READ],
      );
      if (!authorized) {
        return HealthRecoveryMetricRead(
          kind: kind,
          status: HealthRecoveryMetricStatus.missing,
          permission: HealthRecoveryMetricPermission.denied,
          freshness: HealthRecoveryMetricFreshness.unknown,
          value: null,
          unit: unit,
          observedAtUtc: null,
          source: source,
          provenance: '$source:permission',
          providerExternalId: null,
          sourceVersion: 'health-read-v1',
          evidenceTimestampUtc: null,
        );
      }
      final points = await _health.getHealthDataFromTypes(
        startTime: startUtc,
        endTime: endUtc,
        types: [type],
      );
      if (points.isEmpty) {
        return HealthRecoveryMetricRead(
          kind: kind,
          status: HealthRecoveryMetricStatus.missing,
          permission: HealthRecoveryMetricPermission.granted,
          freshness: HealthRecoveryMetricFreshness.unknown,
          value: null,
          unit: unit,
          observedAtUtc: null,
          source: source,
          provenance: '$source:no-data',
          providerExternalId: null,
          sourceVersion: 'health-read-v1',
          evidenceTimestampUtc: null,
        );
      }
      final ordered = [...points]
        ..sort((left, right) => left.dateTo.compareTo(right.dateTo));
      final latest = ordered.last;
      final observedAt = latest.dateTo.toUtc();
      final value = aggregate(ordered);
      if (value == null || !value.isFinite || value < 0) {
        return HealthRecoveryMetricRead(
          kind: kind,
          status: HealthRecoveryMetricStatus.invalid,
          permission: HealthRecoveryMetricPermission.granted,
          freshness: HealthRecoveryMetricFreshness.unknown,
          value: null,
          unit: unit,
          observedAtUtc: observedAt,
          source: source,
          provenance: '$source:${latest.sourceName}',
          providerExternalId: _optional(latest.uuid),
          sourceVersion: 'health-read-v1',
          evidenceTimestampUtc: observedAt,
        );
      }
      final freshness =
          endUtc.difference(observedAt) > const Duration(hours: 36)
          ? HealthRecoveryMetricFreshness.stale
          : HealthRecoveryMetricFreshness.fresh;
      return HealthRecoveryMetricRead(
        kind: kind,
        status: HealthRecoveryMetricStatus.known,
        permission: HealthRecoveryMetricPermission.granted,
        freshness: freshness,
        value: value,
        unit: unit,
        observedAtUtc: observedAt,
        source: source,
        provenance:
            '$source:${latest.sourcePlatform.name}:${latest.sourceName}',
        providerExternalId: _optional(latest.uuid),
        sourceVersion: 'health-read-v1',
        evidenceTimestampUtc: observedAt,
      );
    } catch (error, stackTrace) {
      AppLogger.warning('Recovery health read failed for $kind: $error');
      CrashReportingService.recordCrash(
        error,
        stackTrace,
        reason: 'recovery health read error',
      );
      return HealthRecoveryMetricRead(
        kind: kind,
        status: HealthRecoveryMetricStatus.unknown,
        permission: HealthRecoveryMetricPermission.unavailable,
        freshness: HealthRecoveryMetricFreshness.unknown,
        value: null,
        unit: unit,
        observedAtUtc: null,
        source: source,
        provenance: '$source:error',
        providerExternalId: null,
        sourceVersion: 'health-read-v1',
        evidenceTimestampUtc: null,
      );
    }
  }

  static String? _optional(String value) =>
      value.trim().isEmpty ? null : value.trim();

  /// Import outdoor activities with provenance tracking and duplicate prevention
  Future<List<Map<String, dynamic>>> importOutdoorActivities([
    AppDatabase? db,
  ]) async {
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
      final importer = db == null ? null : HealthActivityImportRepository(db);

      for (final p in data) {
        // Never import a workout this app wrote to Health. This is provenance
        // filtering, not modality inference.
        if (_isIndiFitOrigin(p.sourceName)) continue;

        final input = B02HealthActivityInput.fromHealthDataPoint(p);
        final translation = HealthActivityImportRepository.translateInput(
          input,
        );
        if (translation.status != B02HealthImportStatus.imported) {
          final fingerprint =
              input.fingerprint ??
              '${input.provider}|${input.providerType}|${input.startedAtUtc.toIso8601String()}|${input.endedAtUtc.toIso8601String()}';
          activities.add({
            'status': translation.status.name,
            'imported': false,
            'activityType': translation.activityType?.dbValue,
            'title': input.displayName ?? 'Imported activity',
            'durationMinutes': input.endedAtUtc
                .difference(input.startedAtUtc)
                .inMinutes,
            'calories': input.estimatedCalories ?? 0,
            'date': input.startedAtUtc,
            'fingerprint': fingerprint,
            'externalId': input.externalId,
            'provider': input.provider,
            'providerType': input.providerType,
            'sourceName': input.sourceName,
            'localSessionId': null,
            'reason': translation.reason,
          });
          continue;
        }

        if (importer == null) {
          final fingerprint =
              input.fingerprint ??
              '${input.provider}|${input.providerType}|${input.startedAtUtc.toIso8601String()}|${input.endedAtUtc.toIso8601String()}';
          activities.add({
            'status': B02HealthImportStatus.imported.name,
            'imported': false,
            'activityType': translation.activityType!.dbValue,
            'title': input.displayName ?? 'Imported activity',
            'durationMinutes': input.endedAtUtc
                .difference(input.startedAtUtc)
                .inMinutes,
            'calories': input.estimatedCalories ?? 0,
            'date': input.startedAtUtc,
            'fingerprint': fingerprint,
            'externalId': input.externalId,
            'provider': input.provider,
            'providerType': input.providerType,
            'sourceName': input.sourceName,
            'localSessionId': null,
            'reason': 'Typed activity translated but not persisted.',
          });
          continue;
        }

        final result = await importer.importActivity(input);
        if (result.status == B02HealthImportStatus.duplicate) continue;
        activities.add(result.toDisplayMap(input));
      }

      return activities;
    } catch (e, st) {
      AppLogger.warning('importOutdoorActivities failed: $e');
      CrashReportingService.recordCrash(
        e,
        st,
        reason: 'importOutdoorActivities error',
      );
      rethrow;
    }
  }

  static bool _isIndiFitOrigin(String sourceName) =>
      sourceName.trim().toLowerCase().contains('indifit');

  /// Persists an external activity and its provenance atomically. Returns the
  /// new local session ID, or null when the native activity was already seen.
  Future<int?> persistOutdoorActivity({
    required AppDatabase db,
    required String provider,
    required String? externalId,
    required String sourceName,
    required String fingerprint,
    required String title,
    required int durationMinutes,
    required int calories,
    required DateTime completedAt,
  }) async {
    return db.transaction(() async {
      final existing =
          await (db.select(db.healthProvenances)..where(
                (tbl) => externalId == null
                    ? tbl.fingerprint.equals(fingerprint)
                    : tbl.externalId.equals(externalId) |
                          tbl.fingerprint.equals(fingerprint),
              ))
              .getSingleOrNull();
      if (existing != null) return null;

      final sessionId = await db
          .into(db.workoutSessions)
          .insert(
            WorkoutSessionsCompanion.insert(
              name: title,
              totalVolume: 0.0,
              durationSeconds: durationMinutes * 60,
              estimatedCalories: calories,
              completedAt: Value(completedAt),
              isSynced: const Value(true),
              uuid: Value(externalId ?? fingerprint),
            ),
          );
      await db
          .into(db.healthProvenances)
          .insert(
            HealthProvenancesCompanion.insert(
              provider: provider,
              externalId: Value(externalId),
              sourceName: sourceName.isEmpty ? provider : sourceName,
              localSessionId: Value(sessionId),
              fingerprint: fingerprint,
            ),
          );
      return sessionId;
    });
  }

  /// Write logged workout session to HealthKit / Health Connect with origin tag
  Future<bool> writeWorkoutSession({
    required String title,
    required int durationMinutes,
    required int caloriesBurned,
    required DateTime startTime,
  }) async {
    return writeActivitySession(
      activityType: B02ActivityType.strength,
      title: title,
      durationMinutes: durationMinutes,
      caloriesBurned: caloriesBurned,
      startTime: startTime,
    );
  }

  /// Write a typed B02 activity using the reviewed native mapping. Unsupported
  /// yoga/mobility export mappings return false without relabelling the record.
  Future<bool> writeActivitySession({
    required B02ActivityType activityType,
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

      final platform = _health.platformType;
      return await HealthActivityExportRepository(_health).writeActivity(
        activityType: activityType,
        title: '$title (IndiFit)',
        durationSeconds: durationMinutes * 60,
        caloriesBurned: caloriesBurned,
        startTime: startTime,
        platform: platform,
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
