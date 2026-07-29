import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/b01_legacy_import_support.dart';

enum ActivePlanType { none, legacyRoutine, b01Program }

class ActivePlanSelection {
  final ActivePlanType type;
  final int? legacyRoutineId;
  final String? programVersionId;

  const ActivePlanSelection._({
    required this.type,
    this.legacyRoutineId,
    this.programVersionId,
  });

  factory ActivePlanSelection.none() =>
      const ActivePlanSelection._(type: ActivePlanType.none);

  factory ActivePlanSelection.legacyRoutine(int routineId) =>
      ActivePlanSelection._(
        type: ActivePlanType.legacyRoutine,
        legacyRoutineId: routineId,
      );

  factory ActivePlanSelection.b01Program(String versionId) =>
      ActivePlanSelection._(
        type: ActivePlanType.b01Program,
        programVersionId: versionId,
      );
}

/// Compatibility adapter for bridging legacy routine storage/queries with B01 program versions.
class LegacyProgramCompatibilityAdapter {
  final AppDatabase _db;

  LegacyProgramCompatibilityAdapter(this._db);

  AppDatabase get db => _db;

  /// Resolves current active plan selection.
  /// If `TrainingPlanSettings.activeProgramVersionId` is non-null and references an active version, returns `b01Program`.
  /// Otherwise, if legacy routines exist, falls back to `legacyRoutine` with the greatest routine ID.
  /// Otherwise returns `none`.
  Future<ActivePlanSelection> resolveActivePlanSelection() async {
    final settings = await (db.select(
      db.trainingPlanSettings,
    )..limit(1)).getSingleOrNull();

    if (settings != null && settings.activeProgramVersionId != null) {
      final activeVersion =
          await (db.select(db.programVersions)
                ..where((t) => t.id.equals(settings.activeProgramVersionId!)))
              .getSingleOrNull();
      if (activeVersion != null && activeVersion.status != 'archived') {
        return ActivePlanSelection.b01Program(activeVersion.id);
      }
    }

    final legacyFallback = await getActiveLegacyRoutineFallback();
    if (legacyFallback != null) {
      return ActivePlanSelection.legacyRoutine(legacyFallback.id);
    }

    return ActivePlanSelection.none();
  }

  /// Returns the legacy routine with the greatest ID (de facto latest saved routine)
  /// for legacy compatibility fallback.
  Future<WorkoutRoutine?> getActiveLegacyRoutineFallback() async {
    final routines =
        await (db.select(db.workoutRoutines)..orderBy([
              (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
            ]))
            .get();
    return routines.isEmpty ? null : routines.first;
  }

  /// Syncs a single legacy routine into a deterministic B01 `legacyImport` ProgramVersion
  /// snapshot without setting `activeProgramVersionId` or materializing occurrences.
  Future<void> syncLegacyRoutineToImportVersion(int legacyRoutineId) async {
    final routine = await (db.select(
      db.workoutRoutines,
    )..where((t) => t.id.equals(legacyRoutineId))).getSingleOrNull();
    if (routine == null) return;

    final days =
        await (db.select(db.routineDays)
              ..where((t) => t.routineId.equals(legacyRoutineId))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.dayOfWeek,
                  mode: OrderingMode.asc,
                ),
              ]))
            .get();

    final progId = B01LegacyImportSupport.programId(legacyRoutineId);
    final versionId = B01LegacyImportSupport.programVersionId(legacyRoutineId);
    final blockId = B01LegacyImportSupport.blockId(legacyRoutineId);
    final weekId = B01LegacyImportSupport.weekId(legacyRoutineId);
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      // Upsert Program
      await _db
          .into(_db.programs)
          .insertOnConflictUpdate(
            ProgramsCompanion.insert(
              id: progId,
              name: routine.name,
              notes: Value(routine.notes),
              createdAtUtc: now,
            ),
          );

      // Upsert ProgramVersion
      await _db
          .into(_db.programVersions)
          .insertOnConflictUpdate(
            ProgramVersionsCompanion.insert(
              id: versionId,
              programId: progId,
              versionNumber: 1,
              status: 'draft',
              origin: const Value('legacyImport'),
              createdAtUtc: now,
            ),
          );

      // Upsert LegacyRoutineProgramMappings mapping
      await _db
          .into(_db.legacyRoutineProgramMappings)
          .insertOnConflictUpdate(
            LegacyRoutineProgramMappingsCompanion.insert(
              legacyRoutineId: Value(legacyRoutineId),
              programId: progId,
              programVersionId: versionId,
              importedAtUtc: now,
            ),
          );

      // Delete existing block/week/templates for this legacy import version if updating
      final existingBlocks = await (_db.select(
        _db.programBlocks,
      )..where((t) => t.programVersionId.equals(versionId))).get();
      for (final b in existingBlocks) {
        final existingWeeks = await (_db.select(
          _db.programWeeks,
        )..where((t) => t.programBlockId.equals(b.id))).get();
        for (final w in existingWeeks) {
          final existingTemplates = await (_db.select(
            _db.sessionTemplates,
          )..where((t) => t.programWeekId.equals(w.id))).get();
          for (final st in existingTemplates) {
            await (_db.delete(
              _db.exercisePrescriptions,
            )..where((t) => t.sessionTemplateId.equals(st.id))).go();
          }
          await (_db.delete(
            _db.sessionTemplates,
          )..where((t) => t.programWeekId.equals(w.id))).go();
        }
        await (_db.delete(
          _db.programWeeks,
        )..where((t) => t.programBlockId.equals(b.id))).go();
      }
      await (_db.delete(
        _db.programBlocks,
      )..where((t) => t.programVersionId.equals(versionId))).go();

      // Insert Block & Week
      await _db
          .into(_db.programBlocks)
          .insert(
            ProgramBlocksCompanion.insert(
              id: blockId,
              programVersionId: versionId,
              name: 'Main Block',
              ordinal: 0,
            ),
          );

      await _db
          .into(_db.programWeeks)
          .insert(
            ProgramWeeksCompanion.insert(
              id: weekId,
              programVersionId: versionId,
              programBlockId: blockId,
              ordinalInBlock: 0,
              programWeekOrdinal: 0,
              isDeload: const Value(false),
            ),
          );

      // Insert session templates & prescriptions for days
      for (int i = 0; i < days.length; i++) {
        final day = days[i];
        final templateId = B01LegacyImportSupport.sessionTemplateId(
          legacyRoutineId,
          day.id,
        );

        await _db
            .into(_db.sessionTemplates)
            .insert(
              SessionTemplatesCompanion.insert(
                id: templateId,
                programWeekId: weekId,
                name: day.name,
                ordinal: i,
                plannedWeekday: day.dayOfWeek,
              ),
            );

        if (!day.isRestDay) {
          final exercises =
              await (_db.select(_db.routineExercises)
                    ..where((t) => t.dayId.equals(day.id))
                    ..orderBy([
                      (t) => OrderingTerm(
                        expression: t.orderIndex,
                        mode: OrderingMode.asc,
                      ),
                    ]))
                  .get();

          for (int j = 0; j < exercises.length; j++) {
            final ex = exercises[j];
            final presId = B01LegacyImportSupport.prescriptionId(
              legacyRoutineId,
              ex.id,
            );
            final lookup = B01LegacyImportSupport.lookupExerciseName(
              ex.exerciseName,
            );

            await _db
                .into(_db.exercisePrescriptions)
                .insert(
                  ExercisePrescriptionsCompanion.insert(
                    id: presId,
                    sessionTemplateId: templateId,
                    exerciseId: Value(lookup.canonicalUuid),
                    exerciseNameSnapshot: ex.exerciseName,
                    plannedSets: ex.sets,
                    repsRange: ex.repsRange,
                    ordinal: j,
                  ),
                );
          }
        }
      }
    });
  }

  /// Syncs all saved legacy routines into B01 legacyImport program version snapshots.
  Future<void> syncAllLegacyRoutines() async {
    final routines = await (db.select(db.workoutRoutines)).get();
    for (final r in routines) {
      await syncLegacyRoutineToImportVersion(r.id);
    }
  }
}
