import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import '../../data/database/app_database.dart';

/// Versioned codec for serializing and deserializing active workout drafts.
/// Preserves all performed-set fields and supports legacy bare-array payloads.
class WorkoutDraftCodec {
  static const int currentVersion = 1;

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
        'sessionId': s.sessionId.value,
        'exerciseName': s.exerciseName.value,
        'weight': s.weight.value,
        'reps': s.reps.value,
        'setNumber': s.setNumber.value,
        'isPr': s.isPr.value,
        'rpe': s.rpe.value,
        'isWarmUp': s.isWarmUp.value,
        'setType': s.setType.value,
        'setNotes': s.setNotes.value,
        'uuid': s.uuid.value,
        'durationSeconds': s.durationSeconds.value,
        'distanceKm': s.distanceKm.value,
        'inclinePercentage': s.inclinePercentage.value,
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
      final rawSets = envelope['loggedSets'];
      if (rawSets == null) return const [];
      if (rawSets is! List) {
        throw const FormatException(
          'Envelope "loggedSets" must be a JSON array.',
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
