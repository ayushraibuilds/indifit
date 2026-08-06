// B04-02 product, target and safety policy gate fixtures.
//
// This file is a review packet over the B04-01 contract matrix. It records
// gate state and safety semantics without activating ENABLED-1 or creating a
// runtime policy, target engine, UI, schema or persistence authority.

import 'b04_adaptive_coaching_fixture_matrix.dart';

const int kB04PolicyGateFixtureVersion = 1;
const String kB04PendingSolReviewStatus =
    'pending_fresh_independent_sol_high_review';

const List<String> kB04PolicyGateRequiredStateFixtureIds = [
  'hold-unavailable-zero-delta',
  'readiness-hold-zero-effect',
  'feedback-accept-append-only',
  'feedback-dismiss-no-mutation',
  'missing-required-evidence',
  'dangling-lineage',
  'dietary-possible-unavailable',
  'dietary-unknown-unavailable',
  'dietary-insufficient-unavailable',
  'unknown-nutrition-preserved',
  'range-crosses-decision-boundary',
  'missing-provenance-unavailable',
  'timezone-dst-local-date-frozen',
  'feedback-acknowledge-append-only',
  'feedback-override-user-set',
  'feedback-snooze-presentation-only',
  'future-only-enabled-replay',
];

const List<String> kB04PolicyGateRequiredArithmeticFixtureIds = [
  'E13-range-1800-2200',
  'E13-range-1799-2201',
  'E16-range-1850-2150',
  'E16-range-1849-2151',
  'E41-range-zero-midpoint',
  'E41-range-reversed',
  'E41-range-positive-point',
  'E41-range-negative-bound',
  'E41-range-non-finite',
  'E41-range-mismatched-units',
  'E43-odd-median-and-slopes',
  'E43-even-median-and-slopes',
  'E44-tied-and-fractional-slopes',
  'E42-M-2000',
  'E42-M-2001',
  'E42-M-1801',
];

const List<String> kB04PolicyGateRequiredSafetyWordingIds = [
  'general-wellness',
  'insufficient-information',
  'unsupported-goal',
  'consult-professional',
  'medical-exclusion',
  'emergency-out-of-scope',
  'dietary-unavailable',
  'dietary-hard-block',
  'no-known-conflict',
  'low-risk-logging-warning',
];

class B04ActivationGateFixture {
  final String id;
  final String requirement;
  final String evidenceReference;
  final bool blocking;
  final bool activationRequired;
  final bool satisfied;

  const B04ActivationGateFixture({
    required this.id,
    required this.requirement,
    required this.evidenceReference,
    required this.blocking,
    required this.activationRequired,
    required this.satisfied,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'requirement': requirement,
    'evidence_reference': evidenceReference,
    'blocking': blocking,
    'activation_required': activationRequired,
    'satisfied': satisfied,
  };

  factory B04ActivationGateFixture.fromJson(Map<String, dynamic> json) =>
      B04ActivationGateFixture(
        id: _gateString(json, 'id'),
        requirement: _gateString(json, 'requirement'),
        evidenceReference: _gateString(json, 'evidence_reference'),
        blocking: _gateBool(json, 'blocking'),
        activationRequired: _gateBool(json, 'activation_required'),
        satisfied: _gateBool(json, 'satisfied'),
      );

  void validate() {
    if (id.isEmpty ||
        requirement.isEmpty ||
        evidenceReference.isEmpty ||
        !blocking ||
        !activationRequired) {
      throw StateError('B04 activation gate $id is invalid.');
    }
  }
}

class B04HoldPolicyFixture {
  final String policyVersion;
  final B04FixtureOutcome expectedOutcome;
  final String availabilityReason;
  final String unit;
  final String effectivePeriod;
  final int upwardDeltaKcal;
  final int downwardDeltaKcal;
  final int aggregateDeltaKcal;
  final bool proposalAcceptanceAllowed;
  final bool userSetTargetPreserved;
  final bool userOverrideBypasses;
  final bool aiBypasses;
  final bool currentByDefault;
  final String missingDataRule;
  final String overrideRule;
  final String historicalRule;
  final List<String> replayCases;

  const B04HoldPolicyFixture({
    required this.policyVersion,
    required this.expectedOutcome,
    required this.availabilityReason,
    required this.unit,
    required this.effectivePeriod,
    required this.upwardDeltaKcal,
    required this.downwardDeltaKcal,
    required this.aggregateDeltaKcal,
    required this.proposalAcceptanceAllowed,
    required this.userSetTargetPreserved,
    required this.userOverrideBypasses,
    required this.aiBypasses,
    required this.currentByDefault,
    required this.missingDataRule,
    required this.overrideRule,
    required this.historicalRule,
    required this.replayCases,
  });

  static const current = B04HoldPolicyFixture(
    policyVersion: kB04HoldPolicyVersion,
    expectedOutcome: B04FixtureOutcome.unavailable,
    availabilityReason: 'adaptive_policy_hold',
    unit: 'kcal/day',
    effectivePeriod: 'per adaptation event and affected local-civil-day period',
    upwardDeltaKcal: 0,
    downwardDeltaKcal: 0,
    aggregateDeltaKcal: 0,
    proposalAcceptanceAllowed: false,
    userSetTargetPreserved: true,
    userOverrideBypasses: false,
    aiBypasses: false,
    currentByDefault: true,
    missingDataRule:
        'missing, invalid or stale evidence remains unavailable; never zero',
    overrideRule: 'user override and AI cannot bypass HOLD-1',
    historicalRule:
        'HOLD-1 history remains replayable; later policy changes affect future evaluations only',
    replayCases: [
      'hold_evaluation_replayed_after_enabled_policy_proposal',
      'hold_evaluation_replayed_after_enabled_policy_activation',
      'non_selected_installation_remains_on_hold',
    ],
  );

  Map<String, dynamic> toJson() => {
    'policy_version': policyVersion,
    'expected_outcome': expectedOutcome.name,
    'availability_reason': availabilityReason,
    'unit': unit,
    'effective_period': effectivePeriod,
    'upward_delta_kcal': upwardDeltaKcal,
    'downward_delta_kcal': downwardDeltaKcal,
    'aggregate_delta_kcal': aggregateDeltaKcal,
    'proposal_acceptance_allowed': proposalAcceptanceAllowed,
    'user_set_target_preserved': userSetTargetPreserved,
    'user_override_bypasses': userOverrideBypasses,
    'ai_bypasses': aiBypasses,
    'current_by_default': currentByDefault,
    'missing_data_rule': missingDataRule,
    'override_rule': overrideRule,
    'historical_rule': historicalRule,
    'replay_cases': replayCases,
  };

  factory B04HoldPolicyFixture.fromJson(Map<String, dynamic> json) =>
      B04HoldPolicyFixture(
        policyVersion: _gateString(json, 'policy_version'),
        expectedOutcome: _gateOutcome(json['expected_outcome']),
        availabilityReason: _gateString(json, 'availability_reason'),
        unit: _gateString(json, 'unit'),
        effectivePeriod: _gateString(json, 'effective_period'),
        upwardDeltaKcal: _gateInt(json, 'upward_delta_kcal'),
        downwardDeltaKcal: _gateInt(json, 'downward_delta_kcal'),
        aggregateDeltaKcal: _gateInt(json, 'aggregate_delta_kcal'),
        proposalAcceptanceAllowed: _gateBool(
          json,
          'proposal_acceptance_allowed',
        ),
        userSetTargetPreserved: _gateBool(json, 'user_set_target_preserved'),
        userOverrideBypasses: _gateBool(json, 'user_override_bypasses'),
        aiBypasses: _gateBool(json, 'ai_bypasses'),
        currentByDefault: _gateBool(json, 'current_by_default'),
        missingDataRule: _gateString(json, 'missing_data_rule'),
        overrideRule: _gateString(json, 'override_rule'),
        historicalRule: _gateString(json, 'historical_rule'),
        replayCases: _gateStrings(json, 'replay_cases'),
      );

  void validate() {
    if (policyVersion != kB04HoldPolicyVersion ||
        expectedOutcome != B04FixtureOutcome.unavailable ||
        availabilityReason != 'adaptive_policy_hold' ||
        unit != 'kcal/day' ||
        effectivePeriod.isEmpty ||
        upwardDeltaKcal != 0 ||
        downwardDeltaKcal != 0 ||
        aggregateDeltaKcal != 0 ||
        proposalAcceptanceAllowed ||
        !userSetTargetPreserved ||
        userOverrideBypasses ||
        aiBypasses ||
        !currentByDefault ||
        !missingDataRule.contains('never zero') ||
        !overrideRule.contains('cannot bypass') ||
        !historicalRule.contains('future') ||
        replayCases.length != 3) {
      throw StateError('HOLD-1 policy fixture is incomplete or changed.');
    }
  }
}

class B04ReadinessStateFixture {
  final String id;
  final String inputState;
  final B04FixtureOutcome expectedOutcome;
  final int calorieDeltaKcal;
  final B04Rational trainingLoadDeltaPercent;
  final B04Rational trainingIntensityDeltaPercent;
  final int scheduleDurationDelta;
  final String numericalEffect;

  const B04ReadinessStateFixture({
    required this.id,
    required this.inputState,
    required this.expectedOutcome,
    required this.calorieDeltaKcal,
    required this.trainingLoadDeltaPercent,
    required this.trainingIntensityDeltaPercent,
    required this.scheduleDurationDelta,
    required this.numericalEffect,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'input_state': inputState,
    'expected_outcome': expectedOutcome.name,
    'calorie_delta_kcal': calorieDeltaKcal,
    'training_load_delta_percent': trainingLoadDeltaPercent.toJson(),
    'training_intensity_delta_percent': trainingIntensityDeltaPercent.toJson(),
    'schedule_duration_delta': scheduleDurationDelta,
    'numerical_effect': numericalEffect,
  };

  factory B04ReadinessStateFixture.fromJson(Map<String, dynamic> json) =>
      B04ReadinessStateFixture(
        id: _gateString(json, 'id'),
        inputState: _gateString(json, 'input_state'),
        expectedOutcome: _gateOutcome(json['expected_outcome']),
        calorieDeltaKcal: _gateInt(json, 'calorie_delta_kcal'),
        trainingLoadDeltaPercent: B04Rational.fromJson(
          json['training_load_delta_percent'],
        ),
        trainingIntensityDeltaPercent: B04Rational.fromJson(
          json['training_intensity_delta_percent'],
        ),
        scheduleDurationDelta: _gateInt(json, 'schedule_duration_delta'),
        numericalEffect: _gateString(json, 'numerical_effect'),
      );

  void validate() {
    if (id.isEmpty ||
        inputState.isEmpty ||
        calorieDeltaKcal != 0 ||
        trainingLoadDeltaPercent != B04Rational.fromInt(0) ||
        trainingIntensityDeltaPercent != B04Rational.fromInt(0) ||
        scheduleDurationDelta != 0 ||
        numericalEffect != 'readiness has no numerical effect') {
      throw StateError('Readiness state $id is not an exact zero-effect case.');
    }
    final complete = inputState == 'complete';
    if (complete != (expectedOutcome == B04FixtureOutcome.available)) {
      throw StateError('Readiness state $id has an invalid availability.');
    }
  }
}

class B04ConsentAndAcceptanceFixture {
  final bool adaptiveCoachingDefaultOff;
  final bool explicitAdaptiveConsentRequired;
  final bool aiConsentSeparate;
  final bool implicitLoggingOrInactivityConsent;
  final bool withdrawalStopsFutureProposals;
  final bool historyPreservedAfterWithdrawal;
  final bool proposalAcceptanceRequired;
  final bool proposalAcceptanceIdempotent;
  final bool acceptanceRequiresEnabledPolicy;
  final bool acceptedChangeCreatesEffectiveDatedTargetVersion;
  final bool rejectionDismissalExpiryLeaveTargetUnchanged;
  final bool backgroundActivationAllowed;
  final bool offlineConsentRemainsDeterministic;

  const B04ConsentAndAcceptanceFixture({
    required this.adaptiveCoachingDefaultOff,
    required this.explicitAdaptiveConsentRequired,
    required this.aiConsentSeparate,
    required this.implicitLoggingOrInactivityConsent,
    required this.withdrawalStopsFutureProposals,
    required this.historyPreservedAfterWithdrawal,
    required this.proposalAcceptanceRequired,
    required this.proposalAcceptanceIdempotent,
    required this.acceptanceRequiresEnabledPolicy,
    required this.acceptedChangeCreatesEffectiveDatedTargetVersion,
    required this.rejectionDismissalExpiryLeaveTargetUnchanged,
    required this.backgroundActivationAllowed,
    required this.offlineConsentRemainsDeterministic,
  });

  static const current = B04ConsentAndAcceptanceFixture(
    adaptiveCoachingDefaultOff: true,
    explicitAdaptiveConsentRequired: true,
    aiConsentSeparate: true,
    implicitLoggingOrInactivityConsent: false,
    withdrawalStopsFutureProposals: true,
    historyPreservedAfterWithdrawal: true,
    proposalAcceptanceRequired: true,
    proposalAcceptanceIdempotent: true,
    acceptanceRequiresEnabledPolicy: true,
    acceptedChangeCreatesEffectiveDatedTargetVersion: true,
    rejectionDismissalExpiryLeaveTargetUnchanged: true,
    backgroundActivationAllowed: false,
    offlineConsentRemainsDeterministic: true,
  );

  Map<String, dynamic> toJson() => {
    'adaptive_coaching_default_off': adaptiveCoachingDefaultOff,
    'explicit_adaptive_consent_required': explicitAdaptiveConsentRequired,
    'ai_consent_separate': aiConsentSeparate,
    'implicit_logging_or_inactivity_consent':
        implicitLoggingOrInactivityConsent,
    'withdrawal_stops_future_proposals': withdrawalStopsFutureProposals,
    'history_preserved_after_withdrawal': historyPreservedAfterWithdrawal,
    'proposal_acceptance_required': proposalAcceptanceRequired,
    'proposal_acceptance_idempotent': proposalAcceptanceIdempotent,
    'acceptance_requires_enabled_policy': acceptanceRequiresEnabledPolicy,
    'accepted_change_creates_effective_dated_target_version':
        acceptedChangeCreatesEffectiveDatedTargetVersion,
    'rejection_dismissal_expiry_leave_target_unchanged':
        rejectionDismissalExpiryLeaveTargetUnchanged,
    'background_activation_allowed': backgroundActivationAllowed,
    'offline_consent_remains_deterministic': offlineConsentRemainsDeterministic,
  };

  factory B04ConsentAndAcceptanceFixture.fromJson(Map<String, dynamic> json) =>
      B04ConsentAndAcceptanceFixture(
        adaptiveCoachingDefaultOff: _gateBool(
          json,
          'adaptive_coaching_default_off',
        ),
        explicitAdaptiveConsentRequired: _gateBool(
          json,
          'explicit_adaptive_consent_required',
        ),
        aiConsentSeparate: _gateBool(json, 'ai_consent_separate'),
        implicitLoggingOrInactivityConsent: _gateBool(
          json,
          'implicit_logging_or_inactivity_consent',
        ),
        withdrawalStopsFutureProposals: _gateBool(
          json,
          'withdrawal_stops_future_proposals',
        ),
        historyPreservedAfterWithdrawal: _gateBool(
          json,
          'history_preserved_after_withdrawal',
        ),
        proposalAcceptanceRequired: _gateBool(
          json,
          'proposal_acceptance_required',
        ),
        proposalAcceptanceIdempotent: _gateBool(
          json,
          'proposal_acceptance_idempotent',
        ),
        acceptanceRequiresEnabledPolicy: _gateBool(
          json,
          'acceptance_requires_enabled_policy',
        ),
        acceptedChangeCreatesEffectiveDatedTargetVersion: _gateBool(
          json,
          'accepted_change_creates_effective_dated_target_version',
        ),
        rejectionDismissalExpiryLeaveTargetUnchanged: _gateBool(
          json,
          'rejection_dismissal_expiry_leave_target_unchanged',
        ),
        backgroundActivationAllowed: _gateBool(
          json,
          'background_activation_allowed',
        ),
        offlineConsentRemainsDeterministic: _gateBool(
          json,
          'offline_consent_remains_deterministic',
        ),
      );

  void validate() {
    if (!adaptiveCoachingDefaultOff ||
        !explicitAdaptiveConsentRequired ||
        !aiConsentSeparate ||
        implicitLoggingOrInactivityConsent ||
        !withdrawalStopsFutureProposals ||
        !historyPreservedAfterWithdrawal ||
        !proposalAcceptanceRequired ||
        !proposalAcceptanceIdempotent ||
        !acceptanceRequiresEnabledPolicy ||
        !acceptedChangeCreatesEffectiveDatedTargetVersion ||
        !rejectionDismissalExpiryLeaveTargetUnchanged ||
        backgroundActivationAllowed ||
        !offlineConsentRemainsDeterministic) {
      throw StateError('B04 consent or acceptance boundary is unsafe.');
    }
  }
}

class B04ReadinessHoldFixture {
  final String policyVersion;
  final bool descriptiveCoachingAllowed;
  final bool numericalProposalAllowed;
  final int calorieDeltaKcal;
  final B04Rational trainingLoadDeltaPercent;
  final B04Rational trainingIntensityDeltaPercent;
  final int scheduleDurationDelta;
  final String missingDataRule;
  final String historicalRule;
  final List<B04ReadinessStateFixture> states;

  const B04ReadinessHoldFixture({
    required this.policyVersion,
    required this.descriptiveCoachingAllowed,
    required this.numericalProposalAllowed,
    required this.calorieDeltaKcal,
    required this.trainingLoadDeltaPercent,
    required this.trainingIntensityDeltaPercent,
    required this.scheduleDurationDelta,
    required this.missingDataRule,
    required this.historicalRule,
    required this.states,
  });

  static final current = B04ReadinessHoldFixture(
    policyVersion: kB04ReadinessHoldPolicyVersion,
    descriptiveCoachingAllowed: true,
    numericalProposalAllowed: false,
    calorieDeltaKcal: 0,
    trainingLoadDeltaPercent: B04Rational.fromInt(0),
    trainingIntensityDeltaPercent: B04Rational.fromInt(0),
    scheduleDurationDelta: 0,
    missingDataRule:
        'missing, denied, stale or conflicting readiness remains unknown or unavailable; never zero-filled',
    historicalRule:
        'readiness snapshots retain provenance and corrections append future snapshots only',
    states: [
      B04ReadinessStateFixture(
        id: 'readiness-complete-zero-effect',
        inputState: 'complete',
        expectedOutcome: B04FixtureOutcome.available,
        calorieDeltaKcal: 0,
        trainingLoadDeltaPercent: B04Rational.fromInt(0),
        trainingIntensityDeltaPercent: B04Rational.fromInt(0),
        scheduleDurationDelta: 0,
        numericalEffect: 'readiness has no numerical effect',
      ),
      B04ReadinessStateFixture(
        id: 'readiness-missing-unknown-zero-effect',
        inputState: 'missing',
        expectedOutcome: B04FixtureOutcome.unavailable,
        calorieDeltaKcal: 0,
        trainingLoadDeltaPercent: B04Rational.fromInt(0),
        trainingIntensityDeltaPercent: B04Rational.fromInt(0),
        scheduleDurationDelta: 0,
        numericalEffect: 'readiness has no numerical effect',
      ),
      B04ReadinessStateFixture(
        id: 'readiness-denied-unavailable-zero-effect',
        inputState: 'denied',
        expectedOutcome: B04FixtureOutcome.unavailable,
        calorieDeltaKcal: 0,
        trainingLoadDeltaPercent: B04Rational.fromInt(0),
        trainingIntensityDeltaPercent: B04Rational.fromInt(0),
        scheduleDurationDelta: 0,
        numericalEffect: 'readiness has no numerical effect',
      ),
      B04ReadinessStateFixture(
        id: 'readiness-stale-unavailable-zero-effect',
        inputState: 'stale',
        expectedOutcome: B04FixtureOutcome.unavailable,
        calorieDeltaKcal: 0,
        trainingLoadDeltaPercent: B04Rational.fromInt(0),
        trainingIntensityDeltaPercent: B04Rational.fromInt(0),
        scheduleDurationDelta: 0,
        numericalEffect: 'readiness has no numerical effect',
      ),
      B04ReadinessStateFixture(
        id: 'readiness-conflicting-unavailable-zero-effect',
        inputState: 'conflicting',
        expectedOutcome: B04FixtureOutcome.unavailable,
        calorieDeltaKcal: 0,
        trainingLoadDeltaPercent: B04Rational.fromInt(0),
        trainingIntensityDeltaPercent: B04Rational.fromInt(0),
        scheduleDurationDelta: 0,
        numericalEffect: 'readiness has no numerical effect',
      ),
    ],
  );

  Map<String, dynamic> toJson() => {
    'policy_version': policyVersion,
    'descriptive_coaching_allowed': descriptiveCoachingAllowed,
    'numerical_proposal_allowed': numericalProposalAllowed,
    'calorie_delta_kcal': calorieDeltaKcal,
    'training_load_delta_percent': trainingLoadDeltaPercent.toJson(),
    'training_intensity_delta_percent': trainingIntensityDeltaPercent.toJson(),
    'schedule_duration_delta': scheduleDurationDelta,
    'missing_data_rule': missingDataRule,
    'historical_rule': historicalRule,
    'states': states.map((state) => state.toJson()).toList(),
  };

  factory B04ReadinessHoldFixture.fromJson(Map<String, dynamic> json) =>
      B04ReadinessHoldFixture(
        policyVersion: _gateString(json, 'policy_version'),
        descriptiveCoachingAllowed: _gateBool(
          json,
          'descriptive_coaching_allowed',
        ),
        numericalProposalAllowed: _gateBool(json, 'numerical_proposal_allowed'),
        calorieDeltaKcal: _gateInt(json, 'calorie_delta_kcal'),
        trainingLoadDeltaPercent: B04Rational.fromJson(
          json['training_load_delta_percent'],
        ),
        trainingIntensityDeltaPercent: B04Rational.fromJson(
          json['training_intensity_delta_percent'],
        ),
        scheduleDurationDelta: _gateInt(json, 'schedule_duration_delta'),
        missingDataRule: _gateString(json, 'missing_data_rule'),
        historicalRule: _gateString(json, 'historical_rule'),
        states: _gateObjects(json, 'states', B04ReadinessStateFixture.fromJson),
      );

  void validate() {
    if (policyVersion != kB04ReadinessHoldPolicyVersion ||
        !descriptiveCoachingAllowed ||
        numericalProposalAllowed ||
        calorieDeltaKcal != 0 ||
        trainingLoadDeltaPercent != B04Rational.fromInt(0) ||
        trainingIntensityDeltaPercent != B04Rational.fromInt(0) ||
        scheduleDurationDelta != 0 ||
        !missingDataRule.contains('unknown') ||
        !missingDataRule.contains('never zero') ||
        !historicalRule.contains('future') ||
        states.length != 5) {
      throw StateError('READINESS-HOLD-1 fixture is incomplete or changed.');
    }
    for (final state in states) {
      state.validate();
    }
    final stateNames = states.map((state) => state.inputState).toSet();
    if (!stateNames.containsAll([
      'complete',
      'missing',
      'denied',
      'stale',
      'conflicting',
    ])) {
      throw StateError('READINESS-HOLD-1 input states are incomplete.');
    }
  }
}

class B04SafetyWordingFixture {
  final String id;
  final String semanticState;
  final String text;
  final bool recommendationAllowed;
  final bool targetMutationAllowed;
  final bool hardBlock;
  final bool lowRiskLoggingOnly;
  final bool aiMayAlterNumericalMeaning;
  final List<String> prohibitedClaims;

  const B04SafetyWordingFixture({
    required this.id,
    required this.semanticState,
    required this.text,
    required this.recommendationAllowed,
    required this.targetMutationAllowed,
    required this.hardBlock,
    required this.lowRiskLoggingOnly,
    required this.aiMayAlterNumericalMeaning,
    required this.prohibitedClaims,
  });

  static const catalog = [
    B04SafetyWordingFixture(
      id: 'general-wellness',
      semanticState: 'general_wellness',
      text: 'General wellness guidance only; not medical advice.',
      recommendationAllowed: true,
      targetMutationAllowed: false,
      hardBlock: false,
      lowRiskLoggingOnly: false,
      aiMayAlterNumericalMeaning: false,
      prohibitedClaims: ['diagnosis', 'prescription', 'guarantee'],
    ),
    B04SafetyWordingFixture(
      id: 'insufficient-information',
      semanticState: 'insufficient_information',
      text:
          'There is not enough reliable information for personalized guidance; the current target remains unchanged.',
      recommendationAllowed: false,
      targetMutationAllowed: false,
      hardBlock: false,
      lowRiskLoggingOnly: false,
      aiMayAlterNumericalMeaning: false,
      prohibitedClaims: ['false precision', 'default substitution'],
    ),
    B04SafetyWordingFixture(
      id: 'unsupported-goal',
      semanticState: 'unsupported_goal',
      text:
          'This goal is outside the supported policy; the current target remains unchanged.',
      recommendationAllowed: false,
      targetMutationAllowed: false,
      hardBlock: false,
      lowRiskLoggingOnly: false,
      aiMayAlterNumericalMeaning: false,
      prohibitedClaims: ['guaranteed outcome', 'silent target change'],
    ),
    B04SafetyWordingFixture(
      id: 'consult-professional',
      semanticState: 'consult_professional',
      text:
          'For medical or treatment decisions, consult a qualified healthcare professional.',
      recommendationAllowed: false,
      targetMutationAllowed: false,
      hardBlock: false,
      lowRiskLoggingOnly: false,
      aiMayAlterNumericalMeaning: false,
      prohibitedClaims: ['clinical substitution', 'diagnostic interpretation'],
    ),
    B04SafetyWordingFixture(
      id: 'medical-exclusion',
      semanticState: 'medical_exclusion',
      text:
          'The app cannot diagnose, prescribe, validate a condition or replace professional care.',
      recommendationAllowed: false,
      targetMutationAllowed: false,
      hardBlock: false,
      lowRiskLoggingOnly: false,
      aiMayAlterNumericalMeaning: false,
      prohibitedClaims: ['diagnosis', 'treatment', 'emergency assessment'],
    ),
    B04SafetyWordingFixture(
      id: 'emergency-out-of-scope',
      semanticState: 'emergency_out_of_scope',
      text:
          'Severe or emergency symptoms are outside this feature; use local emergency help.',
      recommendationAllowed: false,
      targetMutationAllowed: false,
      hardBlock: false,
      lowRiskLoggingOnly: false,
      aiMayAlterNumericalMeaning: false,
      prohibitedClaims: ['severity assessment', 'emergency diagnosis'],
    ),
    B04SafetyWordingFixture(
      id: 'dietary-unavailable',
      semanticState: 'dietary_evidence_unavailable',
      text:
          'Safety-sensitive guidance is unavailable because dietary evidence is missing or uncertain.',
      recommendationAllowed: false,
      targetMutationAllowed: false,
      hardBlock: false,
      lowRiskLoggingOnly: true,
      aiMayAlterNumericalMeaning: false,
      prohibitedClaims: ['safe', 'no conflict'],
    ),
    B04SafetyWordingFixture(
      id: 'dietary-hard-block',
      semanticState: 'dietary_hard_block',
      text: 'This candidate is blocked by the recorded dietary constraint.',
      recommendationAllowed: false,
      targetMutationAllowed: false,
      hardBlock: true,
      lowRiskLoggingOnly: true,
      aiMayAlterNumericalMeaning: false,
      prohibitedClaims: ['override safety', 'safe after acknowledgement'],
    ),
    B04SafetyWordingFixture(
      id: 'no-known-conflict',
      semanticState: 'no_known_conflict',
      text: 'No known conflict was detected for the checked evidence.',
      recommendationAllowed: true,
      targetMutationAllowed: false,
      hardBlock: false,
      lowRiskLoggingOnly: false,
      aiMayAlterNumericalMeaning: false,
      prohibitedClaims: ['safety guarantee', 'complete evaluation'],
    ),
    B04SafetyWordingFixture(
      id: 'low-risk-logging-warning',
      semanticState: 'low_risk_logging_warning',
      text:
          'You may record a personal log, but acknowledgement does not make the item suitable or safe.',
      recommendationAllowed: false,
      targetMutationAllowed: false,
      hardBlock: false,
      lowRiskLoggingOnly: true,
      aiMayAlterNumericalMeaning: false,
      prohibitedClaims: ['recommendation output', 'safety downgrade'],
    ),
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'semantic_state': semanticState,
    'text': text,
    'recommendation_allowed': recommendationAllowed,
    'target_mutation_allowed': targetMutationAllowed,
    'hard_block': hardBlock,
    'low_risk_logging_only': lowRiskLoggingOnly,
    'ai_may_alter_numerical_meaning': aiMayAlterNumericalMeaning,
    'prohibited_claims': prohibitedClaims,
  };

  factory B04SafetyWordingFixture.fromJson(Map<String, dynamic> json) =>
      B04SafetyWordingFixture(
        id: _gateString(json, 'id'),
        semanticState: _gateString(json, 'semantic_state'),
        text: _gateString(json, 'text'),
        recommendationAllowed: _gateBool(json, 'recommendation_allowed'),
        targetMutationAllowed: _gateBool(json, 'target_mutation_allowed'),
        hardBlock: _gateBool(json, 'hard_block'),
        lowRiskLoggingOnly: _gateBool(json, 'low_risk_logging_only'),
        aiMayAlterNumericalMeaning: _gateBool(
          json,
          'ai_may_alter_numerical_meaning',
        ),
        prohibitedClaims: _gateStrings(json, 'prohibited_claims'),
      );

  void validate() {
    if (id.isEmpty ||
        semanticState.isEmpty ||
        text.isEmpty ||
        targetMutationAllowed ||
        aiMayAlterNumericalMeaning ||
        prohibitedClaims.isEmpty) {
      throw StateError('Safety wording fixture $id is unsafe or incomplete.');
    }
    if (hardBlock && recommendationAllowed) {
      throw StateError('Hard-block wording $id allows recommendation output.');
    }
    if (lowRiskLoggingOnly && recommendationAllowed) {
      throw StateError(
        'Low-risk logging wording $id allows recommendation output.',
      );
    }
  }
}

class B04OfflineAiBoundaryFixture {
  final bool deterministicLocalResultAllowed;
  final bool missingRequiredEvidenceUnavailable;
  final bool providerFailureQueuesAuthoritativeChange;
  final bool separateAiConsentRequired;
  final bool redactedEnvelopeOnly;
  final bool rawPromptPersisted;
  final bool rawResponsePersisted;
  final bool rawHealthOrDietaryPayloadSent;
  final bool aiCanAlterTarget;
  final bool aiCanAlterSafety;
  final bool aiCanAlterConfidence;

  const B04OfflineAiBoundaryFixture({
    required this.deterministicLocalResultAllowed,
    required this.missingRequiredEvidenceUnavailable,
    required this.providerFailureQueuesAuthoritativeChange,
    required this.separateAiConsentRequired,
    required this.redactedEnvelopeOnly,
    required this.rawPromptPersisted,
    required this.rawResponsePersisted,
    required this.rawHealthOrDietaryPayloadSent,
    required this.aiCanAlterTarget,
    required this.aiCanAlterSafety,
    required this.aiCanAlterConfidence,
  });

  static const current = B04OfflineAiBoundaryFixture(
    deterministicLocalResultAllowed: true,
    missingRequiredEvidenceUnavailable: true,
    providerFailureQueuesAuthoritativeChange: false,
    separateAiConsentRequired: true,
    redactedEnvelopeOnly: true,
    rawPromptPersisted: false,
    rawResponsePersisted: false,
    rawHealthOrDietaryPayloadSent: false,
    aiCanAlterTarget: false,
    aiCanAlterSafety: false,
    aiCanAlterConfidence: false,
  );

  Map<String, dynamic> toJson() => {
    'deterministic_local_result_allowed': deterministicLocalResultAllowed,
    'missing_required_evidence_unavailable': missingRequiredEvidenceUnavailable,
    'provider_failure_queues_authoritative_change':
        providerFailureQueuesAuthoritativeChange,
    'separate_ai_consent_required': separateAiConsentRequired,
    'redacted_envelope_only': redactedEnvelopeOnly,
    'raw_prompt_persisted': rawPromptPersisted,
    'raw_response_persisted': rawResponsePersisted,
    'raw_health_or_dietary_payload_sent': rawHealthOrDietaryPayloadSent,
    'ai_can_alter_target': aiCanAlterTarget,
    'ai_can_alter_safety': aiCanAlterSafety,
    'ai_can_alter_confidence': aiCanAlterConfidence,
  };

  factory B04OfflineAiBoundaryFixture.fromJson(Map<String, dynamic> json) =>
      B04OfflineAiBoundaryFixture(
        deterministicLocalResultAllowed: _gateBool(
          json,
          'deterministic_local_result_allowed',
        ),
        missingRequiredEvidenceUnavailable: _gateBool(
          json,
          'missing_required_evidence_unavailable',
        ),
        providerFailureQueuesAuthoritativeChange: _gateBool(
          json,
          'provider_failure_queues_authoritative_change',
        ),
        separateAiConsentRequired: _gateBool(
          json,
          'separate_ai_consent_required',
        ),
        redactedEnvelopeOnly: _gateBool(json, 'redacted_envelope_only'),
        rawPromptPersisted: _gateBool(json, 'raw_prompt_persisted'),
        rawResponsePersisted: _gateBool(json, 'raw_response_persisted'),
        rawHealthOrDietaryPayloadSent: _gateBool(
          json,
          'raw_health_or_dietary_payload_sent',
        ),
        aiCanAlterTarget: _gateBool(json, 'ai_can_alter_target'),
        aiCanAlterSafety: _gateBool(json, 'ai_can_alter_safety'),
        aiCanAlterConfidence: _gateBool(json, 'ai_can_alter_confidence'),
      );

  void validate() {
    if (!deterministicLocalResultAllowed ||
        !missingRequiredEvidenceUnavailable ||
        providerFailureQueuesAuthoritativeChange ||
        !separateAiConsentRequired ||
        !redactedEnvelopeOnly ||
        rawPromptPersisted ||
        rawResponsePersisted ||
        rawHealthOrDietaryPayloadSent ||
        aiCanAlterTarget ||
        aiCanAlterSafety ||
        aiCanAlterConfidence) {
      throw StateError('B04 offline or AI boundary is unsafe.');
    }
  }
}

class B04N8BoundaryFixture {
  final bool inferenceAllowed;
  final bool currentPersistenceAllowed;
  final bool targetChangesAllowed;
  final String absentContextOutcome;
  final String requiredFutureGate;

  const B04N8BoundaryFixture({
    required this.inferenceAllowed,
    required this.currentPersistenceAllowed,
    required this.targetChangesAllowed,
    required this.absentContextOutcome,
    required this.requiredFutureGate,
  });

  static const current = B04N8BoundaryFixture(
    inferenceAllowed: false,
    currentPersistenceAllowed: false,
    targetChangesAllowed: false,
    absentContextOutcome: 'ordinary evidence-limited or unavailable guidance',
    requiredFutureGate:
        'explicit Product Owner decision, typed semantics, privacy review and new task DAG',
  );

  Map<String, dynamic> toJson() => {
    'inference_allowed': inferenceAllowed,
    'current_persistence_allowed': currentPersistenceAllowed,
    'target_changes_allowed': targetChangesAllowed,
    'absent_context_outcome': absentContextOutcome,
    'required_future_gate': requiredFutureGate,
  };

  factory B04N8BoundaryFixture.fromJson(Map<String, dynamic> json) =>
      B04N8BoundaryFixture(
        inferenceAllowed: _gateBool(json, 'inference_allowed'),
        currentPersistenceAllowed: _gateBool(
          json,
          'current_persistence_allowed',
        ),
        targetChangesAllowed: _gateBool(json, 'target_changes_allowed'),
        absentContextOutcome: _gateString(json, 'absent_context_outcome'),
        requiredFutureGate: _gateString(json, 'required_future_gate'),
      );

  void validate() {
    if (inferenceAllowed ||
        currentPersistenceAllowed ||
        targetChangesAllowed ||
        absentContextOutcome.isEmpty ||
        !requiredFutureGate.contains('new task DAG')) {
      throw StateError('B04 N8 boundary is not conditional and independent.');
    }
  }
}

class B04LegacyPolicyIsolationFixture {
  final List<String> legacyValues;
  final bool authoritativeForB04;
  final String disposition;

  const B04LegacyPolicyIsolationFixture({
    required this.legacyValues,
    required this.authoritativeForB04,
    required this.disposition,
  });

  static const current = B04LegacyPolicyIsolationFixture(
    legacyValues: ['-500 kcal/day', '+300 kcal/day', '1200 kcal/day'],
    authoritativeForB04: false,
    disposition:
        'legacy compatibility behavior only; never infer or authorize B04 policy',
  );

  Map<String, dynamic> toJson() => {
    'legacy_values': legacyValues,
    'authoritative_for_b04': authoritativeForB04,
    'disposition': disposition,
  };

  factory B04LegacyPolicyIsolationFixture.fromJson(Map<String, dynamic> json) =>
      B04LegacyPolicyIsolationFixture(
        legacyValues: _gateStrings(json, 'legacy_values'),
        authoritativeForB04: _gateBool(json, 'authoritative_for_b04'),
        disposition: _gateString(json, 'disposition'),
      );

  void validate() {
    if (legacyValues.length != 3 ||
        authoritativeForB04 ||
        !disposition.contains('never infer') ||
        !disposition.contains('authorize')) {
      throw StateError('Legacy policy constants are not isolated.');
    }
  }
}

class B04SolReviewPacketFixture {
  final String reviewerRole;
  final String status;
  final bool freshIndependentReviewRequired;
  final bool activationEligible;
  final List<String> requiredScope;
  final List<String> acceptedVerdicts;

  const B04SolReviewPacketFixture({
    required this.reviewerRole,
    required this.status,
    required this.freshIndependentReviewRequired,
    required this.activationEligible,
    required this.requiredScope,
    required this.acceptedVerdicts,
  });

  static const current = B04SolReviewPacketFixture(
    reviewerRole: 'Sol High',
    status: kB04PendingSolReviewStatus,
    freshIndependentReviewRequired: true,
    activationEligible: false,
    requiredScope: [
      'ENABLED-1 numerical policy and boundary semantics',
      'HOLD-1 and READINESS-HOLD-1 zero-effect behavior',
      'B02 provenance/readiness boundary',
      'B03 dietary safety and uncertainty mapping',
      'historical replay and future-only policy changes',
      'offline, AI redaction and privacy boundary',
      'professional wording and safety exclusions',
    ],
    acceptedVerdicts: ['approved', 'approved_with_non_blocking_follow_up'],
  );

  Map<String, dynamic> toJson() => {
    'reviewer_role': reviewerRole,
    'status': status,
    'fresh_independent_review_required': freshIndependentReviewRequired,
    'activation_eligible': activationEligible,
    'required_scope': requiredScope,
    'accepted_verdicts': acceptedVerdicts,
  };

  factory B04SolReviewPacketFixture.fromJson(Map<String, dynamic> json) =>
      B04SolReviewPacketFixture(
        reviewerRole: _gateString(json, 'reviewer_role'),
        status: _gateString(json, 'status'),
        freshIndependentReviewRequired: _gateBool(
          json,
          'fresh_independent_review_required',
        ),
        activationEligible: _gateBool(json, 'activation_eligible'),
        requiredScope: _gateStrings(json, 'required_scope'),
        acceptedVerdicts: _gateStrings(json, 'accepted_verdicts'),
      );

  void validate() {
    if (reviewerRole != 'Sol High' ||
        status != kB04PendingSolReviewStatus ||
        !freshIndependentReviewRequired ||
        activationEligible ||
        requiredScope.length != 7 ||
        !acceptedVerdicts.contains('approved') ||
        !acceptedVerdicts.contains('approved_with_non_blocking_follow_up') ||
        !_sameOrderedStrings(requiredScope, current.requiredScope) ||
        !_sameOrderedStrings(acceptedVerdicts, current.acceptedVerdicts)) {
      throw StateError('Fresh independent Sol review packet is invalid.');
    }
  }
}

class B04PolicyGateFixturePacket {
  final int version;
  final int sourceContractVersion;
  final String enabledPolicyVersion;
  final String holdPolicyVersion;
  final String readinessHoldPolicyVersion;
  final String currentPolicyVersion;
  final bool enabledPolicyActive;
  final bool activationEffectiveDateAssigned;
  final List<String> decisionIds;
  final List<B04ActivationGateFixture> activationGates;
  final B04ConsentAndAcceptanceFixture consentAndAcceptance;
  final B04HoldPolicyFixture holdPolicy;
  final B04ReadinessHoldFixture readinessHold;
  final List<B04SafetyWordingFixture> safetyWording;
  final B04OfflineAiBoundaryFixture offlineAiBoundary;
  final B04N8BoundaryFixture n8Boundary;
  final B04LegacyPolicyIsolationFixture legacyPolicyIsolation;
  final B04SolReviewPacketFixture solReview;
  final List<String> requiredEdgeIds;
  final List<String> requiredStateFixtureIds;
  final List<String> requiredArithmeticFixtureIds;

  const B04PolicyGateFixturePacket({
    required this.version,
    required this.sourceContractVersion,
    required this.enabledPolicyVersion,
    required this.holdPolicyVersion,
    required this.readinessHoldPolicyVersion,
    required this.currentPolicyVersion,
    required this.enabledPolicyActive,
    required this.activationEffectiveDateAssigned,
    required this.decisionIds,
    required this.activationGates,
    required this.consentAndAcceptance,
    required this.holdPolicy,
    required this.readinessHold,
    required this.safetyWording,
    required this.offlineAiBoundary,
    required this.n8Boundary,
    required this.legacyPolicyIsolation,
    required this.solReview,
    required this.requiredEdgeIds,
    required this.requiredStateFixtureIds,
    required this.requiredArithmeticFixtureIds,
  });

  static final current = B04PolicyGateFixturePacket(
    version: kB04PolicyGateFixtureVersion,
    sourceContractVersion: kB04AdaptiveCoachingFixtureContractVersion,
    enabledPolicyVersion: kB04EnabledPolicyVersion,
    holdPolicyVersion: kB04HoldPolicyVersion,
    readinessHoldPolicyVersion: kB04ReadinessHoldPolicyVersion,
    currentPolicyVersion: kB04HoldPolicyVersion,
    enabledPolicyActive: false,
    activationEffectiveDateAssigned: false,
    decisionIds: b04D04DecisionIds,
    activationGates: [
      B04ActivationGateFixture(
        id: 'product-owner-approval',
        requirement:
            'Product Owner approval is recorded for the proposed policy.',
        evidenceReference: 'DECISIONS.md#B04-D04-ENABLED-1',
        blocking: true,
        activationRequired: true,
        satisfied: true,
      ),
      B04ActivationGateFixture(
        id: 'fresh-independent-sol-high',
        requirement:
            'Fresh independent Sol High safety and implementation-readiness verdict is approved.',
        evidenceReference: 'VERIFICATION.md#B04-D04 policy-gate verification',
        blocking: true,
        activationRequired: true,
        satisfied: false,
      ),
      B04ActivationGateFixture(
        id: 'policy-branch-merge',
        requirement: 'The reviewed policy branch is merged into integration.',
        evidenceReference: 'release/feature-policy selection record',
        blocking: true,
        activationRequired: true,
        satisfied: false,
      ),
      B04ActivationGateFixture(
        id: 'explicit-release-selection',
        requirement:
            'A release or feature-policy selection records future effective date, timezone and scope.',
        evidenceReference: 'release/feature-policy selection record',
        blocking: true,
        activationRequired: true,
        satisfied: false,
      ),
    ],
    consentAndAcceptance: B04ConsentAndAcceptanceFixture.current,
    holdPolicy: B04HoldPolicyFixture.current,
    readinessHold: B04ReadinessHoldFixture.current,
    safetyWording: B04SafetyWordingFixture.catalog,
    offlineAiBoundary: B04OfflineAiBoundaryFixture.current,
    n8Boundary: B04N8BoundaryFixture.current,
    legacyPolicyIsolation: B04LegacyPolicyIsolationFixture.current,
    solReview: B04SolReviewPacketFixture.current,
    requiredEdgeIds: b04EnabledEdgeIds,
    requiredStateFixtureIds: kB04PolicyGateRequiredStateFixtureIds,
    requiredArithmeticFixtureIds: kB04PolicyGateRequiredArithmeticFixtureIds,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'source_contract_version': sourceContractVersion,
    'enabled_policy_version': enabledPolicyVersion,
    'hold_policy_version': holdPolicyVersion,
    'readiness_hold_policy_version': readinessHoldPolicyVersion,
    'current_policy_version': currentPolicyVersion,
    'enabled_policy_active': enabledPolicyActive,
    'activation_effective_date_assigned': activationEffectiveDateAssigned,
    'decision_ids': decisionIds,
    'activation_gates': activationGates.map((gate) => gate.toJson()).toList(),
    'consent_and_acceptance': consentAndAcceptance.toJson(),
    'hold_policy': holdPolicy.toJson(),
    'readiness_hold': readinessHold.toJson(),
    'safety_wording': safetyWording.map((item) => item.toJson()).toList(),
    'offline_ai_boundary': offlineAiBoundary.toJson(),
    'n8_boundary': n8Boundary.toJson(),
    'legacy_policy_isolation': legacyPolicyIsolation.toJson(),
    'sol_review': solReview.toJson(),
    'required_edge_ids': requiredEdgeIds,
    'required_state_fixture_ids': requiredStateFixtureIds,
    'required_arithmetic_fixture_ids': requiredArithmeticFixtureIds,
  };

  factory B04PolicyGateFixturePacket.fromJson(Map<String, dynamic> json) {
    final packet = B04PolicyGateFixturePacket(
      version: _gateInt(json, 'version'),
      sourceContractVersion: _gateInt(json, 'source_contract_version'),
      enabledPolicyVersion: _gateString(json, 'enabled_policy_version'),
      holdPolicyVersion: _gateString(json, 'hold_policy_version'),
      readinessHoldPolicyVersion: _gateString(
        json,
        'readiness_hold_policy_version',
      ),
      currentPolicyVersion: _gateString(json, 'current_policy_version'),
      enabledPolicyActive: _gateBool(json, 'enabled_policy_active'),
      activationEffectiveDateAssigned: _gateBool(
        json,
        'activation_effective_date_assigned',
      ),
      decisionIds: _gateStrings(json, 'decision_ids'),
      activationGates: _gateObjects(
        json,
        'activation_gates',
        B04ActivationGateFixture.fromJson,
      ),
      consentAndAcceptance: B04ConsentAndAcceptanceFixture.fromJson(
        _gateMap(json['consent_and_acceptance'], 'consent_and_acceptance'),
      ),
      holdPolicy: B04HoldPolicyFixture.fromJson(
        _gateMap(json['hold_policy'], 'hold_policy'),
      ),
      readinessHold: B04ReadinessHoldFixture.fromJson(
        _gateMap(json['readiness_hold'], 'readiness_hold'),
      ),
      safetyWording: _gateObjects(
        json,
        'safety_wording',
        B04SafetyWordingFixture.fromJson,
      ),
      offlineAiBoundary: B04OfflineAiBoundaryFixture.fromJson(
        _gateMap(json['offline_ai_boundary'], 'offline_ai_boundary'),
      ),
      n8Boundary: B04N8BoundaryFixture.fromJson(
        _gateMap(json['n8_boundary'], 'n8_boundary'),
      ),
      legacyPolicyIsolation: B04LegacyPolicyIsolationFixture.fromJson(
        _gateMap(json['legacy_policy_isolation'], 'legacy_policy_isolation'),
      ),
      solReview: B04SolReviewPacketFixture.fromJson(
        _gateMap(json['sol_review'], 'sol_review'),
      ),
      requiredEdgeIds: _gateStrings(json, 'required_edge_ids'),
      requiredStateFixtureIds: _gateStrings(json, 'required_state_fixture_ids'),
      requiredArithmeticFixtureIds: _gateStrings(
        json,
        'required_arithmetic_fixture_ids',
      ),
    );

    packet.validate();
    return packet;
  }

  void validate() {
    if (version != kB04PolicyGateFixtureVersion ||
        sourceContractVersion != kB04AdaptiveCoachingFixtureContractVersion ||
        enabledPolicyVersion != kB04EnabledPolicyVersion ||
        holdPolicyVersion != kB04HoldPolicyVersion ||
        readinessHoldPolicyVersion != kB04ReadinessHoldPolicyVersion ||
        currentPolicyVersion != kB04HoldPolicyVersion ||
        enabledPolicyActive ||
        activationEffectiveDateAssigned ||
        decisionIds.length != 20 ||
        !decisionIds.toSet().containsAll(b04D04DecisionIds) ||
        activationGates.length != 4 ||
        requiredEdgeIds.length != b04EnabledEdgeIds.length ||
        !requiredEdgeIds.toSet().containsAll(b04EnabledEdgeIds) ||
        !_sameStrings(
          requiredStateFixtureIds,
          kB04PolicyGateRequiredStateFixtureIds,
        ) ||
        !_sameStrings(
          requiredArithmeticFixtureIds,
          kB04PolicyGateRequiredArithmeticFixtureIds,
        )) {
      throw StateError('B04-02 policy gate packet is incomplete.');
    }

    final matrix = B04AdaptiveCoachingFixtureMatrix.current;
    matrix.validate();
    if (matrix.enabledPolicy.policyVersion != enabledPolicyVersion ||
        matrix.decisions.any((decision) => !decision.blocking)) {
      throw StateError('B04-02 packet does not use the canonical matrix.');
    }

    for (final gate in activationGates) {
      gate.validate();
    }
    final gateIds = activationGates.map((gate) => gate.id).toSet();
    final expectedGates = {
      for (final gate in B04PolicyGateFixturePacket.current.activationGates)
        gate.id: gate,
    };
    if (!_sameStrings(gateIds, expectedGates.keys)) {
      throw StateError('B04 activation gate coverage is incomplete.');
    }
    for (final gate in activationGates) {
      final expected = expectedGates[gate.id]!;
      if (gate.requirement != expected.requirement ||
          gate.evidenceReference != expected.evidenceReference ||
          gate.blocking != expected.blocking ||
          gate.activationRequired != expected.activationRequired ||
          gate.satisfied != expected.satisfied) {
        throw StateError('B04 activation gate ${gate.id} changed.');
      }
    }

    consentAndAcceptance.validate();
    holdPolicy.validate();
    readinessHold.validate();
    if (!_sameStrings(
      safetyWording.map((item) => item.id),
      kB04PolicyGateRequiredSafetyWordingIds,
    )) {
      throw StateError('B04 safety wording catalog coverage is incomplete.');
    }
    for (final wording in safetyWording) {
      wording.validate();
      final expected = B04SafetyWordingFixture.catalog.singleWhere(
        (item) => item.id == wording.id,
      );
      if (wording.semanticState != expected.semanticState ||
          wording.text != expected.text ||
          wording.recommendationAllowed != expected.recommendationAllowed ||
          wording.targetMutationAllowed != expected.targetMutationAllowed ||
          wording.hardBlock != expected.hardBlock ||
          wording.lowRiskLoggingOnly != expected.lowRiskLoggingOnly ||
          wording.aiMayAlterNumericalMeaning !=
              expected.aiMayAlterNumericalMeaning ||
          !_sameOrderedStrings(
            wording.prohibitedClaims,
            expected.prohibitedClaims,
          )) {
        throw StateError('B04 safety wording ${wording.id} changed.');
      }
    }
    offlineAiBoundary.validate();
    n8Boundary.validate();
    legacyPolicyIsolation.validate();
    solReview.validate();

    final stateIds = matrix.states.map((state) => state.id).toSet();
    if (!stateIds.containsAll(requiredStateFixtureIds)) {
      throw StateError('B04-02 packet references a missing state fixture.');
    }
    final arithmeticIds = {
      ...matrix.ranges.map((range) => range.id),
      ...matrix.trends.map((trend) => trend.id),
      ...matrix.maintenance.map((fixture) => fixture.id),
    };
    if (!arithmeticIds.containsAll(requiredArithmeticFixtureIds)) {
      throw StateError('B04-02 packet references missing arithmetic fixtures.');
    }
  }
}

String _gateString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

int _gateInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

bool _gateBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean.');
  return value;
}

List<String> _gateStrings(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String || item.isEmpty)) {
    throw FormatException('$key must contain strings.');
  }
  return List.unmodifiable(value.cast<String>());
}

Map<String, dynamic> _gateMap(dynamic value, String key) {
  if (value is! Map) throw FormatException('$key must be an object.');
  return Map<String, dynamic>.from(value);
}

List<T> _gateObjects<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! Map)) {
    throw FormatException('$key must contain objects.');
  }
  return List.unmodifiable(
    value.map((item) => parse(Map<String, dynamic>.from(item as Map))),
  );
}

B04FixtureOutcome _gateOutcome(dynamic value) {
  if (value is! String) {
    throw const FormatException('Outcome must be a string.');
  }
  return B04FixtureOutcome.values.byName(value);
}

bool _sameStrings(Iterable<String> actual, Iterable<String> expected) {
  final actualList = actual.toList();
  final expectedList = expected.toList();
  final actualSet = actualList.toSet();
  final expectedSet = expectedList.toSet();
  return actualList.length == expectedList.length &&
      actualSet.length == actualList.length &&
      actualSet.length == expectedSet.length &&
      actualSet.containsAll(expectedSet);
}

bool _sameOrderedStrings(Iterable<String> actual, Iterable<String> expected) {
  final actualList = actual.toList();
  final expectedList = expected.toList();
  if (actualList.length != expectedList.length) return false;
  for (var index = 0; index < actualList.length; index++) {
    if (actualList[index] != expectedList[index]) return false;
  }
  return true;
}
