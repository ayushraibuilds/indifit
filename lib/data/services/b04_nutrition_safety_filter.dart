import '../../core/nutrients.dart';
import '../../core/nutrition_constraints.dart';
import '../models/b04_nutrition_safety_models.dart';

/// Pure B04 policy mapping over the accepted B03 dietary evaluator.
///
/// This class never infers a restriction, recalculates nutrient facts,
/// rewrites B03 evidence, calls a network provider, or treats acknowledgement
/// or user override as safety evidence.
class B04NutritionSafetyFilter {
  final NutritionConstraintEvaluator _evaluator;

  const B04NutritionSafetyFilter({
    NutritionConstraintEvaluator evaluator =
        const NutritionConstraintEvaluator(),
  }) : _evaluator = evaluator;

  /// Runs the sole B03 evaluator, then maps its immutable result to B04
  /// recommendation policy. B03 validation failures become typed unavailable
  /// output rather than escaping as a safety-sensitive recommendation.
  B04NutritionSafetyResult evaluate({
    required NutritionConstraintEvaluationInput subject,
    required Iterable<NutritionUserConstraint> constraints,
    required B04NutritionSafetyOutput output,
    NutrientAggregationResult? nutrientEvidence,
    Iterable<B04NutritionSafetyNutrientBoundary> nutrientBoundaries = const [],
    Iterable<String> acknowledgedConstraintIds = const [],
    bool acknowledgementRequested = false,
    bool userOverrideRequested = false,
  }) {
    final ownedConstraints = List<NutritionUserConstraint>.unmodifiable(
      constraints,
    );
    try {
      final evaluation = _evaluator.evaluate(
        subject: subject,
        constraints: ownedConstraints,
        acknowledgedConstraintIds: acknowledgedConstraintIds,
      );
      return mapEvaluation(
        evaluation: evaluation,
        output: output,
        nutrientEvidence: nutrientEvidence,
        nutrientBoundaries: nutrientBoundaries,
        constraints: ownedConstraints,
        acknowledgementRequested: acknowledgementRequested,
        userOverrideRequested: userOverrideRequested,
      );
    } on NutritionConstraintError catch (error) {
      return B04NutritionSafetyResult.invalidEvidence(
        userId: subject.userId,
        subjectId: subject.subjectId,
        output: output,
        errorCode: error.code,
        nutrientEvidence: nutrientEvidence,
        acknowledgementRequested: acknowledgementRequested,
        userOverrideRequested: userOverrideRequested,
      );
    }
  }

  /// Maps a previously evaluated B03 result without running a second
  /// evaluator or changing the original evidence.
  B04NutritionSafetyResult mapEvaluation({
    required NutritionConstraintEvaluationResult evaluation,
    required B04NutritionSafetyOutput output,
    NutrientAggregationResult? nutrientEvidence,
    Iterable<B04NutritionSafetyNutrientBoundary> nutrientBoundaries = const [],
    Iterable<NutritionUserConstraint> constraints = const [],
    bool acknowledgementRequested = false,
    bool userOverrideRequested = false,
  }) {
    final reasons = <String>{};
    final missingEvidence = <String>{...evaluation.missingEvidence};
    final evidenceIds = <String>{};
    final hardBlocks = <String>{};
    final softFilters = <String>{};
    final uncertain = <String>{};
    final constraintsById = {
      for (final constraint in constraints) constraint.id: constraint,
    };
    final constraintContexts = [
      for (final evaluationItem in evaluation.evaluations)
        if (constraintsById[evaluationItem.constraintId] != null)
          B04NutritionSafetyConstraintContext.fromConstraint(
            constraintsById[evaluationItem.constraintId]!,
          ),
    ];

    for (final item in evaluation.evaluations) {
      evidenceIds.addAll(
        item.evidence.map((reference) => reference.evidenceId),
      );
      missingEvidence.addAll(item.missingEvidence);
      reasons.addAll(_mappedReasons(item));
      switch (item.outcome) {
        case NutritionConstraintOutcome.confirmedConflict:
          if (_isHardBlockType(
            item.type,
            strictness: constraintsById[item.constraintId]?.strictness,
          )) {
            hardBlocks.add(item.constraintId);
          } else {
            softFilters.add(item.constraintId);
          }
        case NutritionConstraintOutcome.possibleConflict:
        case NutritionConstraintOutcome.insufficientInformation:
          uncertain.add(item.constraintId);
        case NutritionConstraintOutcome.noKnownConflict:
          break;
      }
    }

    final nutrientAssessment = _assessNutrients(
      nutrientEvidence: nutrientEvidence,
      boundaries: nutrientBoundaries,
    );
    reasons.addAll(nutrientAssessment.reasonCodes);
    missingEvidence.addAll(nutrientAssessment.missingEvidence);
    evidenceIds.addAll(nutrientAssessment.evidenceIds);

    if (acknowledgementRequested) {
      reasons.add('acknowledgement_does_not_change_safety');
    }
    if (userOverrideRequested) {
      reasons.add('user_override_does_not_change_safety');
    }

    final evaluatedDisposition = _disposition(
      hardBlocks: hardBlocks,
      uncertain: uncertain,
      nutrientUnavailable: nutrientAssessment.unavailable,
      softFilters: softFilters,
    );
    final disposition = output.isSafetySensitive
        ? evaluatedDisposition
        : B04NutritionSafetyDisposition.lowRiskLoggingOnly;

    return B04NutritionSafetyResult(
      userId: evaluation.userId,
      subjectId: evaluation.subjectId,
      output: output,
      disposition: disposition,
      evaluatedDisposition: evaluatedDisposition,
      constraintEvaluation: evaluation,
      evaluatorOutcome: evaluation.outcome,
      nutrientEvidence: nutrientEvidence,
      reasonCodes: reasons,
      evidenceIds: evidenceIds,
      missingEvidence: missingEvidence,
      hardBlockConstraintIds: hardBlocks,
      softFilterConstraintIds: softFilters,
      uncertainConstraintIds: uncertain,
      nutrientRangeIds: nutrientAssessment.rangeIds,
      constraintContexts: constraintContexts,
      acknowledgementRequested: acknowledgementRequested,
      userOverrideRequested: userOverrideRequested,
    );
  }

  /// Safe adapter for malformed evidence rejected before a B03 result exists.
  B04NutritionSafetyResult unavailableForInvalidEvidence({
    required String userId,
    required String subjectId,
    required B04NutritionSafetyOutput output,
    required String errorCode,
    NutrientAggregationResult? nutrientEvidence,
    bool acknowledgementRequested = false,
    bool userOverrideRequested = false,
  }) => B04NutritionSafetyResult.invalidEvidence(
    userId: userId,
    subjectId: subjectId,
    output: output,
    errorCode: errorCode,
    nutrientEvidence: nutrientEvidence,
    acknowledgementRequested: acknowledgementRequested,
    userOverrideRequested: userOverrideRequested,
  );

  B04NutritionSafetyDisposition _disposition({
    required Set<String> hardBlocks,
    required Set<String> uncertain,
    required bool nutrientUnavailable,
    required Set<String> softFilters,
  }) {
    if (hardBlocks.isNotEmpty) return B04NutritionSafetyDisposition.hardBlock;
    if (uncertain.isNotEmpty || nutrientUnavailable) {
      return B04NutritionSafetyDisposition.unavailable;
    }
    if (softFilters.isNotEmpty) return B04NutritionSafetyDisposition.softFilter;
    return B04NutritionSafetyDisposition.noKnownConflict;
  }

  bool _isHardBlockType(
    NutritionConstraintType type, {
    NutritionConstraintStrictness? strictness,
  }) {
    if (strictness != null &&
        strictness != NutritionConstraintStrictness.avoid) {
      return false;
    }
    return switch (type) {
      NutritionConstraintType.allergy => true,
      NutritionConstraintType.intolerance => true,
      NutritionConstraintType.religiousRestriction => true,
      NutritionConstraintType.ethicalPreference => true,
      NutritionConstraintType.dietaryPattern => true,
      NutritionConstraintType.tasteDislike => false,
      NutritionConstraintType.temporaryAvoidance => false,
      NutritionConstraintType.regionalPreference => false,
    };
  }

  Set<String> _mappedReasons(NutritionConstraintEvaluation evaluation) {
    final reasons = <String>{};
    for (final reason in evaluation.reasonCodes) {
      reasons.add(switch (reason) {
        'confirmed_presence' => 'confirmed_conflict',
        'possible_presence' => 'possible_conflict',
        'reviewed_no_detection' => 'no_known_conflict',
        'composition_or_evidence_unknown' => 'insufficient_evidence',
        'cross_contact_requested' => 'possible_cross_contact',
        _ => reason,
      });
    }
    for (final missing in evaluation.missingEvidence) {
      if (missing.endsWith(':composition')) {
        reasons.add('missing_ingredient_evidence');
      } else {
        reasons.add('missing_constraint_evidence');
      }
    }
    if (evaluation.outcome ==
        NutritionConstraintOutcome.insufficientInformation) {
      reasons.add('insufficient_evidence');
    }
    return reasons;
  }

  _NutrientAssessment _assessNutrients({
    required NutrientAggregationResult? nutrientEvidence,
    required Iterable<B04NutritionSafetyNutrientBoundary> boundaries,
  }) {
    if (nutrientEvidence == null) return const _NutrientAssessment();

    final reasonCodes = <String>{};
    final missingEvidence = <String>{};
    final evidenceIds = <String>{};
    final rangeIds = <String>{};
    final boundaryByNutrient = <String, B04NutritionSafetyNutrientBoundary>{};
    var structurallyInvalid = false;
    for (final boundary in boundaries) {
      if (boundaryByNutrient.containsKey(boundary.nutrientId)) {
        structurallyInvalid = true;
        continue;
      }
      boundaryByNutrient[boundary.nutrientId] = boundary;
    }

    for (final entries in nutrientEvidence.sourceLineage.values) {
      evidenceIds.addAll(entries.map((source) => source.stableId));
    }
    for (final entries in nutrientEvidence.factVersionLineage.values) {
      evidenceIds.addAll(entries);
    }

    final completeness = nutrientEvidence.completeness;
    if (completeness.state == NutrientCompletenessState.invalid ||
        completeness.state == NutrientCompletenessState.unknown) {
      reasonCodes.add('unknown_nutrient');
      missingEvidence.addAll(completeness.missingNutrientIds);
    }
    if (completeness.state == NutrientCompletenessState.partial ||
        completeness.missingNutrientIds.isNotEmpty ||
        completeness.partiallyKnownNutrientIds.isNotEmpty) {
      reasonCodes.add('insufficient_nutrient_evidence');
      missingEvidence.addAll(completeness.missingNutrientIds);
    }

    for (final entry in nutrientEvidence.facts.entries) {
      final id = entry.key;
      final fact = entry.value;
      if (fact.sourceReference != null) evidenceIds.add(fact.sourceReference!);
      if (fact.status == NutrientFactStatus.missing) {
        reasonCodes.add('unknown_nutrient');
        missingEvidence.add(id);
        continue;
      }
      if (!fact.isAvailable) continue;

      final hasRange = fact.lower != null || fact.upper != null;
      final isEstimated = fact.status == NutrientFactStatus.estimated;
      if (isEstimated || hasRange) {
        rangeIds.add(id);
        final boundary = boundaryByNutrient[id];
        if (fact.lower == null || fact.upper == null || boundary == null) {
          reasonCodes.add('nutrient_range_unbounded');
          missingEvidence.add(id);
          continue;
        }
        if (fact.unit != boundary.threshold.unit) {
          structurallyInvalid = true;
          continue;
        }
        final lower = fact.lower!.value;
        final upper = fact.upper!.value;
        final threshold = boundary.threshold.value;
        final crosses = switch (boundary.direction) {
          B04NutritionSafetyBoundaryDirection.maximum =>
            lower.compareTo(threshold) <= 0 && upper.compareTo(threshold) > 0,
          B04NutritionSafetyBoundaryDirection.minimum =>
            lower.compareTo(threshold) < 0 && upper.compareTo(threshold) >= 0,
        };
        final entirelyOutside = switch (boundary.direction) {
          B04NutritionSafetyBoundaryDirection.maximum =>
            lower.compareTo(threshold) > 0,
          B04NutritionSafetyBoundaryDirection.minimum =>
            upper.compareTo(threshold) < 0,
        };
        if (crosses) {
          reasonCodes.add('nutrient_range_crosses_boundary');
          missingEvidence.add(id);
        } else if (entirelyOutside) {
          reasonCodes.add('nutrient_boundary_exceeded');
          missingEvidence.add(id);
        }
      } else {
        final boundary = boundaryByNutrient[id];
        if (boundary == null || fact.point == null) continue;
        if (fact.unit != boundary.threshold.unit) {
          structurallyInvalid = true;
          continue;
        }
        final comparison = fact.point!.value.compareTo(
          boundary.threshold.value,
        );
        final exceeded = switch (boundary.direction) {
          B04NutritionSafetyBoundaryDirection.maximum => comparison > 0,
          B04NutritionSafetyBoundaryDirection.minimum => comparison < 0,
        };
        if (exceeded) {
          reasonCodes.add('nutrient_boundary_exceeded');
          missingEvidence.add(id);
        }
      }
    }

    if (structurallyInvalid) {
      reasonCodes.add('structurally_invalid_nutrient_evidence');
      missingEvidence.add('nutrient_structure');
    }
    return _NutrientAssessment(
      unavailable:
          structurallyInvalid ||
          reasonCodes.any(
            (reason) =>
                reason == 'unknown_nutrient' ||
                reason == 'insufficient_nutrient_evidence' ||
                reason == 'nutrient_range_unbounded' ||
                reason == 'nutrient_range_crosses_boundary' ||
                reason == 'nutrient_boundary_exceeded',
          ),
      reasonCodes: reasonCodes.toList(),
      missingEvidence: missingEvidence.toList(),
      evidenceIds: evidenceIds.toList(),
      rangeIds: rangeIds.toList(),
    );
  }
}

class _NutrientAssessment {
  final bool unavailable;
  final List<String> reasonCodes;
  final List<String> missingEvidence;
  final List<String> evidenceIds;
  final List<String> rangeIds;

  const _NutrientAssessment({
    this.unavailable = false,
    this.reasonCodes = const [],
    this.missingEvidence = const [],
    this.evidenceIds = const [],
    this.rangeIds = const [],
  });
}

/// Stable decision-record name retained for callers that do not prefix B04
/// service symbols.
typedef NutritionSafetyFilter = B04NutritionSafetyFilter;
