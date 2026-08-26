import 'dart:io' as io;

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
  restingHeartRate,
  workoutImport,
  workoutExport,
  weightExport,
}

enum HealthPlatformAvailability {
  unknown,
  supported,
  unsupported,
  unavailable,
  error,
}

enum HealthConnectionStatus {
  unknown,
  notConnected,
  connected,
  partial,
  denied,
  unavailable,
}

enum HealthPermissionStatus {
  disabled,
  notRequested,
  granted,
  denied,
  unknown,
  unavailable,
}

/// Each surfaced category maps directly to an existing Health read/write.
/// Workout export remains an existing B02 helper, but has no current consumer
/// caller and is therefore not requested or shown as a release capability.
class HealthCategoryDescriptor {
  final HealthCategory category;
  final String title;
  final String description;
  final HealthDataType type;
  final HealthDataAccess access;
  final bool surfaced;

  const HealthCategoryDescriptor({
    required this.category,
    required this.title,
    required this.description,
    required this.type,
    required this.access,
    this.surfaced = true,
  });
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
  final HealthPlatformAvailability availability;
  final HealthConnectionStatus connectionStatus;
  final Map<HealthCategory, HealthPermissionStatus> permissionStates;
  final Set<HealthCategory> categoriesWithData;
  final bool integrationEnabled;
  final String? platformName;

  const HealthDataSummary({
    this.steps = 0,
    this.activeCalories = 0.0,
    this.sleepHours = 0.0,
    this.isConnected = false,
    this.isError = false,
    this.statusMessage,
    this.categoryStates = const {},
    this.skippedDuplicatesCount = 0,
    this.availability = HealthPlatformAvailability.unknown,
    this.connectionStatus = HealthConnectionStatus.unknown,
    this.permissionStates = const {},
    this.categoriesWithData = const {},
    this.integrationEnabled = false,
    this.platformName,
  });

  HealthDataSummary copyWith({
    int? steps,
    double? activeCalories,
    double? sleepHours,
    bool? isConnected,
    bool? isError,
    String? statusMessage,
    Map<HealthCategory, bool>? categoryStates,
    int? skippedDuplicatesCount,
    HealthPlatformAvailability? availability,
    HealthConnectionStatus? connectionStatus,
    Map<HealthCategory, HealthPermissionStatus>? permissionStates,
    Set<HealthCategory>? categoriesWithData,
    bool? integrationEnabled,
    String? platformName,
  }) {
    return HealthDataSummary(
      steps: steps ?? this.steps,
      activeCalories: activeCalories ?? this.activeCalories,
      sleepHours: sleepHours ?? this.sleepHours,
      isConnected: isConnected ?? this.isConnected,
      isError: isError ?? this.isError,
      statusMessage: statusMessage ?? this.statusMessage,
      categoryStates: categoryStates ?? this.categoryStates,
      skippedDuplicatesCount:
          skippedDuplicatesCount ?? this.skippedDuplicatesCount,
      availability: availability ?? this.availability,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      permissionStates: permissionStates ?? this.permissionStates,
      categoriesWithData: categoriesWithData ?? this.categoriesWithData,
      integrationEnabled: integrationEnabled ?? this.integrationEnabled,
      platformName: platformName ?? this.platformName,
    );
  }

  /// Compatibility for older fixtures that only supplied [isConnected].
  HealthConnectionStatus get resolvedConnectionStatus =>
      connectionStatus != HealthConnectionStatus.unknown
      ? connectionStatus
      : availability == HealthPlatformAvailability.unknown &&
            permissionStates.isEmpty &&
            !integrationEnabled
      ? (isConnected
            ? HealthConnectionStatus.connected
            : HealthConnectionStatus.notConnected)
      : HealthConnectionStatus.unknown;

  HealthPermissionStatus permissionFor(HealthCategory category) {
    final explicit = permissionStates[category];
    if (explicit != null) return explicit;
    if (categoryStates[category] == false) {
      return HealthPermissionStatus.disabled;
    }
    return switch (resolvedConnectionStatus) {
      HealthConnectionStatus.connected => HealthPermissionStatus.granted,
      HealthConnectionStatus.denied => HealthPermissionStatus.denied,
      HealthConnectionStatus.unknown => HealthPermissionStatus.unknown,
      HealthConnectionStatus.unavailable => HealthPermissionStatus.unavailable,
      HealthConnectionStatus.notConnected ||
      HealthConnectionStatus.partial => HealthPermissionStatus.notRequested,
    };
  }

  /// Whether the provider returned a value for this category. The numeric
  /// value may legitimately be zero, so value presence is tracked separately.
  bool hasDataFor(HealthCategory category) {
    if (categoriesWithData.contains(category)) return true;
    // Compatibility for older fixtures and callers created before explicit
    // presence tracking was added.
    return switch (category) {
      HealthCategory.steps => steps != 0,
      HealthCategory.activeEnergy => activeCalories != 0,
      HealthCategory.sleep => sleepHours != 0,
      _ => false,
    };
  }

  bool get hasDailyMetricData =>
      hasDataFor(HealthCategory.steps) ||
      hasDataFor(HealthCategory.activeEnergy) ||
      hasDataFor(HealthCategory.sleep);
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
  HealthConnectionStatus _lastPermissionRequestStatus =
      HealthConnectionStatus.unknown;

  HealthService([Health? health]) : _health = health ?? Health();

  static const String integrationEnabledPrefKey = 'health_integration_enabled';
  static const String permissionRequestedPrefix =
      'health_permission_requested_';

  static const Map<HealthCategory, String> categoryPrefKeys = {
    HealthCategory.steps: 'health_category_steps',
    HealthCategory.activeEnergy: 'health_category_active_energy',
    HealthCategory.sleep: 'health_category_sleep',
    HealthCategory.restingHeartRate: 'health_category_resting_heart_rate',
    HealthCategory.workoutImport: 'health_category_workout_import',
    HealthCategory.workoutExport: 'health_category_workout_export',
    HealthCategory.weightExport: 'health_category_weight_export',
  };

  static const List<HealthCategoryDescriptor> categoryDescriptors = [
    HealthCategoryDescriptor(
      category: HealthCategory.steps,
      title: 'Steps',
      description: 'Allow IndiFit to view daily step counts.',
      type: HealthDataType.STEPS,
      access: HealthDataAccess.READ,
    ),
    HealthCategoryDescriptor(
      category: HealthCategory.activeEnergy,
      title: 'Active energy',
      description: 'Allow IndiFit to view active energy records.',
      type: HealthDataType.ACTIVE_ENERGY_BURNED,
      access: HealthDataAccess.READ,
    ),
    HealthCategoryDescriptor(
      category: HealthCategory.sleep,
      title: 'Sleep',
      description: 'Allow IndiFit to view sleep sessions.',
      type: HealthDataType.SLEEP_SESSION,
      access: HealthDataAccess.READ,
    ),
    HealthCategoryDescriptor(
      category: HealthCategory.restingHeartRate,
      title: 'Resting heart rate',
      description: 'Allow IndiFit to view resting heart rate records.',
      type: HealthDataType.RESTING_HEART_RATE,
      access: HealthDataAccess.READ,
    ),
    HealthCategoryDescriptor(
      category: HealthCategory.workoutImport,
      title: 'Walking, running, and cycling',
      description:
          'Allow IndiFit to import supported walking, running, and cycling activities.',
      type: HealthDataType.WORKOUT,
      access: HealthDataAccess.READ,
    ),
    HealthCategoryDescriptor(
      category: HealthCategory.weightExport,
      title: 'Body weight',
      description: 'Add weight logs saved in IndiFit to your health app.',
      type: HealthDataType.WEIGHT,
      access: HealthDataAccess.WRITE,
    ),
    HealthCategoryDescriptor(
      category: HealthCategory.workoutExport,
      title: 'Workout Export (Write)',
      description: 'Reserved for an existing helper with no current caller.',
      type: HealthDataType.WORKOUT,
      access: HealthDataAccess.WRITE,
      surfaced: false,
    ),
  ];

  static Iterable<HealthCategoryDescriptor> get visibleCategoryDescriptors =>
      categoryDescriptors.where((descriptor) => descriptor.surfaced);

  static HealthCategoryDescriptor descriptorFor(HealthCategory category) =>
      categoryDescriptors.firstWhere(
        (descriptor) => descriptor.category == category,
      );

  HealthConnectionStatus get lastPermissionRequestStatus =>
      _lastPermissionRequestStatus;

  String get platformDisplayName {
    if (io.Platform.isIOS) return 'Apple Health';
    if (io.Platform.isAndroid) return 'Health Connect';
    return 'Health data';
  }

  Future<bool> getIntegrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(integrationEnabledPrefKey) ?? false;
  }

  Future<void> setIntegrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(integrationEnabledPrefKey, enabled);
  }

  /// Checks support without configuring Health or requesting a permission.
  Future<HealthPlatformAvailability> getPlatformAvailability() async {
    if (!io.Platform.isIOS && !io.Platform.isAndroid) {
      return HealthPlatformAvailability.unsupported;
    }
    if (io.Platform.isIOS) return HealthPlatformAvailability.supported;
    try {
      final available = await _health.isHealthConnectAvailable();
      return available
          ? HealthPlatformAvailability.supported
          : HealthPlatformAvailability.unavailable;
    } catch (error, stackTrace) {
      AppLogger.warning('Health platform availability check failed: $error');
      CrashReportingService.recordCrash(
        error,
        stackTrace,
        reason: 'health platform availability error',
      );
      return HealthPlatformAvailability.error;
    }
  }

  /// Stops future integration and never removes canonical local history.
  Future<void> disconnect() async {
    await setIntegrationEnabled(false);
    _lastPermissionRequestStatus = HealthConnectionStatus.notConnected;
    if (!io.Platform.isAndroid) return;
    try {
      await _health.revokePermissions();
    } catch (error, stackTrace) {
      AppLogger.warning('Health permission revocation failed: $error');
      CrashReportingService.recordCrash(
        error,
        stackTrace,
        reason: 'health permission revocation error',
      );
    }
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

  static String _permissionAttemptedKey(HealthCategory category) =>
      '$permissionRequestedPrefix${category.name}';

  Future<bool> _permissionWasRequested(HealthCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionAttemptedKey(category)) ?? false;
  }

  Future<void> _markPermissionRequested(HealthCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionAttemptedKey(category), true);
  }

  Future<HealthPermissionStatus> _permissionStatusFor(
    HealthCategory category, {
    required bool configured,
  }) async {
    final descriptor = descriptorFor(category);
    if (!descriptor.surfaced) return HealthPermissionStatus.unavailable;
    if (!(await getCategoryState(category))) {
      return HealthPermissionStatus.disabled;
    }
    if (!_health.isDataTypeAvailable(descriptor.type)) {
      return HealthPermissionStatus.unavailable;
    }
    if (!configured) await _health.configure();
    try {
      final hasPermissions = await _health.hasPermissions(
        [descriptor.type],
        permissions: [descriptor.access],
      );
      return switch (hasPermissions) {
        true => HealthPermissionStatus.granted,
        false =>
          await _permissionWasRequested(category)
              ? HealthPermissionStatus.denied
              : HealthPermissionStatus.notRequested,
        null => HealthPermissionStatus.unknown,
      };
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Health permission status failed for ${category.name}: $error',
      );
      CrashReportingService.recordCrash(
        error,
        stackTrace,
        reason: 'health permission status error',
      );
      return HealthPermissionStatus.unavailable;
    }
  }

  Future<Map<HealthCategory, HealthPermissionStatus>> _readPermissionStates({
    required Map<HealthCategory, bool> categoryStates,
    required bool configured,
  }) async {
    final result = <HealthCategory, HealthPermissionStatus>{};
    for (final descriptor in visibleCategoryDescriptors) {
      if (categoryStates[descriptor.category] != true) {
        result[descriptor.category] = HealthPermissionStatus.disabled;
      } else {
        result[descriptor.category] = await _permissionStatusFor(
          descriptor.category,
          configured: configured,
        );
      }
    }
    return result;
  }

  static HealthConnectionStatus _connectionStatusFor(
    HealthPlatformAvailability availability,
    bool integrationEnabled,
    Map<HealthCategory, HealthPermissionStatus> permissionStates,
  ) {
    if (availability == HealthPlatformAvailability.unsupported ||
        availability == HealthPlatformAvailability.unavailable ||
        availability == HealthPlatformAvailability.error) {
      return HealthConnectionStatus.unavailable;
    }
    if (!integrationEnabled) return HealthConnectionStatus.notConnected;
    final active = permissionStates.values
        .where((status) => status != HealthPermissionStatus.disabled)
        .toList();
    if (active.isEmpty) return HealthConnectionStatus.notConnected;

    final granted = active
        .where((status) => status == HealthPermissionStatus.granted)
        .length;
    final unknown = active
        .where((status) => status == HealthPermissionStatus.unknown)
        .length;
    final unavailable = active
        .where((status) => status == HealthPermissionStatus.unavailable)
        .length;
    final denied = active
        .where((status) => status == HealthPermissionStatus.denied)
        .length;
    final notRequested = active
        .where((status) => status == HealthPermissionStatus.notRequested)
        .length;

    if (granted == active.length) return HealthConnectionStatus.connected;
    if (granted > 0) return HealthConnectionStatus.partial;
    if (notRequested == active.length) {
      return HealthConnectionStatus.notConnected;
    }
    if (unknown == active.length) return HealthConnectionStatus.unknown;
    if (unavailable == active.length) return HealthConnectionStatus.unavailable;
    if (denied == active.length) return HealthConnectionStatus.denied;
    if (unknown > 0) return HealthConnectionStatus.unknown;
    return HealthConnectionStatus.denied;
  }

  Future<bool> _requestCategoryPermissions(
    HealthCategory category, {
    required bool configured,
  }) async {
    final descriptor = descriptorFor(category);
    if (!descriptor.surfaced || !_health.isDataTypeAvailable(descriptor.type)) {
      return false;
    }
    if (!configured) await _health.configure();
    final current = await _permissionStatusFor(category, configured: true);
    if (current == HealthPermissionStatus.granted) return true;
    if (current == HealthPermissionStatus.unavailable) return false;

    await _markPermissionRequested(category);
    final requested = await _health.requestAuthorization(
      [descriptor.type],
      permissions: [descriptor.access],
    );
    if (!requested) return false;
    final afterRequest = await _permissionStatusFor(category, configured: true);
    // HealthKit may intentionally return an opaque read status after a
    // successful request. Keep it unknown rather than claiming full access.
    return afterRequest == HealthPermissionStatus.granted ||
        afterRequest == HealthPermissionStatus.unknown;
  }

  /// Permission prompts are reachable only from an explicit user action.
  Future<bool> requestCategoryPermissions(HealthCategory category) async {
    final availability = await getPlatformAvailability();
    if (availability != HealthPlatformAvailability.supported) return false;
    return _requestCategoryPermissions(category, configured: false);
  }

  /// Requests only enabled, surfaced categories. Partial access remains
  /// truthful and usable for the categories the OS reports as available.
  Future<bool> requestPermissions() async {
    _lastPermissionRequestStatus = HealthConnectionStatus.unknown;
    final availability = await getPlatformAvailability();
    if (availability != HealthPlatformAvailability.supported) {
      _lastPermissionRequestStatus = HealthConnectionStatus.unavailable;
      await setIntegrationEnabled(false);
      return false;
    }

    final states = await getAllCategoryStates();
    final enabled = visibleCategoryDescriptors
        .where((descriptor) => states[descriptor.category] == true)
        .toList();
    if (enabled.isEmpty) {
      _lastPermissionRequestStatus = HealthConnectionStatus.notConnected;
      await setIntegrationEnabled(false);
      return false;
    }

    await _health.configure();
    final requestResults = <HealthCategory, bool>{};
    for (final descriptor in enabled) {
      final current = await _permissionStatusFor(
        descriptor.category,
        configured: true,
      );
      final shouldRequest = current != HealthPermissionStatus.granted;
      if (shouldRequest) {
        requestResults[descriptor.category] = await _requestCategoryPermissions(
          descriptor.category,
          configured: true,
        );
      }
    }

    final permissionStates = await _readPermissionStates(
      categoryStates: states,
      configured: true,
    );
    // A false native request is authoritative even on platforms whose later
    // read check is privacy-opaque.
    for (final entry in requestResults.entries) {
      if (!entry.value &&
          permissionStates[entry.key] == HealthPermissionStatus.unknown) {
        permissionStates[entry.key] = HealthPermissionStatus.denied;
      }
    }
    final connectionStatus = _connectionStatusFor(
      availability,
      true,
      permissionStates,
    );
    _lastPermissionRequestStatus = connectionStatus;
    final usable =
        connectionStatus == HealthConnectionStatus.connected ||
        connectionStatus == HealthConnectionStatus.partial ||
        connectionStatus == HealthConnectionStatus.unknown;
    await setIntegrationEnabled(usable);
    return usable;
  }

  static bool _canRead(HealthPermissionStatus status) =>
      status == HealthPermissionStatus.granted ||
      status == HealthPermissionStatus.unknown;

  static String? _connectionMessage(
    HealthConnectionStatus status, {
    String? platformName,
  }) {
    final sourceName = platformName ?? 'Health data source';
    return switch (status) {
      HealthConnectionStatus.unknown =>
        '$sourceName did not confirm read access. IndiFit only uses data the system returns.',
      HealthConnectionStatus.denied =>
        'No selected Health permissions are available.',
      HealthConnectionStatus.partial =>
        'Some selected Health categories are available.',
      HealthConnectionStatus.notConnected => null,
      HealthConnectionStatus.connected => null,
      HealthConnectionStatus.unavailable =>
        'Health data is unavailable on this device.',
    };
  }

  /// A write is attempted only after an explicit connection and without
  /// reopening a native permission sheet from a logging action.
  Future<bool> _canUseWritePermission(HealthCategory category) async {
    if (!(await getIntegrationEnabled())) return false;
    if (!(await getCategoryState(category))) return false;
    if (await getPlatformAvailability() !=
        HealthPlatformAvailability.supported) {
      return false;
    }
    final descriptor = descriptorFor(category);
    if (!_health.isDataTypeAvailable(descriptor.type)) return false;
    await _health.configure();
    final status = await _permissionStatusFor(category, configured: true);
    // Unlike an opaque iOS read check, a write must be confirmed before a
    // logging action is allowed to touch the external source.
    return status == HealthPermissionStatus.granted;
  }

  /// Fetch today's metrics without opening a permission prompt. The explicit
  /// connection gate prevents a Settings render or dashboard refresh from
  /// silently starting Health integration.
  Future<HealthDataSummary> fetchTodayHealthData() async {
    final categoryStates = await getAllCategoryStates();
    final availability = await getPlatformAvailability();
    if (availability == HealthPlatformAvailability.error) {
      return HealthDataSummary(
        categoryStates: categoryStates,
        availability: availability,
        connectionStatus: HealthConnectionStatus.unavailable,
        platformName: platformDisplayName,
        statusMessage: 'Health data availability could not be checked.',
        isError: true,
      );
    }
    if (availability != HealthPlatformAvailability.supported) {
      return HealthDataSummary(
        categoryStates: categoryStates,
        availability: availability,
        connectionStatus: HealthConnectionStatus.unavailable,
        platformName: platformDisplayName,
        statusMessage: availability == HealthPlatformAvailability.unsupported
            ? 'Health integration is not supported on this platform.'
            : 'Health data is unavailable on this device.',
      );
    }

    try {
      final integrationEnabled = await getIntegrationEnabled();
      if (!integrationEnabled) {
        return HealthDataSummary(
          categoryStates: categoryStates,
          availability: availability,
          connectionStatus: HealthConnectionStatus.notConnected,
          platformName: platformDisplayName,
          permissionStates: {
            for (final descriptor in visibleCategoryDescriptors)
              descriptor.category: categoryStates[descriptor.category] == true
                  ? HealthPermissionStatus.notRequested
                  : HealthPermissionStatus.disabled,
          },
        );
      }

      await _health.configure();
      final permissions = await _readPermissionStates(
        categoryStates: categoryStates,
        configured: true,
      );
      final connectionStatus = _connectionStatusFor(
        availability,
        integrationEnabled,
        permissions,
      );
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      int steps = 0;
      double activeCals = 0.0;
      double sleepMinutes = 0.0;
      final categoriesWithData = <HealthCategory>{};

      if (_canRead(
        permissions[HealthCategory.steps] ?? HealthPermissionStatus.unavailable,
      )) {
        final total = await _health.getTotalStepsInInterval(midnight, now);
        if (total != null) {
          steps = total;
          categoriesWithData.add(HealthCategory.steps);
        }
      }
      if (_canRead(
        permissions[HealthCategory.activeEnergy] ??
            HealthPermissionStatus.unavailable,
      )) {
        final data = await _health.getHealthDataFromTypes(
          startTime: midnight,
          endTime: now,
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        );
        for (final point in data) {
          final value = point.value;
          if (value is NumericHealthValue) {
            activeCals += value.numericValue.toDouble();
            categoriesWithData.add(HealthCategory.activeEnergy);
          }
        }
      }
      if (_canRead(
        permissions[HealthCategory.sleep] ?? HealthPermissionStatus.unavailable,
      )) {
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
          categoriesWithData.add(HealthCategory.sleep);
        }
      }

      if (permissions.values.any(_canRead)) await setLastSyncTime(now);
      return HealthDataSummary(
        steps: steps,
        activeCalories: activeCals,
        sleepHours: sleepMinutes / 60.0,
        isConnected: connectionStatus == HealthConnectionStatus.connected,
        availability: availability,
        connectionStatus: connectionStatus,
        permissionStates: permissions,
        categoriesWithData: categoriesWithData,
        integrationEnabled: integrationEnabled,
        platformName: platformDisplayName,
        categoryStates: categoryStates,
        statusMessage: _connectionMessage(
          connectionStatus,
          platformName: platformDisplayName,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.warning('Health data read failed: $error');
      CrashReportingService.recordCrash(
        error,
        stackTrace,
        reason: 'health data read error',
      );
      return HealthDataSummary(
        isConnected: false,
        isError: true,
        availability: availability,
        connectionStatus: HealthConnectionStatus.unavailable,
        platformName: platformDisplayName,
        categoryStates: categoryStates,
        statusMessage: 'Health data could not be read right now.',
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
        category: HealthCategory.restingHeartRate,
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
    required HealthCategory category,
    required double? Function(List<HealthDataPoint>) aggregate,
  }) async {
    final source = 'health:${type.name.toLowerCase()}';
    final disabled = !(await getCategoryState(category));
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
      final availability = await getPlatformAvailability();
      if (availability != HealthPlatformAvailability.supported ||
          !(await getIntegrationEnabled())) {
        return HealthRecoveryMetricRead(
          kind: kind,
          status: HealthRecoveryMetricStatus.missing,
          permission: HealthRecoveryMetricPermission.unavailable,
          freshness: HealthRecoveryMetricFreshness.unknown,
          value: null,
          unit: unit,
          observedAtUtc: null,
          source: source,
          provenance: '$source:unavailable',
          providerExternalId: null,
          sourceVersion: 'health-read-v1',
          evidenceTimestampUtc: null,
        );
      }
      await _health.configure();
      final permissionStatus = await _permissionStatusFor(
        category,
        configured: true,
      );
      if (!_canRead(permissionStatus)) {
        return HealthRecoveryMetricRead(
          kind: kind,
          status: HealthRecoveryMetricStatus.missing,
          permission: permissionStatus == HealthPermissionStatus.denied
              ? HealthRecoveryMetricPermission.denied
              : HealthRecoveryMetricPermission.unavailable,
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
          permission: permissionStatus == HealthPermissionStatus.unknown
              ? HealthRecoveryMetricPermission.unknown
              : HealthRecoveryMetricPermission.granted,
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
          permission: permissionStatus == HealthPermissionStatus.unknown
              ? HealthRecoveryMetricPermission.unknown
              : HealthRecoveryMetricPermission.granted,
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
        permission: permissionStatus == HealthPermissionStatus.unknown
            ? HealthRecoveryMetricPermission.unknown
            : HealthRecoveryMetricPermission.granted,
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

      final availability = await getPlatformAvailability();
      if (availability != HealthPlatformAvailability.supported ||
          !(await getIntegrationEnabled())) {
        return [];
      }
      await _health.configure();
      final permissionStatus = await _permissionStatusFor(
        HealthCategory.workoutImport,
        configured: true,
      );
      if (!_canRead(permissionStatus)) return [];

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

      // This helper is not currently wired to a consumer action and is not
      // requested by the release permission surface. A future caller must
      // opt in before any write; saving a workout must never open a prompt.
      if (!await _canUseWritePermission(HealthCategory.workoutExport)) {
        return false;
      }

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

      if (!await _canUseWritePermission(HealthCategory.weightExport)) {
        return false;
      }

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
