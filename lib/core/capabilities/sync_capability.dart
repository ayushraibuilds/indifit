// Note on layering: HlcTimestamp/SyncMutation live in lib/core/sync/ as
// shared kernel types (not a feature package), so this capability contract
// importing them keeps the dependency core->core. Feature screens depend on
// this contract, never on lib/core/sync/ directly.
import '../sync/hlc_timestamp.dart';
import '../sync/sync_mutation.dart';
import 'connected_status.dart';

/// Supported sync domains.
enum SyncDomain {
  workouts,
  nutritionLogs,
  nutritionRecipes,
  weights,
  programs,
  preferences,
}

/// Result of a synchronization cycle for a specific domain.
class SyncDomainResult {
  const SyncDomainResult({
    required this.domain,
    required this.success,
    this.recordsSent = 0,
    this.recordsReceived = 0,
    this.errorMessage,
  });

  final SyncDomain domain;
  final bool success;
  final int recordsSent;
  final int recordsReceived;
  final String? errorMessage;
}

/// Abstract contract for optional multi-device record synchronization.
///
/// Invariant: Writes commit to local Drift tables first. Sync reads from the
/// local database/outbox, reconciles remote changes, and never overwrites local
/// user changes without an explicit domain conflict policy.
abstract class SyncCapability {
  /// Current multi-device synchronization status.
  Future<ConnectedStatusState> getStatus();

  /// Stream of sync status updates.
  Stream<ConnectedStatusState> get onStatusChanged;

  /// Manually requests an immediate sync pass across all or specified domains.
  Future<List<SyncDomainResult>> triggerSync({List<SyncDomain>? domains});

  /// Pulls remote delta mutations committed since [sinceHlc].
  Future<List<SyncMutation>> pullDeltas({
    required HlcTimestamp sinceHlc,
    int limit = 100,
  });

  /// Pushes a batch of local mutations to the remote sync relay.
  Future<bool> pushMutations(List<SyncMutation> mutations);
}

/// Default standalone driver when multi-device sync is not active.
class DisabledSyncCapability implements SyncCapability {
  const DisabledSyncCapability();

  @override
  Future<ConnectedStatusState> getStatus() async =>
      const ConnectedStatusState.neverConfigured();

  @override
  Stream<ConnectedStatusState> get onStatusChanged => Stream.value(
        const ConnectedStatusState.neverConfigured(),
      );

  @override
  Future<List<SyncDomainResult>> triggerSync({List<SyncDomain>? domains}) async =>
      const [];

  @override
  Future<List<SyncMutation>> pullDeltas({
    required HlcTimestamp sinceHlc,
    int limit = 100,
  }) async =>
      const [];

  @override
  Future<bool> pushMutations(List<SyncMutation> mutations) async => false;
}
