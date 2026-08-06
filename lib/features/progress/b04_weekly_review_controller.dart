import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/local_schedule_date_service.dart';
import '../../data/models/b04_briefing_read_models.dart';
import '../../data/models/b04_goal_models.dart';
import '../../data/models/b04_recommendation_history_models.dart';
import '../../data/repositories/b04_briefing_read_repositories.dart';
import '../../data/repositories/b04_recommendation_history_repository.dart';
import '../../data/repositories/coaching_preference_repository.dart';
import '../../data/repositories/nutrition_goal_repository.dart';

enum B04WeeklyReviewControllerStatus {
  idle,
  loading,
  ready,
  noData,
  unavailable,
  failure,
}

class B04WeeklyReviewState {
  final B04WeeklyReviewControllerStatus status;
  final B04WeeklyReviewReadModel? review;
  final String? errorCode;
  final String? errorMessage;
  final bool retryable;

  const B04WeeklyReviewState({
    this.status = B04WeeklyReviewControllerStatus.idle,
    this.review,
    this.errorCode,
    this.errorMessage,
    this.retryable = false,
  });

  bool get isLoading => status == B04WeeklyReviewControllerStatus.loading;

  B04WeeklyReviewState copyWith({
    B04WeeklyReviewControllerStatus? status,
    Object? review = _unset,
    Object? errorCode = _unset,
    Object? errorMessage = _unset,
    bool? retryable,
  }) => B04WeeklyReviewState(
    status: status ?? this.status,
    review: review == _unset
        ? this.review
        : review as B04WeeklyReviewReadModel?,
    errorCode: errorCode == _unset ? this.errorCode : errorCode as String?,
    errorMessage: errorMessage == _unset
        ? this.errorMessage
        : errorMessage as String?,
    retryable: retryable ?? this.retryable,
  );
}

const _unset = Object();

/// Controller for the progress-facing B04 weekly projection. The caller owns
/// period selection; this controller never changes it to a rolling or named
/// calendar week.
class B04WeeklyReviewController extends StateNotifier<B04WeeklyReviewState> {
  final B04WeeklyReviewReadRepository _repository;
  final B04RecommendationHistoryRepository? _history;
  final NutritionGoalRepository? _goals;
  final CoachingPreferenceRepository? _preferences;
  final LocalScheduleDateService _dates;
  String? _userId;
  String? _startLocalDate;
  String? _endLocalDate;
  String? _timezoneId;
  int _generation = 0;

  B04WeeklyReviewController({
    required B04WeeklyReviewReadRepository repository,
    B04RecommendationHistoryRepository? history,
    NutritionGoalRepository? goals,
    CoachingPreferenceRepository? preferences,
    LocalScheduleDateService? dates,
  }) : _repository = repository,
       _history = history,
       _goals = goals,
       _preferences = preferences,
       _dates = dates ?? LocalScheduleDateService(),
       super(const B04WeeklyReviewState());

  Future<void> load({
    required String userId,
    required String startLocalDate,
    required String endLocalDate,
    required String timezoneId,
  }) async {
    final generation = ++_generation;
    _userId = userId;
    _startLocalDate = startLocalDate;
    _endLocalDate = endLocalDate;
    _timezoneId = timezoneId;
    state = state.copyWith(
      status: B04WeeklyReviewControllerStatus.loading,
      review: null,
      errorCode: null,
      errorMessage: null,
      retryable: false,
    );
    try {
      final review = await _repository.read(
        userId: userId,
        startLocalDate: startLocalDate,
        endLocalDate: endLocalDate,
        timezoneId: timezoneId,
      );
      if (!mounted || generation != _generation) return;
      final status = switch (review.status) {
        B04BriefingReadStatus.available =>
          B04WeeklyReviewControllerStatus.ready,
        B04BriefingReadStatus.noData => B04WeeklyReviewControllerStatus.noData,
        B04BriefingReadStatus.unavailable =>
          B04WeeklyReviewControllerStatus.unavailable,
      };
      state = state.copyWith(
        status: status,
        review: review,
        errorCode: null,
        errorMessage: null,
        retryable: false,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      final typed = error is B04BriefingReadRepositoryError ? error : null;
      state = state.copyWith(
        status: B04WeeklyReviewControllerStatus.failure,
        review: null,
        errorCode: typed?.code ?? 'weekly_review_read_failed',
        errorMessage:
            typed?.message ??
            'The weekly review could not be loaded. You can retry.',
        retryable: true,
      );
    }
  }

  Future<void> retry() async {
    final userId = _userId;
    final start = _startLocalDate;
    final end = _endLocalDate;
    final timezoneId = _timezoneId;
    if (userId == null || start == null || end == null || timezoneId == null) {
      return;
    }
    await load(
      userId: userId,
      startLocalDate: start,
      endLocalDate: end,
      timezoneId: timezoneId,
    );
  }

  Future<void> recordFeedback({
    required String recommendationId,
    required B04RecommendationFeedbackAction action,
    String? reason,
  }) async {
    final history = _history;
    final userId = _userId;
    final start = _startLocalDate;
    final end = _endLocalDate;
    final timezoneId = _timezoneId;
    if (history == null ||
        userId == null ||
        start == null ||
        end == null ||
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
          source: 'weekly_review',
          localDate: _dates.localDateFor(createdAtUtc, timezoneId),
          timezoneId: timezoneId,
          createdAtUtc: createdAtUtc,
        ),
      );
      await load(
        userId: userId,
        startLocalDate: start,
        endLocalDate: end,
        timezoneId: timezoneId,
      );
    } catch (error) {
      if (!mounted) return;
      final typed = error is B04RecommendationHistoryError ? error : null;
      state = state.copyWith(
        status: B04WeeklyReviewControllerStatus.failure,
        errorCode: typed?.code ?? 'weekly_review_feedback_failed',
        errorMessage:
            typed?.message ?? 'That feedback could not be recorded. Retry.',
        retryable: true,
      );
    }
  }

  Future<void> acceptTarget(B04BriefingRecommendation recommendation) async {
    final goals = _goals;
    final preferences = _preferences;
    final history = _history;
    final userId = _userId;
    final start = _startLocalDate;
    final end = _endLocalDate;
    final timezoneId = _timezoneId;
    final proposal =
        recommendation.engineRecommendation?.canonicalAdaptiveTarget?.proposal;
    if (goals == null ||
        preferences == null ||
        history == null ||
        userId == null ||
        start == null ||
        end == null ||
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
          source: 'weekly_review',
          localDate: _dates.localDateFor(createdAtUtc, timezoneId),
          timezoneId: timezoneId,
          createdAtUtc: createdAtUtc,
        ),
      );
      await load(
        userId: userId,
        startLocalDate: start,
        endLocalDate: end,
        timezoneId: timezoneId,
      );
    } catch (error) {
      if (!mounted) return;
      var errorCode = 'weekly_review_target_acceptance_failed';
      var errorMessage =
          'The target was not accepted. No proposal was changed.';
      if (error is B04GoalValidationError) {
        errorCode = error.code;
        errorMessage = error.message;
      } else if (error is B04RecommendationHistoryError) {
        errorCode = error.code;
        errorMessage = error.toString();
      }
      state = state.copyWith(
        status: B04WeeklyReviewControllerStatus.failure,
        errorCode: errorCode,
        errorMessage: errorMessage,
        retryable: true,
      );
    }
  }
}
