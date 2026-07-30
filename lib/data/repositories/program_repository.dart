import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// An explicitly preserved unresolved exercise reference. New authoring must
/// select a stable exercise ID; this flag exists only for import/compatibility
/// flows that cannot safely resolve a legacy/custom name.
class ExercisePrescriptionInput {
  final String? exerciseId;
  final String exerciseNameSnapshot;
  final int plannedSets;
  final String repsRange;
  final int ordinal;
  final bool allowUnresolvedExerciseFallback;

  const ExercisePrescriptionInput({
    this.exerciseId,
    required this.exerciseNameSnapshot,
    required this.plannedSets,
    required this.repsRange,
    required this.ordinal,
    this.allowUnresolvedExerciseFallback = false,
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

/// Complete, ordered, immutable read model for a version graph.
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

/// Small UI-safe exercise selection model. It exposes stable identity and
/// display metadata without making authoring widgets database owners.
class ExerciseAuthoringOption {
  final String stableId;
  final String name;
  final String equipment;

  const ExerciseAuthoringOption({
    required this.stableId,
    required this.name,
    required this.equipment,
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

  /// Authoring read model for the exact, stable-ID exercise picker. The UI
  /// never resolves a typed name itself: a normal prescription is created from
  /// one of these persisted catalogue/custom rows, while unresolved names are
  /// an explicit compatibility-only choice.
  Future<List<ExerciseAuthoringOption>> getExercisesForAuthoring() async {
    final rows =
        await (db.select(db.exercises)
              ..where((table) => table.stableId.isNotNull())
              ..orderBy([(table) => OrderingTerm(expression: table.name)]))
            .get();
    return rows
        .map(
          (row) => ExerciseAuthoringOption(
            stableId: row.stableId!,
            name: row.name,
            equipment: row.equipment,
          ),
        )
        .toList(growable: false);
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
    return ProgramDetailAggregate(
      program: program,
      version: version,
      blocks: blocks,
      weeks: weeks,
      sessionTemplates: templates,
      exercisePrescriptions: prescriptions,
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
          for (final prescription in template.prescriptions) {
            await db
                .into(db.exercisePrescriptions)
                .insert(
                  ExercisePrescriptionsCompanion.insert(
                    id: _uuid.v4(),
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
                ),
              );
          for (final prescription in source.exercisePrescriptions.where(
            (row) => row.sessionTemplateId == template.id,
          )) {
            await db
                .into(db.exercisePrescriptions)
                .insert(
                  ExercisePrescriptionsCompanion.insert(
                    id: _uuid.v4(),
                    sessionTemplateId: newTemplateId,
                    ordinal: prescription.ordinal,
                    exerciseId: Value(prescription.exerciseId),
                    exerciseNameSnapshot: prescription.exerciseNameSnapshot,
                    plannedSets: prescription.plannedSets,
                    repsRange: prescription.repsRange,
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
    final weekIds = weeks.map((row) => row.id).toList();
    if (weekIds.isNotEmpty) {
      final templates = await (db.select(
        db.sessionTemplates,
      )..where((t) => t.programWeekId.isIn(weekIds))).get();
      final templateIds = templates.map((row) => row.id).toList();
      if (templateIds.isNotEmpty) {
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
          for (final prescription in template.prescriptions) {
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
