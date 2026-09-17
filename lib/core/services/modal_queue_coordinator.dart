import 'dart:async';
import 'package:flutter/widgets.dart';

/// Coordinates modal bottom sheets and dialogs to prevent collision.
/// Ensures celebration sheets or alerts do not overlap with active modals (e.g. rest timer).
class ModalQueueCoordinator {
  ModalQueueCoordinator._();

  static final ModalQueueCoordinator instance = ModalQueueCoordinator._();

  int _activeModalCount = 0;
  final List<void Function()> _queue = [];

  int get activeModalCount => _activeModalCount;
  bool get isModalActive => _activeModalCount > 0;
  int get queueLength => _queue.length;

  /// Call when a modal sheet is presented.
  void markModalActive() {
    _activeModalCount++;
  }

  /// Call when a modal sheet is dismissed.
  void markModalDismissed() {
    if (_activeModalCount > 0) {
      _activeModalCount--;
    }
    _drainNext();
  }

  /// Enqueues a modal presentation.
  /// If no modal is active, runs immediately.
  /// If a modal is active, waits until all active modals are dismissed.
  Future<T?> enqueueModal<T>({
    required BuildContext context,
    required Future<T?> Function() showModal,
  }) {
    final completer = Completer<T?>();

    void execute() {
      if (!context.mounted) {
        completer.complete(null);
        _drainNext();
        return;
      }
      markModalActive();
      showModal().then((result) {
        completer.complete(result);
      }).catchError((Object error, StackTrace stackTrace) {
        completer.completeError(error, stackTrace);
      }).whenComplete(() {
        markModalDismissed();
      });
    }

    if (_activeModalCount == 0) {
      execute();
    } else {
      _queue.add(execute);
    }

    return completer.future;
  }

  void _drainNext() {
    if (_activeModalCount == 0 && _queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      next();
    }
  }

  @visibleForTesting
  void resetForTest() {
    _activeModalCount = 0;
    _queue.clear();
  }
}
