import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../data/models/b02_progress_read_models.dart';
import '../../data/repositories/b02_progress_read_repository.dart';

enum B02ProgressStatus { loading, ready, partial, failure, recovery }

class B02ProgressState {
  final B02ProgressStatus status;
  final B02ProgressReadModel? data;
  final List<String> issues;
  final Object? error;

  const B02ProgressState({
    required this.status,
    required this.data,
    required this.issues,
    required this.error,
  });

  const B02ProgressState.loading({B02ProgressReadModel? data})
    : this(
        status: B02ProgressStatus.loading,
        data: data,
        issues: const [],
        error: null,
      );

  B02ProgressState copyWith({
    B02ProgressStatus? status,
    B02ProgressReadModel? data,
    bool clearData = false,
    List<String>? issues,
    Object? error,
    bool clearError = false,
  }) {
    return B02ProgressState(
      status: status ?? this.status,
      data: clearData ? null : (data ?? this.data),
      issues: issues ?? this.issues,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get isLoading => status == B02ProgressStatus.loading;
}

class B02ProgressController extends StateNotifier<B02ProgressState> {
  final B02ProgressReadSource _source;
  B02ProgressQuery _lastQuery;
  int _requestNumber = 0;

  B02ProgressController(this._source, {B02ProgressQuery? initialQuery})
    : _lastQuery = initialQuery ?? B02ProgressQuery.recentUtc(),
      super(const B02ProgressState.loading());

  Future<void> load([B02ProgressQuery? query]) async {
    final selectedQuery = query ?? _lastQuery;
    _lastQuery = selectedQuery;
    final request = ++_requestNumber;
    final previous = state.data;
    state = B02ProgressState.loading(data: previous);

    final activity = await _readPart(
      'Activity history',
      () => _source.readActivityHistory(selectedQuery),
    );
    final groups = await _readPart(
      'Group history',
      () => _source.readGroupHistory(selectedQuery),
    );
    final targets = await _readPart(
      'Suggested targets',
      () => _source.readTargetEvidence(selectedQuery),
    );
    final muscle = await _readPart(
      'Muscle volume',
      () => _source.readMuscleVolume(selectedQuery),
    );
    if (!mounted || request != _requestNumber) return;

    final issues = [
      ...activity.issues,
      ...groups.issues,
      ...targets.issues,
      ...muscle.issues,
    ];
    final successes = [
      activity,
      groups,
      targets,
      muscle,
    ].where((part) => part.value != null).length;
    final model = B02ProgressReadModel(
      query: selectedQuery,
      activityHistory: activity.value ?? previous?.activityHistory,
      groupHistory: groups.value ?? previous?.groupHistory,
      targetEvidence: targets.value ?? previous?.targetEvidence,
      muscleVolume: muscle.value ?? previous?.muscleVolume,
    );
    if (issues.isEmpty) {
      state = B02ProgressState(
        status: B02ProgressStatus.ready,
        data: model,
        issues: const [],
        error: null,
      );
      return;
    }
    if (successes == 0) {
      state = B02ProgressState(
        status: previous == null
            ? B02ProgressStatus.failure
            : B02ProgressStatus.recovery,
        data: previous == null ? null : model,
        issues: issues,
        error: issues.first,
      );
      return;
    }
    state = B02ProgressState(
      status: B02ProgressStatus.partial,
      data: model,
      issues: issues,
      error: issues.first,
    );
  }

  Future<void> retry() => load(_lastQuery);

  Future<_B02ProgressPart<T>> _readPart<T>(
    String label,
    Future<T> Function() read,
  ) async {
    try {
      return _B02ProgressPart<T>(value: await read());
    } catch (error) {
      // The failure remains in the state and is rendered by the card. It is
      // not converted into an empty value, so unknown never becomes zero.
      return _B02ProgressPart<T>(issues: ['$label unavailable']);
    }
  }
}

class _B02ProgressPart<T> {
  final T? value;
  final List<String> issues;

  const _B02ProgressPart({this.value, this.issues = const []});
}

final b02ProgressReadSourceProvider = Provider<B02ProgressReadSource>((ref) {
  return B02ProgressReadRepository(ref.watch(databaseProvider));
});

final b02ProgressControllerProvider =
    StateNotifierProvider<B02ProgressController, B02ProgressState>((ref) {
      final controller = B02ProgressController(
        ref.watch(b02ProgressReadSourceProvider),
      );
      unawaited(controller.load());
      return controller;
    });
