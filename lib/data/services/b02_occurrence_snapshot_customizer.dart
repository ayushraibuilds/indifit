import 'dart:convert';

import '../models/b02_execution_models.dart';

/// A change to one already planned prescription in one scheduled workout.
///
/// This is deliberately a patch input, not a second occurrence or program
/// model. The prescription ID remains the identity of the planned slot; the
/// customizer only changes the launch snapshot that belongs to that one
/// unstarted occurrence.
class OccurrenceExerciseCustomization {
  const OccurrenceExerciseCustomization({
    required this.prescriptionId,
    this.replacementExerciseId,
    this.plannedSets,
    this.repsRange,
    this.targetLoadKg,
    this.targetLoadBasis,
  });

  final String prescriptionId;
  final String? replacementExerciseId;
  final int? plannedSets;
  final String? repsRange;
  final double? targetLoadKg;
  final String? targetLoadBasis;

  bool get hasChanges =>
      replacementExerciseId != null ||
      plannedSets != null ||
      repsRange != null ||
      targetLoadKg != null;
}

/// Pure, fail-closed mutation of the B02 execution snapshot shape.
///
/// The repository supplies the canonical exercise catalog and owns the
/// occurrence transaction. This service preserves prescription IDs and the
/// existing group graph, so it cannot accidentally turn a per-day edit into
/// program authoring.
class B02OccurrenceSnapshotCustomizer {
  const B02OccurrenceSnapshotCustomizer();

  String apply({
    required String snapshotJson,
    required String occurrenceId,
    required Iterable<OccurrenceExerciseCustomization> changes,
    required Map<String, String> canonicalExercises,
  }) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(snapshotJson);
    } on Object {
      throw const B02ValidationException(
        'This workout snapshot is unavailable right now.',
      );
    }
    final root = _decodeObject(decoded, 'workout snapshot');
    final snapshotOccurrenceId = root['occurrenceId'];
    if (snapshotOccurrenceId is! String ||
        snapshotOccurrenceId.trim() != occurrenceId.trim()) {
      throw const B02ValidationException(
        'The workout snapshot does not belong to this scheduled workout.',
      );
    }

    final rawPrescriptions = root['prescriptions'];
    if (rawPrescriptions is! List || rawPrescriptions.isEmpty) {
      throw const B02ValidationException(
        'This workout has no editable exercise prescriptions.',
      );
    }
    final prescriptions = <Map<String, dynamic>>[];
    final byId = <String, Map<String, dynamic>>{};
    final groupedPrescriptionIds = _groupedPrescriptionIds(root['groups']);
    for (var index = 0; index < rawPrescriptions.length; index++) {
      final raw = rawPrescriptions[index];
      final prescription = _decodeObject(raw, 'exercise prescription');
      final id = _requiredText(prescription['id'], 'prescription ID');
      final ordinal = _requiredInt(prescription['ordinal'], 'exercise order');
      if (ordinal != index || byId.containsKey(id)) {
        throw const B02ValidationException(
          'This workout has an invalid exercise order.',
        );
      }
      prescriptions.add(prescription);
      byId[id] = prescription;
    }

    final seenChanges = <String>{};
    var changed = false;
    for (final change in changes) {
      final prescriptionId = change.prescriptionId.trim();
      if (prescriptionId.isEmpty || !seenChanges.add(prescriptionId)) {
        throw const B02ValidationException(
          'Each exercise can be changed only once per save.',
        );
      }
      if (!change.hasChanges) {
        throw const B02ValidationException(
          'Choose a change before saving the workout.',
        );
      }
      if (change.replacementExerciseId != null && change.targetLoadKg != null) {
        throw const B02ValidationException(
          'Set the replacement load after the workout starts.',
        );
      }
      final prescription = byId[prescriptionId];
      if (prescription == null) {
        throw const B02ValidationException(
          'An exercise is no longer available in this workout.',
        );
      }

      if (change.plannedSets != null) {
        if (groupedPrescriptionIds.contains(prescriptionId)) {
          throw const B02ValidationException(
            'Set count is controlled by this workout group.',
          );
        }
        if (change.plannedSets! < 1) {
          throw const B02ValidationException('Sets must be at least 1.');
        }
        prescription['plannedSets'] = change.plannedSets;
        changed = true;
      }

      final reps = change.repsRange?.trim();
      if (reps != null) {
        final range = _parseRepsRange(reps);
        prescription['repsRange'] = reps;
        // These snapshot-level fields are the explicit per-occurrence
        // override. B02 falls back to relational prescription rows only when
        // the frozen snapshot has not supplied a value.
        prescription['targetRepsMin'] = range.$1;
        prescription['targetRepsMax'] = range.$2;
        _updateSetPrescriptions(prescription, (set) {
          set['targetRepsMin'] = range.$1;
          set['targetRepsMax'] = range.$2;
        });
        changed = true;
      }

      if (change.targetLoadKg != null) {
        final load = change.targetLoadKg!;
        if (!load.isFinite || load < 0) {
          throw const B02ValidationException(
            'Load must be a valid non-negative number.',
          );
        }
        final basis = change.targetLoadBasis?.trim();
        if (basis != null && !_loadBases.contains(basis)) {
          throw const B02ValidationException('This load type is unavailable.');
        }
        prescription['targetLoadKg'] = load;
        if (basis != null) prescription['loadBasis'] = basis;
        _updateSetPrescriptions(prescription, (set) {
          set['targetLoadKg'] = load;
          if (basis != null) set['loadBasis'] = basis;
        });
        changed = true;
      }

      final replacementId = change.replacementExerciseId?.trim();
      if (replacementId != null) {
        final replacementName = canonicalExercises[replacementId];
        if (replacementName == null || replacementName.trim().isEmpty) {
          throw const B02ValidationException(
            'The selected replacement is no longer available.',
          );
        }
        final currentId = prescription['exerciseId'];
        if (currentId is String && currentId.trim() == replacementId) {
          throw const B02ValidationException(
            'The selected exercise is already in this workout.',
          );
        }
        final currentName = prescription['exerciseNameSnapshot'];
        final expectedId = prescription['expectedExerciseId'] is String
            ? (prescription['expectedExerciseId'] as String).trim()
            : currentId is String
            ? currentId.trim()
            : '';
        final expectedName =
            prescription['expectedExerciseNameSnapshot'] is String
            ? (prescription['expectedExerciseNameSnapshot'] as String).trim()
            : currentName is String
            ? currentName.trim()
            : '';
        if (expectedId.isEmpty || expectedName.isEmpty) {
          throw const B02ValidationException(
            'The planned exercise identity is unavailable.',
          );
        }
        prescription['expectedExerciseId'] = expectedId;
        prescription['expectedExerciseNameSnapshot'] = expectedName;
        prescription['exerciseId'] = replacementId;
        prescription['exerciseNameSnapshot'] = replacementName.trim();
        if (replacementId == expectedId) {
          prescription.remove('substitutionReason');
          prescription.remove('targetLoadClearedForReplacement');
        } else {
          prescription['substitutionReason'] = 'User-selected replacement';
          // A replacement must use its own history and load recommendation.
          // It cannot inherit an equipment-specific load from the planned
          // exercise merely because it occupies the same occurrence slot.
          prescription['targetLoadClearedForReplacement'] = true;
          prescription.remove('targetLoadKg');
          prescription.remove('loadBasis');
          _updateSetPrescriptions(prescription, (set) {
            set.remove('targetLoadKg');
            set.remove('loadBasis');
          });
        }
        changed = true;
      }
    }

    if (!changed) {
      throw const B02ValidationException(
        'Choose a change before saving the workout.',
      );
    }
    root['prescriptions'] = prescriptions;
    return jsonEncode(root);
  }

  static final Set<String> _loadBases = {
    for (final basis in B02LoadBasis.values) basis.dbValue,
  };

  static void _updateSetPrescriptions(
    Map<String, dynamic> prescription,
    void Function(Map<String, dynamic> set) update,
  ) {
    final rawSets = prescription['strengthSetPrescriptions'];
    if (rawSets is! List) return;
    for (var index = 0; index < rawSets.length; index++) {
      final rawSet = rawSets[index];
      if (rawSet is! Map) {
        throw const B02ValidationException(
          'This workout has invalid set targets.',
        );
      }
      final updated = Map<String, dynamic>.from(rawSet);
      update(updated);
      rawSets[index] = updated;
    }
  }

  static Set<String> _groupedPrescriptionIds(Object? rawGroups) {
    if (rawGroups == null) return <String>{};
    if (rawGroups is! List) {
      throw const B02ValidationException('This workout has invalid groups.');
    }
    final ids = <String>{};
    for (final rawGroup in rawGroups) {
      final group = _decodeObject(rawGroup, 'exercise group');
      final members = group['members'];
      if (members is! List) {
        throw const B02ValidationException(
          'This workout has invalid group members.',
        );
      }
      for (final rawMember in members) {
        final member = _decodeObject(rawMember, 'group member');
        ids.add(
          _requiredText(
            member['exercisePrescriptionId'],
            'group prescription ID',
          ),
        );
      }
    }
    return ids;
  }

  static Map<String, dynamic> _decodeObject(Object? raw, String field) {
    if (raw is! Map) {
      throw B02ValidationException('$field is unavailable.');
    }
    return Map<String, dynamic>.from(raw);
  }

  static String _requiredText(Object? raw, String field) {
    if (raw is! String || raw.trim().isEmpty) {
      throw B02ValidationException('$field is unavailable.');
    }
    return raw.trim();
  }

  static int _requiredInt(Object? raw, String field) {
    if (raw is! int) throw B02ValidationException('$field is unavailable.');
    return raw;
  }

  static (int, int) _parseRepsRange(String value) {
    final numbers = RegExp(
      r'\d+',
    ).allMatches(value).map((match) => int.parse(match.group(0)!)).toList();
    if (numbers.isEmpty ||
        numbers.length > 2 ||
        numbers.any((item) => item < 1)) {
      throw const B02ValidationException(
        'Use a positive repetition target, such as 8 or 8–10.',
      );
    }
    final min = numbers.first;
    final max = numbers.length == 1 ? min : numbers[1];
    if (max < min) {
      throw const B02ValidationException(
        'The highest repetition target must not be below the lowest.',
      );
    }
    return (min, max);
  }
}
