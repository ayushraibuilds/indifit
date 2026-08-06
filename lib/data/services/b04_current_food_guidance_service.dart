import '../../core/nutrients.dart';
import '../../core/typed_quantities.dart';
import '../models/b04_current_food_models.dart';
import '../models/b04_goal_models.dart';
import '../models/b04_recommendation_context_models.dart';
import '../models/b04_recommendation_models.dart';
import 'b04_recommendation_engine.dart';

/// B04-12's local current-food read-model boundary.
///
/// The service consumes B03 daily totals, B03-derived candidate nutrient facts,
/// and the already-mapped B03 safety result. It does not query the network,
/// infer availability, calculate recipes, or evaluate constraints a second
/// time. The shared B04 recommendation engine remains the final deterministic
/// recommendation authority.
class B04CurrentFoodGuidanceService {
  final B04RecommendationEngine _recommendations;

  const B04CurrentFoodGuidanceService({
    B04RecommendationEngine recommendations = const B04RecommendationEngine(),
  }) : _recommendations = recommendations;

  B04RemainingTargetReadModel readRemainingTargets({
    required B04RecommendationContext context,
    String? localDate,
  }) {
    final date =
        (localDate ??
                context.mealOpportunity?.localDate ??
                context.window.startLocalDate)
            .trim();
    final goal = context.activeGoal;
    B04NutritionDayContext? day;
    for (final candidate in context.nutrition.days) {
      if (candidate.localDate == date) {
        day = candidate;
        break;
      }
    }
    final sourceIds = _consumptionSourceIds(day);
    final factVersions = _consumptionFactVersions(day);
    final missingEvidence = <String>{
      ...context.missingEvidence
          .where(
            (item) =>
                item.kind == B04MissingEvidenceKind.nutritionTotals &&
                (item.localDate == null || item.localDate == date),
          )
          .map((item) => item.reasonCode),
    };
    if (day == null) missingEvidence.add('daily_totals_unavailable');

    final goalIsOwned = goal == null || goal.userId == context.userId;
    final goalTimezoneMatches =
        goal == null || goal.timezoneId == context.window.timezoneId;
    final goalIsEffective = goal == null || _isGoalEffective(goal, date);
    if (!goalIsOwned) missingEvidence.add('goal_owner_mismatch');
    if (!goalTimezoneMatches) missingEvidence.add('goal_timezone_mismatch');
    if (!goalIsEffective) missingEvidence.add('goal_not_effective');

    final targetDefinitions = [
      (
        id: 'energy',
        unit: NutrientUnit.kilocalorie,
        target: goal?.calorieTargetKcal == null
            ? null
            : QuantityAmount.fromNum(goal!.calorieTargetKcal!).toString(),
      ),
      (
        id: 'protein',
        unit: NutrientUnit.gram,
        target: _goalAmount(goal?.proteinTargetG),
      ),
      (
        id: 'carbohydrate',
        unit: NutrientUnit.gram,
        target: _goalAmount(goal?.carbsTargetG),
      ),
      (
        id: 'fat',
        unit: NutrientUnit.gram,
        target: _goalAmount(goal?.fatTargetG),
      ),
    ];

    final targets = <B04CurrentFoodNutrientValue>[];
    for (final definition in targetDefinitions) {
      final fact = day?.totals.facts[definition.id];
      targets.add(
        _remainingValue(
          nutrientId: definition.id,
          unit: definition.unit,
          targetText: definition.target,
          fact: fact,
          goal: goal,
          context: context,
          day: day,
          sourceIds: sourceIds,
          factVersions: factVersions,
          forcedReason:
              goal == null ||
                  !goalIsOwned ||
                  !goalTimezoneMatches ||
                  !goalIsEffective ||
                  day == null
              ? _targetMissingReason(
                  goal: goal,
                  day: day,
                  goalIsOwned: goalIsOwned,
                  goalTimezoneMatches: goalTimezoneMatches,
                  goalIsEffective: goalIsEffective,
                  context: context,
                  localDate: date,
                )
              : null,
        ),
      );
    }

    return B04RemainingTargetReadModel(
      userId: context.userId,
      localDate: date,
      timezoneId: context.window.timezoneId,
      goalVersionId: goal?.id,
      goalSource: goal?.source.stableId,
      goalEffectiveFromLocalDate: goal?.effectiveFromLocalDate,
      targets: targets,
      consumedRecordIds: day?.recordIds ?? const [],
      consumedEstimateIds: day?.estimateIds ?? const [],
      consumedIssueIds: day?.compatibilityIssueIds ?? const [],
      consumedFactVersions: factVersions,
      missingEvidence: missingEvidence,
    );
  }

  B04CurrentFoodGuidance evaluate({
    required B04RecommendationContext context,
    required Iterable<B04CurrentFoodCandidateInput> candidates,
  }) {
    final opportunity = context.mealOpportunity;
    final remaining = readRemainingTargets(context: context);
    final inputs = candidates.toList(growable: false);
    final evaluatedAt = context.evaluatedAtUtc;
    final localDate = remaining.localDate;

    if (opportunity == null) {
      return _emptyGuidance(
        context: context,
        remaining: remaining,
        status: B04CurrentFoodGuidanceStatus.unavailable,
        reasonCodes: const ['explicit_opportunity_required'],
      );
    }
    if (opportunity.status == B04MealOpportunityStatus.noCandidate ||
        opportunity.candidates.isEmpty) {
      return _emptyGuidance(
        context: context,
        remaining: remaining,
        status: B04CurrentFoodGuidanceStatus.noCandidate,
        reasonCodes: [opportunity.reasonCode, 'no_explicit_candidate'],
      );
    }
    if (opportunity.status == B04MealOpportunityStatus.unavailable) {
      return _emptyGuidance(
        context: context,
        remaining: remaining,
        status: B04CurrentFoodGuidanceStatus.unavailable,
        reasonCodes: [opportunity.reasonCode],
      );
    }

    _validateCandidateInputs(opportunity, inputs);

    final remainingEnergy = remaining.energy;
    if (remainingEnergy == null ||
        remainingEnergy.state == B04CurrentFoodValueState.missing ||
        remainingEnergy.state == B04CurrentFoodValueState.unknown ||
        remainingEnergy.state == B04CurrentFoodValueState.invalid) {
      return _emptyGuidance(
        context: context,
        remaining: remaining,
        status: B04CurrentFoodGuidanceStatus.unavailable,
        reasonCodes: [
          ...remaining.missingEvidence,
          'remaining_energy_${remainingEnergy?.state.stableId ?? 'missing'}',
        ],
        excludedCandidates: [
          for (final input in inputs)
            B04CurrentFoodExcludedCandidate(
              selectionId: input.selection.selectionId,
              displayLabel: input.displayLabel,
              source: input.selection.source,
              reasonCodes: const ['remaining_target_unavailable'],
            ),
        ],
      );
    }

    final engineCandidates = <B04RecommendationCandidate>[];
    final inputByRecommendationId = <String, B04CurrentFoodCandidateInput>{};
    for (final input in inputs) {
      final recommendationId = _recommendationId(input.selection.selectionId);
      inputByRecommendationId[recommendationId] = input;
      engineCandidates.add(
        B04RecommendationCandidate(
          id: recommendationId,
          action: B04RecommendationAction.nutritionMeal,
          rationaleCode: 'meal_opportunity_target_fit',
          evidence: _recommendationEvidence(input),
          userSelected: true,
          nutritionSafety: input.safety,
        ),
      );
    }

    final evaluation = _recommendations.evaluate(
      context: context,
      candidates: engineCandidates,
      scope: B04RecommendationEvaluationScope.mealOpportunity,
    );
    final recommendationsById = {
      for (final recommendation in evaluation.recommendations)
        recommendation.id: recommendation,
    };
    final cards = <B04CurrentFoodCandidateCard>[];
    final excluded = <B04CurrentFoodExcludedCandidate>[];
    for (final entry in inputByRecommendationId.entries) {
      final input = entry.value;
      final recommendation = recommendationsById[entry.key];
      if (recommendation == null) {
        excluded.add(_excluded(input, const ['recommendation_not_evaluated']));
        continue;
      }
      if (recommendation.state == B04RecommendationState.unavailable) {
        excluded.add(_excluded(input, recommendation.unavailableReasons));
        continue;
      }
      final targetFit = _targetFit(
        remaining: remainingEnergy,
        candidate: input.nutrientEvidence?.facts['energy'],
        evidenceIds: [
          ...remainingEnergy.sourceIds,
          ..._factSourceIds(input.nutrientEvidence, 'energy'),
        ],
      );
      if (targetFit.state == B04CurrentFoodTargetFitState.unavailable) {
        excluded.add(_excluded(input, [targetFit.reasonCode]));
        continue;
      }
      cards.add(
        B04CurrentFoodCandidateCard(
          selectionId: input.selection.selectionId,
          subjectId: input.selection.subjectId,
          source: input.selection.source,
          displayLabel: input.displayLabel,
          recommendation: recommendation,
          targetFit: targetFit,
          nutrientFacts: _candidateFactSummaries(input.nutrientEvidence),
        ),
      );
    }

    cards.sort((left, right) {
      final fit = left.targetFit.rank.compareTo(right.targetFit.rank);
      if (fit != 0) return fit;
      final priority = left.recommendation.priority.rank.compareTo(
        right.recommendation.priority.rank,
      );
      if (priority != 0) return priority;
      return left.selectionId.compareTo(right.selectionId);
    });

    final reasons = <String>{
      ...remaining.missingEvidence,
      if (cards.isNotEmpty) 'candidate_guidance_available',
      if (cards.isEmpty) 'no_candidate_after_filter',
      ...evaluation.lowRiskWarnings.expand((item) => item.reasonCodes),
    };
    final hasSafetyUnavailable = excluded.any(
      (item) => item.reasonCodes.any(_isSafetyUnavailableReason),
    );
    final status = cards.isNotEmpty
        ? B04CurrentFoodGuidanceStatus.available
        : hasSafetyUnavailable
        ? B04CurrentFoodGuidanceStatus.unavailable
        : B04CurrentFoodGuidanceStatus.noCandidate;
    if (hasSafetyUnavailable) reasons.add('safety_evidence_unavailable');

    return B04CurrentFoodGuidance(
      status: status,
      userId: context.userId,
      localDate: localDate,
      timezoneId: context.window.timezoneId,
      evaluatedAtUtc: evaluatedAt,
      remainingTargets: remaining,
      cards: cards,
      excludedCandidates: excluded,
      lowRiskWarnings: evaluation.lowRiskWarnings,
      recommendationEvaluation: evaluation,
      reasonCodes: reasons,
    );
  }

  B04CurrentFoodGuidance _emptyGuidance({
    required B04RecommendationContext context,
    required B04RemainingTargetReadModel remaining,
    required B04CurrentFoodGuidanceStatus status,
    required Iterable<String> reasonCodes,
    Iterable<B04CurrentFoodExcludedCandidate> excludedCandidates = const [],
  }) => B04CurrentFoodGuidance(
    status: status,
    userId: context.userId,
    localDate: remaining.localDate,
    timezoneId: context.window.timezoneId,
    evaluatedAtUtc: context.evaluatedAtUtc,
    remainingTargets: remaining,
    excludedCandidates: excludedCandidates,
    recommendationEvaluation: null,
    reasonCodes: {
      ...reasonCodes,
      if (status == B04CurrentFoodGuidanceStatus.noCandidate) 'no_candidate',
      if (status == B04CurrentFoodGuidanceStatus.unavailable)
        'guidance_unavailable',
    },
  );

  void _validateCandidateInputs(
    B04MealOpportunity opportunity,
    List<B04CurrentFoodCandidateInput> inputs,
  ) {
    final selected = {
      for (final candidate in opportunity.candidates)
        candidate.selectionId: candidate,
    };
    final seen = <String>{};
    for (final input in inputs) {
      final id = input.selection.selectionId;
      if (!seen.add(id)) {
        throw ArgumentError(
          'Current-food candidate selections must be unique.',
        );
      }
      final selectedCandidate = selected[id];
      if (selectedCandidate == null ||
          selectedCandidate.source != input.selection.source ||
          selectedCandidate.subjectId != input.selection.subjectId) {
        throw ArgumentError(
          'Current-food data must match the explicit meal opportunity.',
        );
      }
    }
  }

  B04RecommendationEvidence _recommendationEvidence(
    B04CurrentFoodCandidateInput input,
  ) {
    final evidenceIds = <String>{
      ...input.evidenceIds,
      if (input.selection.evidence.identityReference != null)
        input.selection.evidence.identityReference!,
      if (input.selection.evidence.nutrientReference != null)
        input.selection.evidence.nutrientReference!,
      if (input.selection.evidence.constraintReference != null)
        input.selection.evidence.constraintReference!,
      ...input.selection.evidence.estimateReferences,
      ..._factSourceIds(input.nutrientEvidence, null),
    };
    final missing = <String>{};
    final uncertainty = <String>{};
    if (input.selection.evidence.state ==
        B04MealCandidateEvidenceState.unavailable) {
      missing.add('candidate_evidence_unavailable');
    } else if (input.selection.evidence.state ==
        B04MealCandidateEvidenceState.partial) {
      uncertainty.add('candidate_evidence_partial');
    }
    if (input.nutrientEvidence == null) {
      missing.add('candidate_nutrient_evidence_missing');
    } else if (input.nutrientEvidence!.completeness.state ==
            NutrientCompletenessState.invalid ||
        input.nutrientEvidence!.completeness.state ==
            NutrientCompletenessState.unknown) {
      uncertainty.add('candidate_nutrient_evidence_unknown');
    } else if (input.nutrientEvidence!.completeness.state ==
        NutrientCompletenessState.partial) {
      uncertainty.add('candidate_nutrient_evidence_partial');
    }
    if (evidenceIds.isEmpty) missing.add('candidate_evidence_unidentified');
    if (missing.isNotEmpty) {
      return B04RecommendationEvidence(
        state: B04RecommendationEvidenceState.missing,
        evidenceIds: evidenceIds,
        missingEvidence: missing,
        uncertaintyCodes: uncertainty,
      );
    }
    return B04RecommendationEvidence(
      state: uncertainty.isEmpty
          ? B04RecommendationEvidenceState.complete
          : B04RecommendationEvidenceState.partial,
      evidenceIds: evidenceIds,
      missingEvidence: const [],
      uncertaintyCodes: uncertainty,
    );
  }

  B04CurrentFoodExcludedCandidate _excluded(
    B04CurrentFoodCandidateInput input,
    Iterable<String> reasons,
  ) {
    final normalized = reasons
        .map((reason) => reason.trim())
        .where((reason) => reason.isNotEmpty)
        .toSet();
    if (normalized.isEmpty) normalized.add('candidate_unavailable');
    return B04CurrentFoodExcludedCandidate(
      selectionId: input.selection.selectionId,
      displayLabel: input.displayLabel,
      source: input.selection.source,
      reasonCodes: normalized,
      safetyDisposition: input.safety?.evaluatedDisposition,
    );
  }

  B04CurrentFoodTargetFit _targetFit({
    required B04CurrentFoodNutrientValue remaining,
    required NutrientFact? candidate,
    required Iterable<String> evidenceIds,
  }) {
    final targetInterval = _intervalForValue(remaining);
    final candidateInterval = _intervalForFact(candidate);
    if (targetInterval == null || candidateInterval == null) {
      return B04CurrentFoodTargetFit(
        state: B04CurrentFoodTargetFitState.unavailable,
        rank: 3,
        reasonCode: candidate == null
            ? 'candidate_energy_unknown'
            : 'target_fit_unavailable',
        nutrientId: 'energy',
        evidenceIds: evidenceIds,
      );
    }
    if (candidateInterval.upper.compareTo(targetInterval.lower) <= 0) {
      return B04CurrentFoodTargetFit(
        state: B04CurrentFoodTargetFitState.fits,
        rank: 0,
        reasonCode: 'within_remaining_target',
        nutrientId: 'energy',
        evidenceIds: evidenceIds,
      );
    }
    if (candidateInterval.lower.compareTo(targetInterval.upper) > 0) {
      return B04CurrentFoodTargetFit(
        state: B04CurrentFoodTargetFitState.exceeds,
        rank: 2,
        reasonCode: 'exceeds_remaining_target',
        nutrientId: 'energy',
        evidenceIds: evidenceIds,
      );
    }
    return B04CurrentFoodTargetFit(
      state: B04CurrentFoodTargetFitState.uncertain,
      rank: 1,
      reasonCode: 'target_range_uncertain',
      nutrientId: 'energy',
      evidenceIds: evidenceIds,
    );
  }

  List<B04CurrentFoodNutrientValue> _candidateFactSummaries(
    NutrientAggregationResult? evidence,
  ) {
    if (evidence == null) return const [];
    final sourceIds = _factSourceIds(evidence, null);
    final result = <B04CurrentFoodNutrientValue>[];
    for (final id in const ['energy', 'protein', 'carbohydrate', 'fat']) {
      final fact = evidence.facts[id];
      if (fact == null) continue;
      result.add(
        _summaryForFact(
          fact: fact,
          sourceType: 'b03_candidate_read_model',
          sourceVersion: fact.factVersion,
          sourceIds: [...sourceIds, ..._factSourceIds(evidence, id)],
          unknownReason: 'candidate_nutrient_unknown',
        ),
      );
    }
    result.sort((left, right) => left.nutrientId.compareTo(right.nutrientId));
    return List.unmodifiable(result);
  }

  B04CurrentFoodNutrientValue _remainingValue({
    required String nutrientId,
    required NutrientUnit unit,
    required String? targetText,
    required NutrientFact? fact,
    required NutritionGoalVersionReadModel? goal,
    required B04RecommendationContext context,
    required B04NutritionDayContext? day,
    required List<String> sourceIds,
    required List<String> factVersions,
    required String? forcedReason,
  }) {
    final valueSourceIds = <String>{
      ...sourceIds,
      if (goal != null) 'goal_version:${goal.id}',
      if (sourceIds.isEmpty) 'remaining_target:$nutrientId',
    };
    final sourceVersion = goal?.calculationVersion ?? goal?.policyVersion;
    if (forcedReason != null) {
      return B04CurrentFoodNutrientValue(
        nutrientId: nutrientId,
        unit: unit,
        state: B04CurrentFoodValueState.unknown,
        sourceType: 'goal_version_and_b03_read_model',
        sourceVersion: sourceVersion,
        sourceIds: valueSourceIds,
        reasonCode: forcedReason,
      );
    }
    if (targetText == null) {
      return B04CurrentFoodNutrientValue(
        nutrientId: nutrientId,
        unit: unit,
        state: B04CurrentFoodValueState.missing,
        sourceType: 'goal_version',
        sourceVersion: sourceVersion,
        sourceIds: valueSourceIds,
        reasonCode: 'goal_target_missing',
      );
    }
    final target = _B04SignedDecimal.tryParse(targetText);
    if (target == null || target.isNegative) {
      return B04CurrentFoodNutrientValue(
        nutrientId: nutrientId,
        unit: unit,
        state: B04CurrentFoodValueState.invalid,
        sourceType: 'goal_version',
        sourceVersion: sourceVersion,
        sourceIds: valueSourceIds,
        reasonCode: 'goal_target_invalid',
      );
    }
    if (day == null || fact == null) {
      return B04CurrentFoodNutrientValue(
        nutrientId: nutrientId,
        unit: unit,
        state: B04CurrentFoodValueState.missing,
        sourceType: 'goal_version_and_b03_read_model',
        sourceVersion: sourceVersion,
        sourceIds: valueSourceIds,
        reasonCode: 'daily_totals_missing',
      );
    }
    if (fact.status == NutrientFactStatus.missing ||
        fact.status == NutrientFactStatus.notApplicable) {
      return B04CurrentFoodNutrientValue(
        nutrientId: nutrientId,
        unit: unit,
        state: B04CurrentFoodValueState.missing,
        sourceType: 'goal_version_and_b03_read_model',
        sourceVersion: fact.factVersion,
        sourceIds: valueSourceIds,
        reasonCode: 'consumed_${fact.status.stableId}',
      );
    }
    if (fact.coverageIncomplete) {
      return B04CurrentFoodNutrientValue(
        nutrientId: nutrientId,
        unit: unit,
        state: B04CurrentFoodValueState.unknown,
        sourceType: 'goal_version_and_b03_read_model',
        sourceVersion: fact.factVersion,
        sourceIds: valueSourceIds,
        reasonCode: 'consumed_totals_partial',
      );
    }
    final lower = _decimalFromAmount(fact.lower);
    final upper = _decimalFromAmount(fact.upper);
    final point = _decimalFromAmount(fact.point);
    final hasRange = lower != null || upper != null;
    if (fact.status == NutrientFactStatus.estimated || hasRange) {
      if (lower == null || upper == null) {
        return B04CurrentFoodNutrientValue(
          nutrientId: nutrientId,
          unit: unit,
          state: B04CurrentFoodValueState.unknown,
          sourceType: 'goal_version_and_b03_read_model',
          sourceVersion: fact.factVersion,
          sourceIds: valueSourceIds,
          reasonCode: 'consumed_range_unbounded',
        );
      }
      return B04CurrentFoodNutrientValue(
        nutrientId: nutrientId,
        unit: unit,
        state: B04CurrentFoodValueState.range,
        lower: target.subtract(upper).toString(),
        upper: target.subtract(lower).toString(),
        sourceType: 'goal_version_and_b03_read_model',
        sourceVersion: fact.factVersion,
        sourceIds: valueSourceIds,
        reasonCode: 'consumed_range_preserved',
      );
    }
    if (point == null ||
        (fact.status != NutrientFactStatus.known &&
            fact.status != NutrientFactStatus.knownZero)) {
      return B04CurrentFoodNutrientValue(
        nutrientId: nutrientId,
        unit: unit,
        state: B04CurrentFoodValueState.unknown,
        sourceType: 'goal_version_and_b03_read_model',
        sourceVersion: fact.factVersion,
        sourceIds: valueSourceIds,
        reasonCode: 'consumed_totals_unknown',
      );
    }
    return B04CurrentFoodNutrientValue(
      nutrientId: nutrientId,
      unit: unit,
      state: B04CurrentFoodValueState.known,
      point: target.subtract(point).toString(),
      sourceType: 'goal_version_and_b03_read_model',
      sourceVersion: fact.factVersion,
      sourceIds: valueSourceIds,
      reasonCode: 'remaining_target_derived',
    );
  }

  B04CurrentFoodNutrientValue _summaryForFact({
    required NutrientFact fact,
    required String sourceType,
    required String sourceVersion,
    required Iterable<String> sourceIds,
    required String unknownReason,
  }) {
    final point = _decimalFromAmount(fact.point);
    final lower = _decimalFromAmount(fact.lower);
    final upper = _decimalFromAmount(fact.upper);
    final hasRange = lower != null || upper != null;
    final state = _factValueState(fact);
    final normalizedSourceIds = <String>{
      ...sourceIds,
      if (fact.sourceReference != null) fact.sourceReference!,
      if (fact.factVersion.isNotEmpty) 'nutrient_fact:${fact.factVersion}',
      if (sourceIds.isEmpty && fact.sourceReference == null)
        'candidate_fact:${fact.nutrientId}',
    };
    return B04CurrentFoodNutrientValue(
      nutrientId: fact.nutrientId,
      unit: fact.unit,
      state: state,
      point: state == B04CurrentFoodValueState.known ? point?.toString() : null,
      lower: state == B04CurrentFoodValueState.range ? lower?.toString() : null,
      upper: state == B04CurrentFoodValueState.range ? upper?.toString() : null,
      sourceType: sourceType,
      sourceVersion: sourceVersion,
      sourceIds: normalizedSourceIds,
      reasonCode:
          state == B04CurrentFoodValueState.unknown ||
              state == B04CurrentFoodValueState.missing
          ? unknownReason
          : hasRange
          ? 'candidate_range_preserved'
          : null,
    );
  }

  B04CurrentFoodValueState _factValueState(NutrientFact fact) {
    if (fact.status == NutrientFactStatus.missing ||
        fact.status == NutrientFactStatus.notApplicable) {
      return B04CurrentFoodValueState.missing;
    }
    if (fact.coverageIncomplete) return B04CurrentFoodValueState.unknown;
    if (fact.lower != null || fact.upper != null) {
      return fact.lower != null && fact.upper != null
          ? B04CurrentFoodValueState.range
          : B04CurrentFoodValueState.unknown;
    }
    if ((fact.status == NutrientFactStatus.known ||
            fact.status == NutrientFactStatus.knownZero) &&
        fact.point != null) {
      return B04CurrentFoodValueState.known;
    }
    return B04CurrentFoodValueState.unknown;
  }

  _B04DecimalInterval? _intervalForValue(B04CurrentFoodNutrientValue value) {
    final point = _B04SignedDecimal.tryParse(value.point ?? '');
    final lower = _B04SignedDecimal.tryParse(value.lower ?? '');
    final upper = _B04SignedDecimal.tryParse(value.upper ?? '');
    if (value.state == B04CurrentFoodValueState.known && point != null) {
      return _B04DecimalInterval(point, point);
    }
    if (value.state == B04CurrentFoodValueState.range &&
        lower != null &&
        upper != null) {
      return _B04DecimalInterval(lower, upper);
    }
    return null;
  }

  _B04DecimalInterval? _intervalForFact(NutrientFact? fact) {
    if (fact == null ||
        _factValueState(fact) == B04CurrentFoodValueState.unknown) {
      return null;
    }
    final point = _decimalFromAmount(fact.point);
    if (_factValueState(fact) == B04CurrentFoodValueState.known &&
        point != null) {
      return _B04DecimalInterval(point, point);
    }
    final lower = _decimalFromAmount(fact.lower);
    final upper = _decimalFromAmount(fact.upper);
    if (_factValueState(fact) == B04CurrentFoodValueState.range &&
        lower != null &&
        upper != null) {
      return _B04DecimalInterval(lower, upper);
    }
    return null;
  }

  List<String> _consumptionSourceIds(B04NutritionDayContext? day) {
    if (day == null) return const ['consumption:missing'];
    final ids = <String>{
      ...day.recordIds.map((id) => 'consumption:$id'),
      ...day.estimateIds.map((id) => 'estimate:$id'),
      ...day.compatibilityIssueIds.map((id) => 'compatibility:$id'),
      if (day.recordIds.isEmpty) 'consumption:${day.localDate}:empty',
    };
    return ids.toList()..sort();
  }

  List<String> _consumptionFactVersions(B04NutritionDayContext? day) {
    if (day == null) return const [];
    final versions = <String>{
      for (final values in day.totals.factVersionLineage.values) ...values,
    };
    return versions.toList()..sort();
  }

  List<String> _factSourceIds(
    NutrientAggregationResult? evidence,
    String? nutrientId,
  ) {
    if (evidence == null) return const [];
    final ids = <String>{};
    final sourceEntries = nutrientId == null
        ? evidence.sourceLineage.entries
        : evidence.sourceLineage.entries.where(
            (entry) => entry.key == nutrientId,
          );
    for (final entry in sourceEntries) {
      ids.addAll(
        entry.value.map((source) => 'nutrient_source:${source.stableId}'),
      );
    }
    final versionEntries = nutrientId == null
        ? evidence.factVersionLineage.entries
        : evidence.factVersionLineage.entries.where(
            (entry) => entry.key == nutrientId,
          );
    for (final entry in versionEntries) {
      ids.addAll(entry.value.map((version) => 'nutrient_fact:$version'));
    }
    final fact = nutrientId == null ? null : evidence.facts[nutrientId];
    if (fact?.sourceReference != null) ids.add(fact!.sourceReference!);
    return ids.toList()..sort();
  }

  String? _targetMissingReason({
    required NutritionGoalVersionReadModel? goal,
    required B04NutritionDayContext? day,
    required bool goalIsOwned,
    required bool goalTimezoneMatches,
    required bool goalIsEffective,
    required B04RecommendationContext context,
    required String localDate,
  }) {
    if (goal == null) return 'goal_missing';
    if (!goalIsOwned) return 'goal_owner_mismatch';
    if (!goalTimezoneMatches) return 'goal_timezone_mismatch';
    if (!goalIsEffective) return 'goal_not_effective';
    if (day == null) return 'daily_totals_unavailable';
    for (final item in context.missingEvidence) {
      if (item.kind == B04MissingEvidenceKind.nutritionTotals &&
          (item.localDate == null || item.localDate == localDate)) {
        return item.reasonCode;
      }
    }
    return 'daily_totals_limited';
  }

  bool _isGoalEffective(NutritionGoalVersionReadModel goal, String localDate) {
    if (goal.effectiveFromLocalDate.compareTo(localDate) > 0) return false;
    final effectiveTo = goal.effectiveToLocalDate;
    return effectiveTo == null || effectiveTo.compareTo(localDate) >= 0;
  }

  String? _goalAmount(double? value) {
    if (value == null || !value.isFinite || value < 0) return null;
    try {
      return QuantityAmount.fromNum(value).toString();
    } on QuantityError {
      return null;
    }
  }

  _B04SignedDecimal? _decimalFromAmount(NutrientAmount? amount) =>
      amount == null
      ? null
      : _B04SignedDecimal.tryParse(amount.value.toString());

  String _recommendationId(String selectionId) =>
      'meal-opportunity-${selectionId.trim()}';

  bool _isSafetyUnavailableReason(String reason) {
    final normalized = reason.toLowerCase();
    return normalized.contains('dietary_unavailable') ||
        normalized.contains('dietary_safety') ||
        normalized.contains('candidate_evidence') ||
        normalized.contains('candidate_nutrient_evidence') ||
        normalized.contains('safety_evidence_missing');
  }
}

class _B04DecimalInterval {
  final _B04SignedDecimal lower;
  final _B04SignedDecimal upper;

  const _B04DecimalInterval(this.lower, this.upper);
}

/// A small signed decimal used only for the ephemeral remaining-target
/// projection. B03 facts and goal targets remain stored in their own typed
/// authorities.
class _B04SignedDecimal implements Comparable<_B04SignedDecimal> {
  final BigInt coefficient;
  final int scale;

  const _B04SignedDecimal._(this.coefficient, this.scale);

  static _B04SignedDecimal? tryParse(String value) {
    final trimmed = value.trim();
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$').firstMatch(trimmed);
    if (match == null) return null;
    final sign = match.group(1) == '-' ? -BigInt.one : BigInt.one;
    final fraction = match.group(3) ?? '';
    final coefficient = sign * BigInt.parse('${match.group(2)}$fraction');
    return _normalize(coefficient, fraction.length);
  }

  static _B04SignedDecimal _normalize(BigInt coefficient, int scale) {
    while (scale > 0 &&
        coefficient != BigInt.zero &&
        coefficient % BigInt.from(10) == BigInt.zero) {
      coefficient ~/= BigInt.from(10);
      scale--;
    }
    return _B04SignedDecimal._(coefficient, scale);
  }

  bool get isNegative => coefficient.isNegative;

  _B04SignedDecimal add(_B04SignedDecimal other) {
    final scaleToUse = scale > other.scale ? scale : other.scale;
    final left = coefficient * _pow10(scaleToUse - scale);
    final right = other.coefficient * _pow10(scaleToUse - other.scale);
    return _normalize(left + right, scaleToUse);
  }

  _B04SignedDecimal subtract(_B04SignedDecimal other) =>
      add(_B04SignedDecimal._(-other.coefficient, other.scale));

  @override
  int compareTo(_B04SignedDecimal other) {
    final scaleToUse = scale > other.scale ? scale : other.scale;
    final left = coefficient * _pow10(scaleToUse - scale);
    final right = other.coefficient * _pow10(scaleToUse - other.scale);
    return left.compareTo(right);
  }

  @override
  String toString() {
    final absolute = coefficient.abs().toString().padLeft(scale + 1, '0');
    if (scale == 0) return coefficient.isNegative ? '-$absolute' : absolute;
    final split = absolute.length - scale;
    final result =
        '${absolute.substring(0, split)}.${absolute.substring(split)}';
    return coefficient.isNegative ? '-$result' : result;
  }
}

BigInt _pow10(int exponent) => BigInt.from(10).pow(exponent);
