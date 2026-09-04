/// Superseded by [FoodCatalogCapability] (`food_catalog_capability.dart`).
///
/// This NET-01A-era abstraction and its serving-size-based [RemoteFoodCandidate]
/// have no live callers (verified: only the registry default driver and one
/// NET-01A contract test reference the disabled driver). Do not build new
/// features on this contract; it is retained without deletion per the
/// retired-code inventory process (PV1-ENG-03/C1B) and will be removed there.
@Deprecated('Superseded; see doc comment above.')
class RemoteFoodCandidate {
  const RemoteFoodCandidate({
    required this.providerId,
    required this.externalId,
    required this.name,
    this.brand,
    this.barcode,
    required this.servingSizeG,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.micros = const {},
  });

  final String providerId;
  final String externalId;
  final String name;
  final String? brand;
  final String? barcode;
  final double servingSizeG;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final Map<String, double> micros;
}

/// Abstract contract for online food and barcode catalogue lookups.
///
/// Superseded by [FoodCatalogCapability]. Retained without deletion per the
/// retired-code inventory process (PV1-ENG-03/C1B).
///
/// Invariant: Remote results remain clearly visually distinct from local
/// canonical foods until explicitly logged, reviewed, or saved. Once logged,
/// results are cached locally and work offline.
@Deprecated('Superseded; see doc comment above.')
abstract class RemoteCatalogueCapability {
  /// Whether the remote food search service is available.
  bool get isAvailable;

  /// Searches the remote food database by text query.
  Future<List<RemoteFoodCandidate>> searchFoods(
    String query, {
    int limit = 20,
  });

  /// Looks up a packaged product by its barcode.
  Future<RemoteFoodCandidate?> lookupBarcode(String barcode);
}

/// Default disabled implementation for offline-only operation.
///
/// Superseded by [DisabledFoodCatalogCapability] in `food_catalog_capability.dart`.
@Deprecated('Superseded; see doc comment above.')
class DisabledRemoteCatalogueCapability implements RemoteCatalogueCapability {
  const DisabledRemoteCatalogueCapability();

  @override
  bool get isAvailable => false;

  @override
  Future<List<RemoteFoodCandidate>> searchFoods(
    String query, {
    int limit = 20,
  }) async =>
      const [];

  @override
  Future<RemoteFoodCandidate?> lookupBarcode(String barcode) async => null;
}
