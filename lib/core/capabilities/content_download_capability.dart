/// Download request status.
enum AssetDownloadState {
  notStarted,
  downloading,
  completed,
  failed,
  cancelled,
}

/// Progress descriptor for an asset download operation.
class AssetDownloadProgress {
  const AssetDownloadProgress({
    required this.assetId,
    required this.state,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  final String assetId;
  final AssetDownloadState state;
  final int bytesReceived;
  final int totalBytes;
  final String? errorMessage;

  double get progressFraction =>
      totalBytes > 0 ? (bytesReceived / totalBytes).clamp(0.0, 1.0) : 0.0;
}

/// Abstract contract for acquiring rich exercise demonstration media,
/// motion packs, or signed catalog updates.
///
/// Invariant: Failed or unconfigured downloads never remove or invalidate
/// bundled SVG muscle maps, local still images, or text instructions.
abstract class ContentDownloadCapability {
  /// Whether download capability is configured.
  bool get isConfigured;

  /// Enqueues or starts downloading a media asset to local storage.
  Future<bool> downloadAsset({
    required String assetId,
    required String sourceUrl,
    required String localDestinationPath,
    String? expectedSha256,
  });

  /// Verifies SHA256 integrity of an existing downloaded asset file.
  Future<bool> verifyIntegrity({
    required String localPath,
    required String expectedSha256,
  });

  /// Deletes a cached download to free storage budget.
  Future<void> evictAsset(String assetId);
}

/// Default implementation when no remote content server is configured.
class DisabledContentDownloadCapability implements ContentDownloadCapability {
  const DisabledContentDownloadCapability();

  @override
  bool get isConfigured => false;

  @override
  Future<bool> downloadAsset({
    required String assetId,
    required String sourceUrl,
    required String localDestinationPath,
    String? expectedSha256,
  }) async =>
      false;

  @override
  Future<bool> verifyIntegrity({
    required String localPath,
    required String expectedSha256,
  }) async =>
      false;

  @override
  Future<void> evictAsset(String assetId) async {}
}
