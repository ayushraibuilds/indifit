import '../../database/app_database.dart';
import '../../models/b02_execution_models.dart';
import '../../models/b02_group_plan_validator.dart';
import '../program_repository.dart';

/// Validates program authoring structures, version graphs, ordinals,
/// group plans, and bundled sources.
class ProgramAuthoringValidator {
  const ProgramAuthoringValidator();

  void requireText(String value, String label) {
    if (value.trim().isEmpty) throw ArgumentError('$label must not be blank.');
  }

  void validateOrdinals(String label, Iterable<int> ordinals) {
    final values = ordinals.toList()..sort();
    for (var index = 0; index < values.length; index++) {
      if (values[index] != index) {
        throw ArgumentError('$label ordinals must be contiguous from zero.');
      }
    }
  }

  void requireExactOrder(
    Set<String> actualIds,
    List<String> requestedIds,
    String label,
  ) {
    if (requestedIds.length != actualIds.length ||
        requestedIds.toSet().length != requestedIds.length ||
        requestedIds.any((id) => !actualIds.contains(id))) {
      throw ArgumentError(
        'The requested $label order must contain every existing $label exactly once.',
      );
    }
  }

  B02ExerciseGroupMember memberRowAsDomain(ExerciseGroupMember member) {
    return B02ExerciseGroupMember(
      id: member.id,
      exercisePrescriptionId: member.exercisePrescriptionId,
      ordinal: member.ordinal,
      transitionRestSeconds: member.transitionRestSeconds,
    );
  }

  void validateExistingBundledSource(
    BundledProgramSourceInput source,
    Iterable<Program> programs,
    Iterable<ProgramVersion> versions,
  ) {
    Program? program;
    for (final row in programs) {
      if (row.id == source.programId) {
        program = row;
        break;
      }
    }
    ProgramVersion? version;
    for (final row in versions) {
      if (row.id == source.sourceVersionId) {
        version = row;
        break;
      }
    }
    if (program == null || version == null) {
      throw StateError(
        'Bundled program source ${source.programId} is incomplete.',
      );
    }
    if (program.archivedAtUtc != null ||
        version.programId != source.programId ||
        version.status != 'published' ||
        version.versionNumber != 1 ||
        version.archivedAtUtc != null) {
      throw StateError(
        'Bundled program source ${source.programId} is unavailable.',
      );
    }
  }

  Future<void> validateGraph(
    AppDatabase db,
    List<ProgramBlockInput> blocks,
  ) async {
    validateOrdinals('block', blocks.map((block) => block.ordinal));
    var expectedProgramWeekOrdinal = 0;
    final exerciseIds = <String>{};
    final prescriptionRowIds = <String>{};
    final groupRowIds = <String>{};
    final groupMemberRowIds = <String>{};
    for (final block in blocks) {
      requireText(block.name, 'Block name');
      validateOrdinals(
        'week in block ${block.ordinal}',
        block.weeks.map((week) => week.ordinalInBlock),
      );
      for (final week in block.weeks) {
        if (week.programWeekOrdinal != expectedProgramWeekOrdinal++) {
          throw ArgumentError(
            'Program week ordinals must be contiguous from zero.',
          );
        }
        validateOrdinals(
          'template in week ${week.programWeekOrdinal}',
          week.templates.map((template) => template.ordinal),
        );
        for (final template in week.templates) {
          requireText(template.name, 'Session template name');
          if (template.plannedWeekday < 1 || template.plannedWeekday > 7) {
            throw ArgumentError('Planned weekday must be between 1 and 7.');
          }
          final minute = template.plannedStartMinute;
          if (minute != null && (minute < 0 || minute > 1439)) {
            throw ArgumentError(
              'Planned start minute must be between 0 and 1439.',
            );
          }
          validateOrdinals(
            'prescription in template ${template.ordinal}',
            template.prescriptions.map((p) => p.ordinal),
          );
          final templatePrescriptionIds = <String>{};
          for (final prescription in template.prescriptions) {
            final prescriptionRowId = prescription.id;
            if (prescriptionRowId != null) {
              requireText(prescriptionRowId, 'Exercise prescription ID');
              if (!prescriptionRowIds.add(prescriptionRowId.trim()) ||
                  !templatePrescriptionIds.add(prescriptionRowId.trim())) {
                throw ArgumentError(
                  'Exercise prescription IDs must be unique in a program graph.',
                );
              }
            }
            requireText(
              prescription.exerciseNameSnapshot,
              'Exercise name snapshot',
            );
            requireText(prescription.repsRange, 'Reps range');
            if (prescription.plannedSets <= 0) {
              throw ArgumentError('Planned sets must be greater than zero.');
            }
            final id = prescription.exerciseId;
            if (id == null || id.trim().isEmpty) {
              if (!prescription.allowUnresolvedExerciseFallback) {
                throw ArgumentError(
                  'New prescriptions require a stable exercise ID; unresolved fallback must be explicit.',
                );
              }
            } else {
              exerciseIds.add(id);
            }
          }
          final groups = template.groups
              .map(
                (group) => B02ExerciseGroup(
                  id: group.id?.trim().isNotEmpty == true
                      ? group.id!.trim()
                      : 'group-${block.ordinal}-${week.programWeekOrdinal}-${template.ordinal}-${group.ordinal}',
                  sessionTemplateId:
                      'template-${block.ordinal}-${week.programWeekOrdinal}-${template.ordinal}',
                  ordinal: group.ordinal,
                  groupType: group.groupType,
                  roundCount: group.roundCount,
                  restAfterRoundSeconds: group.restAfterRoundSeconds,
                  label: group.label,
                  members: group.members
                      .map(
                        (member) => B02ExerciseGroupMember(
                          id: member.id?.trim().isNotEmpty == true
                              ? member.id!.trim()
                              : 'member-${block.ordinal}-${week.programWeekOrdinal}-${template.ordinal}-${group.ordinal}-${member.ordinal}',
                          exercisePrescriptionId: member.exercisePrescriptionId,
                          ordinal: member.ordinal,
                          transitionRestSeconds: member.transitionRestSeconds,
                        ),
                      )
                      .toList(growable: false),
                ),
              )
              .toList(growable: false);
          for (final group in groups) {
            if (!groupRowIds.add(group.id)) {
              throw ArgumentError(
                'Exercise group IDs must be unique in a program graph.',
              );
            }
            for (final member in group.members) {
              if (!groupMemberRowIds.add(member.id)) {
                throw ArgumentError(
                  'Exercise group member IDs must be unique in a program graph.',
                );
              }
            }
          }
          B02GroupPlanValidator.validate(
            groups: groups,
            prescriptionIds: templatePrescriptionIds,
          );
        }
      }
    }
    if (exerciseIds.isEmpty) return;
    final found = await (db.select(
      db.exercises,
    )..where((t) => t.stableId.isIn(exerciseIds.toList()))).get();
    final foundIds = found
        .map((exercise) => exercise.stableId)
        .whereType<String>()
        .toSet();
    final missing = exerciseIds.difference(foundIds);
    if (missing.isNotEmpty) {
      throw ArgumentError(
        'Unknown stable exercise IDs: ${missing.join(', ')}.',
      );
    }
  }
}
