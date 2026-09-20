/// Abstract contract for privacy-minimized crash reporting and diagnostics.
///
/// Invariant: User personal fitness records (workout weights, exercises, food
/// logs, body weights) are strictly redacted and never transmitted in
/// ordinary crash logs or diagnostic traces.
abstract class DiagnosticsCapability {
  /// Whether diagnostic reporting is consented and active.
  bool get isEnabled;

  /// Records a non-fatal error with diagnostic metadata.
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? contextualMetadata,
  });

  /// Records a non-sensitive lifecycle breadcrumb.
  void recordBreadcrumb(String message, {String category = 'lifecycle'});
}

/// Privacy-first no-op default.
class NoOpDiagnosticsCapability implements DiagnosticsCapability {
  const NoOpDiagnosticsCapability();

  @override
  bool get isEnabled => false;

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? contextualMetadata,
  }) {}

  @override
  void recordBreadcrumb(String message, {String category = 'lifecycle'}) {}
}
