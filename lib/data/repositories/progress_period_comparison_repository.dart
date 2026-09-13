import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/nutrients.dart';
import '../../core/nutrition_household_measures.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../features/progress/r08f4_training_volume_presentation.dart';
import '../database/app_database.dart';
import '../models/b02_execution_models.dart';
import '../models/progress_dashboard_models.dart';
import '../models/progress_period_comparison_models.dart';
import 'nutrition_read_model_repository.dart';
import 'nutrition_target_authority.dart';

/// Repository responsible for bounded historical queries and truthful period
/// comparisons (PV1-PROG-01).
///
/// Implements the formal contract in `PROG01A_HISTORICAL_DRILLDOWNS_AND_PERIOD_COMPARISON.md`.
/// Every database read is bounded by civil-date converted UTC timestamps.
/// Nutrition averages strictly respect logged-day denominators.
class ProgressPeriodComparisonRepository {
  ProgressPeriodComparisonRepository({
    required AppDatabase database,
    LocalScheduleDateService? dates,
    NutritionReadModelRepository? nutrition,
    NutritionTargetAuthority? nutritionTargets,
  })  : _database = database,
        _dates = dates ?? LocalScheduleDateService(),
        _nutrition = nutrition,
        _nutritionTargets = nutritionTargets;

  final AppDatabase _database;
  final LocalScheduleDateService _dates;
  final NutritionReadModelRepository? _nutrition;
  final NutritionTargetAuthority? _nutritionTargets;

  /// Loads and computes comparative metrics across two bounded like-for-like periods.
  Future<ProgressPeriodComparisonSnapshot> comparePeriods({
    required PeriodComparisonRange range,
    required DateTime nowUtc,
    required String timezoneId,
  }) async {
    final today = _dates.localDateFor(nowUtc, timezoneId);

    final (currentWindow, previousWindow) = _resolveWindows(
      range: range,
      today: today,
      nowUtc: nowUtc,
      timezoneId: timezoneId,
    );

    // 1. Training metrics across both windows
    final currentWorkouts = await _readBoundedWorkouts(
      window: currentWindow,
      timezoneId: timezoneId,
      nowUtc: nowUtc,
    );
    final previousWorkouts = await _readBoundedWorkouts(
      window: previousWindow,
      timezoneId: timezoneId,
      nowUtc: nowUtc,
    );

    final trainingComparison = _buildTrainingComparison(
      currentWindow: currentWindow,
      previousWindow: previousWindow,
      currentWorkouts: currentWorkouts,
      previousWorkouts: previousWorkouts,
    );

    // 2. Nutrition metrics across both windows
    ComparativeNutritionMetrics? nutritionComparison;
    if (_nutrition != null) {
      try {
        nutritionComparison = await _buildNutritionComparison(
          currentWindow: currentWindow,
          previousWindow: previousWindow,
          today: today,
          nowUtc: nowUtc,
          timezoneId: timezoneId,
        );
      } catch (_) {
        nutritionComparison = null;
      }
    }

    // 3. Body Weight metrics across both windows
    ComparativeWeightMetrics? weightComparison;
    try {
      weightComparison = await _buildWeightComparison(
        currentWindow: currentWindow,
        previousWindow: previousWindow,
        range: range,
      );
    } catch (_) {
      weightComparison = null;
    }

    // 4. Strength exercises comparison
    final strengthComparisons = await _compareStrengthExercises(
      currentWindow: currentWindow,
      previousWindow: previousWindow,
      nowUtc: nowUtc,
      timezoneId: timezoneId,
    );

    return ProgressPeriodComparisonSnapshot(
      range: range,
      timezoneId: timezoneId,
      currentWindow: currentWindow,
      previousWindow: previousWindow,
      trainingComparison: trainingComparison,
      nutritionComparison: nutritionComparison,
      weightComparison: weightComparison,
      strengthComparisons: strengthComparisons,
    );
  }

  (PeriodDateWindow, PeriodDateWindow) _resolveWindows({
    required PeriodComparisonRange range,
    required String today,
    required DateTime nowUtc,
    required String timezoneId,
  }) {
    switch (range) {
      case PeriodComparisonRange.week:
        final weekday = _dates.weekday(today, timezoneId);
        final currentMonday = _dates.addCalendarDays(today, timezoneId, 1 - weekday);
        final currentSunday = _dates.addCalendarDays(currentMonday, timezoneId, 6);
        final previousMonday = _dates.addCalendarDays(currentMonday, timezoneId, -7);
        final previousSunday = _dates.addCalendarDays(previousMonday, timezoneId, 6);

        final (currentStartUtc, currentEndExclusiveUtc) = _toUtcBounds(
          currentMonday,
          currentSunday,
          timezoneId,
        );
        final (prevStartUtc, prevEndExclusiveUtc) = _toUtcBounds(
          previousMonday,
          previousSunday,
          timezoneId,
        );

        final currentWindow = PeriodDateWindow(
          startLocalDate: currentMonday,
          endLocalDate: currentSunday,
          startUtc: currentStartUtc,
          endExclusiveUtc: currentEndExclusiveUtc,
          daysCount: 7,
          status: PeriodCompletenessStatus.inProgress,
          inProgressDayIndex: weekday,
        );

        final previousWindow = PeriodDateWindow(
          startLocalDate: previousMonday,
          endLocalDate: previousSunday,
          startUtc: prevStartUtc,
          endExclusiveUtc: prevEndExclusiveUtc,
          daysCount: 7,
          status: PeriodCompletenessStatus.complete,
        );

        return (currentWindow, previousWindow);

      case PeriodComparisonRange.fourWeeks:
        // Current 28-day training cycle: today - 27 through today
        final currentStart = _dates.addCalendarDays(today, timezoneId, -27);
        final currentEnd = today;

        // Previous 28-day training cycle: today - 55 through today - 28
        final prevStart = _dates.addCalendarDays(today, timezoneId, -55);
        final prevEnd = _dates.addCalendarDays(today, timezoneId, -28);

        final (currentStartUtc, currentEndExclusiveUtc) = _toUtcBounds(
          currentStart,
          currentEnd,
          timezoneId,
        );
        final (prevStartUtc, prevEndExclusiveUtc) = _toUtcBounds(
          prevStart,
          prevEnd,
          timezoneId,
        );

        final currentWindow = PeriodDateWindow(
          startLocalDate: currentStart,
          endLocalDate: currentEnd,
          startUtc: currentStartUtc,
          endExclusiveUtc: currentEndExclusiveUtc,
          daysCount: 28,
          status: PeriodCompletenessStatus.inProgress,
          inProgressDayIndex: 28,
        );

        final previousWindow = PeriodDateWindow(
          startLocalDate: prevStart,
          endLocalDate: prevEnd,
          startUtc: prevStartUtc,
          endExclusiveUtc: prevEndExclusiveUtc,
          daysCount: 28,
          status: PeriodCompletenessStatus.complete,
        );

        return (currentWindow, previousWindow);
    }
  }

  (DateTime, DateTime) _toUtcBounds(
    String startLocalDate,
    String endLocalDate,
    String timezoneId,
  ) {
    final startParts = startLocalDate.split('-').map(int.parse).toList();
    final endParts = endLocalDate.split('-').map(int.parse).toList();
    final loc = _dates.locationFor(timezoneId);

    final tzStart = tz.TZDateTime(loc, startParts[0], startParts[1], startParts[2]);
    final tzEndNextDay = tz.TZDateTime(loc, endParts[0], endParts[1], endParts[2] + 1);

    return (tzStart.toUtc(), tzEndNextDay.toUtc());
  }

  Future<List<ProgressWorkoutRecord>> _readBoundedWorkouts({
    required PeriodDateWindow window,
    required String timezoneId,
    required DateTime nowUtc,
  }) async {
    final tbl = _database.workoutSessions;
    final rows = await (_database.select(tbl)
          ..where((s) =>
              s.completedAt.isBiggerOrEqualValue(window.startUtc) &
              s.completedAt.isSmallerThanValue(window.endExclusiveUtc))
          ..orderBy([(s) => OrderingTerm.desc(s.completedAt)]))
        .get();

    if (rows.isEmpty) return const [];

    final canonicalFacts = await _readCanonicalFactsForWindow(
      startUtc: window.startUtc,
      endExclusiveUtc: window.endExclusiveUtc,
    );

    return [
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
              localDate: _dates.localDateFor(row.completedAt.toUtc(), timezoneId),
              activityType: row.activityType,
              totalVolumeKg: volumeIsTrustworthy ? facts!.volumeKg : 0,
              durationSeconds: row.durationSeconds,
              workingSetsCount: facts?.workingSetsCount ?? 0,
              volumeIsTrustworthy: volumeIsTrustworthy,
              completionKind: row.completionKind,
            );
          }(),
    ];
  }

  Future<Map<int, _SessionFacts>> _readCanonicalFactsForWindow({
    required DateTime startUtc,
    required DateTime endExclusiveUtc,
  }) async {
    final sets = _database.performedSets;
    final exercises = _database.performedExercises;
    final sessions = _database.workoutSessions;

    final rows = await (_database.select(sets).join([
      innerJoin(exercises, exercises.id.equalsExp(sets.performedExerciseId)),
      innerJoin(sessions, sessions.id.equalsExp(exercises.sessionId)),
    ])
          ..where(sessions.completedAt.isBiggerOrEqualValue(startUtc) &
                  sessions.completedAt.isSmallerThanValue(endExclusiveUtc))
          ..where(sessions.activityType.equals(B02ActivityType.strength.dbValue))
          ..where(sets.role.equals(B02SetRole.working.dbValue)))
        .get();

    if (rows.isEmpty) return const {};

    final setIds = rows.map((r) => r.readTable(sets).id).toSet();
    final segmentedSetIds = <String>{};
    if (setIds.isNotEmpty) {
      final segments = await (_database.select(_database.performedSetSegments)
            ..where((seg) => seg.performedSetId.isIn(setIds)))
          .get();
      segmentedSetIds.addAll(segments.map((seg) => seg.performedSetId));
    }

    final facts = <int, _SessionFacts>{};
    for (final row in rows) {
      final s = row.readTable(sets);
      final sess = row.readTable(sessions);
      final current = facts.putIfAbsent(sess.id, _SessionFacts.new);

      final hasActual = s.actualLoadKg != null &&
          s.actualReps != null &&
          s.actualReps! >= 1 &&
          s.actualLoadKg!.isFinite &&
          s.actualLoadKg! >= 0 &&
          s.actualLoadBasis != null;

      if (hasActual) current.workingSetsCount++;

      final hasAnyActualFact =
          s.actualLoadKg != null || s.actualReps != null || s.actualLoadBasis != null;
      if (!hasAnyActualFact) continue;

      if (!hasActual || segmentedSetIds.contains(s.id)) {
        current.isTrustworthy = false;
        continue;
      }

      try {
        final basis = B02LoadBasis.parse(s.actualLoadBasis);
        if (basis != B02LoadBasis.totalExternal) {
          current.isTrustworthy = false;
          continue;
        }
      } catch (_) {
        current.isTrustworthy = false;
        continue;
      }

      current.volumeKg += s.actualLoadKg! * s.actualReps!;
    }
    return facts;
  }

  ComparativeTrainingMetrics _buildTrainingComparison({
    required PeriodDateWindow currentWindow,
    required PeriodDateWindow previousWindow,
    required List<ProgressWorkoutRecord> currentWorkouts,
    required List<ProgressWorkoutRecord> previousWorkouts,
  }) {
    final currentSummary = _summarizeTrainingWindow(currentWindow, currentWorkouts);
    final prevSummary = _summarizeTrainingWindow(previousWindow, previousWorkouts);

    final sessionDelta = currentSummary.sessionCount - prevSummary.sessionCount;
    final sessionPct = prevSummary.sessionCount > 0
        ? (sessionDelta / prevSummary.sessionCount) * 100.0
        : null;

    final dayDelta = currentSummary.trainingDayCount - prevSummary.trainingDayCount;
    final dayPct = prevSummary.trainingDayCount > 0
        ? (dayDelta / prevSummary.trainingDayCount) * 100.0
        : null;

    final volumeDelta = (currentSummary.volumeIsTrustworthy && prevSummary.volumeIsTrustworthy)
        ? currentSummary.totalVolumeKg - prevSummary.totalVolumeKg
        : null;
    final volumePct = (volumeDelta != null && prevSummary.totalVolumeKg > 0)
        ? (volumeDelta / prevSummary.totalVolumeKg) * 100.0
        : null;

    final durationDelta = currentSummary.totalDurationSeconds - prevSummary.totalDurationSeconds;
    final durationPct = prevSummary.totalDurationSeconds > 0
        ? (durationDelta / prevSummary.totalDurationSeconds) * 100.0
        : null;

    return ComparativeTrainingMetrics(
      current: currentSummary,
      previous: prevSummary,
      sessionCountMetric: ComparativeMetric<int>(
        current: currentSummary.sessionCount,
        previous: prevSummary.sessionCount,
        delta: sessionDelta.toDouble(),
        percentChange: sessionPct,
        status: currentWindow.status,
      ),
      trainingDayMetric: ComparativeMetric<int>(
        current: currentSummary.trainingDayCount,
        previous: prevSummary.trainingDayCount,
        delta: dayDelta.toDouble(),
        percentChange: dayPct,
        status: currentWindow.status,
      ),
      volumeMetric: ComparativeMetric<double>(
        current: currentSummary.totalVolumeKg,
        previous: prevSummary.totalVolumeKg,
        delta: volumeDelta,
        percentChange: volumePct,
        status: (currentSummary.volumeIsTrustworthy && prevSummary.volumeIsTrustworthy)
            ? currentWindow.status
            : PeriodCompletenessStatus.sparse,
      ),
      durationMetric: ComparativeMetric<int>(
        current: currentSummary.totalDurationSeconds,
        previous: prevSummary.totalDurationSeconds,
        delta: durationDelta.toDouble(),
        percentChange: durationPct,
        status: currentWindow.status,
      ),
    );
  }

  TrainingPeriodSummary _summarizeTrainingWindow(
    PeriodDateWindow window,
    List<ProgressWorkoutRecord> workouts,
  ) {
    final consistency = R08F4TrainingVolumePresentation.summarizeConsistency(workouts);
    final trustworthyVolumeWorkouts = workouts.where(
      (w) => w.isCanonicalStrength && w.volumeIsTrustworthy && w.totalVolumeKg > 0,
    );
    final totalVolume = trustworthyVolumeWorkouts.fold<double>(
      0.0,
      (sum, w) => sum + w.totalVolumeKg,
    );
    final totalDuration = workouts.fold<int>(
      0,
      (sum, w) => sum + w.durationSeconds,
    );

    return TrainingPeriodSummary(
      window: window,
      sessionCount: consistency.sessionCount,
      trainingDayCount: consistency.trainingDayCount,
      workingSetsCount: consistency.workingSetsCount,
      totalDurationSeconds: totalDuration,
      totalVolumeKg: totalVolume,
      volumeIsTrustworthy: trustworthyVolumeWorkouts.isNotEmpty,
      partialSessionCount: consistency.partialSessionCount,
      fullSessionCount: consistency.sessionCount - consistency.partialSessionCount,
    );
  }

  Future<ComparativeNutritionMetrics?> _buildNutritionComparison({
    required PeriodDateWindow currentWindow,
    required PeriodDateWindow previousWindow,
    required String today,
    required DateTime nowUtc,
    required String timezoneId,
  }) async {
    final nutritionRepo = _nutrition;
    if (nutritionRepo == null) return null;

    final currentSummary = await _readNutritionWindowSummary(
      window: currentWindow,
      today: today,
      nowUtc: nowUtc,
      timezoneId: timezoneId,
    );
    final prevSummary = await _readNutritionWindowSummary(
      window: previousWindow,
      today: today,
      nowUtc: nowUtc,
      timezoneId: timezoneId,
    );

    if (!currentSummary.hasLoggedDays && !prevSummary.hasLoggedDays) {
      return null;
    }

    final caloriesDelta = (currentSummary.averageCaloriesKcal != null &&
            prevSummary.averageCaloriesKcal != null)
        ? currentSummary.averageCaloriesKcal! - prevSummary.averageCaloriesKcal!
        : null;
    final caloriesPct = (caloriesDelta != null && prevSummary.averageCaloriesKcal! > 0)
        ? (caloriesDelta / prevSummary.averageCaloriesKcal!) * 100.0
        : null;

    final proteinDelta = (currentSummary.averageProteinG != null &&
            prevSummary.averageProteinG != null)
        ? currentSummary.averageProteinG! - prevSummary.averageProteinG!
        : null;
    final proteinPct = (proteinDelta != null && prevSummary.averageProteinG! > 0)
        ? (proteinDelta / prevSummary.averageProteinG!) * 100.0
        : null;

    final loggedDaysDelta = currentSummary.loggedDaysCount - prevSummary.loggedDaysCount;

    return ComparativeNutritionMetrics(
      current: currentSummary,
      previous: prevSummary,
      caloriesMetric: ComparativeMetric<double>(
        current: currentSummary.averageCaloriesKcal,
        previous: prevSummary.averageCaloriesKcal,
        delta: caloriesDelta,
        percentChange: caloriesPct,
        status: currentWindow.status,
        evidenceDescription:
            '${currentSummary.loggedDaysCount}/${currentSummary.daysInPeriod} days logged vs ${prevSummary.loggedDaysCount}/${prevSummary.daysInPeriod} days logged',
      ),
      proteinMetric: ComparativeMetric<double>(
        current: currentSummary.averageProteinG,
        previous: prevSummary.averageProteinG,
        delta: proteinDelta,
        percentChange: proteinPct,
        status: currentWindow.status,
        evidenceDescription:
            '${currentSummary.loggedDaysCount}/${currentSummary.daysInPeriod} days logged vs ${prevSummary.loggedDaysCount}/${prevSummary.daysInPeriod} days logged',
      ),
      loggedDaysMetric: ComparativeMetric<int>(
        current: currentSummary.loggedDaysCount,
        previous: prevSummary.loggedDaysCount,
        delta: loggedDaysDelta.toDouble(),
        status: currentWindow.status,
      ),
    );
  }

  Future<NutritionPeriodSummary> _readNutritionWindowSummary({
    required PeriodDateWindow window,
    required String today,
    required DateTime nowUtc,
    required String timezoneId,
  }) async {
    final dates = [
      for (var i = 0; i < window.daysCount; i++)
        _dates.addCalendarDays(window.startLocalDate, timezoneId, i),
    ];

    final readableDates = dates
        .where((d) => _dates.compare(d, today) <= 0)
        .toList(growable: false);

    final dailyModels = await _nutrition!.dailyTotalsForLocalDates(
      userId: kLocalNutritionUserScopeId,
      localDates: readableDates,
    );

    var loggedDays = 0;
    var totalCalories = 0.0;
    var totalProtein = 0.0;
    var proteinTargetMetDays = 0;
    double? targetCalories;
    double? targetProtein;
    var hasTarget = false;

    // Resolve date-scoped target if available
    if (_nutritionTargets != null) {
      try {
        final targets = await _nutritionTargets.resolve(
          NutritionTargetDateQuery(
            localDate: window.endLocalDate,
            timezoneId: timezoneId,
          ),
        );
        if (targets.hasAnyTarget) {
          hasTarget = true;
          targetCalories = targets.calorieTargetKcal?.toDouble();
          targetProtein = targets.proteinTargetG;
        }
      } catch (_) {}
    }

    for (final date in readableDates) {
      final model = dailyModels[date];
      if (model == null) continue;

      final hasLogs = model.records.isNotEmpty;
      if (!hasLogs) continue;

      loggedDays++;
      final energyFact = model.totals.facts['energy'];
      final proteinFact =
          model.totals.facts['protein'] ?? model.totals.facts['macronutrient_protein'];

      final calValue = _isCompleteNutrientFact(energyFact)
          ? double.tryParse(energyFact!.point!.value.toString())
          : null;
      final protValue = _isCompleteNutrientFact(proteinFact)
          ? double.tryParse(proteinFact!.point!.value.toString())
          : null;

      if (calValue != null) totalCalories += calValue;
      if (protValue != null) {
        totalProtein += protValue;
        if (targetProtein != null && protValue >= targetProtein) {
          proteinTargetMetDays++;
        }
      }
    }

    final avgCalories = loggedDays > 0 ? (totalCalories / loggedDays) : null;
    final avgProtein = loggedDays > 0 ? (totalProtein / loggedDays) : null;

    return NutritionPeriodSummary(
      window: window,
      daysInPeriod: window.daysCount,
      loggedDaysCount: loggedDays,
      averageCaloriesKcal: avgCalories,
      averageProteinG: avgProtein,
      targetCaloriesKcal: targetCalories,
      targetProteinG: targetProtein,
      proteinTargetMetDaysCount: proteinTargetMetDays,
      hasTarget: hasTarget,
    );
  }

  static bool _isCompleteNutrientFact(NutrientFact? fact) =>
      fact != null &&
      fact.point != null &&
      !fact.coverageIncomplete &&
      (fact.status == NutrientFactStatus.known ||
          fact.status == NutrientFactStatus.knownZero);

  Future<ComparativeWeightMetrics?> _buildWeightComparison({
    required PeriodDateWindow currentWindow,
    required PeriodDateWindow previousWindow,
    required PeriodComparisonRange range,
  }) async {
    final currentSummary = await _readWeightWindowSummary(currentWindow);
    final prevSummary = await _readWeightWindowSummary(previousWindow);

    if (!currentSummary.hasObservations && !prevSummary.hasObservations) {
      return null;
    }

    double? deltaBetweenPeriods;
    if (currentSummary.latestWeightKg != null && prevSummary.latestWeightKg != null) {
      deltaBetweenPeriods = currentSummary.latestWeightKg! - prevSummary.latestWeightKg!;
    }

    double? ratePerWeek;
    if (deltaBetweenPeriods != null) {
      switch (range) {
        case PeriodComparisonRange.week:
          ratePerWeek = deltaBetweenPeriods;
          break;
        case PeriodComparisonRange.fourWeeks:
          ratePerWeek = deltaBetweenPeriods / 4.0;
          break;
      }
    }

    final completeness = (currentSummary.hasObservations && prevSummary.hasObservations)
        ? currentWindow.status
        : PeriodCompletenessStatus.sparse;

    return ComparativeWeightMetrics(
      current: currentSummary,
      previous: prevSummary,
      weightDeltaBetweenPeriodsKg: deltaBetweenPeriods,
      ratePerWeekKg: ratePerWeek,
      completeness: completeness,
    );
  }

  Future<WeightPeriodSummary> _readWeightWindowSummary(PeriodDateWindow window) async {
    final tbl = _database.bodyMeasurements;
    final rows = await (_database.select(tbl)
          ..where((m) =>
              m.recordedAt.isBiggerOrEqualValue(window.startUtc) &
              m.recordedAt.isSmallerThanValue(window.endExclusiveUtc) &
              m.weight.isNotNull())
          ..orderBy([(m) => OrderingTerm.asc(m.recordedAt)]))
        .get();

    final weights = rows.map((r) => r.weight!).where((w) => w > 0).toList();
    if (weights.isEmpty) {
      return WeightPeriodSummary(
        window: window,
        observationCount: 0,
      );
    }

    final first = weights.first;
    final latest = weights.last;
    final delta = weights.length >= 2 ? latest - first : null;
    final sum = weights.fold<double>(0.0, (acc, w) => acc + w);
    final avg = sum / weights.length;
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);

    return WeightPeriodSummary(
      window: window,
      observationCount: weights.length,
      firstWeightKg: first,
      latestWeightKg: latest,
      deltaKg: delta,
      averageWeightKg: avg,
      minWeightKg: minW,
      maxWeightKg: maxW,
    );
  }

  Future<List<StrengthExercisePeriodComparison>> _compareStrengthExercises({
    required PeriodDateWindow currentWindow,
    required PeriodDateWindow previousWindow,
    required DateTime nowUtc,
    required String timezoneId,
  }) async {
    final currentExerciseData = await _readExerciseDataForWindow(
      startUtc: currentWindow.startUtc,
      endExclusiveUtc: currentWindow.endExclusiveUtc,
    );
    final prevExerciseData = await _readExerciseDataForWindow(
      startUtc: previousWindow.startUtc,
      endExclusiveUtc: previousWindow.endExclusiveUtc,
    );

    final exerciseIds = <String>{
      ...currentExerciseData.keys,
      ...prevExerciseData.keys,
    };

    final comparisons = <StrengthExercisePeriodComparison>[];
    for (final exerciseId in exerciseIds) {
      final current = currentExerciseData[exerciseId];
      final previous = prevExerciseData[exerciseId];
      final name = current?.name ?? previous?.name ?? 'Exercise';

      comparisons.add(
        StrengthExercisePeriodComparison(
          exerciseId: exerciseId,
          exerciseName: name,
          currentHeaviestLoadKg: current?.heaviestLoadKg,
          currentHeaviestReps: current?.heaviestReps,
          previousHeaviestLoadKg: previous?.heaviestLoadKg,
          previousHeaviestReps: previous?.heaviestReps,
          currentVolumeKg: current?.volumeKg ?? 0.0,
          previousVolumeKg: previous?.volumeKg ?? 0.0,
          currentSetCount: current?.setCount ?? 0,
          previousSetCount: previous?.setCount ?? 0,
        ),
      );
    }

    // Rank by current volume, then total volume
    comparisons.sort((a, b) {
      final byCurrVol = b.currentVolumeKg.compareTo(a.currentVolumeKg);
      if (byCurrVol != 0) return byCurrVol;
      return (b.currentVolumeKg + b.previousVolumeKg)
          .compareTo(a.currentVolumeKg + a.previousVolumeKg);
    });

    return comparisons;
  }

  Future<Map<String, _ExerciseWindowData>> _readExerciseDataForWindow({
    required DateTime startUtc,
    required DateTime endExclusiveUtc,
  }) async {
    final sets = _database.performedSets;
    final exercises = _database.performedExercises;
    final sessions = _database.workoutSessions;

    final rows = await (_database.select(sets).join([
      innerJoin(exercises, exercises.id.equalsExp(sets.performedExerciseId)),
      innerJoin(sessions, sessions.id.equalsExp(exercises.sessionId)),
    ])
          ..where(sessions.completedAt.isBiggerOrEqualValue(startUtc) &
                  sessions.completedAt.isSmallerThanValue(endExclusiveUtc))
          ..where(sessions.activityType.equals(B02ActivityType.strength.dbValue))
          ..where(sets.role.equals(B02SetRole.working.dbValue)))
        .get();

    final data = <String, _ExerciseWindowData>{};
    for (final row in rows) {
      final s = row.readTable(sets);
      final e = row.readTable(exercises);

      if (s.actualLoadBasis != 'totalExternal' ||
          s.actualLoadKg == null ||
          s.actualReps == null ||
          s.actualReps! < 1) {
        continue;
      }

      final item = data.putIfAbsent(
        e.actualExerciseId,
        () => _ExerciseWindowData(name: e.actualExerciseNameSnapshot),
      );

      item.setCount++;
      item.volumeKg += s.actualLoadKg! * s.actualReps!;

      if (item.heaviestLoadKg == null || s.actualLoadKg! > item.heaviestLoadKg!) {
        item.heaviestLoadKg = s.actualLoadKg!;
        item.heaviestReps = s.actualReps!;
      }
    }
    return data;
  }
}

class _SessionFacts {
  int workingSetsCount = 0;
  double volumeKg = 0.0;
  bool isTrustworthy = true;
}

class _ExerciseWindowData {
  _ExerciseWindowData({required this.name});
  final String name;
  int setCount = 0;
  double volumeKg = 0.0;
  double? heaviestLoadKg;
  int? heaviestReps;
}
