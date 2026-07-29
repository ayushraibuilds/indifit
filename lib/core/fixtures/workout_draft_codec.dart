import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import '../../data/database/app_database.dart';

/// Exception thrown when encountering an unsupported future or legacy codec envelope version.
class UnsupportedDraftVersionException implements Exception {
  final int version;
  const UnsupportedDraftVersionException(this.version);

  @override
  String toString() =>
      'UnsupportedDraftVersionException: Draft codec version $version is not supported (supported version: ${WorkoutDraftCodec.currentVersion}).';
}

/// Versioned codec for serializing and deserializing active workout drafts.
/// Preserves all performed-set fields and supports legacy bare-array payloads.
///
/// NOTE ON BOUNDED LIFECYCLE LIMITATION:
/// Session logging (logSession) saves session and performed sets atomically in Drift database.
/// Active draft deletion (deleteActiveDraft) occurs immediately after logSession succeeds.
/// In the event of process termination between these operations, both a saved session and an active draft
/// may persist. Full database-level transactional occurrence finalization and command-ID idempotency
/// are explicitly deferred to task B01-09.
class WorkoutDraftCodec {
  static const int currentVersion = 1;

  /// Allowed canonical set types supported in the application.
  static const Set<String> allowedSetTypes = {
    'working',
    'warmup',
    'drop',
    'failure',
    'amrap',
  };

  /// Serializes active draft state into a versioned JSON envelope string.
  static String encode({
    required String routineName,
    required int currentExerciseIndex,
    required int currentSetIndex,
    required int elapsedSeconds,
    required List<WorkoutSetsCompanion> loggedSets,
  }) {
    final rawSets = loggedSets.map((s) {
      final map = <String, dynamic>{
        'sessionId': s.sessionId.present ? s.sessionId.value : 0,
        'exerciseName': s.exerciseName.present ? s.exerciseName.value : '',
        'weight': s.weight.present ? s.weight.value : 0.0,
        'reps': s.reps.present ? s.reps.value : 0,
        'setNumber': s.setNumber.present ? s.setNumber.value : 1,
        'isPr': s.isPr.present ? s.isPr.value : false,
        'rpe': s.rpe.present ? s.rpe.value : null,
        'isWarmUp': s.isWarmUp.present ? s.isWarmUp.value : false,
        'setType': s.setType.present ? s.setType.value : 'working',
        'setNotes': s.setNotes.present ? s.setNotes.value : null,
        'uuid': s.uuid.present ? s.uuid.value : null,
        'durationSeconds': s.durationSeconds.present
            ? s.durationSeconds.value
            : null,
        'distanceKm': s.distanceKm.present ? s.distanceKm.value : null,
        'inclinePercentage': s.inclinePercentage.present
            ? s.inclinePercentage.value
            : null,
      };
      return map;
    }).toList();

    final envelope = <String, dynamic>{
      'version': currentVersion,
      'routineName': routineName,
      'currentExerciseIndex': currentExerciseIndex,
      'currentSetIndex': currentSetIndex,
      'elapsedSeconds': elapsedSeconds,
      'loggedSets': rawSets,
    };

    return jsonEncode(envelope);
  }

  /// Deserializes a draft JSON string (envelope v1 or legacy bare-array v0) into a list of [WorkoutSetsCompanion] objects.
  static List<WorkoutSetsCompanion> decodeLoggedSets(String jsonStr) {
    if (jsonStr.trim().isEmpty) return const [];

    dynamic decoded;
    try {
      decoded = jsonDecode(jsonStr);
    } catch (e) {
      throw FormatException(
        'Invalid JSON structure in workout draft payload: $e',
      );
    }

    if (decoded is List) {
      // Legacy bare-array format (v0)
      return decoded.map((item) {
        if (item is! Map<String, dynamic> && item is! Map) {
          throw const FormatException(
            'Legacy draft set item must be a JSON object.',
          );
        }
        final map = Map<String, dynamic>.from(item as Map);
        return _parseWorkoutSetsCompanion(map, isLegacy: true);
      }).toList();
    } else if (decoded is Map) {
      // Versioned envelope format (v1+)
      final envelope = Map<String, dynamic>.from(decoded);

      // 1. Validate version member presence and version compatibility
      final versionRaw = envelope['version'];
      if (versionRaw == null) {
        throw const FormatException(
          'Missing required "version" in draft envelope payload.',
        );
      }
      if (versionRaw is! int) {
        throw const FormatException(
          'Draft envelope "version" must be an integer.',
        );
      }
      if (versionRaw != currentVersion) {
        throw UnsupportedDraftVersionException(versionRaw);
      }

      // 2. Validate loggedSets presence and list type
      if (!envelope.containsKey('loggedSets') ||
          envelope['loggedSets'] == null) {
        throw const FormatException(
          'Missing required "loggedSets" array in draft envelope.',
        );
      }
      final rawSets = envelope['loggedSets'];
      if (rawSets is! List) {
        throw const FormatException(
          'Draft envelope "loggedSets" must be a JSON array.',
        );
      }

      return rawSets.map((item) {
        if (item is! Map<String, dynamic> && item is! Map) {
          throw const FormatException('Draft set item must be a JSON object.');
        }
        final map = Map<String, dynamic>.from(item as Map);
        return _parseWorkoutSetsCompanion(map, isLegacy: false);
      }).toList();
    } else {
      throw const FormatException(
        'Draft payload must be a JSON object or array.',
      );
    }
  }

  static WorkoutSetsCompanion _parseWorkoutSetsCompanion(
    Map<String, dynamic> map, {
    required bool isLegacy,
  }) {
    final sessionId = _parseRequiredInt(map, 'sessionId');
    final exerciseName = _parseRequiredString(map, 'exerciseName');
    final weight = _parseRequiredDouble(map, 'weight');
    final reps = _parseRequiredInt(map, 'reps');
    final setNumber = _parseRequiredInt(map, 'setNumber');
    final isPr = _parseRequiredBool(map, 'isPr');

    final rpe = _parseOptionalInt(map, 'rpe');
    final isWarmUp = _parseOptionalBool(map, 'isWarmUp') ?? false;

    final setType = _parseOptionalString(map, 'setType') ?? 'working';
    if (!allowedSetTypes.contains(setType.toLowerCase())) {
      throw FormatException(
        'Invalid setType "$setType". Allowed set types: ${allowedSetTypes.join(', ')}.',
      );
    }

    final setNotes = _parseOptionalString(map, 'setNotes');
    final uuid = _parseOptionalString(map, 'uuid');
    final durationSeconds = _parseOptionalInt(map, 'durationSeconds');
    final distanceKm = _parseOptionalDouble(map, 'distanceKm');
    final inclinePercentage = _parseOptionalDouble(map, 'inclinePercentage');

    return WorkoutSetsCompanion.insert(
      sessionId: sessionId,
      exerciseName: exerciseName,
      weight: weight,
      reps: reps,
      setNumber: setNumber,
      isPr: Value(isPr),
      rpe: Value(rpe),
      isWarmUp: Value(isWarmUp),
      setType: Value(setType),
      setNotes: Value(setNotes),
      uuid: Value(uuid),
      durationSeconds: Value(durationSeconds),
      distanceKm: Value(distanceKm),
      inclinePercentage: Value(inclinePercentage),
    );
  }

  static int _parseRequiredInt(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val == null) {
      throw FormatException('Missing required field "$key" in draft payload.');
    }
    if (val is! int) {
      throw FormatException('Field "$key" must be an integer.');
    }
    return val;
  }

  static String _parseRequiredString(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val == null) {
      throw FormatException('Missing required field "$key" in draft payload.');
    }
    if (val is! String) {
      throw FormatException('Field "$key" must be a string.');
    }
    return val;
  }

  static double _parseRequiredDouble(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val == null) {
      throw FormatException('Missing required field "$key" in draft payload.');
    }
    if (val is num) {
      return val.toDouble();
    }
    throw FormatException('Field "$key" must be a number.');
  }

  static bool _parseRequiredBool(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val == null) {
      throw FormatException('Missing required field "$key" in draft payload.');
    }
    if (val is! bool) {
      throw FormatException('Field "$key" must be a boolean.');
    }
    return val;
  }

  static int? _parseOptionalInt(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val == null) return null;
    if (val is int) return val;
    throw FormatException('Optional field "$key" must be an integer or null.');
  }

  static double? _parseOptionalDouble(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val == null) return null;
    if (val is num) return val.toDouble();
    throw FormatException('Optional field "$key" must be a number or null.');
  }

  static String? _parseOptionalString(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val == null) return null;
    if (val is String) return val;
    throw FormatException('Optional field "$key" must be a string or null.');
  }

  static bool? _parseOptionalBool(Map<String, dynamic> map, String key) {
    final val = map[key];
    if (val == null) return null;
    if (val is bool) return val;
    throw FormatException('Optional field "$key" must be a boolean or null.');
  }
}
