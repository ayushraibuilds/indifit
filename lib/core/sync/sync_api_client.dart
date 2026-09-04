/// Network client contracts and in-memory mock for multi-device sync relay.
library;

import '../capabilities/sync_capability.dart';
import 'hlc_timestamp.dart';
import 'sync_mutation.dart';

/// Request payload for pushing a batch of mutations to the sync relay.
class SyncPushRequest {
  const SyncPushRequest({required this.mutations});

  final List<SyncMutation> mutations;

  Map<String, dynamic> toJson() => {
        'mutations': mutations.map((m) => m.toJson()).toList(),
      };

  factory SyncPushRequest.fromJson(Map<String, dynamic> json) {
    return SyncPushRequest(
      mutations: (json['mutations'] as List)
          .map((m) => SyncMutation.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Response returned by the sync relay after accepting a push batch.
class SyncPushResponse {
  const SyncPushResponse({
    required this.acceptedCount,
    required this.serverReceivedHlc,
  });

  final int acceptedCount;
  final HlcTimestamp serverReceivedHlc;

  Map<String, dynamic> toJson() => {
        'accepted_count': acceptedCount,
        'server_received_hlc': serverReceivedHlc.toJson(),
      };

  factory SyncPushResponse.fromJson(Map<String, dynamic> json) {
    return SyncPushResponse(
      acceptedCount: (json['accepted_count'] as num).toInt(),
      serverReceivedHlc: HlcTimestamp.fromJson(
        json['server_received_hlc'] as Map<String, dynamic>,
      ),
    );
  }
}

/// Response returned when pulling delta mutations from the sync relay.
class SyncPullResponse {
  const SyncPullResponse({
    required this.mutations,
    required this.hasMore,
    this.latestHlc,
  });

  final List<SyncMutation> mutations;
  final bool hasMore;
  final HlcTimestamp? latestHlc;

  Map<String, dynamic> toJson() => {
        'mutations': mutations.map((m) => m.toJson()).toList(),
        'has_more': hasMore,
        if (latestHlc != null) 'latest_hlc': latestHlc!.toJson(),
      };

  factory SyncPullResponse.fromJson(Map<String, dynamic> json) {
    return SyncPullResponse(
      mutations: (json['mutations'] as List)
          .map((m) => SyncMutation.fromJson(m as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool? ?? false,
      latestHlc: json['latest_hlc'] != null
          ? HlcTimestamp.fromJson(json['latest_hlc'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Abstract contract for communicating with the IndiFit Sync Relay backend.
abstract class SyncApiClient {
  /// Pushes a batch of local mutations to the remote relay.
  Future<SyncPushResponse> pushMutations(List<SyncMutation> mutations);

  /// Pulls delta mutations committed since [sinceHlc].
  Future<SyncPullResponse> pullDeltas({
    required HlcTimestamp sinceHlc,
    SyncDomain? domain,
    int limit = 100,
  });
}

/// In-memory mock sync relay for unit tests and local simulations.
class InMemorySyncApiClient implements SyncApiClient {
  InMemorySyncApiClient({
    this.simulatedError,
    this.clockSkewThresholdMillis = 3600000, // 1 hour
  });

  final Exception? simulatedError;
  final int clockSkewThresholdMillis;

  /// In-memory mutations stream ordered by HLC.
  final List<SyncMutation> _storedMutations = [];

  int get totalStoredCount => _storedMutations.length;

  void clear() => _storedMutations.clear();

  @override
  Future<SyncPushResponse> pushMutations(List<SyncMutation> mutations) async {
    if (simulatedError != null) throw simulatedError!;

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    var accepted = 0;
    HlcTimestamp latest = const HlcTimestamp(millis: 0, counter: 0, nodeId: 'server');

    for (final mutation in mutations) {
      // Validate clock skew
      if (mutation.hlc.millis > now + clockSkewThresholdMillis) {
        throw FormatException(
          'Clock skew exceeded for mutation ${mutation.entityId}: ${mutation.hlc.millis} vs now $now',
        );
      }

      // Deduplicate on (domain, entityId, hlc): same numeric id in two
      // domains must not collide.
      final exists = _storedMutations.any(
        (m) =>
            m.domain == mutation.domain &&
            m.entityId == mutation.entityId &&
            m.hlc == mutation.hlc,
      );
      if (!exists) {
        _storedMutations.add(mutation);
        accepted++;
      }
      if (mutation.hlc > latest) {
        latest = mutation.hlc;
      }
    }

    // Keep stored mutations sorted by HLC
    _storedMutations.sort((a, b) => a.hlc.compareTo(b.hlc));

    return SyncPushResponse(
      acceptedCount: accepted,
      serverReceivedHlc: latest,
    );
  }

  @override
  Future<SyncPullResponse> pullDeltas({
    required HlcTimestamp sinceHlc,
    SyncDomain? domain,
    int limit = 100,
  }) async {
    if (simulatedError != null) throw simulatedError!;

    final eligible = _storedMutations.where((m) {
      if (m.hlc <= sinceHlc) return false;
      if (domain != null && m.domain != domain) return false;
      return true;
    }).toList();

    final slice = eligible.take(limit).toList();
    final hasMore = eligible.length > limit;
    final latest = slice.isNotEmpty ? slice.last.hlc : null;

    return SyncPullResponse(
      mutations: slice,
      hasMore: hasMore,
      latestHlc: latest,
    );
  }
}
