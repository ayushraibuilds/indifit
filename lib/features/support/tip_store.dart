import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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

  /// Finishes a transaction (acknowledge and consume on Android, finish on
  /// iOS). Safe to call for any update with [TipPurchaseUpdate.needsCompletion].
  Future<void> complete(TipPurchaseUpdate update);
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
        (purchases) => [
          for (final purchase in purchases)
            TipPurchaseUpdate(
              productId: purchase.productID,
              status: switch (purchase.status) {
                PurchaseStatus.pending => TipPurchaseStatus.pending,
                PurchaseStatus.purchased => TipPurchaseStatus.purchased,
                PurchaseStatus.canceled => TipPurchaseStatus.cancelled,
                PurchaseStatus.error => TipPurchaseStatus.error,
                PurchaseStatus.restored => TipPurchaseStatus.restored,
              },
              needsCompletion: purchase.pendingCompletePurchase,
              errorCode: purchase.error?.code,
              platformPurchase: purchase,
            ),
        ],
      );

  @override
  Future<bool> buy(String productId) async {
    final details = _details[productId];
    if (details == null) return false;
    // Consumable with autoConsume: a tip can be given again and never turns
    // into an owned item.
    return _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  @override
  Future<void> complete(TipPurchaseUpdate update) async {
    final purchase = update.platformPurchase;
    if (purchase is PurchaseDetails && purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }
}

/// Creating the store is lazy: Riverpod builds it only when the tip screen
/// reads it, never at app start.
final tipStoreProvider = Provider<TipStore>((ref) => InAppPurchaseTipStore());
