import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../database/app_database.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return WorkoutRepository(db);
});

class RoutineDayWithExercises {
  final String dayName;
  final int dayOfWeek;
  final bool isRestDay;
  final List<RoutineExerciseInput> exercises;

  RoutineDayWithExercises({
    required this.dayName,
    required this.dayOfWeek,
    required this.isRestDay,
    required this.exercises,
  });
}

class RoutineExerciseInput {
  final String name;
  final int sets;
  final String repsRange;

  RoutineExerciseInput({
    required this.name,
    required this.sets,
    required this.repsRange,
  });
}

class WorkoutRepository {
  final AppDatabase _db;

  WorkoutRepository(this._db);

  // 1. Search exercises locally (Fuzzy search)
  Future<List<Exercise>> searchExercises(String query) async {
    if (query.trim().isEmpty) return [];
    final clean = query.toLowerCase().trim();
    return (await (_db.select(_db.exercises)
          ..where((tbl) => tbl.name.lower().contains(clean) | tbl.muscleGroups.lower().contains(clean)))
        .get());
  }

  // 2. Save dynamic AI routine inside a database transaction
  Future<int> saveRoutine({
    required String name,
    required String goal,
    String? notes,
    required List<RoutineDayWithExercises> days,
  }) async {
    return await _db.transaction(() async {
      // 1. Insert routine header
      final routineId = await _db.into(_db.workoutRoutines).insert(
            WorkoutRoutinesCompanion.insert(
              name: name,
              goal: goal,
              notes: Value(notes),
            ),
          );

      // 2. Insert days and exercises
      for (final dayData in days) {
        final dayId = await _db.into(_db.routineDays).insert(
              RoutineDaysCompanion.insert(
                routineId: routineId,
                dayOfWeek: dayData.dayOfWeek,
                name: dayData.dayName,
                isRestDay: Value(dayData.isRestDay),
              ),
            );

        if (!dayData.isRestDay) {
          for (int i = 0; i < dayData.exercises.length; i++) {
            final exInput = dayData.exercises[i];
            await _db.into(_db.routineExercises).insert(
                  RoutineExercisesCompanion.insert(
                    dayId: dayId,
                    exerciseName: exInput.name,
                    sets: exInput.sets,
                    repsRange: exInput.repsRange,
                    orderIndex: i,
                  ),
                );
          }
        }
      }

      return routineId;
    });
  }

  // 3. Retrieve all cached routines
  Future<List<WorkoutRoutine>> getSavedRoutines() async {
    return await _db.select(_db.workoutRoutines).get();
  }

  // 4. Retrieve single routine structure (days and exercises)
  Future<List<Map<String, dynamic>>> getRoutineDetails(int routineId) async {
    final days = await (_db.select(_db.routineDays)..where((tbl) => tbl.routineId.equals(routineId))).get();
    
    final List<Map<String, dynamic>> results = [];
    for (final day in days) {
      final exercises = await (_db.select(_db.routineExercises)..where((tbl) => tbl.dayId.equals(day.id))).get();
      results.add({
        'day': day,
        'exercises': exercises,
      });
    }
    return results;
  }

  // 5. Watch completed workout sessions
  Stream<List<WorkoutSession>> watchSessions() {
    return (_db.select(_db.workoutSessions)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.completedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  // 6. Log a completed session and its sets in a transaction
  Future<int> logSession({
    required String name,
    required double volume,
    required int durationSeconds,
    required int calories,
    required List<WorkoutSetsCompanion> sets,
  }) async {
    return await _db.transaction(() async {
      final sessionId = await _db.into(_db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              name: name,
              totalVolume: volume,
              durationSeconds: durationSeconds,
              estimatedCalories: calories,
            ),
          );

      for (final set in sets) {
        // Inject generated session ID into each set before insert
        final completedSet = set.copyWith(sessionId: Value(sessionId));
        await _db.into(_db.workoutSets).insert(completedSet);
      }

      return sessionId;
    });
  }

  // 7. Fetch the sets from the most recent session for a given exercise (for autofill)
  Future<List<WorkoutSet>> getLatestSetsForExercise(String exerciseName) async {
    final query = _db.select(_db.workoutSets).join([
      innerJoin(
        _db.workoutSessions,
        _db.workoutSessions.id.equalsExp(_db.workoutSets.sessionId),
      ),
    ])
      ..where(_db.workoutSets.exerciseName.equals(exerciseName))
      ..orderBy([OrderingTerm(expression: _db.workoutSessions.completedAt, mode: OrderingMode.desc)]);

    final rows = await query.get();
    if (rows.isEmpty) return [];

    // Get the sessionId of the latest session
    final latestSessionId = rows.first.readTable(_db.workoutSets).sessionId;

    // Fetch all sets for this exercise from that session
    return await (_db.select(_db.workoutSets)
          ..where((tbl) => tbl.sessionId.equals(latestSessionId) & tbl.exerciseName.equals(exerciseName))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.setNumber)]))
        .get();
  }

  // 8. Calculate personal record (PR) from past sets based on estimated 1RM
  Future<WorkoutSet?> getPersonalRecord(String exerciseName) async {
    final sets = await (_db.select(_db.workoutSets)
          ..where((tbl) => tbl.exerciseName.equals(exerciseName)))
        .get();
    
    if (sets.isEmpty) return null;
    
    WorkoutSet? bestSet;
    double max1Rm = 0.0;
    
    for (final s in sets) {
      // Epley formula for 1RM calculation
      final oneRm = s.weight * (1 + s.reps / 30.0);
      if (oneRm > max1Rm) {
        max1Rm = oneRm;
        bestSet = s;
      }
    }
    return bestSet;
  }

  // 9. Log body measurements
  Future<int> logBodyMeasurement({
    double? weight,
    double? waist,
    double? chest,
    double? arms,
  }) async {
    return await _db.into(_db.bodyMeasurements).insert(
          BodyMeasurementsCompanion.insert(
            weight: Value(weight),
            waist: Value(waist),
            chest: Value(chest),
            arms: Value(arms),
          ),
        );
  }

  // 10. Fetch body measurements sorted by date descending
  Future<List<BodyMeasurement>> getBodyMeasurements() async {
    return await (_db.select(_db.bodyMeasurements)
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.recordedAt, mode: OrderingMode.desc)]))
        .get();
  }

  // 11. Fetch latest completed workout session
  Future<WorkoutSession?> getLastCompletedSession() async {
    final query = _db.select(_db.workoutSessions)
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.completedAt, mode: OrderingMode.desc)])
      ..limit(1);
    final rows = await query.get();
    return rows.isEmpty ? null : rows.first;
  }

  // 12. Fetch all sets for a given sessionId
  Future<List<WorkoutSet>> getSetsForSession(int sessionId) async {
    return await (_db.select(_db.workoutSets)
      ..where((tbl) => tbl.sessionId.equals(sessionId))
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.setNumber)]))
      .get();
  }



  // 14. Fetch complete exercise history (sets grouped by session)
  Future<List<Map<String, dynamic>>> getExerciseHistory(String exerciseName) async {
    final query = _db.select(_db.workoutSets).join([
      innerJoin(
        _db.workoutSessions,
        _db.workoutSessions.id.equalsExp(_db.workoutSets.sessionId),
      ),
    ])
      ..where(_db.workoutSets.exerciseName.equals(exerciseName))
      ..orderBy([OrderingTerm(expression: _db.workoutSessions.completedAt, mode: OrderingMode.desc)]);

    final rows = await query.get();
    
    final Map<int, Map<String, dynamic>> grouped = {};
    for (final row in rows) {
      final set = row.readTable(_db.workoutSets);
      final session = row.readTable(_db.workoutSessions);
      
      grouped.putIfAbsent(session.id, () => {
        'session': session,
        'sets': <WorkoutSet>[],
      });
      (grouped[session.id]!['sets'] as List<WorkoutSet>).add(set);
    }
    
    return grouped.values.toList();
  }

  // 15. Active Draft Persistence
  Future<WorkoutDraft?> getActiveDraft() async {
    final rows = await (_db.select(_db.workoutDrafts)
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.updatedAt, mode: OrderingMode.desc)])
      ..limit(1))
      .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> saveWorkoutDraft(WorkoutDraftsCompanion draft) async {
    // Delete any previous drafts first to maintain at most one active draft
    await _db.delete(_db.workoutDrafts).go();
    return await _db.into(_db.workoutDrafts).insert(draft);
  }

  Future<int> deleteActiveDraft() async {
    return await _db.delete(_db.workoutDrafts).go();
  }

  Future<List<RoutineExercise>> getExercisesForRoutineName(String name) async {
    final routineQuery = _db.select(_db.workoutRoutines)
      ..where((tbl) => tbl.name.equals(name))
      ..limit(1);
    final routines = await routineQuery.get();
    if (routines.isEmpty) return [];

    final rId = routines.first.id;

    final daysQuery = _db.select(_db.routineDays)
      ..where((tbl) => tbl.routineId.equals(rId));
    final days = await daysQuery.get();
    if (days.isEmpty) return [];

    final dayIds = days.map((d) => d.id).toList();

    final exercisesQuery = _db.select(_db.routineExercises)
      ..where((tbl) => tbl.dayId.isIn(dayIds))
      ..orderBy([(tbl) => OrderingTerm(expression: tbl.orderIndex)]);
    return await exercisesQuery.get();
  }
}

