import 'package:drift/drift.dart';

import '../../core/nutrients.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import '../models/b02_muscle_volume_models.dart';
import '../models/b04_goal_models.dart';
import '../models/progress_dashboard_models.dart';
import 'b02_muscle_volume_repository.dart';
import 'nutrition_goal_repository.dart';
import 'nutrition_read_model_repository.dart';
import 'nutrition_target_authority.dart';
import 'workout_repository.dart';

/// Read-only composition for the consumer Progress tab.
///
/// It deliberately reads completed-session facts, persisted measurements, B02
/// performed values, B03 nutrition consumption, and the existing B02
/// muscle-volume output. It neither persists aggregate data nor converts
/// prescribed/recommended targets into achievements.
class ProgressDashboardReadRepository {
  ProgressDashboardReadRepository(
    this._database, {
    WorkoutRepository? workouts,
    B02MuscleVolumeRepository? muscleVolume,
    NutritionReadModelRepository? nutrition,
    NutritionTargetAuthority? nutritionTargets,
    @Deprecated('Use nutritionTargets.')
    NutritionGoalRepository? nutritionGoals,
    LocalScheduleDateService? dates,
  }) : _workouts = workouts ?? WorkoutRepository(_database),
       _muscleVolume = muscleVolume ?? B02MuscleVolumeRepository(_database),
       _nutrition = nutrition,
       _nutritionTargets =
           nutritionTargets ??
           (nutritionGoals == null
               ? null
               : NutritionTargetAuthority(
                   goals: nutritionGoals,
                   dates: dates ?? LocalScheduleDateService(),
                 )),
       _dates = dates ?? LocalScheduleDateService();

  final AppDatabase _database;
  final WorkoutRepository _workouts;
  final B02MuscleVolumeRepository _muscleVolume;
  final NutritionReadModelRepository? _nutrition;
  final NutritionTargetAuthority? _nutritionTargets;
  final LocalScheduleDateService _dates;

  Future<ProgressDashboardSnapshot> read({
    required DateTime nowUtc,
    required String timezoneId,
  }) async {
    final unavailable = <ProgressDataSection>{};
    final now = nowUtc.toUtc();

    final measurements = await _readSafely(
      section: ProgressDataSection.measurements,
      unavailable: unavailable,
      read: () => _readMeasurements(now, timezoneId),
    );
    final workouts = await _readSafely(
      section: ProgressDataSection.workouts,
      unavailable: unavailable,
      read: () => _readWorkouts(now, timezoneId),
    );
    final strengthSets = await _readSafely(
      section: ProgressDataSection.strength,
      unavailable: unavailable,
      read: () => _readPerformedStrengthSets(now, timezoneId),
    );
    final muscleBalance = await _readSafely(
      section: ProgressDataSection.muscleBalance,
      unavailable: unavailable,
      read: () =>
          _readRecentCompletedMuscleVolume(now: now, timezoneId: timezoneId),
    );
    final nutritionSummary = await _readSafely(
      section: ProgressDataSection.nutrition,
      unavailable: unavailable,
      read: () => _readNutritionSummary(nowUtc: now, timezoneId: timezoneId),
    );

    final today = _dates.localDateFor(now, timezoneId);
    final weekday = _dates.weekday(today, timezoneId);
    final mondayOffset = 1 - weekday;
    final monday = _dates.addCalendarDays(today, timezoneId, mondayOffset);
    final sunday = _dates.addCalendarDays(monday, timezoneId, 6);

    final weeklyTrainedDates = <String>{
      if (workouts != null)
        for (final w in workouts)
          if (_dates.compare(w.localDate, monday) >= 0 &&
              _dates.compare(w.localDate, sunday) <= 0)
            w.localDate,
    };

    final strengthExercises = strengthSets == null
        ? null
        : _buildStrengthExerciseSummaries(strengthSets);

    return ProgressDashboardSnapshot(
      nowUtc: now,
      timezoneId: timezoneId,
      todayLocalDate: today,
      measurements: measurements,
      workouts: workouts,
      strengthSets: strengthSets,
      muscleBalance: muscleBalance,
      unavailableSections: unavailable,
      nutritionSummary: nutritionSummary,
      strengthExercises: strengthExercises,
      weeklyTrainedDates: weeklyTrainedDates,
    );
  }

  Future<T?> _readSafely<T>({
    required ProgressDataSection section,
    required Set<ProgressDataSection> unavailable,
    required Future<T> Function() read,
  }) async {
    try {
      return await read();
    } catch (_) {
      unavailable.add(section);
      return null;
    }
  }

  Future<List<ProgressMeasurementRecord>> _readMeasurements(
    DateTime nowUtc,
    String timezoneId,
  ) async {
    final rows = await _workouts.getBodyMeasurements();
    final result = [
      for (final row in rows)
        if (!row.recordedAt.toUtc().isAfter(nowUtc))
          ProgressMeasurementRecord(
            id: row.id,
            recordedAt: row.recordedAt,
            localDate: _dates.localDateFor(row.recordedAt.toUtc(), timezoneId),
            weightKg: row.weight,
            waistCm: row.waist,
            chestCm: row.chest,
            armsCm: row.arms,
          ),
    ];
    result.sort(_compareMeasurementsNewestFirst);
    return result;
  }

  Future<List<ProgressWorkoutRecord>> _readWorkouts(
    DateTime nowUtc,
    String timezoneId,
  ) async {
    final rows = await _workouts.getSessions();
    final canonicalFacts = await _readCanonicalSessionFacts();
    final result = [
      for (final row in rows)
        if (!row.completedAt.toUtc().isAfter(nowUtc))
          () {
            final facts = canonicalFacts[row.id];
            final volumeIsTrustworthy =
                row.activityType == B02ActivityType.strength.dbValue &&
                facts?.isTrustworthy == true;
            return ProgressWorkoutRecord(
              id: row.id,
              name: row.name,
              completedAtUtc: row.completedAt.toUtc(),
              localDate: _dates.localDateFor(
                row.completedAt.toUtc(),
                timezoneId,
              ),
              activityType: row.activityType,
              totalVolumeKg: volumeIsTrustworthy ? facts!.volumeKg : 0,
              durationSeconds: row.durationSeconds,
              workingSetsCount: facts?.workingSetsCount ?? 0,
              volumeIsTrustworthy: volumeIsTrustworthy,
              completionKind: row.completionKind,
            );
          }(),
    ];
    result.sort((first, second) {
      final byCompletedAt = second.completedAtUtc.compareTo(
        first.completedAtUtc,
      );
      return byCompletedAt != 0 ? byCompletedAt : second.id.compareTo(first.id);
    });
    return result;
  }

  Future<Map<int, _ProgressSessionFacts>> _readCanonicalSessionFacts() async {
    final sets = _database.performedSets;
    final exercises = _database.performedExercises;
    final sessions = _database.workoutSessions;
    final rows =
        await (_database.select(sets).join([
                innerJoin(
                  exercises,
                  exercises.id.equalsExp(sets.performedExerciseId),
                ),
                innerJoin(sessions, sessions.id.equalsExp(exercises.sessionId)),
              ])
              ..where(
                sessions.activityType.equals(B02ActivityType.strength.dbValue),
              )
              ..where(sets.role.equals(B02SetRole.working.dbValue)))
            .get();
    if (rows.isEmpty) return const {};

    final setIds = rows.map((row) => row.readTable(sets).id).toSet();
    final segmentedSetIds = <String>{};
    if (setIds.isNotEmpty) {
      final segments = await (_database.select(
        _database.performedSetSegments,
      )..where((segment) => segment.performedSetId.isIn(setIds))).get();
      segmentedSetIds.addAll(segments.map((segment) => segment.performedSetId));
    }

    final facts = <int, _ProgressSessionFacts>{};
    for (final row in rows) {
      final set = row.readTable(sets);
      final session = row.readTable(sessions);
      final current = facts.putIfAbsent(session.id, _ProgressSessionFacts.new);
      final hasActual =
          set.actualLoadKg != null &&
          set.actualReps != null &&
          set.actualReps! >= 1 &&
          set.actualLoadKg!.isFinite &&
          set.actualLoadKg! >= 0 &&
          set.actualLoadBasis != null;
      if (hasActual) current.workingSetsCount++;

      final hasAnyActualFact =
          set.actualLoadKg != null ||
          set.actualReps != null ||
          set.actualLoadBasis != null;
      if (!hasAnyActualFact) continue;
      if (!hasActual || segmentedSetIds.contains(set.id)) {
        current.isTrustworthy = false;
        continue;
      }
      try {
        final basis = B02LoadBasis.parse(set.actualLoadBasis);
        if (basis != B02LoadBasis.totalExternal) {
          current.isTrustworthy = false;
          continue;
        }
      } on B02ValidationException {
        current.isTrustworthy = false;
        continue;
      }
      current.volumeKg += set.actualLoadKg! * set.actualReps!;
      current.hasExternalSet = true;
    }
    for (final current in facts.values) {
      current.isTrustworthy = current.isTrustworthy && current.hasExternalSet;
    }
    return facts;
  }

  Future<List<ProgressStrengthSetRecord>> _readPerformedStrengthSets(
    DateTime nowUtc,
    String timezoneId,
  ) async {
    final sets = _database.performedSets;
    final exercises = _database.performedExercises;
    final sessions = _database.workoutSessions;
    final rows =
        await (_database.select(sets).join([
                innerJoin(
                  exercises,
                  exercises.id.equalsExp(sets.performedExerciseId),
                ),
                innerJoin(sessions, sessions.id.equalsExp(exercises.sessionId)),
              ])
              ..where(
                sessions.activityType.equals(B02ActivityType.strength.dbValue),
              )
              ..where(sets.role.equals(B02SetRole.working.dbValue))
              ..orderBy([
                OrderingTerm.desc(sessions.completedAt),
                OrderingTerm.asc(exercises.ordinal),
                OrderingTerm.asc(sets.ordinal),
              ]))
            .get();

    final result = <ProgressStrengthSetRecord>[];
    for (final row in rows) {
      final set = row.readTable(sets);
      final exercise = row.readTable(exercises);
      final session = row.readTable(sessions);
      final completedAtUtc = session.completedAt.toUtc();
      final actualLoad = set.actualLoadKg;
      final actualReps = set.actualReps;
      final loadBasis = set.actualLoadBasis;
      if (!const {'full', 'partial'}.contains(session.completionKind) ||
          !const {'completed', 'partial'}.contains(exercise.status) ||
          completedAtUtc.isAfter(nowUtc) ||
          actualLoad == null ||
          actualReps == null ||
          actualReps < 1 ||
          loadBasis == null) {
        continue;
      }
      // The database constraint protects writes, but preserve the fail-closed
      // B02 meaning at this presentation boundary as well.
      try {
        B02LoadBasis.parse(loadBasis);
      } on B02ValidationException {
        continue;
      }
      result.add(
        ProgressStrengthSetRecord(
          performedSetId: set.id,
          exerciseId: exercise.actualExerciseId,
          exerciseName: exercise.actualExerciseNameSnapshot,
          sessionId: session.id,
          performedExerciseId: exercise.id,
          completedAtUtc: completedAtUtc,
          localDate: _dates.localDateFor(completedAtUtc, timezoneId),
          loadKg: actualLoad,
          reps: actualReps,
          loadBasis: loadBasis,
        ),
      );
    }
    return result;
  }

  Future<B02MuscleVolumeReadModel> _readRecentCompletedMuscleVolume({
    required DateTime now,
    required String timezoneId,
  }) {
    final today = _dates.localDateFor(now, timezoneId);
    final endDate = _dates.addCalendarDays(today, timezoneId, -1);
    final startDate = _dates.addCalendarDays(endDate, timezoneId, -27);
    return _muscleVolume.read(
      B02MuscleVolumeQuery(
        startLocalDate: startDate,
        endLocalDate: endDate,
        timezoneId: timezoneId,
      ),
    );
  }

  Future<ProgressNutritionSummary?> _readNutritionSummary({
    required DateTime nowUtc,
    required String timezoneId,
  }) async {
    final nutritionRepo = _nutrition;
    if (nutritionRepo == null) return null;

    final today = _dates.localDateFor(nowUtc, timezoneId);
    final weekday = _dates.weekday(today, timezoneId);
    final mondayOffset = 1 - weekday;
    final monday = _dates.addCalendarDays(today, timezoneId, mondayOffset);

    final daySummaries = <ProgressNutritionDaySummary>[];
    var loggedDays = 0;
    var proteinMetDays = 0;
    var totalCalories = 0.0;
    var totalProtein = 0.0;
    var calorieEvidenceDays = 0;
    var proteinEvidenceDays = 0;
    double? todayTargetCalories;
    double? todayTargetProtein;
    NutritionGoalType? todayTargetGoalType;

    final dates = [
      for (var i = 0; i < 7; i++) _dates.addCalendarDays(monday, timezoneId, i),
    ];
    final readableDates = dates
        .where((date) => _dates.compare(date, today) <= 0)
        .toList(growable: false);
    final dailyModels = await nutritionRepo.dailyTotalsForLocalDates(
      userId: kLocalNutritionUserScopeId,
      localDates: readableDates,
    );

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (var i = 0; i < 7; i++) {
      final date = dates[i];
      final dayLabel = dayLabels[i];
      final isToday = date == today;

      final isFuture = _dates.compare(date, today) > 0;
      if (isFuture) {
        daySummaries.add(
          ProgressNutritionDaySummary(
            localDate: date,
            dayLabel: dayLabel,
            isToday: isToday,
            hasFoodLog: false,
            isProteinTargetMet: false,
            isNutrientIncomplete: false,
          ),
        );
        continue;
      }

      final targets = _nutritionTargets == null
          ? null
          : await _nutritionTargets.resolve(
              NutritionTargetDateQuery(localDate: date, timezoneId: timezoneId),
            );
      final targetCalories = targets?.calorieTargetKcal?.toDouble();
      final targetProtein = targets?.proteinTargetG;
      if (isToday) {
        todayTargetCalories = targetCalories;
        todayTargetProtein = targetProtein;
        todayTargetGoalType = targets?.goalVersion?.goalType;
      }

      final daily = dailyModels[date];
      final hasLogs = daily?.records.isNotEmpty ?? false;
      if (hasLogs) loggedDays++;

      final energyFact = daily?.totals.facts['energy'];
      final proteinFact =
          daily?.totals.facts['protein'] ??
          daily?.totals.facts['macronutrient_protein'];
      final energyComplete = _isCompleteNutrientFact(energyFact);
      final proteinComplete = _isCompleteNutrientFact(proteinFact);
      final calValue = energyComplete
          ? double.tryParse(energyFact!.point!.value.toString())
          : null;
      final protValue = proteinComplete
          ? double.tryParse(proteinFact!.point!.value.toString())
          : null;
      if (calValue != null) {
        totalCalories += calValue;
        calorieEvidenceDays++;
      }
      if (protValue != null) {
        totalProtein += protValue;
        proteinEvidenceDays++;
      }
      final proteinMet =
          protValue != null &&
          targetProtein != null &&
          targetProtein > 0 &&
          protValue >= targetProtein;
      if (proteinMet) proteinMetDays++;

      daySummaries.add(
        ProgressNutritionDaySummary(
          localDate: date,
          dayLabel: dayLabel,
          isToday: isToday,
          caloriesKcal: calValue,
          calorieTargetKcal: targetCalories,
          proteinG: protValue,
          proteinTargetG: targetProtein,
          hasFoodLog: hasLogs,
          isProteinTargetMet: proteinMet,
          isNutrientIncomplete:
              hasLogs &&
              ((!energyComplete && energyFact != null) ||
                  (!proteinComplete && proteinFact != null)),
        ),
      );
    }

    return ProgressNutritionSummary(
      days: daySummaries,
      loggedDaysCount: loggedDays,
      calorieEvidenceDaysCount: calorieEvidenceDays,
      proteinEvidenceDaysCount: proteinEvidenceDays,
      proteinTargetMetDaysCount: proteinMetDays,
      averageCaloriesKcal: calorieEvidenceDays > 0
          ? (totalCalories / calorieEvidenceDays)
          : null,
      averageProteinG: proteinEvidenceDays > 0
          ? (totalProtein / proteinEvidenceDays)
          : null,
      targetCaloriesKcal: todayTargetCalories,
      targetProteinG: todayTargetProtein,
      targetGoalType: todayTargetGoalType,
      hasTarget: daySummaries.any(
        (day) => day.calorieTargetKcal != null || day.proteinTargetG != null,
      ),
    );
  }

  static bool _isCompleteNutrientFact(NutrientFact? fact) =>
      fact != null &&
      fact.point != null &&
      !fact.coverageIncomplete &&
      (fact.status == NutrientFactStatus.known ||
          fact.status == NutrientFactStatus.knownZero);

  static List<ProgressStrengthExerciseSummary> _buildStrengthExerciseSummaries(
    List<ProgressStrengthSetRecord> sets,
  ) {
    if (sets.isEmpty) return const [];
    final groups = <String, List<ProgressStrengthSetRecord>>{};
    for (final set in sets) {
      groups.putIfAbsent(set.exerciseId, () => []).add(set);
    }

    final summaries = <ProgressStrengthExerciseSummary>[];
    for (final entry in groups.entries) {
      final exerciseSets = entry.value;
      exerciseSets.sort(_compareStrengthRecords);
      final latestSet = exerciseSets.last;
      final externalSets = exerciseSets
          .where((set) => set.loadBasis == B02LoadBasis.totalExternal.dbValue)
          .toList(growable: false);
      final bestSet = externalSets.isEmpty
          ? latestSet
          : externalSets.reduce(_heavierStrengthSet);
      final sessionKeys = exerciseSets.map(_strengthSessionKey).toSet();

      summaries.add(
        ProgressStrengthExerciseSummary(
          exerciseId: entry.key,
          exerciseName: latestSet.exerciseName,
          latestSet: latestSet,
          bestSet: bestSet,
          sessionCount: sessionKeys.length,
          comparisonText: _compareLatestStrengthSession(
            exerciseSets,
            latestSet,
          ),
          history: exerciseSets,
        ),
      );
    }

    summaries.sort(
      (first, second) => second.latestSet.completedAtUtc.compareTo(
        first.latestSet.completedAtUtc,
      ),
    );
    return summaries;
  }

  static int _compareStrengthRecords(
    ProgressStrengthSetRecord first,
    ProgressStrengthSetRecord second,
  ) {
    final byTime = first.completedAtUtc.compareTo(second.completedAtUtc);
    if (byTime != 0) return byTime;
    final bySession = (first.sessionId ?? -1).compareTo(second.sessionId ?? -1);
    if (bySession != 0) return bySession;
    return first.performedSetId.compareTo(second.performedSetId);
  }

  static ProgressStrengthSetRecord _heavierStrengthSet(
    ProgressStrengthSetRecord first,
    ProgressStrengthSetRecord second,
  ) {
    if (first.loadKg != second.loadKg) {
      return first.loadKg > second.loadKg ? first : second;
    }
    if (first.reps != second.reps) {
      return first.reps > second.reps ? first : second;
    }
    return _compareStrengthRecords(first, second) > 0 ? first : second;
  }

  static String _strengthSessionKey(ProgressStrengthSetRecord record) =>
      record.sessionId == null
      ? 'date:${record.localDate}'
      : 'session:${record.sessionId}';

  static String? _compareLatestStrengthSession(
    List<ProgressStrengthSetRecord> records,
    ProgressStrengthSetRecord latestSet,
  ) {
    if (latestSet.loadBasis != B02LoadBasis.totalExternal.dbValue) return null;
    final latestSession = _strengthSessionKey(latestSet);
    final latestAtRep = records
        .where(
          (record) =>
              _strengthSessionKey(record) == latestSession &&
              record.loadBasis == B02LoadBasis.totalExternal.dbValue &&
              record.reps == latestSet.reps,
        )
        .toList(growable: false);
    if (latestAtRep.isEmpty) return null;

    final previous = records
        .where(
          (record) =>
              _strengthSessionKey(record) != latestSession &&
              record.loadBasis == B02LoadBasis.totalExternal.dbValue &&
              record.reps == latestSet.reps,
        )
        .toList(growable: true);
    if (previous.isEmpty) return null;
    previous.sort(_compareStrengthRecords);
    final previousSession = _strengthSessionKey(previous.last);
    final previousAtRep = previous
        .where((record) => _strengthSessionKey(record) == previousSession)
        .reduce(_heavierStrengthSet);
    final currentAtRep = latestAtRep.reduce(_heavierStrengthSet);
    final difference = currentAtRep.loadKg - previousAtRep.loadKg;
    if (difference == 0) return null;
    final sign = difference > 0 ? '+' : '';
    return '$sign${_formatNumber(difference)} kg at ${currentAtRep.reps} reps';
  }

  static String _formatNumber(double value) {
    final whole = value.roundToDouble() == value;
    return whole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  static int _compareMeasurementsNewestFirst(
    ProgressMeasurementRecord first,
    ProgressMeasurementRecord second,
  ) {
    final byRecordedAt = second.recordedAt.compareTo(first.recordedAt);
    return byRecordedAt != 0 ? byRecordedAt : second.id.compareTo(first.id);
  }
}

class _ProgressSessionFacts {
  double volumeKg = 0;
  int workingSetsCount = 0;
  bool hasExternalSet = false;
  bool isTrustworthy = true;
}
