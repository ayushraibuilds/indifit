import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../models/b04_adaptive_target_models.dart';
import '../models/b04_goal_models.dart';
import '../models/b04_recommendation_context_models.dart';
import '../models/b04_recovery_models.dart';

/// Pure B04-08 boundary that assembles frozen read models into an ephemeral
/// recommendation context. It owns no repository, calculator, evaluator,
/// persistence, provider, or AI access.
class B04RecommendationContextAssembler {
  final LocalScheduleDateService _dates;
  final B04AdaptiveTargetPolicy policy;

  B04RecommendationContextAssembler({
    LocalScheduleDateService? dates,
    this.policy = B04AdaptiveTargetPolicy.current,
  }) : _dates = dates ?? LocalScheduleDateService();

  B04RecommendationContext assemble(B04RecommendationContextInput input) {
    final contextId = input.contextId.trim();
    final userId = input.userId.trim();
    if (contextId.isEmpty || userId.isEmpty) {
      throw ArgumentError('A recommendation context requires an identity.');
    }
    if (!input.evaluatedAtUtc.isUtc) {
      throw ArgumentError.value(
        input.evaluatedAtUtc,
        'evaluatedAtUtc',
        'Context evaluation time must be UTC.',
      );
    }

    final timezoneId = input.timezoneId.trim();
    _dates.validateTimezone(timezoneId);
    final start = _dates.normalizeLocalDate(input.startLocalDate);
    final end = _dates.normalizeLocalDate(input.endLocalDate);
    final expectedDates = _expectedDates(
      period: input.period,
      start: start,
      end: end,
      timezoneId: timezoneId,
    );

    final missing = <B04MissingEvidence>[];
    _validateOwner(userId, input.activeGoal?.userId, 'goal');
    _validateOwner(userId, input.preferences?.userId, 'consent');
    _validateOwner(userId, input.eligibility?.userId, 'eligibility');
    _validateOwner(userId, input.readinessSnapshot?.userId, 'readiness');
    if (input.progress != null &&
        input.progress!.query.timezoneId != timezoneId) {
      throw ArgumentError(
        'Workload read model timezone must match the frozen context timezone.',
      );
    }
    if (input.mealOpportunity != null &&
        input.mealOpportunity!.timezoneId != timezoneId) {
      throw ArgumentError(
        'Meal opportunity timezone must match the frozen context timezone.',
      );
    }
    if (input.mealOpportunity != null) {
      _validateMealOpportunity(input.mealOpportunity!, timezoneId);
      if (!expectedDates.contains(input.mealOpportunity!.localDate)) {
        throw ArgumentError(
          'Meal opportunity local date must be inside the frozen context period.',
        );
      }
    }

    _validateGoalPeriod(
      input.activeGoal,
      timezoneId: timezoneId,
      start: start,
      end: end,
      missing: missing,
    );
    _validateEligibilityPeriod(
      input.eligibility,
      timezoneId: timezoneId,
      expectedDates: expectedDates,
      missing: missing,
    );

    if (input.activeGoal == null) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.goal,
          reasonCode: 'goal_unavailable',
        ),
      );
    }
    if (input.preferences == null ||
        !input.preferences!.adaptiveCoachingEnabled) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.consent,
          reasonCode: 'coaching_consent_required',
        ),
      );
    }
    if (input.eligibility == null) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.eligibility,
          reasonCode: 'eligibility_unavailable',
        ),
      );
    } else if (!input.eligibility!.isEligible) {
      missing.add(
        B04MissingEvidence(
          kind: B04MissingEvidenceKind.eligibility,
          reasonCode: input.eligibility!.result.stableId,
        ),
      );
    }

    final nutrition = _nutritionContext(
      input.nutritionDays,
      expectedDates,
      userId,
      missing,
    );
    final readiness = _readinessContext(
      input.readinessSnapshot,
      expectedDates,
      timezoneId,
      missing,
    );
    final workload = input.progress == null
        ? null
        : B04WorkloadContext.fromProgress(input.progress!);
    if (workload == null) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.workload,
          reasonCode: 'workload_unavailable',
        ),
      );
    }
    final schedule = input.schedule == null
        ? null
        : B04ScheduleContext.fromSnapshot(input.schedule!);
    if (schedule == null) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.schedule,
          reasonCode: 'schedule_unavailable',
        ),
      );
    }

    final constraints = input.constraintEvaluations == null
        ? const <B04ConstraintContext>[]
        : input.constraintEvaluations!
              .map((item) {
                _validateOwner(userId, item.userId, 'constraint');
                return B04ConstraintContext.fromEvaluation(item);
              })
              .toList(growable: false);
    if (input.constraintEvaluations == null) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.constraintPolicy,
          reasonCode: 'constraint_evaluation_unavailable',
        ),
      );
    }

    if (input.targetResult == null) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.targetPolicy,
          reasonCode: 'target_policy_unavailable',
        ),
      );
    } else if (!_targetLineageMatches(input.targetResult!)) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.targetPolicy,
          reasonCode: 'target_policy_lineage_mismatch',
        ),
      );
    }

    final opportunity = input.mealOpportunity;
    if (opportunity != null && !opportunity.hasSelection) {
      missing.add(
        B04MissingEvidence(
          kind: B04MissingEvidenceKind.mealOpportunity,
          reasonCode: opportunity.reasonCode,
        ),
      );
    } else if (opportunity != null && !opportunity.hasCompleteSelection) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.mealOpportunity,
          reasonCode: 'candidate_evidence_partial',
        ),
      );
    }

    final availability = _availability(
      missing: missing,
      nutrition: nutrition,
      readiness: readiness,
      opportunity: opportunity,
    );
    final normalizedMissing = List<B04MissingEvidence>.unmodifiable(
      missing.fold<Map<String, B04MissingEvidence>>({}, (map, item) {
        final key = '${item.kind.stableId}:${item.localDate ?? ''}';
        map[key] = item;
        return map;
      }).values,
    );

    return B04RecommendationContext(
      contextId: contextId,
      userId: userId,
      window: B04RecommendationWindow(
        period: input.period,
        startLocalDate: start,
        endLocalDate: end,
        timezoneId: timezoneId,
        targetEvaluationWindowDays: policy.evaluationWindowDays,
        aggregateWindowDays: policy.aggregateWindowDays,
      ),
      evaluatedAtUtc: input.evaluatedAtUtc,
      availability: availability,
      activeGoal: input.activeGoal,
      preferences: input.preferences,
      eligibility: input.eligibility,
      readiness: readiness,
      workload: workload,
      schedule: schedule,
      nutrition: nutrition,
      constraints: List.unmodifiable(constraints),
      targetResult: input.targetResult,
      mealOpportunity: opportunity,
      missingEvidence: normalizedMissing,
      n8: B04N8Context.absent,
    );
  }

  List<String> _expectedDates({
    required B04RecommendationPeriod period,
    required String start,
    required String end,
    required String timezoneId,
  }) {
    final expectedDays = period == B04RecommendationPeriod.daily ? 1 : 7;
    if (period == B04RecommendationPeriod.daily && start != end) {
      throw ArgumentError('A daily context must cover exactly one civil date.');
    }
    if (period == B04RecommendationPeriod.weekly) {
      final finalExpected = _dates.addCalendarDays(
        start,
        timezoneId,
        expectedDays - 1,
      );
      if (finalExpected != end) {
        throw ArgumentError(
          'A weekly context must cover exactly seven civil dates.',
        );
      }
    }
    return List.unmodifiable([
      for (var index = 0; index < expectedDays; index++)
        _dates.addCalendarDays(start, timezoneId, index),
    ]);
  }

  B04NutritionContext _nutritionContext(
    List<NutritionDailyReadModel> source,
    List<String> expectedDates,
    String userId,
    List<B04MissingEvidence> missing,
  ) {
    final byDate = <String, NutritionDailyReadModel>{};
    for (final day in source) {
      if (day.userId != userId) {
        throw ArgumentError(
          'Nutrition read model owner does not match context.',
        );
      }
      final localDate = _dates.normalizeLocalDate(day.localDate);
      if (!expectedDates.contains(localDate)) {
        throw ArgumentError(
          'Nutrition read model date is outside the frozen context window.',
        );
      }
      if (byDate.putIfAbsent(localDate, () => day) != day) {
        throw ArgumentError('Nutrition context cannot repeat a local date.');
      }
      for (final record in day.records) {
        if (record.userId != userId ||
            _dates.normalizeLocalDate(record.localDate) != localDate) {
          throw ArgumentError(
            'Nutrition record must retain its source owner and local date.',
          );
        }
      }
    }
    final days = <B04NutritionDayContext>[];
    final missingDates = <String>[];
    for (final date in expectedDates) {
      final readModel = byDate[date];
      if (readModel == null) {
        missingDates.add(date);
        missing.add(
          B04MissingEvidence(
            kind: B04MissingEvidenceKind.nutritionTotals,
            reasonCode: 'daily_totals_unavailable',
            localDate: date,
          ),
        );
        continue;
      }
      final day = B04NutritionDayContext.fromReadModel(readModel);
      days.add(day);
      if (day.isUnknown || day.isPartial) {
        missing.add(
          B04MissingEvidence(
            kind: B04MissingEvidenceKind.nutritionTotals,
            reasonCode: day.isUnknown
                ? 'daily_totals_unknown'
                : 'daily_totals_partial',
            localDate: date,
          ),
        );
      }
    }
    return B04NutritionContext(
      days: List.unmodifiable(days),
      expectedLocalDates: expectedDates,
      missingLocalDates: List.unmodifiable(missingDates),
    );
  }

  B04ReadinessContext? _readinessContext(
    ReadinessSnapshotReadModel? source,
    List<String> expectedDates,
    String timezoneId,
    List<B04MissingEvidence> missing,
  ) {
    if (source == null) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.readiness,
          reasonCode: 'readiness_unavailable',
        ),
      );
      return null;
    }
    final localDate = _dates.normalizeLocalDate(source.localDate);
    if (!expectedDates.contains(localDate) || source.timezoneId != timezoneId) {
      throw ArgumentError(
        'Readiness snapshot must retain its source local date and timezone.',
      );
    }
    final result = B04ReadinessContext.fromSnapshot(source);
    if (!result.isUsable) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.readiness,
          reasonCode: 'readiness_incomplete_or_unavailable',
        ),
      );
    }
    return result;
  }

  B04ContextAvailability _availability({
    required List<B04MissingEvidence> missing,
    required B04NutritionContext nutrition,
    required B04ReadinessContext? readiness,
    required B04MealOpportunity? opportunity,
  }) {
    final hardKinds = {
      B04MissingEvidenceKind.goal,
      B04MissingEvidenceKind.consent,
      B04MissingEvidenceKind.eligibility,
      B04MissingEvidenceKind.targetPolicy,
    };
    if (missing.any((item) => hardKinds.contains(item.kind))) {
      return B04ContextAvailability.unavailable;
    }
    if (missing.isNotEmpty ||
        nutrition.isEvidenceLimited ||
        readiness == null ||
        (opportunity != null && !opportunity.hasSelection)) {
      return B04ContextAvailability.evidenceLimited;
    }
    return B04ContextAvailability.available;
  }

  void _validateGoalPeriod(
    NutritionGoalVersionReadModel? goal, {
    required String timezoneId,
    required String start,
    required String end,
    required List<B04MissingEvidence> missing,
  }) {
    if (goal == null) return;
    _dates.validateTimezone(goal.timezoneId);
    if (goal.timezoneId != timezoneId) {
      throw ArgumentError(
        'Goal timezone must match the frozen context timezone.',
      );
    }
    final effectiveFrom = _dates.normalizeLocalDate(
      goal.effectiveFromLocalDate,
    );
    final effectiveTo = goal.effectiveToLocalDate == null
        ? null
        : _dates.normalizeLocalDate(goal.effectiveToLocalDate!);
    if (effectiveTo != null && _dates.compare(effectiveFrom, effectiveTo) > 0) {
      throw ArgumentError('Goal effective dates must be ordered.');
    }
    if (_dates.compare(effectiveFrom, start) > 0 ||
        (effectiveTo != null && _dates.compare(effectiveTo, end) < 0)) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.goal,
          reasonCode: 'goal_not_effective_for_context',
        ),
      );
    }
  }

  void _validateEligibilityPeriod(
    CoachingEligibilityReadModel? eligibility, {
    required String timezoneId,
    required List<String> expectedDates,
    required List<B04MissingEvidence> missing,
  }) {
    if (eligibility == null) return;
    _dates.validateTimezone(eligibility.timezoneId);
    if (eligibility.timezoneId != timezoneId) {
      throw ArgumentError(
        'Eligibility timezone must match the frozen context timezone.',
      );
    }
    final evaluationDate = _dates.normalizeLocalDate(
      eligibility.evaluationLocalDate,
    );
    if (!expectedDates.contains(evaluationDate)) {
      missing.add(
        const B04MissingEvidence(
          kind: B04MissingEvidenceKind.eligibility,
          reasonCode: 'eligibility_not_evaluated_for_context',
        ),
      );
    }
  }

  void _validateMealOpportunity(
    B04MealOpportunity opportunity,
    String timezoneId,
  ) {
    if (!opportunity.currentInstantUtc.isUtc) {
      throw ArgumentError('Meal opportunity instant must be UTC.');
    }
    final derivedLocalDate = _dates.localDateFor(
      opportunity.currentInstantUtc,
      timezoneId,
    );
    if (derivedLocalDate != opportunity.localDate) {
      throw ArgumentError(
        'Meal opportunity local date must retain its source instant and timezone.',
      );
    }
    final selectionIds = <String>{};
    for (final candidate in opportunity.candidates) {
      if (candidate.selectionId.trim().isEmpty ||
          candidate.subjectId.trim().isEmpty ||
          !selectionIds.add(candidate.selectionId.trim())) {
        throw ArgumentError(
          'Meal opportunity candidates must be unique and identified.',
        );
      }
      if (candidate.evidence.isComplete &&
          (candidate.evidence.identityReference?.trim().isEmpty != false ||
              candidate.evidence.nutrientReference?.trim().isEmpty != false ||
              candidate.evidence.constraintReference?.trim().isEmpty !=
                  false)) {
        throw ArgumentError(
          'Complete meal candidate evidence must retain all B03 references.',
        );
      }
    }
  }

  static void _validateOwner(String owner, String? sourceOwner, String name) {
    if (sourceOwner != null && sourceOwner != owner) {
      throw ArgumentError('$name read model owner does not match context.');
    }
  }

  bool _targetLineageMatches(B04AdaptiveTargetResult target) {
    if (target.policyVersion == policy.policyVersion &&
        target.calculationVersion == policy.calculationVersion &&
        target.algorithmVersion == policy.algorithmVersion) {
      return true;
    }
    return target.reasonCode == 'adaptive_policy_hold' &&
        target.policyVersion == kB04HoldPolicyVersion &&
        target.calculationVersion == 'B04-07-TARGET-HOLD-V1' &&
        target.algorithmVersion == kB04HoldPolicyVersion;
  }
}
