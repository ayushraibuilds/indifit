import 'dart:convert';

import 'package:indifit/core/fixtures/workout_draft_codec.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b02_execution_models.dart';

/// Result of reading either a B02 v2 execution draft or a retained B01 draft.
///
/// A legacy result intentionally exposes only the old performed-set companion
/// list. It does not fabricate B02 identity, group, modality, target or
/// technique values.
class B02DraftDecodeResult {
  final int version;
  final B02ExecutionDraftState? state;
  final List<WorkoutSetsCompanion>? legacyLoggedSets;

  const B02DraftDecodeResult._({
    required this.version,
    this.state,
    this.legacyLoggedSets,
  });

  const B02DraftDecodeResult.v2(B02ExecutionDraftState state)
    : this._(version: B02ExecutionDraftState.schemaVersion, state: state);

  const B02DraftDecodeResult.legacy({
    required int version,
    required List<WorkoutSetsCompanion> sets,
  }) : this._(version: version, legacyLoggedSets: sets);

  bool get isLegacy => legacyLoggedSets != null;
  bool get isCanonical => state != null;
}

class B02UnsupportedDraftVersionException implements Exception {
  final int version;

  const B02UnsupportedDraftVersionException(this.version);

  @override
  String toString() =>
      'B02UnsupportedDraftVersionException: draft version $version is not supported (supported version: ${B02ExecutionDraftState.schemaVersion}).';
}

/// Version 2 codec for the B02 execution-state payload.
///
/// The existing [WorkoutDraftCodec] remains the source of truth for legacy v0
/// and v1 set-only payloads. This codec only owns the richer B02 envelope and
/// delegates legacy decoding without changing its accepted behavior.
class B02ExecutionDraftCodec {
  static const int currentVersion = B02ExecutionDraftState.schemaVersion;

  static String encode(B02ExecutionDraftState state) {
    return jsonEncode(state.toJson());
  }

  static B02DraftDecodeResult decode(String payload) {
    if (payload.trim().isEmpty) {
      throw const FormatException('B02 draft payload must not be empty.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (error) {
      throw FormatException('Invalid B02 draft JSON: $error');
    }

    if (decoded is List) {
      return B02DraftDecodeResult.legacy(
        version: 0,
        sets: WorkoutDraftCodec.decodeLoggedSets(payload),
      );
    }
    if (decoded is! Map) {
      throw const FormatException(
        'B02 draft payload must be a versioned object or legacy array.',
      );
    }

    final envelope = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final rawVersion = envelope['version'];
    if (rawVersion is! int) {
      throw const FormatException(
        'B02 draft envelope version must be an integer.',
      );
    }

    if (rawVersion == 0 || rawVersion == 1) {
      return B02DraftDecodeResult.legacy(
        version: rawVersion,
        sets: WorkoutDraftCodec.decodeLoggedSets(payload),
      );
    }
    if (rawVersion != currentVersion) {
      throw B02UnsupportedDraftVersionException(rawVersion);
    }

    return B02DraftDecodeResult.v2(B02ExecutionDraftState.fromJson(envelope));
  }
}
