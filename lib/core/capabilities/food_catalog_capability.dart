import '../catalog/food_catalog_models.dart';

export '../catalog/food_catalog_models.dart';

/// Contract defining remote food catalog search, barcode lookup, and caching.
///
/// Implementations must enforce the "No Silent Promotion Invariant":
/// Remote candidates retrieved via this capability are read models and are never
/// committed to historical nutrition logs without explicit user review.
abstract class FoodCatalogCapability {
  /// Searches external and cached catalogs for food items matching [query].
  Future<FoodSearchPage> searchRemoteFoods(
    String query, {
    int page = 1,
    int pageSize = 20,
  });

  /// Looks up a product by its EAN-13, UPC-A, or UPC-E [barcode].
  ///
  /// Returns `null` if the barcode is not recognized or network is unavailable.
  Future<RemoteFoodCandidate?> lookupByBarcode(String barcode);

  /// Caches a remote candidate in the local SQLite Tier-1 cache.
  Future<void> cacheRemoteCandidate(RemoteFoodCandidate candidate);

  /// Retrieves a previously cached candidate by its unique [candidateId].
  Future<RemoteFoodCandidate?> getCachedCandidate(String candidateId);

  /// Returns recent cached candidates for offline discovery and instant search.
  Future<List<RemoteFoodCandidate>> getRecentCachedCandidates({int limit = 50});
}

/// Fallback driver used when remote catalog access is disabled or device is offline.
class DisabledFoodCatalogCapability implements FoodCatalogCapability {
  const DisabledFoodCatalogCapability();

  @override
  Future<FoodSearchPage> searchRemoteFoods(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return FoodSearchPage(
      items: const [],
      totalCount: 0,
      page: page,
      hasMore: false,
      query: query,
    );
  }

  @override
  Future<RemoteFoodCandidate?> lookupByBarcode(String barcode) async {
    return null;
  }

  @override
  Future<void> cacheRemoteCandidate(RemoteFoodCandidate candidate) async {}

  @override
  Future<RemoteFoodCandidate?> getCachedCandidate(String candidateId) async {
    return null;
  }

  @override
  Future<List<RemoteFoodCandidate>> getRecentCachedCandidates({
    int limit = 50,
  }) async {
    return const [];
  }
}
