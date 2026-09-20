import 'dart:math' as math;

import '../../data/models/adaptive_tdee_models.dart';

/// Pure, deterministic algorithm engine for on-device Adaptive TDEE calculation.
///
/// Implements dynamic energy balance:
///   Expenditure = Intake - (Delta TrendWeight * 7700 kcal/kg)
///
/// Fully adheres to:
/// - Adherence neutrality (missing days are unobserved, never 0 kcal)
/// - Trend weight EWMA noise reduction (alpha = 0.12)
/// - Expenditure smoothing with daily rate-of-change clamp (beta = 0.06, +/- 35 kcal/day)
/// - Warm-up Bayesian blend with baseline prior over first 14 observed food intake days
/// - Physiological BMR-scaled bounds
/// - Rolling 21-day confidence evaluation
class AdaptiveTdeeEngine {
  const AdaptiveTdeeEngine();

  AdaptiveTdeeEstimate calculate({
    AdaptiveTdeePolicy policy = AdaptiveTdeePolicy.v1,
    required double baselineBmr,
    required double baselineTdeeKcal,
    required List<AdaptiveTdeeDayInput> days,
    required String evaluationLocalDate,
    required String timezoneId,
  }) {
    final bool invalidBmr = baselineBmr <= 0.0;
    final double effectiveFloor = invalidBmr
        ? policy.absoluteFloorKcal
        : math.max(
            policy.absoluteFloorKcal,
            policy.bmrFloorMultiplier * baselineBmr,
          );
    final double effectiveCeiling = invalidBmr
        ? policy.absoluteCeilingKcal
        : math.min(
            policy.absoluteCeilingKcal,
            policy.bmrCeilingMultiplier * baselineBmr,
          );

    final double effectiveBaselineTdee = baselineTdeeKcal <= 0.0
        ? (baselineBmr > 0.0 ? baselineBmr * 1.55 : 2000.0)
        : baselineTdeeKcal.clamp(effectiveFloor, effectiveCeiling);

    if (days.isEmpty) {
      return AdaptiveTdeeEstimate(
        currentTdeeKcal: effectiveBaselineTdee,
        baselineTdeeKcal: effectiveBaselineTdee,
        currentScaleWeightKg: null,
        trendWeightKg: null,
        confidence: AdaptiveTdeeConfidence.calibrating,
        confidenceMessage:
            'Calibrating: log 7 days of food and 5 weigh-ins to establish an adaptive trend.',
        loggedFoodDaysInWindow: 0,
        loggedWeightDaysInWindow: 0,
        totalObservedFoodDays: 0,
        policyVersion: policy.policyVersion,
        history: const [],
      );
    }

    // Bound historical evaluation to maxHistoryDays to preserve mobile performance
    // while providing continuous EWMA evolution.
    final evaluatedDays = days.length > policy.maxHistoryDays
        ? days.sublist(days.length - policy.maxHistoryDays)
        : days;

    double? currentTrendWeight;
    double? previousTrendWeight;
    double smoothedTdee = effectiveBaselineTdee;
    int totalObservedFoodDays = 0;
    double? latestScaleWeight;
    final history = <AdaptiveTdeeDayOutput>[];

    for (final day in evaluatedDays) {
      // 1. Trend Weight Evolution (EWMA)
      if (day.hasWeight) {
        latestScaleWeight = day.scaleWeightKg!;
        if (currentTrendWeight == null) {
          currentTrendWeight = day.scaleWeightKg!;
        } else {
          currentTrendWeight =
              (policy.alphaWeight * day.scaleWeightKg!) +
              ((1.0 - policy.alphaWeight) * currentTrendWeight);
        }
      }

      // 2. Dynamic Energy Balance
      double? rawExpenditure;
      if (currentTrendWeight != null && previousTrendWeight != null) {
        final deltaWeightKg = currentTrendWeight - previousTrendWeight;
        final deltaEnergyKcal = deltaWeightKg * policy.tissueKcalPerKg;

        if (day.hasObservedIntake) {
          totalObservedFoodDays++;
          rawExpenditure = day.caloriesConsumed! - deltaEnergyKcal;
        }
      } else if (day.hasObservedIntake) {
        // First day with weight or intake before delta can be computed
        totalObservedFoodDays++;
        rawExpenditure = day.caloriesConsumed!;
      }

      // 3. Expenditure Smoothing & Clamping (Adherence-Neutral)
      if (rawExpenditure != null) {
        final targetTdee =
            (policy.betaTdee * rawExpenditure) +
            ((1.0 - policy.betaTdee) * smoothedTdee);
        final delta = (targetTdee - smoothedTdee).clamp(
          -policy.maxDailyDeltaKcal,
          policy.maxDailyDeltaKcal,
        );
        smoothedTdee = (smoothedTdee + delta).clamp(
          effectiveFloor,
          effectiveCeiling,
        );
      }

      history.add(
        AdaptiveTdeeDayOutput(
          localDate: day.localDate,
          scaleWeightKg: day.scaleWeightKg,
          trendWeightKg: currentTrendWeight,
          rawExpenditureKcal: rawExpenditure,
          smoothedTdeeKcal: smoothedTdee,
          hasObservedIntake: day.hasObservedIntake,
        ),
      );

      previousTrendWeight = currentTrendWeight;
    }

    // 4. Bayesian Warm-Up Blend with Baseline Prior
    final double warmupWeight = policy.warmupDays > 0
        ? math.min(1.0, totalObservedFoodDays / policy.warmupDays)
        : 1.0;
    final double blendedTdee =
        (warmupWeight * smoothedTdee) +
        ((1.0 - warmupWeight) * effectiveBaselineTdee);
    final double finalTdee = blendedTdee.clamp(effectiveFloor, effectiveCeiling);

    // 5. Rolling Evaluation Window & Confidence Scoring
    final windowLength = math.min(policy.windowDays, history.length);
    final windowDays = history.sublist(history.length - windowLength);

    final loggedFoodDaysInWindow =
        windowDays.where((d) => d.hasObservedIntake).length;
    final loggedWeightDaysInWindow =
        windowDays.where((d) => d.scaleWeightKg != null && d.scaleWeightKg! > 0).length;

    AdaptiveTdeeConfidence confidence;
    String confidenceMessage;

    if (invalidBmr) {
      confidence = AdaptiveTdeeConfidence.calibrating;
      confidenceMessage =
          'Calibrating: profile metrics required for physiological calibration.';
    } else if (loggedFoodDaysInWindow >= policy.minFoodDaysHigh &&
        loggedWeightDaysInWindow >= policy.minWeightDaysHigh) {
      confidence = AdaptiveTdeeConfidence.high;
      confidenceMessage =
          'High confidence ($loggedFoodDaysInWindow/${policy.windowDays} food days, $loggedWeightDaysInWindow weigh-ins).';
    } else if (loggedFoodDaysInWindow >= policy.minFoodDaysModerate &&
        loggedWeightDaysInWindow >= policy.minWeightDaysModerate) {
      confidence = AdaptiveTdeeConfidence.moderate;
      confidenceMessage =
          'Moderate confidence ($loggedFoodDaysInWindow/${policy.windowDays} food days, $loggedWeightDaysInWindow weigh-ins).';
    } else {
      confidence = AdaptiveTdeeConfidence.calibrating;
      final neededFood = math.max(0, policy.minFoodDaysModerate - loggedFoodDaysInWindow);
      final neededWeight = math.max(0, policy.minWeightDaysModerate - loggedWeightDaysInWindow);
      final parts = <String>[];
      if (neededFood > 0) parts.add('$neededFood more food ${neededFood == 1 ? 'day' : 'days'}');
      if (neededWeight > 0) parts.add('$neededWeight more ${neededWeight == 1 ? 'weigh-in' : 'weigh-ins'}');
      confidenceMessage =
          'Calibrating: log ${parts.join(' and ')} for moderate confidence.';
    }

    return AdaptiveTdeeEstimate(
      currentTdeeKcal: finalTdee,
      baselineTdeeKcal: effectiveBaselineTdee,
      currentScaleWeightKg: latestScaleWeight,
      trendWeightKg: currentTrendWeight,
      confidence: confidence,
      confidenceMessage: confidenceMessage,
      loggedFoodDaysInWindow: loggedFoodDaysInWindow,
      loggedWeightDaysInWindow: loggedWeightDaysInWindow,
      totalObservedFoodDays: totalObservedFoodDays,
      policyVersion: policy.policyVersion,
      history: history,
    );
  }
}
