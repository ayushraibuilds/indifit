import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/fixtures/b02_muscle_catalog.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import '../models/b02_muscle_volume_models.dart';
import '../services/b02_muscle_volume_service.dart';

class B02MuscleVolumeQuery {
  final String startLocalDate;
  final String endLocalDate;
  final String timezoneId;

  const B02MuscleVolumeQuery({
    required this.startLocalDate,
    required this.endLocalDate,
    required this.timezoneId,
  });
}

class B02MuscleVolumeRepositoryException implements Exception {
  final String message;

  const B02MuscleVolumeRepositoryException(this.message);

  @override
  String toString() => 'B02MuscleVolumeRepositoryException: $message';
}

/// Read-only repository for the derived muscle volume contract.  No aggregate
/// rows are written; every call reads the current immutable performed facts.
class B02MuscleVolumeRepository {
  final AppDatabase _db;
  final B02MuscleVolumeService _service;
  final LocalScheduleDateService _civilDates;

  B02MuscleVolumeRepository(
    this._db, {
    B02MuscleVolumeService service = const B02MuscleVolumeService(),
    LocalScheduleDateService? civilDates,
  }) : _service = service,
       _civilDates = civilDates ?? LocalScheduleDateService();

  Future<B02MuscleVolumeReadModel> read(B02MuscleVolumeQuery query) async {
    final range = _resolveRange(query);
    final legacyStatement =
        _db.select(_db.workoutSets).join([
            innerJoin(
              _db.workoutSessions,
              _db.workoutSessions.id.equalsExp(_db.workoutSets.sessionId),
            ),
          ])
          ..where(
            _db.workoutSessions.activityType.equals(
              B02ActivityType.legacy.dbValue,
            ),
          )
          ..where(
            _db.workoutSessions.completedAt.isBiggerOrEqualValue(
              range.startUtc,
            ),
          )
          ..where(
            _db.workoutSessions.completedAt.isSmallerThanValue(
              range.endExclusiveUtc,
            ),
          );
    final legacySetCount = (await legacyStatement.get()).length;
    final sets = _db.performedSets;
    final exercises = _db.performedExercises;
    final sessions = _db.workoutSessions;
    final statement =
        _db.select(sets).join([
            innerJoin(
              exercises,
              exercises.id.equalsExp(sets.performedExerciseId),
            ),
            innerJoin(sessions, sessions.id.equalsExp(exercises.sessionId)),
          ])
          ..where(
            sessions.activityType.equals(B02ActivityType.strength.dbValue),
          )
          ..where(sessions.completedAt.isBiggerOrEqualValue(range.startUtc))
          ..where(
            sessions.completedAt.isSmallerThanValue(range.endExclusiveUtc),
          )
          ..orderBy([
            OrderingTerm.asc(sessions.completedAt),
            OrderingTerm.asc(exercises.ordinal),
            OrderingTerm.asc(sets.ordinal),
          ]);
    final joinedRows = await statement.get();
    final setRows = <String, _JoinedSetRow>{};
    final actualExerciseIds = <String>{};
    for (final row in joinedRows) {
      final set = row.readTable(sets);
      final performedExercise = row.readTable(exercises);
      if (setRows.containsKey(set.id)) {
        throw const B02MuscleVolumeRepositoryException(
          'A performed set was returned more than once.',
        );
      }
      setRows[set.id] = _JoinedSetRow(
        set: set,
        performedExercise: performedExercise,
      );
      actualExerciseIds.add(performedExercise.actualExerciseId);
    }

    final setIds = setRows.keys.toSet();
    final segments = setIds.isEmpty
        ? const <PerformedSetSegment>[]
        : await (_db.select(_db.performedSetSegments)
                ..where((table) => table.performedSetId.isIn(setIds))
                ..orderBy([
                  (table) => OrderingTerm.asc(table.performedSetId),
                  (table) => OrderingTerm.asc(table.ordinal),
                ]))
              .get();
    final segmentsBySet = <String, List<PerformedSetSegment>>{};
    for (final segment in segments) {
      if (!setIds.contains(segment.performedSetId)) {
        throw const B02MuscleVolumeRepositoryException(
          'A segment references a set outside the selected range.',
        );
      }
      segmentsBySet.putIfAbsent(segment.performedSetId, () => []).add(segment);
    }

    final exerciseRows = actualExerciseIds.isEmpty
        ? const <Exercise>[]
        : await (_db.select(
            _db.exercises,
          )..where((table) => table.stableId.isIn(actualExerciseIds))).get();
    final resolvedExerciseIds = exerciseRows
        .map((row) => row.stableId)
        .whereType<String>()
        .toSet();
    if (resolvedExerciseIds.length != actualExerciseIds.length) {
      throw const B02MuscleVolumeRepositoryException(
        'A performed exercise has no canonical stable-ID parent.',
      );
    }

    final mappingRows = actualExerciseIds.isEmpty
        ? const <ExerciseMuscleMapping>[]
        : await (_db.select(_db.exerciseMuscleMappings)
                ..where((table) => table.exerciseId.isIn(actualExerciseIds))
                ..orderBy([
                  (table) => OrderingTerm.asc(table.exerciseId),
                  (table) => OrderingTerm.asc(table.muscleId),
                ]))
              .get();
    // Read the complete active taxonomy so a heat-map cell with no observed
    // allocation is distinguishable from an absent/unknown muscle catalog.
    final muscleRows = await _db.select(_db.muscles).get();
    final muscleCatalog = <String, B02MuscleCatalogEntry>{
      for (final row in muscleRows)
        row.id: B02MuscleCatalogEntry(
          id: row.id,
          displayName: row.displayName,
          region: row.region,
          catalogVersion: row.catalogVersion,
          isActive: row.isActive,
        ),
    };
    final mappings = _groupMappings(mappingRows);

    final facts = <B02MuscleVolumeSetFact>[
      for (final row in setRows.values)
        B02MuscleVolumeSetFact(
          id: row.set.id,
          exerciseId: row.performedExercise.actualExerciseId,
          role: B02SetRole.parse(row.set.role),
          actualReps: row.set.actualReps,
          targetRepsMin: row.set.targetRepsMin,
          isAssisted:
              row.set.assistanceKg != null || row.set.assistanceMode != null,
          segments: [
            for (final segment in segmentsBySet[row.set.id] ?? const [])
              B02MuscleVolumeSegmentFact(
                ordinal: segment.ordinal,
                reps: segment.reps,
              ),
          ],
        ),
    ];

    // Keep the read path strict for reviewed rows. Unknown rows are grouped
    // as unknown and their raw contribution columns are never allocated.
    final reviewedMappings = mappings.values.where(
      (mapping) => mapping.isReviewed,
    );
    const validator = B02MuscleMappingValidator();
    validator.validate(
      mappings: reviewedMappings,
      canonicalExerciseIds: resolvedExerciseIds,
      muscles: muscleCatalog,
    );
    return _service.calculate(
      range: range,
      facts: facts,
      mappings: mappings,
      muscles: muscleCatalog,
      legacySetCount: legacySetCount,
    );
  }

  Future<B02MuscleVolumeMapping?> readMappingForExercise(
    String stableExerciseId,
  ) async {
    final exerciseId = stableExerciseId.trim();
    if (exerciseId.isEmpty) {
      throw const B02MuscleVolumeRepositoryException(
        'Exercise stable ID must not be blank.',
      );
    }
    final rows =
        await (_db.select(_db.exerciseMuscleMappings)
              ..where((table) => table.exerciseId.equals(exerciseId))
              ..orderBy([(table) => OrderingTerm.asc(table.muscleId)]))
            .get();
    if (rows.isEmpty) return null;
    return _groupMapping(rows);
  }

  B02MuscleVolumeDateRange _resolveRange(B02MuscleVolumeQuery query) {
    final start = _civilDates.normalizeLocalDate(query.startLocalDate);
    final end = _civilDates.normalizeLocalDate(query.endLocalDate);
    final location = _civilDates.locationFor(query.timezoneId);
    if (start.compareTo(end) > 0) {
      throw ArgumentError.value(
        query.endLocalDate,
        'endLocalDate',
        'Must not precede startLocalDate.',
      );
    }
    final startParts = _parseDate(start);
    final endParts = _parseDate(end);
    final startLocal = tz.TZDateTime(
      location,
      startParts.$1,
      startParts.$2,
      startParts.$3,
    );
    final endExclusiveLocal = tz.TZDateTime(
      location,
      endParts.$1,
      endParts.$2,
      endParts.$3 + 1,
    );
    return B02MuscleVolumeDateRange(
      startLocalDate: start,
      endLocalDate: end,
      timezoneId: query.timezoneId,
      startUtc: startLocal.toUtc(),
      endExclusiveUtc: endExclusiveLocal.toUtc(),
    );
  }

  Map<String, B02MuscleVolumeMapping> _groupMappings(
    Iterable<ExerciseMuscleMapping> rows,
  ) {
    final grouped = <String, List<ExerciseMuscleMapping>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.exerciseId, () => []).add(row);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: _groupMapping(entry.value),
    };
  }

  B02MuscleVolumeMapping _groupMapping(Iterable<ExerciseMuscleMapping> rows) {
    final values = rows.toList(growable: false);
    if (values.isEmpty) {
      throw const B02MuscleVolumeRepositoryException(
        'Cannot group an empty muscle mapping.',
      );
    }
    final first = values.first;
    final statuses = values.map((row) => row.mappingStatus).toSet();
    final status = statuses.length == 1
        ? B02MappingStatus.parse(first.mappingStatus)
        : B02MappingStatus.unknown;
    if (status == B02MappingStatus.unknown) {
      // The SQL table has one row per contribution, so an unknown mapping
      // may retain legacy columns.  It remains entirely unallocated.
      return B02MuscleVolumeMapping(
        exerciseId: first.exerciseId,
        status: B02MappingStatus.unknown,
        source: null,
        catalogVersion: first.catalogVersion,
        contributions: const [],
      );
    }
    final sourceValues = values.map((row) => row.source).toSet();
    final versions = values.map((row) => row.catalogVersion).toSet();
    if (sourceValues.length != 1 || versions.length != 1) {
      throw const B02MuscleVolumeRepositoryException(
        'Reviewed mapping rows disagree on source or catalog version.',
      );
    }
    return B02MuscleVolumeMapping(
      exerciseId: first.exerciseId,
      status: status,
      source: first.source,
      catalogVersion: first.catalogVersion,
      contributions: [
        for (final row in values)
          B02MuscleContribution(
            muscleId: row.muscleId,
            role: B02MuscleRole.parse(row.role),
            contributionBasisPoints: row.contributionBasisPoints,
          ),
      ],
    );
  }

  static (int, int, int) _parseDate(String value) => (
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(5, 7)),
    int.parse(value.substring(8, 10)),
  );
}

/// Transactional seed/validation boundary for the reviewed catalog.  It is
/// explicit so migrations and import paths can choose when to seed while
/// preserving pre-existing unknown/custom rows.
class B02MuscleCatalogRepository {
  final AppDatabase _db;
  final B02MuscleMappingValidator _validator;

  B02MuscleCatalogRepository(
    this._db, {
    B02MuscleMappingValidator validator = const B02MuscleMappingValidator(),
  }) : _validator = validator;

  Future<B02MuscleMappingSeedResult> seedReviewedCatalog() async {
    final seedMuscles = {
      for (final muscle in B02CanonicalMuscleCatalog.muscles) muscle.id: muscle,
    };
    final seedMappings = B02CanonicalMuscleCatalog.reviewedMappings();
    _validator.validate(
      mappings: seedMappings,
      canonicalExerciseIds: {
        for (final mapping in seedMappings) mapping.exerciseId,
      },
      muscles: seedMuscles,
    );

    return _db.transaction(() async {
      final existingMuscles = await _db.select(_db.muscles).get();
      final existingMuscleById = {
        for (final muscle in existingMuscles) muscle.id: muscle,
      };
      final existingDisplayKeys = {
        for (final muscle in existingMuscles)
          '${muscle.displayName}\u0000${muscle.catalogVersion}': muscle.id,
      };
      final exercises =
          await (_db.select(_db.exercises)..where(
                (table) => table.stableId.isIn(
                  seedMappings.map((mapping) => mapping.exerciseId),
                ),
              ))
              .get();
      final exerciseIds = exercises
          .map((exercise) => exercise.stableId)
          .whereType<String>()
          .toSet();
      final customExerciseIds = exercises
          .where((exercise) => exercise.isCustom)
          .map((exercise) => exercise.stableId)
          .whereType<String>()
          .toSet();
      final missingExerciseIds = seedMappings
          .map((mapping) => mapping.exerciseId)
          .where((id) => !exerciseIds.contains(id))
          .toSet();
      if (missingExerciseIds.isNotEmpty) {
        throw B02MuscleVolumeValidationException(
          'Reviewed muscle seed references missing canonical exercise(s): '
          '${missingExerciseIds.join(', ')}',
        );
      }
      if (customExerciseIds.isNotEmpty) {
        throw B02MuscleVolumeValidationException(
          'Reviewed muscle seed references custom exercise ID(s): '
          '${customExerciseIds.join(', ')}',
        );
      }

      final musclesToInsert = <MusclesCompanion>[];
      var preservedMuscles = 0;
      for (final muscle in seedMuscles.values) {
        final existing = existingMuscleById[muscle.id];
        if (existing != null) {
          if (existing.displayName != muscle.displayName ||
              existing.region != muscle.region ||
              existing.catalogVersion != muscle.catalogVersion ||
              !existing.isActive) {
            throw const B02MuscleVolumeValidationException(
              'Existing muscle catalog data conflicts with the reviewed seed.',
            );
          }
          preservedMuscles++;
          continue;
        }
        final displayKey =
            '${muscle.displayName}\u0000${muscle.catalogVersion}';
        if (existingDisplayKeys.containsKey(displayKey)) {
          throw const B02MuscleVolumeValidationException(
            'Reviewed muscle seed would violate the catalog uniqueness rule.',
          );
        }
        musclesToInsert.add(
          MusclesCompanion.insert(
            id: muscle.id,
            displayName: muscle.displayName,
            region: muscle.region,
            catalogVersion: muscle.catalogVersion,
          ),
        );
      }

      final existingMappings =
          await (_db.select(_db.exerciseMuscleMappings)..where(
                (table) => table.exerciseId.isIn(
                  seedMappings.map((mapping) => mapping.exerciseId),
                ),
              ))
              .get();
      final existingByPair = {
        for (final row in existingMappings)
          '${row.exerciseId}\u0000${row.muscleId}': row,
      };
      final expectedByPair = {
        for (final mapping in seedMappings)
          for (final contribution in mapping.contributions)
            '${mapping.exerciseId}\u0000${contribution.muscleId}': (
              mapping,
              contribution,
            ),
      };
      for (final existing in existingMappings) {
        if (existing.mappingStatus != B02MappingStatus.unknown.dbValue &&
            !expectedByPair.containsKey(
              '${existing.exerciseId}\u0000${existing.muscleId}',
            )) {
          throw const B02MuscleVolumeValidationException(
            'Existing reviewed exercise-muscle data conflicts with the seed.',
          );
        }
      }
      final mappingsToInsert = <ExerciseMuscleMappingsCompanion>[];
      var preservedMappings = 0;
      for (final mapping in seedMappings) {
        for (final contribution in mapping.contributions) {
          final key = '${mapping.exerciseId}\u0000${contribution.muscleId}';
          final existing = existingByPair[key];
          if (existing != null) {
            if (existing.mappingStatus == B02MappingStatus.unknown.dbValue) {
              preservedMappings++;
              continue;
            }
            if (existing.mappingStatus != mapping.status.dbValue ||
                existing.role != contribution.role.dbValue ||
                existing.contributionBasisPoints !=
                    contribution.contributionBasisPoints ||
                existing.source != mapping.source ||
                existing.catalogVersion != mapping.catalogVersion) {
              throw const B02MuscleVolumeValidationException(
                'Existing exercise-muscle data conflicts with the reviewed seed.',
              );
            }
            preservedMappings++;
            continue;
          }
          final rowId =
              '${mapping.exerciseId}:${contribution.muscleId}:v'
              '${mapping.catalogVersion}';
          mappingsToInsert.add(
            ExerciseMuscleMappingsCompanion.insert(
              id: rowId,
              exerciseId: mapping.exerciseId,
              muscleId: contribution.muscleId,
              role: contribution.role.dbValue,
              contributionBasisPoints: contribution.contributionBasisPoints,
              mappingStatus: mapping.status.dbValue,
              source: Value(mapping.source),
              catalogVersion: mapping.catalogVersion,
            ),
          );
        }
      }
      if (musclesToInsert.isNotEmpty) {
        await _db.batch(
          (batch) => batch.insertAll(_db.muscles, musclesToInsert),
        );
      }
      if (mappingsToInsert.isNotEmpty) {
        await _db.batch(
          (batch) =>
              batch.insertAll(_db.exerciseMuscleMappings, mappingsToInsert),
        );
      }
      return B02MuscleMappingSeedResult(
        insertedMuscles: musclesToInsert.length,
        insertedMappings: mappingsToInsert.length,
        preservedMuscles: preservedMuscles,
        preservedMappings: preservedMappings,
      );
    });
  }
}

class _JoinedSetRow {
  final PerformedSet set;
  final PerformedExercise performedExercise;

  const _JoinedSetRow({required this.set, required this.performedExercise});
}

typedef MuscleVolumeRepository = B02MuscleVolumeRepository;
