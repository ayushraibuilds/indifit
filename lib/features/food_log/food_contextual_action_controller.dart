import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/food_repository.dart';

/// Typed values collected by the existing B03 edit sheet.  B05 transports
/// these values to B03; it does not calculate or reinterpret nutrition facts.
class FoodLogEditValues {
  const FoodLogEditValues({
    required this.name,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.servingLogged,
  });

  final String name;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double servingLogged;
}

/// A narrow B05 seam around B03 food mutations. Widgets invoke this seam
/// rather than reading Drift or owning food-log mutation rules.
abstract interface class FoodContextualActionGateway {
  Future<void> edit({required int id, required FoodLogEditValues values});

  Future<void> copy({
    required FoodLog source,
    required DateTime targetDate,
    required String targetMealType,
  });

  Future<void> delete(FoodLog source);

  /// B03 may expose a supported restore/correction operation in a later
  /// source. The UI must not infer one from the deleted row or restore locally.
  bool get supportsRestore;

  Future<void> restore(FoodLog source);
}

/// Production adapter for the existing B03 legacy FoodRepository.
///
/// FoodRepository currently supports append-only edit corrections and physical
/// deletion, but does not expose a reversible deletion contract. Consequently
/// [supportsRestore] is false and the B05 UI uses a confirmation-only delete
/// flow. Tests and future B03 adapters can opt in only by implementing a real
/// restore/correction operation.
class FoodRepositoryContextualActionGateway
    implements FoodContextualActionGateway {
  const FoodRepositoryContextualActionGateway(this._repository);

  final FoodRepository _repository;

  @override
  Future<void> edit({
    required int id,
    required FoodLogEditValues values,
  }) async {
    final updated = await _repository.updateFoodLog(
      id: id,
      name: values.name,
      calories: values.calories,
      proteinG: values.proteinG,
      carbsG: values.carbsG,
      fatG: values.fatG,
      servingLogged: values.servingLogged,
    );
    if (!updated) {
      throw const FoodContextualUnavailableException(
        'This food entry is no longer available. Refresh to see the latest log.',
      );
    }
  }

  @override
  Future<void> copy({
    required FoodLog source,
    required DateTime targetDate,
    required String targetMealType,
  }) async {
    await _repository.logFoodEntry(
      name: source.name,
      calories: source.calories,
      proteinG: source.proteinG,
      carbsG: source.carbsG,
      fatG: source.fatG,
      servingLogged: source.servingLogged,
      servingUnit: source.servingUnit,
      mealType: targetMealType,
      foodItemId: source.foodItemId,
      loggedAt: targetDate,
    );
  }

  @override
  Future<void> delete(FoodLog source) async {
    final deleted = await _repository.deleteLogEntry(source.id);
    if (deleted == 0) {
      throw const FoodContextualUnavailableException(
        'This food entry is no longer available. Refresh to see the latest log.',
      );
    }
  }

  @override
  bool get supportsRestore => false;

  @override
  Future<void> restore(FoodLog source) {
    throw const FoodContextualUnavailableException(
      'Undo is not available for this food entry.',
    );
  }
}

class FoodContextualUnavailableException implements Exception {
  const FoodContextualUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum FoodContextualAction { edit, copy, delete, undo }

enum FoodContextualActionStatus {
  ready,
  pending,
  success,
  failure,
  unavailable,
}

class FoodDeleteUndoOffer {
  const FoodDeleteUndoOffer({required this.source, required this.expiresAtUtc});

  final FoodLog source;
  final DateTime expiresAtUtc;

  bool isAvailableAt(DateTime nowUtc) => nowUtc.isBefore(expiresAtUtc);
}

class FoodContextualActionState {
  const FoodContextualActionState({
    required this.status,
    this.activeAction,
    this.message,
    this.undoOffer,
  });

  const FoodContextualActionState.ready()
    : status = FoodContextualActionStatus.ready,
      activeAction = null,
      message = null,
      undoOffer = null;

  final FoodContextualActionStatus status;
  final FoodContextualAction? activeAction;
  final String? message;
  final FoodDeleteUndoOffer? undoOffer;

  bool get isPending => status == FoodContextualActionStatus.pending;
  bool get canRetry => status == FoodContextualActionStatus.failure;
}

/// Coordinates transient feedback and optional B03-backed deletion undo.
/// Nothing in this controller derives totals or rolls back a widget-local list.
class FoodContextualActionController
    extends StateNotifier<FoodContextualActionState> {
  FoodContextualActionController({
    required FoodContextualActionGateway gateway,
    required FoodLog source,
    DateTime Function()? nowUtc,
    Duration undoWindow = const Duration(seconds: 10),
  }) : _gateway = gateway,
       _source = source,
       _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _undoWindow = undoWindow,
       super(const FoodContextualActionState.ready());

  final FoodContextualActionGateway _gateway;
  final FoodLog _source;
  final DateTime Function() _nowUtc;
  final Duration _undoWindow;
  Future<void> Function()? _retryAction;

  Future<void> edit(FoodLogEditValues values) async {
    if (state.isPending) return;
    await _run(
      action: FoodContextualAction.edit,
      retry: () => edit(values),
      operation: () async {
        await _gateway.edit(id: _source.id, values: values);
        _succeed('Food entry updated.');
      },
    );
  }

  Future<void> copy({DateTime? targetDate, String? targetMealType}) async {
    if (state.isPending) return;
    await _run(
      action: FoodContextualAction.copy,
      retry: () => copy(targetDate: targetDate, targetMealType: targetMealType),
      operation: () async {
        await _gateway.copy(
          source: _source,
          targetDate: targetDate ?? _source.loggedAt,
          targetMealType: targetMealType ?? _source.mealType,
        );
        _succeed('Food entry copied.');
      },
    );
  }

  Future<void> delete() async {
    if (state.isPending) return;
    await _run(
      action: FoodContextualAction.delete,
      retry: delete,
      operation: () async {
        await _gateway.delete(_source);
        if (!mounted) return;
        _retryAction = null;
        final offer = _gateway.supportsRestore
            ? FoodDeleteUndoOffer(
                source: _source,
                expiresAtUtc: _nowUtc().add(_undoWindow),
              )
            : null;
        state = FoodContextualActionState(
          status: FoodContextualActionStatus.success,
          message: offer == null
              ? 'Food entry deleted. Undo is unavailable for this entry.'
              : 'Food entry deleted. Undo is available briefly.',
          undoOffer: offer,
        );
      },
    );
  }

  Future<void> undo() async {
    if (state.isPending) return;
    final offer = state.undoOffer;
    if (offer == null || !_gateway.supportsRestore) {
      _setUnavailable('Undo is not available for this food entry.');
      return;
    }
    if (!offer.isAvailableAt(_nowUtc())) {
      state = const FoodContextualActionState.ready();
      return;
    }
    await _run(
      action: FoodContextualAction.undo,
      retry: undo,
      operation: () async {
        await _gateway.restore(offer.source);
        _succeed('Food entry restored.');
      },
    );
  }

  void expireUndo() {
    if (state.undoOffer == null || state.isPending) return;
    state = const FoodContextualActionState.ready();
  }

  Future<void> retry() async {
    if (state.isPending) return;
    final retry = _retryAction;
    if (retry != null) await retry();
  }

  Future<void> _run({
    required FoodContextualAction action,
    required Future<void> Function() retry,
    required Future<void> Function() operation,
  }) async {
    state = FoodContextualActionState(
      status: FoodContextualActionStatus.pending,
      activeAction: action,
    );
    try {
      await operation();
    } on FoodContextualUnavailableException catch (error) {
      _setUnavailable(error.message);
    } catch (error) {
      if (!mounted) return;
      _retryAction = retry;
      state = FoodContextualActionState(
        status: FoodContextualActionStatus.failure,
        activeAction: action,
        message: 'Could not update this food entry: $error',
      );
    }
  }

  void _succeed(String message) {
    if (!mounted) return;
    _retryAction = null;
    state = FoodContextualActionState(
      status: FoodContextualActionStatus.success,
      message: message,
    );
  }

  void _setUnavailable(String message) {
    if (!mounted) return;
    _retryAction = null;
    state = FoodContextualActionState(
      status: FoodContextualActionStatus.unavailable,
      message: message,
    );
  }
}

final foodContextualActionGatewayProvider =
    Provider<FoodContextualActionGateway>((ref) {
      return FoodRepositoryContextualActionGateway(
        ref.watch(foodRepositoryProvider),
      );
    });

final foodContextualActionControllerProvider = StateNotifierProvider.autoDispose
    .family<FoodContextualActionController, FoodContextualActionState, FoodLog>(
      (ref, source) {
        return FoodContextualActionController(
          gateway: ref.watch(foodContextualActionGatewayProvider),
          source: source,
        );
      },
    );
