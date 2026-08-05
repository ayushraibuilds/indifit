import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'package:indifit/core/fixtures/b04_policy_gate_fixture.dart';

void main() {
  group('B04-02 product and safety policy gate packet', () {
    test('packet is complete, inactive and self-validating', () {
      final packet = B04PolicyGateFixturePacket.current;

      packet.validate();

      expect(packet.version, kB04PolicyGateFixtureVersion);
      expect(
        packet.sourceContractVersion,
        kB04AdaptiveCoachingFixtureContractVersion,
      );
      expect(packet.enabledPolicyVersion, kB04EnabledPolicyVersion);
      expect(packet.holdPolicyVersion, kB04HoldPolicyVersion);
      expect(packet.readinessHoldPolicyVersion, kB04ReadinessHoldPolicyVersion);
      expect(packet.currentPolicyVersion, kB04HoldPolicyVersion);
      expect(packet.enabledPolicyActive, isFalse);
      expect(packet.activationEffectiveDateAssigned, isFalse);
      expect(packet.decisionIds, hasLength(20));
      expect(packet.activationGates, hasLength(4));
      expect(packet.safetyWording, hasLength(10));
      expect(
        packet.requiredStateFixtureIds,
        contains('feedback-accept-append-only'),
      );
    });

    test(
      'consent, withdrawal and target acceptance boundaries are explicit',
      () {
        final packet = B04PolicyGateFixturePacket.current;
        final consent = packet.consentAndAcceptance;

        consent.validate();
        expect(consent.adaptiveCoachingDefaultOff, isTrue);
        expect(consent.explicitAdaptiveConsentRequired, isTrue);
        expect(consent.aiConsentSeparate, isTrue);
        expect(consent.implicitLoggingOrInactivityConsent, isFalse);
        expect(consent.withdrawalStopsFutureProposals, isTrue);
        expect(consent.historyPreservedAfterWithdrawal, isTrue);
        expect(consent.proposalAcceptanceRequired, isTrue);
        expect(consent.proposalAcceptanceIdempotent, isTrue);
        expect(
          consent.acceptedChangeCreatesEffectiveDatedTargetVersion,
          isTrue,
        );
        expect(consent.rejectionDismissalExpiryLeaveTargetUnchanged, isTrue);
        expect(consent.backgroundActivationAllowed, isFalse);
        expect(consent.offlineConsentRemainsDeterministic, isTrue);

        final matrix = B04AdaptiveCoachingFixtureMatrix.current;
        final consentAuthority = matrix.durableAuthorities.singleWhere(
          (authority) => authority.name == 'coaching_consent_events',
        );
        expect(
          consentAuthority.requiredFields,
          containsAll(['consent_category', 'action']),
        );
        final implicitConsent = matrix.negativeFixtures.singleWhere(
          (fixture) => fixture.decisionId == 'B04-D04-04',
        );
        expect(implicitConsent.scenario, contains('implicit bundled consent'));
        final accepted = matrix.states.singleWhere(
          (state) => state.id == 'feedback-accept-append-only',
        );
        expect(accepted.inputCondition, contains('explicit acceptance'));
        expect(
          matrix.decisions
              .singleWhere((decision) => decision.id == 'B04-D04-19')
              .selectedOption,
          contains('explicit acceptance'),
        );
      },
    );

    test(
      'packet serialization round-trips without duplicating policy data',
      () {
        final packet = B04PolicyGateFixturePacket.current;
        final decoded = B04PolicyGateFixturePacket.fromJson(
          jsonDecode(jsonEncode(packet.toJson())),
        );

        expect(decoded.toJson(), equals(packet.toJson()));
        expect(
          decoded.enabledPolicyVersion,
          B04AdaptiveCoachingFixtureMatrix.current.enabledPolicy.policyVersion,
        );
        expect(
          decoded.requiredEdgeIds,
          equals(
            B04AdaptiveCoachingFixtureMatrix.current.enabledEdges
                .map((edge) => edge.id)
                .toList(),
          ),
        );
      },
    );

    test('HOLD-1 remains current with exact zero deltas and no bypass', () {
      final hold = B04PolicyGateFixturePacket.current.holdPolicy;

      hold.validate();
      expect(hold.expectedOutcome, B04FixtureOutcome.unavailable);
      expect(hold.upwardDeltaKcal, 0);
      expect(hold.downwardDeltaKcal, 0);
      expect(hold.aggregateDeltaKcal, 0);
      expect(hold.proposalAcceptanceAllowed, isFalse);
      expect(hold.userSetTargetPreserved, isTrue);
      expect(hold.userOverrideBypasses, isFalse);
      expect(hold.aiBypasses, isFalse);
      expect(hold.currentByDefault, isTrue);
    });

    test(
      'READINESS-HOLD-1 keeps every readiness numerical effect exactly zero',
      () {
        final readiness = B04PolicyGateFixturePacket.current.readinessHold;

        readiness.validate();
        expect(readiness.descriptiveCoachingAllowed, isTrue);
        expect(readiness.numericalProposalAllowed, isFalse);
        expect(readiness.calorieDeltaKcal, 0);
        expect(readiness.trainingLoadDeltaPercent, B04Rational.fromInt(0));
        expect(readiness.trainingIntensityDeltaPercent, B04Rational.fromInt(0));
        expect(readiness.scheduleDurationDelta, 0);
        expect(
          readiness.states.map((state) => state.inputState).toSet(),
          containsAll([
            'complete',
            'missing',
            'denied',
            'stale',
            'conflicting',
          ]),
        );
        for (final state in readiness.states) {
          expect(state.calorieDeltaKcal, 0, reason: state.id);
          expect(
            state.trainingLoadDeltaPercent,
            B04Rational.fromInt(0),
            reason: state.id,
          );
          expect(
            state.trainingIntensityDeltaPercent,
            B04Rational.fromInt(0),
            reason: state.id,
          );
          expect(state.scheduleDurationDelta, 0, reason: state.id);
        }
      },
    );

    test(
      'activation gates are blocking and fresh Sol review remains pending',
      () {
        final packet = B04PolicyGateFixturePacket.current;

        for (final gate in packet.activationGates) {
          expect(gate.blocking, isTrue, reason: gate.id);
          expect(gate.activationRequired, isTrue, reason: gate.id);
          expect(gate.satisfied, isFalse, reason: gate.id);
        }
        expect(packet.solReview.reviewerRole, 'Sol High');
        expect(packet.solReview.status, kB04PendingSolReviewStatus);
        expect(packet.solReview.freshIndependentReviewRequired, isTrue);
        expect(packet.solReview.activationEligible, isFalse);
        expect(
          packet.solReview.acceptedVerdicts,
          containsAll(['approved', 'approved_with_non_blocking_follow_up']),
        );
      },
    );

    test('safety wording preserves non-medical and unavailable boundaries', () {
      final wording = B04PolicyGateFixturePacket.current.safetyWording;

      for (final item in wording) {
        item.validate();
        expect(item.targetMutationAllowed, isFalse, reason: item.id);
        expect(item.aiMayAlterNumericalMeaning, isFalse, reason: item.id);
      }

      final hardBlock = wording.singleWhere(
        (item) => item.semanticState == 'dietary_hard_block',
      );
      expect(hardBlock.hardBlock, isTrue);
      expect(hardBlock.recommendationAllowed, isFalse);

      final uncertain = wording.singleWhere(
        (item) => item.semanticState == 'dietary_evidence_unavailable',
      );
      expect(uncertain.recommendationAllowed, isFalse);
      expect(uncertain.lowRiskLoggingOnly, isTrue);

      final noKnown = wording.singleWhere(
        (item) => item.semanticState == 'no_known_conflict',
      );
      expect(noKnown.recommendationAllowed, isTrue);
      expect(noKnown.prohibitedClaims, contains('safety guarantee'));
    });

    test('offline, AI, N8 and legacy boundaries remain explicit', () {
      final packet = B04PolicyGateFixturePacket.current;

      packet.offlineAiBoundary.validate();
      expect(packet.offlineAiBoundary.deterministicLocalResultAllowed, isTrue);
      expect(
        packet.offlineAiBoundary.missingRequiredEvidenceUnavailable,
        isTrue,
      );
      expect(packet.offlineAiBoundary.separateAiConsentRequired, isTrue);
      expect(packet.offlineAiBoundary.redactedEnvelopeOnly, isTrue);
      expect(packet.offlineAiBoundary.rawPromptPersisted, isFalse);
      expect(packet.offlineAiBoundary.rawResponsePersisted, isFalse);

      packet.n8Boundary.validate();
      expect(packet.n8Boundary.inferenceAllowed, isFalse);
      expect(packet.n8Boundary.currentPersistenceAllowed, isFalse);
      expect(packet.n8Boundary.targetChangesAllowed, isFalse);

      packet.legacyPolicyIsolation.validate();
      expect(packet.legacyPolicyIsolation.authoritativeForB04, isFalse);
      expect(
        packet.legacyPolicyIsolation.legacyValues,
        containsAll(['-500 kcal/day', '+300 kcal/day', '1200 kcal/day']),
      );
    });

    test('tampered gate data fails closed', () {
      final invalid = B04PolicyGateFixturePacket.current.toJson();
      invalid['enabled_policy_active'] = true;
      expect(
        () => B04PolicyGateFixturePacket.fromJson(invalid),
        throwsA(isA<StateError>()),
      );

      final invalidHold = B04PolicyGateFixturePacket.current.toJson();
      final hold = Map<String, dynamic>.from(invalidHold['hold_policy'] as Map);
      hold['upward_delta_kcal'] = 100;
      invalidHold['hold_policy'] = hold;
      expect(
        () => B04PolicyGateFixturePacket.fromJson(invalidHold),
        throwsA(isA<StateError>()),
      );

      final invalidSol = B04PolicyGateFixturePacket.current.toJson();
      final sol = Map<String, dynamic>.from(invalidSol['sol_review'] as Map);
      sol['status'] = 'approved';
      invalidSol['sol_review'] = sol;
      expect(
        () => B04PolicyGateFixturePacket.fromJson(invalidSol),
        throwsA(isA<StateError>()),
      );
    });
  });
}
