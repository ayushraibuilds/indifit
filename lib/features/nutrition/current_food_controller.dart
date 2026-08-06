import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/b04_current_food_models.dart';
import '../../data/models/b04_recommendation_context_models.dart';
import '../../data/services/b04_current_food_guidance_service.dart';
import '../../data/services/b04_production_recommendation_orchestrator.dart';

enum B04CurrentFoodControllerStatus {
  idle,
  loading,
  ready,
  noCandidate,
  unavailable,
  failure,
}

class B04CurrentFoodState {
  final B04CurrentFoodControllerStatus status;
  final B04CurrentFoodGuidance? guidance;
  final String? errorCode;
  final String? errorMessage;
  final bool retryable;

  const B04CurrentFoodState({
    this.status = B04CurrentFoodControllerStatus.idle,
    this.guidance,
    this.errorCode,
    this.errorMessage,
    this.retryable = false,
  });

  bool get isLoading => status == B04CurrentFoodControllerStatus.loading;

  B04CurrentFoodState copyWith({
    B04CurrentFoodControllerStatus? status,
    Object? guidance = _unset,
    Object? errorCode = _unset,
    Object? errorMessage = _unset,
    bool? retryable,
  }) => B04CurrentFoodState(
    status: status ?? this.status,
    guidance: guidance == _unset
        ? this.guidance
        : guidance as B04CurrentFoodGuidance?,
    errorCode: errorCode == _unset ? this.errorCode : errorCode as String?,
    errorMessage: errorMessage == _unset
        ? this.errorMessage
        : errorMessage as String?,
    retryable: retryable ?? this.retryable,
  );
}

const _unset = Object();

/// State owner for the current-food read model. The caller supplies the
/// already assembled B04 context and explicit local candidates; this
/// controller performs no persistence, search, network call, or safety
/// evaluation.
class B04CurrentFoodController extends StateNotifier<B04CurrentFoodState> {
  final B04CurrentFoodGuidanceService _service;
  final Future<B04ProductionRecommendationOrchestrator> Function()?
  _loadOrchestrator;
  B04RecommendationContext? _lastContext;
  List<B04CurrentFoodCandidateInput> _lastCandidates = const [];
  int _generation = 0;

  B04CurrentFoodController({
    required B04CurrentFoodGuidanceService service,
    Future<B04ProductionRecommendationOrchestrator> Function()?
    loadOrchestrator,
  }) : _service = service,
       _loadOrchestrator = loadOrchestrator,
       super(const B04CurrentFoodState());

  Future<void> loadProduction({
    required B04RecommendationContext context,
    bool refresh = false,
  }) async {
    final loader = _loadOrchestrator;
    if (loader == null) {
      await load(context: context, candidates: const []);
      return;
    }
    final generation = ++_generation;
    _lastContext = context;
    _lastCandidates = const [];
    state = state.copyWith(
      status: B04CurrentFoodControllerStatus.loading,
      guidance: null,
      errorCode: null,
      errorMessage: null,
      retryable: false,
    );
    try {
      final orchestrator = await loader();
      final result = refresh
          ? await orchestrator.reloadCurrentFood(
              userId: context.userId,
              localDate: context.window.startLocalDate,
              timezoneId: context.window.timezoneId,
            )
          : await orchestrator.loadCurrentFood(
              userId: context.userId,
              localDate: context.window.startLocalDate,
              timezoneId: context.window.timezoneId,
            );
      _lastContext = result.context;
      _lastCandidates = result.candidates;
      if (!mounted || generation != _generation) return;
      final status = switch (result.guidance.status) {
        B04CurrentFoodGuidanceStatus.available =>
          B04CurrentFoodControllerStatus.ready,
        B04CurrentFoodGuidanceStatus.noCandidate =>
          B04CurrentFoodControllerStatus.noCandidate,
        B04CurrentFoodGuidanceStatus.unavailable =>
          B04CurrentFoodControllerStatus.unavailable,
      };
      state = state.copyWith(
        status: status,
        guidance: result.guidance,
        errorCode: null,
        errorMessage: null,
        retryable: false,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      final typed = error is B04CurrentFoodError ? error : null;
      state = state.copyWith(
        status: B04CurrentFoodControllerStatus.failure,
        guidance: null,
        errorCode: typed?.code ?? 'current_food_guidance_failed',
        errorMessage:
            typed?.message ??
            'Current-food guidance could not be loaded. You can retry.',
        retryable: true,
      );
    }
  }

  Future<void> load({
    required B04RecommendationContext context,
    required Iterable<B04CurrentFoodCandidateInput> candidates,
  }) async {
    final generation = ++_generation;
    _lastContext = context;
    _lastCandidates = List.unmodifiable(candidates);
    state = state.copyWith(
      status: B04CurrentFoodControllerStatus.loading,
      guidance: null,
      errorCode: null,
      errorMessage: null,
      retryable: false,
    );
    try {
      final guidance = _service.evaluate(
        context: context,
        candidates: _lastCandidates,
      );
      if (!mounted || generation != _generation) return;
      final status = switch (guidance.status) {
        B04CurrentFoodGuidanceStatus.available =>
          B04CurrentFoodControllerStatus.ready,
        B04CurrentFoodGuidanceStatus.noCandidate =>
          B04CurrentFoodControllerStatus.noCandidate,
        B04CurrentFoodGuidanceStatus.unavailable =>
          B04CurrentFoodControllerStatus.unavailable,
      };
      state = state.copyWith(
        status: status,
        guidance: guidance,
        errorCode: null,
        errorMessage: null,
        retryable: false,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      final typed = error is B04CurrentFoodError ? error : null;
      state = state.copyWith(
        status: B04CurrentFoodControllerStatus.failure,
        guidance: null,
        errorCode: typed?.code ?? 'current_food_guidance_failed',
        errorMessage:
            typed?.message ??
            'Current-food guidance could not be loaded. You can retry.',
        retryable: true,
      );
    }
  }

  Future<void> retry() async {
    final context = _lastContext;
    if (context == null) return;
    if (_loadOrchestrator != null) {
      await loadProduction(context: context, refresh: true);
      return;
    }
    await load(context: context, candidates: _lastCandidates);
  }
}
