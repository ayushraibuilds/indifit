/// Store product IDs for the supporter tip jar.
///
/// Tips are consumable in-app purchases that unlock nothing. The owner creates
/// these three products, with these exact IDs, in BOTH App Store Connect
/// (type: Consumable) and the Google Play Console (one-time products). Until
/// they exist, the tip screen shows a friendly "not set up yet" message.
///
/// Suggested prices: ₹49, ₹99 and ₹199. Prices shown in the app always come
/// from the store, so they are localized and never hard-coded here.
abstract final class TipJarProducts {
  static const String small = 'indifit_tip_small';
  static const String medium = 'indifit_tip_medium';
  static const String large = 'indifit_tip_large';

  /// Display order on the tip screen (smallest first).
  static const List<String> ids = [small, medium, large];

  /// Plain labels shown beside each store price.
  static const Map<String, String> labels = {
    small: 'Buy a chai',
    medium: 'Chai and a snack',
    large: 'Buy a thali',
  };
}
