import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'b02_execution_models.dart';

/// Validation shared by the draft editor and persistence adapters.
///
/// The model constructor validates the shape of each technique. This
/// validator additionally checks the relationship between a set header and
/// its actual segments, which cannot be known by [B02TechniqueFields] alone.
class B02RichSetValidator {
  const B02RichSetValidator._();

  static void validateTechnique(
    B02TechniqueFields technique, {
    int? headerReps,
  }) {
    if (headerReps != null && headerReps < 0) {
      throw const B02ValidationException('Header reps must not be negative.');
    }

    if (technique.segments.isEmpty) return;

    if (!technique.isDropSet && !technique.isRestPause) {
      throw const B02ValidationException(
        'Segments require drop-set or rest-pause intent.',
      );
    }

    if (headerReps != null && technique.segmentReps != headerReps) {
      throw B02ValidationException(
        'Segment reps (${technique.segmentReps}) must equal header reps ($headerReps).',
      );
    }
  }

  static void validatePerformedSet(B02PerformedSet set) {
    validateTechnique(set.technique, headerReps: set.actualReps);
  }

  static void validatePrescription(B02StrengthSetPrescription prescription) {
    // A range is a target, not an actual header. It is therefore intentionally
    // not compared with planned segment totals; performed sets carry the
    // actual header that must equal their segment total.
    validateTechnique(prescription.technique);
  }
}

extension B02SetSegmentEditing on B02SetSegment {
  B02SetSegment copyWith({
    String? id,
    int? ordinal,
    int? reps,
    Object? externalLoadKg = _unset,
    Object? loadBasis = _unset,
    Object? assistanceKg = _unset,
    Object? restBeforeSeconds = _unset,
  }) {
    return B02SetSegment(
      id: id ?? this.id,
      ordinal: ordinal ?? this.ordinal,
      reps: reps ?? this.reps,
      externalLoadKg: externalLoadKg == _unset
          ? this.externalLoadKg
          : externalLoadKg as double?,
      loadBasis: loadBasis == _unset
          ? this.loadBasis
          : loadBasis as B02LoadBasis?,
      assistanceKg: assistanceKg == _unset
          ? this.assistanceKg
          : assistanceKg as double?,
      restBeforeSeconds: restBeforeSeconds == _unset
          ? this.restBeforeSeconds
          : restBeforeSeconds as int?,
    );
  }
}

extension B02TechniqueEditing on B02TechniqueFields {
  bool get hasTempo => tempoEccentricSeconds != null;

  int get segmentReps =>
      segments.fold(0, (total, segment) => total + segment.reps);

  B02TechniqueFields copyWith({
    B02EffortMode? effortMode,
    bool? endedAtFailure,
    bool? isDropSet,
    bool? isRestPause,
    Object? tempoEccentricSeconds = _unset,
    Object? tempoBottomPauseSeconds = _unset,
    Object? tempoConcentricSeconds = _unset,
    Object? tempoLockoutPauseSeconds = _unset,
    Object? pausedRepPosition = _unset,
    Object? pausedRepSeconds = _unset,
    Object? assistanceMode = _unset,
    Object? assistanceKg = _unset,
    List<B02SetSegment>? segments,
  }) {
    return B02TechniqueFields(
      effortMode: effortMode ?? this.effortMode,
      endedAtFailure: endedAtFailure ?? this.endedAtFailure,
      isDropSet: isDropSet ?? this.isDropSet,
      isRestPause: isRestPause ?? this.isRestPause,
      tempoEccentricSeconds: tempoEccentricSeconds == _unset
          ? this.tempoEccentricSeconds
          : tempoEccentricSeconds as int?,
      tempoBottomPauseSeconds: tempoBottomPauseSeconds == _unset
          ? this.tempoBottomPauseSeconds
          : tempoBottomPauseSeconds as int?,
      tempoConcentricSeconds: tempoConcentricSeconds == _unset
          ? this.tempoConcentricSeconds
          : tempoConcentricSeconds as int?,
      tempoLockoutPauseSeconds: tempoLockoutPauseSeconds == _unset
          ? this.tempoLockoutPauseSeconds
          : tempoLockoutPauseSeconds as int?,
      pausedRepPosition: pausedRepPosition == _unset
          ? this.pausedRepPosition
          : pausedRepPosition as B02PausedRepPosition?,
      pausedRepSeconds: pausedRepSeconds == _unset
          ? this.pausedRepSeconds
          : pausedRepSeconds as int?,
      assistanceMode: assistanceMode == _unset
          ? this.assistanceMode
          : assistanceMode as B02AssistanceMode?,
      assistanceKg: assistanceKg == _unset
          ? this.assistanceKg
          : assistanceKg as double?,
      segments: segments ?? this.segments,
    );
  }
}

const _unset = Object();

/// Small codec used by editors and repositories that need to move one rich
/// technique without parsing the complete execution envelope.
class B02TechniqueDraftCodec {
  const B02TechniqueDraftCodec._();

  static String encode(B02TechniqueFields technique) {
    B02RichSetValidator.validateTechnique(technique);
    return jsonEncode(technique.toJson());
  }

  static B02TechniqueFields decode(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        throw const B02ValidationException(
          'Technique payload must be an object.',
        );
      }
      return B02TechniqueFields.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on B02ValidationException {
      rethrow;
    } on Object catch (error) {
      throw B02ValidationException('Invalid technique payload: $error');
    }
  }
}

/// A lossless persistence bundle for a performed rich set. The generated
/// Drift companions cover relational columns; the typed technique and segment
/// companions remain explicit so callers cannot silently drop drop/rest-pause
/// intent while the existing v16 schema is retained.
class B02PerformedSetCompanions {
  final PerformedSetsCompanion set;
  final List<PerformedSetSegmentsCompanion> segments;
  final B02TechniqueFields technique;

  const B02PerformedSetCompanions({
    required this.set,
    required this.segments,
    required this.technique,
  });

  factory B02PerformedSetCompanions.fromDto(B02PerformedSet value) {
    B02RichSetValidator.validatePerformedSet(value);
    return B02PerformedSetCompanions(
      set: PerformedSetsCompanion.insert(
        id: value.id,
        performedExerciseId: value.performedExerciseId,
        ordinal: value.ordinal,
        role: value.role.dbValue,
        targetLoadKg: Value(value.targetLoadKg),
        targetLoadBasis: Value(value.targetLoadBasis?.dbValue),
        targetRepsMin: Value(value.targetRepsMin),
        targetRepsMax: Value(value.targetRepsMax),
        targetRpe: Value(value.targetRpe),
        actualLoadKg: Value(value.actualLoadKg),
        actualLoadBasis: Value(value.actualLoadBasis?.dbValue),
        actualReps: Value(value.actualReps),
        actualRpe: Value(value.actualRpe),
        effortMode: Value(value.technique.effortMode.dbValue),
        endedAtFailure: Value(value.technique.endedAtFailure),
        tempoEccentricSeconds: Value(value.technique.tempoEccentricSeconds),
        tempoBottomPauseSeconds: Value(value.technique.tempoBottomPauseSeconds),
        tempoConcentricSeconds: Value(value.technique.tempoConcentricSeconds),
        tempoLockoutPauseSeconds: Value(
          value.technique.tempoLockoutPauseSeconds,
        ),
        pausedRepPosition: Value(value.technique.pausedRepPosition?.dbValue),
        pausedRepSeconds: Value(value.technique.pausedRepSeconds),
        assistanceMode: Value(value.technique.assistanceMode?.dbValue),
        assistanceKg: Value(value.technique.assistanceKg),
        notes: Value(value.notes),
      ),
      segments: [
        for (final segment in value.technique.segments)
          PerformedSetSegmentsCompanion.insert(
            id: segment.id ?? '${value.id}-segment-${segment.ordinal}',
            performedSetId: value.id,
            ordinal: segment.ordinal,
            reps: segment.reps,
            externalLoadKg: Value(segment.externalLoadKg),
            loadBasis: Value(segment.loadBasis?.dbValue),
            assistanceKg: Value(segment.assistanceKg),
            restBeforeSeconds: Value(segment.restBeforeSeconds),
          ),
      ],
      technique: value.technique,
    );
  }
}

extension B02StrengthSetPrescriptionPersistence on B02StrengthSetPrescription {
  StrengthSetPrescriptionsCompanion toDriftCompanion() {
    B02RichSetValidator.validatePrescription(this);
    return StrengthSetPrescriptionsCompanion.insert(
      id: id,
      exercisePrescriptionId: exercisePrescriptionId,
      ordinal: ordinal,
      targetLoadKg: Value(targetLoadKg),
      loadBasis: Value(loadBasis?.dbValue),
      targetRepsMin: Value(targetRepsMin),
      targetRepsMax: Value(targetRepsMax),
      targetRpe: Value(targetRpe),
      restSeconds: Value(restSeconds),
      effortMode: Value(technique.effortMode.dbValue),
      tempoEccentricSeconds: Value(technique.tempoEccentricSeconds),
      tempoBottomPauseSeconds: Value(technique.tempoBottomPauseSeconds),
      tempoConcentricSeconds: Value(technique.tempoConcentricSeconds),
      tempoLockoutPauseSeconds: Value(technique.tempoLockoutPauseSeconds),
      pausedRepPosition: Value(technique.pausedRepPosition?.dbValue),
      pausedRepSeconds: Value(technique.pausedRepSeconds),
      assistanceMode: Value(technique.assistanceMode?.dbValue),
      assistanceKg: Value(technique.assistanceKg),
      techniquePlanJson: Value(B02TechniqueDraftCodec.encode(technique)),
    );
  }
}
