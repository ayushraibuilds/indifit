import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:health/health.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import 'b02_activity_session_repository.dart';

enum B02HealthImportStatus { imported, duplicate, unsupported, invalid }

/// Raw, provider-labelled workout data. The provider type is kept separate
/// from the IndiFit activity type so unsupported values remain visible and
/// cannot be silently classified.
class B02HealthActivityInput {
  final String provider;
  final String providerType;
  final String sourceName;
  final String? externalId;
  final String? fingerprint;
  final DateTime startedAtUtc;
  final DateTime endedAtUtc;
  final String? displayName;
  final int? distanceMetres;
  final double? observedPaceSecondsPerKm;
  final double? observedSpeedKph;
  final double? inclinePercentage;
  final double? elevationMetres;
  final int? averageHeartRate;
  final int? perceivedExertion;
  final int? estimatedCalories;
  final bool isIntervalWorkout;
  final List<B02CardioInterval> intervals;

  const B02HealthActivityInput({
    required this.provider,
    required this.providerType,
    required this.sourceName,
    required this.externalId,
    required this.fingerprint,
    required this.startedAtUtc,
    required this.endedAtUtc,
    this.displayName,
    this.distanceMetres,
    this.observedPaceSecondsPerKm,
    this.observedSpeedKph,
    this.inclinePercentage,
    this.elevationMetres,
    this.averageHeartRate,
    this.perceivedExertion,
    this.estimatedCalories,
    this.isIntervalWorkout = false,
    this.intervals = const [],
  });

  factory B02HealthActivityInput.fromHealthDataPoint(HealthDataPoint point) {
    final provider = B02HealthProviderTypeMapping.providerCode(
      point.sourcePlatform,
    );
    final value = point.value;
    final providerType = value is WorkoutHealthValue
        ? B02HealthProviderTypeMapping.providerTypeFor(
                point.sourcePlatform,
                value.workoutActivityType,
              ) ??
              value.workoutActivityType.name
        : point.typeString;
    final workout = value is WorkoutHealthValue ? value : null;
    final distance = workout?.totalDistance;
    final durationSeconds = point.dateTo.difference(point.dateFrom).inSeconds;
    final pace = distance != null && distance > 0 && durationSeconds > 0
        ? durationSeconds / (distance / 1000)
        : null;
    return B02HealthActivityInput(
      provider: provider,
      providerType: providerType,
      sourceName: point.sourceName,
      externalId: point.uuid.trim().isEmpty ? null : point.uuid,
      fingerprint: null,
      startedAtUtc: point.dateFrom.toUtc(),
      endedAtUtc: point.dateTo.toUtc(),
      displayName: null,
      distanceMetres: distance,
      observedPaceSecondsPerKm: pace,
      estimatedCalories: workout?.totalEnergyBurned,
    );
  }
}

class B02HealthImportTranslation {
  final B02HealthImportStatus status;
  final B02ActivityType? activityType;
  final B02HealthActivityInput input;
  final String reason;

  const B02HealthImportTranslation({
    required this.status,
    required this.activityType,
    required this.input,
    required this.reason,
  });

  bool get isSupported => activityType != null;
}

/// The only provider mapping used by B02-09. These are the reviewed fixture
/// keys; display names, source names and arbitrary provider strings are never
/// consulted for modality classification.
class B02HealthProviderTypeMapping {
  static const Map<String, B02ActivityType> reviewedProviderTypes = {
    'health_connect|EXERCISE_SESSION_TYPE_BIKING': B02ActivityType.cycling,
    'health_connect|EXERCISE_SESSION_TYPE_RUNNING': B02ActivityType.running,
    'health_connect|EXERCISE_SESSION_TYPE_WALKING': B02ActivityType.walking,
    'health_kit|HKWorkoutActivityTypeCycling': B02ActivityType.cycling,
    'health_kit|HKWorkoutActivityTypeRunning': B02ActivityType.running,
    'health_kit|HKWorkoutActivityTypeWalking': B02ActivityType.walking,
  };

  static String providerCode(HealthPlatformType platform) => switch (platform) {
    HealthPlatformType.googleHealthConnect => 'health_connect',
    HealthPlatformType.appleHealth => 'health_kit',
  };

  static B02ActivityType? mapProviderType(
    String provider,
    String providerType,
  ) => reviewedProviderTypes['$provider|$providerType'];

  static String? providerTypeFor(
    HealthPlatformType platform,
    HealthWorkoutActivityType activityType,
  ) {
    final provider = providerCode(platform);
    final providerType = switch (activityType) {
      HealthWorkoutActivityType.BIKING =>
        provider == 'health_connect'
            ? 'EXERCISE_SESSION_TYPE_BIKING'
            : 'HKWorkoutActivityTypeCycling',
      HealthWorkoutActivityType.RUNNING =>
        provider == 'health_connect'
            ? 'EXERCISE_SESSION_TYPE_RUNNING'
            : 'HKWorkoutActivityTypeRunning',
      HealthWorkoutActivityType.WALKING =>
        provider == 'health_connect'
            ? 'EXERCISE_SESSION_TYPE_WALKING'
            : 'HKWorkoutActivityTypeWalking',
      _ => null,
    };
    return providerType;
  }
}

class B02HealthImportResult {
  final B02HealthImportStatus status;
  final int? localSessionId;
  final B02ActivityType? activityType;
  final String provider;
  final String providerType;
  final String? externalId;
  final String fingerprint;
  final String reason;

  const B02HealthImportResult({
    required this.status,
    required this.localSessionId,
    required this.activityType,
    required this.provider,
    required this.providerType,
    required this.externalId,
    required this.fingerprint,
    required this.reason,
  });

  bool get imported => status == B02HealthImportStatus.imported;

  Map<String, dynamic> toDisplayMap(B02HealthActivityInput input) => {
    'status': status.name,
    'imported': imported,
    'activityType': activityType?.dbValue,
    'title': input.displayName ?? 'Imported activity',
    'durationMinutes': input.endedAtUtc
        .difference(input.startedAtUtc)
        .inMinutes,
    'calories': input.estimatedCalories ?? 0,
    'date': input.startedAtUtc,
    'externalId': externalId,
    'fingerprint': fingerprint,
    'provider': provider,
    'providerType': providerType,
    'sourceName': input.sourceName,
    'localSessionId': localSessionId,
    'reason': reason,
  };
}

/// Translates exact Health provider records and persists them through the
/// canonical activity owner. Unknown provider types produce a visible result
/// but never create a local activity.
class HealthActivityImportRepository {
  final AppDatabase _db;
  final ActivitySessionRepository _activities;
  final Uuid _uuid;

  HealthActivityImportRepository(
    this._db, [
    ActivitySessionRepository? activities,
    Uuid? uuid,
  ]) : _activities = activities ?? ActivitySessionRepository(_db),
       _uuid = uuid ?? const Uuid();

  B02HealthImportTranslation translate(B02HealthActivityInput input) {
    return translateInput(input);
  }

  static B02HealthImportTranslation translateInput(
    B02HealthActivityInput input,
  ) {
    final activityType = B02HealthProviderTypeMapping.mapProviderType(
      input.provider,
      input.providerType,
    );
    if (activityType == null) {
      return B02HealthImportTranslation(
        status: B02HealthImportStatus.unsupported,
        activityType: null,
        input: input,
        reason: 'Provider activity type is not in the reviewed B02 mapping.',
      );
    }
    final durationSeconds = input.endedAtUtc
        .difference(input.startedAtUtc)
        .inSeconds;
    if (durationSeconds < 1) {
      return B02HealthImportTranslation(
        status: B02HealthImportStatus.invalid,
        activityType: activityType,
        input: input,
        reason: 'Imported activity duration must be positive.',
      );
    }
    try {
      B02CardioSessionDetail(
        activityType: activityType,
        durationSeconds: durationSeconds,
        distanceMetres: input.distanceMetres,
        observedPaceSecondsPerKm: input.observedPaceSecondsPerKm,
        observedSpeedKph: input.observedSpeedKph,
        inclinePercentage: input.inclinePercentage,
        elevationMetres: input.elevationMetres,
        averageHeartRate: input.averageHeartRate,
        perceivedExertion: input.perceivedExertion,
        isIntervalWorkout: input.isIntervalWorkout,
        inputMode: B02InputMode.healthImport,
        intervals: input.intervals,
      );
    } on B02ValidationException catch (error) {
      return B02HealthImportTranslation(
        status: B02HealthImportStatus.invalid,
        activityType: activityType,
        input: input,
        reason: error.message,
      );
    }
    return B02HealthImportTranslation(
      status: B02HealthImportStatus.imported,
      activityType: activityType,
      input: input,
      reason: 'Provider activity is mapped by the reviewed B02 contract.',
    );
  }

  Future<B02HealthImportResult> importActivity(
    B02HealthActivityInput input,
  ) async {
    final translation = translate(input);
    final fingerprint = _fingerprint(input);
    if (translation.status != B02HealthImportStatus.imported) {
      return B02HealthImportResult(
        status: translation.status,
        localSessionId: null,
        activityType: translation.activityType,
        provider: input.provider,
        providerType: input.providerType,
        externalId: input.externalId,
        fingerprint: fingerprint,
        reason: translation.reason,
      );
    }

    final externalId = _cleanNullable(input.externalId);
    final scopedExternalId = externalId == null
        ? null
        : _scopeKey(input.provider, externalId);
    final scopedFingerprint = _scopeKey(input.provider, fingerprint);
    final existing = await _findDuplicate(
      provider: input.provider,
      externalId: scopedExternalId,
      fingerprint: scopedFingerprint,
    );
    if (existing != null) {
      return B02HealthImportResult(
        status: B02HealthImportStatus.duplicate,
        localSessionId: existing.localSessionId,
        activityType: translation.activityType,
        provider: input.provider,
        providerType: input.providerType,
        externalId: externalId,
        fingerprint: fingerprint,
        reason: 'Provider activity was already imported.',
      );
    }

    final detail = B02CardioSessionDetail(
      activityType: translation.activityType!,
      durationSeconds: input.endedAtUtc
          .difference(input.startedAtUtc)
          .inSeconds,
      distanceMetres: input.distanceMetres,
      observedPaceSecondsPerKm: input.observedPaceSecondsPerKm,
      observedSpeedKph: input.observedSpeedKph,
      inclinePercentage: input.inclinePercentage,
      elevationMetres: input.elevationMetres,
      averageHeartRate: input.averageHeartRate,
      perceivedExertion: input.perceivedExertion,
      isIntervalWorkout: input.isIntervalWorkout,
      inputMode: B02InputMode.healthImport,
      intervals: input.intervals,
    );
    final state = B02ExecutionDraftState(
      snapshotId: _uuid.v4(),
      snapshotVersion: 1,
      activityType: translation.activityType!,
      routineName: input.displayName?.trim().isNotEmpty == true
          ? input.displayName!.trim()
          : 'Imported activity',
      elapsedSeconds: detail.durationSeconds,
      currentExerciseOrdinal: 0,
      currentSetOrdinal: 0,
      cardioDetail: detail,
    );
    final sessionId = await _activities.completeImportedActivity(
      state: state,
      provider: input.provider,
      sourceName: input.sourceName,
      externalId: scopedExternalId,
      fingerprint: scopedFingerprint,
      estimatedCalories: input.estimatedCalories ?? 0,
      completedAtUtc: input.endedAtUtc,
    );
    return B02HealthImportResult(
      status: B02HealthImportStatus.imported,
      localSessionId: sessionId,
      activityType: translation.activityType,
      provider: input.provider,
      providerType: input.providerType,
      externalId: externalId,
      fingerprint: fingerprint,
      reason: translation.reason,
    );
  }

  Future<B02HealthImportResult> importHealthDataPoint(HealthDataPoint point) =>
      importActivity(B02HealthActivityInput.fromHealthDataPoint(point));

  Future<HealthProvenance?> _findDuplicate({
    required String provider,
    required String? externalId,
    required String fingerprint,
  }) async {
    final query = _db.select(_db.healthProvenances)
      ..where((table) {
        final providerMatch = table.provider.equals(provider);
        if (externalId != null) {
          return providerMatch & table.externalId.equals(externalId);
        }
        return providerMatch & table.fingerprint.equals(fingerprint);
      })
      ..limit(1);
    return query.getSingleOrNull();
  }

  String _fingerprint(B02HealthActivityInput input) {
    final supplied = _cleanNullable(input.fingerprint);
    if (supplied != null) return supplied;
    final canonical = [
      input.provider,
      input.providerType,
      input.externalId ?? '',
      input.startedAtUtc.toUtc().toIso8601String(),
      input.endedAtUtc.toUtc().toIso8601String(),
      input.distanceMetres?.toString() ?? '',
      input.estimatedCalories?.toString() ?? '',
    ].join('|');
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static String _scopeKey(String provider, String value) => '$provider|$value';

  static String? _cleanNullable(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}

class HealthActivityExportRepository {
  final Health _health;

  HealthActivityExportRepository([Health? health])
    : _health = health ?? Health();

  static HealthWorkoutActivityType? nativeTypeFor(
    B02ActivityType activityType,
    HealthPlatformType platform,
  ) {
    return switch (activityType) {
      B02ActivityType.strength => HealthWorkoutActivityType.STRENGTH_TRAINING,
      B02ActivityType.running => HealthWorkoutActivityType.RUNNING,
      B02ActivityType.cycling => HealthWorkoutActivityType.BIKING,
      B02ActivityType.walking => HealthWorkoutActivityType.WALKING,
      B02ActivityType.yoga => HealthWorkoutActivityType.YOGA,
      B02ActivityType.mobility || B02ActivityType.legacy => null,
    };
  }

  Future<bool> writeActivity({
    required B02ActivityType activityType,
    required String title,
    required int durationSeconds,
    required int caloriesBurned,
    required DateTime startTime,
    required HealthPlatformType platform,
  }) async {
    if (durationSeconds < 1 || caloriesBurned < 0) return false;
    final nativeType = nativeTypeFor(activityType, platform);
    if (nativeType == null) return false;
    return _health.writeWorkoutData(
      activityType: nativeType,
      title: title,
      start: startTime,
      end: startTime.add(Duration(seconds: durationSeconds)),
      totalEnergyBurned: caloriesBurned,
      totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
    );
  }
}
