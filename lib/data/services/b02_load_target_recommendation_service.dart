import '../../data/models/b02_execution_models.dart';
import 'b02_warmup_recommendation_service.dart';

/// The only progression constants used by the B02 target rule. Changing any
/// value requires a new [ruleVersion] so historical offers remain explainable.
class B02LoadTargetRuleV1 {
  static const String ruleVersion = 'b02-target-v1';
  static const Duration comparatorWindow = Duration(days: 84);
  static const double deloadFactor = 0.90;
  static const int lowRpeIncreaseCeiling = 8;

  const B02LoadTargetRuleV1._();
}

enum B02TargetDisposition {
  noRecommendation,
  prescriptionFallback,
  keepComparableLoad,
  increaseOneIncrement,
  decreaseOneIncrement,
  deloadReduction,
}

/// Immutable prescription facts, frozen at recommendation time.
class B02LoadTargetPrescription {
  final String? stableExerciseId;
  final bool identityResolved;
  final B02LoadBasis? loadBasis;
  final double? prescribedLoadKg;
  final int? targetRepsMin;
  final int? targetRepsMax;
  final int? targetRpe;
  final bool isDeloadWeek;

  const B02LoadTargetPrescription({
    required this.stableExerciseId,
    required this.identityResolved,
    required this.loadBasis,
    this.prescribedLoadKg,
    this.targetRepsMin,
    this.targetRepsMax,
    this.targetRpe,
    this.isDeloadWeek = false,
  });

  bool get hasRepRange =>
      targetRepsMin != null &&
      targetRepsMax != null &&
      targetRepsMin! <= targetRepsMax!;
}

/// A single canonical performed working set eligible for target evidence.
/// This type intentionally contains actual, rather than prescribed, values.
class B02TargetComparator {
  final String performedSetId;
  final String stableExerciseId;
  final B02LoadBasis loadBasis;
  final double actualLoadKg;
  final int actualReps;
  final int? actualRpe;
  final bool endedAtFailure;
  final DateTime completedAtUtc;

  const B02TargetComparator({
    required this.performedSetId,
    required this.stableExerciseId,
    required this.loadBasis,
    required this.actualLoadKg,
    required this.actualReps,
    required this.actualRpe,
    required this.endedAtFailure,
    required this.completedAtUtc,
  });
}

/// Read-only evidence supplied to the pure target rule. A null workload means
/// the execution timezone was unavailable, not that workload was zero.
class B02LoadTargetEvidence {
  final DateTime cutoffUtc;
  final List<B02TargetComparator> comparators;
  final int? recentWorkingSetCount;
  final bool recoveryKnown;

  const B02LoadTargetEvidence({
    required this.cutoffUtc,
    required this.comparators,
    required this.recentWorkingSetCount,
    required this.recoveryKnown,
  });
}

class B02LoadTargetRecommendationRequest {
  final String recommendationId;
  final String performedExerciseId;
  final B02LoadTargetPrescription prescription;
  final B02LoadTargetEvidence evidence;
  final B02EquipmentIncrementInput incrementInput;

  const B02LoadTargetRecommendationRequest({
    required this.recommendationId,
    required this.performedExerciseId,
    required this.prescription,
    required this.evidence,
    this.incrementInput = const B02EquipmentIncrementInput(),
  });
}

class B02LoadTargetRecommendationResult {
  final B02TargetRecommendation recommendation;
  final B02TargetDisposition disposition;
  final B02TargetComparator? selectedComparator;

  const B02LoadTargetRecommendationResult({
    required this.recommendation,
    required this.disposition,
    required this.selectedComparator,
  });
}

/// Pure B02-D11 recommendation engine. It deliberately has no repository,
/// clock, health, or UI dependency: consumers first gather frozen evidence and
/// then pass it to this deterministic rule.
class LoadTargetRecommendationService {
  static const String ruleVersion = B02LoadTargetRuleV1.ruleVersion;

  const LoadTargetRecommendationService();

  B02LoadTargetRecommendationResult recommend(
    B02LoadTargetRecommendationRequest request,
  ) {
    final prescription = request.prescription;
    final increment = const B02EquipmentIncrementResolver().resolve(
      request.incrementInput,
    );
    final rationale = <String>[];
    final validIdentity =
        prescription.identityResolved &&
        _nonBlank(prescription.stableExerciseId);
    final validBasis = prescription.loadBasis != null;

    if (!validIdentity) {
      rationale.add('identity-unresolved');
      return _result(
        request: request,
        incrementKg: increment.incrementKg,
        rationale: rationale,
        confidence: B02Confidence.insufficient,
        disposition: B02TargetDisposition.noRecommendation,
        selected: null,
        recommendedLoadKg: null,
        comparatorInRange: false,
      );
    }
    if (!validBasis) {
      rationale.add('load-basis-unknown');
      return _result(
        request: request,
        incrementKg: increment.incrementKg,
        rationale: rationale,
        confidence: B02Confidence.insufficient,
        disposition: B02TargetDisposition.noRecommendation,
        selected: null,
        recommendedLoadKg: null,
        comparatorInRange: false,
      );
    }

    final eligible = request.evidence.comparators
        .where(
          (candidate) =>
              candidate.stableExerciseId == prescription.stableExerciseId &&
              candidate.loadBasis == prescription.loadBasis &&
              candidate.completedAtUtc.toUtc().isAfter(
                request.evidence.cutoffUtc.toUtc().subtract(
                  const Duration(microseconds: 1),
                ),
              ),
        )
        .toList(growable: false);
    eligible.sort((first, second) {
      final completed = second.completedAtUtc.compareTo(first.completedAtUtc);
      return completed != 0
          ? completed
          : second.performedSetId.compareTo(first.performedSetId);
    });
    final inRange = prescription.hasRepRange
        ? eligible
              .where(
                (candidate) =>
                    candidate.actualReps >= prescription.targetRepsMin! &&
                    candidate.actualReps <= prescription.targetRepsMax!,
              )
              .toList(growable: false)
        : const <B02TargetComparator>[];
    final selected = inRange.isNotEmpty
        ? inRange.first
        : (eligible.isEmpty ? null : eligible.first);
    final comparatorInRange = inRange.isNotEmpty;

    if (!request.evidence.recoveryKnown) rationale.add('recovery-unknown');
    if (request.evidence.recentWorkingSetCount == null) {
      rationale.add('workload-unknown');
    }
    if (!prescription.hasRepRange) rationale.add('rep-range-incomplete');

    if (selected == null) {
      rationale.add('no-comparable-history');
      final prescribed = _nonNegativeFinite(prescription.prescribedLoadKg);
      if (prescribed == null) {
        rationale.add('manual-load-required');
        return _result(
          request: request,
          incrementKg: increment.incrementKg,
          rationale: rationale,
          confidence: B02Confidence.insufficient,
          disposition: B02TargetDisposition.noRecommendation,
          selected: null,
          recommendedLoadKg: null,
          comparatorInRange: false,
        );
      }
      rationale.add('prescription-fallback');
      return _result(
        request: request,
        incrementKg: increment.incrementKg,
        rationale: rationale,
        confidence: B02Confidence.low,
        disposition: B02TargetDisposition.prescriptionFallback,
        selected: null,
        recommendedLoadKg: prescribed,
        comparatorInRange: false,
      );
    }

    if (!comparatorInRange) rationale.add('comparator-outside-rep-range');
    if (prescription.isDeloadWeek) {
      if (!increment.isAvailable) {
        rationale.add('increment-unavailable');
        rationale.add('deload-load-unavailable');
        return _result(
          request: request,
          incrementKg: null,
          rationale: rationale,
          confidence: B02Confidence.insufficient,
          disposition: B02TargetDisposition.noRecommendation,
          selected: selected,
          recommendedLoadKg: null,
          comparatorInRange: comparatorInRange,
        );
      }
      rationale.add('deload-v1');
      final deload = _roundToIncrement(
        selected.actualLoadKg * B02LoadTargetRuleV1.deloadFactor,
        increment.incrementKg!,
      );
      return _result(
        request: request,
        incrementKg: increment.incrementKg,
        rationale: rationale,
        confidence: B02Confidence.medium,
        disposition: B02TargetDisposition.deloadReduction,
        selected: selected,
        recommendedLoadKg: deload.clamp(0, selected.actualLoadKg).toDouble(),
        comparatorInRange: comparatorInRange,
      );
    }

    final needsIncrease =
        prescription.hasRepRange &&
        selected.actualReps >= prescription.targetRepsMax! &&
        selected.actualRpe != null &&
        selected.actualRpe! <= B02LoadTargetRuleV1.lowRpeIncreaseCeiling;
    final failedBeforeMinimum =
        prescription.hasRepRange &&
        selected.endedAtFailure &&
        selected.actualReps < prescription.targetRepsMin!;
    final belowMinimum =
        prescription.hasRepRange &&
        selected.actualReps < prescription.targetRepsMin!;
    final needsDecrease = belowMinimum || failedBeforeMinimum;

    if ((needsIncrease || needsDecrease) && !increment.isAvailable) {
      rationale.add('increment-unavailable');
      return _result(
        request: request,
        incrementKg: null,
        rationale: rationale,
        confidence: B02Confidence.insufficient,
        disposition: B02TargetDisposition.noRecommendation,
        selected: selected,
        recommendedLoadKg: null,
        comparatorInRange: comparatorInRange,
      );
    }
    if (needsIncrease) {
      rationale.add('max-reps-rpe-at-most-8');
      return _result(
        request: request,
        incrementKg: increment.incrementKg,
        rationale: rationale,
        confidence: _historyConfidence(
          evidence: request.evidence,
          comparatorInRange: comparatorInRange,
          repRangeKnown: prescription.hasRepRange,
        ),
        disposition: B02TargetDisposition.increaseOneIncrement,
        selected: selected,
        recommendedLoadKg: selected.actualLoadKg + increment.incrementKg!,
        comparatorInRange: comparatorInRange,
      );
    }
    if (needsDecrease) {
      rationale.add('below-rep-minimum');
      if (failedBeforeMinimum) rationale.add('failure-before-minimum');
      return _result(
        request: request,
        incrementKg: increment.incrementKg,
        rationale: rationale,
        confidence: _historyConfidence(
          evidence: request.evidence,
          comparatorInRange: comparatorInRange,
          repRangeKnown: prescription.hasRepRange,
        ),
        disposition: B02TargetDisposition.decreaseOneIncrement,
        selected: selected,
        recommendedLoadKg: (selected.actualLoadKg - increment.incrementKg!)
            .clamp(0, double.infinity)
            .toDouble(),
        comparatorInRange: comparatorInRange,
      );
    }

    rationale.add('comparable-load-kept');
    return _result(
      request: request,
      incrementKg: increment.incrementKg,
      rationale: rationale,
      confidence: _historyConfidence(
        evidence: request.evidence,
        comparatorInRange: comparatorInRange,
        repRangeKnown: prescription.hasRepRange,
      ),
      disposition: B02TargetDisposition.keepComparableLoad,
      selected: selected,
      recommendedLoadKg: selected.actualLoadKg,
      comparatorInRange: comparatorInRange,
    );
  }

  B02LoadTargetRecommendationResult _result({
    required B02LoadTargetRecommendationRequest request,
    required double? incrementKg,
    required List<String> rationale,
    required B02Confidence confidence,
    required B02TargetDisposition disposition,
    required B02TargetComparator? selected,
    required double? recommendedLoadKg,
    required bool comparatorInRange,
  }) {
    final prescription = request.prescription;
    final previousReps = selected?.actualReps;
    return B02LoadTargetRecommendationResult(
      disposition: disposition,
      selectedComparator: selected,
      recommendation: B02TargetRecommendation(
        id: request.recommendationId,
        performedExerciseId: request.performedExerciseId,
        ruleVersion: ruleVersion,
        confidence: confidence,
        completeness: {
          'identityResolved': prescription.identityResolved,
          'loadBasisKnown': prescription.loadBasis != null,
          'repRangeKnown': prescription.hasRepRange,
          'comparatorHistoryKnown': selected != null,
          'comparatorInRepRange': comparatorInRange,
          'incrementKnown': incrementKg != null,
          'recoveryKnown': request.evidence.recoveryKnown,
          'recentWorkingSetCountKnown':
              request.evidence.recentWorkingSetCount != null,
          if (request.evidence.recentWorkingSetCount != null)
            'recentWorkingSetCount': request.evidence.recentWorkingSetCount,
          if (selected != null) ...{
            'previousLoadKg': selected.actualLoadKg,
            'previousReps': selected.actualReps,
            if (selected.actualRpe != null) 'previousRpe': selected.actualRpe,
          },
          if (!prescription.hasRepRange && previousReps != null)
            'previousAchievedReps': previousReps,
        },
        recommendedLoadKg: recommendedLoadKg,
        loadBasis: recommendedLoadKg == null ? null : prescription.loadBasis,
        targetRepsMin: prescription.hasRepRange
            ? prescription.targetRepsMin
            : null,
        targetRepsMax: prescription.hasRepRange
            ? prescription.targetRepsMax
            : null,
        targetRpe: prescription.targetRpe,
        incrementKg: incrementKg,
        evidenceCutoffUtc: request.evidence.cutoffUtc.toUtc(),
        comparatorCount: selected == null
            ? 0
            : request.evidence.comparators
                  .where(
                    (candidate) =>
                        candidate.stableExerciseId ==
                            prescription.stableExerciseId &&
                        candidate.loadBasis == prescription.loadBasis &&
                        candidate.completedAtUtc.toUtc().isAfter(
                          request.evidence.cutoffUtc.toUtc().subtract(
                            const Duration(microseconds: 1),
                          ),
                        ),
                  )
                  .length,
        rationaleCodes: rationale,
      ),
    );
  }

  static B02Confidence _historyConfidence({
    required B02LoadTargetEvidence evidence,
    required bool comparatorInRange,
    required bool repRangeKnown,
  }) {
    if (!repRangeKnown) return B02Confidence.low;
    // A recent exact-ID/load-basis comparator remains strong evidence even
    // when no set falls inside the current rep range; range completeness is
    // exposed separately and does not weaken the known failure outcome.
    return evidence.recoveryKnown ? B02Confidence.high : B02Confidence.medium;
  }

  static bool _nonBlank(String? value) =>
      value != null && value.trim().isNotEmpty;

  static double? _nonNegativeFinite(double? value) =>
      value == null || !value.isFinite || value < 0 ? null : value;

  static double _roundToIncrement(double value, double increment) =>
      (value / increment).round() * increment;
}
