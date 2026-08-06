import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../models/b02_progress_read_models.dart';
import '../models/b04_adaptive_target_models.dart';
import '../models/b04_briefing_read_models.dart';
import '../models/b04_current_food_models.dart';
import '../models/b04_goal_models.dart';
import '../models/b04_nutrition_safety_models.dart';
import '../models/b04_recommendation_context_models.dart';
import '../models/b04_recommendation_history_models.dart';
import '../models/b04_recommendation_models.dart';
import '../models/b04_recovery_models.dart';
import '../repositories/b02_progress_read_repository.dart';
import '../repositories/b04_briefing_read_repositories.dart';
import '../repositories/b04_recommendation_history_repository.dart';
import '../repositories/calendar_read_repository.dart';
import '../repositories/coaching_preference_repository.dart';
import '../repositories/nutrition_constraint_repository.dart';
import '../repositories/nutrition_goal_repository.dart';
import '../repositories/nutrition_read_model_repository.dart';
import '../repositories/nutrition_recipe_log_coordinator.dart';
import '../repositories/nutrition_recipe_repository.dart';
import '../repositories/nutrition_thali_repository.dart';
import '../repositories/readiness_snapshot_repository.dart';
import 'b04_adaptive_target_engine.dart';
import 'b04_current_food_guidance_service.dart';
import 'b04_meal_opportunity_service.dart';
import 'b04_nutrition_safety_filter.dart';
import 'b04_recommendation_context_assembler.dart';
import 'b04_recommendation_engine.dart';

class B04ProductionCurrentFoodResult {
  final B04RecommendationContext context;
  final List<B04CurrentFoodCandidateInput> candidates;
  final B04CurrentFoodGuidance guidance;

  const B04ProductionCurrentFoodResult({
    required this.context,
    required this.candidates,
    required this.guidance,
  });
}

class B04ProductionRecommendationOrchestrator {
  final NutritionGoalRepository _goals;
  final CoachingPreferenceRepository _preferences;
  final NutritionReadModelRepository _nutrition;
  final NutritionConstraintRepository _constraints;
  final NutritionRecipeRepository _recipes;
  final NutritionRecipeLogCoordinator _recipeLogging;
  final NutritionThaliRepository _thalis;
  final ReadinessSnapshotRepository _readiness;
  final B02ProgressReadRepository _progress;
  final CalendarReadRepository _calendar;
  final B04AdaptiveTargetEngine _targetEngine;
  final B04RecommendationContextAssembler _assembler;
  final B04RecommendationHistoryRepository _history;
  final B04DailyBriefingReadRepository _dailyRead;
  final B04WeeklyReviewReadRepository _weeklyRead;
  final B04CurrentFoodGuidanceService _currentFood;
  final B04MealOpportunityService _opportunities;
  final B04NutritionSafetyFilter _safety;
  final B04RecommendationEngine _engine;
  final NutrientRegistry _registry;
  final LocalScheduleDateService _dates;
  final DateTime Function() _nowUtc;
  final B04ActivationMetadata _activation;
  final Map<String, Future<B04ProductionCurrentFoodResult>> _currentRuns = {};
  final Map<String, Future<_ProductionPeriod>> _coachingRuns = {};

  B04ProductionRecommendationOrchestrator({
    required NutritionGoalRepository goals,
    required CoachingPreferenceRepository preferences,
    required NutritionReadModelRepository nutrition,
    required NutritionConstraintRepository constraints,
    required NutritionRecipeRepository recipes,
    required NutritionRecipeLogCoordinator recipeLogging,
    required NutritionThaliRepository thalis,
    required ReadinessSnapshotRepository readiness,
    required B02ProgressReadRepository progress,
    required CalendarReadRepository calendar,
    required B04AdaptiveTargetEngine targetEngine,
    required B04RecommendationContextAssembler assembler,
    required B04RecommendationHistoryRepository history,
    required B04DailyBriefingReadRepository dailyRead,
    required B04WeeklyReviewReadRepository weeklyRead,
    required B04CurrentFoodGuidanceService currentFood,
    required B04MealOpportunityService opportunities,
    required B04NutritionSafetyFilter safety,
    required NutrientRegistry registry,
    LocalScheduleDateService? dates,
    B04RecommendationEngine engine = const B04RecommendationEngine(),
    DateTime Function()? nowUtc,
    B04ActivationMetadata activation = const B04ActivationMetadata(),
  }) : _goals = goals,
       _preferences = preferences,
       _nutrition = nutrition,
       _constraints = constraints,
       _recipes = recipes,
       _recipeLogging = recipeLogging,
       _thalis = thalis,
       _readiness = readiness,
       _progress = progress,
       _calendar = calendar,
       _targetEngine = targetEngine,
       _assembler = assembler,
       _history = history,
       _dailyRead = dailyRead,
       _weeklyRead = weeklyRead,
       _currentFood = currentFood,
       _opportunities = opportunities,
       _safety = safety,
       _engine = engine,
       _registry = registry,
       _dates = dates ?? LocalScheduleDateService(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _activation = activation;

  Future<B04RecommendationContext> loadCurrentFoodContext({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) async {
    final result = await loadCurrentFood(
      userId: userId,
      localDate: localDate,
      timezoneId: timezoneId,
    );
    return result.context;
  }

  Future<B04ProductionCurrentFoodResult> loadCurrentFood({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) async {
    final owner = userId.trim();
    final date = _dates.normalizeLocalDate(localDate);
    final zone = timezoneId.trim();
    _dates.validateTimezone(zone);
    final key = 'current-food:$owner:$date:$zone';
    final existing = _currentRuns[key];
    if (existing != null) return existing;
    final future = _loadCurrentFood(
      userId: owner,
      localDate: date,
      timezoneId: zone,
    );
    _currentRuns[key] = future;
    try {
      return await future;
    } catch (_) {
      final removed = _currentRuns.remove(key);
      if (removed != null) {
        unawaited(removed.then<void>((_) {}, onError: (error, stackTrace) {}));
      }
      rethrow;
    }
  }

  Future<B04ProductionCurrentFoodResult> reloadCurrentFood({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) async {
    final key = _currentFoodKey(
      userId: userId,
      localDate: localDate,
      timezoneId: timezoneId,
    );
    final removedFuture = _currentRuns.remove(key);
    if (removedFuture != null) {
      unawaited(
        removedFuture.then<void>((_) {}, onError: (error, stackTrace) {}),
      );
    }
    return loadCurrentFood(
      userId: userId,
      localDate: localDate,
      timezoneId: timezoneId,
    );
  }

  Future<B04BriefingReadModel> loadDaily({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) async {
    final period = await _loadCoachingPeriod(
      scope: B04RecommendationHistoryScope.daily,
      userId: userId,
      startLocalDate: localDate,
      endLocalDate: localDate,
      timezoneId: timezoneId,
    );
    final issued = await _issueIfAllowed(period);
    if (issued) {
      return _dailyRead.read(
        userId: userId,
        localDate: period.context.window.startLocalDate,
        timezoneId: timezoneId,
      );
    }
    return _dailyRead.projectEvaluation(
      evaluation: period.evaluation,
      historyRows: period.periodRows,
    );
  }

  Future<B04BriefingReadModel> loadWeekly({
    required String userId,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) async {
    final period = await _loadCoachingPeriod(
      scope: B04RecommendationHistoryScope.weekly,
      userId: userId,
      startLocalDate: startLocalDate,
      endLocalDate: endLocalDate,
      timezoneId: timezoneId,
    );
    final issued = await _issueIfAllowed(period);
    if (issued) {
      return _weeklyRead.read(
        userId: userId,
        startLocalDate: period.context.window.startLocalDate,
        endLocalDate: period.context.window.endLocalDate,
        timezoneId: timezoneId,
      );
    }
    return _weeklyRead.projectEvaluation(
      evaluation: period.evaluation,
      historyRows: period.periodRows,
    );
  }

  Future<B04ProductionCurrentFoodResult> _loadCurrentFood({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) async {
    final period = await _buildReplayablePeriod(
      scope: B04RecommendationHistoryScope.mealOpportunity,
      userId: userId,
      startLocalDate: localDate,
      endLocalDate: localDate,
      timezoneId: timezoneId,
      includeMealCandidates: true,
    );
    await _issueIfAllowed(period);
    final guidance =
        period.guidance ??
        _currentFood.evaluate(
          context: period.context,
          candidates: period.candidates,
        );
    return B04ProductionCurrentFoodResult(
      context: period.context,
      candidates: period.candidates,
      guidance: guidance,
    );
  }

  Future<_ProductionPeriod> _buildReplayablePeriod({
    required B04RecommendationHistoryScope scope,
    required String userId,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
    required bool includeMealCandidates,
  }) async {
    final owner = userId.trim();
    final start = _dates.normalizeLocalDate(startLocalDate);
    final end = _dates.normalizeLocalDate(endLocalDate);
    final zone = timezoneId.trim();
    _dates.validateTimezone(zone);
    final now = _evaluationTimestamp(_nowUtc().toUtc());
    final initial = await _buildPeriod(
      scope: scope,
      userId: owner,
      startLocalDate: start,
      endLocalDate: end,
      timezoneId: zone,
      evaluationAtUtc: now,
      sourceAtUtc: now,
      includeMealCandidates: includeMealCandidates,
    );
    final rows = initial.periodRows;
    final replayRows = rows.toList(growable: false)
      ..sort((left, right) {
        final time = right.createdAtUtc.compareTo(left.createdAtUtc);
        return time == 0 ? right.id.compareTo(left.id) : time;
      });
    for (final replayRow in replayRows) {
      final replay = await _buildPeriod(
        scope: scope,
        userId: owner,
        startLocalDate: start,
        endLocalDate: end,
        timezoneId: zone,
        evaluationAtUtc: replayRow.createdAtUtc,
        sourceAtUtc: now,
        includeMealCandidates: includeMealCandidates,
        existingRows: rows,
      );
      if (replay.evaluation.contextFingerprint ==
          replayRow.contextFingerprint) {
        return replay;
      }
    }
    if (rows.isNotEmpty &&
        !initial.evaluation.evaluatedAtUtc.isAfter(
          rows.map((row) => row.createdAtUtc).reduce(_later),
        )) {
      final next = rows
          .map((row) => row.createdAtUtc)
          .reduce(_later)
          .add(const Duration(seconds: 1));
      return _buildPeriod(
        scope: scope,
        userId: owner,
        startLocalDate: start,
        endLocalDate: end,
        timezoneId: zone,
        evaluationAtUtc: next,
        sourceAtUtc: now,
        includeMealCandidates: includeMealCandidates,
        existingRows: rows,
      );
    }
    return initial;
  }

  Future<_ProductionPeriod> _buildCoachingPeriod({
    required B04RecommendationHistoryScope scope,
    required String userId,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) async {
    return _buildReplayablePeriod(
      scope: scope,
      userId: userId,
      startLocalDate: startLocalDate,
      endLocalDate: endLocalDate,
      timezoneId: timezoneId,
      includeMealCandidates: false,
    );
  }

  Future<_ProductionPeriod> _loadCoachingPeriod({
    required B04RecommendationHistoryScope scope,
    required String userId,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) async {
    final owner = userId.trim();
    final start = _dates.normalizeLocalDate(startLocalDate);
    final end = _dates.normalizeLocalDate(endLocalDate);
    final zone = timezoneId.trim();
    _dates.validateTimezone(zone);
    final key = '${scope.stableId}:$owner:$start:$end:$zone';
    final existing = _coachingRuns[key];
    if (existing != null) return existing;
    final future = _buildCoachingPeriod(
      scope: scope,
      userId: owner,
      startLocalDate: start,
      endLocalDate: end,
      timezoneId: zone,
    );
    _coachingRuns[key] = future;
    try {
      return await future;
    } catch (_) {
      if (identical(_coachingRuns[key], future)) {
        final removedFuture = _coachingRuns.remove(key);
        assert(removedFuture == null || identical(removedFuture, future));
      }
      rethrow;
    }
  }

  String _currentFoodKey({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) {
    final owner = userId.trim();
    final date = _dates.normalizeLocalDate(localDate);
    final zone = timezoneId.trim();
    _dates.validateTimezone(zone);
    return 'current-food:$owner:$date:$zone';
  }

  Future<_ProductionPeriod> _buildPeriod({
    required B04RecommendationHistoryScope scope,
    required String userId,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
    required DateTime evaluationAtUtc,
    required DateTime sourceAtUtc,
    required bool includeMealCandidates,
    List<B04HistoricalRecommendation>? existingRows,
  }) async {
    final periodRows =
        existingRows ??
        await _periodRows(
          userId: userId,
          scope: scope,
          startLocalDate: startLocalDate,
          endLocalDate: endLocalDate,
          timezoneId: timezoneId,
        );
    final sources = await _loadSources(
      userId: userId,
      startLocalDate: startLocalDate,
      endLocalDate: endLocalDate,
      timezoneId: timezoneId,
      atUtc: sourceAtUtc,
    );
    final candidates = includeMealCandidates
        ? await _loadCurrentFoodCandidates(
            userId: userId,
            localDate: endLocalDate,
            atUtc: sourceAtUtc,
            constraints: sources.constraints,
            day: sources.nutritionDays
                .where((item) => item.localDate == endLocalDate)
                .firstOrNull,
          )
        : const _ProductionCandidateSet.empty();
    final target = _targetEngine.evaluate(
      B04AdaptiveTargetRequest(
        evaluationId: 'b04-${scope.stableId}:$startLocalDate:$endLocalDate',
        userId: userId,
        evaluationLocalDate: endLocalDate,
        timezoneId: timezoneId,
        evaluatedAtUtc: evaluationAtUtc,
        explicitlyInitiated: true,
        adaptiveConsentEnabled:
            sources.preferences?.adaptiveCoachingEnabled == true,
        offline: true,
        storedPolicyVersion: _activation.policyVersion == kB04HoldPolicyVersion
            ? kB04HoldPolicyVersion
            : null,
        activation: _activation,
        eligibility: sources.eligibility,
        activeGoal: sources.activeGoal,
        goalRate: _goalRate(sources.activeGoal),
        bodyMetrics: null,
        maintenanceEvidence: null,
        nutritionDays: const [],
        weightObservations: const [],
        history: const [],
      ),
    );
    final opportunity = includeMealCandidates
        ? _opportunities.create(
            currentInstantUtc: evaluationAtUtc,
            timezoneId: timezoneId,
            kind: B04MealOpportunityKind.now,
            candidates: candidates.selections,
          )
        : null;
    final context = _assembler.assemble(
      B04RecommendationContextInput(
        contextId: _contextId(
          scope: scope,
          startLocalDate: startLocalDate,
          endLocalDate: endLocalDate,
          timezoneId: timezoneId,
        ),
        userId: userId,
        period: scope == B04RecommendationHistoryScope.weekly
            ? B04RecommendationPeriod.weekly
            : B04RecommendationPeriod.daily,
        startLocalDate: startLocalDate,
        endLocalDate: endLocalDate,
        timezoneId: timezoneId,
        evaluatedAtUtc: evaluationAtUtc,
        activeGoal: sources.activeGoal,
        preferences: sources.preferences,
        eligibility: sources.eligibility,
        readinessSnapshot: sources.readiness,
        progress: sources.progress,
        schedule: sources.schedule,
        nutritionDays: sources.nutritionDays,
        constraintEvaluations: includeMealCandidates
            ? candidates.constraintEvaluations
            : const [],
        targetResult: target,
        mealOpportunity: opportunity,
      ),
    );
    final guidance = includeMealCandidates
        ? _currentFood.evaluate(context: context, candidates: candidates.inputs)
        : null;
    final evaluation =
        guidance?.recommendationEvaluation ??
        _engine.evaluate(
          context: context,
          candidates: includeMealCandidates
              ? const []
              : [
                  _targetCandidate(
                    target: target,
                    scope: scope,
                    contextUserId: userId,
                  ),
                ],
          scope: includeMealCandidates
              ? B04RecommendationEvaluationScope.mealOpportunity
              : B04RecommendationEvaluationScope.coaching,
        );
    return _ProductionPeriod(
      scope: scope,
      context: context,
      evaluation: evaluation,
      guidance: guidance,
      candidates: candidates.inputs,
      periodRows: periodRows,
    );
  }

  Future<_ProductionSources> _loadSources({
    required String userId,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
    required DateTime atUtc,
  }) async {
    final activeGoal = await _readOrNull(
      () => _goals.activeGoal(
        userId: userId,
        localDate: endLocalDate,
        timezoneId: timezoneId,
      ),
    );
    final preferences = await _readOrNull(
      () => _preferences.currentPreferences(userId: userId, atUtc: atUtc),
    );
    final eligibility = await _readOrNull(
      () => _preferences.currentEligibility(userId: userId, atUtc: atUtc),
    );
    final readiness = await _readOrNull(
      () => _readiness.latestForLocalDate(
        userId: userId,
        localDate: endLocalDate,
        timezoneId: timezoneId,
      ),
    );
    final progress = await _readOrNull(
      () => _progress.read(
        B02ProgressQuery(
          startLocalDate: startLocalDate,
          endLocalDate: endLocalDate,
          timezoneId: timezoneId,
        ),
      ),
    );
    final schedule = await _readOrNull(
      () => _calendar.readSnapshot(
        startLocalDate: startLocalDate,
        endLocalDate: endLocalDate,
        timezoneId: timezoneId,
      ),
    );
    final nutritionDays = <NutritionDailyReadModel>[];
    var cursor = startLocalDate;
    while (true) {
      final day = await _readOrNull(
        () => _nutrition.dailyTotals(userId: userId, localDate: cursor),
      );
      if (day != null) nutritionDays.add(day);
      if (cursor == endLocalDate) break;
      cursor = _dates.addCalendarDays(cursor, timezoneId, 1);
    }
    final constraints = await _readOrNull(
      () => _constraints.listActiveConstraints(userId: userId, atUtc: atUtc),
    );
    return _ProductionSources(
      activeGoal: activeGoal,
      preferences: preferences,
      eligibility: eligibility,
      readiness: readiness,
      progress: progress,
      schedule: schedule,
      nutritionDays: List.unmodifiable(nutritionDays),
      constraints: constraints ?? const [],
    );
  }

  Future<_ProductionCandidateSet> _loadCurrentFoodCandidates({
    required String userId,
    required String localDate,
    required DateTime atUtc,
    required List<NutritionUserConstraint> constraints,
    required NutritionDailyReadModel? day,
  }) async {
    final inputs = <B04CurrentFoodCandidateInput>[];
    final evaluations = <NutritionConstraintEvaluationResult>[];
    final selectionIds = <String>{};
    if (day != null) {
      for (final record in day.records) {
        if (record.isLegacy) continue;
        for (final item in record.items) {
          final sourceId = '${record.stableId}:${item.stableId}';
          if (item.foodId != null) {
            final selectionId = 'canonical-food:$sourceId';
            if (!selectionIds.add(selectionId)) continue;
            try {
              final nutrientEvidence = _aggregateFacts(item.facts);
              final evaluation = await _constraints.evaluateFood(
                userId: userId,
                foodId: item.foodId!,
                atUtc: atUtc,
              );
              inputs.add(
                _candidateInput(
                  selectionId: selectionId,
                  source: B04MealCandidateSource.canonicalFood,
                  subjectId: item.foodId!,
                  displayLabel: item.displayLabel ?? 'Canonical food',
                  userId: userId,
                  nutrientEvidence: nutrientEvidence,
                  evaluation: evaluation,
                  constraints: constraints,
                  identityReference: 'food:${item.foodId}',
                  nutrientReference: 'snapshot-item:${item.stableId}',
                ),
              );
              evaluations.add(evaluation);
            } catch (_) {
              inputs.add(
                _unavailableCandidate(
                  selectionId: selectionId,
                  source: B04MealCandidateSource.canonicalFood,
                  subjectId: item.foodId!,
                  displayLabel: item.displayLabel ?? 'Canonical food',
                  userId: userId,
                  errorCode: 'food_evidence_unavailable',
                  identityReference: 'food:${item.foodId}',
                  nutrientReference: 'snapshot-item:${item.stableId}',
                ),
              );
            }
          } else if (item.recipeVersionId != null) {
            final selectionId = 'canonical-recipe:$sourceId';
            if (!selectionIds.add(selectionId)) continue;
            try {
              final nutrientEvidence = _aggregateFacts(item.facts);
              final evaluation = await _constraints.evaluateRecipeVersion(
                userId: userId,
                recipeVersionId: item.recipeVersionId!,
                atUtc: atUtc,
              );
              inputs.add(
                _candidateInput(
                  selectionId: selectionId,
                  source: B04MealCandidateSource.publishedRecipeVersion,
                  subjectId: item.recipeVersionId!,
                  displayLabel: item.displayLabel ?? 'Published recipe',
                  userId: userId,
                  nutrientEvidence: nutrientEvidence,
                  evaluation: evaluation,
                  constraints: constraints,
                  identityReference: 'recipe-version:${item.recipeVersionId}',
                  nutrientReference: 'snapshot-item:${item.stableId}',
                ),
              );
              evaluations.add(evaluation);
            } catch (_) {
              inputs.add(
                _unavailableCandidate(
                  selectionId: selectionId,
                  source: B04MealCandidateSource.publishedRecipeVersion,
                  subjectId: item.recipeVersionId!,
                  displayLabel: item.displayLabel ?? 'Published recipe',
                  userId: userId,
                  errorCode: 'recipe_evidence_unavailable',
                  identityReference: 'recipe-version:${item.recipeVersionId}',
                  nutrientReference: 'snapshot-item:${item.stableId}',
                ),
              );
            }
          }
        }
      }
    }
    final recipeOptions = await _readOrNull(
      () => _thalis.searchRecipes(userId: userId),
    );
    for (final option in recipeOptions ?? const []) {
      final selectionId = 'saved-recipe:${option.recipeVersionId}';
      if (!selectionIds.add(selectionId)) continue;
      final displayLabel = option.recipeName.trim().isEmpty
          ? 'Saved recipe'
          : option.recipeName;
      try {
        final version = await _recipes.getVersion(option.recipeVersionId);
        if (version == null ||
            version.status != NutritionRecipeVersionStatus.published) {
          throw const NutritionRecipeVersionNotFoundError(
            'Published recipe version is unavailable.',
          );
        }
        final amount = version.servingDefinition == null
            ? NutritionRecipeLogAmount.wholeRecipe()
            : NutritionRecipeLogAmount.declaredServing();
        final preview = await _recipeLogging.preview(
          userId: userId,
          recipeId: option.recipeId,
          recipeVersionId: option.recipeVersionId,
          amount: amount,
        );
        final nutrientEvidence = _aggregateFacts(preview.calculation.facts);
        final evaluation = await _constraints.evaluateRecipeVersion(
          userId: userId,
          recipeVersionId: option.recipeVersionId,
          atUtc: atUtc,
        );
        inputs.add(
          _candidateInput(
            selectionId: selectionId,
            source: B04MealCandidateSource.publishedRecipeVersion,
            subjectId: option.recipeVersionId,
            displayLabel: displayLabel,
            userId: userId,
            nutrientEvidence: nutrientEvidence,
            evaluation: evaluation,
            constraints: constraints,
            identityReference: 'recipe-version:${option.recipeVersionId}',
            nutrientReference:
                'recipe-calculation:${preview.calculation.lineage.fingerprint}',
          ),
        );
        evaluations.add(evaluation);
      } catch (_) {
        inputs.add(
          _unavailableCandidate(
            selectionId: selectionId,
            source: B04MealCandidateSource.publishedRecipeVersion,
            subjectId: option.recipeVersionId,
            displayLabel: displayLabel,
            userId: userId,
            errorCode: 'recipe_evidence_unavailable',
            identityReference: 'recipe-version:${option.recipeVersionId}',
            nutrientReference: 'recipe-version:${option.recipeVersionId}',
          ),
        );
      }
    }
    final drafts = await _readOrNull(() => _thalis.listDrafts(userId: userId));
    for (final draft in drafts ?? const []) {
      final selectionId = 'saved-thali:${draft.id}:${draft.currentVersion}';
      if (!selectionIds.add(selectionId)) continue;
      try {
        final preview = await _thalis.preview(
          draft: draft,
          evaluatedAtUtc: atUtc,
        );
        final evaluation = preview.constraintEvaluation;
        if (evaluation == null) {
          throw const NutritionConstraintValidationError(
            'missing_thali_constraint_evaluation',
            'A saved thali requires a B03 constraint evaluation.',
          );
        }
        inputs.add(
          _candidateInput(
            selectionId: selectionId,
            source: B04MealCandidateSource.savedThali,
            subjectId: draft.id,
            displayLabel: draft.name,
            userId: userId,
            nutrientEvidence: preview.aggregate,
            evaluation: evaluation,
            constraints: constraints,
            identityReference: 'thali:${draft.id}:${draft.currentVersion}',
            nutrientReference: 'thali:${draft.compositionFingerprint}',
          ),
        );
        evaluations.add(evaluation);
      } catch (_) {
        inputs.add(
          _unavailableCandidate(
            selectionId: selectionId,
            source: B04MealCandidateSource.savedThali,
            subjectId: draft.id,
            displayLabel: draft.name,
            userId: userId,
            errorCode: 'thali_evidence_unavailable',
            identityReference: 'thali:${draft.id}:${draft.currentVersion}',
            nutrientReference: 'thali:${draft.id}:${draft.currentVersion}',
          ),
        );
      }
    }
    return _ProductionCandidateSet(
      inputs: List.unmodifiable(inputs),
      selections: List.unmodifiable(inputs.map((item) => item.selection)),
      constraintEvaluations: List.unmodifiable(evaluations),
    );
  }

  B04CurrentFoodCandidateInput _candidateInput({
    required String selectionId,
    required B04MealCandidateSource source,
    required String subjectId,
    required String displayLabel,
    required String userId,
    required NutrientAggregationResult? nutrientEvidence,
    required NutritionConstraintEvaluationResult evaluation,
    required List<NutritionUserConstraint> constraints,
    required String identityReference,
    required String nutrientReference,
  }) {
    final safety = _safety.mapEvaluation(
      evaluation: evaluation,
      output: B04NutritionSafetyOutput.eatNow,
      nutrientEvidence: nutrientEvidence,
      constraints: constraints,
    );
    final selection = B04MealCandidate(
      selectionId: selectionId,
      source: source,
      subjectId: subjectId,
      evidence: B04MealCandidateEvidence.complete(
        identityReference: identityReference,
        nutrientReference: nutrientReference,
        constraintReference: _constraintReference(evaluation),
      ),
    );
    return B04CurrentFoodCandidateInput(
      selection: selection,
      displayLabel: displayLabel,
      nutrientEvidence: nutrientEvidence,
      safety: safety,
      evidenceIds: [
        identityReference,
        nutrientReference,
        _constraintReference(evaluation),
        ...safety.evidenceIds,
      ],
    );
  }

  B04CurrentFoodCandidateInput _unavailableCandidate({
    required String selectionId,
    required B04MealCandidateSource source,
    required String subjectId,
    required String displayLabel,
    required String userId,
    required String errorCode,
    required String identityReference,
    required String nutrientReference,
    NutrientAggregationResult? nutrientEvidence,
  }) {
    final selection = B04MealCandidate(
      selectionId: selectionId,
      source: source,
      subjectId: subjectId,
      evidence: B04MealCandidateEvidence.unavailable,
    );
    final safety = _safety.unavailableForInvalidEvidence(
      userId: userId,
      subjectId: subjectId,
      output: B04NutritionSafetyOutput.eatNow,
      errorCode: errorCode,
      nutrientEvidence: nutrientEvidence,
    );
    return B04CurrentFoodCandidateInput(
      selection: selection,
      displayLabel: displayLabel,
      nutrientEvidence: nutrientEvidence,
      safety: safety,
      evidenceIds: [identityReference, nutrientReference],
    );
  }

  NutrientAggregationResult _aggregateFacts(Map<String, NutrientFact> facts) {
    return NutrientAggregationService.aggregate(
      registry: _registry,
      contributions: facts.values.map(
        (fact) => NutrientContribution(fact: fact),
      ),
      requestedNutrientIds: _registry.definitions
          .map((definition) => definition.id)
          .toSet(),
    );
  }

  String _constraintReference(NutritionConstraintEvaluationResult evaluation) {
    final value = Map<String, dynamic>.from(
      evaluation.toJson(includeFingerprint: false),
    )..remove('evaluated_at');
    final fingerprint = sha256.convert(utf8.encode(jsonEncode(value)));
    return 'constraint:${fingerprint.toString()}';
  }

  B04RecommendationCandidate _targetCandidate({
    required B04AdaptiveTargetResult target,
    required B04RecommendationHistoryScope scope,
    required String contextUserId,
  }) {
    final evidence = target.evidenceIds.isEmpty
        ? const B04RecommendationEvidence.missing(
            missingEvidence: ['adaptive_target_evidence_unavailable'],
          )
        : B04RecommendationEvidence(
            state: B04RecommendationEvidenceState.complete,
            evidenceIds: target.evidenceIds,
          );
    final safetyEvidence = target.evidenceIds.isEmpty
        ? ['adaptive-target-safety:${target.policyVersion}']
        : target.evidenceIds;
    return B04RecommendationCandidate(
      id: 'b04-${scope.stableId}-adaptive-target',
      action: B04RecommendationAction.nutritionTarget,
      rationaleCode: 'canonical_adaptive_target',
      evidence: evidence,
      nutritionSafety: B04NutritionSafetyResult(
        userId: contextUserId,
        subjectId: 'adaptive-target',
        output: B04NutritionSafetyOutput.adaptiveTarget,
        disposition: B04NutritionSafetyDisposition.noKnownConflict,
        evaluatedDisposition: B04NutritionSafetyDisposition.noKnownConflict,
        constraintEvaluation: null,
        evaluatorOutcome: null,
        nutrientEvidence: null,
        reasonCodes: const ['adaptive_target_safety_policy'],
        evidenceIds: safetyEvidence,
        missingEvidence: const [],
        hardBlockConstraintIds: const [],
        softFilterConstraintIds: const [],
        uncertainConstraintIds: const [],
        nutrientRangeIds: const [],
        constraintContexts: const [],
      ),
    );
  }

  String? _goalRate(NutritionGoalVersionReadModel? goal) {
    if (goal == null) return null;
    try {
      return _goals.defaultAdaptiveGoalRate(goal.goalType);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _issueIfAllowed(_ProductionPeriod period) async {
    if (period.evaluation.recommendations.isEmpty) return false;
    final preferences = period.context.preferences;
    final eligibility = period.context.eligibility;
    final consentEventId = preferences?.adaptiveCoachingEvent?.id;
    final eligibilityEvaluationId = eligibility?.id;
    if (preferences?.adaptiveCoachingEnabled != true ||
        consentEventId == null ||
        eligibility?.isEligible != true ||
        eligibilityEvaluationId == null) {
      return false;
    }
    final command = B04RecommendationHistoryCommand(
      evaluation: period.evaluation,
      scope: period.scope,
      consentEventId: consentEventId,
      eligibilityEvaluationId: eligibilityEvaluationId,
      goalVersionId: _goalVersionForPeriod(period),
      readinessSnapshotId: _readinessIdForPeriod(period),
      evidenceByRecommendationId: {
        for (final recommendation in period.evaluation.recommendations)
          recommendation.id: [
            for (final evidenceId in recommendation.evidenceIds)
              B04RecommendationEvidenceInput(
                evidenceKind: 'production_orchestration',
                sourceType: 'b04_production_orchestration',
                sourceId: evidenceId,
                sourceVersion: recommendation.algorithmVersion,
                status: recommendation.state.stableId,
                localDate: period.evaluation.startLocalDate,
                timezoneId: period.evaluation.timezoneId,
              ),
          ],
      },
      supersedesByRecommendationId: _supersedes(period),
    );
    await _history.issue(command);
    return true;
  }

  String? _goalVersionForPeriod(_ProductionPeriod period) {
    final goal = period.context.activeGoal;
    if (goal == null) return null;
    final start = _dates.compare(
      goal.effectiveFromLocalDate,
      period.context.window.startLocalDate,
    );
    final end = goal.effectiveToLocalDate == null
        ? -1
        : _dates.compare(
            goal.effectiveToLocalDate!,
            period.context.window.endLocalDate,
          );
    return start <= 0 && end <= 0 ? goal.id : null;
  }

  String? _readinessIdForPeriod(_ProductionPeriod period) {
    final readiness = period.context.readiness;
    if (readiness == null) return null;
    final start = _dates.compare(
      readiness.localDate,
      period.context.window.startLocalDate,
    );
    final end = _dates.compare(
      readiness.localDate,
      period.context.window.endLocalDate,
    );
    return start >= 0 && end <= 0 ? readiness.snapshotId : null;
  }

  Map<String, String?> _supersedes(_ProductionPeriod period) {
    final used = <String>{};
    final rows = period.periodRows.toList()
      ..sort((left, right) {
        final time = right.createdAtUtc.compareTo(left.createdAtUtc);
        return time == 0 ? right.id.compareTo(left.id) : time;
      });
    final result = <String, String?>{};
    for (final recommendation in period.evaluation.recommendations) {
      for (final row in rows) {
        if (used.contains(row.id) ||
            row.action != recommendation.action.stableId ||
            row.contextFingerprint == period.evaluation.contextFingerprint) {
          continue;
        }
        used.add(row.id);
        result[recommendation.id] = row.id;
        break;
      }
    }
    return result;
  }

  Future<List<B04HistoricalRecommendation>> _periodRows({
    required String userId,
    required B04RecommendationHistoryScope scope,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) async {
    final rows = await _history.listHistory(userId: userId, scope: scope);
    return List.unmodifiable(
      rows.where(
        (row) =>
            row.localPeriodStart == startLocalDate &&
            row.localPeriodEnd == endLocalDate &&
            row.timezoneId == timezoneId,
      ),
    );
  }

  String _contextId({
    required B04RecommendationHistoryScope scope,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) =>
      'b04-production:${scope.stableId}:$startLocalDate:$endLocalDate:$timezoneId';

  static DateTime _later(DateTime left, DateTime right) =>
      left.isAfter(right) ? left : right;

  static DateTime _evaluationTimestamp(DateTime value) => DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
  );

  Future<T?> _readOrNull<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on Object {
      return null;
    }
  }
}

class _ProductionSources {
  final NutritionGoalVersionReadModel? activeGoal;
  final CoachingPreferencesReadModel? preferences;
  final CoachingEligibilityReadModel? eligibility;
  final ReadinessSnapshotReadModel? readiness;
  final B02ProgressReadModel? progress;
  final CalendarReadSnapshot? schedule;
  final List<NutritionDailyReadModel> nutritionDays;
  final List<NutritionUserConstraint> constraints;

  const _ProductionSources({
    required this.activeGoal,
    required this.preferences,
    required this.eligibility,
    required this.readiness,
    required this.progress,
    required this.schedule,
    required this.nutritionDays,
    required this.constraints,
  });
}

class _ProductionCandidateSet {
  final List<B04CurrentFoodCandidateInput> inputs;
  final List<B04MealCandidate> selections;
  final List<NutritionConstraintEvaluationResult> constraintEvaluations;

  const _ProductionCandidateSet({
    required this.inputs,
    required this.selections,
    required this.constraintEvaluations,
  });

  const _ProductionCandidateSet.empty()
    : inputs = const [],
      selections = const [],
      constraintEvaluations = const [];
}

class _ProductionPeriod {
  final B04RecommendationHistoryScope scope;
  final B04RecommendationContext context;
  final B04RecommendationEvaluation evaluation;
  final B04CurrentFoodGuidance? guidance;
  final List<B04CurrentFoodCandidateInput> candidates;
  final List<B04HistoricalRecommendation> periodRows;

  const _ProductionPeriod({
    required this.scope,
    required this.context,
    required this.evaluation,
    required this.guidance,
    required this.candidates,
    required this.periodRows,
  });
}
