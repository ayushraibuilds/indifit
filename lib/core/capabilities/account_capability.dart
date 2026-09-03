/// User account state descriptor.
class AccountSession {
  const AccountSession({
    required this.userId,
    required this.deviceId,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });

  final String userId;
  final String deviceId;
  final String? email;
  final String? displayName;
  final bool isAnonymous;
}

/// Abstract contract for optional account and multi-device identity.
///
/// Invariant: All core fitness tracking is completely functional without an
/// account. Account identity enables cloud backup, multi-device sync, and
/// remote features only.
abstract class AccountCapability {
  /// True if a user account session is active.
  Future<bool> get isAuthenticated;

  /// Current user ID if authenticated, or null for guest/local users.
  Future<String?> get currentUserId;

  /// Stable unique hardware/installation device ID used for sync attribution.
  Future<String> get deviceId;

  /// Stream emitting updates whenever authentication state transitions.
  Stream<AccountSession?> get onSessionChanged;

  /// Signs out and returns to guest/local-only mode.
  ///
  /// Invariant: Local workout, nutrition, and weight history are NEVER deleted
  /// on sign-out unless the user explicitly requests local data erasure.
  Future<void> signOut();

  /// Requests remote account deletion and data scrubbing.
  Future<void> requestAccountDeletion();
}

/// Default offline-first guest implementation.
class NoOpAccountCapability implements AccountCapability {
  const NoOpAccountCapability({String defaultDeviceId = 'local-device'});

  final String _deviceId = 'local-device';

  @override
  Future<bool> get isAuthenticated async => false;

  @override
  Future<String?> get currentUserId async => null;

  @override
  Future<String> get deviceId async => _deviceId;

  @override
  Stream<AccountSession?> get onSessionChanged => Stream.value(null);

  @override
  Future<void> signOut() async {}

  @override
  Future<void> requestAccountDeletion() async {}
}
