import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../models/b04_adaptive_target_models.dart';
import '../models/b04_goal_models.dart';
import '../models/b04_nutrition_safety_models.dart';
import '../models/b04_recommendation_context_models.dart';
import '../models/b04_recommendation_models.dart';

/// One deterministic B04 recommendation authority for daily, weekly,
/// training, and nutrition consumers.
///
/// This service only ranks immutable, already-evaluated candidates. B02 owns
/// training calculations, B04-07 owns adaptive target calculations, B03 owns
/// dietary evaluation, and B04-09 maps that evaluation to safety policy.
class B04RecommendationEngine {
  const B04RecommendationEngine();

  B04RecommendationEvaluation evaluate({
    required B04RecommendationContext context,
    required Iterable<B04RecommendationCandidate> candidates,
    B04RecommendationEvaluationScope scope =
        B04RecommendationEvaluationScope.coaching,
  }) {
    _validateContext(context);
    final orderedCandidates = candidates.toList();
    final candidateIds = <String>{};
    for (final candidate in orderedCandidates) {
      if (!candidateIds.add(candidate.id)) {
        throw ArgumentError('Recommendation candidate IDs must be unique.');
      }
      _validateCandidateOwnership(context, candidate);
    }
    orderedCandidates.sort((left, right) => left.id.compareTo(right.id));

    final eligibilityState = _eligibilityState(context.eligibility);
    final consentState = _consentState(context.preferences);
    final policyVersion = _policyVersion(context);
    final policyState = _policyState(context.targetResult);
    final globalReasons = _globalUnavailableReasons(
      context: context,
      eligibilityState: eligibilityState,
      consentState: consentState,
      policyState: policyState,
      scope: scope,
    );

    final evaluatedCandidates = <_CandidateEvaluation>[
      for (final candidate in orderedCandidates)
        _evaluateCandidate(
          context: context,
          candidate: candidate,
          eligibilityState: eligibilityState,
          consentState: consentState,
          policyState: policyState,
          policyVersion: policyVersion,
          globalReasons: globalReasons,
          scope: scope,
        ),
    ];
    final evaluated = <B04Recommendation>[
      for (final item in evaluatedCandidates)
        if (item.includeRecommendation) item.recommendation,
    ];
    evaluated.sort(_compareRecommendations);

    final availableIds = evaluated
        .where((item) => item.state != B04RecommendationState.unavailable)
        .map((item) => item.id)
        .toList(growable: false);
    final recommendations = evaluated
        .map(
          (item) => item.copyWithAlternatives(
            availableIds.where((id) => id != item.id).take(3),
          ),
        )
        .toList(growable: false);

    final warnings = <B04RecommendationWarning>[
      for (final item in evaluatedCandidates) ...item.warnings,
    ];
    warnings.sort(
      (left, right) => left.candidateId.compareTo(right.candidateId),
    );

    final draft = {
      'context_id': context.contextId,
      'period': context.window.period.stableId,
      'start_local_date': context.window.startLocalDate,
      'end_local_date': context.window.endLocalDate,
      'timezone_id': context.window.timezoneId,
      'evaluated_at_utc': context.evaluatedAtUtc.toIso8601String(),
      'eligibility_state': eligibilityState.stableId,
      'consent_state': consentState.stableId,
      'policy_state': policyState.stableId,
      'policy_version': policyVersion,
      'rule_version': kB04RecommendationRuleVersion,
      'algorithm_version': kB04RecommendationAlgorithmVersion,
      'copy_version': kB04RecommendationCopyVersion,
      'recommendations': recommendations
          .map((item) => item.toRedactedMap())
          .toList(),
      'low_risk_warnings': warnings
          .map((item) => item.toRedactedMap())
          .toList(),
    };
    final contextFingerprint = _fingerprint(context.toRedactedMap());
    final fingerprint = _fingerprint({
      ...draft,
      'context_fingerprint': contextFingerprint,
    });

    return B04RecommendationEvaluation(
      contextId: context.contextId,
      userId: context.userId,
      scope: scope,
      period: context.window.period,
      startLocalDate: context.window.startLocalDate,
      endLocalDate: context.window.endLocalDate,
      timezoneId: context.window.timezoneId,
      evaluatedAtUtc: context.evaluatedAtUtc,
      eligibilityState: eligibilityState,
      consentState: consentState,
      policyState: policyState,
      policyVersion: policyVersion,
      recommendations: recommendations,
      lowRiskWarnings: warnings,
      contextFingerprint: contextFingerprint,
      fingerprint: fingerprint,
    );
  }

  _CandidateEvaluation _evaluateCandidate({
    required B04RecommendationContext context,
    required B04RecommendationCandidate candidate,
    required B04RecommendationEligibilityState eligibilityState,
    required B04RecommendationConsentState consentState,
    required B04RecommendationPolicyState policyState,
    required String policyVersion,
    required List<String> globalReasons,
    required B04RecommendationEvaluationScope scope,
  }) {
    final missingEvidence = <String>{
      ...context.missingEvidence.map((item) => item.reasonCode),
      ...candidate.evidence.missingEvidence,
    };
    final uncertaintyCodes = <String>{...candidate.evidence.uncertaintyCodes};
    if (context.nutrition.hasUnknownTotals) {
      uncertaintyCodes.add('nutrition_totals_unknown');
    }
    if (context.readiness == null || !context.readiness!.isUsable) {
      uncertaintyCodes.add('readiness_incomplete');
    }

    final unavailableReasons = <String>{...globalReasons};
    final safety = candidate.nutritionSafety;
    final safetyConstraintIds = <String>{};
    var state = B04RecommendationState.available;
    var targetAcceptance = B04RecommendationTargetAcceptanceState.notApplicable;

    if (candidate.action.isNutrition) {
      if (safety == null) {
        unavailableReasons.add('dietary_safety_evidence_missing');
      } else {
        safetyConstraintIds.addAll(safety.hardBlockConstraintIds);
        safetyConstraintIds.addAll(safety.uncertainConstraintIds);
        missingEvidence.addAll(safety.missingEvidence);
        uncertaintyCodes.addAll(safety.uncertainConstraintIds);
        uncertaintyCodes.addAll(safety.reasonCodes.where(_isUncertaintyCode));
        if (safety.isLowRiskLoggingOnly) {
          unavailableReasons.add('low_risk_logging_only');
        } else if (!_safetyOutputMatches(candidate.action, safety.output)) {
          unavailableReasons.add('dietary_safety_scope_mismatch');
        } else if (safety.isHardBlock || safety.isUnavailable) {
          unavailableReasons.add(
            'dietary_${safety.evaluatedDisposition.stableId}',
          );
        } else if (!safety.recommendationAllowed) {
          unavailableReasons.add(
            'dietary_${safety.evaluatedDisposition.stableId}',
          );
        } else if (safety.evidenceIds.isEmpty) {
          unavailableReasons.add('dietary_evidence_missing');
        } else if (safety.disposition ==
            B04NutritionSafetyDisposition.softFilter) {
          state = B04RecommendationState.cautious;
        }
      }
    }

    if (candidate.action == B04RecommendationAction.training &&
        (context.readiness == null || !context.readiness!.isUsable)) {
      unavailableReasons.add('readiness_incomplete');
    }

    B04AdaptiveTargetResult? canonicalAdaptiveTarget;
    if (candidate.action == B04RecommendationAction.nutritionTarget) {
      if (scope == B04RecommendationEvaluationScope.mealOpportunity) {
        unavailableReasons.add('adaptive_policy_scope_mismatch');
      }
      canonicalAdaptiveTarget = context.targetResult;
      final target = context.targetResult;
      if (target == null) {
        targetAcceptance = B04RecommendationTargetAcceptanceState.unavailable;
        unavailableReasons.add('target_policy_missing');
      } else if (_isHoldTarget(target)) {
        targetAcceptance = B04RecommendationTargetAcceptanceState.unavailable;
        unavailableReasons.add('adaptive_policy_hold');
      } else if (target.status != B04AdaptiveTargetStatus.available &&
          target.status != B04AdaptiveTargetStatus.onTrack) {
        targetAcceptance = B04RecommendationTargetAcceptanceState.unavailable;
        unavailableReasons.add(target.reasonCode);
      } else if (target.status == B04AdaptiveTargetStatus.available &&
          target.proposal != null) {
        targetAcceptance =
            B04RecommendationTargetAcceptanceState.proposalAvailable;
        state = B04RecommendationState.confirm;
      } else {
        targetAcceptance = B04RecommendationTargetAcceptanceState.unchanged;
      }
    }

    final partialEvidenceUnavailable =
        scope == B04RecommendationEvaluationScope.mealOpportunity &&
        candidate.evidence.state == B04RecommendationEvidenceState.partial;
    if (candidate.evidence.state == B04RecommendationEvidenceState.missing ||
        candidate.evidence.state == B04RecommendationEvidenceState.unknown ||
        partialEvidenceUnavailable) {
      unavailableReasons.add(
        'candidate_evidence_${candidate.evidence.state.stableId}',
      );
    } else if (candidate.evidence.state ==
        B04RecommendationEvidenceState.invalid) {
      unavailableReasons.add('candidate_evidence_invalid');
    } else if (candidate.evidence.state ==
        B04RecommendationEvidenceState.partial) {
      state = B04RecommendationState.confirm;
    }

    if (unavailableReasons.isNotEmpty) {
      state = B04RecommendationState.unavailable;
    }

    final priority = _priority(candidate, safety, unavailableReasons);
    final evidenceIds = <String>{...candidate.evidence.evidenceIds};
    if (safety != null) evidenceIds.addAll(safety.evidenceIds);
    final sortedEvidence = evidenceIds.toList()..sort();
    final sortedMissing = missingEvidence.toList()..sort();
    final sortedUncertainty = uncertaintyCodes.toList()..sort();
    final sortedUnavailable = unavailableReasons.toList()..sort();
    final explanation = _explanation(
      candidate: candidate,
      safety: safety,
      state: state,
      evidenceIds: sortedEvidence,
      uncertaintyCodes: sortedUncertainty,
      unavailableReasons: sortedUnavailable,
    );
    final completeness = _completeness(
      candidate: candidate,
      state: state,
      unavailableReasons: sortedUnavailable,
    );
    final confidence = _confidence(state, candidate.evidence.state);

    final recommendation = B04Recommendation(
      id: candidate.id,
      action: candidate.action,
      state: state,
      priority: priority,
      rationaleCode: candidate.rationaleCode,
      explanation: explanation,
      confidence: confidence,
      completeness: completeness,
      evidenceIds: sortedEvidence,
      missingEvidence: sortedMissing,
      uncertaintyCodes: sortedUncertainty,
      unavailableReasons: sortedUnavailable,
      eligibilityState: eligibilityState,
      consentState: consentState,
      policyState: policyState,
      policyVersion: policyVersion,
      ruleVersion: kB04RecommendationRuleVersion,
      algorithmVersion: kB04RecommendationAlgorithmVersion,
      copyVersion: kB04RecommendationCopyVersion,
      targetAcceptanceState: targetAcceptance,
      canonicalAdaptiveTarget: canonicalAdaptiveTarget,
      canonicalTrainingRecommendation: candidate.trainingRecommendation,
      safetyDisposition: safety?.evaluatedDisposition,
      safetyConstraintIds: safetyConstraintIds,
      safetyNutrientRangeIds: safety?.nutrientRangeIds ?? const [],
    );

    final warnings = <B04RecommendationWarning>[];
    if (safety?.isLowRiskLoggingOnly == true) {
      warnings.add(
        B04RecommendationWarning(
          candidateId: candidate.id,
          wording: _appendEvidence(
            wording: safety!.wording,
            evidenceIds: sortedEvidence,
            uncertaintyCodes: sortedUncertainty,
          ),
          evidenceIds: sortedEvidence,
          reasonCodes: safety.reasonCodes,
        ),
      );
    }
    return _CandidateEvaluation(
      recommendation: recommendation,
      warnings: warnings,
      includeRecommendation: safety?.isLowRiskLoggingOnly != true,
    );
  }

  B04RecommendationPriority _priority(
    B04RecommendationCandidate candidate,
    B04NutritionSafetyResult? safety,
    Set<String> unavailableReasons,
  ) {
    if (candidate.action.isNutrition &&
        (safety == null ||
            !safety.recommendationAllowed ||
            safety.isHardBlock ||
            safety.isUnavailable ||
            safety.isLowRiskLoggingOnly ||
            unavailableReasons.contains('dietary_safety_scope_mismatch') ||
            unavailableReasons.contains('dietary_evidence_missing') ||
            unavailableReasons.contains('dietary_safety_evidence_missing'))) {
      return B04RecommendationPriority.safetyBlock;
    }
    if (candidate.urgent) return B04RecommendationPriority.urgent;
    if (candidate.userSelected) return B04RecommendationPriority.userSelected;
    return switch (candidate.action) {
      B04RecommendationAction.training => B04RecommendationPriority.training,
      B04RecommendationAction.nutritionTarget ||
      B04RecommendationAction.nutritionMeal =>
        B04RecommendationPriority.nutrition,
      B04RecommendationAction.education => B04RecommendationPriority.education,
    };
  }

  String _explanation({
    required B04RecommendationCandidate candidate,
    required B04NutritionSafetyResult? safety,
    required B04RecommendationState state,
    required List<String> evidenceIds,
    required List<String> uncertaintyCodes,
    required List<String> unavailableReasons,
  }) {
    final useSafetyWording =
        safety != null &&
        (state != B04RecommendationState.unavailable ||
            safety.isHardBlock ||
            safety.isLowRiskLoggingOnly ||
            safety.isUnavailable ||
            unavailableReasons.contains('dietary_safety_scope_mismatch') ||
            unavailableReasons.contains('dietary_evidence_missing') ||
            unavailableReasons.contains('dietary_safety_evidence_missing'));
    final base = useSafetyWording
        ? _safetyExplanation(
            safety: safety,
            unavailableReasons: unavailableReasons,
          )
        : unavailableReasons.any(
            (reason) =>
                reason.contains('unsupported') || reason.contains('policy'),
          )
        ? 'This goal or target policy is outside the supported policy; the current target remains unchanged.'
        : state == B04RecommendationState.unavailable
        ? 'There is not enough reliable information for personalized guidance; the current target remains unchanged.'
        : 'General wellness guidance only; not medical advice.';
    final status = switch (state) {
      B04RecommendationState.available => 'Available guidance.',
      B04RecommendationState.cautious => 'Use with caution.',
      B04RecommendationState.confirm =>
        'Confirmation is required before acting on this guidance.',
      B04RecommendationState.unavailable => 'This guidance is unavailable.',
      B04RecommendationState.dismissed => 'This guidance was dismissed.',
      B04RecommendationState.superseded => 'This guidance was superseded.',
    };
    return '$base $status ${_appendEvidenceText(evidenceIds, uncertaintyCodes)}';
  }

  String _safetyExplanation({
    required B04NutritionSafetyResult safety,
    required List<String> unavailableReasons,
  }) {
    if (unavailableReasons.contains('dietary_safety_scope_mismatch') ||
        safety.isUnavailable) {
      return 'Safety-sensitive guidance is unavailable because dietary evidence is missing or uncertain.';
    }
    if (safety.isHardBlock) {
      return 'This candidate is blocked by the recorded dietary constraint.';
    }
    return safety.wording;
  }

  String _appendEvidence({
    required String wording,
    required List<String> evidenceIds,
    required List<String> uncertaintyCodes,
  }) => '$wording ${_appendEvidenceText(evidenceIds, uncertaintyCodes)}';

  String _appendEvidenceText(
    List<String> evidenceIds,
    List<String> uncertaintyCodes,
  ) {
    final evidence = evidenceIds.isEmpty
        ? 'none recorded'
        : evidenceIds.join(', ');
    final uncertainty = uncertaintyCodes.isEmpty
        ? 'none recorded'
        : uncertaintyCodes.join(', ');
    return 'Evidence: $evidence. Uncertainty: $uncertainty.';
  }

  B04RecommendationCompleteness _completeness({
    required B04RecommendationCandidate candidate,
    required B04RecommendationState state,
    required List<String> unavailableReasons,
  }) {
    if (candidate.evidence.state == B04RecommendationEvidenceState.invalid ||
        unavailableReasons.any((reason) => reason.contains('invalid'))) {
      return B04RecommendationCompleteness.invalid;
    }
    if (state == B04RecommendationState.unavailable &&
        (candidate.evidence.state == B04RecommendationEvidenceState.missing ||
            candidate.evidence.state ==
                B04RecommendationEvidenceState.unknown ||
            unavailableReasons.isNotEmpty)) {
      return B04RecommendationCompleteness.missing;
    }
    if (candidate.evidence.state == B04RecommendationEvidenceState.partial ||
        state == B04RecommendationState.cautious ||
        state == B04RecommendationState.confirm) {
      return B04RecommendationCompleteness.partial;
    }
    return B04RecommendationCompleteness.complete;
  }

  B04RecommendationConfidence _confidence(
    B04RecommendationState state,
    B04RecommendationEvidenceState evidenceState,
  ) {
    if (state == B04RecommendationState.unavailable) {
      return B04RecommendationConfidence.unknown;
    }
    if (state == B04RecommendationState.confirm ||
        evidenceState == B04RecommendationEvidenceState.partial) {
      return B04RecommendationConfidence.low;
    }
    if (state == B04RecommendationState.cautious) {
      return B04RecommendationConfidence.medium;
    }
    return B04RecommendationConfidence.high;
  }

  List<String> _globalUnavailableReasons({
    required B04RecommendationContext context,
    required B04RecommendationEligibilityState eligibilityState,
    required B04RecommendationConsentState consentState,
    required B04RecommendationPolicyState policyState,
    required B04RecommendationEvaluationScope scope,
  }) {
    final reasons = <String>{};
    if (scope == B04RecommendationEvaluationScope.mealOpportunity) {
      for (final item in context.missingEvidence) {
        if (item.kind == B04MissingEvidenceKind.nutritionTotals ||
            item.kind == B04MissingEvidenceKind.mealOpportunity) {
          reasons.add(item.reasonCode);
        }
      }
      if (context.nutrition.missingLocalDates.isNotEmpty) {
        reasons.add('daily_totals_unavailable');
      }
      if (context.nutrition.hasUnknownTotals) {
        reasons.add('daily_totals_unknown');
      } else if (context.nutrition.isEvidenceLimited) {
        reasons.add('daily_totals_partial');
      }
      final opportunity = context.mealOpportunity;
      if (opportunity == null || !opportunity.hasSelection) {
        reasons.add(opportunity?.reasonCode ?? 'explicit_opportunity_required');
      }
      return reasons.toList()..sort();
    }
    if (context.availability != B04ContextAvailability.available) {
      reasons.add('context_${context.availability.stableId}');
      reasons.addAll(context.missingEvidence.map((item) => item.reasonCode));
    }
    if (eligibilityState != B04RecommendationEligibilityState.eligible) {
      reasons.add('eligibility_${eligibilityState.stableId}');
    }
    if (consentState != B04RecommendationConsentState.enabled) {
      reasons.add('adaptive_consent_${consentState.stableId}');
    }
    if (context.activeGoal == null) reasons.add('goal_missing');
    if (policyState == B04RecommendationPolicyState.missing ||
        policyState == B04RecommendationPolicyState.unavailable) {
      reasons.add('target_policy_${policyState.stableId}');
    }
    return reasons.toList()..sort();
  }

  void _validateContext(B04RecommendationContext context) {
    if (context.contextId.trim().isEmpty || context.userId.trim().isEmpty) {
      throw ArgumentError('Recommendation context identity is required.');
    }
    if (!context.evaluatedAtUtc.isUtc) {
      throw ArgumentError('Recommendation evaluation must use UTC.');
    }
    final dates = LocalScheduleDateService();
    final timezoneId = context.window.timezoneId.trim();
    dates.validateTimezone(timezoneId);
    final start = dates.normalizeLocalDate(context.window.startLocalDate);
    final end = dates.normalizeLocalDate(context.window.endLocalDate);
    if (context.window.period == B04RecommendationPeriod.daily &&
        start != end) {
      throw ArgumentError(
        'A daily recommendation must cover exactly one civil date.',
      );
    }
    if (context.window.period == B04RecommendationPeriod.weekly &&
        dates.addCalendarDays(start, timezoneId, 6) != end) {
      throw ArgumentError(
        'A weekly recommendation must cover exactly seven civil dates.',
      );
    }
    if (context.activeGoal != null &&
        context.activeGoal!.userId != context.userId) {
      throw ArgumentError(
        'Recommendation goal ownership does not match context.',
      );
    }
    if (context.preferences != null &&
        context.preferences!.userId != context.userId) {
      throw ArgumentError(
        'Recommendation consent ownership does not match context.',
      );
    }
    if (context.eligibility != null &&
        context.eligibility!.userId != context.userId) {
      throw ArgumentError(
        'Recommendation eligibility ownership does not match context.',
      );
    }
  }

  void _validateCandidateOwnership(
    B04RecommendationContext context,
    B04RecommendationCandidate candidate,
  ) {
    final safety = candidate.nutritionSafety;
    if (safety != null &&
        (safety.userId != context.userId || safety.subjectId.trim().isEmpty)) {
      throw ArgumentError(
        'Nutrition safety ownership does not match recommendation context.',
      );
    }
  }

  B04RecommendationEligibilityState _eligibilityState(
    CoachingEligibilityReadModel? eligibility,
  ) {
    final result = eligibility?.result;
    return switch (result) {
      null => B04RecommendationEligibilityState.missing,
      CoachingEligibilityResult.eligible =>
        B04RecommendationEligibilityState.eligible,
      CoachingEligibilityResult.underage =>
        B04RecommendationEligibilityState.underage,
      CoachingEligibilityResult.unknownAge =>
        B04RecommendationEligibilityState.unknownAge,
      CoachingEligibilityResult.conflictingAge =>
        B04RecommendationEligibilityState.conflictingAge,
      CoachingEligibilityResult.withheldAge =>
        B04RecommendationEligibilityState.withheldAge,
      CoachingEligibilityResult.invalidEvidence =>
        B04RecommendationEligibilityState.invalidEvidence,
      CoachingEligibilityResult.policyUnavailable =>
        B04RecommendationEligibilityState.policyUnavailable,
    };
  }

  B04RecommendationConsentState _consentState(
    CoachingPreferencesReadModel? preferences,
  ) {
    if (preferences == null) return B04RecommendationConsentState.missing;
    return preferences.adaptiveCoachingEnabled
        ? B04RecommendationConsentState.enabled
        : B04RecommendationConsentState.disabled;
  }

  String _policyVersion(B04RecommendationContext context) =>
      context.targetResult?.policyVersion ??
      context.activeGoal?.policyVersion ??
      'missing';

  B04RecommendationPolicyState _policyState(B04AdaptiveTargetResult? target) {
    if (target == null) return B04RecommendationPolicyState.missing;
    if (_isHoldTarget(target)) {
      return B04RecommendationPolicyState.hold;
    }
    if (target.policyVersion == B04AdaptiveTargetPolicy.current.policyVersion) {
      return B04RecommendationPolicyState.enabled;
    }
    return B04RecommendationPolicyState.unavailable;
  }

  bool _isHoldTarget(B04AdaptiveTargetResult target) =>
      target.reasonCode == 'adaptive_policy_hold';

  int _compareRecommendations(B04Recommendation left, B04Recommendation right) {
    final priority = left.priority.rank.compareTo(right.priority.rank);
    if (priority != 0) return priority;
    return left.id.compareTo(right.id);
  }

  bool _isUncertaintyCode(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('possible') ||
        normalized.contains('unknown') ||
        normalized.contains('insufficient') ||
        normalized.contains('missing') ||
        normalized.contains('invalid') ||
        normalized.contains('uncertain') ||
        normalized.contains('cross_contact');
  }

  bool _safetyOutputMatches(
    B04RecommendationAction action,
    B04NutritionSafetyOutput output,
  ) {
    if (action == B04RecommendationAction.nutritionTarget) {
      return output == B04NutritionSafetyOutput.adaptiveTarget;
    }
    return switch (output) {
      B04NutritionSafetyOutput.eatNow ||
      B04NutritionSafetyOutput.dailyCoaching ||
      B04NutritionSafetyOutput.weeklyCoaching ||
      B04NutritionSafetyOutput.rankedMealCandidates ||
      B04NutritionSafetyOutput.suitableCandidate => true,
      B04NutritionSafetyOutput.adaptiveTarget ||
      B04NutritionSafetyOutput.lowRiskLogging => false,
    };
  }

  String _fingerprint(Object? value) =>
      sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();

  Object? _canonicalize(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort(
          (left, right) => left.key.toString().compareTo(right.key.toString()),
        );
      return <String, Object?>{
        for (final entry in entries)
          entry.key.toString(): _canonicalize(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_canonicalize).toList(growable: false);
    }
    return value;
  }
}

class _CandidateEvaluation {
  final B04Recommendation recommendation;
  final List<B04RecommendationWarning> warnings;
  final bool includeRecommendation;

  const _CandidateEvaluation({
    required this.recommendation,
    required this.warnings,
    required this.includeRecommendation,
  });
}
