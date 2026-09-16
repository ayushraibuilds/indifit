import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../program_repository.dart';

/// Deep-clones published or draft program version graphs into fresh editable
/// drafts with independent UUIDs across all blocks, weeks, session templates,
/// exercise prescriptions, groups, and group members.
class ProgramSnapshotCloner {
  const ProgramSnapshotCloner();

  Future<void> copyGraph({
    required AppDatabase db,
    required Uuid uuid,
    required ProgramDetailAggregate source,
    required String newVersionId,
  }) async {
    for (final block in source.blocks) {
      final newBlockId = uuid.v4();
      await db
          .into(db.programBlocks)
          .insert(
            ProgramBlocksCompanion.insert(
              id: newBlockId,
              programVersionId: newVersionId,
              ordinal: block.ordinal,
              name: block.name,
              description: Value(block.description),
            ),
          );
      for (final week in source.weeks.where(
        (row) => row.programBlockId == block.id,
      )) {
        final newWeekId = uuid.v4();
        await db
            .into(db.programWeeks)
            .insert(
              ProgramWeeksCompanion.insert(
                id: newWeekId,
                programVersionId: newVersionId,
                programBlockId: newBlockId,
                ordinalInBlock: week.ordinalInBlock,
                programWeekOrdinal: week.programWeekOrdinal,
                name: Value(week.name),
                isDeload: Value(week.isDeload),
              ),
            );
        for (final template in source.sessionTemplates.where(
          (row) => row.programWeekId == week.id,
        )) {
          final newTemplateId = uuid.v4();
          await db
              .into(db.sessionTemplates)
              .insert(
                SessionTemplatesCompanion.insert(
                  id: newTemplateId,
                  programWeekId: newWeekId,
                  ordinal: template.ordinal,
                  name: template.name,
                  plannedWeekday: template.plannedWeekday,
                  plannedStartMinute: Value(template.plannedStartMinute),
                  notes: Value(template.notes),
                  activityType: Value(template.activityType),
                  defaultRestSeconds: Value(template.defaultRestSeconds),
                ),
              );
          final prescriptionIdsBySourceId = <String, String>{};
          for (final prescription in source.exercisePrescriptions.where(
            (row) => row.sessionTemplateId == template.id,
          )) {
            final newPrescriptionId = uuid.v4();
            prescriptionIdsBySourceId[prescription.id] = newPrescriptionId;
            await db
                .into(db.exercisePrescriptions)
                .insert(
                  ExercisePrescriptionsCompanion.insert(
                    id: newPrescriptionId,
                    sessionTemplateId: newTemplateId,
                    ordinal: prescription.ordinal,
                    exerciseId: Value(prescription.exerciseId),
                    exerciseNameSnapshot: prescription.exerciseNameSnapshot,
                    plannedSets: prescription.plannedSets,
                    repsRange: prescription.repsRange,
                  ),
                );
          }
          for (final group in source.groups.where(
            (row) => row.sessionTemplateId == template.id,
          )) {
            final newGroupId = uuid.v4();
            await db
                .into(db.exerciseGroups)
                .insert(
                  ExerciseGroupsCompanion.insert(
                    id: newGroupId,
                    sessionTemplateId: newTemplateId,
                    ordinal: group.ordinal,
                    groupType: group.groupType,
                    roundCount: group.roundCount,
                    restAfterRoundSeconds: Value(group.restAfterRoundSeconds),
                    label: Value(group.label),
                  ),
                );
            for (final member in source.groupMembers.where(
              (row) => row.exerciseGroupId == group.id,
            )) {
              final newPrescriptionId =
                  prescriptionIdsBySourceId[member.exercisePrescriptionId];
              if (newPrescriptionId == null) {
                throw StateError(
                  'Group member ${member.id} has no copied prescription.',
                );
              }
              await db
                  .into(db.exerciseGroupMembers)
                  .insert(
                    ExerciseGroupMembersCompanion.insert(
                      id: uuid.v4(),
                      exerciseGroupId: newGroupId,
                      exercisePrescriptionId: newPrescriptionId,
                      ordinal: member.ordinal,
                      transitionRestSeconds: Value(
                        member.transitionRestSeconds,
                      ),
                    ),
                  );
            }
          }
        }
      }
    }
  }
}
