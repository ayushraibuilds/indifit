import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show BillingResponse;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../core/utils/app_logger.dart';

/// A tip product as the store reports it. [price] is the store's own
/// localized price string (for example "₹49.00").
class TipProduct {
  const TipProduct({
    required this.id,
    required this.title,
    required this.price,
  });

  final String id;
  final String title;
  final String price;
}

/// Result of asking the store for the tip products.
class TipProductQuery {
  const TipProductQuery({
    required this.products,
    this.notFoundIds = const [],
    this.errorMessage,
  });

  final List<TipProduct> products;
  final List<String> notFoundIds;
  final String? errorMessage;
}

enum TipPurchaseStatus { pending, purchased, cancelled, error, restored }

/// One purchase update from the store.
class TipPurchaseUpdate {
  const TipPurchaseUpdate({
    required this.productId,
    required this.status,
    this.needsCompletion = false,
    this.errorCode,
    this.platformPurchase,
  });

  final String productId;
  final TipPurchaseStatus status;

  /// True when the store is waiting for the app to finish this transaction.
  /// It must be completed, or a consumable tip stays stuck.
  final bool needsCompletion;
  final String? errorCode;

  /// The plugin's own purchase object, kept so [TipStore.complete] can hand
  /// it back. Fakes leave it null.
  final Object? platformPurchase;
}

/// How a store transaction is finished.
enum TipCompletion {
  /// Nothing to do: the store isn't waiting on this transaction.
  none,

  /// Finish it (iOS `finishTransaction`, Android acknowledge).
  complete,

  /// Android: consume it. Consuming also acknowledges, so Play never
  /// refunds it, and the same tip can be given again.
  consume,
}

/// How to finish a tip transaction. Every tip is a consumable, so on Android
/// a purchased or recovered tip is always consumed by the app itself: the
/// plugin's auto-consume only covers a purchase that completes in the same
/// app session as its `buy`, so a slow payment (UPI, pending card) that
/// clears after the person left would otherwise stay unconsumed and be
/// refunded after three days.
TipCompletion tipCompletionFor({
  required TipPurchaseStatus status,
  required bool pendingCompletePurchase,
  required bool isAndroid,
}) {
  if (isAndroid &&
      (status == TipPurchaseStatus.purchased ||
          status == TipPurchaseStatus.restored)) {
    return TipCompletion.consume;
  }
  return pendingCompletePurchase ? TipCompletion.complete : TipCompletion.none;
}

/// The small slice of the store that the tip jar needs.
///
/// Wrapping `InAppPurchase` keeps the plugin out of widget tests and makes
/// sure nothing talks to the store until the tip screen asks it to.
abstract interface class TipStore {
  Future<bool> isAvailable();

  Future<TipProductQuery> queryProducts(Set<String> ids);

  Stream<List<TipPurchaseUpdate>> get purchaseUpdates;

  /// Starts the store's purchase sheet. Returns false if the request could
  /// not be sent.
  Future<bool> buy(String productId);

  /// Finishes a transaction (consume on Android, finish on iOS). Safe to
  /// call for any update with [TipPurchaseUpdate.needsCompletion].
  Future<void> complete(TipPurchaseUpdate update);

  /// Asks the store again for tips it is still waiting on the app to finish,
  /// so they arrive on [purchaseUpdates]. Android only: Play hands back
  /// unconsumed purchases (for example a UPI payment that cleared after the
  /// tip screen closed). iOS re-delivers unfinished transactions on its own
  /// once [purchaseUpdates] is listened to, without the Apple ID prompt a
  /// restore can show.
  Future<void> recoverUnfinished();
}

/// The real store, backed by `in_app_purchase`.
///
/// `InAppPurchase.instance` is only touched inside these methods, so creating
/// this object does not open a store connection.
class InAppPurchaseTipStore implements TipStore {
  InAppPurchaseTipStore([InAppPurchase? plugin]) : _plugin = plugin;

  InAppPurchase? _plugin;
  final Map<String, ProductDetails> _details = {};

  InAppPurchase get _iap => _plugin ??= InAppPurchase.instance;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<TipProductQuery> queryProducts(Set<String> ids) async {
    final response = await _iap.queryProductDetails(ids);
    for (final details in response.productDetails) {
      _details[details.id] = details;
    }
    return TipProductQuery(
      products: [
        for (final details in response.productDetails)
          TipProduct(
            id: details.id,
            title: details.title,
            price: details.price,
          ),
      ],
      notFoundIds: response.notFoundIDs,
      errorMessage: response.error?.message,
    );
  }

  @override
  Stream<List<TipPurchaseUpdate>> get purchaseUpdates =>
      _iap.purchaseStream.map(
        (purchases) => [for (final purchase in purchases) _update(purchase)],
      );

  static TipPurchaseUpdate _update(PurchaseDetails purchase) {
    final status = switch (purchase.status) {
      PurchaseStatus.pending => TipPurchaseStatus.pending,
      PurchaseStatus.purchased => TipPurchaseStatus.purchased,
      PurchaseStatus.canceled => TipPurchaseStatus.cancelled,
      PurchaseStatus.error => TipPurchaseStatus.error,
      PurchaseStatus.restored => TipPurchaseStatus.restored,
    };
    final completion = tipCompletionFor(
      status: status,
      pendingCompletePurchase: purchase.pendingCompletePurchase,
      isAndroid: purchase is GooglePlayPurchaseDetails,
    );
    return TipPurchaseUpdate(
      productId: purchase.productID,
      status: status,
      needsCompletion: completion != TipCompletion.none,
      errorCode: purchase.error?.code,
      platformPurchase: purchase,
    );
  }

  @override
  Future<bool> buy(String productId) async {
    final details = _details[productId];
    if (details == null) return false;
    // A consumable, so a tip never turns into an owned item. The app consumes
    // it in [complete] rather than relying on auto-consume, which only lasts
    // for this app session (see [tipCompletionFor]).
    return _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
      autoConsume: false,
    );
  }

  @override
  Future<void> complete(TipPurchaseUpdate update) async {
    final purchase = update.platformPurchase;
    if (purchase is! PurchaseDetails) return;
    switch (tipCompletionFor(
      status: update.status,
      pendingCompletePurchase: purchase.pendingCompletePurchase,
      isAndroid: purchase is GooglePlayPurchaseDetails,
    )) {
      case TipCompletion.none:
        return;
      case TipCompletion.complete:
        await _iap.completePurchase(purchase);
      case TipCompletion.consume:
        final result = await _iap
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
            .consumePurchase(purchase);
        if (result.responseCode != BillingResponse.ok) {
          // Play keeps it unconsumed; the next visit's recoverUnfinished
          // hands it back to try again.
          AppLogger.warning(
            'Tip consume failed: ${result.responseCode}',
            'TipJar',
          );
        }
    }
  }

  @override
  Future<void> recoverUnfinished() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _iap.restorePurchases();
  }
}

/// Creating the store is lazy: Riverpod builds it only when the tip screen
/// reads it, never at app start.
final tipStoreProvider = Provider<TipStore>((ref) => InAppPurchaseTipStore());
