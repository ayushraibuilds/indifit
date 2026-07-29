import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

/// Inputs for constructing or updating program blocks, weeks, templates, and prescriptions.
class ExercisePrescriptionInput {
  final String? exerciseId;
  final String exerciseNameSnapshot;
  final int plannedSets;
  final String repsRange;
  final int ordinal;

  const ExercisePrescriptionInput({
    this.exerciseId,
    required this.exerciseNameSnapshot,
    required this.plannedSets,
    required this.repsRange,
    required this.ordinal,
  });
}

class SessionTemplateInput {
  final String name;
  final int ordinal;
  final int plannedWeekday;
  final int? plannedStartMinute;
  final String? notes;
  final List<ExercisePrescriptionInput> prescriptions;

  const SessionTemplateInput({
    required this.name,
    required this.ordinal,
    required this.plannedWeekday,
    this.plannedStartMinute,
    this.notes,
    required this.prescriptions,
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

/// Rich read model representing a complete training program version graph.
class ProgramDetailAggregate {
  final Program program;
  final ProgramVersion version;
  final List<ProgramBlock> blocks;
  final List<ProgramWeek> weeks;
  final List<SessionTemplate> sessionTemplates;
  final List<ExercisePrescription> exercisePrescriptions;

  const ProgramDetailAggregate({
    required this.program,
    required this.version,
    required this.blocks,
    required this.weeks,
    required this.sessionTemplates,
    required this.exercisePrescriptions,
  });
}

/// Durable repository for training program authoring, version copying, and lifecycle state management.
class ProgramRepository {
  final AppDatabase db;
  final Uuid _uuid;

  ProgramRepository(this.db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  /// Returns all program headers ordered by creation date descending.
  Future<List<Program>> getAllPrograms() async {
    return (db.select(db.programs)..orderBy([
          (t) =>
              OrderingTerm(expression: t.createdAtUtc, mode: OrderingMode.desc),
        ]))
        .get();
  }

  /// Returns all versions for a given program ordered by version number ascending.
  Future<List<ProgramVersion>> getVersionsForProgram(String programId) async {
    return (db.select(db.programVersions)
          ..where((t) => t.programId.equals(programId))
          ..orderBy([(t) => OrderingTerm(expression: t.versionNumber)]))
        .get();
  }

  /// Fetches a complete immutable program version aggregate tree.
  Future<ProgramDetailAggregate?> getProgramVersionDetail(
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

    final weekIds = weeks.map((w) => w.id).toList();

    final templates = weekIds.isEmpty
        ? <SessionTemplate>[]
        : await (db.select(db.sessionTemplates)
                ..where((t) => t.programWeekId.isIn(weekIds))
                ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
              .get();

    final templateIds = templates.map((t) => t.id).toList();

    final prescriptions = templateIds.isEmpty
        ? <ExercisePrescription>[]
        : await (db.select(db.exercisePrescriptions)
                ..where((t) => t.sessionTemplateId.isIn(templateIds))
                ..orderBy([(t) => OrderingTerm(expression: t.ordinal)]))
              .get();

    return ProgramDetailAggregate(
      program: program,
      version: version,
      blocks: blocks,
      weeks: weeks,
      sessionTemplates: templates,
      exercisePrescriptions: prescriptions,
    );
  }

  /// Creates a new program header along with an initial draft v1 version.
  Future<String> createProgram({
    required String name,
    String? goal,
    String? notes,
    List<ProgramBlockInput>? blocks,
  }) async {
    final now = DateTime.now().toUtc();
    final programId = _uuid.v4();
    final versionId = _uuid.v4();

    return db.transaction(() async {
      await db
          .into(db.programs)
          .insert(
            ProgramsCompanion.insert(
              id: programId,
              name: name,
              goal: Value(goal),
              notes: Value(notes),
              createdAtUtc: now,
            ),
          );

      await db
          .into(db.programVersions)
          .insert(
            ProgramVersionsCompanion.insert(
              id: versionId,
              programId: programId,
              versionNumber: 1,
              status: 'draft',
              origin: const Value('user'),
              createdAtUtc: now,
            ),
          );

      if (blocks != null && blocks.isNotEmpty) {
        await _insertVersionGraph(versionId, blocks);
      }

      return programId;
    });
  }

  /// Creates a new draft version under an existing program.
  Future<String> createDraftVersion(
    String programId, {
    List<ProgramBlockInput>? blocks,
  }) async {
    final existingVersions = await getVersionsForProgram(programId);
    final maxVersion = existingVersions.fold<int>(
      0,
      (prev, v) => v.versionNumber > prev ? v.versionNumber : prev,
    );
    final newVersionNumber = maxVersion + 1;
    final now = DateTime.now().toUtc();
    final versionId = _uuid.v4();

    return db.transaction(() async {
      await db
          .into(db.programVersions)
          .insert(
            ProgramVersionsCompanion.insert(
              id: versionId,
              programId: programId,
              versionNumber: newVersionNumber,
              status: 'draft',
              origin: const Value('user'),
              createdAtUtc: now,
            ),
          );

      if (blocks != null && blocks.isNotEmpty) {
        await _insertVersionGraph(versionId, blocks);
      }

      return versionId;
    });
  }

  /// Updates a draft version graph. Throws StateError if version is published or archived.
  Future<void> updateDraftVersion(
    String versionId, {
    List<ProgramBlockInput>? blocks,
  }) async {
    final version = await (db.select(
      db.programVersions,
    )..where((t) => t.id.equals(versionId))).getSingleOrNull();
    if (version == null) {
      throw StateError('Program version $versionId not found.');
    }
    if (version.status != 'draft') {
      throw StateError(
        'Cannot edit version $versionId with status "${version.status}". Only draft versions are editable.',
      );
    }

    return db.transaction(() async {
      await _deleteVersionGraph(versionId);
      if (blocks != null && blocks.isNotEmpty) {
        await _insertVersionGraph(versionId, blocks);
      }
    });
  }

  /// Copies any version (draft, published, or archived) into a new draft version.
  Future<String> copyToNewDraftVersion(String sourceVersionId) async {
    final sourceDetail = await getProgramVersionDetail(sourceVersionId);
    if (sourceDetail == null) {
      throw StateError('Source version $sourceVersionId not found.');
    }

    final existingVersions = await getVersionsForProgram(
      sourceDetail.program.id,
    );
    final maxVersion = existingVersions.fold<int>(
      0,
      (prev, v) => v.versionNumber > prev ? v.versionNumber : prev,
    );
    final newVersionNumber = maxVersion + 1;
    final now = DateTime.now().toUtc();
    final newVersionId = _uuid.v4();

    return db.transaction(() async {
      await db
          .into(db.programVersions)
          .insert(
            ProgramVersionsCompanion.insert(
              id: newVersionId,
              programId: sourceDetail.program.id,
              versionNumber: newVersionNumber,
              status: 'draft',
              origin: const Value('user'),
              sourceVersionId: Value(sourceVersionId),
              createdAtUtc: now,
            ),
          );

      // Reconstruct graph inputs from source aggregate
      for (final block in sourceDetail.blocks) {
        final blockId = _uuid.v4();
        await db
            .into(db.programBlocks)
            .insert(
              ProgramBlocksCompanion.insert(
                id: blockId,
                programVersionId: newVersionId,
                ordinal: block.ordinal,
                name: block.name,
                description: Value(block.description),
              ),
            );

        final blockWeeks = sourceDetail.weeks
            .where((w) => w.programBlockId == block.id)
            .toList();
        for (final week in blockWeeks) {
          final weekId = _uuid.v4();
          await db
              .into(db.programWeeks)
              .insert(
                ProgramWeeksCompanion.insert(
                  id: weekId,
                  programVersionId: newVersionId,
                  programBlockId: blockId,
                  ordinalInBlock: week.ordinalInBlock,
                  programWeekOrdinal: week.programWeekOrdinal,
                  name: Value(week.name),
                  isDeload: Value(week.isDeload),
                ),
              );

          final weekTemplates = sourceDetail.sessionTemplates
              .where((t) => t.programWeekId == week.id)
              .toList();
          for (final template in weekTemplates) {
            final templateId = _uuid.v4();
            await db
                .into(db.sessionTemplates)
                .insert(
                  SessionTemplatesCompanion.insert(
                    id: templateId,
                    programWeekId: weekId,
                    ordinal: template.ordinal,
                    name: template.name,
                    plannedWeekday: template.plannedWeekday,
                    plannedStartMinute: Value(template.plannedStartMinute),
                    notes: Value(template.notes),
                  ),
                );

            final templatePrescriptions = sourceDetail.exercisePrescriptions
                .where((p) => p.sessionTemplateId == template.id)
                .toList();
            for (final p in templatePrescriptions) {
              await db
                  .into(db.exercisePrescriptions)
                  .insert(
                    ExercisePrescriptionsCompanion.insert(
                      id: _uuid.v4(),
                      sessionTemplateId: templateId,
                      ordinal: p.ordinal,
                      exerciseId: Value(p.exerciseId),
                      exerciseNameSnapshot: p.exerciseNameSnapshot,
                      plannedSets: p.plannedSets,
                      repsRange: p.repsRange,
                    ),
                  );
            }
          }
        }
      }

      return newVersionId;
    });
  }

  /// Publishes a draft version. Sets publishedAtUtc timestamp.
  Future<void> publishVersion(String versionId) async {
    final version = await (db.select(
      db.programVersions,
    )..where((t) => t.id.equals(versionId))).getSingleOrNull();
    if (version == null) throw StateError('Version $versionId not found.');

    final now = DateTime.now().toUtc();
    await (db.update(
      db.programVersions,
    )..where((t) => t.id.equals(versionId))).write(
      ProgramVersionsCompanion(
        status: const Value('published'),
        publishedAtUtc: Value(now),
      ),
    );
  }

  /// Archives a program version.
  Future<void> archiveVersion(String versionId) async {
    final version = await (db.select(
      db.programVersions,
    )..where((t) => t.id.equals(versionId))).getSingleOrNull();
    if (version == null) throw StateError('Version $versionId not found.');

    final now = DateTime.now().toUtc();
    await (db.update(
      db.programVersions,
    )..where((t) => t.id.equals(versionId))).write(
      ProgramVersionsCompanion(
        status: const Value('archived'),
        archivedAtUtc: Value(now),
      ),
    );
  }

  /// Deletes a draft version and its child records.
  Future<void> deleteDraftVersion(String versionId) async {
    final version = await (db.select(
      db.programVersions,
    )..where((t) => t.id.equals(versionId))).getSingleOrNull();
    if (version == null) throw StateError('Version $versionId not found.');
    if (version.status != 'draft') {
      throw StateError(
        'Cannot delete non-draft version with status "${version.status}".',
      );
    }

    return db.transaction(() async {
      await _deleteVersionGraph(versionId);
      await (db.delete(
        db.programVersions,
      )..where((t) => t.id.equals(versionId))).go();
    });
  }

  // --- Helper Methods ---

  Future<void> _insertVersionGraph(
    String versionId,
    List<ProgramBlockInput> blocks,
  ) async {
    for (final blockInput in blocks) {
      final blockId = _uuid.v4();
      await db
          .into(db.programBlocks)
          .insert(
            ProgramBlocksCompanion.insert(
              id: blockId,
              programVersionId: versionId,
              ordinal: blockInput.ordinal,
              name: blockInput.name,
              description: Value(blockInput.description),
            ),
          );

      for (final weekInput in blockInput.weeks) {
        final weekId = _uuid.v4();
        await db
            .into(db.programWeeks)
            .insert(
              ProgramWeeksCompanion.insert(
                id: weekId,
                programVersionId: versionId,
                programBlockId: blockId,
                ordinalInBlock: weekInput.ordinalInBlock,
                programWeekOrdinal: weekInput.programWeekOrdinal,
                name: Value(weekInput.name),
                isDeload: Value(weekInput.isDeload),
              ),
            );

        for (final tmplInput in weekInput.templates) {
          final tmplId = _uuid.v4();
          await db
              .into(db.sessionTemplates)
              .insert(
                SessionTemplatesCompanion.insert(
                  id: tmplId,
                  programWeekId: weekId,
                  ordinal: tmplInput.ordinal,
                  name: tmplInput.name,
                  plannedWeekday: tmplInput.plannedWeekday,
                  plannedStartMinute: Value(tmplInput.plannedStartMinute),
                  notes: Value(tmplInput.notes),
                ),
              );

          for (final rxInput in tmplInput.prescriptions) {
            await db
                .into(db.exercisePrescriptions)
                .insert(
                  ExercisePrescriptionsCompanion.insert(
                    id: _uuid.v4(),
                    sessionTemplateId: tmplId,
                    ordinal: rxInput.ordinal,
                    exerciseId: Value(rxInput.exerciseId),
                    exerciseNameSnapshot: rxInput.exerciseNameSnapshot,
                    plannedSets: rxInput.plannedSets,
                    repsRange: rxInput.repsRange,
                  ),
                );
          }
        }
      }
    }
  }

  Future<void> _deleteVersionGraph(String versionId) async {
    final weeks = await (db.select(
      db.programWeeks,
    )..where((t) => t.programVersionId.equals(versionId))).get();
    final weekIds = weeks.map((w) => w.id).toList();

    if (weekIds.isNotEmpty) {
      final templates = await (db.select(
        db.sessionTemplates,
      )..where((t) => t.programWeekId.isIn(weekIds))).get();
      final tmplIds = templates.map((t) => t.id).toList();

      if (tmplIds.isNotEmpty) {
        await (db.delete(
          db.exercisePrescriptions,
        )..where((t) => t.sessionTemplateId.isIn(tmplIds))).go();
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
}
