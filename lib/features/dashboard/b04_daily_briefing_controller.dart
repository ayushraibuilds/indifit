import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/b04_briefing_read_models.dart';
import '../../data/repositories/b04_briefing_read_repositories.dart';

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
  String? _userId;
  String? _localDate;
  String? _timezoneId;
  int _generation = 0;

  B04DailyBriefingController({
    required B04DailyBriefingReadRepository repository,
  }) : _repository = repository,
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
      final briefing = await _repository.read(
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
        errorMessage:
            typed?.message ??
            'The daily briefing could not be loaded. You can retry.',
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
}
