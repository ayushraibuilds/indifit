import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presentation/product_failure_presentation.dart';
import '../../core/services/local_schedule_date_service.dart';
import '../../data/models/b04_briefing_read_models.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/models/b04_recommendation_history_models.dart';
import '../../data/repositories/b04_briefing_read_repositories.dart';
import '../../data/repositories/b04_recommendation_history_repository.dart';
import '../../data/repositories/coaching_preference_repository.dart';
import '../../data/repositories/nutrition_goal_repository.dart';
import '../../data/services/b04_production_recommendation_orchestrator.dart';

enum B04DailyBriefingControllerStatus {
  idle,
  loading,
  ready,
  noData,
  unavailable,
  failure,
}

class B04DailyBriefingState {
  final B04DailyBriefingControllerStatus status;
  final B04DailyBriefingReadModel? briefing;
  final String? errorCode;
  final String? errorMessage;
  final bool retryable;

  const B04DailyBriefingState({
    this.status = B04DailyBriefingControllerStatus.idle,
    this.briefing,
    this.errorCode,
    this.errorMessage,
    this.retryable = false,
  });

  bool get isLoading => status == B04DailyBriefingControllerStatus.loading;

  B04DailyBriefingState copyWith({
    B04DailyBriefingControllerStatus? status,
    Object? briefing = _unset,
    Object? errorCode = _unset,
    Object? errorMessage = _unset,
    bool? retryable,
  }) => B04DailyBriefingState(
    status: status ?? this.status,
    briefing: briefing == _unset
        ? this.briefing
        : briefing as B04DailyBriefingReadModel?,
    errorCode: errorCode == _unset ? this.errorCode : errorCode as String?,
    errorMessage: errorMessage == _unset
        ? this.errorMessage
        : errorMessage as String?,
    retryable: retryable ?? this.retryable,
  );
}

const _unset = Object();

/// Controller for the dashboard-facing B04 daily projection. It owns only
/// loading/error state; period validation and recommendation projection stay
/// in the read repository.
class B04DailyBriefingController extends StateNotifier<B04DailyBriefingState> {
  final B04DailyBriefingReadRepository _repository;
  final B04RecommendationHistoryRepository? _history;
  final NutritionGoalRepository? _goals;
  final CoachingPreferenceRepository? _preferences;
  final Future<B04ProductionRecommendationOrchestrator> Function()?
  _loadOrchestrator;
  final LocalScheduleDateService _dates;
  String? _userId;
  String? _localDate;
  String? _timezoneId;
  int _generation = 0;

  B04DailyBriefingController({
    required B04DailyBriefingReadRepository repository,
    B04RecommendationHistoryRepository? history,
    NutritionGoalRepository? goals,
    CoachingPreferenceRepository? preferences,
    LocalScheduleDateService? dates,
    Future<B04ProductionRecommendationOrchestrator> Function()?
    loadOrchestrator,
  }) : _repository = repository,
       _history = history,
       _goals = goals,
       _preferences = preferences,
       _loadOrchestrator = loadOrchestrator,
       _dates = dates ?? LocalScheduleDateService(),
       super(const B04DailyBriefingState());

  Future<void> load({
    required String userId,
    required String localDate,
    required String timezoneId,
  }) async {
    final generation = ++_generation;
    _userId = userId;
    _localDate = localDate;
    _timezoneId = timezoneId;
    state = state.copyWith(
      status: B04DailyBriefingControllerStatus.loading,
      briefing: null,
      errorCode: null,
      errorMessage: null,
      retryable: false,
    );
    try {
      final loadOrchestrator = _loadOrchestrator;
      final briefing = loadOrchestrator == null
          ? await _repository.read(
              userId: userId,
              localDate: localDate,
              timezoneId: timezoneId,
            )
          : await (await loadOrchestrator()).loadDaily(
              userId: userId,
              localDate: localDate,
              timezoneId: timezoneId,
            );
      if (!mounted || generation != _generation) return;
      final status = switch (briefing.status) {
        B04BriefingReadStatus.available =>
          B04DailyBriefingControllerStatus.ready,
        B04BriefingReadStatus.noData => B04DailyBriefingControllerStatus.noData,
        B04BriefingReadStatus.unavailable =>
          B04DailyBriefingControllerStatus.unavailable,
      };
      state = state.copyWith(
        status: status,
        briefing: briefing,
        errorCode: null,
        errorMessage: null,
        retryable: false,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      final typed = error is B04BriefingReadRepositoryError ? error : null;
      state = state.copyWith(
        status: B04DailyBriefingControllerStatus.failure,
        briefing: null,
        errorCode: typed?.code ?? 'daily_briefing_read_failed',
        errorMessage: ProductFailurePresentation.fromCode(
          typed?.code,
          title: 'Daily briefing unavailable',
        ).message,
        retryable: true,
      );
    }
  }

  Future<void> retry() async {
    final userId = _userId;
    final localDate = _localDate;
    final timezoneId = _timezoneId;
    if (userId == null || localDate == null || timezoneId == null) return;
    await load(userId: userId, localDate: localDate, timezoneId: timezoneId);
  }

  Future<void> recordFeedback({
    required String recommendationId,
    required B04RecommendationFeedbackAction action,
    String? reason,
  }) async {
    final history = _history;
    final userId = _userId;
    final localDate = _localDate;
    final timezoneId = _timezoneId;
    if (history == null ||
        userId == null ||
        localDate == null ||
        timezoneId == null) {
      return;
    }
    try {
      final createdAtUtc = DateTime.now().toUtc();
      await history.recordFeedback(
        B04RecommendationFeedbackCommand(
          userId: userId,
          recommendationId: recommendationId,
          action: action,
          reason: reason,
          source: 'daily_briefing',
          localDate: _dates.localDateFor(createdAtUtc, timezoneId),
          timezoneId: timezoneId,
          createdAtUtc: createdAtUtc,
        ),
      );
      await load(userId: userId, localDate: localDate, timezoneId: timezoneId);
    } catch (error) {
      if (!mounted) return;
      final typed = error is B04RecommendationHistoryError ? error : null;
      state = state.copyWith(
        status: B04DailyBriefingControllerStatus.failure,
        errorCode: typed?.code ?? 'daily_briefing_feedback_failed',
        errorMessage: ProductFailurePresentation.fromCode(
          typed?.code,
          title: 'Feedback could not be saved',
        ).message,
        retryable: true,
      );
    }
  }

  Future<void> acceptTarget(B04BriefingRecommendation recommendation) async {
    final goals = _goals;
    final preferences = _preferences;
    final history = _history;
    final userId = _userId;
    final localDate = _localDate;
    final timezoneId = _timezoneId;
    final proposal =
        recommendation.engineRecommendation?.canonicalAdaptiveTarget?.proposal;
    if (goals == null ||
        preferences == null ||
        history == null ||
        userId == null ||
        localDate == null ||
        timezoneId == null ||
        proposal == null) {
      return;
    }
    try {
      final createdAtUtc = DateTime.now().toUtc();
      final availability = await preferences.adaptiveAvailability(
        userId: userId,
      );
      await goals.acceptAdaptiveProposal(
        proposal: proposal,
        adaptiveConsentEnabled:
            availability.preferences.adaptiveCoachingEnabled,
        ageEligible: availability.eligibility?.isEligible == true,
        acceptanceCommandId: recommendation.id,
      );
      await history.recordFeedback(
        B04RecommendationFeedbackCommand(
          userId: userId,
          recommendationId: recommendation.id,
          action: B04RecommendationFeedbackAction.accept,
          source: 'daily_briefing',
          localDate: _dates.localDateFor(createdAtUtc, timezoneId),
          timezoneId: timezoneId,
          createdAtUtc: createdAtUtc,
        ),
      );
      await load(userId: userId, localDate: localDate, timezoneId: timezoneId);
    } catch (error) {
      if (!mounted) return;
      var errorCode = 'daily_briefing_target_acceptance_failed';
      var errorMessage =
          'The target was not accepted. No proposal was changed.';
      if (error is B04GoalValidationError) {
        errorCode = error.code;
        errorMessage = 'The target was not accepted. No changes were made.';
      } else if (error is B04RecommendationHistoryError) {
        errorCode = error.code;
        errorMessage = ProductFailurePresentation.fromCode(error.code).message;
      }
      state = state.copyWith(
        status: B04DailyBriefingControllerStatus.failure,
        errorCode: errorCode,
        errorMessage: errorMessage,
        retryable: true,
      );
    }
  }
}
