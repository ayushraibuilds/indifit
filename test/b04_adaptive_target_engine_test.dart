import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/models/b04_adaptive_target_models.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/models/b04_recovery_models.dart';
import 'package:indifit/data/services/b04_adaptive_target_engine.dart';

void main() {
  late B04AdaptiveTargetEngine engine;

  setUp(() {
    engine = B04AdaptiveTargetEngine();
  });

  group('HOLD-1 and activation', () {
    test('default HOLD emits no proposal and exactly zero delta', () {
      final result = engine.evaluate(_request(slopeGramsPerDay: -20));

      expect(result.status, B04AdaptiveTargetStatus.unavailable);
      expect(result.reasonCode, 'adaptive_policy_hold');
      expect(result.policyVersion, kB04HoldPolicyVersion);
      expect(result.adaptiveDeltaKcal, 0);
      expect(result.proposedTargetKcal, isNull);
      expect(result.proposal, isNull);
      expect(result.currentTargetKcal, 1800);
    });

    test('product approval alone cannot activate ENABLED-1', () {
      final result = engine.evaluate(
        _request(
          activation: const B04ActivationMetadata(
            policyVersion: kB04EnabledPolicyVersion,
            productOwnerApproved: true,
          ),
        ),
      );

      expect(result.policyVersion, kB04HoldPolicyVersion);
      expect(result.reasonCode, 'adaptive_policy_hold');
      expect(result.adaptiveDeltaKcal, 0);
    });

    test(
      'future activation remains inactive until its local effective date',
      () {
        final result = engine.evaluate(
          _request(activation: _enabled(effectiveFrom: '2026-03-01')),
        );

        expect(result.status, B04AdaptiveTargetStatus.inactive);
        expect(result.policyVersion, kB04EnabledPolicyVersion);
        expect(result.adaptiveDeltaKcal, 0);
      },
    );

    test(
      'background, user override and AI suggestions cannot bypass the gate',
      () {
        final hold = engine.evaluate(
          _request(
            explicitlyInitiated: false,
            userOverrideRequested: true,
            aiSuggestedDeltaKcal: 500,
          ),
        );
        final enabled = engine.evaluate(
          _request(
            activation: _enabled(),
            explicitlyInitiated: false,
            adaptiveConsentEnabled: true,
            userOverrideRequested: true,
            aiSuggestedDeltaKcal: 500,
          ),
        );

        expect(hold.adaptiveDeltaKcal, 0);
        expect(hold.proposal, isNull);
        expect(enabled.reasonCode, 'explicit_evaluation_required');
        expect(enabled.adaptiveDeltaKcal, 0);
        expect(enabled.proposal, isNull);
      },
    );

    test(
      'fixture contract and production policy retain the accepted values',
      () {
        final fixture = B04AdaptiveCoachingFixtureMatrix.current;
        fixture.validate();

        expect(
          engine.policy.policyVersion,
          fixture.enabledPolicy.policyVersion,
        );
        expect(
          engine.policy.evaluationWindowDays,
          fixture.enabledPolicy.evaluationWindowDays,
        );
        expect(
          engine.policy.minimumValidWeightDays,
          fixture.enabledPolicy.minimumValidWeightDays,
        );
        expect(
          engine.policy.minimumWeightSpanDays,
          fixture.enabledPolicy.minimumWeightSpanDays,
        );
        expect(
          engine.policy.proposalStepKcal,
          fixture.enabledPolicy.proposalStepKcal,
        );
        expect(
          engine.policy.aggregateWindowDays,
          fixture.enabledPolicy.aggregateWindowDays,
        );
      },
    );
  });

  group('eligibility and evidence safety', () {
    test(
      'underage, unknown and missing eligibility stay explicit and non-numeric',
      () {
        for (final state in [
          CoachingEligibilityResult.underage,
          CoachingEligibilityResult.unknownAge,
          CoachingEligibilityResult.withheldAge,
          CoachingEligibilityResult.conflictingAge,
          CoachingEligibilityResult.invalidEvidence,
        ]) {
          final result = engine.evaluate(
            _request(activation: _enabled(), eligibility: _eligibility(state)),
          );

          expect(result.status, B04AdaptiveTargetStatus.unavailable);
          expect(result.adaptiveDeltaKcal, 0);
          expect(result.proposal, isNull);
          expect(result.reasonCode, isNot('eligible'));
        }

        final missing = engine.evaluate(
          _request(activation: _enabled(), omitEligibility: true),
        );
        expect(missing.reasonCode, 'coaching_unavailable_age');
        expect(missing.adaptiveDeltaKcal, 0);
      },
    );

    test('consent is independently required', () {
      final result = engine.evaluate(
        _request(activation: _enabled(), adaptiveConsentEnabled: false),
      );

      expect(result.reasonCode, 'coaching_consent_required');
      expect(result.adaptiveDeltaKcal, 0);
    });

    test(
      'pregnancy, clinician-managed and uncertain safety states are blocked',
      () {
        for (final safety in [
          const B04SafetyInput(pregnancyOrBreastfeeding: true),
          const B04SafetyInput(clinicianManagedPlan: true),
          const B04SafetyInput(state: B04SafetyState.possible),
          const B04SafetyInput(state: B04SafetyState.unknown),
          const B04SafetyInput(state: B04SafetyState.insufficient),
          const B04SafetyInput(state: B04SafetyState.confirmedConflict),
        ]) {
          final result = engine.evaluate(
            _request(activation: _enabled(), safety: safety),
          );
          expect(result.status, B04AdaptiveTargetStatus.unavailable);
          expect(result.adaptiveDeltaKcal, 0);
          expect(result.proposal, isNull);
        }
      },
    );

    test(
      'one observation, stale body metrics and invalid units never become zero',
      () {
        final oneWeight = engine.evaluate(
          _request(
            activation: _enabled(),
            weights: [_weight('one', '2026-02-21', '70000')],
          ),
        );
        final noBody = engine.evaluate(
          _request(activation: _enabled(), omitBody: true),
        );
        final wrongUnit = engine.evaluate(
          _request(
            activation: _enabled(),
            nutrition: _nutritionDays(
              energy: const B04NumericRangeEvidence(point: '2000', unit: 'g'),
            ),
          ),
        );

        expect(oneWeight.adaptiveDeltaKcal, 0);
        expect(oneWeight.reasonCode, 'insufficient_weight_days');
        expect(noBody.reasonCode, 'body_metrics_unavailable');
        expect(wrongUnit.status, B04AdaptiveTargetStatus.invalidEvidence);
        expect(wrongUnit.adaptiveDeltaKcal, 0);
      },
    );

    test(
      'loss BMI exactly 18.5 passes while one unit below is unavailable',
      () {
        final atBoundary = engine.evaluate(
          _request(
            activation: _enabled(),
            body: _body(heightCm: '200', weightGrams: '74000'),
          ),
        );
        final below = engine.evaluate(
          _request(
            activation: _enabled(),
            body: _body(heightCm: '200', weightGrams: '73999'),
          ),
        );

        expect(atBoundary.status, B04AdaptiveTargetStatus.onTrack);
        expect(below.reasonCode, 'loss_bmi_below_supported_boundary');
        expect(below.adaptiveDeltaKcal, 0);
      },
    );
  });

  group('ENABLED-1 deterministic arithmetic', () {
    test('upward and downward proposals are exactly one hundred kcal', () {
      final downward = engine.evaluate(
        _request(activation: _enabled(), slopeGramsPerDay: -20),
      );
      final upward = engine.evaluate(
        _request(activation: _enabled(), slopeGramsPerDay: -80),
      );

      expect(downward.status, B04AdaptiveTargetStatus.available);
      expect(downward.direction, B04AdaptiveTargetDirection.decreaseCalories);
      expect(downward.adaptiveDeltaKcal, -100);
      expect(downward.proposedTargetKcal, 1700);
      expect(upward.direction, B04AdaptiveTargetDirection.increaseCalories);
      expect(upward.adaptiveDeltaKcal, 100);
      expect(upward.proposedTargetKcal, 1900);
      expect(downward.proposal!.goalRate, '-0.50% body weight/week');
      downward.proposal!.validate();
    });

    test(
      'exact deadband edges are on track and outside edges choose direction',
      () {
        final cases = <int, B04AdaptiveTargetStatus>{
          -65: B04AdaptiveTargetStatus.onTrack,
          -35: B04AdaptiveTargetStatus.onTrack,
          -34: B04AdaptiveTargetStatus.available,
          -66: B04AdaptiveTargetStatus.available,
        };
        for (final entry in cases.entries) {
          final result = engine.evaluate(
            _request(activation: _enabled(), slopeGramsPerDay: entry.key),
          );
          expect(result.status, entry.value, reason: 'slope ${entry.key}');
          if (entry.value == B04AdaptiveTargetStatus.onTrack) {
            expect(result.adaptiveDeltaKcal, 0);
          } else {
            expect(result.adaptiveDeltaKcal.abs(), 100);
          }
        }
      },
    );

    test('rapid thresholds are exclusive and use exact unrounded rates', () {
      final exact = engine.evaluate(
        _request(activation: _enabled(), slopeGramsPerDay: -100),
      );
      final rapid = engine.evaluate(
        _request(activation: _enabled(), slopeGramsPerDay: -101),
      );

      expect(exact.weeklyRatePercent, B04ExactRational.parse('-1'));
      expect(exact.status, B04AdaptiveTargetStatus.available);
      expect(rapid.status, B04AdaptiveTargetStatus.rapidChangeReview);
      expect(rapid.reasonCode, 'rapid_change_review');
      expect(rapid.adaptiveDeltaKcal, 0);
    });

    test('gain and maintenance deadbands use their own signed rates', () {
      final gainOnTrack = engine.evaluate(
        _request(
          activation: _enabled(),
          goalType: NutritionGoalType.gain,
          target: 2200,
          goalRate: 'gain:+0.25% body weight/week',
          slopeGramsPerDay: 25,
        ),
      );
      final maintenanceIncrease = engine.evaluate(
        _request(
          activation: _enabled(),
          goalType: NutritionGoalType.maintenance,
          target: 2000,
          goalRate: 'maintenance:0.00% body weight/week',
          slopeGramsPerDay: -30,
        ),
      );

      expect(gainOnTrack.status, B04AdaptiveTargetStatus.onTrack);
      expect(maintenanceIncrease.adaptiveDeltaKcal, 100);
      expect(
        maintenanceIncrease.direction,
        B04AdaptiveTargetDirection.increaseCalories,
      );
    });

    test('gain rapid threshold is exclusive', () {
      final exact = engine.evaluate(
        _request(
          activation: _enabled(),
          goalType: NutritionGoalType.gain,
          goalRate: '+0.25% body weight/week',
          slopeGramsPerDay: 50,
        ),
      );
      final rapid = engine.evaluate(
        _request(
          activation: _enabled(),
          goalType: NutritionGoalType.gain,
          goalRate: '+0.25% body weight/week',
          slopeGramsPerDay: 51,
        ),
      );

      expect(exact.weeklyRatePercent, B04ExactRational.parse('0.5'));
      expect(exact.status, B04AdaptiveTargetStatus.available);
      expect(rapid.status, B04AdaptiveTargetStatus.rapidChangeReview);
      expect(rapid.adaptiveDeltaKcal, 0);
    });

    test(
      'unsupported faster goal rates are unavailable and never defaulted',
      () {
        final result = engine.evaluate(
          _request(
            activation: _enabled(),
            goalRate: '-0.75% body weight/week',
            slopeGramsPerDay: -20,
          ),
        );

        expect(result.reasonCode, 'unsupported_goal_rate');
        expect(result.adaptiveDeltaKcal, 0);
      },
    );

    test(
      'odd/even medians, Theil-Sen slopes and display rounding stay exact',
      () {
        expect(
          engine.median([
            B04ExactRational.fromInt(1),
            B04ExactRational.fromInt(3),
            B04ExactRational.fromInt(2),
          ]),
          B04ExactRational.fromInt(2),
        );
        expect(
          engine.median([
            B04ExactRational.fromInt(1),
            B04ExactRational.fromInt(4),
            B04ExactRational.fromInt(2),
            B04ExactRational.fromInt(3),
          ]),
          B04ExactRational.parse('2.5'),
        );
        final slope = engine.theilSenSlope([
          _weight('a', '2026-02-01', '70000'),
          _weight('b', '2026-02-03', '69900'),
          _weight('c', '2026-02-04', '69850'),
        ]);
        expect(slope, B04ExactRational.parse('-50'));
        expect(B04ExactRational.parse('0.125').displayPercent(), '0.13');
        expect(B04ExactRational.parse('-0.125').displayPercent(), '-0.13');
      },
    );

    test(
      'maintenance normalization uses ties-away-from-zero and exact caps',
      () {
        expect(engine.normalizedMaintenance('2000'), 2000);
        expect(engine.normalizedMaintenance('2000.5'), 2001);
        expect(engine.normalizedMaintenance('1800.5'), 1801);

        final result = engine.evaluate(
          _request(
            activation: _enabled(),
            maintenance: _maintenance(point: '2001'),
            slopeGramsPerDay: -20,
          ),
        );
        expect(result.normalizedMaintenanceKcal, 2001);
      },
    );

    test('nutrition and maintenance range limits are inclusive and exact', () {
      final nutritionPass = engine.evaluate(
        _request(
          activation: _enabled(),
          nutrition: _nutritionDays(
            energy: const B04NumericRangeEvidence(
              point: '2000',
              lower: '1800',
              upper: '2200',
              unit: 'kcal/day',
            ),
          ),
        ),
      );
      final nutritionFail = engine.evaluate(
        _request(
          activation: _enabled(),
          nutrition: _nutritionDays(
            energy: const B04NumericRangeEvidence(
              point: '2000',
              lower: '1799',
              upper: '2201',
              unit: 'kcal/day',
            ),
          ),
        ),
      );
      final maintenancePass = engine.evaluate(
        _request(
          activation: _enabled(),
          maintenance: _maintenance(
            point: '2000',
            lower: '1850',
            upper: '2150',
          ),
        ),
      );
      final maintenanceFail = engine.evaluate(
        _request(
          activation: _enabled(),
          maintenance: _maintenance(
            point: '2000',
            lower: '1849',
            upper: '2151',
          ),
        ),
      );

      expect(nutritionPass.status, B04AdaptiveTargetStatus.onTrack);
      expect(nutritionFail.reasonCode, 'nutrition_range_too_wide');
      expect(maintenancePass.status, B04AdaptiveTargetStatus.onTrack);
      expect(maintenanceFail.reasonCode, 'maintenance_range_too_wide');
    });

    test(
      'invalid midpoint, reversed, negative and non-finite ranges fail closed',
      () {
        for (final range in [
          const B04NumericRangeEvidence(
            lower: '0',
            upper: '0',
            unit: 'kcal/day',
          ),
          const B04NumericRangeEvidence(
            lower: '2200',
            upper: '1800',
            unit: 'kcal/day',
          ),
          const B04NumericRangeEvidence(
            lower: '-1',
            upper: '2000',
            unit: 'kcal/day',
          ),
          const B04NumericRangeEvidence(point: 'NaN', unit: 'kcal/day'),
          const B04NumericRangeEvidence(point: 'Infinity', unit: 'kcal/day'),
        ]) {
          final result = engine.evaluate(
            _request(
              activation: _enabled(),
              nutrition: _nutritionDays(energy: range),
            ),
          );
          expect(result.adaptiveDeltaKcal, 0);
          expect(result.proposal, isNull);
          expect(result.status, isNot(B04AdaptiveTargetStatus.available));
        }
      },
    );
  });

  group('bounds, cadence and replay', () {
    test('boundary crossing never emits a smaller clamp', () {
      final floor = engine.evaluate(
        _request(activation: _enabled(), target: 1600, slopeGramsPerDay: -20),
      );
      final outside = engine.evaluate(
        _request(activation: _enabled(), target: 1599, slopeGramsPerDay: -20),
      );
      final gainCeiling = engine.evaluate(
        _request(
          activation: _enabled(),
          goalType: NutritionGoalType.gain,
          target: 2300,
          goalRate: 'gain:+0.25% body weight/week',
          slopeGramsPerDay: 9,
        ),
      );

      expect(floor.status, B04AdaptiveTargetStatus.policyBoundaryReached);
      expect(floor.proposedTargetKcal, isNull);
      expect(outside.reasonCode, 'user_target_outside_supported_policy');
      expect(gainCeiling.status, B04AdaptiveTargetStatus.policyBoundaryReached);
    });

    test('cadence and seven-day expiry use completed local days', () {
      final recent = engine.evaluate(
        _request(
          activation: _enabled(),
          slopeGramsPerDay: -20,
          history: [
            _history(
              id: 'recent',
              localDate: '2026-02-02',
              state: B04AdaptiveProposalState.accepted,
              accepted: true,
            ),
          ],
        ),
      );
      final expired = engine.evaluate(
        _request(
          activation: _enabled(),
          slopeGramsPerDay: -20,
          history: [
            _history(
              id: 'pending-expired',
              localDate: '2026-02-15',
              state: B04AdaptiveProposalState.pending,
            ),
          ],
        ),
      );

      expect(recent.reasonCode, 'proposal_cadence_not_met');
      expect(expired.status, B04AdaptiveTargetStatus.expired);
      expect(expired.reasonCode, 'proposal_expired');
    });

    test(
      'aggregate counts accepted engine deltas but excludes manual changes',
      () {
        final blocked = engine.evaluate(
          _request(
            activation: _enabled(),
            slopeGramsPerDay: -80,
            history: [
              _history(
                id: 'engine-plus-100-a',
                localDate: '2026-01-20',
                deltaKcal: 100,
                state: B04AdaptiveProposalState.accepted,
                accepted: true,
              ),
              _history(
                id: 'engine-plus-100-b',
                localDate: '2026-01-21',
                deltaKcal: 100,
                state: B04AdaptiveProposalState.accepted,
                accepted: true,
              ),
            ],
          ),
        );
        final manualIgnored = engine.evaluate(
          _request(
            activation: _enabled(),
            slopeGramsPerDay: -80,
            history: [
              _history(
                id: 'manual-plus-200',
                localDate: '2026-01-20',
                deltaKcal: 200,
                engineAuthored: false,
                state: B04AdaptiveProposalState.accepted,
                accepted: true,
              ),
            ],
          ),
        );

        expect(blocked.status, B04AdaptiveTargetStatus.policyBoundaryReached);
        expect(manualIgnored.status, B04AdaptiveTargetStatus.available);
        expect(manualIgnored.adaptiveDeltaKcal, 100);
      },
    );

    test(
      'stored policy version controls replay and offline results are deterministic',
      () {
        final enabled = _request(activation: _enabled(), slopeGramsPerDay: -20);
        final holdReplay = engine.evaluate(
          _request(
            activation: _enabled(),
            storedPolicyVersion: kB04HoldPolicyVersion,
            slopeGramsPerDay: -20,
          ),
        );
        final first = engine.evaluate(enabled);
        final second = engine.evaluate(
          _request(
            activation: _enabled(),
            slopeGramsPerDay: -20,
            offline: true,
            aiSuggestedDeltaKcal: 900,
            userOverrideRequested: true,
          ),
        );

        expect(holdReplay.policyVersion, kB04HoldPolicyVersion);
        expect(holdReplay.adaptiveDeltaKcal, 0);
        expect(second.adaptiveDeltaKcal, first.adaptiveDeltaKcal);
        expect(
          second.proposal!.evidenceFingerprint,
          first.proposal!.evidenceFingerprint,
        );
        expect(second.proposedTargetKcal, first.proposedTargetKcal);
      },
    );

    test(
      'append-only correction supersedes evidence without rewriting the input',
      () {
        final original = _weights(slopeGramsPerDay: -20);
        final corrected = [
          ...original,
          _weight(
            'weight-10-correction',
            original[10].localDate,
            original[10].grams,
            supersedesObservationId: 'weight-10',
          ),
        ];
        final before = engine.evaluate(
          _request(
            activation: _enabled(),
            weights: original,
            slopeGramsPerDay: -20,
          ),
        );
        final after = engine.evaluate(
          _request(
            activation: _enabled(),
            weights: corrected,
            slopeGramsPerDay: -20,
          ),
        );

        expect(original.any((item) => item.id == 'weight-10'), isTrue);
        expect(after.evidenceIds, contains('weight-10-correction'));
        expect(after.evidenceIds, isNot(contains('weight-10')));
        expect(after.weeklyRatePercent, before.weeklyRatePercent);
      },
    );

    test(
      'stored local dates survive DST and the incomplete current day is excluded',
      () {
        const timezoneId = 'America/New_York';
        const evaluationLocalDate = '2026-03-16';
        final base = _request(
          activation: _enabled(timezoneId: timezoneId),
          evaluationLocalDate: evaluationLocalDate,
          timezoneId: timezoneId,
          evaluatedAtUtc: DateTime.utc(2026, 3, 16, 12),
          slopeGramsPerDay: -20,
        );
        final withCurrentDay = _request(
          activation: _enabled(timezoneId: timezoneId),
          evaluationLocalDate: evaluationLocalDate,
          timezoneId: timezoneId,
          evaluatedAtUtc: DateTime.utc(2026, 3, 16, 12),
          slopeGramsPerDay: -20,
          weights: [
            ..._weights(
              evaluationLocalDate: evaluationLocalDate,
              timezoneId: timezoneId,
              slopeGramsPerDay: -20,
            ),
            _weight(
              'current-incomplete',
              evaluationLocalDate,
              '1',
              timezoneId: timezoneId,
            ),
          ],
        );
        final first = engine.evaluate(base);
        final second = engine.evaluate(withCurrentDay);

        expect(first.status, B04AdaptiveTargetStatus.available);
        expect(second.status, first.status);
        expect(second.adaptiveDeltaKcal, first.adaptiveDeltaKcal);
        expect(second.evidenceIds, isNot(contains('current-incomplete')));
      },
    );
  });

  group('evidence window boundaries', () {
    test('a goal change requires exactly 21 new completed local days', () {
      final twenty = engine.evaluate(
        _request(
          activation: _enabled(),
          goalEffectiveFromLocalDate: '2026-02-02',
          slopeGramsPerDay: -20,
        ),
      );
      final twentyOne = engine.evaluate(
        _request(
          activation: _enabled(),
          goalEffectiveFromLocalDate: '2026-02-01',
          slopeGramsPerDay: -20,
        ),
      );

      expect(twenty.reasonCode, 'evaluation_window_reset');
      expect(twenty.adaptiveDeltaKcal, 0);
      expect(twentyOne.status, B04AdaptiveTargetStatus.available);
    });

    test(
      'weight count, span, block distribution and freshness gates are exact',
      () {
        final all = _weights(slopeGramsPerDay: -20);
        final nine = engine.evaluate(
          _request(
            activation: _enabled(),
            weights: all.take(9).toList(),
            slopeGramsPerDay: -20,
          ),
        );
        final shortSpan = engine.evaluate(
          _request(
            activation: _enabled(),
            weights: all.take(14).toList(),
            slopeGramsPerDay: -20,
          ),
        );
        final missingFirstBlock = engine.evaluate(
          _request(
            activation: _enabled(),
            weights: [
              all[0],
              all[1],
              all[7],
              all[8],
              all[9],
              all[14],
              all[15],
              all[16],
              all[19],
              all[20],
            ],
            slopeGramsPerDay: -20,
          ),
        );
        final staleLatest = engine.evaluate(
          _request(
            activation: _enabled(),
            weights: [
              all[0],
              all[1],
              all[2],
              all[7],
              all[8],
              all[9],
              all[10],
              all[13],
              all[14],
              all[15],
            ],
            slopeGramsPerDay: -20,
          ),
        );

        expect(nine.reasonCode, 'insufficient_weight_days');
        expect(shortSpan.reasonCode, 'insufficient_weight_span');
        expect(
          missingFirstBlock.reasonCode,
          'insufficient_weight_block_distribution',
        );
        expect(staleLatest.reasonCode, 'weight_evidence_stale');
      },
    );

    test('nutrition count and completeness gates are exact', () {
      final thirteen = engine.evaluate(
        _request(
          activation: _enabled(),
          nutrition: _nutritionDays().take(13).toList(),
          slopeGramsPerDay: -20,
        ),
      );
      final belowCompleteness = engine.evaluate(
        _request(
          activation: _enabled(),
          nutrition: _nutritionDays(completenessPercent: '79.99'),
          slopeGramsPerDay: -20,
        ),
      );
      final exactCompleteness = engine.evaluate(
        _request(
          activation: _enabled(),
          nutrition: _nutritionDays(completenessPercent: '80'),
          slopeGramsPerDay: -20,
        ),
      );

      expect(thirteen.reasonCode, 'insufficient_nutrition_days');
      expect(
        belowCompleteness.reasonCode,
        'nutrition_completeness_insufficient',
      );
      expect(exactCompleteness.status, B04AdaptiveTargetStatus.available);
    });

    test(
      'different range actions remain unavailable rather than exactified',
      () {
        final result = engine.evaluate(
          _request(
            activation: _enabled(),
            slopeGramsPerDay: -20,
            nutrition: _nutritionDays(
              energy: const B04NumericRangeEvidence(
                lower: '1800',
                upper: '2200',
                unit: 'kcal/day',
                actionAtLower: 'increase',
                actionAtUpper: 'decrease',
              ),
            ),
          ),
        );

        expect(result.reasonCode, 'unavailable_uncertain_range');
        expect(result.adaptiveDeltaKcal, 0);
      },
    );

    test('maintenance freshness is inclusive at 30 days and stale at 31', () {
      final end = _dates.addCalendarDays(_evaluationDate, _timezoneId, -1);
      final fresh = engine.evaluate(
        _request(
          activation: _enabled(),
          slopeGramsPerDay: -20,
          maintenance: _maintenance(
            localDate: _dates.addCalendarDays(end, _timezoneId, -30),
          ),
        ),
      );
      final stale = engine.evaluate(
        _request(
          activation: _enabled(),
          slopeGramsPerDay: -20,
          maintenance: _maintenance(
            localDate: _dates.addCalendarDays(end, _timezoneId, -31),
          ),
        ),
      );

      expect(fresh.status, B04AdaptiveTargetStatus.available);
      expect(stale.reasonCode, 'maintenance_evidence_stale');
    });
  });

  group('READINESS-HOLD-1 overlay', () {
    test(
      'complete, missing and unavailable readiness have exact zero effects',
      () {
        final complete = engine.evaluateTrainingOverlay(
          readinessSnapshot: _readiness(
            completeness: ReadinessCompleteness.complete,
            status: ReadinessStatus.available,
          ),
          baseB02Recommendation: null,
        );
        final unavailable = engine.evaluateTrainingOverlay(
          readinessSnapshot: _readiness(
            completeness: ReadinessCompleteness.unknown,
            status: ReadinessStatus.unavailable,
          ),
          baseB02Recommendation: null,
        );
        for (final result in [complete, unavailable]) {
          expect(result.policyVersion, kB04ReadinessHoldPolicyVersion);
          expect(result.calorieDeltaKcal, 0);
          expect(result.trainingLoadDeltaPercent, 0);
          expect(result.trainingIntensityDeltaPercent, 0);
          expect(result.scheduleDurationDelta, 0);
          expect(result.numericalProposalAllowed, isFalse);
        }
        expect(complete.descriptiveCoachingAllowed, isTrue);
        expect(unavailable.descriptiveCoachingAllowed, isFalse);
      },
    );
  });
}

const _userId = 'user-a';
const _timezoneId = 'Asia/Kolkata';
const _evaluationDate = '2026-02-22';
final _dates = LocalScheduleDateService();

B04ActivationMetadata _enabled({
  String effectiveFrom = '2026-01-01',
  String timezoneId = _timezoneId,
  String scopeUserId = _userId,
}) => B04ActivationMetadata.enabled(
  effectiveFromLocalDate: effectiveFrom,
  timezoneId: timezoneId,
  scopeUserId: scopeUserId,
  mergedBranch: 'batch/b04-adaptive-coaching',
  releaseSelection: 'test-enabled-policy',
);

B04AdaptiveTargetRequest _request({
  NutritionGoalType goalType = NutritionGoalType.loss,
  int? target,
  String? goalRate,
  String goalEffectiveFromLocalDate = '2026-01-01',
  int slopeGramsPerDay = -50,
  String evaluationLocalDate = _evaluationDate,
  String timezoneId = _timezoneId,
  DateTime? evaluatedAtUtc,
  B04ActivationMetadata? activation,
  CoachingEligibilityReadModel? eligibility,
  bool omitEligibility = false,
  bool adaptiveConsentEnabled = true,
  bool explicitlyInitiated = true,
  bool offline = false,
  bool userOverrideRequested = false,
  int? aiSuggestedDeltaKcal,
  String? storedPolicyVersion,
  B04BodyMetricsEvidence? body,
  bool omitBody = false,
  List<B04WeightObservation>? weights,
  List<B04NutritionDayEvidence>? nutrition,
  B04MaintenanceEnergyEvidence? maintenance,
  bool omitMaintenance = false,
  List<B04AdaptiveTargetHistoryEvent> history = const [],
  B04SafetyInput safety = const B04SafetyInput(),
}) {
  final atUtc = evaluatedAtUtc ?? DateTime.utc(2026, 2, 22, 10);
  final effectiveTarget =
      target ??
      switch (goalType) {
        NutritionGoalType.loss => 1800,
        NutritionGoalType.maintenance => 2000,
        NutritionGoalType.gain => 2200,
        NutritionGoalType.custom => 2000,
      };
  final effectiveRate =
      goalRate ??
      switch (goalType) {
        NutritionGoalType.loss => '-0.50% body weight/week',
        NutritionGoalType.maintenance => '0.00% body weight/week',
        NutritionGoalType.gain => '+0.25% body weight/week',
        NutritionGoalType.custom => '0.00% body weight/week',
      };
  return B04AdaptiveTargetRequest(
    evaluationId: 'evaluation-1',
    userId: _userId,
    evaluationLocalDate: evaluationLocalDate,
    timezoneId: timezoneId,
    evaluatedAtUtc: atUtc,
    explicitlyInitiated: explicitlyInitiated,
    adaptiveConsentEnabled: adaptiveConsentEnabled,
    offline: offline,
    userOverrideRequested: userOverrideRequested,
    aiSuggestedDeltaKcal: aiSuggestedDeltaKcal,
    storedPolicyVersion: storedPolicyVersion,
    activation: activation ?? const B04ActivationMetadata(),
    eligibility: omitEligibility
        ? null
        : (eligibility ??
              _eligibility(
                CoachingEligibilityResult.eligible,
                evaluationLocalDate: evaluationLocalDate,
                timezoneId: timezoneId,
                evaluatedAtUtc: atUtc,
              )),
    activeGoal: NutritionGoalVersionReadModel(
      id: 'goal-1',
      userId: _userId,
      versionNumber: 1,
      goalType: goalType,
      source: NutritionGoalSource.userSet,
      calorieTargetKcal: effectiveTarget,
      proteinTargetG: 140,
      carbsTargetG: 220,
      fatTargetG: 60,
      policyVersion: null,
      calculationVersion: null,
      algorithmVersion: null,
      effectiveFromLocalDate: goalEffectiveFromLocalDate,
      effectiveToLocalDate: null,
      timezoneId: timezoneId,
      supersedesGoalVersionId: null,
      evidenceFingerprint: null,
      exactResultNumerator: null,
      exactResultDenominator: null,
      normalizedMaintenanceKcal: null,
      createdAtUtc: DateTime.utc(2026, 1, 1),
    ),
    goalRate: effectiveRate,
    bodyMetrics: omitBody
        ? null
        : (body ??
              _body(
                localDate: _dates.addCalendarDays(
                  evaluationLocalDate,
                  timezoneId,
                  -1,
                ),
                timezoneId: timezoneId,
              )),
    weightObservations:
        weights ??
        _weights(
          slopeGramsPerDay: slopeGramsPerDay,
          evaluationLocalDate: evaluationLocalDate,
          timezoneId: timezoneId,
        ),
    nutritionDays:
        nutrition ??
        _nutritionDays(
          evaluationLocalDate: evaluationLocalDate,
          timezoneId: timezoneId,
        ),
    maintenanceEvidence: omitMaintenance
        ? null
        : (maintenance ??
              _maintenance(
                localDate: _dates.addCalendarDays(
                  evaluationLocalDate,
                  timezoneId,
                  -1,
                ),
                timezoneId: timezoneId,
              )),
    history: history,
    safety: safety,
  );
}

CoachingEligibilityReadModel _eligibility(
  CoachingEligibilityResult result, {
  String evaluationLocalDate = _evaluationDate,
  String timezoneId = _timezoneId,
  DateTime? evaluatedAtUtc,
}) => CoachingEligibilityReadModel(
  userId: _userId,
  result: result,
  reasonCode: result == CoachingEligibilityResult.eligible
      ? 'eligible'
      : result.stableId,
  policyVersion: kB04EnabledPolicyVersion,
  evaluationLocalDate: evaluationLocalDate,
  timezoneId: timezoneId,
  evaluationUtc: (evaluatedAtUtc ?? DateTime.utc(2026, 2, 22, 10)).subtract(
    const Duration(minutes: 1),
  ),
);

B04BodyMetricsEvidence _body({
  String heightCm = '170',
  String weightGrams = '70000',
  String localDate = '2026-02-21',
  String timezoneId = _timezoneId,
}) => B04BodyMetricsEvidence(
  id: 'body-1',
  userId: _userId,
  heightCm: heightCm,
  weightGrams: weightGrams,
  sourceId: 'profile-snapshot',
  sourceVersion: 'profile-v1',
  localDate: localDate,
  timezoneId: timezoneId,
  observedAtUtc: DateTime.utc(2026, 2, 21, 10),
);

List<B04WeightObservation> _weights({
  int slopeGramsPerDay = -50,
  String evaluationLocalDate = _evaluationDate,
  String timezoneId = _timezoneId,
}) {
  final end = _dates.addCalendarDays(evaluationLocalDate, timezoneId, -1);
  final start = _dates.addCalendarDays(end, timezoneId, -20);
  return [
    for (var index = 0; index < 21; index++)
      _weight(
        'weight-$index',
        _dates.addCalendarDays(start, timezoneId, index),
        (70000 + slopeGramsPerDay * (index - 10)).toString(),
        timezoneId: timezoneId,
      ),
  ];
}

B04WeightObservation _weight(
  String id,
  String localDate,
  String grams, {
  String timezoneId = _timezoneId,
  String? supersedesObservationId,
}) => B04WeightObservation(
  id: id,
  userId: _userId,
  localDate: localDate,
  timezoneId: timezoneId,
  grams: grams,
  sourceId: 'scale',
  sourceVersion: 'scale-v1',
  observedAtUtc: DateTime.utc(2026, 2, 21, 8),
  supersedesObservationId: supersedesObservationId,
);

List<B04NutritionDayEvidence> _nutritionDays({
  String evaluationLocalDate = _evaluationDate,
  String timezoneId = _timezoneId,
  String completenessPercent = '80',
  B04NumericRangeEvidence energy = const B04NumericRangeEvidence(
    point: '2000',
    unit: 'kcal/day',
  ),
}) {
  final end = _dates.addCalendarDays(evaluationLocalDate, timezoneId, -1);
  final start = _dates.addCalendarDays(end, timezoneId, -20);
  return [
    for (var index = 0; index < 21; index++)
      B04NutritionDayEvidence(
        id: 'nutrition-$index',
        userId: _userId,
        localDate: _dates.addCalendarDays(start, timezoneId, index),
        timezoneId: timezoneId,
        energy: energy,
        completenessPercent: completenessPercent,
        sourceId: 'b03-history',
        sourceVersion: 'b03-v1',
        historicalSnapshot: true,
        observedAtUtc: DateTime.utc(2026, 2, 1 + index, 12),
      ),
  ];
}

B04MaintenanceEnergyEvidence _maintenance({
  String point = '2000',
  String? lower,
  String? upper,
  String localDate = '2026-02-21',
  String timezoneId = _timezoneId,
}) => B04MaintenanceEnergyEvidence(
  id: 'maintenance-1',
  userId: _userId,
  localDate: localDate,
  timezoneId: timezoneId,
  energy: B04NumericRangeEvidence(
    point: point,
    lower: lower,
    upper: upper,
    unit: 'kcal/day',
  ),
  sourceId: 'b03-maintenance',
  sourceVersion: 'b03-v1',
  policyVersion: kB04EnabledPolicyVersion,
  historicalSnapshot: true,
  observedAtUtc: DateTime.utc(2026, 2, 21, 12),
);

B04AdaptiveTargetHistoryEvent _history({
  required String id,
  required String localDate,
  int deltaKcal = 100,
  bool engineAuthored = true,
  bool accepted = false,
  B04AdaptiveProposalState state = B04AdaptiveProposalState.pending,
}) => B04AdaptiveTargetHistoryEvent(
  id: id,
  userId: _userId,
  localDate: localDate,
  timezoneId: _timezoneId,
  deltaKcal: deltaKcal,
  engineAuthored: engineAuthored,
  accepted: accepted,
  state: state,
  policyVersion: kB04EnabledPolicyVersion,
);

ReadinessSnapshotReadModel _readiness({
  required ReadinessCompleteness completeness,
  required ReadinessStatus status,
}) => ReadinessSnapshotReadModel(
  id: 'readiness-1',
  userId: _userId,
  localDate: _evaluationDate,
  timezoneId: _timezoneId,
  completeness: completeness,
  status: status,
  band: status == ReadinessStatus.available ? ReadinessBand.ready : null,
  confidence: status == ReadinessStatus.available ? 1 : null,
  calculationVersion: kB04ReadinessCalculationVersion,
  policyVersion: kB04ReadinessHoldPolicyVersion,
  unavailableReason: status == ReadinessStatus.unavailable
      ? 'readiness_unavailable'
      : null,
  evidenceFingerprint: 'readiness-fingerprint',
  createdAtUtc: DateTime.utc(2026, 2, 22),
  supersededAtUtc: null,
  supersedesSnapshotId: null,
);
