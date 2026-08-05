import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';

void main() {
  group('B04-01 contract and fixture matrix', () {
    test('matrix is versioned, complete and self-validating', () {
      final matrix = B04AdaptiveCoachingFixtureMatrix.current;

      matrix.validate();

      expect(matrix.version, kB04AdaptiveCoachingFixtureContractVersion);
      expect(matrix.enabledPolicy.policyVersion, kB04EnabledPolicyVersion);
      expect(matrix.outcomes, hasLength(7));
      expect(matrix.decisions, hasLength(20));
      expect(matrix.negativeFixtures, hasLength(20));
      expect(matrix.enabledEdges, hasLength(47));
      expect(matrix.states, isNotEmpty);
      expect(matrix.ranges, hasLength(10));
      expect(matrix.trends, hasLength(3));
      expect(matrix.maintenance, hasLength(3));
      expect(matrix.durableAuthorities, hasLength(2));
    });

    test('contract serialization round-trips without losing traceability', () {
      final matrix = B04AdaptiveCoachingFixtureMatrix.current;
      final encoded = jsonEncode(matrix.toJson());
      final decoded = B04AdaptiveCoachingFixtureMatrix.fromJson(
        jsonDecode(encoded),
      );

      expect(decoded.toJson(), equals(matrix.toJson()));
      expect(
        decoded.decisions.map((decision) => decision.id).toSet(),
        equals(b04D04DecisionIds.toSet()),
      );
      expect(
        decoded.enabledEdges.map((edge) => edge.id).toSet(),
        equals(b04EnabledEdgeIds.toSet()),
      );
    });

    test(
      'unsupported versions and dangling fixture references fail closed',
      () {
        final json = B04AdaptiveCoachingFixtureMatrix.current.toJson();
        json['version'] = 99;
        expect(
          () => B04AdaptiveCoachingFixtureMatrix.fromJson(json),
          throwsA(isA<FormatException>()),
        );

        final invalid = B04AdaptiveCoachingFixtureMatrix.current.toJson();
        final outcomes = List<Map<String, dynamic>>.from(
          (invalid['outcomes'] as List).map(
            (item) => Map<String, dynamic>.from(item as Map),
          ),
        );
        outcomes.first['fixture_ids'] = ['missing-fixture'];
        invalid['outcomes'] = outcomes;
        expect(
          () => B04AdaptiveCoachingFixtureMatrix.fromJson(invalid),
          throwsA(isA<StateError>()),
        );

        final invalidPolicy = B04AdaptiveCoachingFixtureMatrix.current.toJson();
        final policy = Map<String, dynamic>.from(
          invalidPolicy['enabled_policy'] as Map,
        );
        policy['proposal_step_kcal'] = 50;
        invalidPolicy['enabled_policy'] = policy;
        expect(
          () => B04AdaptiveCoachingFixtureMatrix.fromJson(invalidPolicy),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('every outcome has an owner and downstream fixture set', () {
      final matrix = B04AdaptiveCoachingFixtureMatrix.current;
      final fixtureIds = {
        ...matrix.enabledEdges.map((edge) => edge.id),
        ...matrix.states.map((state) => state.id),
      };

      for (final outcome in matrix.outcomes) {
        expect(outcome.owner, isNotEmpty);
        expect(outcome.description, isNotEmpty);
        expect(fixtureIds, containsAll(outcome.fixtureIds));
        expect(outcome.downstreamTasks, isNotEmpty);
      }

      final r01 = matrix.outcomes.singleWhere(
        (outcome) => outcome.id == 'B04-R01',
      );
      expect(
        r01.downstreamTasks,
        equals(['B04-02', 'B04-05', 'B04-07', 'B04-15']),
      );
    });

    test(
      'D04-01 through D04-20 retain required fields and negative fixtures',
      () {
        final matrix = B04AdaptiveCoachingFixtureMatrix.current;
        final negatives = {
          for (final fixture in matrix.negativeFixtures) fixture.id: fixture,
        };
        for (final decision in matrix.decisions) {
          expect(decision.selectedOption, isNotEmpty);
          expect(decision.unit, isNotEmpty);
          expect(decision.effectivePeriod, isNotEmpty);
          expect(decision.boundaryRule, isNotEmpty);
          expect(decision.missingDataRule, isNotEmpty);
          expect(decision.policyVersion, isNotEmpty);
          expect(decision.overrideRule, isNotEmpty);
          expect(decision.negativeFixtureId, isNotEmpty);
          expect(decision.affectedTasks, isNotEmpty);
          expect(decision.blocking, isTrue);
          final negative = negatives[decision.negativeFixtureId];
          expect(negative, isNotNull);
          expect(negative!.decisionId, decision.id);
          expect(negative.id, 'd04-${decision.id.substring(8)}-negative');
          expect(negative.scenario, isNotEmpty);
          expect(
            negative.expectedOutcome,
            isIn([
              B04FixtureOutcome.unavailable,
              B04FixtureOutcome.invalidEvidence,
            ]),
          );
          expect(negative.adaptiveDeltaKcal, 0);
          expect(negative.targetUnchanged, isTrue);
          expect(negative.historyUnchanged, isTrue);
        }
      },
    );

    test(
      'ENABLED-1 contract exposes exact policy values and blocking gates',
      () {
        final policy = B04AdaptiveCoachingFixtureMatrix.current.enabledPolicy;

        policy.validate();
        expect(policy.minimumAgeYears, 18);
        expect(policy.evaluationWindowDays, 21);
        expect(policy.minimumValidWeightDays, 10);
        expect(policy.minimumWeightSpanDays, 14);
        expect(policy.minimumFirstBlockWeightDays, 3);
        expect(policy.minimumFinalBlockWeightDays, 3);
        expect(policy.latestWeightFreshnessDays, 4);
        expect(policy.minimumNutritionValidDays, 14);
        expect(policy.nutritionCompletenessPercent, '80');
        expect(policy.nutritionMaximumRangePercent, '20');
        expect(policy.maintenanceFreshnessDays, 30);
        expect(policy.maintenanceMaximumRangePercent, '15');
        expect(policy.proposalStepKcal, 100);
        expect(policy.proposalCadenceDays, 21);
        expect(policy.proposalExpiryDays, 7);
        expect(policy.aggregateWindowDays, 42);
        expect(policy.aggregateMinimumKcal, -200);
        expect(policy.aggregateMaximumKcal, 200);
        expect(policy.lossMaximumDeficitKcal, 500);
        expect(policy.lossMaximumDeficitPercent, '20');
        expect(policy.lossMinimumFloorKcal, 1200);
        expect(policy.lossMinimumFloorPercent, '80');
        expect(policy.gainMaximumSurplusKcal, 300);
        expect(policy.gainMaximumSurplusPercent, '15');
        expect(
          policy.supportedGoalRates,
          equals([
            'loss:-0.25% body weight/week',
            'loss:-0.50% body weight/week',
            'maintenance:0.00% body weight/week',
            'gain:+0.10% body weight/week',
            'gain:+0.25% body weight/week',
          ]),
        );
        expect(
          policy.defaultGoalRates,
          equals({
            'loss': '-0.50% body weight/week',
            'maintenance': '0.00% body weight/week',
            'gain': '+0.25% body weight/week',
          }),
        );
        expect(policy.lossGainDeadbandPercent, '0.15');
        expect(policy.maintenanceDeadbandPercent, '0.25');
        expect(policy.lossRapidChangePercent, '-1.00');
        expect(policy.gainRapidChangePercent, '+0.50');
        expect(policy.blockingActivationGates, hasLength(4));
        expect(policy.unitRule, contains('finite'));
        expect(policy.missingDataRule, contains('never zero'));
        expect(policy.overrideRule, contains('cannot bypass'));
      },
    );
  });

  group('B04-01 negative state and ownership fixtures', () {
    test(
      'HOLD-1 is unavailable, zero-delta and preserves user-set targets',
      () {
        final hold = B04AdaptiveCoachingFixtureMatrix.current.states
            .singleWhere((state) => state.id == 'hold-unavailable-zero-delta');

        expect(hold.policyVersion, kB04HoldPolicyVersion);
        expect(hold.expectedOutcome, B04FixtureOutcome.unavailable);
        expect(hold.adaptiveDeltaKcal, 0);
        expect(hold.userSetTargetPreserved, isTrue);
      },
    );

    test(
      'missing, dangling-lineage and dietary uncertainty stay unavailable',
      () {
        final states = B04AdaptiveCoachingFixtureMatrix.current.states;
        for (final id in [
          'missing-required-evidence',
          'dangling-lineage',
          'dietary-possible-unavailable',
          'dietary-unknown-unavailable',
          'dietary-insufficient-unavailable',
        ]) {
          expect(
            states.singleWhere((state) => state.id == id).expectedOutcome,
            isIn([
              B04FixtureOutcome.unavailable,
              B04FixtureOutcome.invalidEvidence,
            ]),
          );
        }
      },
    );

    test(
      'B03 and B01/B02 authorities are reused without duplicate calculators',
      () {
        final authorities =
            B04AdaptiveCoachingFixtureMatrix.current.authorities;

        expect(
          authorities.map((authority) => authority.authority),
          containsAll([
            'NutritionReadModelRepository',
            'NutritionConstraintRepository',
            'NutritionEstimateRepository',
            'LocalScheduleDateService',
          ]),
        );
        expect(
          authorities.every((authority) => !authority.duplicateCreated),
          isTrue,
        );
      },
    );

    test('consent and eligibility are append-only durable authorities', () {
      for (final authority
          in B04AdaptiveCoachingFixtureMatrix.current.durableAuthorities) {
        expect(authority.lineage, B04LineageKind.appendOnly);
        expect(authority.requiredFields, isNotEmpty);
        expect(authority.rejectedRestoreCases, contains('duplicate_id'));
        expect(
          authority.rejectedRestoreCases,
          contains('unsupported_policy_version'),
        );
        expect(authority.indexes, isNotEmpty);
        expect(authority.foreignKeys, isNotEmpty);
        expect(authority.correctionRule, contains('future'));
      }

      final consent = B04AdaptiveCoachingFixtureMatrix
          .current
          .durableAuthorities
          .singleWhere(
            (authority) => authority.name == 'coaching_consent_events',
          );
      expect(
        consent.requiredFields,
        containsAll(['related_or_superseded_event_id', 'created_at_utc']),
      );
      expect(consent.indexes, contains('unique(portable_event_id)'));
      expect(consent.foreignKeys, contains('user_id -> users.id'));

      final eligibility = B04AdaptiveCoachingFixtureMatrix
          .current
          .durableAuthorities
          .singleWhere(
            (authority) => authority.name == 'coaching_eligibility_evaluations',
          );
      expect(
        eligibility.requiredFields,
        containsAll([
          'minimum_age_rule_version',
          'goal_reference',
          'recommendation_or_attempt_reference',
          'evidence_fingerprint',
        ]),
      );
      expect(eligibility.indexes, contains('unique(portable_evaluation_id)'));
      expect(eligibility.foreignKeys, contains('user_id -> users.id'));
    });
  });

  group('B04-01 ENABLED-1 exact arithmetic fixtures', () {
    test('E13 and E16 use exact range width and midpoint arithmetic', () {
      final ranges = B04AdaptiveCoachingFixtureMatrix.current.ranges;
      final nutritionPass = ranges.singleWhere(
        (range) => range.id == 'E13-range-1800-2200',
      );
      final nutritionFail = ranges.singleWhere(
        (range) => range.id == 'E13-range-1799-2201',
      );
      final maintenancePass = ranges.singleWhere(
        (range) => range.id == 'E16-range-1850-2150',
      );
      final maintenanceFail = ranges.singleWhere(
        (range) => range.id == 'E16-range-1849-2151',
      );

      expect(nutritionPass.width, B04Rational.fromInt(400));
      expect(nutritionPass.midpoint, B04Rational.fromInt(2000));
      expect(nutritionPass.relativeWidthPercent, B04Rational.fromInt(20));
      expect(nutritionPass.expectedOutcome, B04FixtureOutcome.onTrack);
      expect(nutritionFail.relativeWidthPercent, B04Rational.fromInts(201, 10));
      expect(nutritionFail.expectedOutcome, B04FixtureOutcome.unavailable);
      expect(maintenancePass.relativeWidthPercent, B04Rational.fromInt(15));
      expect(
        maintenanceFail.relativeWidthPercent,
        B04Rational.fromInts(151, 10),
      );
    });

    test('E41 rejects invalid ranges and finite/unit/domain violations', () {
      final ranges = B04AdaptiveCoachingFixtureMatrix.current.ranges;

      expect(
        ranges
            .singleWhere((range) => range.id == 'E41-range-zero-midpoint')
            .midpoint,
        isNull,
      );
      expect(
        ranges.singleWhere((range) => range.id == 'E41-range-reversed').width,
        isNull,
      );
      final positivePoint = ranges.singleWhere(
        (range) => range.id == 'E41-range-positive-point',
      );
      expect(positivePoint.width, B04Rational.fromInt(0));
      expect(positivePoint.midpoint, B04Rational.fromInt(2000));
      expect(positivePoint.relativeWidthPercent, B04Rational.fromInt(0));
      expect(positivePoint.expectedOutcome, B04FixtureOutcome.available);
      expect(
        ranges
            .singleWhere((range) => range.id == 'E41-range-negative-bound')
            .midpoint,
        isNull,
      );
      expect(
        ranges.singleWhere((range) => range.id == 'E41-range-non-finite').width,
        isNull,
      );
      final mismatchedUnits = ranges.singleWhere(
        (range) => range.id == 'E41-range-mismatched-units',
      );
      expect(mismatchedUnits.lowerUnit, 'kcal/day');
      expect(mismatchedUnits.upperUnit, 'grams');
      expect(mismatchedUnits.width, isNull);
      expect(
        B04RangeFixture(
          id: 'non-finite',
          lower: 'NaN',
          upper: '2000',
          unit: 'kcal/day',
          expectedOutcome: B04FixtureOutcome.invalidEvidence,
          expectedReason: 'unavailable_invalid_range',
        ).relativeWidthPercent,
        isNull,
      );
    });

    test(
      'E42 normalizes maintenance once and preserves floor/ceil arithmetic',
      () {
        final fixtures = B04AdaptiveCoachingFixtureMatrix.current.maintenance;

        expect(b04NormalizedMaintenance('2000'), 2000);
        expect(b04NormalizedMaintenance('2000.5'), 2001);
        expect(b04NormalizedMaintenance('1800.5'), 1801);
        expect(
          fixtures.map(
            (fixture) => [
              fixture.normalizedM,
              fixture.deficitCap,
              fixture.targetFloor,
              fixture.surplusCap,
              fixture.targetCeiling,
            ],
          ),
          equals([
            [2000, 400, 1600, 300, 2300],
            [2001, 400, 1601, 300, 2301],
            [1801, 360, 1441, 270, 2071],
          ]),
        );
        expect(b04BasisPoints('0.10'), B04Rational.fromInt(10));
        expect(b04BasisPoints('0.15'), B04Rational.fromInt(15));
        expect(
          (B04Rational.fromInt(2001) * B04Rational.fromInts(20, 100))
              .floorInteger()
              .toInt(),
          400,
        );
        expect(
          (B04Rational.fromInt(2001) * B04Rational.fromInts(80, 100))
              .ceilInteger()
              .toInt(),
          1601,
        );
      },
    );

    test('E43 and E44 retain odd/even exact medians and Theil-Sen slopes', () {
      for (final trend in B04AdaptiveCoachingFixtureMatrix.current.trends) {
        final median = b04Median(
          trend.weights.map((weight) => B04Rational.fromInt(weight.grams)),
        );
        final slope = b04TheilSenSlope(trend.weights);
        final weekly = b04WeeklyRatePercent(
          slopeGramsPerDay: slope,
          medianWindowWeightGrams: median,
        );

        expect(median, trend.expectedMedianGrams, reason: trend.id);
        expect(slope, trend.expectedSlopeGramsPerDay, reason: trend.id);
        expect(weekly, trend.expectedWeeklyRatePercent, reason: trend.id);
        expect(trend.policyVersion, kB04EnabledPolicyVersion);
        expect(trend.algorithmVersion, kB04TrendAlgorithmVersion);
        expect(trend.unit, contains('grams'));
        expect(trend.timezone, contains('IANA'));
        expect(trend.effectivePeriod, contains('local civil'));
      }
    });

    test('E46 rounds display values only, away from zero at halfway ties', () {
      expect(b04DisplayPercent(B04Rational.parse('0.125')), '0.13');
      expect(b04DisplayPercent(B04Rational.parse('-0.125')), '-0.13');
      expect(b04DisplayPercent(B04Rational.parse('0.1249')), '0.12');
      expect(b04DisplayPercent(B04Rational.parse('-0.1249')), '-0.12');
    });

    test('E45 compares exact boundaries before display rounding', () {
      final edge = B04AdaptiveCoachingFixtureMatrix.current.enabledEdges
          .singleWhere((item) => item.id == 'E45');
      final lower = B04Rational.parse(edge.exactValues['loss_lower_edge']!);
      final upper = B04Rational.parse(edge.exactValues['loss_upper_edge']!);
      final rapidExact = B04Rational.parse(
        edge.exactValues['rapid_exact_edge']!,
      );
      final rapidOutside = B04Rational.parse(
        edge.exactValues['rapid_outside']!,
      );

      expect(lower, lessThan(B04Rational.parse('-0.35')));
      expect(upper, greaterThan(B04Rational.parse('-0.65')));
      expect(rapidExact, equals(B04Rational.fromInts(-100, 100)));
      expect(rapidOutside, lessThan(rapidExact));
      expect(b04DisplayPercent(rapidOutside), '-1.00');
    });

    test(
      'E47 counts only accepted engine deltas and checks the prospective step',
      () {
        const events = [
          B04AggregateEventFixture(
            localDay: 10,
            deltaKcal: 100,
            engineAuthored: true,
            accepted: true,
          ),
          B04AggregateEventFixture(
            localDay: 20,
            deltaKcal: -100,
            engineAuthored: true,
            accepted: true,
          ),
          B04AggregateEventFixture(
            localDay: 21,
            deltaKcal: 100,
            engineAuthored: false,
            accepted: true,
          ),
          B04AggregateEventFixture(
            localDay: 0,
            deltaKcal: 100,
            engineAuthored: true,
            accepted: true,
          ),
        ];

        final aggregate = b04AcceptedEngineAggregate(
          events: events,
          evaluationDay: 42,
          prospectiveDeltaKcal: 100,
        );
        expect(aggregate, 100);
        expect(b04AggregateWithinBounds(aggregate), isTrue);
        expect(
          b04AggregateWithinBounds(
            b04AcceptedEngineAggregate(
              events: [
                ...events,
                const B04AggregateEventFixture(
                  localDay: 30,
                  deltaKcal: 100,
                  engineAuthored: true,
                  accepted: true,
                ),
                const B04AggregateEventFixture(
                  localDay: 31,
                  deltaKcal: 100,
                  engineAuthored: true,
                  accepted: true,
                ),
              ],
              evaluationDay: 42,
              prospectiveDeltaKcal: 100,
            ),
          ),
          isFalse,
        );
      },
    );

    test(
      'all enabled edges carry exact policy metadata and required boundaries',
      () {
        final edges = B04AdaptiveCoachingFixtureMatrix.current.enabledEdges;
        expect(
          edges.map((edge) => edge.id).toSet(),
          equals(b04EnabledEdgeIds.toSet()),
        );
        for (final edge in edges) {
          expect(edge.unit, isNotEmpty, reason: edge.id);
          expect(edge.period, isNotEmpty, reason: edge.id);
          expect(edge.timezone, contains('IANA'), reason: edge.id);
          expect(
            edge.missingDataResult,
            contains('unavailable'),
            reason: edge.id,
          );
          expect(edge.overrideRule, contains('cannot bypass'), reason: edge.id);
        }
        expect(
          edges.singleWhere((edge) => edge.id == 'E20').expectedResult,
          contains('100'),
        );
        expect(
          edges.singleWhere((edge) => edge.id == 'E26').expectedResult,
          contains('no smaller clamp'),
        );
        expect(
          edges.singleWhere((edge) => edge.id == 'E47').scenario,
          contains('prospective aggregate'),
        );
        expect(
          edges.singleWhere((edge) => edge.id == 'E01').kind,
          B04FixtureCaseKind.negative,
        );
        expect(
          edges.singleWhere((edge) => edge.id == 'E13').kind,
          B04FixtureCaseKind.boundary,
        );
        expect(
          edges.singleWhere((edge) => edge.id == 'E20').kind,
          B04FixtureCaseKind.positive,
        );
        expect(
          edges.singleWhere((edge) => edge.id == 'E01').policyVersions,
          containsAll([kB04EnabledPolicyVersion, kB04HoldPolicyVersion]),
        );
        expect(
          edges.singleWhere((edge) => edge.id == 'E32').policyVersions,
          containsAll([
            kB04ReadinessHoldPolicyVersion,
            kB04EnabledPolicyVersion,
          ]),
        );
        expect(
          edges.singleWhere((edge) => edge.id == 'E37').policyVersions,
          containsAll([kB04EnabledPolicyVersion, kB04HoldPolicyVersion]),
        );
        for (final edge in edges) {
          expect(edge.policyVersions, isNotEmpty, reason: edge.id);
          expect(
            edge.policyVersions,
            everyElement(
              isIn([
                kB04EnabledPolicyVersion,
                kB04HoldPolicyVersion,
                kB04ReadinessHoldPolicyVersion,
              ]),
            ),
            reason: edge.id,
          );
        }
      },
    );
  });

  group('B04-01 state transition and replay fixtures', () {
    test(
      'acceptance is effective-dated while dismiss and expiry do not mutate targets',
      () {
        final states = B04AdaptiveCoachingFixtureMatrix.current.states;
        final accepted = states.singleWhere(
          (state) => state.id == 'feedback-accept-append-only',
        );
        final dismissed = states.singleWhere(
          (state) => state.id == 'feedback-dismiss-no-mutation',
        );

        expect(accepted.lineage, B04LineageKind.effectiveDated);
        expect(accepted.adaptiveDeltaKcal.abs(), 100);
        expect(dismissed.lineage, B04LineageKind.appendOnly);
        expect(dismissed.adaptiveDeltaKcal, 0);
        expect(dismissed.userSetTargetPreserved, isTrue);
      },
    );

    test(
      'readiness and AI cannot change deterministic numerical authority',
      () {
        final states = B04AdaptiveCoachingFixtureMatrix.current.states;
        final readiness = states.singleWhere(
          (state) => state.id == 'readiness-hold-zero-effect',
        );
        final ai = B04AdaptiveCoachingFixtureMatrix.current.enabledEdges
            .singleWhere((edge) => edge.id == 'E33');

        expect(readiness.adaptiveDeltaKcal, 0);
        expect(ai.expectedResult, contains('authoritative'));
        expect(ai.overrideRule, contains('cannot bypass'));
      },
    );

    test(
      'policy-version replay is future-only and never cross-recomputes history',
      () {
        final replay = B04AdaptiveCoachingFixtureMatrix.current.states
            .singleWhere((state) => state.id == 'future-only-enabled-replay');
        final edge = B04AdaptiveCoachingFixtureMatrix.current.enabledEdges
            .singleWhere((item) => item.id == 'E37');

        expect(replay.policyVersion, kB04EnabledPolicyVersion);
        expect(replay.lineage, B04LineageKind.effectiveDated);
        expect(edge.expectedResult, contains('stored policy version'));
        expect(edge.period, contains('policy'));
      },
    );

    test(
      'unknown, range, provenance, timezone and feedback states are typed',
      () {
        final states = B04AdaptiveCoachingFixtureMatrix.current.states;
        final byId = {for (final state in states) state.id: state};

        expect(byId['unknown-nutrition-preserved']!.state, 'unknown');
        expect(
          byId['unknown-nutrition-preserved']!.expectedOutcome,
          B04FixtureOutcome.unavailable,
        );
        expect(
          byId['range-crosses-decision-boundary']!.state,
          'uncertain_range',
        );
        expect(
          byId['range-crosses-decision-boundary']!.expectedOutcome,
          B04FixtureOutcome.unavailable,
        );
        expect(
          byId['missing-provenance-unavailable']!.expectedOutcome,
          B04FixtureOutcome.invalidEvidence,
        );
        expect(
          byId['timezone-dst-local-date-frozen']!.inputCondition,
          contains('DST'),
        );
        for (final id in [
          'feedback-acknowledge-append-only',
          'feedback-override-user-set',
          'feedback-snooze-presentation-only',
        ]) {
          expect(byId[id]!.adaptiveDeltaKcal, 0);
          expect(byId[id]!.userSetTargetPreserved, isTrue);
        }
        expect(
          byId['feedback-override-user-set']!.lineage,
          B04LineageKind.effectiveDated,
        );
      },
    );
  });
}
