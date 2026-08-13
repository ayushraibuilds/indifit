import '../models/b02_execution_models.dart';
import '../repositories/b02_target_recommendation_repository.dart';
import 'b02_load_target_recommendation_service.dart';
import 'b02_warmup_recommendation_service.dart';

/// The single production preparation boundary for the B02 strength player.
/// Repositories gather canonical history and frozen slot inputs; this class
/// invokes the already-approved pure recommendation engines and returns the
/// next durable draft state plus player-ready slots.
class B02WorkoutPreparationResult {
  final B02ExecutionDraftState state;
  final List<B02StrengthExecutionSlot> slots;
  final bool changed;

  const B02WorkoutPreparationResult({
    required this.state,
    required this.slots,
    required this.changed,
  });
}

class B02WorkoutPreparationOrchestrator {
  final B02TargetEvidenceRepository _evidenceRepository;
  final LoadTargetRecommendationService _targetService;
  final WarmupRecommendationService _warmupService;
  final DateTime Function() _nowUtc;

  const B02WorkoutPreparationOrchestrator({
    required B02TargetEvidenceRepository evidenceRepository,
    LoadTargetRecommendationService targetService =
        const LoadTargetRecommendationService(),
    WarmupRecommendationService warmupService =
        const WarmupRecommendationService(),
    DateTime Function()? nowUtc,
  }) : _evidenceRepository = evidenceRepository,
       _targetService = targetService,
       _warmupService = warmupService,
       _nowUtc = nowUtc ?? _utcNow;

  Future<B02WorkoutPreparationResult> prepare({
    required B02ExecutionDraftState state,
    required List<B02StrengthExecutionSlot> slots,
    required String? executionTimezoneId,
  }) async {
    if (slots.isEmpty) {
      return B02WorkoutPreparationResult(
        state: state,
        slots: slots,
        changed: false,
      );
    }

    final recommendations = <String, B02TargetRecommendation>{
      ...state.targetRecommendations,
    };
    final evidenceBySlot = <String, B02LoadTargetEvidence>{};
    var changed = false;
    final preparedSlots = <B02StrengthExecutionSlot>[];

    for (final slot in slots) {
      final performedExerciseId = 'performed:${slot.id}';
      var recommendation = recommendations[slot.id];
      if (recommendation == null) {
        final evidence = await _evidenceRepository.gather(
          B02TargetEvidenceQuery(
            stableExerciseId: slot.exerciseId,
            identityResolved: slot.hasCanonicalExercise,
            loadBasis: slot.targetLoadBasis,
            nowUtc: _nowUtc().toUtc(),
            executionTimezoneId: executionTimezoneId,
            // B02 may consume this optional input, but it must not reach into
            // B04 readiness or turn missing recovery into a number.
            recoveryKnown: false,
          ),
        );
        evidenceBySlot[slot.id] = evidence;
        recommendation = _targetService
            .recommend(
              B02LoadTargetRecommendationRequest(
                recommendationId: 'target:${state.snapshotId}:${slot.id}',
                performedExerciseId: performedExerciseId,
                prescription: B02LoadTargetPrescription(
                  stableExerciseId: slot.exerciseId,
                  identityResolved: slot.hasCanonicalExercise,
                  loadBasis: slot.targetLoadBasis,
                  prescribedLoadKg: slot.targetLoadKg,
                  targetRepsMin: slot.targetRepsMin,
                  targetRepsMax: slot.targetRepsMax,
                  targetRpe: slot.targetRpe,
                  isDeloadWeek: slot.isDeloadWeek,
                ),
                evidence: evidence,
                incrementInput: B02EquipmentIncrementInput(
                  effectiveItemIncrementKg: slot.effectiveItemIncrementKg,
                  profileDefaultIncrementKg: slot.profileDefaultIncrementKg,
                ),
              ),
            )
            .recommendation;
        recommendations[slot.id] = recommendation;
        changed = true;
      }

      final override = state.targetOverrides[slot.id];
      preparedSlots.add(
        slot.copyWith(
          targetLoadKg:
              override?.loadKg ??
              recommendation.recommendedLoadKg ??
              slot.targetLoadKg,
          targetLoadBasis:
              override?.loadBasis ??
              recommendation.loadBasis ??
              slot.targetLoadBasis,
          targetRepsMin:
              override?.targetRepsMin ??
              recommendation.targetRepsMin ??
              slot.targetRepsMin,
          targetRepsMax:
              override?.targetRepsMax ??
              recommendation.targetRepsMax ??
              slot.targetRepsMax,
          targetRpe:
              override?.targetRpe ?? recommendation.targetRpe ?? slot.targetRpe,
        ),
      );
    }

    var nextState = state;
    if (changed) {
      nextState = nextState.copyWith(targetRecommendations: recommendations);
    }

    final warmupSlot = _warmupSlot(nextState, preparedSlots);
    if (nextState.warmupRecommendation == null ||
        nextState.warmupSlotId != warmupSlot.id) {
      final recommendation = recommendations[warmupSlot.id];
      final evidence = evidenceBySlot[warmupSlot.id];
      final warmup = _warmupService.recommend(
        B02WarmupRequest(
          preference: warmupSlot.executionPreference?.warmupPreference,
          requestedCount: warmupSlot.executionPreference?.warmupSetCount,
          userEditedTarget: _candidateFromOverride(
            nextState.targetOverrides[warmupSlot.id],
          ),
          targetRecommendation: _candidateFromRecommendation(recommendation),
          prescription: _candidateFromSlot(
            warmupSlot,
            B02WarmupTargetSource.prescription,
          ),
          recentComparable: _candidateFromComparator(
            evidence?.comparators.firstOrNull,
          ),
          incrementInput: B02EquipmentIncrementInput(
            effectiveItemIncrementKg: warmupSlot.effectiveItemIncrementKg,
            profileDefaultIncrementKg: warmupSlot.profileDefaultIncrementKg,
          ),
        ),
      );
      nextState = nextState.copyWith(
        warmupRecommendation: warmup,
        warmupSlotId: warmupSlot.id,
      );
      changed = true;
    }

    return B02WorkoutPreparationResult(
      state: nextState,
      slots: preparedSlots,
      changed: changed,
    );
  }

  B02StrengthExecutionSlot _warmupSlot(
    B02ExecutionDraftState state,
    List<B02StrengthExecutionSlot> slots,
  ) {
    final id = state.warmupSlotId;
    if (id != null) {
      for (final slot in slots) {
        if (slot.id == id) return slot;
      }
    }
    return slots.first;
  }

  B02WarmupLoadCandidate? _candidateFromRecommendation(
    B02TargetRecommendation? recommendation,
  ) {
    if (recommendation == null) return null;
    return B02WarmupLoadCandidate(
      loadKg: recommendation.recommendedLoadKg,
      loadBasis: recommendation.loadBasis,
      source: B02WarmupTargetSource.targetRecommendation,
    );
  }

  B02WarmupLoadCandidate? _candidateFromOverride(B02TargetOverride? override) {
    if (override == null) return null;
    return B02WarmupLoadCandidate(
      loadKg: override.loadKg,
      loadBasis: override.loadBasis,
      source: B02WarmupTargetSource.userEditedDraft,
    );
  }

  B02WarmupLoadCandidate _candidateFromSlot(
    B02StrengthExecutionSlot slot,
    B02WarmupTargetSource source,
  ) {
    return B02WarmupLoadCandidate(
      loadKg: slot.targetLoadKg,
      loadBasis: slot.targetLoadBasis,
      source: source,
    );
  }

  B02WarmupLoadCandidate? _candidateFromComparator(
    B02TargetComparator? comparator,
  ) {
    if (comparator == null) return null;
    return B02WarmupLoadCandidate(
      loadKg: comparator.actualLoadKg,
      loadBasis: comparator.loadBasis,
      source: B02WarmupTargetSource.recentComparable,
    );
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}

extension on List<B02TargetComparator> {
  B02TargetComparator? get firstOrNull => isEmpty ? null : first;
}
