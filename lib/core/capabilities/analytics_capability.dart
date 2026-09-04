/// Abstract contract for privacy-minimized product analytics.
///
/// Invariant: Analytics covers aggregate, non-sensitive product events only
/// (screen views, feature usage counts). Fitness records, nutrition payloads,
/// health observations, and crash breadcrumbs containing personal data are
/// excluded by default and require explicit opt-in. Diagnostics (crash
/// reporting) is a separate capability ([DiagnosticsCapability]).
abstract class AnalyticsCapability {
  /// Whether product analytics collection is consented and active.
  bool get isEnabled;

  /// Records a non-sensitive product event (e.g. `food_search_opened`).
  ///
  /// [name] must be a stable snake_case event key. [parameters] must contain
  /// only non-sensitive aggregates (counts, durations, feature flags) — never
  /// workout loads, food names, weights, or health values.
  void recordEvent(String name, {Map<String, Object?> parameters = const {}});
}

/// Privacy-first no-op default: analytics off unless explicitly enabled.
class NoOpAnalyticsCapability implements AnalyticsCapability {
  const NoOpAnalyticsCapability();

  @override
  bool get isEnabled => false;

  @override
  void recordEvent(String name, {Map<String, Object?> parameters = const {}}) {}
}
