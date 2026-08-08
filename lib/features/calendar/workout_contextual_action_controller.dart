import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/calendar_repository.dart';

/// B05 presentation adapter for a B01 occurrence action. It stores only
/// short-lived UI state; occurrence transitions and inverse validity remain
/// owned by [CalendarRepository].
abstract interface class WorkoutOccurrenceActionGateway {
  Future<ScheduledSessionOccurrence?> getOccurrence(String occurrenceId);

  Future<OccurrenceMutationResult> skip(SkipOccurrenceCommand command);

  Future<OccurrenceMutationResult> restore(RestoreOccurrenceCommand command);
}

class CalendarWorkoutOccurrenceActionGateway
    implements WorkoutOccurrenceActionGateway {
  const CalendarWorkoutOccurrenceActionGateway(this._repository);

  final CalendarRepository _repository;

  @override
  Future<ScheduledSessionOccurrence?> getOccurrence(String occurrenceId) =>
      _repository.getOccurrence(occurrenceId);

  @override
  Future<OccurrenceMutationResult> skip(SkipOccurrenceCommand command) =>
      _repository.skip(command);

  @override
  Future<OccurrenceMutationResult> restore(RestoreOccurrenceCommand command) =>
      _repository.restore(command);
}

enum WorkoutOccurrenceAction { skip, undo }

enum WorkoutOccurrenceActionStatus {
  ready,
  pending,
  success,
  failure,
  unavailable,
}

class WorkoutOccurrenceUndoOffer {
  const WorkoutOccurrenceUndoOffer({
    required this.occurrenceId,
    required this.expiresAtUtc,
  });

  final String occurrenceId;
  final DateTime expiresAtUtc;

  bool isAvailableAt(DateTime nowUtc) => nowUtc.isBefore(expiresAtUtc);
}

class WorkoutOccurrenceActionState {
  const WorkoutOccurrenceActionState({
    required this.status,
    this.activeAction,
    this.message,
    this.undoOffer,
  });

  const WorkoutOccurrenceActionState.ready()
    : status = WorkoutOccurrenceActionStatus.ready,
      activeAction = null,
      message = null,
      undoOffer = null;

  final WorkoutOccurrenceActionStatus status;
  final WorkoutOccurrenceAction? activeAction;
  final String? message;
  final WorkoutOccurrenceUndoOffer? undoOffer;

  bool get isPending => status == WorkoutOccurrenceActionStatus.pending;

  bool get canRetry => status == WorkoutOccurrenceActionStatus.failure;
}

/// Coordinates pending/failure/undo feedback while retaining B01 as the sole
/// owner of occurrence transitions and their downstream validity checks.
class WorkoutOccurrenceActionController
    extends StateNotifier<WorkoutOccurrenceActionState> {
  WorkoutOccurrenceActionController({
    required WorkoutOccurrenceActionGateway gateway,
    required String occurrenceId,
    Uuid? uuid,
    DateTime Function()? nowUtc,
    Duration undoWindow = const Duration(seconds: 10),
  }) : _gateway = gateway,
       _occurrenceId = occurrenceId,
       _uuid = uuid ?? const Uuid(),
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _undoWindow = undoWindow,
       super(const WorkoutOccurrenceActionState.ready());

  final WorkoutOccurrenceActionGateway _gateway;
  final String _occurrenceId;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;
  final Duration _undoWindow;
  Future<void> Function()? _retryAction;

  Future<void> skip(SkipDisposition disposition) async {
    if (state.isPending) return;
    await _run(
      action: WorkoutOccurrenceAction.skip,
      retry: () => skip(disposition),
      operation: () async {
        final occurrence = await _gateway.getOccurrence(_occurrenceId);
        if (occurrence == null) {
          _setUnavailable(
            'This workout is no longer available. Refresh to see the latest plan.',
          );
          return;
        }
        late final OccurrenceStatus status;
        try {
          status = _parseStatus(occurrence.status);
        } on StateError {
          _setUnavailable(
            'This workout is not available in the latest plan. Refresh and try again.',
          );
          return;
        }
        if (status != OccurrenceStatus.planned &&
            status != OccurrenceStatus.rescheduled) {
          _setUnavailable(
            'This workout cannot be skipped in its current state. Refresh to see the latest plan.',
          );
          return;
        }
        await _gateway.skip(
          SkipOccurrenceCommand(
            occurrenceId: _occurrenceId,
            commandId: _uuid.v4(),
            expectedStatus: status,
            disposition: disposition,
            reason: 'User chose a contextual workout action.',
          ),
        );
        if (!mounted) return;
        _retryAction = null;
        state = WorkoutOccurrenceActionState(
          status: WorkoutOccurrenceActionStatus.success,
          message: 'Workout skipped. Undo is available briefly.',
          undoOffer: WorkoutOccurrenceUndoOffer(
            occurrenceId: _occurrenceId,
            expiresAtUtc: _nowUtc().add(_undoWindow),
          ),
        );
      },
    );
  }

  Future<void> undo() async {
    if (state.isPending) return;
    final offer = state.undoOffer;
    if (offer == null) {
      _setUnavailable('Undo is not available for this workout action.');
      return;
    }
    if (!offer.isAvailableAt(_nowUtc())) {
      state = const WorkoutOccurrenceActionState.ready();
      return;
    }
    await _run(
      action: WorkoutOccurrenceAction.undo,
      retry: undo,
      operation: () async {
        final occurrence = await _gateway.getOccurrence(offer.occurrenceId);
        if (occurrence == null ||
            occurrence.status != OccurrenceStatus.skipped.dbValue) {
          _setUnavailable(
            'Undo is no longer available because this workout has changed. Refresh to see the latest plan.',
          );
          return;
        }
        await _gateway.restore(
          RestoreOccurrenceCommand(
            occurrenceId: offer.occurrenceId,
            commandId: _uuid.v4(),
            expectedStatus: OccurrenceStatus.skipped,
          ),
        );
        if (!mounted) return;
        _retryAction = null;
        state = const WorkoutOccurrenceActionState(
          status: WorkoutOccurrenceActionStatus.success,
          message: 'Workout restored to the plan.',
        );
      },
    );
  }

  void expireUndo() {
    if (state.undoOffer == null || state.isPending) return;
    state = const WorkoutOccurrenceActionState.ready();
  }

  Future<void> retry() async {
    if (state.isPending) return;
    final retry = _retryAction;
    if (retry != null) await retry();
  }

  Future<void> _run({
    required WorkoutOccurrenceAction action,
    required Future<void> Function() retry,
    required Future<void> Function() operation,
  }) async {
    state = WorkoutOccurrenceActionState(
      status: WorkoutOccurrenceActionStatus.pending,
      activeAction: action,
    );
    try {
      await operation();
    } on InvalidOccurrenceTransitionException catch (error) {
      if (mounted) {
        _setUnavailable(_transitionMessage(error.message));
      }
    } catch (error) {
      if (!mounted) return;
      _retryAction = retry;
      state = WorkoutOccurrenceActionState(
        status: WorkoutOccurrenceActionStatus.failure,
        activeAction: action,
        message: 'Could not update this workout. Try again.',
      );
    }
  }

  void _setUnavailable(String message) {
    if (!mounted) return;
    _retryAction = null;
    state = WorkoutOccurrenceActionState(
      status: WorkoutOccurrenceActionStatus.unavailable,
      message: message,
    );
  }

  static OccurrenceStatus _parseStatus(String value) =>
      OccurrenceStatus.values.firstWhere(
        (status) => status.dbValue == value,
        orElse: () => throw StateError('Unknown occurrence status: $value'),
      );

  static String _transitionMessage(String message) => switch (message.trim()) {
    'A later workout has started.' => 'A later workout has started.',
    _ =>
      'This workout changed before the action completed. Refresh and try again.',
  };
}

final workoutOccurrenceActionGatewayProvider =
    Provider<WorkoutOccurrenceActionGateway>((ref) {
      return CalendarWorkoutOccurrenceActionGateway(
        ref.watch(calendarRepositoryProvider),
      );
    });

final workoutOccurrenceActionControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      WorkoutOccurrenceActionController,
      WorkoutOccurrenceActionState,
      String
    >((ref, occurrenceId) {
      return WorkoutOccurrenceActionController(
        gateway: ref.watch(workoutOccurrenceActionGatewayProvider),
        occurrenceId: occurrenceId,
      );
    });
