import '../../core/nutrients.dart';
import '../../core/nutrition_constraints.dart';
import '../../core/typed_quantities.dart';

/// Version of the B04 mapping contract over the accepted B03 safety result.
/// B03 remains the evaluator and evidence authority.
const String kB04NutritionSafetyMapperVersion = 'b04-d08-mapper-v1';

enum B04NutritionSafetyOutput {
  eatNow,
  adaptiveTarget,
  dailyCoaching,
  weeklyCoaching,
  rankedMealCandidates,
  suitableCandidate,
  lowRiskLogging,
}

extension B04NutritionSafetyOutputId on B04NutritionSafetyOutput {
  String get stableId => switch (this) {
    B04NutritionSafetyOutput.eatNow => 'eat_now',
    B04NutritionSafetyOutput.adaptiveTarget => 'adaptive_target',
    B04NutritionSafetyOutput.dailyCoaching => 'daily_coaching',
    B04NutritionSafetyOutput.weeklyCoaching => 'weekly_coaching',
    B04NutritionSafetyOutput.rankedMealCandidates => 'ranked_meal_candidates',
    B04NutritionSafetyOutput.suitableCandidate => 'suitable_candidate',
    B04NutritionSafetyOutput.lowRiskLogging => 'low_risk_logging',
  };

  bool get isSafetySensitive => this != B04NutritionSafetyOutput.lowRiskLogging;
}

enum B04NutritionSafetyDisposition {
  noKnownConflict,
  softFilter,
  hardBlock,
  unavailable,
  lowRiskLoggingOnly,
}

extension B04NutritionSafetyDispositionId on B04NutritionSafetyDisposition {
  String get stableId => switch (this) {
    B04NutritionSafetyDisposition.noKnownConflict => 'no_known_conflict',
    B04NutritionSafetyDisposition.softFilter => 'soft_filter',
    B04NutritionSafetyDisposition.hardBlock => 'hard_block',
    B04NutritionSafetyDisposition.unavailable => 'unavailable',
    B04NutritionSafetyDisposition.lowRiskLoggingOnly => 'low_risk_logging_only',
  };
}

enum B04NutritionSafetyBoundaryDirection { maximum, minimum }

extension B04NutritionSafetyBoundaryDirectionId
    on B04NutritionSafetyBoundaryDirection {
  String get stableId => switch (this) {
    B04NutritionSafetyBoundaryDirection.maximum => 'maximum',
    B04NutritionSafetyBoundaryDirection.minimum => 'minimum',
  };
}

/// A caller-supplied approved decision boundary for one typed nutrient range.
/// B04 compares B03 bounds against this boundary; it does not create a new
/// nutrient calculation or exactify an estimate.
class B04NutritionSafetyNutrientBoundary {
  final String nutrientId;
  final B04NutritionSafetyBoundaryDirection direction;
  final NutrientAmount threshold;
  final String reasonCode;

  B04NutritionSafetyNutrientBoundary({
    required String nutrientId,
    required this.direction,
    required this.threshold,
    String reasonCode = 'nutrient_decision_boundary',
  }) : nutrientId = nutrientId.trim(),
       reasonCode = reasonCode.trim() {
    if (this.nutrientId.isEmpty || this.reasonCode.isEmpty) {
      throw ArgumentError('Nutrient boundaries require stable IDs.');
    }
    if (threshold.value.compareTo(QuantityAmount.zero) < 0) {
      throw ArgumentError('Nutrient boundaries cannot be negative.');
    }
  }

  Map<String, dynamic> toRedactedMap() => {
    'nutrient_id': nutrientId,
    'direction': direction.stableId,
    'threshold': threshold.toJson(),
    'reason_code': reasonCode,
  };
}

class B04NutritionSafetyConstraintContext {
  final String constraintId;
  final NutritionConstraintType type;
  final String targetKey;
  final NutritionConstraintStrictness strictness;
  final String? severity;
  final bool crossContact;

  const B04NutritionSafetyConstraintContext({
    required this.constraintId,
    required this.type,
    required this.targetKey,
    required this.strictness,
    required this.severity,
    required this.crossContact,
  });

  factory B04NutritionSafetyConstraintContext.fromConstraint(
    NutritionUserConstraint constraint,
  ) => B04NutritionSafetyConstraintContext(
    constraintId: constraint.id,
    type: constraint.type,
    targetKey: constraint.target.stableKey,
    strictness: constraint.strictness,
    severity: constraint.severity,
    crossContact: constraint.crossContact,
  );

  Map<String, dynamic> toRedactedMap() => {
    'constraint_id': constraintId,
    'strictness': strictness.stableId,
    'cross_contact': crossContact,
  };
}

class B04NutritionSafetyResult {
  final String userId;
  final String subjectId;
  final B04NutritionSafetyOutput output;
  final B04NutritionSafetyDisposition disposition;
  final B04NutritionSafetyDisposition evaluatedDisposition;
  final NutritionConstraintEvaluationResult? constraintEvaluation;
  final NutritionConstraintOutcome? evaluatorOutcome;
  final NutrientAggregationResult? nutrientEvidence;
  final String policyVersion;
  final List<String> reasonCodes;
  final List<String> evidenceIds;
  final List<String> missingEvidence;
  final List<String> hardBlockConstraintIds;
  final List<String> softFilterConstraintIds;
  final List<String> uncertainConstraintIds;
  final List<String> nutrientRangeIds;
  final List<B04NutritionSafetyConstraintContext> constraintContexts;
  final String? invalidEvidenceCode;
  final bool acknowledgementRequested;
  final bool userOverrideRequested;

  B04NutritionSafetyResult({
    required String userId,
    required String subjectId,
    required this.output,
    required this.disposition,
    required this.evaluatedDisposition,
    required this.constraintEvaluation,
    required this.evaluatorOutcome,
    required this.nutrientEvidence,
    this.policyVersion = kB04NutritionSafetyMapperVersion,
    required Iterable<String> reasonCodes,
    required Iterable<String> evidenceIds,
    required Iterable<String> missingEvidence,
    required Iterable<String> hardBlockConstraintIds,
    required Iterable<String> softFilterConstraintIds,
    required Iterable<String> uncertainConstraintIds,
    required Iterable<String> nutrientRangeIds,
    required Iterable<B04NutritionSafetyConstraintContext> constraintContexts,
    String? invalidEvidenceCode,
    this.acknowledgementRequested = false,
    this.userOverrideRequested = false,
  }) : userId = userId.trim(),
       subjectId = subjectId.trim(),
       reasonCodes = _sortedUnique(reasonCodes),
       evidenceIds = _sortedUnique(evidenceIds),
       missingEvidence = _sortedUnique(missingEvidence),
       hardBlockConstraintIds = _sortedUnique(hardBlockConstraintIds),
       softFilterConstraintIds = _sortedUnique(softFilterConstraintIds),
       uncertainConstraintIds = _sortedUnique(uncertainConstraintIds),
       nutrientRangeIds = _sortedUnique(nutrientRangeIds),
       constraintContexts = List.unmodifiable(
         constraintContexts.toList()
           ..sort((a, b) => a.constraintId.compareTo(b.constraintId)),
       ),
       invalidEvidenceCode = invalidEvidenceCode?.trim() {
    if (this.userId.isEmpty || this.subjectId.isEmpty) {
      throw ArgumentError('Nutrition safety results require user and subject.');
    }
    if (policyVersion.trim().isEmpty) {
      throw ArgumentError('Nutrition safety results require a policy version.');
    }
    final evaluation = constraintEvaluation;
    if (evaluation != null &&
        (evaluation.userId != this.userId ||
            evaluation.subjectId != this.subjectId)) {
      throw ArgumentError(
        'Constraint evaluation ownership must match the safety result.',
      );
    }
    if (evaluatedDisposition == B04NutritionSafetyDisposition.hardBlock &&
        hardBlockConstraintIds.isEmpty) {
      throw ArgumentError('A hard block requires a constraint identity.');
    }
    if (invalidEvidenceCode != null &&
        evaluatedDisposition != B04NutritionSafetyDisposition.unavailable) {
      throw ArgumentError('Invalid evidence must be unavailable.');
    }
    if (output.isSafetySensitive &&
        disposition == B04NutritionSafetyDisposition.lowRiskLoggingOnly) {
      throw ArgumentError(
        'Low-risk logging is a separate non-recommendation output.',
      );
    }
    if (!output.isSafetySensitive &&
        disposition != B04NutritionSafetyDisposition.lowRiskLoggingOnly) {
      throw ArgumentError(
        'Low-risk logging output must remain separately scoped.',
      );
    }
  }

  factory B04NutritionSafetyResult.invalidEvidence({
    required String userId,
    required String subjectId,
    required B04NutritionSafetyOutput output,
    required String errorCode,
    NutrientAggregationResult? nutrientEvidence,
    bool acknowledgementRequested = false,
    bool userOverrideRequested = false,
  }) {
    final disposition = output.isSafetySensitive
        ? B04NutritionSafetyDisposition.unavailable
        : B04NutritionSafetyDisposition.lowRiskLoggingOnly;
    return B04NutritionSafetyResult(
      userId: userId,
      subjectId: subjectId,
      output: output,
      disposition: disposition,
      evaluatedDisposition: B04NutritionSafetyDisposition.unavailable,
      constraintEvaluation: null,
      evaluatorOutcome: null,
      nutrientEvidence: nutrientEvidence,
      reasonCodes: const ['structurally_invalid_evidence'],
      evidenceIds: const [],
      missingEvidence: [errorCode],
      hardBlockConstraintIds: const [],
      softFilterConstraintIds: const [],
      uncertainConstraintIds: const [],
      nutrientRangeIds: const [],
      constraintContexts: const [],
      invalidEvidenceCode: errorCode,
      acknowledgementRequested: acknowledgementRequested,
      userOverrideRequested: userOverrideRequested,
    );
  }

  bool get recommendationAllowed =>
      output.isSafetySensitive &&
      (disposition == B04NutritionSafetyDisposition.noKnownConflict ||
          disposition == B04NutritionSafetyDisposition.softFilter);

  bool get isHardBlock =>
      evaluatedDisposition == B04NutritionSafetyDisposition.hardBlock;

  bool get isUnavailable =>
      evaluatedDisposition == B04NutritionSafetyDisposition.unavailable;

  bool get isLowRiskLoggingOnly =>
      disposition == B04NutritionSafetyDisposition.lowRiskLoggingOnly;

  String? get constraintRuleVersion => constraintEvaluation?.ruleVersion;

  int? get constraintTaxonomyVersion => constraintEvaluation?.taxonomyVersion;

  DateTime? get constraintEvaluatedAtUtc =>
      constraintEvaluation?.evaluatedAtUtc;

  String? get constraintEvaluationFingerprint =>
      constraintEvaluation?.fingerprint;

  /// Exact approved semantic text for the safety states. No-known-conflict is
  /// deliberately not phrased as safe or guaranteed.
  String get wording => switch (disposition) {
    B04NutritionSafetyDisposition.noKnownConflict =>
      'No known conflict was detected for the checked evidence.',
    B04NutritionSafetyDisposition.softFilter =>
      'This candidate is filtered by a recorded preference.',
    B04NutritionSafetyDisposition.hardBlock =>
      'This candidate is blocked by the recorded dietary constraint.',
    B04NutritionSafetyDisposition.unavailable =>
      'Safety-sensitive guidance is unavailable because dietary evidence is missing or uncertain.',
    B04NutritionSafetyDisposition.lowRiskLoggingOnly =>
      'You may record a personal log, but acknowledgement does not make the item suitable or safe.',
  };

  Map<String, dynamic> toRedactedMap() => {
    'subject_id': subjectId,
    'output': output.stableId,
    'disposition': disposition.stableId,
    'evaluated_disposition': evaluatedDisposition.stableId,
    if (evaluatorOutcome != null)
      'evaluator_outcome': evaluatorOutcome!.stableId,
    'policy_version': policyVersion,
    'reason_codes': reasonCodes,
    'evidence_ids': evidenceIds,
    'missing_evidence_count': missingEvidence.length,
    'hard_block_constraint_ids': hardBlockConstraintIds,
    'soft_filter_constraint_ids': softFilterConstraintIds,
    'uncertain_constraint_ids': uncertainConstraintIds,
    'nutrient_range_ids': nutrientRangeIds,
    'constraint_contexts': constraintContexts
        .map((item) => item.toRedactedMap())
        .toList(),
    if (constraintRuleVersion != null)
      'constraint_rule_version': constraintRuleVersion,
    if (constraintTaxonomyVersion != null)
      'constraint_taxonomy_version': constraintTaxonomyVersion,
    if (constraintEvaluatedAtUtc != null)
      'constraint_evaluated_at_utc': constraintEvaluatedAtUtc!
          .toIso8601String(),
    if (constraintEvaluationFingerprint != null)
      'constraint_evaluation_fingerprint': constraintEvaluationFingerprint,
    if (invalidEvidenceCode != null)
      'invalid_evidence_code': invalidEvidenceCode,
    'acknowledgement_requested': acknowledgementRequested,
    'user_override_requested': userOverrideRequested,
    if (nutrientEvidence != null)
      'nutrient_evidence': {
        'completeness': nutrientEvidence!.completeness.toJson(),
        'facts': {
          for (final entry in nutrientEvidence!.facts.entries)
            entry.key: {
              'unit': entry.value.unit.stableId,
              'status': entry.value.status.stableId,
              if (entry.value.point != null)
                'point': entry.value.point!.toJson(),
              if (entry.value.lower != null)
                'lower': entry.value.lower!.toJson(),
              if (entry.value.upper != null)
                'upper': entry.value.upper!.toJson(),
              'fact_version': entry.value.factVersion,
              'coverage_incomplete': entry.value.coverageIncomplete,
            },
        },
        'source_lineage': {
          for (final entry in nutrientEvidence!.sourceLineage.entries)
            entry.key: entry.value.map((source) => source.stableId).toList(),
        },
        'fact_version_lineage': nutrientEvidence!.factVersionLineage,
      },
  };
}

List<String> _sortedUnique(Iterable<String> values) {
  final result =
      values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return List.unmodifiable(result);
}
