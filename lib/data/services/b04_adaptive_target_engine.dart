import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../models/b04_adaptive_target_models.dart';
import '../models/b04_goal_models.dart';
import '../models/b04_recovery_models.dart';
import 'b02_load_target_recommendation_service.dart';

/// Deterministic, read-only B04-07 target evaluator.
///
/// The evaluator consumes frozen read models and never reads a clock, writes a
/// target, accepts a proposal, calls an AI provider or changes a B02 result.
/// Persistence and explicit acceptance remain owned by B04-05.
class B04AdaptiveTargetEngine {
  final LocalScheduleDateService _dates;
  final B04AdaptiveTargetPolicy policy;

  B04AdaptiveTargetEngine({
    LocalScheduleDateService? dates,
    this.policy = B04AdaptiveTargetPolicy.current,
  }) : _dates = dates ?? LocalScheduleDateService();

  B04AdaptiveTargetResult evaluate(B04AdaptiveTargetRequest request) {
    final identity = _validateRequestEnvelope(request);
    if (identity != null) return identity;

    final localDate = _dates.normalizeLocalDate(request.evaluationLocalDate);
    final timezoneId = request.timezoneId.trim();
    final storedPolicy = request.storedPolicyVersion?.trim();
    if (storedPolicy != null &&
        storedPolicy != kB04HoldPolicyVersion &&
        storedPolicy != policy.policyVersion) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'unsupported_policy_version',
        policyVersion: storedPolicy,
      );
    }
    if (storedPolicy == kB04HoldPolicyVersion) {
      return _hold(request, reasonCode: 'adaptive_policy_hold');
    }

    final activation = request.activation;
    final active = activation.isActiveFor(
      userId: request.userId.trim(),
      localDate: localDate,
      timezoneId: timezoneId,
      dates: _dates,
    );
    if (!active) {
      final futureEnabled =
          activation.policyVersion == policy.policyVersion &&
          activation.hasAllActivationGates &&
          activation.effectiveFromLocalDate != null &&
          activation.timezoneId == timezoneId &&
          _isBefore(localDate, activation.effectiveFromLocalDate!);
      if (futureEnabled) {
        return _failure(
          request,
          status: B04AdaptiveTargetStatus.inactive,
          reasonCode: 'adaptive_policy_inactive',
          policyVersion: policy.policyVersion,
        );
      }
      return _hold(request, reasonCode: 'adaptive_policy_hold');
    }
    if (storedPolicy != null && storedPolicy != policy.policyVersion) {
      return _hold(request, reasonCode: 'adaptive_policy_hold');
    }

    if (!request.explicitlyInitiated) {
      return _failure(request, reasonCode: 'explicit_evaluation_required');
    }
    if (!request.adaptiveConsentEnabled) {
      return _failure(request, reasonCode: 'coaching_consent_required');
    }

    final eligibilityFailure = _eligibilityFailure(request, localDate);
    if (eligibilityFailure != null) return eligibilityFailure;

    final goalFailure = _goalFailure(request, localDate, timezoneId);
    if (goalFailure != null) return goalFailure;
    final goal = request.activeGoal!;
    final currentTarget = goal.calorieTargetKcal!;

    final safetyFailure = _safetyFailure(request);
    if (safetyFailure != null) return safetyFailure;

    final bodyFailure = _bodyMetricsFailure(request);
    if (bodyFailure != null) return bodyFailure;
    final bmiFailure = _lossBmiFailure(request, goal.goalType);
    if (bmiFailure != null) return bmiFailure;

    final parsedRate = _goalRate(request.goalRate, goal.goalType);
    if (parsedRate == null) {
      return _failure(request, reasonCode: 'unsupported_goal_rate');
    }

    final endDate = _dates.addCalendarDays(localDate, timezoneId, -1);
    final initialStart = _dates.addCalendarDays(
      endDate,
      timezoneId,
      -(policy.evaluationWindowDays - 1),
    );
    final effectiveDate = _effectiveGoalDate(goal, localDate);
    if (effectiveDate == null) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'invalid_goal_effective_date',
      );
    }
    if (goal.source != NutritionGoalSource.compatibility &&
        _dates.compare(effectiveDate, initialStart) > 0) {
      return _failure(
        request,
        reasonCode: 'evaluation_window_reset',
        currentTargetKcal: currentTarget,
      );
    }
    final startDate = _dates.compare(initialStart, effectiveDate) < 0
        ? effectiveDate
        : initialStart;

    final weights = _weightSummary(
      request,
      startDate: startDate,
      endDate: endDate,
      evaluationTimezoneId: timezoneId,
    );
    if (weights.failure != null) {
      return _failure(
        request,
        status: weights.failure!.status,
        reasonCode: weights.failure!.reasonCode,
        evidenceIds: weights.failure!.evidenceIds,
      );
    }

    final nutrition = _nutritionSummary(
      request,
      startDate: startDate,
      endDate: endDate,
      evaluationTimezoneId: timezoneId,
    );
    if (nutrition.failure != null) {
      return _failure(
        request,
        status: nutrition.failure!.status,
        reasonCode: nutrition.failure!.reasonCode,
        evidenceIds: nutrition.failure!.evidenceIds,
      );
    }

    final maintenance = _maintenanceSummary(
      request,
      endDate: endDate,
      effectiveDate: effectiveDate,
      evaluationTimezoneId: timezoneId,
    );
    if (maintenance.failure != null) {
      return _failure(
        request,
        status: maintenance.failure!.status,
        reasonCode: maintenance.failure!.reasonCode,
        evidenceIds: maintenance.failure!.evidenceIds,
      );
    }

    final evidenceIds = <String>{
      ...weights.value!.evidenceIds,
      ...nutrition.value!.evidenceIds,
      ...maintenance.value!.evidenceIds,
      if (request.bodyMetrics != null) request.bodyMetrics!.id,
    }.toList()..sort();
    final rate = weights.value!.weeklyRatePercent;
    final goalRateValue = parsedRate.value;
    final deadband = goal.goalType == NutritionGoalType.maintenance
        ? policy.maintenanceDeadband
        : policy.lossGainDeadband;

    if (goal.goalType == NutritionGoalType.loss &&
            rate < policy.lossRapidChange ||
        goal.goalType == NutritionGoalType.gain &&
            rate > policy.gainRapidChange) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.rapidChangeReview,
        reasonCode: 'rapid_change_review',
        currentTargetKcal: currentTarget,
        normalizedMaintenanceKcal: maintenance.value!.normalizedMaintenanceKcal,
        medianWeightGrams: weights.value!.medianWeightGrams,
        slopeGramsPerDay: weights.value!.slopeGramsPerDay,
        weeklyRatePercent: rate,
        evidenceIds: evidenceIds,
      );
    }

    final direction = _direction(
      goal.goalType,
      rate: rate,
      requestedRate: goalRateValue,
      deadband: deadband,
    );
    if (direction == B04AdaptiveTargetDirection.onTrack) {
      return _result(
        request,
        status: B04AdaptiveTargetStatus.onTrack,
        reasonCode: 'target_on_track',
        direction: direction,
        adaptiveDeltaKcal: 0,
        currentTargetKcal: currentTarget,
        normalizedMaintenanceKcal: maintenance.value!.normalizedMaintenanceKcal,
        medianWeightGrams: weights.value!.medianWeightGrams,
        slopeGramsPerDay: weights.value!.slopeGramsPerDay,
        weeklyRatePercent: rate,
        evidenceIds: evidenceIds,
      );
    }

    final historyFailure = _historyFailure(
      request,
      localDate: localDate,
      effectiveDate: effectiveDate,
      evidenceIds: evidenceIds,
    );
    if (historyFailure != null) return historyFailure;

    final delta = direction == B04AdaptiveTargetDirection.increaseCalories
        ? policy.proposalStepKcal
        : -policy.proposalStepKcal;
    final normalizedMaintenance = maintenance.value!.normalizedMaintenanceKcal;
    final bound = _targetBound(goal.goalType, normalizedMaintenance);
    if (bound != null &&
        (currentTarget < bound.lower || currentTarget > bound.upper)) {
      return _failure(
        request,
        reasonCode: 'user_target_outside_supported_policy',
        currentTargetKcal: currentTarget,
        normalizedMaintenanceKcal: normalizedMaintenance,
        medianWeightGrams: weights.value!.medianWeightGrams,
        slopeGramsPerDay: weights.value!.slopeGramsPerDay,
        weeklyRatePercent: rate,
        evidenceIds: evidenceIds,
      );
    }
    final candidate = currentTarget + delta;
    if (bound != null && (candidate < bound.lower || candidate > bound.upper)) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.policyBoundaryReached,
        reasonCode: 'policy_boundary_reached',
        currentTargetKcal: currentTarget,
        normalizedMaintenanceKcal: normalizedMaintenance,
        medianWeightGrams: weights.value!.medianWeightGrams,
        slopeGramsPerDay: weights.value!.slopeGramsPerDay,
        weeklyRatePercent: rate,
        evidenceIds: evidenceIds,
      );
    }
    if (candidate <= 0) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.policyBoundaryReached,
        reasonCode: 'policy_boundary_reached',
        currentTargetKcal: currentTarget,
        normalizedMaintenanceKcal: normalizedMaintenance,
        evidenceIds: evidenceIds,
      );
    }

    final aggregate = _acceptedEngineAggregate(
      request,
      evaluationLocalDate: localDate,
      effectiveDate: effectiveDate,
    );
    if (aggregate + delta < policy.aggregateMinimumKcal ||
        aggregate + delta > policy.aggregateMaximumKcal) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.policyBoundaryReached,
        reasonCode: 'policy_boundary_reached',
        currentTargetKcal: currentTarget,
        normalizedMaintenanceKcal: normalizedMaintenance,
        medianWeightGrams: weights.value!.medianWeightGrams,
        slopeGramsPerDay: weights.value!.slopeGramsPerDay,
        weeklyRatePercent: rate,
        evidenceIds: evidenceIds,
      );
    }

    final proposal = _proposal(
      request,
      goal: goal,
      goalRate: parsedRate.text!,
      candidateTarget: candidate,
      normalizedMaintenanceKcal: normalizedMaintenance,
      evidenceIds: evidenceIds,
      weeklyRatePercent: rate,
    );
    return _result(
      request,
      status: B04AdaptiveTargetStatus.available,
      reasonCode: 'adaptive_proposal_available',
      direction: direction,
      adaptiveDeltaKcal: delta,
      currentTargetKcal: currentTarget,
      proposedTargetKcal: candidate,
      normalizedMaintenanceKcal: normalizedMaintenance,
      medianWeightGrams: weights.value!.medianWeightGrams,
      slopeGramsPerDay: weights.value!.slopeGramsPerDay,
      weeklyRatePercent: rate,
      evidenceIds: evidenceIds,
      proposal: proposal,
    );
  }

  /// Returns the separate readiness/training overlay. B02 remains the owner
  /// of the supplied training recommendation and all numerical effects are
  /// zero under READINESS-HOLD-1.
  B04TrainingOverlayResult evaluateTrainingOverlay({
    required ReadinessSnapshotReadModel? readinessSnapshot,
    required B02LoadTargetRecommendationResult? baseB02Recommendation,
  }) {
    if (readinessSnapshot == null) {
      return B04TrainingOverlayResult(
        policyVersion: kB04ReadinessHoldPolicyVersion,
        status: 'unavailable',
        reasonCode: 'readiness_unavailable',
        readinessSnapshot: null,
        baseB02Recommendation: baseB02Recommendation,
        calorieDeltaKcal: 0,
        trainingLoadDeltaPercent: 0,
        trainingIntensityDeltaPercent: 0,
        scheduleDurationDelta: 0,
        numericalProposalAllowed: false,
        descriptiveCoachingAllowed: false,
      );
    }
    final descriptive =
        readinessSnapshot.completeness == ReadinessCompleteness.complete &&
        readinessSnapshot.status != ReadinessStatus.unavailable;
    return B04TrainingOverlayResult(
      policyVersion: kB04ReadinessHoldPolicyVersion,
      status: descriptive ? 'descriptive_only' : 'unavailable',
      reasonCode: descriptive
          ? 'readiness_descriptive_only'
          : (readinessSnapshot.unavailableReason ?? 'readiness_unavailable'),
      readinessSnapshot: readinessSnapshot,
      baseB02Recommendation: baseB02Recommendation,
      calorieDeltaKcal: 0,
      trainingLoadDeltaPercent: 0,
      trainingIntensityDeltaPercent: 0,
      scheduleDurationDelta: 0,
      numericalProposalAllowed: false,
      descriptiveCoachingAllowed: descriptive,
    );
  }

  B04ExactRational median(Iterable<B04ExactRational> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) throw ArgumentError('At least one value is required.');
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / B04ExactRational.fromInt(2);
  }

  B04ExactRational theilSenSlope(Iterable<B04WeightObservation> observations) {
    final values = <String, B04ExactRational>{};
    for (final observation in observations) {
      final value = B04ExactRational.parse(observation.grams);
      final existing = values[observation.localDate];
      values[observation.localDate] = existing == null
          ? value
          : median([existing, value]);
    }
    return _theilSenSlopeFromValues(values);
  }

  B04ExactRational weeklyRatePercent({
    required B04ExactRational slopeGramsPerDay,
    required B04ExactRational medianWindowWeightGrams,
  }) =>
      slopeGramsPerDay *
      B04ExactRational.fromInt(7) *
      B04ExactRational.fromInt(100) /
      medianWindowWeightGrams;

  int normalizedMaintenance(String rawPointKcal) =>
      B04ExactRational.parse(rawPointKcal).roundAwayFromZero().toInt();

  B04AdaptiveTargetResult? _validateRequestEnvelope(
    B04AdaptiveTargetRequest request,
  ) {
    if (request.evaluationId.trim().isEmpty || request.userId.trim().isEmpty) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'missing_evaluation_identity',
      );
    }
    if (!request.evaluatedAtUtc.isUtc) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'evaluation_timestamp_not_utc',
      );
    }
    try {
      _dates.normalizeLocalDate(request.evaluationLocalDate);
      _dates.validateTimezone(request.timezoneId);
    } on Object {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'invalid_evaluation_time_context',
      );
    }
    return null;
  }

  B04AdaptiveTargetResult? _eligibilityFailure(
    B04AdaptiveTargetRequest request,
    String localDate,
  ) {
    final eligibility = request.eligibility;
    if (eligibility == null) {
      return _failure(request, reasonCode: 'coaching_unavailable_age');
    }
    if (eligibility.userId != request.userId.trim() ||
        eligibility.evaluationLocalDate != localDate ||
        eligibility.timezoneId != request.timezoneId.trim() ||
        !eligibility.evaluationUtc.isUtc ||
        eligibility.evaluationUtc.isAfter(request.evaluatedAtUtc)) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'eligibility_lineage_invalid',
      );
    }
    switch (eligibility.result) {
      case CoachingEligibilityResult.eligible:
        if (eligibility.policyVersion != policy.policyVersion) {
          return _failure(request, reasonCode: 'adaptive_policy_hold');
        }
        return null;
      case CoachingEligibilityResult.underage:
        return _failure(request, reasonCode: 'coaching_unavailable_age');
      case CoachingEligibilityResult.unknownAge:
      case CoachingEligibilityResult.conflictingAge:
      case CoachingEligibilityResult.withheldAge:
      case CoachingEligibilityResult.invalidEvidence:
      case CoachingEligibilityResult.policyUnavailable:
        return _failure(
          request,
          reasonCode: eligibility.reasonCode.trim().isEmpty
              ? 'coaching_unavailable'
              : eligibility.reasonCode,
        );
    }
  }

  B04AdaptiveTargetResult? _goalFailure(
    B04AdaptiveTargetRequest request,
    String localDate,
    String timezoneId,
  ) {
    final goal = request.activeGoal;
    if (goal == null) {
      return _failure(request, reasonCode: 'active_goal_unavailable');
    }
    if (goal.userId != request.userId.trim() ||
        goal.timezoneId != timezoneId ||
        goal.id.trim().isEmpty ||
        goal.calorieTargetKcal == null ||
        goal.calorieTargetKcal! <= 0) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'invalid_active_goal',
        currentTargetKcal: goal.calorieTargetKcal,
      );
    }
    if (goal.goalType == NutritionGoalType.custom) {
      return _failure(request, reasonCode: 'unsupported_goal_type');
    }
    try {
      final effective = _dates.normalizeLocalDate(goal.effectiveFromLocalDate);
      if (_dates.compare(effective, localDate) > 0) {
        return _failure(
          request,
          status: B04AdaptiveTargetStatus.invalidEvidence,
          reasonCode: 'active_goal_not_effective',
        );
      }
      if (goal.effectiveToLocalDate != null) {
        final end = _dates.normalizeLocalDate(goal.effectiveToLocalDate!);
        if (_dates.compare(end, localDate) < 0) {
          return _failure(
            request,
            status: B04AdaptiveTargetStatus.invalidEvidence,
            reasonCode: 'active_goal_expired',
          );
        }
      }
    } on Object {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'invalid_goal_effective_date',
      );
    }
    return null;
  }

  String? _effectiveGoalDate(
    NutritionGoalVersionReadModel goal,
    String localDate,
  ) {
    try {
      final value = _dates.normalizeLocalDate(goal.effectiveFromLocalDate);
      return _dates.compare(value, localDate) <= 0 ? value : null;
    } on Object {
      return null;
    }
  }

  B04AdaptiveTargetResult? _safetyFailure(B04AdaptiveTargetRequest request) {
    final safety = request.safety;
    if (safety.pregnancyOrBreastfeeding) {
      return _failure(
        request,
        reasonCode: 'adaptive_goal_unsupported_pregnancy_or_breastfeeding',
      );
    }
    if (safety.clinicianManagedPlan) {
      return _failure(request, reasonCode: 'clinician_managed_plan');
    }
    if (safety.eatingDisorderRestriction) {
      return _failure(request, reasonCode: 'dietary_restriction_unavailable');
    }
    if (safety.state != B04SafetyState.clear) {
      return _failure(request, reasonCode: 'dietary_${safety.state.stableId}');
    }
    return null;
  }

  B04AdaptiveTargetResult? _bodyMetricsFailure(
    B04AdaptiveTargetRequest request,
  ) {
    final body = request.bodyMetrics;
    if (body == null) {
      return _failure(request, reasonCode: 'body_metrics_unavailable');
    }
    try {
      _dates.normalizeLocalDate(body.localDate);
      _dates.validateTimezone(body.timezoneId);
    } on Object {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'invalid_body_time_context',
      );
    }
    if (body.observedAtUtc.isAfter(request.evaluatedAtUtc)) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'future_body_evidence',
      );
    }
    if (body.state != B04EvidenceState.known &&
        body.state != B04EvidenceState.estimated) {
      return _failure(
        request,
        status: body.state == B04EvidenceState.invalid
            ? B04AdaptiveTargetStatus.invalidEvidence
            : B04AdaptiveTargetStatus.unavailable,
        reasonCode: 'body_${body.state.stableId}',
      );
    }
    if (body.userId != request.userId.trim() ||
        body.heightUnit != 'cm' ||
        body.weightUnit != 'g' ||
        body.id.trim().isEmpty ||
        body.sourceId.trim().isEmpty ||
        body.sourceVersion.trim().isEmpty ||
        !body.observedAtUtc.isUtc) {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'invalid_body_metrics',
      );
    }
    try {
      final height = B04ExactRational.parse(body.heightCm);
      final weight = B04ExactRational.parse(body.weightGrams);
      if (height <= B04ExactRational.fromInt(0) ||
          weight <= B04ExactRational.fromInt(0) ||
          !weight.isInteger) {
        throw const FormatException();
      }
    } on Object {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'invalid_body_metrics',
      );
    }
    return null;
  }

  B04AdaptiveTargetResult? _lossBmiFailure(
    B04AdaptiveTargetRequest request,
    NutritionGoalType goalType,
  ) {
    if (goalType != NutritionGoalType.loss) return null;
    final body = request.bodyMetrics!;
    try {
      final height = B04ExactRational.parse(body.heightCm);
      final weight = B04ExactRational.parse(body.weightGrams);
      final bmi = weight * B04ExactRational.fromInt(10) / (height * height);
      if (bmi < B04ExactRational.parse('18.5')) {
        return _failure(
          request,
          reasonCode: 'loss_bmi_below_supported_boundary',
        );
      }
    } on Object {
      return _failure(
        request,
        status: B04AdaptiveTargetStatus.invalidEvidence,
        reasonCode: 'invalid_body_metrics',
      );
    }
    return null;
  }

  ({B04ExactRational value, String? text})? _goalRate(
    String? raw,
    NutritionGoalType type,
  ) {
    final rawValue = raw?.trim();
    final prefix = '${type.stableId}:';
    final normalized = rawValue != null && rawValue.startsWith(prefix)
        ? rawValue.substring(prefix.length)
        : rawValue;
    if (normalized == null ||
        !policy.supportedGoalRates.contains('${type.stableId}:$normalized')) {
      return null;
    }
    final match = RegExp(
      r'^([+-]?\d+(?:\.\d+)?)% body weight/week$',
    ).firstMatch(normalized);
    if (match == null) return null;
    try {
      return (value: B04ExactRational.parse(match.group(1)!), text: normalized);
    } on Object {
      return null;
    }
  }

  B04AdaptiveTargetDirection _direction(
    NutritionGoalType type, {
    required B04ExactRational rate,
    required B04ExactRational requestedRate,
    required B04ExactRational deadband,
  }) {
    final lower = requestedRate - deadband;
    final upper = requestedRate + deadband;
    if (rate >= lower && rate <= upper) {
      return B04AdaptiveTargetDirection.onTrack;
    }
    if (type == NutritionGoalType.loss) {
      return rate > upper
          ? B04AdaptiveTargetDirection.decreaseCalories
          : B04AdaptiveTargetDirection.increaseCalories;
    }
    if (type == NutritionGoalType.gain) {
      return rate < lower
          ? B04AdaptiveTargetDirection.increaseCalories
          : B04AdaptiveTargetDirection.decreaseCalories;
    }
    return rate < lower
        ? B04AdaptiveTargetDirection.increaseCalories
        : B04AdaptiveTargetDirection.decreaseCalories;
  }

  _Gate<_WeightSummary> _weightSummary(
    B04AdaptiveTargetRequest request, {
    required String startDate,
    required String endDate,
    required String evaluationTimezoneId,
  }) {
    final source = request.weightObservations;
    final superseded = <String>{
      for (final item in source)
        if (item.supersedesObservationId != null) item.supersedesObservationId!,
    };
    for (final item in source) {
      final related = item.supersedesObservationId;
      if (related != null &&
          !source.any((candidate) => candidate.id == related)) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.invalidEvidence,
          'dangling_weight_correction',
          [item.id],
        );
      }
    }
    final byDay = <String, List<_ParsedWeight>>{};
    for (final item in source) {
      if (superseded.contains(item.id)) continue;
      String date;
      try {
        date = _dates.normalizeLocalDate(item.localDate);
        _dates.validateTimezone(item.timezoneId);
      } on Object {
        return _Gate.failure(
          B04AdaptiveTargetStatus.invalidEvidence,
          'invalid_weight_time_context',
          [item.id],
        );
      }
      final inWindow =
          _dates.compare(date, startDate) >= 0 &&
          _dates.compare(date, endDate) <= 0;
      if (!inWindow) continue;
      if (item.userId != request.userId.trim() ||
          item.unit != 'g' ||
          item.id.trim().isEmpty ||
          item.sourceId.trim().isEmpty ||
          item.sourceVersion.trim().isEmpty ||
          !item.observedAtUtc.isUtc ||
          item.observedAtUtc.isAfter(request.evaluatedAtUtc)) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.invalidEvidence,
          'invalid_weight_provenance',
          [item.id],
        );
      }
      if (item.state != B04EvidenceState.known &&
          item.state != B04EvidenceState.estimated) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.unavailable,
          'weight_${item.state.stableId}',
          [item.id],
        );
      }
      B04ExactRational grams;
      try {
        grams = B04ExactRational.parse(item.grams);
        if (!grams.isInteger || grams <= B04ExactRational.fromInt(0)) {
          throw const FormatException();
        }
      } on Object {
        return _Gate.failure(
          B04AdaptiveTargetStatus.invalidEvidence,
          'invalid_weight_value',
          [item.id],
        );
      }
      byDay
          .putIfAbsent(date, () => [])
          .add(_ParsedWeight(item: item, grams: grams));
    }
    final daily = <String, B04ExactRational>{};
    final evidenceIds = <String>[];
    for (final entry in byDay.entries) {
      daily[entry.key] = median([for (final value in entry.value) value.grams]);
      evidenceIds.addAll(entry.value.map((value) => value.item.id));
    }
    final days = daily.keys.toList()..sort();
    if (days.length < policy.minimumValidWeightDays) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.unavailable,
        'insufficient_weight_days',
        evidenceIds,
      );
    }
    final span = _daysBetween(days.first, days.last, evaluationTimezoneId);
    if (span < policy.minimumWeightSpanDays) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.unavailable,
        'insufficient_weight_span',
        evidenceIds,
      );
    }
    final latestAge = _daysBetween(days.last, endDate, evaluationTimezoneId);
    if (latestAge > policy.latestWeightFreshnessDays) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.unavailable,
        'weight_evidence_stale',
        evidenceIds,
      );
    }
    final firstBlockEnd = _dates.addCalendarDays(
      startDate,
      evaluationTimezoneId,
      6,
    );
    final finalBlockStart = _dates.addCalendarDays(
      endDate,
      evaluationTimezoneId,
      -6,
    );
    final firstBlock = days.where(
      (day) =>
          _dates.compare(day, startDate) >= 0 &&
          _dates.compare(day, firstBlockEnd) <= 0,
    );
    final finalBlock = days.where(
      (day) =>
          _dates.compare(day, finalBlockStart) >= 0 &&
          _dates.compare(day, endDate) <= 0,
    );
    if (firstBlock.length < policy.minimumBlockWeightDays ||
        finalBlock.length < policy.minimumBlockWeightDays) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.unavailable,
        'insufficient_weight_block_distribution',
        evidenceIds,
      );
    }
    final dailyValues = [for (final day in days) daily[day]!];
    final medianWeightGrams = median(dailyValues);
    B04ExactRational slope;
    try {
      slope = _theilSenSlopeFromValues(daily);
    } on Object {
      return _Gate.failure(
        B04AdaptiveTargetStatus.invalidEvidence,
        'invalid_weight_trend',
        evidenceIds,
      );
    }
    final weekly = weeklyRatePercent(
      slopeGramsPerDay: slope,
      medianWindowWeightGrams: medianWeightGrams,
    );
    return _Gate.value(
      _WeightSummary(
        medianWeightGrams: medianWeightGrams,
        slopeGramsPerDay: slope,
        weeklyRatePercent: weekly,
        evidenceIds: evidenceIds,
      ),
    );
  }

  B04ExactRational _theilSenSlopeFromValues(
    Map<String, B04ExactRational> values,
  ) {
    final ordered = values.keys.toList()..sort();
    final slopes = <B04ExactRational>[];
    for (var i = 0; i < ordered.length; i++) {
      for (var j = i + 1; j < ordered.length; j++) {
        final dayDelta = _daysBetween(ordered[i], ordered[j], 'UTC');
        if (dayDelta <= 0) {
          throw ArgumentError('Weight dates must be increasing.');
        }
        slopes.add(
          (values[ordered[j]]! - values[ordered[i]]!) /
              B04ExactRational.fromInt(dayDelta),
        );
      }
    }
    return median(slopes);
  }

  _Gate<_NutritionSummary> _nutritionSummary(
    B04AdaptiveTargetRequest request, {
    required String startDate,
    required String endDate,
    required String evaluationTimezoneId,
  }) {
    final source = request.nutritionDays;
    final superseded = <String>{
      for (final item in source)
        if (item.supersedesEvidenceId != null) item.supersedesEvidenceId!,
    };
    for (final item in source) {
      final related = item.supersedesEvidenceId;
      if (related != null &&
          !source.any((candidate) => candidate.id == related)) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.invalidEvidence,
          'dangling_nutrition_correction',
          [item.id],
        );
      }
    }
    final byDay = <String, B04NutritionDayEvidence>{};
    for (final item in source) {
      if (superseded.contains(item.id)) continue;
      String date;
      try {
        date = _dates.normalizeLocalDate(item.localDate);
        _dates.validateTimezone(item.timezoneId);
      } on Object {
        return _Gate.failure(
          B04AdaptiveTargetStatus.invalidEvidence,
          'invalid_nutrition_time_context',
          [item.id],
        );
      }
      if (_dates.compare(date, startDate) < 0 ||
          _dates.compare(date, endDate) > 0) {
        continue;
      }
      if (item.userId != request.userId.trim() ||
          item.id.trim().isEmpty ||
          item.sourceId.trim().isEmpty ||
          item.sourceVersion.trim().isEmpty ||
          !item.historicalSnapshot ||
          !item.observedAtUtc.isUtc ||
          item.observedAtUtc.isAfter(request.evaluatedAtUtc)) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.invalidEvidence,
          'invalid_nutrition_provenance',
          [item.id],
        );
      }
      if (byDay.containsKey(date)) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.unavailable,
          'nutrition_conflicting_evidence',
          [byDay[date]!.id, item.id],
        );
      }
      if (item.energy.state != B04EvidenceState.known &&
          item.energy.state != B04EvidenceState.estimated) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.unavailable,
          'nutrition_${item.energy.state.stableId}',
          [item.id],
        );
      }
      if (item.energy.stale || item.energy.conflicting) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.unavailable,
          item.energy.stale ? 'nutrition_stale' : 'nutrition_conflicting',
          [item.id],
        );
      }
      final range = _range(item.energy, expectedUnit: 'kcal/day');
      if (range.failure != null) {
        return _Gate.failure(range.failure!.status, range.failure!.reasonCode, [
          item.id,
        ]);
      }
      if (item.energy.actionAtLower != null &&
          item.energy.actionAtUpper != null &&
          item.energy.actionAtLower != item.energy.actionAtUpper) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.unavailable,
          'unavailable_uncertain_range',
          [item.id],
        );
      }
      try {
        final completeness = B04ExactRational.parse(item.completenessPercent);
        if (completeness < B04ExactRational.fromInt(0) ||
            completeness > B04ExactRational.fromInt(100)) {
          return _Gate.failure(
            B04AdaptiveTargetStatus.invalidEvidence,
            'invalid_nutrition_completeness',
            [item.id],
          );
        }
        if (completeness < policy.nutritionCompleteness) {
          return _Gate.failure(
            B04AdaptiveTargetStatus.unavailable,
            'nutrition_completeness_insufficient',
            [item.id],
          );
        }
      } on Object {
        return _Gate.failure(
          B04AdaptiveTargetStatus.invalidEvidence,
          'invalid_nutrition_completeness',
          [item.id],
        );
      }
      byDay[date] = item;
    }
    if (byDay.length < policy.minimumNutritionValidDays) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.unavailable,
        'insufficient_nutrition_days',
        byDay.values.map((item) => item.id).toList(),
      );
    }
    return _Gate.value(
      _NutritionSummary(
        evidenceIds: byDay.values.map((item) => item.id).toList(),
      ),
    );
  }

  _Gate<_MaintenanceSummary> _maintenanceSummary(
    B04AdaptiveTargetRequest request, {
    required String endDate,
    required String effectiveDate,
    required String evaluationTimezoneId,
  }) {
    final item = request.maintenanceEvidence;
    if (item == null) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.unavailable,
        'maintenance_unavailable',
        const [],
      );
    }
    String date;
    try {
      date = _dates.normalizeLocalDate(item.localDate);
      _dates.validateTimezone(item.timezoneId);
    } on Object {
      return _Gate.failure(
        B04AdaptiveTargetStatus.invalidEvidence,
        'invalid_maintenance_time_context',
        [item.id],
      );
    }
    if (_dates.compare(date, effectiveDate) < 0) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.unavailable,
        'maintenance_evidence_reset',
        [item.id],
      );
    }
    if (item.userId != request.userId.trim() ||
        item.id.trim().isEmpty ||
        item.sourceId.trim().isEmpty ||
        item.sourceVersion.trim().isEmpty ||
        !item.historicalSnapshot ||
        !item.observedAtUtc.isUtc ||
        item.observedAtUtc.isAfter(request.evaluatedAtUtc) ||
        item.policyVersion != policy.policyVersion) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.invalidEvidence,
        'invalid_maintenance_provenance',
        [item.id],
      );
    }
    if (item.energy.state != B04EvidenceState.known &&
        item.energy.state != B04EvidenceState.estimated) {
      return _Gate.failure(
        item.energy.state == B04EvidenceState.invalid
            ? B04AdaptiveTargetStatus.invalidEvidence
            : B04AdaptiveTargetStatus.unavailable,
        'maintenance_${item.energy.state.stableId}',
        [item.id],
      );
    }
    if (item.energy.stale || item.energy.conflicting) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.unavailable,
        item.energy.stale ? 'maintenance_stale' : 'maintenance_conflicting',
        [item.id],
      );
    }
    final age = _daysBetween(date, endDate, evaluationTimezoneId);
    if (age < 0) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.invalidEvidence,
        'future_maintenance_evidence',
        [item.id],
      );
    }
    if (age > policy.maintenanceFreshnessDays) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.unavailable,
        'maintenance_evidence_stale',
        [item.id],
      );
    }
    if (item.energy.actionAtLower != null &&
        item.energy.actionAtUpper != null &&
        item.energy.actionAtLower != item.energy.actionAtUpper) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.unavailable,
        'unavailable_uncertain_range',
        [item.id],
      );
    }
    final range = _range(
      item.energy,
      expectedUnit: 'kcal/day',
      maintenance: true,
    );
    if (range.failure != null) {
      return _Gate.failure(range.failure!.status, range.failure!.reasonCode, [
        item.id,
      ]);
    }
    final point = item.energy.point;
    if (point == null) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.unavailable,
        'maintenance_point_unavailable',
        [item.id],
      );
    }
    try {
      final value = B04ExactRational.parse(point);
      if (value <= B04ExactRational.fromInt(0) ||
          value < range.value!.lower ||
          value > range.value!.upper) {
        throw const FormatException();
      }
      final normalized = value.roundAwayFromZero().toInt();
      if (normalized <= 0) throw const FormatException();
      return _Gate.value(
        _MaintenanceSummary(
          normalizedMaintenanceKcal: normalized,
          evidenceIds: [item.id],
        ),
      );
    } on Object {
      return _Gate.failure(
        B04AdaptiveTargetStatus.invalidEvidence,
        'invalid_maintenance_point',
        [item.id],
      );
    }
  }

  _Gate<_ParsedRange> _range(
    B04NumericRangeEvidence input, {
    required String expectedUnit,
    bool maintenance = false,
  }) {
    if (input.unit != expectedUnit ||
        input.lowerUnit != null && input.lowerUnit != input.unit ||
        input.upperUnit != null && input.upperUnit != input.unit) {
      return _Gate.failure(
        B04AdaptiveTargetStatus.invalidEvidence,
        'invalid_numeric_unit',
        const [],
      );
    }
    try {
      B04ExactRational lower;
      B04ExactRational upper;
      if (input.point != null) {
        final point = B04ExactRational.parse(input.point!);
        if (input.lower != null || input.upper != null) {
          if (input.lower == null || input.upper == null) {
            return _Gate.failure(
              B04AdaptiveTargetStatus.invalidEvidence,
              'invalid_numeric_range',
              const [],
            );
          }
          lower = B04ExactRational.parse(input.lower!);
          upper = B04ExactRational.parse(input.upper!);
          if (point < lower || point > upper) {
            return _Gate.failure(
              B04AdaptiveTargetStatus.invalidEvidence,
              'point_outside_numeric_range',
              const [],
            );
          }
        } else {
          lower = point;
          upper = point;
        }
      } else if (input.lower != null && input.upper != null) {
        lower = B04ExactRational.parse(input.lower!);
        upper = B04ExactRational.parse(input.upper!);
      } else {
        return _Gate.failure(
          B04AdaptiveTargetStatus.unavailable,
          'numeric_range_unavailable',
          const [],
        );
      }
      if (lower < B04ExactRational.fromInt(0) || upper < lower) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.invalidEvidence,
          'invalid_numeric_range',
          const [],
        );
      }
      final midpoint = (lower + upper) / B04ExactRational.fromInt(2);
      if (midpoint <= B04ExactRational.fromInt(0)) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.invalidEvidence,
          'unavailable_invalid_midpoint',
          const [],
        );
      }
      final width = upper - lower;
      final relative = width / midpoint * B04ExactRational.fromInt(100);
      final maximum = maintenance
          ? policy.maintenanceMaximumRange
          : policy.nutritionMaximumRange;
      if (relative > maximum) {
        return _Gate.failure(
          B04AdaptiveTargetStatus.unavailable,
          maintenance
              ? 'maintenance_range_too_wide'
              : 'nutrition_range_too_wide',
          const [],
        );
      }
      return _Gate.value(
        _ParsedRange(
          lower: lower,
          upper: upper,
          relativeWidthPercent: relative,
        ),
      );
    } on FormatException {
      return _Gate.failure(
        B04AdaptiveTargetStatus.invalidEvidence,
        'invalid_numeric_value',
        const [],
      );
    } on Object {
      return _Gate.failure(
        B04AdaptiveTargetStatus.invalidEvidence,
        'invalid_numeric_value',
        const [],
      );
    }
  }

  B04AdaptiveTargetResult? _historyFailure(
    B04AdaptiveTargetRequest request, {
    required String localDate,
    required String effectiveDate,
    required List<String> evidenceIds,
  }) {
    final source = request.history;
    final superseded = <String>{
      for (final item in source)
        if (item.supersedesEventId != null) item.supersedesEventId!,
    };
    for (final item in source) {
      if (item.supersedesEventId != null &&
          !source.any((candidate) => candidate.id == item.supersedesEventId)) {
        return _failure(
          request,
          status: B04AdaptiveTargetStatus.invalidEvidence,
          reasonCode: 'dangling_history_correction',
          evidenceIds: evidenceIds,
        );
      }
    }
    final active =
        source.where((item) => !superseded.contains(item.id)).toList()
          ..sort((a, b) {
            final byDate = b.localDate.compareTo(a.localDate);
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
    for (final item in active) {
      if (item.userId != request.userId.trim() ||
          item.id.trim().isEmpty ||
          item.timezoneId.trim().isEmpty) {
        return _failure(
          request,
          status: B04AdaptiveTargetStatus.invalidEvidence,
          reasonCode: 'invalid_history_provenance',
          evidenceIds: evidenceIds,
        );
      }
      if (item.engineAuthored &&
          (item.state == B04AdaptiveProposalState.pending ||
              item.state == B04AdaptiveProposalState.accepted) &&
          item.deltaKcal != policy.proposalStepKcal &&
          item.deltaKcal != -policy.proposalStepKcal) {
        return _failure(
          request,
          status: B04AdaptiveTargetStatus.invalidEvidence,
          reasonCode: 'invalid_history_delta',
          evidenceIds: evidenceIds,
        );
      }
      try {
        _dates.normalizeLocalDate(item.localDate);
        _dates.validateTimezone(item.timezoneId);
      } on Object {
        return _failure(
          request,
          status: B04AdaptiveTargetStatus.invalidEvidence,
          reasonCode: 'invalid_history_time_context',
          evidenceIds: evidenceIds,
        );
      }
    }
    final currentHistory = active.where(
      (item) =>
          _dates.compare(item.localDate, effectiveDate) >= 0 &&
          (!item.engineAuthored || item.policyVersion == policy.policyVersion),
    );
    final pending = currentHistory.where(
      (item) => item.state == B04AdaptiveProposalState.pending,
    );
    for (final item in pending) {
      final age = _daysBetween(item.localDate, localDate, request.timezoneId);
      if (age >= policy.proposalExpiryDays) {
        return _failure(
          request,
          status: B04AdaptiveTargetStatus.expired,
          reasonCode: 'proposal_expired',
          evidenceIds: evidenceIds,
        );
      }
      if (age >= 0) {
        return _failure(
          request,
          reasonCode: 'unresolved_proposal',
          evidenceIds: evidenceIds,
        );
      }
    }
    final recent = currentHistory.where(
      (item) =>
          item.engineAuthored &&
          item.localDate.compareTo(localDate) <= 0 &&
          item.state != B04AdaptiveProposalState.rejected &&
          item.state != B04AdaptiveProposalState.dismissed &&
          item.state != B04AdaptiveProposalState.expired,
    );
    for (final item in recent) {
      final age = _daysBetween(item.localDate, localDate, request.timezoneId);
      if (age < policy.proposalCadenceDays) {
        return _failure(
          request,
          reasonCode: 'proposal_cadence_not_met',
          evidenceIds: evidenceIds,
        );
      }
      break;
    }
    return null;
  }

  int _acceptedEngineAggregate(
    B04AdaptiveTargetRequest request, {
    required String evaluationLocalDate,
    required String effectiveDate,
  }) {
    final superseded = <String>{
      for (final item in request.history)
        if (item.supersedesEventId != null) item.supersedesEventId!,
    };
    return request.history
        .where(
          (item) =>
              !superseded.contains(item.id) &&
              item.userId == request.userId.trim() &&
              item.engineAuthored &&
              item.accepted &&
              item.state == B04AdaptiveProposalState.accepted &&
              item.policyVersion == policy.policyVersion &&
              _dates.compare(item.localDate, effectiveDate) >= 0,
        )
        .where((item) {
          final age = _daysBetween(
            item.localDate,
            evaluationLocalDate,
            request.timezoneId,
          );
          return age >= 0 && age < policy.aggregateWindowDays;
        })
        .fold<int>(0, (sum, item) => sum + item.deltaKcal);
  }

  ({int lower, int upper})? _targetBound(
    NutritionGoalType type,
    int maintenance,
  ) {
    switch (type) {
      case NutritionGoalType.loss:
        final deficitByPercent =
            (B04ExactRational.fromInt(maintenance) *
                    policy.lossMaximumDeficit /
                    B04ExactRational.fromInt(100))
                .floorInteger()
                .toInt();
        final floorByPercent =
            (B04ExactRational.fromInt(maintenance) *
                    policy.lossMinimumFloor /
                    B04ExactRational.fromInt(100))
                .ceilInteger()
                .toInt();
        final lower =
            maintenance -
            (policy.lossMaximumDeficitKcal < deficitByPercent
                ? policy.lossMaximumDeficitKcal
                : deficitByPercent);
        final floor = policy.lossMinimumFloorKcal > floorByPercent
            ? policy.lossMinimumFloorKcal
            : floorByPercent;
        return (lower: lower > floor ? lower : floor, upper: maintenance);
      case NutritionGoalType.gain:
        final surplusByPercent =
            (B04ExactRational.fromInt(maintenance) *
                    policy.gainMaximumSurplus /
                    B04ExactRational.fromInt(100))
                .floorInteger()
                .toInt();
        final surplus = policy.gainMaximumSurplusKcal < surplusByPercent
            ? policy.gainMaximumSurplusKcal
            : surplusByPercent;
        return (lower: maintenance, upper: maintenance + surplus);
      case NutritionGoalType.maintenance:
      case NutritionGoalType.custom:
        return null;
    }
  }

  AdaptiveGoalProposal _proposal(
    B04AdaptiveTargetRequest request, {
    required NutritionGoalVersionReadModel goal,
    required String goalRate,
    required int candidateTarget,
    required int normalizedMaintenanceKcal,
    required List<String> evidenceIds,
    required B04ExactRational weeklyRatePercent,
  }) {
    final canonical = jsonEncode({
      'algorithm_version': policy.algorithmVersion,
      'evaluation_id': request.evaluationId.trim(),
      'evidence_ids': evidenceIds,
      'goal_id': goal.id,
      'goal_rate': goalRate,
      'maintenance': normalizedMaintenanceKcal,
      'policy_version': policy.policyVersion,
      'weekly_rate': weeklyRatePercent.canonical,
    });
    final fingerprint = sha256.convert(utf8.encode(canonical)).toString();
    return AdaptiveGoalProposal(
      id: 'b04-adaptive-proposal:${request.evaluationId.trim()}',
      userId: request.userId.trim(),
      goalType: goal.goalType,
      goalRate: goalRate,
      calorieTargetKcal: candidateTarget,
      proteinTargetG: goal.proteinTargetG,
      carbsTargetG: goal.carbsTargetG,
      fatTargetG: goal.fatTargetG,
      policyVersion: policy.policyVersion,
      calculationVersion: policy.calculationVersion,
      algorithmVersion: policy.algorithmVersion,
      effectiveFromLocalDate: request.evaluationLocalDate,
      timezoneId: request.timezoneId.trim(),
      evidenceFingerprint: fingerprint,
      exactResultNumerator: candidateTarget.toString(),
      exactResultDenominator: '1',
      normalizedMaintenanceKcal: normalizedMaintenanceKcal,
    );
  }

  B04AdaptiveTargetResult _hold(
    B04AdaptiveTargetRequest request, {
    required String reasonCode,
  }) => _failure(
    request,
    status: B04AdaptiveTargetStatus.unavailable,
    reasonCode: reasonCode,
    policyVersion: kB04HoldPolicyVersion,
    currentTargetKcal: request.activeGoal?.calorieTargetKcal,
  );

  B04AdaptiveTargetResult _failure(
    B04AdaptiveTargetRequest request, {
    B04AdaptiveTargetStatus status = B04AdaptiveTargetStatus.unavailable,
    required String reasonCode,
    String? policyVersion,
    int? currentTargetKcal,
    int? normalizedMaintenanceKcal,
    B04ExactRational? medianWeightGrams,
    B04ExactRational? slopeGramsPerDay,
    B04ExactRational? weeklyRatePercent,
    List<String> evidenceIds = const [],
  }) => _result(
    request,
    status: status,
    reasonCode: reasonCode,
    direction: B04AdaptiveTargetDirection.onTrack,
    adaptiveDeltaKcal: 0,
    currentTargetKcal: currentTargetKcal,
    normalizedMaintenanceKcal: normalizedMaintenanceKcal,
    medianWeightGrams: medianWeightGrams,
    slopeGramsPerDay: slopeGramsPerDay,
    weeklyRatePercent: weeklyRatePercent,
    evidenceIds: evidenceIds,
    policyVersion: policyVersion,
  );

  B04AdaptiveTargetResult _result(
    B04AdaptiveTargetRequest request, {
    required B04AdaptiveTargetStatus status,
    required String reasonCode,
    required B04AdaptiveTargetDirection direction,
    required int adaptiveDeltaKcal,
    int? currentTargetKcal,
    int? proposedTargetKcal,
    int? normalizedMaintenanceKcal,
    B04ExactRational? medianWeightGrams,
    B04ExactRational? slopeGramsPerDay,
    B04ExactRational? weeklyRatePercent,
    String? policyVersion,
    List<String> evidenceIds = const [],
    AdaptiveGoalProposal? proposal,
  }) {
    return B04AdaptiveTargetResult(
      status: status,
      reasonCode: reasonCode,
      policyVersion: policyVersion ?? policy.policyVersion,
      calculationVersion: policyVersion == kB04HoldPolicyVersion
          ? 'B04-07-TARGET-HOLD-V1'
          : policy.calculationVersion,
      algorithmVersion: policyVersion == kB04HoldPolicyVersion
          ? kB04HoldPolicyVersion
          : policy.algorithmVersion,
      direction: direction,
      adaptiveDeltaKcal: adaptiveDeltaKcal,
      currentTargetKcal: currentTargetKcal,
      proposedTargetKcal: proposedTargetKcal,
      normalizedMaintenanceKcal: normalizedMaintenanceKcal,
      medianWeightGrams: medianWeightGrams,
      slopeGramsPerDay: slopeGramsPerDay,
      weeklyRatePercent: weeklyRatePercent,
      displayWeeklyRatePercent: weeklyRatePercent?.displayPercent(),
      evidenceIds: evidenceIds,
      proposal: proposal,
      trainingOverlay: B04TrainingOverlayResult.unavailable,
    );
  }

  bool _isBefore(String first, String second) {
    try {
      return _dates.compare(first, second) < 0;
    } on Object {
      return false;
    }
  }

  int _daysBetween(String first, String second, String timezoneId) {
    final comparison = _dates.compare(first, second);
    if (comparison == 0) return 0;
    var cursor = first;
    var days = 0;
    final direction = comparison < 0 ? 1 : -1;
    while (cursor != second && days < 100000) {
      cursor = _dates.addCalendarDays(cursor, timezoneId, direction);
      days += direction;
    }
    if (cursor != second) throw StateError('Civil dates are not reachable.');
    return days;
  }
}

class _Gate<T> {
  final T? value;
  final _Failure? failure;

  const _Gate.value(this.value) : failure = null;
  const _Gate.failed(this.failure) : value = null;

  factory _Gate.failure(
    B04AdaptiveTargetStatus status,
    String reasonCode,
    List<String> evidenceIds,
  ) => _Gate<T>.failed(_Failure(status, reasonCode, evidenceIds));
}

class _Failure {
  final B04AdaptiveTargetStatus status;
  final String reasonCode;
  final List<String> evidenceIds;

  _Failure(this.status, this.reasonCode, Iterable<String> evidenceIds)
    : evidenceIds = List.unmodifiable(evidenceIds);
}

class _ParsedWeight {
  final B04WeightObservation item;
  final B04ExactRational grams;

  const _ParsedWeight({required this.item, required this.grams});
}

class _WeightSummary {
  final B04ExactRational medianWeightGrams;
  final B04ExactRational slopeGramsPerDay;
  final B04ExactRational weeklyRatePercent;
  final List<String> evidenceIds;

  const _WeightSummary({
    required this.medianWeightGrams,
    required this.slopeGramsPerDay,
    required this.weeklyRatePercent,
    required this.evidenceIds,
  });
}

class _NutritionSummary {
  final List<String> evidenceIds;

  const _NutritionSummary({required this.evidenceIds});
}

class _MaintenanceSummary {
  final int normalizedMaintenanceKcal;
  final List<String> evidenceIds;

  const _MaintenanceSummary({
    required this.normalizedMaintenanceKcal,
    required this.evidenceIds,
  });
}

class _ParsedRange {
  final B04ExactRational lower;
  final B04ExactRational upper;
  final B04ExactRational relativeWidthPercent;

  const _ParsedRange({
    required this.lower,
    required this.upper,
    required this.relativeWidthPercent,
  });
}
