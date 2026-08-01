import 'b02_execution_models.dart';

/// Validates the explicit group graph independently of Drift or widgets.
///
/// The caller supplies the prescription IDs that belong to one session
/// template. Group membership is checked against that exact set; no display
/// name or adjacency fallback is permitted.
class B02GroupPlanValidator {
  const B02GroupPlanValidator._();

  static void validate({
    required Iterable<B02ExerciseGroup> groups,
    required Set<String> prescriptionIds,
  }) {
    final values = groups.toList(growable: false);
    _contiguous(values.map((group) => group.ordinal), 'Group');
    final groupIds = <String>{};
    final memberIds = <String>{};
    final memberPrescriptionIds = <String>{};

    for (final group in values) {
      if (!groupIds.add(group.id)) {
        throw B02ValidationException('Exercise group IDs must be unique.');
      }
      for (final member in group.members) {
        if (!memberIds.add(member.id)) {
          throw B02ValidationException(
            'Exercise group member IDs must be unique.',
          );
        }
        if (!prescriptionIds.contains(member.exercisePrescriptionId)) {
          throw B02ValidationException(
            'Group member references an exercise prescription outside its session template.',
          );
        }
        if (!memberPrescriptionIds.add(member.exercisePrescriptionId)) {
          throw B02ValidationException(
            'An exercise prescription can belong to only one group.',
          );
        }
      }
    }
  }

  static void _contiguous(Iterable<int> ordinals, String label) {
    final values = ordinals.toList()..sort();
    for (var index = 0; index < values.length; index++) {
      if (values[index] != index) {
        throw B02ValidationException(
          '$label ordinals must be contiguous from zero.',
        );
      }
    }
  }
}
