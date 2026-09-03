/// Connectivity and network policy abstraction for IndiFit.
///
/// Invariant: Local persistence never waits for or checks network state before
/// committing user data to SQLite. Network checks are used exclusively to gate
/// background synchronization and explicitly connected queries.
library;

/// High-level transport type.
enum NetworkTransportType {
  none,
  wifi,
  cellular,
  ethernet,
  other,
}

/// Abstract contract for network reachability and transfer policy.
abstract class NetworkCapability {
  /// Whether the device has an active network connection.
  bool get isConnected;

  /// The active connection medium (Wi-Fi, cellular, none).
  NetworkTransportType get transportType;

  /// Stream of connectivity transitions.
  Stream<bool> get onConnectivityChanged;

  /// Checks whether a connected operation should proceed given user bandwidth
  /// preferences (e.g. Wi-Fi only for large media or backups).
  bool canExecuteOperation({bool requireWifi = false}) {
    if (!isConnected) return false;
    if (requireWifi && transportType != NetworkTransportType.wifi) {
      return false;
    }
    return true;
  }
}

/// Default offline driver for tests and air-gapped environments.
class OfflineNetworkCapability implements NetworkCapability {
  const OfflineNetworkCapability();

  @override
  bool get isConnected => false;

  @override
  NetworkTransportType get transportType => NetworkTransportType.none;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(false);

  @override
  bool canExecuteOperation({bool requireWifi = false}) => false;
}

/// In-memory controllable network capability for tests and diagnostics.
class TestableNetworkCapability implements NetworkCapability {
  TestableNetworkCapability({
    bool initialConnected = true,
    NetworkTransportType initialTransport = NetworkTransportType.wifi,
  })  : _connected = initialConnected,
        _transport = initialTransport;

  bool _connected;
  NetworkTransportType _transport;

  void setConnected(bool connected, [NetworkTransportType? transport]) {
    _connected = connected;
    if (transport != null) {
      _transport = transport;
    } else if (!connected) {
      _transport = NetworkTransportType.none;
    }
  }

  @override
  bool get isConnected => _connected;

  @override
  NetworkTransportType get transportType => _transport;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(_connected);

  @override
  bool canExecuteOperation({bool requireWifi = false}) {
    if (!_connected) return false;
    if (requireWifi && _transport != NetworkTransportType.wifi) {
      return false;
    }
    return true;
  }
}
