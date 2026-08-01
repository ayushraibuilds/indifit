import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import '../models/b02_group_plan_validator.dart';

class ActivationRejectedException implements Exception {
  final String message;

  const ActivationRejectedException(this.message);

  @override
  String toString() => 'ActivationRejectedException: $message';
}

class ActivateProgramVersionCommand {
  final String programVersionId;
  final String commandId;
  final String activationLocalDate;
  final String timezoneId;

  /// The safe default is to retain prior occurrences. Only IDs explicitly
  /// supplied here are cancelled, and their history is retained as an event.
  final Set<String> cancelPriorOccurrenceIds;

  const ActivateProgramVersionCommand({
    required this.programVersionId,
    required this.commandId,
    required this.activationLocalDate,
    required this.timezoneId,
    this.cancelPriorOccurrenceIds = const {},
  });
}

class ActivationResult {
  final String programVersionId;
  final List<ScheduledSessionOccurrence> occurrences;
  final bool wasIdempotent;

  const ActivationResult({
    required this.programVersionId,
    required this.occurrences,
    required this.wasIdempotent,
  });
}

/// Owns the activation transaction only. It does not depend on
/// [ProgramRepository] or [CalendarRepository], avoiding repository cycles.
class ProgramActivationCoordinator {
  final AppDatabase _db;
  final LocalScheduleDateService _dates;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  ProgramActivationCoordinator(
    this._db, {
    LocalScheduleDateService? dates,
    Uuid? uuid,
    DateTime Function()? nowUtc,
  }) : _dates = dates ?? LocalScheduleDateService(nowUtc: nowUtc),
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  Future<ActivationResult> activate(
    ActivateProgramVersionCommand command,
  ) async {
    _require(command.commandId, 'Activation command ID');
    final activationDate = _dates.normalizeLocalDate(
      command.activationLocalDate,
    );
    _dates.validateTimezone(command.timezoneId);

    return _db.transaction(() async {
      final version = await _getVersion(command.programVersionId);
      if (version.status == 'published') {
        final existing = await _findActivationResult(
          programVersionId: version.id,
          commandId: command.commandId,
        );
        if (existing != null) return existing;
        throw const ActivationRejectedException(
          'A published version cannot be activated again; create a replacement draft.',
        );
      }
      if (version.status != 'draft') {
        throw const ActivationRejectedException(
          'Only draft versions can activate.',
        );
      }

      final activeDrafts = await _db.select(_db.workoutDrafts).get();
      if (activeDrafts.isNotEmpty) {
        throw const ActivationRejectedException(
          'Resolve the existing workout draft before activating a program.',
        );
      }

      final graph = await _loadAndValidateGraph(version.id);
      final now = _nowUtc().toUtc();
      final settings = await (_db.select(
        _db.trainingPlanSettings,
      )..where((table) => table.id.equals(1))).getSingleOrNull();
      if (settings == null) {
        throw const ActivationRejectedException(
          'Training plan settings are missing.',
        );
      }

      final priorActiveVersionId = settings.activeProgramVersionId;
      if (command.cancelPriorOccurrenceIds.isNotEmpty) {
        if (priorActiveVersionId == null) {
          throw const ActivationRejectedException(
            'There is no prior active version with occurrences to cancel.',
          );
        }
        await _cancelSelectedPriorOccurrences(
          priorVersionId: priorActiveVersionId,
          occurrenceIds: command.cancelPriorOccurrenceIds,
          activationCommandId: command.commandId,
          occurredAtUtc: now,
        );
      }

      final occurrences = <ScheduledSessionOccurrence>[];
      for (final templateData in graph.templates) {
        final occurrenceId = _uuid.v4();
        final localDate = _dates.occurrenceDate(
          activationLocalDate: activationDate,
          timezoneId: command.timezoneId,
          programWeekOrdinal: templateData.week.programWeekOrdinal,
          plannedWeekday: templateData.template.plannedWeekday,
        );
        await _db
            .into(_db.scheduledSessionOccurrences)
            .insert(
              ScheduledSessionOccurrencesCompanion.insert(
                id: occurrenceId,
                programVersionId: version.id,
                sessionTemplateId: templateData.template.id,
                programBlockOrdinal: templateData.block.ordinal,
                programWeekOrdinal: templateData.week.programWeekOrdinal,
                sessionOrdinal: templateData.template.ordinal,
                originalLocalDate: localDate,
                originalTimezoneId: command.timezoneId,
                effectiveLocalDate: localDate,
                effectiveTimezoneId: command.timezoneId,
                createdAtUtc: now,
              ),
            );
        await _db
            .into(_db.occurrenceEvents)
            .insert(
              OccurrenceEventsCompanion.insert(
                id: _uuid.v4(),
                occurrenceId: occurrenceId,
                commandId: command.commandId,
                eventType: 'activated',
                toStatus: const Value('planned'),
                afterLocalDate: Value(localDate),
                afterTimezoneId: Value(command.timezoneId),
                metadataJson: Value(
                  jsonEncode({'activationProgramVersionId': version.id}),
                ),
                occurredAtUtc: now,
              ),
            );
        occurrences.add(
          ScheduledSessionOccurrence(
            id: occurrenceId,
            programVersionId: version.id,
            sessionTemplateId: templateData.template.id,
            programBlockOrdinal: templateData.block.ordinal,
            programWeekOrdinal: templateData.week.programWeekOrdinal,
            sessionOrdinal: templateData.template.ordinal,
            repeatOrdinal: 0,
            originalLocalDate: localDate,
            originalTimezoneId: command.timezoneId,
            effectiveLocalDate: localDate,
            effectiveTimezoneId: command.timezoneId,
            status: 'planned',
            progressionDisposition: 'pending',
            skipMode: null,
            repeatPurpose: null,
            repeatedFromOccurrenceId: null,
            executionSnapshotJson: null,
            startedAtUtc: null,
            terminalAtUtc: null,
            createdAtUtc: now,
          ),
        );
      }

      await (_db.update(
        _db.programVersions,
      )..where((table) => table.id.equals(version.id))).write(
        ProgramVersionsCompanion(
          status: const Value('published'),
          publishedAtUtc: Value(now),
        ),
      );
      await (_db.update(
        _db.trainingPlanSettings,
      )..where((table) => table.id.equals(1))).write(
        TrainingPlanSettingsCompanion(
          activeProgramVersionId: Value(version.id),
          activeSinceLocalDate: Value(activationDate),
          activeSinceTimezoneId: Value(command.timezoneId),
          updatedAtUtc: Value(now),
        ),
      );

      return ActivationResult(
        programVersionId: version.id,
        occurrences: occurrences,
        wasIdempotent: false,
      );
    });
  }

  Future<ActivationResult?> _findActivationResult({
    required String programVersionId,
    required String commandId,
  }) async {
    final occurrences =
        await (_db.select(_db.scheduledSessionOccurrences)
              ..where(
                (table) => table.programVersionId.equals(programVersionId),
              )
              ..orderBy([
                (table) => OrderingTerm(expression: table.programWeekOrdinal),
                (table) => OrderingTerm(expression: table.sessionOrdinal),
              ]))
            .get();
    if (occurrences.isEmpty) return null;
    final ids = occurrences.map((occurrence) => occurrence.id).toList();
    final events =
        await (_db.select(_db.occurrenceEvents)..where(
              (table) =>
                  table.occurrenceId.isIn(ids) &
                  table.commandId.equals(commandId) &
                  table.eventType.equals('activated'),
            ))
            .get();
    if (events.length != occurrences.length) return null;
    return ActivationResult(
      programVersionId: programVersionId,
      occurrences: occurrences,
      wasIdempotent: true,
    );
  }

  Future<void> _cancelSelectedPriorOccurrences({
    required String priorVersionId,
    required Set<String> occurrenceIds,
    required String activationCommandId,
    required DateTime occurredAtUtc,
  }) async {
    final rows =
        await (_db.select(_db.scheduledSessionOccurrences)..where(
              (table) =>
                  table.programVersionId.equals(priorVersionId) &
                  table.id.isIn(occurrenceIds.toList()),
            ))
            .get();
    if (rows.length != occurrenceIds.length ||
        rows.any(
          (row) => row.status != 'planned' && row.status != 'rescheduled',
        )) {
      throw const ActivationRejectedException(
        'Only selected unstarted occurrences from the prior active version can be cancelled.',
      );
    }
    for (final row in rows) {
      await (_db.update(_db.scheduledSessionOccurrences)..where(
            (table) =>
                table.id.equals(row.id) &
                table.status.isIn(const ['planned', 'rescheduled']),
          ))
          .write(
            ScheduledSessionOccurrencesCompanion(
              status: const Value('cancelled'),
              terminalAtUtc: Value(occurredAtUtc),
            ),
          );
      await _db
          .into(_db.occurrenceEvents)
          .insert(
            OccurrenceEventsCompanion.insert(
              id: _uuid.v4(),
              occurrenceId: row.id,
              commandId: activationCommandId,
              eventType: 'activationCancelled',
              fromStatus: Value(row.status),
              toStatus: const Value('cancelled'),
              beforeLocalDate: Value(row.effectiveLocalDate),
              beforeTimezoneId: Value(row.effectiveTimezoneId),
              afterLocalDate: Value(row.effectiveLocalDate),
              afterTimezoneId: Value(row.effectiveTimezoneId),
              reason: const Value('replacementActivation'),
              occurredAtUtc: occurredAtUtc,
            ),
          );
    }
  }

  Future<ProgramVersion> _getVersion(String versionId) async {
    final version = await (_db.select(
      _db.programVersions,
    )..where((table) => table.id.equals(versionId))).getSingleOrNull();
    if (version == null) {
      throw ActivationRejectedException(
        'Program version $versionId was not found.',
      );
    }
    return version;
  }

  Future<_ValidatedGraph> _loadAndValidateGraph(String versionId) async {
    final blocks =
        await (_db.select(_db.programBlocks)
              ..where((table) => table.programVersionId.equals(versionId))
              ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
            .get();
    if (blocks.isEmpty) {
      throw const ActivationRejectedException(
        'A program needs at least one block.',
      );
    }
    _requireContiguous(blocks.map((block) => block.ordinal), 'Block');

    final weeks =
        await (_db.select(_db.programWeeks)
              ..where((table) => table.programVersionId.equals(versionId))
              ..orderBy([
                (table) => OrderingTerm(expression: table.programWeekOrdinal),
              ]))
            .get();
    if (weeks.isEmpty) {
      throw const ActivationRejectedException(
        'A program needs at least one week.',
      );
    }
    _requireContiguous(
      weeks.map((week) => week.programWeekOrdinal),
      'Program week',
    );
    for (final block in blocks) {
      _requireContiguous(
        weeks
            .where((week) => week.programBlockId == block.id)
            .map((week) => week.ordinalInBlock),
        'Week in block ${block.ordinal}',
      );
    }

    final weekIds = weeks.map((week) => week.id).toList();
    final templates =
        await (_db.select(_db.sessionTemplates)
              ..where((table) => table.programWeekId.isIn(weekIds))
              ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
            .get();
    if (templates.isEmpty) {
      throw const ActivationRejectedException(
        'A program needs at least one session template.',
      );
    }
    for (final week in weeks) {
      final inWeek = templates.where(
        (template) => template.programWeekId == week.id,
      );
      _requireContiguous(
        inWeek.map((template) => template.ordinal),
        'Template in week ${week.programWeekOrdinal}',
      );
      if (inWeek.any(
        (template) =>
            template.plannedWeekday < DateTime.monday ||
            template.plannedWeekday > DateTime.sunday,
      )) {
        throw const ActivationRejectedException(
          'A session template has an invalid weekday.',
        );
      }
    }

    final templateIds = templates.map((template) => template.id).toList();
    final prescriptions =
        await (_db.select(_db.exercisePrescriptions)
              ..where((table) => table.sessionTemplateId.isIn(templateIds))
              ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
            .get();
    final groups =
        await (_db.select(_db.exerciseGroups)
              ..where((table) => table.sessionTemplateId.isIn(templateIds))
              ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
            .get();
    final groupIds = groups.map((group) => group.id).toList();
    final groupMembers = groupIds.isEmpty
        ? <ExerciseGroupMember>[]
        : await (_db.select(_db.exerciseGroupMembers)
                ..where((table) => table.exerciseGroupId.isIn(groupIds))
                ..orderBy([(table) => OrderingTerm(expression: table.ordinal)]))
              .get();
    for (final template in templates) {
      final inTemplate = prescriptions.where(
        (prescription) => prescription.sessionTemplateId == template.id,
      );
      if (inTemplate.isEmpty) {
        throw const ActivationRejectedException(
          'Every session template needs a prescription.',
        );
      }
      _requireContiguous(
        inTemplate.map((prescription) => prescription.ordinal),
        'Prescription in template ${template.name}',
      );
      if (inTemplate.any(
        (prescription) =>
            prescription.exerciseNameSnapshot.trim().isEmpty ||
            prescription.repsRange.trim().isEmpty ||
            prescription.plannedSets <= 0,
      )) {
        throw const ActivationRejectedException(
          'A prescription has invalid execution data.',
        );
      }
      final inGroups = groups.where(
        (group) => group.sessionTemplateId == template.id,
      );
      final prescriptionIds = inTemplate.map((row) => row.id).toSet();
      try {
        B02GroupPlanValidator.validate(
          groups: inGroups.map(
            (group) => B02ExerciseGroup(
              id: group.id,
              sessionTemplateId: group.sessionTemplateId,
              ordinal: group.ordinal,
              groupType: B02GroupType.parse(group.groupType),
              roundCount: group.roundCount,
              restAfterRoundSeconds: group.restAfterRoundSeconds,
              label: group.label,
              members: groupMembers
                  .where((member) => member.exerciseGroupId == group.id)
                  .map(
                    (member) => B02ExerciseGroupMember(
                      id: member.id,
                      exercisePrescriptionId: member.exercisePrescriptionId,
                      ordinal: member.ordinal,
                      transitionRestSeconds: member.transitionRestSeconds,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          prescriptionIds: prescriptionIds,
        );
      } on B02ValidationException catch (error) {
        throw ActivationRejectedException(
          'Invalid exercise group in template ${template.name}: ${error.message}',
        );
      }
    }

    final blockById = {for (final block in blocks) block.id: block};
    final templatesForMaterialization = <_TemplateData>[];
    for (final template in templates) {
      final week = weeks.singleWhere(
        (week) => week.id == template.programWeekId,
      );
      final block = blockById[week.programBlockId];
      if (block == null) {
        throw const ActivationRejectedException(
          'A program week has no matching block.',
        );
      }
      templatesForMaterialization.add(
        _TemplateData(block: block, week: week, template: template),
      );
    }
    templatesForMaterialization.sort((first, second) {
      final byWeek = first.week.programWeekOrdinal.compareTo(
        second.week.programWeekOrdinal,
      );
      return byWeek == 0
          ? first.template.ordinal.compareTo(second.template.ordinal)
          : byWeek;
    });
    return _ValidatedGraph(templates: templatesForMaterialization);
  }

  static void _requireContiguous(Iterable<int> ordinals, String label) {
    final values = ordinals.toList()..sort();
    for (var index = 0; index < values.length; index++) {
      if (values[index] != index) {
        throw ActivationRejectedException(
          '$label ordinals must be contiguous from zero.',
        );
      }
    }
  }

  static void _require(String value, String label) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, label, 'Must not be blank.');
    }
  }
}

class _ValidatedGraph {
  final List<_TemplateData> templates;

  const _ValidatedGraph({required this.templates});
}

class _TemplateData {
  final ProgramBlock block;
  final ProgramWeek week;
  final SessionTemplate template;

  const _TemplateData({
    required this.block,
    required this.week,
    required this.template,
  });
}
