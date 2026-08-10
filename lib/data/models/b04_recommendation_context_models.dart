import '../../core/nutrients.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/nutrition_legacy_read_models.dart';
import '../models/b02_progress_read_models.dart';
import '../models/b04_adaptive_target_models.dart';
import '../models/b04_goal_models.dart';
import '../models/b04_recovery_models.dart';
import '../repositories/calendar_read_repository.dart';

enum B04RecommendationPeriod { daily, weekly }

extension B04RecommendationPeriodId on B04RecommendationPeriod {
  String get stableId => name;
}

enum B04ContextAvailability { available, evidenceLimited, unavailable }

extension B04ContextAvailabilityId on B04ContextAvailability {
  String get stableId => switch (this) {
    B04ContextAvailability.available => 'available',
    B04ContextAvailability.evidenceLimited => 'evidence_limited',
    B04ContextAvailability.unavailable => 'unavailable',
  };
}

enum B04MissingEvidenceKind {
  nutritionTotals,
  readiness,
  workload,
  schedule,
  goal,
  consent,
  eligibility,
  mealOpportunity,
  constraintPolicy,
  targetPolicy,
}

extension B04MissingEvidenceKindId on B04MissingEvidenceKind {
  String get stableId => switch (this) {
    B04MissingEvidenceKind.nutritionTotals => 'nutrition_totals',
    B04MissingEvidenceKind.readiness => 'readiness',
    B04MissingEvidenceKind.workload => 'workload',
    B04MissingEvidenceKind.schedule => 'schedule',
    B04MissingEvidenceKind.goal => 'goal',
    B04MissingEvidenceKind.consent => 'consent',
    B04MissingEvidenceKind.eligibility => 'eligibility',
    B04MissingEvidenceKind.mealOpportunity => 'meal_opportunity',
    B04MissingEvidenceKind.constraintPolicy => 'constraint_policy',
    B04MissingEvidenceKind.targetPolicy => 'target_policy',
  };
}

class B04MissingEvidence {
  final B04MissingEvidenceKind kind;
  final String reasonCode;
  final String? localDate;

  const B04MissingEvidence({
    required this.kind,
    required this.reasonCode,
    this.localDate,
  });

  Map<String, dynamic> toRedactedMap() => {
    'kind': kind.stableId,
    'reason_code': reasonCode,
    if (localDate != null) 'local_date': localDate,
  };
}

class B04RecommendationWindow {
  final B04RecommendationPeriod period;
  final String startLocalDate;
  final String endLocalDate;
  final String timezoneId;
  final int targetEvaluationWindowDays;
  final int aggregateWindowDays;

  const B04RecommendationWindow({
    required this.period,
    required this.startLocalDate,
    required this.endLocalDate,
    required this.timezoneId,
    required this.targetEvaluationWindowDays,
    required this.aggregateWindowDays,
  });

  Map<String, dynamic> toRedactedMap() => {
    'period': period.stableId,
    'start_local_date': startLocalDate,
    'end_local_date': endLocalDate,
    'timezone_id': timezoneId,
    'target_evaluation_window_days': targetEvaluationWindowDays,
    'aggregate_window_days': aggregateWindowDays,
  };
}

class B04NutritionDayContext {
  final String localDate;
  final NutrientAggregationResult totals;
  final List<String> recordIds;
  final Map<String, int> sourceCounts;
  final List<String> compatibilityIssueIds;
  final List<String> estimateIds;
  final bool containsLegacyCompatibility;

  const B04NutritionDayContext({
    required this.localDate,
    required this.totals,
    required this.recordIds,
    required this.sourceCounts,
    required this.compatibilityIssueIds,
    required this.estimateIds,
    required this.containsLegacyCompatibility,
  });

  factory B04NutritionDayContext.fromReadModel(
    NutritionDailyReadModel readModel,
  ) {
    final estimateIds = <String>{};
    for (final record in readModel.records) {
      for (final item in record.items) {
        final estimateId = item.estimateId ?? item.sourceReference;
        if (item.estimateId != null && estimateId != null) {
          estimateIds.add(estimateId);
        }
      }
    }
    return B04NutritionDayContext(
      localDate: readModel.localDate,
      totals: readModel.totals,
      recordIds: List.unmodifiable(readModel.recordIds),
      sourceCounts: Map.unmodifiable(readModel.sourceCounts),
      compatibilityIssueIds: List.unmodifiable(
        readModel.issues.map((issue) => issue.stableId),
      ),
      estimateIds: List.unmodifiable(estimateIds.toList()..sort()),
      containsLegacyCompatibility: readModel.records.any(
        (record) => record.isLegacy,
      ),
    );
  }

  bool get isUnknown =>
      totals.completeness.state == NutrientCompletenessState.unknown ||
      totals.completeness.state == NutrientCompletenessState.invalid;

  bool get isPartial =>
      totals.completeness.state == NutrientCompletenessState.partial;

  Map<String, dynamic> toRedactedMap() => {
    'local_date': localDate,
    'completeness': totals.completeness.state.name,
    'record_count': recordIds.length,
    'record_ids': recordIds,
    'source_counts': sourceCounts,
    'compatibility_issue_ids': compatibilityIssueIds,
    'estimate_ids': estimateIds,
    'contains_legacy_compatibility': containsLegacyCompatibility,
    'lineage': {
      'nutrient_ids': totals.facts.keys.toList()..sort(),
      'source_lineage': totals.sourceLineage.keys.toList()..sort(),
      'fact_versions': totals.factVersionLineage.keys.toList()..sort(),
    },
  };
}

class B04NutritionContext {
  final List<B04NutritionDayContext> days;
  final List<String> expectedLocalDates;
  final List<String> missingLocalDates;

  const B04NutritionContext({
    required this.days,
    required this.expectedLocalDates,
    required this.missingLocalDates,
  });

  bool get hasUnknownTotals => days.any((day) => day.isUnknown);

  bool get isEvidenceLimited =>
      missingLocalDates.isNotEmpty ||
      hasUnknownTotals ||
      days.any((day) => day.isPartial);

  Map<String, dynamic> toRedactedMap() => {
    'expected_local_dates': expectedLocalDates,
    'missing_local_dates': missingLocalDates,
    'days': days.map((day) => day.toRedactedMap()).toList(),
  };
}

class B04ReadinessContext {
  final String snapshotId;
  final String localDate;
  final String timezoneId;
  final ReadinessCompleteness completeness;
  final ReadinessStatus status;
  final ReadinessBand? band;
  final double? confidence;
  final String calculationVersion;
  final String policyVersion;
  final List<String> evidenceObservationIds;

  const B04ReadinessContext({
    required this.snapshotId,
    required this.localDate,
    required this.timezoneId,
    required this.completeness,
    required this.status,
    required this.band,
    required this.confidence,
    required this.calculationVersion,
    required this.policyVersion,
    required this.evidenceObservationIds,
  });

  factory B04ReadinessContext.fromSnapshot(ReadinessSnapshotReadModel value) =>
      B04ReadinessContext(
        snapshotId: value.id,
        localDate: value.localDate,
        timezoneId: value.timezoneId,
        completeness: value.completeness,
        status: value.status,
        band: value.band,
        confidence: value.confidence,
        calculationVersion: value.calculationVersion,
        policyVersion: value.policyVersion,
        evidenceObservationIds: value.evidenceObservationIds,
      );

  bool get isUsable =>
      completeness == ReadinessCompleteness.complete &&
      status != ReadinessStatus.unavailable;

  Map<String, dynamic> toRedactedMap() => {
    'snapshot_id': snapshotId,
    'local_date': localDate,
    'timezone_id': timezoneId,
    'completeness': completeness.stableId,
    'status': status.stableId,
    if (band != null) 'band': band!.stableId,
    if (confidence != null) 'confidence': confidence,
    'calculation_version': calculationVersion,
    'policy_version': policyVersion,
    'evidence_observation_ids': evidenceObservationIds,
  };
}

class B04ScheduleContext {
  final List<String> occurrenceIds;
  final List<String> overdueOccurrenceIds;
  final String? activeProgramVersionId;

  const B04ScheduleContext({
    required this.occurrenceIds,
    required this.overdueOccurrenceIds,
    required this.activeProgramVersionId,
  });

  factory B04ScheduleContext.fromSnapshot(CalendarReadSnapshot value) =>
      B04ScheduleContext(
        occurrenceIds: List.unmodifiable(
          value.rangeOccurrences.map((item) => item.occurrence.id),
        ),
        overdueOccurrenceIds: List.unmodifiable(
          value.overdueOccurrences.map((item) => item.occurrence.id),
        ),
        activeProgramVersionId: value.activeProgramVersionId,
      );

  Map<String, dynamic> toRedactedMap() => {
    'occurrence_ids': occurrenceIds,
    'overdue_occurrence_ids': overdueOccurrenceIds,
    if (activeProgramVersionId != null)
      'active_program_version_id': activeProgramVersionId,
  };
}

class B04WorkloadContext {
  final String queryStartLocalDate;
  final String queryEndLocalDate;
  final String timezoneId;
  final List<String> activityRecordIds;
  final int partialGroupCount;
  final int targetEvidenceCount;

  const B04WorkloadContext({
    required this.queryStartLocalDate,
    required this.queryEndLocalDate,
    required this.timezoneId,
    required this.activityRecordIds,
    required this.partialGroupCount,
    required this.targetEvidenceCount,
  });

  factory B04WorkloadContext.fromProgress(
    B02ProgressReadModel value,
  ) => B04WorkloadContext(
    queryStartLocalDate: value.query.startLocalDate,
    queryEndLocalDate: value.query.endLocalDate,
    timezoneId: value.query.timezoneId,
    activityRecordIds: List.unmodifiable(
      (value.activityHistory ?? const <B02ProgressActivityRecord>[]).map(
        (item) => item.sessionId.toString(),
      ),
    ),
    partialGroupCount: (value.groupHistory ?? const <B02ProgressGroupHistory>[])
        .where((item) => item.isPartial)
        .length,
    targetEvidenceCount:
        (value.targetEvidence ?? const <B02ProgressTargetEvidence>[]).length,
  );

  Map<String, dynamic> toRedactedMap() => {
    'query_start_local_date': queryStartLocalDate,
    'query_end_local_date': queryEndLocalDate,
    'timezone_id': timezoneId,
    'activity_record_ids': activityRecordIds,
    'partial_group_count': partialGroupCount,
    'target_evidence_count': targetEvidenceCount,
  };
}

class B04ConstraintContext {
  final String subjectId;
  final String outcome;
  final String ruleVersion;
  final int taxonomyVersion;
  final String fingerprint;
  final List<String> missingEvidence;
  final List<String> evaluationIds;

  const B04ConstraintContext({
    required this.subjectId,
    required this.outcome,
    required this.ruleVersion,
    required this.taxonomyVersion,
    required this.fingerprint,
    required this.missingEvidence,
    required this.evaluationIds,
  });

  factory B04ConstraintContext.fromEvaluation(
    NutritionConstraintEvaluationResult value,
  ) => B04ConstraintContext(
    subjectId: value.subjectId,
    outcome: value.outcome.stableId,
    ruleVersion: value.ruleVersion,
    taxonomyVersion: value.taxonomyVersion,
    fingerprint: value.fingerprint,
    missingEvidence: List.unmodifiable(value.missingEvidence),
    evaluationIds: List.unmodifiable(
      value.evaluations.map((item) => item.constraintId),
    ),
  );

  Map<String, dynamic> toRedactedMap() => {
    'subject_id': subjectId,
    'outcome': outcome,
    'rule_version': ruleVersion,
    'taxonomy_version': taxonomyVersion,
    'fingerprint': fingerprint,
    'missing_evidence': missingEvidence,
    'evaluation_ids': evaluationIds,
  };
}

enum B04MealOpportunityKind {
  now,
  plannedMeal,
  postWorkout,
  userEnteredFastingExclusion,
}

extension B04MealOpportunityKindId on B04MealOpportunityKind {
  String get stableId => switch (this) {
    B04MealOpportunityKind.now => 'now',
    B04MealOpportunityKind.plannedMeal => 'planned_meal',
    B04MealOpportunityKind.postWorkout => 'post_workout',
    B04MealOpportunityKind.userEnteredFastingExclusion =>
      'user_entered_fasting_exclusion',
  };
}

enum B04MealCandidateSource {
  canonicalFood,
  publishedRecipeVersion,
  savedThali,
}

extension B04MealCandidateSourceId on B04MealCandidateSource {
  String get stableId => switch (this) {
    B04MealCandidateSource.canonicalFood => 'canonical_food',
    B04MealCandidateSource.publishedRecipeVersion => 'published_recipe_version',
    B04MealCandidateSource.savedThali => 'saved_thali',
  };
}

enum B04MealCandidateEvidenceState { complete, partial, unavailable }

extension B04MealCandidateEvidenceStateId on B04MealCandidateEvidenceState {
  String get stableId => name;
}

/// Opaque references to B03-owned identity, nutrient and constraint evidence.
/// B04 carries their state and lineage without recalculating or re-evaluating
/// any source authority.
class B04MealCandidateEvidence {
  final B04MealCandidateEvidenceState state;
  final String? identityReference;
  final String? nutrientReference;
  final String? constraintReference;
  final List<String> estimateReferences;

  const B04MealCandidateEvidence({
    required this.state,
    this.identityReference,
    this.nutrientReference,
    this.constraintReference,
    this.estimateReferences = const [],
  });

  const B04MealCandidateEvidence.complete({
    required this.identityReference,
    required this.nutrientReference,
    required this.constraintReference,
    this.estimateReferences = const [],
  }) : state = B04MealCandidateEvidenceState.complete;

  const B04MealCandidateEvidence.partial({
    this.identityReference,
    this.nutrientReference,
    this.constraintReference,
    this.estimateReferences = const [],
  }) : state = B04MealCandidateEvidenceState.partial;

  static const unavailable = B04MealCandidateEvidence(
    state: B04MealCandidateEvidenceState.unavailable,
  );

  bool get isComplete => state == B04MealCandidateEvidenceState.complete;

  Map<String, dynamic> toRedactedMap() => {
    'state': state.stableId,
    if (identityReference != null) 'identity_reference': identityReference,
    if (nutrientReference != null) 'nutrient_reference': nutrientReference,
    if (constraintReference != null)
      'constraint_reference': constraintReference,
    'estimate_references': estimateReferences,
  };
}

enum B04MealOpportunityStatus { available, noCandidate, unavailable }

extension B04MealOpportunityStatusId on B04MealOpportunityStatus {
  String get stableId => name;
}

class B04MealCandidate {
  final String selectionId;
  final B04MealCandidateSource source;
  final String subjectId;
  final B04MealCandidateEvidence evidence;

  const B04MealCandidate({
    required this.selectionId,
    required this.source,
    required this.subjectId,
    required this.evidence,
  });

  factory B04MealCandidate.fromSourceId({
    required String selectionId,
    required String sourceId,
    required String subjectId,
    B04MealCandidateEvidence evidence = B04MealCandidateEvidence.unavailable,
  }) {
    final source = switch (sourceId.trim()) {
      'canonical_food' => B04MealCandidateSource.canonicalFood,
      'published_recipe_version' =>
        B04MealCandidateSource.publishedRecipeVersion,
      'saved_thali' => B04MealCandidateSource.savedThali,
      'legacy_food_log' ||
      'meal_plan' ||
      'external_search' => throw ArgumentError(
        'Legacy, meal-plan, and external candidates are not meal opportunities.',
      ),
      _ => throw ArgumentError.value(
        sourceId,
        'sourceId',
        'Only canonical food, published recipe, or saved thali selections are supported.',
      ),
    };
    return B04MealCandidate(
      selectionId: selectionId,
      source: source,
      subjectId: subjectId,
      evidence: evidence,
    );
  }

  Map<String, dynamic> toRedactedMap() => {
    'selection_id': selectionId,
    'source': source.stableId,
    'subject_id': subjectId,
    'evidence': evidence.toRedactedMap(),
  };
}

class B04MealOpportunity {
  final B04MealOpportunityStatus status;
  final B04MealOpportunityKind? kind;
  final DateTime currentInstantUtc;
  final String localDate;
  final String timezoneId;
  final String? explicitMealCategory;
  final List<B04MealCandidate> candidates;
  final String reasonCode;

  const B04MealOpportunity({
    required this.status,
    required this.kind,
    required this.currentInstantUtc,
    required this.localDate,
    required this.timezoneId,
    required this.explicitMealCategory,
    required this.candidates,
    required this.reasonCode,
  });

  bool get hasSelection => status == B04MealOpportunityStatus.available;

  bool get hasCompleteSelection =>
      hasSelection &&
      candidates.isNotEmpty &&
      candidates.every((item) => item.evidence.isComplete);

  Map<String, dynamic> toRedactedMap() => {
    'status': status.stableId,
    if (kind != null) 'kind': kind!.stableId,
    'local_date': localDate,
    'timezone_id': timezoneId,
    if (explicitMealCategory != null)
      'explicit_meal_category': explicitMealCategory,
    'candidates': candidates.map((item) => item.toRedactedMap()).toList(),
    'reason_code': reasonCode,
  };
}

class B04N8Context {
  final String state;

  const B04N8Context._(this.state);

  static const absent = B04N8Context._('absent');

  Map<String, dynamic> toRedactedMap() => {'state': state};
}

class B04RecommendationContextInput {
  final String contextId;
  final String userId;
  final String? nutritionUserId;
  final String? constraintUserId;
  final B04RecommendationPeriod period;
  final String startLocalDate;
  final String endLocalDate;
  final String timezoneId;
  final DateTime evaluatedAtUtc;
  final NutritionGoalVersionReadModel? activeGoal;
  final CoachingPreferencesReadModel? preferences;
  final CoachingEligibilityReadModel? eligibility;
  final ReadinessSnapshotReadModel? readinessSnapshot;
  final B02ProgressReadModel? progress;
  final CalendarReadSnapshot? schedule;
  final List<NutritionDailyReadModel> nutritionDays;
  final List<NutritionConstraintEvaluationResult>? constraintEvaluations;
  final B04AdaptiveTargetResult? targetResult;
  final B04MealOpportunity? mealOpportunity;

  const B04RecommendationContextInput({
    required this.contextId,
    required this.userId,
    this.nutritionUserId,
    this.constraintUserId,
    required this.period,
    required this.startLocalDate,
    required this.endLocalDate,
    required this.timezoneId,
    required this.evaluatedAtUtc,
    required this.activeGoal,
    required this.preferences,
    required this.eligibility,
    required this.readinessSnapshot,
    required this.progress,
    required this.schedule,
    required this.nutritionDays,
    required this.constraintEvaluations,
    required this.targetResult,
    required this.mealOpportunity,
  });
}

class B04RecommendationContext {
  final String contextId;
  final String userId;
  final String nutritionUserId;
  final B04RecommendationWindow window;
  final DateTime evaluatedAtUtc;
  final B04ContextAvailability availability;
  final NutritionGoalVersionReadModel? activeGoal;
  final CoachingPreferencesReadModel? preferences;
  final CoachingEligibilityReadModel? eligibility;
  final B04ReadinessContext? readiness;
  final B04WorkloadContext? workload;
  final B04ScheduleContext? schedule;
  final B04NutritionContext nutrition;
  final List<B04ConstraintContext> constraints;
  final B04AdaptiveTargetResult? targetResult;
  final B04MealOpportunity? mealOpportunity;
  final List<B04MissingEvidence> missingEvidence;
  final B04N8Context n8;

  const B04RecommendationContext({
    required this.contextId,
    required this.userId,
    String? nutritionUserId,
    required this.window,
    required this.evaluatedAtUtc,
    required this.availability,
    required this.activeGoal,
    required this.preferences,
    required this.eligibility,
    required this.readiness,
    required this.workload,
    required this.schedule,
    required this.nutrition,
    required this.constraints,
    required this.targetResult,
    required this.mealOpportunity,
    required this.missingEvidence,
    required this.n8,
  }) : nutritionUserId = nutritionUserId ?? userId;

  /// This map is the provider/redaction boundary. It intentionally contains
  /// no user identity, display labels, raw records, prompts, images, health
  /// payloads, or mutable catalogue objects.
  Map<String, dynamic> toRedactedMap() => {
    'context_id': contextId,
    'window': window.toRedactedMap(),
    'evaluated_at_utc': evaluatedAtUtc.toIso8601String(),
    'availability': availability.stableId,
    if (activeGoal != null)
      'goal': {
        'version_id': activeGoal!.id,
        'version_number': activeGoal!.versionNumber,
        'goal_type': activeGoal!.goalType.stableId,
        'source': activeGoal!.source.stableId,
      },
    if (preferences != null)
      'consent': {
        'adaptive_coaching_enabled': preferences!.adaptiveCoachingEnabled,
        'optional_ai_enabled': preferences!.optionalAiEnabled,
      },
    if (eligibility != null)
      'eligibility': {
        'result': eligibility!.result.stableId,
        'reason_code': eligibility!.reasonCode,
        'policy_version': eligibility!.policyVersion,
      },
    if (readiness != null) 'readiness': readiness!.toRedactedMap(),
    if (workload != null) 'workload': workload!.toRedactedMap(),
    if (schedule != null) 'schedule': schedule!.toRedactedMap(),
    'nutrition': nutrition.toRedactedMap(),
    'constraints': constraints.map((item) => item.toRedactedMap()).toList(),
    if (targetResult != null)
      'target_policy': {
        'status': targetResult!.status.stableId,
        'reason_code': targetResult!.reasonCode,
        'policy_version': targetResult!.policyVersion,
        'calculation_version': targetResult!.calculationVersion,
        'algorithm_version': targetResult!.algorithmVersion,
        'evidence_ids': targetResult!.evidenceIds,
      },
    if (mealOpportunity != null)
      'meal_opportunity': mealOpportunity!.toRedactedMap(),
    'missing_evidence': missingEvidence
        .map((item) => item.toRedactedMap())
        .toList(),
    'n8': n8.toRedactedMap(),
  };
}
