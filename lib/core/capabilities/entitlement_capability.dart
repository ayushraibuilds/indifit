/// Entitlement tier.
enum EntitlementTier {
  free,
  pro,
  lifetime,
}

/// Status descriptor for user feature entitlements.
class EntitlementState {
  const EntitlementState({
    required this.tier,
    this.isActive = true,
    this.expiresAtUtc,
    this.gracePeriodActive = false,
  });

  final EntitlementTier tier;
  final bool isActive;
  final DateTime? expiresAtUtc;
  final bool gracePeriodActive;
}

/// Abstract contract for feature entitlement and subscription verification.
///
/// Invariant: Offline core fitness functionality (logging workouts, food,
/// weight, offline plan libraries, and local progress) is NEVER locked or
/// disabled by entitlement provider outages or expired offline tokens.
abstract class EntitlementCapability {
  /// Current entitlement state.
  EntitlementState get currentEntitlement;

  /// Stream of entitlement transitions.
  Stream<EntitlementState> get onEntitlementChanged;

  /// Checks whether a specific premium feature is accessible.
  bool isFeatureAccessible(String featureKey);
}

/// Default implementation providing full access to all local V1 features.
class FullLocalEntitlementCapability implements EntitlementCapability {
  const FullLocalEntitlementCapability();

  @override
  EntitlementState get currentEntitlement => const EntitlementState(
        tier: EntitlementTier.free,
        isActive: true,
      );

  @override
  Stream<EntitlementState> get onEntitlementChanged => Stream.value(
        currentEntitlement,
      );

  @override
  bool isFeatureAccessible(String featureKey) => true;
}
