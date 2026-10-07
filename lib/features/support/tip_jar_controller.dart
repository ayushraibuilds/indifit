import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/privacy/privacy_policy.dart';
import '../../core/utils/app_logger.dart';
import 'tip_jar_products.dart';
import 'tip_store.dart';

/// Where loading the tip products got to.
enum TipJarLoad {
  loading,

  /// Offline Mode is on, so the store is never contacted.
  offline,
  storeUnavailable,

  /// The store answered but none of the tip products exist yet.
  productsMissing,
  ready,
  failed,
}

/// Where the current tip purchase is.
enum TipPurchasePhase { idle, inProgress, pending, cancelled, failed, thanked }

class TipJarState {
  const TipJarState({
    this.load = TipJarLoad.loading,
    this.products = const [],
    this.purchase = TipPurchasePhase.idle,
  });

  final TipJarLoad load;
  final List<TipProduct> products;
  final TipPurchasePhase purchase;

  bool get isBusy =>
      purchase == TipPurchasePhase.inProgress ||
      purchase == TipPurchasePhase.pending;

  TipJarState copyWith({
    TipJarLoad? load,
    List<TipProduct>? products,
    TipPurchasePhase? purchase,
  }) => TipJarState(
    load: load ?? this.load,
    products: products ?? this.products,
    purchase: purchase ?? this.purchase,
  );
}

/// Drives the supporter tip jar. Tips unlock nothing; this controller only
/// shows products, starts a purchase and finishes every transaction.
class TipJarController extends StateNotifier<TipJarState> {
  /// [store] is null when Offline Mode is on.
  TipJarController(this._store)
    : super(
        _store == null
            ? const TipJarState(load: TipJarLoad.offline)
            : const TipJarState(),
      ) {
    if (_store != null) unawaited(load());
  }

  final TipStore? _store;
  StreamSubscription<List<TipPurchaseUpdate>>? _subscription;

  Future<void> load() async {
    final store = _store;
    if (store == null) return;
    state = state.copyWith(load: TipJarLoad.loading);
    try {
      if (!await store.isAvailable()) {
        if (mounted) state = state.copyWith(load: TipJarLoad.storeUnavailable);
        return;
      }
      // Listen before querying so any transaction left unfinished from an
      // earlier visit is completed now.
      _subscription ??= store.purchaseUpdates.listen(
        _onUpdates,
        onError: (Object error, StackTrace stackTrace) {
          AppLogger.warning('Tip purchase stream error: $error', 'TipJar');
          if (mounted) {
            state = state.copyWith(purchase: TipPurchasePhase.failed);
          }
        },
      );
      // A tip paid slowly (UPI, pending card) may have cleared after the
      // screen closed; finish it now so the store doesn't refund it.
      unawaited(_recoverUnfinished(store));
      final result = await store.queryProducts(TipJarProducts.ids.toSet());
      if (!mounted) return;
      final byId = {for (final product in result.products) product.id: product};
      final ordered = [
        for (final id in TipJarProducts.ids)
          if (byId[id] != null) byId[id]!,
      ];
      if (ordered.isNotEmpty) {
        state = state.copyWith(load: TipJarLoad.ready, products: ordered);
      } else if (result.errorMessage != null) {
        AppLogger.warning(
          'Tip products query failed: ${result.errorMessage}',
          'TipJar',
        );
        state = state.copyWith(load: TipJarLoad.failed, products: const []);
      } else {
        state = state.copyWith(
          load: TipJarLoad.productsMissing,
          products: const [],
        );
      }
    } catch (error) {
      AppLogger.warning('Tip jar could not reach the store: $error', 'TipJar');
      if (mounted) state = state.copyWith(load: TipJarLoad.failed);
    }
  }

  Future<void> buy(String productId) async {
    final store = _store;
    if (store == null || state.isBusy) return;
    state = state.copyWith(purchase: TipPurchasePhase.inProgress);
    try {
      final sent = await store.buy(productId);
      if (!sent && mounted) {
        state = state.copyWith(purchase: TipPurchasePhase.failed);
      }
    } catch (error) {
      AppLogger.warning('Tip purchase could not start: $error', 'TipJar');
      if (mounted) state = state.copyWith(purchase: TipPurchasePhase.failed);
    }
  }

  Future<void> _recoverUnfinished(TipStore store) async {
    try {
      await store.recoverUnfinished();
    } catch (error) {
      AppLogger.warning(
        'Unfinished tips could not be fetched: $error',
        'TipJar',
      );
    }
  }

  /// Clears a cancelled or failed note once the person has seen it.
  void dismissNotice() {
    if (state.purchase == TipPurchasePhase.cancelled ||
        state.purchase == TipPurchasePhase.failed) {
      state = state.copyWith(purchase: TipPurchasePhase.idle);
    }
  }

  Future<void> _onUpdates(List<TipPurchaseUpdate> updates) async {
    for (final update in updates) {
      // Always finish the transaction first, whatever its outcome, so a
      // consumable tip never gets stuck.
      if (update.needsCompletion) {
        try {
          await _store?.complete(update);
        } catch (error) {
          AppLogger.warning('Tip purchase completion failed: $error', 'TipJar');
        }
      }
      if (!mounted) continue;
      final next = switch (update.status) {
        TipPurchaseStatus.pending => TipPurchasePhase.pending,
        TipPurchaseStatus.purchased => TipPurchasePhase.thanked,
        TipPurchaseStatus.cancelled => TipPurchasePhase.cancelled,
        TipPurchaseStatus.error => TipPurchasePhase.failed,
        // Consumables are never restored; nothing to show.
        TipPurchaseStatus.restored => null,
      };
      if (next != null) state = state.copyWith(purchase: next);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

/// Built only when the tip screen opens. In Offline Mode the store provider
/// is never read, so no store connection is made.
final tipJarControllerProvider =
    StateNotifierProvider.autoDispose<TipJarController, TipJarState>((ref) {
      final offline = ref.watch(
        privacyPolicyProvider.select((policy) => policy.isOfflineOnly),
      );
      return TipJarController(offline ? null : ref.watch(tipStoreProvider));
    });
