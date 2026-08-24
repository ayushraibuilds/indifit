import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import '../models/b02_group_plan_validator.dart';

/// An explicitly preserved unresolved exercise reference. New authoring must
/// select a stable exercise ID; this flag exists only for import/compatibility
/// flows that cannot safely resolve a legacy/custom name.
class ExercisePrescriptionInput {
  final String? id;
  final String? exerciseId;
  final String exerciseNameSnapshot;
  final int plannedSets;
  final String repsRange;
  final int ordinal;
  final bool allowUnresolvedExerciseFallback;

  const ExercisePrescriptionInput({
    this.id,
    this.exerciseId,
    required this.exerciseNameSnapshot,
    required this.plannedSets,
    required this.repsRange,
    required this.ordinal,
    this.allowUnresolvedExerciseFallback = false,
  });
}

class ExerciseGroupMemberInput {
  final String? id;
  final String exercisePrescriptionId;
  final int ordinal;
  final int? transitionRestSeconds;

  const ExerciseGroupMemberInput({
    this.id,
    required this.exercisePrescriptionId,
    required this.ordinal,
    this.transitionRestSeconds,
  });
}

class ExerciseGroupInput {
  final String? id;
  final int ordinal;
  final B02GroupType groupType;
  final int roundCount;
  final int? restAfterRoundSeconds;
  final String? label;
  final List<ExerciseGroupMemberInput> members;

  const ExerciseGroupInput({
    this.id,
    required this.ordinal,
    required this.groupType,
    required this.roundCount,
    this.restAfterRoundSeconds,
    this.label,
    required this.members,
  });
}

class SessionTemplateInput {
  final String name;
  final int ordinal;
  final int plannedWeekday;
  final int? plannedStartMinute;
  final String? notes;
  final List<ExercisePrescriptionInput> prescriptions;
  final List<ExerciseGroupInput> groups;

  const SessionTemplateInput({
    required this.name,
    required this.ordinal,
    required this.plannedWeekday,
    this.plannedStartMinute,
    this.notes,
    required this.prescriptions,
    this.groups = const [],
  });
}

class ProgramWeekInput {
  final String? name;
  final int ordinalInBlock;
  final int programWeekOrdinal;
  final bool isDeload;
  final List<SessionTemplateInput> templates;

  const ProgramWeekInput({
    this.name,
    required this.ordinalInBlock,
    required this.programWeekOrdinal,
    this.isDeload = false,
    required this.templates,
  });
}

class ProgramBlockInput {
  final String name;
  final String? description;
  final int ordinal;
  final List<ProgramWeekInput> weeks;

  const ProgramBlockInput({
    required this.name,
    this.description,
    required this.ordinal,
    required this.weeks,
  });
}

/// Complete, ordered, immutable read model for a version graph.
class ProgramDetailAggregate {
  final Program program;
  final ProgramVersion version;
  final List<ProgramBlock> blocks;
  final List<ProgramWeek> weeks;
  final List<SessionTemplate> sessionTemplates;
  final List<ExercisePrescription> exercisePrescriptions;
  final List<ExerciseGroup> groups;
  final List<ExerciseGroupMember> groupMembers;

  const ProgramDetailAggregate({
    required this.program,
    required this.version,
    required this.blocks,
    required this.weeks,
    required this.sessionTemplates,
    required this.exercisePrescriptions,
    this.groups = const [],
    this.groupMembers = const [],
  });
}

/// B01 authoring owner. It intentionally cannot activate or publish a
/// version: B01-06's activation coordinator owns that cross-aggregate
/// transaction together with occurrence materialisation.
class ProgramRepository {
  final AppDatabase db;
  final Uuid _uuid;

  ProgramRepository(this.db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  Future<List<Program>> getAllPrograms({bool includeArchived = false}) {
    final query = db.select(db.programs)
      ..orderBy([
        (t) =>
            OrderingTerm(expression: t.createdAtUtc, mode: OrderingMode.desc),
      ]);
    if (!includeArchived) {
      query.where((t) => t.archivedAtUtc.isNull());
    }
    return query.get();
  }

  Stream<List<Program>> watchAllPrograms({bool includeArchived = false}) {
    final query = db.select(db.programs)
      ..orderBy([
        (t) =>
            OrderingTerm(expression: t.createdAtUtc, mode: OrderingMode.desc),
      ]);
    if (!includeArchived) {
      query.where((t) => t.archivedAtUtc.isNull());
    }
    return query.watch();
  }

  /// Program identity metadata is user-owned but is deliberately separate
  /// from a version graph. Updating it cannot mutate a published version or a
  /// frozen execution snapshot.
  Future<void> updateProgramMetadata({
    required String programId,
    required String name,
    String? notes,
  }) async {
    _requireText(name, 'Program name');
    final changed =
        await (db.update(
          db.programs,
        )..where((table) => table.id.equals(programId))).write(
          ProgramsCompanion(
            name: Value(name.trim()),
            notes: Value(_nullableTrim(notes)),
          ),
        );
    if (changed != 1) {
      throw StateError('Program $programId is unavailable for editing.');
    }
  }

  Future<List<ProgramVersion>> getVersionsForProgram(String programId) {
    return (db.select(db.programVersions)
          ..where((t) => t.programId.equals(programId))
          ..orderBy([(t) => OrderingTerm(expression: t.versionNumber)]))
        .get();
  }

  Stream<List<ProgramVersion>> watchVersionsForProgram(String programId) {
    return (db.select(db.programVersions)
          ..where((t) => t.programId.equals(programId))
          ..orderBy([(t) => OrderingTerm(expression: t.versionNumber)]))
        .watch();
  }

  Future<ProgramDetailAggregate?> getProgramVersionDetail(String versionId) {
    return db.transaction(() => _readProgramVersionDetail(versionId));
  }

  /// Watches the full graph. Child-table subscriptions deliberately invalidate
  /// this aggregate, so a provider cannot retain a stale draft after an edit.
  Stream<ProgramDetailAggregate?> watchProgramVersionDetail(String versionId) {
    late StreamController<ProgramDetailAggregate?> controller;
    final subscriptions = <StreamSubscription<void>>[];
    var emitting = false;

    Future<void> emit() async {
      if (emitting || controller.isClosed) return;
      emitting = true;
      try {
        controller.add(await getProgramVersionDetail(versionId));
      } finally {
        emitting = false;
      }
    }

    controller = StreamController<ProgramDetailAggregate?>(
      onListen: () {
        final watches = <Stream<List<dynamic>>>[
          (db.select(
            db.programVersions,
          )..where((t) => t.id.equals(versionId))).watch(),
          (db.select(
            db.programBlocks,
          )..where((t) => t.programVersionId.equals(versionId))).watch(),
          (db.select(
            db.programWeeks,
          )..where((t) => t.programVersionId.equals(versionId))).watch(),
          db.select(db.sessionTemplates).watch(),
          db.select(db.exercisePrescriptions).watch(),
          db.select(db.exerciseGroups).watch(),
          db.select(db.exerciseGroupMembers).watch(),
        ];
        for (final watch in watches) {
          subscriptions.add(watch.map<void>((_) {}).listen((_) => emit()));
        }
        emit();
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// Creates a Program and its editable v1 draft. An empty graph is permitted
  /// while authoring, but all supplied graph content is validated before write.
  Future<String> createProgram({
    required String name,
    String? goal,
    String? notes,
    List<ProgramBlockInput> blocks = const [],
  }) async {
    _requireText(name, 'Program name');
    await _validateGraph(blocks);
    final now = DateTime.now().toUtc();
    final programId = _uuid.v4();
    final versionId = _uuid.v4();

    return db.transaction(() async {
      await db
          .into(db.programs)
          .insert(
            ProgramsCompanion.insert(
              id: programId,
              name: name.trim(),
              goal: Value(_nullableTrim(goal)),
              notes: Value(_nullableTrim(notes)),
              createdAtUtc: now,
            ),
          );
      await _insertDraftVersion(
        versionId: versionId,
        programId: programId,
        versionNumber: 1,
        createdAtUtc: now,
        blocks: blocks,
      );
      return programId;
    });
  }

  Future<String> createDraftVersion(
    String programId, {
    List<ProgramBlockInput> blocks = const [],
  }) async {
    await _validateGraph(blocks);
    final now = DateTime.now().toUtc();
    final versionId = _uuid.v4();

    return db.transaction(() async {
      final program = await (db.select(
        db.programs,
      )..where((t) => t.id.equals(programId))).getSingleOrNull();
      if (program == null || program.archivedAtUtc != null) {
        throw StateError('Program $programId is unavailable for new drafts.');
      }
      final versions = await getVersionsForProgram(programId);
      final nextNumber =
          versions.fold<int>(
            0,
            (max, version) =>
                version.versionNumber > max ? version.versionNumber : max,
          ) +
          1;
      await _insertDraftVersion(
        versionId: versionId,
        programId: programId,
        versionNumber: nextNumber,
        createdAtUtc: now,
        blocks: blocks,
      );
      return versionId;
    });
  }

  Future<void> updateDraftVersion(
    String versionId, {
    required List<ProgramBlockInput> blocks,
  }) async {
    await _validateGraph(blocks);
    await db.transaction(() async {
      await _requireDraft(versionId);
      await _deleteVersionGraph(versionId);
      await _insertVersionGraph(versionId, blocks);
    });
  }

  /// Saves the editable plan metadata and its ordered graph as one operation.
  ///
  /// The authoring surface uses this boundary so a graph-write failure cannot
  /// leave the plan name/notes updated while the structure is still old. The
  /// version guard and graph validation remain in this repository; callers do
  /// not get a second persistence or lifecycle authority.
  Future<void> saveDraft({
    required String versionId,
    required String name,
    String? notes,
    required List<ProgramBlockInput> blocks,
  }) async {
    _requireText(name, 'Program name');
    await _validateGraph(blocks);
    await db.transaction(() async {
      final version = await _requireDraft(versionId);
      await (db.update(
        db.programs,
      )..where((table) => table.id.equals(version.programId))).write(
        ProgramsCompanion(
          name: Value(name.trim()),
          notes: Value(_nullableTrim(notes)),
        ),
      );
      await _deleteVersionGraph(versionId);
      await _insertVersionGraph(versionId, blocks);
    });
  }

  /// Adds one explicit group to a draft session template. New groups append at
  /// the end; callers use [reorderExerciseGroups] for any other order.
  Future<String> createExerciseGroup(
    String sessionTemplateId,
    ExerciseGroupInput input,
  ) async {
    return db.transaction(() async {
      await _requireDraftTemplate(sessionTemplateId);
      final existing = await _readGroupRows(sessionTemplateId);
      if (input.ordinal != existing.groups.length) {
        throw ArgumentError(
          'A new exercise group must append at ordinal ${existing.groups.length}.',
        );
      }
      final groupId = input.id?.trim().isNotEmpty == true
          ? input.id!.trim()
          : _uuid.v4();
      final prescriptionIds = await _prescriptionIds(sessionTemplateId);
      final candidate = _groupInputAsDomain(input, groupId);
      B02GroupPlanValidator.validate(
        groups: [
          ..._groupRowsAsDomain(existing.groups, existing.members),
          candidate,
        ],
        prescriptionIds: prescriptionIds,
      );
      await _insertGroup(
        sessionTemplateId: sessionTemplateId,
        groupId: groupId,
        input: input,
      );
      return groupId;
    });
  }

  /// Replaces a group's editable fields and member slots while the parent
  /// version remains a draft. Published or started graphs are rejected.
  Future<void> updateExerciseGroup(
    String groupId,
    ExerciseGroupInput input,
  ) async {
    await db.transaction(() async {
      final current = await _requireDraftGroup(groupId);
      if (input.id != null && input.id!.trim() != groupId) {
        throw ArgumentError(
          'Exercise group ID cannot change during an update.',
        );
      }
      final existing = await _readGroupRows(current.template.id);
      final prescriptionIds = await _prescriptionIds(current.template.id);
      final candidate = _groupInputAsDomain(input, groupId);
      final groups = _groupRowsAsDomain(existing.groups, existing.members)
          .map((group) => group.id == groupId ? candidate : group)
          .toList(growable: false);
      B02GroupPlanValidator.validate(
        groups: groups,
        prescriptionIds: prescriptionIds,
      );
      await (db.update(
        db.exerciseGroups,
      )..where((t) => t.id.equals(groupId))).write(
        ExerciseGroupsCompanion(
          ordinal: Value(input.ordinal),
          groupType: Value(input.groupType.dbValue),
          roundCount: Value(input.roundCount),
          restAfterRoundSeconds: Value(input.restAfterRoundSeconds),
          label: Value(_nullableTrim(input.label)),
        ),
      );
      await (db.delete(
        db.exerciseGroupMembers,
      )..where((t) => t.exerciseGroupId.equals(groupId))).go();
      await _insertGroupMembers(groupId, input.members);
    });
  }

  /// Deletes a group and closes the ordinal gap in the same transaction.
  Future<void> deleteExerciseGroup(String groupId) async {
    await db.transaction(() async {
      final current = await _requireDraftGroup(groupId);
      await (db.delete(
        db.exerciseGroupMembers,
      )..where((t) => t.exerciseGroupId.equals(groupId))).go();
      await (db.delete(
        db.exerciseGroups,
      )..where((t) => t.id.equals(groupId))).go();
      final remaining =
          await (db.select(db.exerciseGroups)
                ..where((t) => t.sessionTemplateId.equals(current.template.id))
                ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
              .get();
      for (var index = 0; index < remaining.length; index++) {
        if (remaining[index].ordinal != index) {
          await (db.update(db.exerciseGroups)
                ..where((t) => t.id.equals(remaining[index].id)))
              .write(ExerciseGroupsCompanion(ordinal: Value(index)));
        }
      }
    });
  }

  /// Appends one member to a draft group after validating the complete plan.
  Future<String> addExerciseGroupMember(
    String groupId,
    ExerciseGroupMemberInput input,
  ) async {
    return db.transaction(() async {
      final current = await _requireDraftGroup(groupId);
      final existing = await _readGroupRows(current.template.id);
      final group = existing.groups.singleWhere((row) => row.id == groupId);
      final members = existing.members
          .where((row) => row.exerciseGroupId == groupId)
          .toList(growable: false);
      if (input.ordinal != members.length) {
        throw ArgumentError(
          'A new group member must append at ordinal ${members.length}.',
        );
      }
      final memberId = input.id?.trim().isNotEmpty == true
          ? input.id!.trim()
          : _uuid.v4();
      final prescriptionIds = await _prescriptionIds(current.template.id);
      final candidate = B02ExerciseGroup(
        id: group.id,
        ordinal: group.ordinal,
        groupType: B02GroupType.parse(group.groupType),
        roundCount: group.roundCount,
        restAfterRoundSeconds: group.restAfterRoundSeconds,
        label: group.label,
        members: [
          ...members.map(_memberRowAsDomain),
          B02ExerciseGroupMember(
            id: memberId,
            exercisePrescriptionId: input.exercisePrescriptionId,
            ordinal: input.ordinal,
            transitionRestSeconds: input.transitionRestSeconds,
          ),
        ],
      );
      final groups = _groupRowsAsDomain(existing.groups, existing.members)
          .map((row) => row.id == groupId ? candidate : row)
          .toList(growable: false);
      B02GroupPlanValidator.validate(
        groups: groups,
        prescriptionIds: prescriptionIds,
      );
      await _insertGroupMember(groupId, memberId, input);
      return memberId;
    });
  }

  Future<void> updateExerciseGroupMember(
    String memberId,
    ExerciseGroupMemberInput input,
  ) async {
    await db.transaction(() async {
      final current = await _requireDraftMember(memberId);
      final existing = await _readGroupRows(current.template.id);
      final group = existing.groups.singleWhere(
        (row) => row.id == current.member.exerciseGroupId,
      );
      final candidateMembers = existing.members
          .where((row) => row.exerciseGroupId == group.id)
          .map(
            (row) => row.id == memberId
                ? B02ExerciseGroupMember(
                    id: memberId,
                    exercisePrescriptionId: input.exercisePrescriptionId,
                    ordinal: input.ordinal,
                    transitionRestSeconds: input.transitionRestSeconds,
                  )
                : _memberRowAsDomain(row),
          )
          .toList(growable: false);
      final candidate = B02ExerciseGroup(
        id: group.id,
        ordinal: group.ordinal,
        groupType: B02GroupType.parse(group.groupType),
        roundCount: group.roundCount,
        restAfterRoundSeconds: group.restAfterRoundSeconds,
        label: group.label,
        members: candidateMembers,
      );
      final groups = _groupRowsAsDomain(existing.groups, existing.members)
          .map((row) => row.id == group.id ? candidate : row)
          .toList(growable: false);
      B02GroupPlanValidator.validate(
        groups: groups,
        prescriptionIds: await _prescriptionIds(current.template.id),
      );
      await (db.update(
        db.exerciseGroupMembers,
      )..where((t) => t.id.equals(memberId))).write(
        ExerciseGroupMembersCompanion(
          exercisePrescriptionId: Value(input.exercisePrescriptionId),
          ordinal: Value(input.ordinal),
          transitionRestSeconds: Value(input.transitionRestSeconds),
        ),
      );
    });
  }

  Future<void> deleteExerciseGroupMember(String memberId) async {
    await db.transaction(() async {
      final current = await _requireDraftMember(memberId);
      final existing = await _readGroupRows(current.template.id);
      final group = existing.groups.singleWhere(
        (row) => row.id == current.member.exerciseGroupId,
      );
      final remaining = existing.members
          .where((row) => row.exerciseGroupId == group.id && row.id != memberId)
          .toList(growable: false);
      final candidate = B02ExerciseGroup(
        id: group.id,
        ordinal: group.ordinal,
        groupType: B02GroupType.parse(group.groupType),
        roundCount: group.roundCount,
        restAfterRoundSeconds: group.restAfterRoundSeconds,
        label: group.label,
        members: remaining
            .asMap()
            .entries
            .map(
              (entry) => B02ExerciseGroupMember(
                id: entry.value.id,
                exercisePrescriptionId: entry.value.exercisePrescriptionId,
                ordinal: entry.key,
                transitionRestSeconds: entry.value.transitionRestSeconds,
              ),
            )
            .toList(growable: false),
      );
      final groups = _groupRowsAsDomain(existing.groups, existing.members)
          .map((row) => row.id == group.id ? candidate : row)
          .toList(growable: false);
      B02GroupPlanValidator.validate(
        groups: groups,
        prescriptionIds: await _prescriptionIds(current.template.id),
      );
      await (db.delete(
        db.exerciseGroupMembers,
      )..where((t) => t.id.equals(memberId))).go();
      for (var index = 0; index < remaining.length; index++) {
        await (db.update(db.exerciseGroupMembers)
              ..where((t) => t.id.equals(remaining[index].id)))
            .write(ExerciseGroupMembersCompanion(ordinal: Value(index)));
      }
    });
  }

  Future<void> reorderExerciseGroups(
    String sessionTemplateId,
    List<String> orderedGroupIds,
  ) async {
    await db.transaction(() async {
      await _requireDraftTemplate(sessionTemplateId);
      final groups = await (db.select(
        db.exerciseGroups,
      )..where((t) => t.sessionTemplateId.equals(sessionTemplateId))).get();
      _requireExactOrder(
        groups.map((group) => group.id).toSet(),
        orderedGroupIds,
        'group',
      );
      // The unique (template, ordinal) key makes an in-place swap unsafe.
      // Move the rows to a valid, non-overlapping ordinal range first, then
      // assign the requested contiguous order in this same transaction.
      for (var index = 0; index < orderedGroupIds.length; index++) {
        await (db.update(
          db.exerciseGroups,
        )..where((t) => t.id.equals(orderedGroupIds[index]))).write(
          ExerciseGroupsCompanion(
            ordinal: Value(orderedGroupIds.length + index),
          ),
        );
      }
      for (var index = 0; index < orderedGroupIds.length; index++) {
        await (db.update(db.exerciseGroups)
              ..where((t) => t.id.equals(orderedGroupIds[index])))
            .write(ExerciseGroupsCompanion(ordinal: Value(index)));
      }
    });
  }

  Future<void> reorderExerciseGroupMembers(
    String groupId,
    List<String> orderedMemberIds,
  ) async {
    await db.transaction(() async {
      final current = await _requireDraftGroup(groupId);
      final members = await (db.select(
        db.exerciseGroupMembers,
      )..where((t) => t.exerciseGroupId.equals(groupId))).get();
      _requireExactOrder(
        members.map((member) => member.id).toSet(),
        orderedMemberIds,
        'group member',
      );
      for (var index = 0; index < orderedMemberIds.length; index++) {
        await (db.update(
          db.exerciseGroupMembers,
        )..where((t) => t.id.equals(orderedMemberIds[index]))).write(
          ExerciseGroupMembersCompanion(
            ordinal: Value(orderedMemberIds.length + index),
          ),
        );
      }
      for (var index = 0; index < orderedMemberIds.length; index++) {
        await (db.update(db.exerciseGroupMembers)
              ..where((t) => t.id.equals(orderedMemberIds[index])))
            .write(ExerciseGroupMembersCompanion(ordinal: Value(index)));
      }
      // Keep the parent read in this method so a deleted/reparented group
      // cannot be reordered through a stale member list.
      if (current.group.id != groupId) {
        throw StateError('Exercise group ancestry changed during reorder.');
      }
    });
  }

  /// Copies a historical structure into a new, editable draft. The source
  /// remains untouched regardless of lifecycle state.
  Future<String> copyToNewDraftVersion(String sourceVersionId) async {
    final source = await getProgramVersionDetail(sourceVersionId);
    if (source == null) {
      throw StateError('Source version $sourceVersionId not found.');
    }
    final now = DateTime.now().toUtc();
    final newVersionId = _uuid.v4();

    return db.transaction(() async {
      final versions = await getVersionsForProgram(source.program.id);
      final nextNumber =
          versions.fold<int>(
            0,
            (max, version) =>
                version.versionNumber > max ? version.versionNumber : max,
          ) +
          1;
      await db
          .into(db.programVersions)
          .insert(
            ProgramVersionsCompanion.insert(
              id: newVersionId,
              programId: source.program.id,
              versionNumber: nextNumber,
              status: 'draft',
              origin: const Value('user'),
              sourceVersionId: Value(sourceVersionId),
              createdAtUtc: now,
            ),
          );
      await _copyGraph(source, newVersionId);
      return newVersionId;
    });
  }

  Future<void> archiveVersion(String versionId) async {
    await db.transaction(() async {
      final version = await _requireVersion(versionId);
      if (version.status == 'archived') return;
      await _rejectActiveVersion(versionId);
      await (db.update(
        db.programVersions,
      )..where((t) => t.id.equals(versionId))).write(
        ProgramVersionsCompanion(
          status: const Value('archived'),
          archivedAtUtc: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }

  /// Hard deletion is restricted to unreferenced, never-published drafts.
  Future<void> deleteDraftVersion(String versionId) async {
    await db.transaction(() async {
      final version = await _requireDraft(versionId);
      await _rejectActiveVersion(versionId);
      final occurrence = await (db.select(
        db.scheduledSessionOccurrences,
      )..where((t) => t.programVersionId.equals(versionId))).getSingleOrNull();
      final legacyMapping = await (db.select(
        db.legacyRoutineProgramMappings,
      )..where((t) => t.programVersionId.equals(versionId))).getSingleOrNull();
      if (occurrence != null || legacyMapping != null) {
        throw StateError('Referenced draft $versionId cannot be deleted.');
      }
      await _deleteVersionGraph(version.id);
      await (db.delete(
        db.programVersions,
      )..where((t) => t.id.equals(versionId))).go();
    });
  }

  Future<void> archiveProgram(String programId) async {
    await db.transaction(() async {
      final program = await (db.select(
        db.programs,
      )..where((t) => t.id.equals(programId))).getSingleOrNull();
      if (program == null) throw StateError('Program $programId not found.');
      if (program.archivedAtUtc != null) return;
      final versions = await getVersionsForProgram(programId);
      for (final version in versions) {
        await _rejectActiveVersion(version.id);
      }
      await (db.update(
        db.programs,
      )..where((t) => t.id.equals(programId))).write(
        ProgramsCompanion(archivedAtUtc: Value(DateTime.now().toUtc())),
      );
    });
  }

  Future<void> deleteProgramIfDraftOnly(String programId) async {
    await db.transaction(() async {
      final versions = await getVersionsForProgram(programId);
      if (versions.isEmpty) throw StateError('Program $programId not found.');
      if (versions.any((version) => version.status != 'draft')) {
        throw StateError('Only draft-only programs can be deleted.');
      }
      for (final version in versions) {
        await _rejectActiveVersion(version.id);
        final occurrence =
            await (db.select(db.scheduledSessionOccurrences)
                  ..where((t) => t.programVersionId.equals(version.id)))
                .getSingleOrNull();
        if (occurrence != null) {
          throw StateError('Referenced program $programId cannot be deleted.');
        }
        await _deleteVersionGraph(version.id);
      }
      await (db.delete(
        db.programVersions,
      )..where((t) => t.programId.equals(programId))).go();
      await (db.delete(db.programs)..where((t) => t.id.equals(programId))).go();
    });
  }

  Future<ProgramDetailAggregate?> _readProgramVersionDetail(
    String versionId,
  ) async {
    final version = await (db.select(
      db.programVersions,
    )..where((t) => t.id.equals(versionId))).getSingleOrNull();
    if (version == null) return null;
    final program = await (db.select(
      db.programs,
    )..where((t) => t.id.equals(version.programId))).getSingle();
    final blocks =
        await (db.select(db.programBlocks)
              ..where((t) => t.programVersionId.equals(versionId))
              ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
            .get();
    final weeks =
        await (db.select(db.programWeeks)
              ..where((t) => t.programVersionId.equals(versionId))
              ..orderBy([
                (t) => OrderingTerm(expression: t.programWeekOrdinal),
              ]))
            .get();
    final weekIds = weeks.map((row) => row.id).toList();
    final templates = weekIds.isEmpty
        ? <SessionTemplate>[]
        : await (db.select(db.sessionTemplates)
                ..where((t) => t.programWeekId.isIn(weekIds))
                ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
              .get();
    final templateIds = templates.map((row) => row.id).toList();
    final prescriptions = templateIds.isEmpty
        ? <ExercisePrescription>[]
        : await (db.select(db.exercisePrescriptions)
                ..where((t) => t.sessionTemplateId.isIn(templateIds))
                ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
              .get();
    final groups = templateIds.isEmpty
        ? <ExerciseGroup>[]
        : await (db.select(db.exerciseGroups)
                ..where((t) => t.sessionTemplateId.isIn(templateIds))
                ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
              .get();
    final groupIds = groups.map((group) => group.id).toList();
    final groupMembers = groupIds.isEmpty
        ? <ExerciseGroupMember>[]
        : await (db.select(db.exerciseGroupMembers)
                ..where((t) => t.exerciseGroupId.isIn(groupIds))
                ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
              .get();
    return ProgramDetailAggregate(
      program: program,
      version: version,
      blocks: blocks,
      weeks: weeks,
      sessionTemplates: templates,
      exercisePrescriptions: prescriptions,
      groups: groups,
      groupMembers: groupMembers,
    );
  }

  Future<void> _insertDraftVersion({
    required String versionId,
    required String programId,
    required int versionNumber,
    required DateTime createdAtUtc,
    required List<ProgramBlockInput> blocks,
  }) async {
    await db
        .into(db.programVersions)
        .insert(
          ProgramVersionsCompanion.insert(
            id: versionId,
            programId: programId,
            versionNumber: versionNumber,
            status: 'draft',
            origin: const Value('user'),
            createdAtUtc: createdAtUtc,
          ),
        );
    await _insertVersionGraph(versionId, blocks);
  }

  Future<void> _insertVersionGraph(
    String versionId,
    List<ProgramBlockInput> blocks,
  ) async {
    for (final block in blocks) {
      final blockId = _uuid.v4();
      await db
          .into(db.programBlocks)
          .insert(
            ProgramBlocksCompanion.insert(
              id: blockId,
              programVersionId: versionId,
              ordinal: block.ordinal,
              name: block.name.trim(),
              description: Value(_nullableTrim(block.description)),
            ),
          );
      for (final week in block.weeks) {
        final weekId = _uuid.v4();
        await db
            .into(db.programWeeks)
            .insert(
              ProgramWeeksCompanion.insert(
                id: weekId,
                programVersionId: versionId,
                programBlockId: blockId,
                ordinalInBlock: week.ordinalInBlock,
                programWeekOrdinal: week.programWeekOrdinal,
                name: Value(_nullableTrim(week.name)),
                isDeload: Value(week.isDeload),
              ),
            );
        for (final template in week.templates) {
          final templateId = _uuid.v4();
          await db
              .into(db.sessionTemplates)
              .insert(
                SessionTemplatesCompanion.insert(
                  id: templateId,
                  programWeekId: weekId,
                  ordinal: template.ordinal,
                  name: template.name.trim(),
                  plannedWeekday: template.plannedWeekday,
                  plannedStartMinute: Value(template.plannedStartMinute),
                  notes: Value(_nullableTrim(template.notes)),
                ),
              );
          final prescriptionIdsByInputId = <String, String>{};
          for (final prescription in template.prescriptions) {
            final prescriptionId = prescription.id?.trim().isNotEmpty == true
                ? prescription.id!.trim()
                : _uuid.v4();
            if (prescription.id != null) {
              prescriptionIdsByInputId[prescription.id!.trim()] =
                  prescriptionId;
            }
            await db
                .into(db.exercisePrescriptions)
                .insert(
                  ExercisePrescriptionsCompanion.insert(
                    id: prescriptionId,
                    sessionTemplateId: templateId,
                    ordinal: prescription.ordinal,
                    exerciseId: Value(prescription.exerciseId),
                    exerciseNameSnapshot: prescription.exerciseNameSnapshot
                        .trim(),
                    plannedSets: prescription.plannedSets,
                    repsRange: prescription.repsRange.trim(),
                  ),
                );
          }
          for (final group in template.groups) {
            final groupId = group.id?.trim().isNotEmpty == true
                ? group.id!.trim()
                : _uuid.v4();
            await db
                .into(db.exerciseGroups)
                .insert(
                  ExerciseGroupsCompanion.insert(
                    id: groupId,
                    sessionTemplateId: templateId,
                    ordinal: group.ordinal,
                    groupType: group.groupType.dbValue,
                    roundCount: group.roundCount,
                    restAfterRoundSeconds: Value(group.restAfterRoundSeconds),
                    label: Value(_nullableTrim(group.label)),
                  ),
                );
            for (final member in group.members) {
              final prescriptionId =
                  prescriptionIdsByInputId[member.exercisePrescriptionId];
              if (prescriptionId == null) {
                throw StateError(
                  'Group member ${member.exercisePrescriptionId} was not found in the inserted template.',
                );
              }
              await db
                  .into(db.exerciseGroupMembers)
                  .insert(
                    ExerciseGroupMembersCompanion.insert(
                      id: member.id?.trim().isNotEmpty == true
                          ? member.id!.trim()
                          : _uuid.v4(),
                      exerciseGroupId: groupId,
                      exercisePrescriptionId: prescriptionId,
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

  Future<void> _copyGraph(
    ProgramDetailAggregate source,
    String newVersionId,
  ) async {
    for (final block in source.blocks) {
      final newBlockId = _uuid.v4();
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
        final newWeekId = _uuid.v4();
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
          final newTemplateId = _uuid.v4();
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
            final newPrescriptionId = _uuid.v4();
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
            final newGroupId = _uuid.v4();
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
                      id: _uuid.v4(),
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

  Future<SessionTemplate> _requireDraftTemplate(String templateId) async {
    final template = await (db.select(
      db.sessionTemplates,
    )..where((t) => t.id.equals(templateId))).getSingleOrNull();
    if (template == null) {
      throw StateError('Session template $templateId not found.');
    }
    final week = await (db.select(
      db.programWeeks,
    )..where((t) => t.id.equals(template.programWeekId))).getSingleOrNull();
    if (week == null) {
      throw StateError('Session template $templateId has no program week.');
    }
    await _requireDraft(week.programVersionId);
    return template;
  }

  Future<({ExerciseGroup group, SessionTemplate template})> _requireDraftGroup(
    String groupId,
  ) async {
    final group = await (db.select(
      db.exerciseGroups,
    )..where((t) => t.id.equals(groupId))).getSingleOrNull();
    if (group == null) {
      throw StateError('Exercise group $groupId not found.');
    }
    final template = await _requireDraftTemplate(group.sessionTemplateId);
    return (group: group, template: template);
  }

  Future<({ExerciseGroupMember member, SessionTemplate template})>
  _requireDraftMember(String memberId) async {
    final member = await (db.select(
      db.exerciseGroupMembers,
    )..where((t) => t.id.equals(memberId))).getSingleOrNull();
    if (member == null) {
      throw StateError('Exercise group member $memberId not found.');
    }
    final group = await (db.select(
      db.exerciseGroups,
    )..where((t) => t.id.equals(member.exerciseGroupId))).getSingleOrNull();
    if (group == null) {
      throw StateError('Exercise group member $memberId has no group.');
    }
    final template = await _requireDraftTemplate(group.sessionTemplateId);
    return (member: member, template: template);
  }

  Future<({List<ExerciseGroup> groups, List<ExerciseGroupMember> members})>
  _readGroupRows(String sessionTemplateId) async {
    final groups =
        await (db.select(db.exerciseGroups)
              ..where((t) => t.sessionTemplateId.equals(sessionTemplateId))
              ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
            .get();
    final groupIds = groups.map((group) => group.id).toList();
    final members = groupIds.isEmpty
        ? <ExerciseGroupMember>[]
        : await (db.select(db.exerciseGroupMembers)
                ..where((t) => t.exerciseGroupId.isIn(groupIds))
                ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
              .get();
    return (groups: groups, members: members);
  }

  Future<Set<String>> _prescriptionIds(String sessionTemplateId) async {
    final prescriptions = await (db.select(
      db.exercisePrescriptions,
    )..where((t) => t.sessionTemplateId.equals(sessionTemplateId))).get();
    return prescriptions.map((prescription) => prescription.id).toSet();
  }

  Future<void> _insertGroup({
    required String sessionTemplateId,
    required String groupId,
    required ExerciseGroupInput input,
  }) async {
    await db
        .into(db.exerciseGroups)
        .insert(
          ExerciseGroupsCompanion.insert(
            id: groupId,
            sessionTemplateId: sessionTemplateId,
            ordinal: input.ordinal,
            groupType: input.groupType.dbValue,
            roundCount: input.roundCount,
            restAfterRoundSeconds: Value(input.restAfterRoundSeconds),
            label: Value(_nullableTrim(input.label)),
          ),
        );
    await _insertGroupMembers(groupId, input.members);
  }

  Future<void> _insertGroupMembers(
    String groupId,
    Iterable<ExerciseGroupMemberInput> members,
  ) async {
    for (final member in members) {
      await _insertGroupMember(
        groupId,
        member.id?.trim().isNotEmpty == true ? member.id!.trim() : _uuid.v4(),
        member,
      );
    }
  }

  Future<void> _insertGroupMember(
    String groupId,
    String memberId,
    ExerciseGroupMemberInput input,
  ) {
    return db
        .into(db.exerciseGroupMembers)
        .insert(
          ExerciseGroupMembersCompanion.insert(
            id: memberId,
            exerciseGroupId: groupId,
            exercisePrescriptionId: input.exercisePrescriptionId,
            ordinal: input.ordinal,
            transitionRestSeconds: Value(input.transitionRestSeconds),
          ),
        );
  }

  B02ExerciseGroup _groupInputAsDomain(
    ExerciseGroupInput input,
    String groupId,
  ) {
    return B02ExerciseGroup(
      id: groupId,
      ordinal: input.ordinal,
      groupType: input.groupType,
      roundCount: input.roundCount,
      restAfterRoundSeconds: input.restAfterRoundSeconds,
      label: input.label,
      members: input.members
          .asMap()
          .entries
          .map(
            (entry) => B02ExerciseGroupMember(
              id: entry.value.id?.trim().isNotEmpty == true
                  ? entry.value.id!.trim()
                  : '$groupId/member/${entry.key}',
              exercisePrescriptionId: entry.value.exercisePrescriptionId,
              ordinal: entry.value.ordinal,
              transitionRestSeconds: entry.value.transitionRestSeconds,
            ),
          )
          .toList(growable: false),
    );
  }

  List<B02ExerciseGroup> _groupRowsAsDomain(
    Iterable<ExerciseGroup> groups,
    Iterable<ExerciseGroupMember> members,
  ) {
    return groups
        .map(
          (group) => B02ExerciseGroup(
            id: group.id,
            sessionTemplateId: group.sessionTemplateId,
            ordinal: group.ordinal,
            groupType: B02GroupType.parse(group.groupType),
            roundCount: group.roundCount,
            restAfterRoundSeconds: group.restAfterRoundSeconds,
            label: group.label,
            members: members
                .where((member) => member.exerciseGroupId == group.id)
                .map(_memberRowAsDomain)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  static B02ExerciseGroupMember _memberRowAsDomain(ExerciseGroupMember member) {
    return B02ExerciseGroupMember(
      id: member.id,
      exercisePrescriptionId: member.exercisePrescriptionId,
      ordinal: member.ordinal,
      transitionRestSeconds: member.transitionRestSeconds,
    );
  }

  static void _requireExactOrder(
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

  Future<void> _deleteVersionGraph(String versionId) async {
    final weeks = await (db.select(
      db.programWeeks,
    )..where((t) => t.programVersionId.equals(versionId))).get();
    final weekIds = weeks.map((row) => row.id).toList();
    if (weekIds.isNotEmpty) {
      final templates = await (db.select(
        db.sessionTemplates,
      )..where((t) => t.programWeekId.isIn(weekIds))).get();
      final templateIds = templates.map((row) => row.id).toList();
      if (templateIds.isNotEmpty) {
        final groups = await (db.select(
          db.exerciseGroups,
        )..where((t) => t.sessionTemplateId.isIn(templateIds))).get();
        final groupIds = groups.map((group) => group.id).toList();
        if (groupIds.isNotEmpty) {
          await (db.delete(
            db.exerciseGroupMembers,
          )..where((t) => t.exerciseGroupId.isIn(groupIds))).go();
          await (db.delete(
            db.exerciseGroups,
          )..where((t) => t.id.isIn(groupIds))).go();
        }
        await (db.delete(
          db.exercisePrescriptions,
        )..where((t) => t.sessionTemplateId.isIn(templateIds))).go();
        await (db.delete(
          db.sessionTemplates,
        )..where((t) => t.programWeekId.isIn(weekIds))).go();
      }
      await (db.delete(
        db.programWeeks,
      )..where((t) => t.programVersionId.equals(versionId))).go();
    }
    await (db.delete(
      db.programBlocks,
    )..where((t) => t.programVersionId.equals(versionId))).go();
  }

  Future<ProgramVersion> _requireVersion(String versionId) async {
    final version = await (db.select(
      db.programVersions,
    )..where((t) => t.id.equals(versionId))).getSingleOrNull();
    if (version == null) {
      throw StateError('Program version $versionId not found.');
    }
    return version;
  }

  Future<ProgramVersion> _requireDraft(String versionId) async {
    final version = await _requireVersion(versionId);
    if (version.status != 'draft') {
      throw StateError('Only draft versions are editable or deletable.');
    }
    return version;
  }

  Future<void> _rejectActiveVersion(String versionId) async {
    final settings = await (db.select(
      db.trainingPlanSettings,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (settings?.activeProgramVersionId == versionId) {
      throw StateError(
        'The active program version must be replaced or cleared first.',
      );
    }
  }

  Future<void> _validateGraph(List<ProgramBlockInput> blocks) async {
    _validateOrdinals('block', blocks.map((block) => block.ordinal));
    var expectedProgramWeekOrdinal = 0;
    final exerciseIds = <String>{};
    final prescriptionRowIds = <String>{};
    final groupRowIds = <String>{};
    final groupMemberRowIds = <String>{};
    for (final block in blocks) {
      _requireText(block.name, 'Block name');
      _validateOrdinals(
        'week in block ${block.ordinal}',
        block.weeks.map((week) => week.ordinalInBlock),
      );
      for (final week in block.weeks) {
        if (week.programWeekOrdinal != expectedProgramWeekOrdinal++) {
          throw ArgumentError(
            'Program week ordinals must be contiguous from zero.',
          );
        }
        _validateOrdinals(
          'template in week ${week.programWeekOrdinal}',
          week.templates.map((template) => template.ordinal),
        );
        for (final template in week.templates) {
          _requireText(template.name, 'Session template name');
          if (template.plannedWeekday < 1 || template.plannedWeekday > 7) {
            throw ArgumentError('Planned weekday must be between 1 and 7.');
          }
          final minute = template.plannedStartMinute;
          if (minute != null && (minute < 0 || minute > 1439)) {
            throw ArgumentError(
              'Planned start minute must be between 0 and 1439.',
            );
          }
          _validateOrdinals(
            'prescription in template ${template.ordinal}',
            template.prescriptions.map((p) => p.ordinal),
          );
          final templatePrescriptionIds = <String>{};
          for (final prescription in template.prescriptions) {
            final prescriptionRowId = prescription.id;
            if (prescriptionRowId != null) {
              _requireText(prescriptionRowId, 'Exercise prescription ID');
              if (!prescriptionRowIds.add(prescriptionRowId.trim()) ||
                  !templatePrescriptionIds.add(prescriptionRowId.trim())) {
                throw ArgumentError(
                  'Exercise prescription IDs must be unique in a program graph.',
                );
              }
            }
            _requireText(
              prescription.exerciseNameSnapshot,
              'Exercise name snapshot',
            );
            _requireText(prescription.repsRange, 'Reps range');
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

  static void _validateOrdinals(String label, Iterable<int> ordinals) {
    final values = ordinals.toList()..sort();
    for (var index = 0; index < values.length; index++) {
      if (values[index] != index) {
        throw ArgumentError('$label ordinals must be contiguous from zero.');
      }
    }
  }

  static void _requireText(String value, String label) {
    if (value.trim().isEmpty) throw ArgumentError('$label must not be blank.');
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
