import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/algorithms/adaptive_tdee_engine.dart';
import 'package:indifit/data/models/adaptive_tdee_models.dart';

void main() {
  const engine = AdaptiveTdeeEngine();
  const policy = AdaptiveTdeePolicy.v1;
  const baselineBmr = 1650.0; // 70kg, 170cm, 25yo male
  const baselineTdee = 2500.0; // ~1.5x BMR

  group('AdaptiveTdeeEngine - Mathematical Convergence', () {
    test('converges to true expenditure in stable weight maintenance', () {
      // 60 days of eating 2,500 kcal with constant 75.0 kg weight
      final days = <AdaptiveTdeeDayInput>[];
      for (int i = 1; i <= 60; i++) {
        final dateStr = '2026-01-${i.toString().padLeft(2, '0')}';
        days.add(
          AdaptiveTdeeDayInput(
            localDate: dateStr,
            scaleWeightKg: 75.0,
            caloriesConsumed: 2500.0,
            intakeSource: AdaptiveTdeeIntakeSource.foodLog,
          ),
        );
      }

      final estimate = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: 2200.0, // Seeded with different prior to test convergence
        days: days,
        evaluationLocalDate: '2026-03-01',
        timezoneId: 'UTC',
      );

      expect(estimate.confidence, AdaptiveTdeeConfidence.high);
      expect(estimate.trendWeightKg, closeTo(75.0, 0.01));
      // Should converge closely to 2,500 kcal
      expect(estimate.currentTdeeKcal, closeTo(2500.0, 20.0));
      expect(estimate.loggedFoodDaysInWindow, 21);
      expect(estimate.loggedWeightDaysInWindow, 21);
    });

    test('converges to true expenditure during fat loss in deficit', () {
      // Eating 2,000 kcal/day while losing ~0.45 kg/week (64.3 g/day)
      // True expenditure should be ~2000 + (0.0643 * 7700) ~ 2495 kcal/day
      final days = <AdaptiveTdeeDayInput>[];
      double currentWeight = 80.0;
      const dailyLossKg = 0.45 / 7.0; // ~64.3g per day

      for (int i = 1; i <= 70; i++) {
        final month = (i ~/ 30) + 1;
        final day = (i % 30) + 1;
        final dateStr = '2026-0$month-${day.toString().padLeft(2, '0')}';
        days.add(
          AdaptiveTdeeDayInput(
            localDate: dateStr,
            scaleWeightKg: currentWeight,
            caloriesConsumed: 2000.0,
            intakeSource: AdaptiveTdeeIntakeSource.snapshot,
          ),
        );
        currentWeight -= dailyLossKg;
      }

      final estimate = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: baselineTdee,
        days: days,
        evaluationLocalDate: '2026-03-15',
        timezoneId: 'UTC',
      );

      expect(estimate.confidence, AdaptiveTdeeConfidence.high);
      expect(estimate.currentTdeeKcal, closeTo(2495.0, 35.0));
    });

    test('converges to true expenditure during muscle gain in surplus', () {
      // Eating 3,000 kcal/day while gaining ~0.45 kg/week (64.3 g/day)
      // True expenditure should be ~3000 - (0.0643 * 7700) ~ 2505 kcal/day
      final days = <AdaptiveTdeeDayInput>[];
      double currentWeight = 70.0;
      const dailyGainKg = 0.45 / 7.0;

      for (int i = 1; i <= 70; i++) {
        final month = (i ~/ 30) + 1;
        final day = (i % 30) + 1;
        final dateStr = '2026-0$month-${day.toString().padLeft(2, '0')}';
        days.add(
          AdaptiveTdeeDayInput(
            localDate: dateStr,
            scaleWeightKg: currentWeight,
            caloriesConsumed: 3000.0,
            intakeSource: AdaptiveTdeeIntakeSource.foodLog,
          ),
        );
        currentWeight += dailyGainKg;
      }

      final estimate = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: baselineTdee,
        days: days,
        evaluationLocalDate: '2026-03-15',
        timezoneId: 'UTC',
      );

      expect(estimate.confidence, AdaptiveTdeeConfidence.high);
      expect(estimate.currentTdeeKcal, closeTo(2505.0, 35.0));
    });
  });

  group('AdaptiveTdeeEngine - Adherence Neutrality & Noise Filtering', () {
    test('missing food log days do not drag TDEE down to zero', () {
      // User logs 2500 kcal on Mon, Wed, Fri only (Tue, Thu, Sat, Sun missing)
      // Weight remains constant 75.0 kg
      final days = <AdaptiveTdeeDayInput>[];
      for (int i = 1; i <= 28; i++) {
        final isFoodDay = (i % 2 != 0); // Alternate days
        days.add(
          AdaptiveTdeeDayInput(
            localDate: '2026-01-${i.toString().padLeft(2, '0')}',
            scaleWeightKg: 75.0,
            caloriesConsumed: isFoodDay ? 2500.0 : null,
            intakeSource: isFoodDay
                ? AdaptiveTdeeIntakeSource.foodLog
                : AdaptiveTdeeIntakeSource.none,
          ),
        );
      }

      final estimate = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: 2500.0,
        days: days,
        evaluationLocalDate: '2026-01-28',
        timezoneId: 'UTC',
      );

      // TDEE should NOT drop towards 0 or 1250 kcal; it stays around 2500
      expect(estimate.currentTdeeKcal, closeTo(2500.0, 30.0));
      // Unobserved days are omitted from raw expenditure
      final unobservedOutputs = estimate.history.where((d) => !d.hasObservedIntake);
      for (final output in unobservedOutputs) {
        expect(output.rawExpenditureKcal, isNull);
      }
    });

    test('3kg water retention scale weight outlier is heavily dampened', () {
      // 20 days stable at 75 kg, then day 21 has a 78.0 kg scale spike (e.g. sodium/water)
      final days = <AdaptiveTdeeDayInput>[];
      for (int i = 1; i <= 20; i++) {
        days.add(
          AdaptiveTdeeDayInput(
            localDate: '2026-01-${i.toString().padLeft(2, '0')}',
            scaleWeightKg: 75.0,
            caloriesConsumed: 2500.0,
            intakeSource: AdaptiveTdeeIntakeSource.foodLog,
          ),
        );
      }
      days.add(
        const AdaptiveTdeeDayInput(
          localDate: '2026-01-21',
          scaleWeightKg: 78.0, // 3 kg spike
          caloriesConsumed: 2500.0,
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
      );

      final estimate = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: 2500.0,
        days: days,
        evaluationLocalDate: '2026-01-21',
        timezoneId: 'UTC',
      );

      // Trend weight on day 21: 0.12 * 78 + 0.88 * 75 = 75.36 kg (only 360g increase)
      expect(estimate.trendWeightKg, closeTo(75.36, 0.05));
      // Rate-of-change clamp prevents TDEE from plummeting; delta cannot exceed 35 kcal/day
      final prevTdee = estimate.history[19].smoothedTdeeKcal;
      final spikeTdee = estimate.history[20].smoothedTdeeKcal;
      expect((spikeTdee - prevTdee).abs(), lessThanOrEqualTo(35.01));
    });

    test('rate of change clamp strictly bounds day-over-day shifts to +/- 35 kcal', () {
      // User logs a massive 10,000 kcal binge day
      final days = [
        const AdaptiveTdeeDayInput(
          localDate: '2026-01-01',
          scaleWeightKg: 75.0,
          caloriesConsumed: 2500.0,
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
        const AdaptiveTdeeDayInput(
          localDate: '2026-01-02',
          scaleWeightKg: 75.0,
          caloriesConsumed: 10000.0, // +7500 kcal binge
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
      ];

      final estimate = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: 2500.0,
        days: days,
        evaluationLocalDate: '2026-01-02',
        timezoneId: 'UTC',
      );

      final day1 = estimate.history[0].smoothedTdeeKcal;
      final day2 = estimate.history[1].smoothedTdeeKcal;
      expect(day2 - day1, closeTo(35.0, 0.001));
    });
  });

  group('AdaptiveTdeeEngine - Physiological Bounds & Bayesian Blend', () {
    test('enforces physiological floor and ceiling scaled to BMR', () {
      // BMR = 1500. Floor = max(1000, 0.8 * 1500) = 1200. Ceiling = min(6000, 3.0 * 1500) = 4500.
      final daysFloor = List.generate(
        100,
        (i) => AdaptiveTdeeDayInput(
          localDate: '2026-01-01',
          scaleWeightKg: 70.0,
          caloriesConsumed: 500.0, // Starvation intake
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
      );

      final estimateFloor = engine.calculate(
        policy: policy,
        baselineBmr: 1500.0,
        baselineTdeeKcal: 2000.0,
        days: daysFloor,
        evaluationLocalDate: '2026-01-01',
        timezoneId: 'UTC',
      );
      expect(estimateFloor.currentTdeeKcal, greaterThanOrEqualTo(1200.0));

      final daysCeiling = List.generate(
        100,
        (i) => AdaptiveTdeeDayInput(
          localDate: '2026-01-01',
          scaleWeightKg: 70.0,
          caloriesConsumed: 8000.0, // Massive surplus intake
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
      );

      final estimateCeiling = engine.calculate(
        policy: policy,
        baselineBmr: 1500.0,
        baselineTdeeKcal: 2000.0,
        days: daysCeiling,
        evaluationLocalDate: '2026-01-01',
        timezoneId: 'UTC',
      );
      expect(estimateCeiling.currentTdeeKcal, lessThanOrEqualTo(4500.0));
    });

    test('warm-up blend transitions from prior over 14 observed food days', () {
      // On day 7 (7 observed food days), warmupWeight is 7/14 = 0.5
      final days = List.generate(
        7,
        (i) => AdaptiveTdeeDayInput(
          localDate: '2026-01-${(i + 1).toString().padLeft(2, '0')}',
          scaleWeightKg: 70.0,
          caloriesConsumed: 3000.0,
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
      );

      final estimate = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: 2000.0,
        days: days,
        evaluationLocalDate: '2026-01-07',
        timezoneId: 'UTC',
      );

      expect(estimate.totalObservedFoodDays, 7);
      // Smoothed TDEE on day 7 has been pulled upwards towards 3000
      final smoothed = estimate.history.last.smoothedTdeeKcal;
      final expectedBlended = (0.5 * smoothed) + (0.5 * 2000.0);
      expect(estimate.currentTdeeKcal, closeTo(expectedBlended, 0.01));
    });
  });

  group('AdaptiveTdeeEngine - Confidence & Edge Cases', () {
    test('confidence transitions: calibrating -> moderate -> high', () {
      // 1. 3 days: Calibrating
      final days3 = List.generate(
        3,
        (i) => AdaptiveTdeeDayInput(
          localDate: '2026-01-0$i',
          scaleWeightKg: 70.0,
          caloriesConsumed: 2000.0,
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
      );
      final est3 = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: baselineTdee,
        days: days3,
        evaluationLocalDate: '2026-01-03',
        timezoneId: 'UTC',
      );
      expect(est3.confidence, AdaptiveTdeeConfidence.calibrating);
      expect(est3.confidenceMessage, contains('Calibrating'));

      // 2. 8 food days & 6 weight days: Moderate
      final days8 = List.generate(
        8,
        (i) => AdaptiveTdeeDayInput(
          localDate: '2026-01-${(i + 1).toString().padLeft(2, '0')}',
          scaleWeightKg: i < 6 ? 70.0 : null,
          caloriesConsumed: 2000.0,
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
      );
      final est8 = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: baselineTdee,
        days: days8,
        evaluationLocalDate: '2026-01-08',
        timezoneId: 'UTC',
      );
      expect(est8.confidence, AdaptiveTdeeConfidence.moderate);

      // 3. 15 food days & 12 weight days: High
      final days15 = List.generate(
        15,
        (i) => AdaptiveTdeeDayInput(
          localDate: '2026-01-${(i + 1).toString().padLeft(2, '0')}',
          scaleWeightKg: i < 12 ? 70.0 : null,
          caloriesConsumed: 2000.0,
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
      );
      final est15 = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: baselineTdee,
        days: days15,
        evaluationLocalDate: '2026-01-15',
        timezoneId: 'UTC',
      );
      expect(est15.confidence, AdaptiveTdeeConfidence.high);
    });

    test('empty history returns calibrating state without crashing', () {
      final estimate = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: baselineTdee,
        days: const [],
        evaluationLocalDate: '2026-01-01',
        timezoneId: 'UTC',
      );

      expect(estimate.confidence, AdaptiveTdeeConfidence.calibrating);
      expect(estimate.currentTdeeKcal, baselineTdee);
      expect(estimate.trendWeightKg, isNull);
      expect(estimate.currentScaleWeightKg, isNull);
      expect(estimate.history, isEmpty);
    });

    test('day-output trendWeightKg is null before first scale weigh-in', () {
      final days = [
        const AdaptiveTdeeDayInput(
          localDate: '2026-01-01',
          scaleWeightKg: null,
          caloriesConsumed: 2000.0,
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
        const AdaptiveTdeeDayInput(
          localDate: '2026-01-02',
          scaleWeightKg: null,
          caloriesConsumed: 2100.0,
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
        const AdaptiveTdeeDayInput(
          localDate: '2026-01-03',
          scaleWeightKg: 75.0,
          caloriesConsumed: 2000.0,
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
      ];

      final estimate = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: baselineTdee,
        days: days,
        evaluationLocalDate: '2026-01-03',
        timezoneId: 'UTC',
      );

      expect(estimate.history[0].trendWeightKg, isNull);
      expect(estimate.history[1].trendWeightKg, isNull);
      expect(estimate.history[2].trendWeightKg, closeTo(75.0, 0.01));
      expect(estimate.trendWeightKg, closeTo(75.0, 0.01));
    });

    test('invalid BMR (<= 0) falls back to absolute bounds and forces calibrating', () {
      final days = List.generate(
        20,
        (i) => AdaptiveTdeeDayInput(
          localDate: '2026-01-${(i + 1).toString().padLeft(2, '0')}',
          scaleWeightKg: 70.0,
          caloriesConsumed: 2000.0,
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
      );

      final estimate = engine.calculate(
        policy: policy,
        baselineBmr: 0.0, // Invalid BMR
        baselineTdeeKcal: 0.0, // Invalid baseline TDEE
        days: days,
        evaluationLocalDate: '2026-01-20',
        timezoneId: 'UTC',
      );

      expect(estimate.confidence, AdaptiveTdeeConfidence.calibrating);
      expect(estimate.currentTdeeKcal, isNot(isNaN));
      expect(estimate.currentTdeeKcal, greaterThanOrEqualTo(1000.0));
      expect(estimate.currentTdeeKcal, lessThanOrEqualTo(6000.0));
    });

    test('caps history lookback to maxHistoryDays', () {
      // 400 days of input
      final days = List.generate(
        400,
        (i) => AdaptiveTdeeDayInput(
          localDate: '2025-01-01',
          scaleWeightKg: 70.0,
          caloriesConsumed: 2200.0,
          intakeSource: AdaptiveTdeeIntakeSource.foodLog,
        ),
      );

      final estimate = engine.calculate(
        policy: policy,
        baselineBmr: baselineBmr,
        baselineTdeeKcal: baselineTdee,
        days: days,
        evaluationLocalDate: '2026-02-05',
        timezoneId: 'UTC',
      );

      expect(estimate.history.length, policy.maxHistoryDays);
    });
  });
}
