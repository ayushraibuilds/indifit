/// Supported external platform integration partners.
enum IntegrationPlatform {
  appleHealth,
  healthConnect,
  externalSensor,
}

/// Abstract contract for third-party platform integrations (HealthKit, Health Connect).
///
/// Invariant: External health sync failures never prevent or block local workout
/// completion or weight recording. Imported observations are normalized and attributed.
abstract class IntegrationCapability {
  /// True if the integration is authorized and enabled by the user.
  Future<bool> isAuthorized(IntegrationPlatform platform);

  /// Requests permission to read/write from the specified health platform.
  Future<bool> requestAuthorization(IntegrationPlatform platform);

  /// Writes a completed workout session to the external health store.
  Future<bool> writeCompletedWorkout({
    required String sessionUuid,
    required DateTime startUtc,
    required DateTime endUtc,
    required String title,
    double? activeEnergyKcal,
  });

  /// Writes a weight observation to the external health store.
  Future<bool> writeWeight({
    required double weightKg,
    required DateTime recordedAtUtc,
  });
}

/// Default disabled implementation for isolated environments.
class DisabledIntegrationCapability implements IntegrationCapability {
  const DisabledIntegrationCapability();

  @override
  Future<bool> isAuthorized(IntegrationPlatform platform) async => false;

  @override
  Future<bool> requestAuthorization(IntegrationPlatform platform) async =>
      false;

  @override
  Future<bool> writeCompletedWorkout({
    required String sessionUuid,
    required DateTime startUtc,
    required DateTime endUtc,
    required String title,
    double? activeEnergyKcal,
  }) async =>
      false;

  @override
  Future<bool> writeWeight({
    required double weightKg,
    required DateTime recordedAtUtc,
  }) async =>
      false;
}
