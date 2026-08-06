import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/b04_briefing_read_models.dart';
import '../../data/repositories/b04_briefing_read_repositories.dart';

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
  String? _userId;
  String? _startLocalDate;
  String? _endLocalDate;
  String? _timezoneId;
  int _generation = 0;

  B04WeeklyReviewController({required B04WeeklyReviewReadRepository repository})
    : _repository = repository,
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
}
