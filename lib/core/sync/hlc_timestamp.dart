/// Hybrid Logical Clock (HLC) implementation for IndiFit distributed synchronization.
///
/// HLC provides a strict total ordering of events across devices without
/// requiring synchronized physical clocks or centralized clock servers.
///
/// Format: `<millis_hex>_<counter_hex>_<node_id>`
library;

import 'package:flutter/foundation.dart';

/// Immutable timestamp combining physical time, logical sequence, and node identity.
@immutable
class HlcTimestamp implements Comparable<HlcTimestamp> {
  const HlcTimestamp({
    required this.millis,
    required this.counter,
    required this.nodeId,
  })  : assert(millis >= 0, 'millis must be non-negative'),
        assert(counter >= 0, 'counter must be non-negative'),
        assert(nodeId.length > 0, 'nodeId cannot be empty');

  /// Physical time in milliseconds since Unix epoch.
  final int millis;

  /// Monotonic counter for events occurring within the same physical millisecond.
  final int counter;

  /// Globally unique identifier of the originating device/node.
  final String nodeId;

  /// Canonical string representation: e.g. "00018fa24b00_0001_iPhone-15-Pro"
  @override
  String toString() {
    final mHex = millis.toRadixString(16).padLeft(12, '0');
    final cHex = counter.toRadixString(16).padLeft(4, '0');
    return '${mHex}_${cHex}_$nodeId';
  }

  /// Parses a canonical HLC string representation.
  factory HlcTimestamp.fromString(String raw) {
    final parts = raw.split('_');
    if (parts.length < 3) {
      throw FormatException('Invalid HLC timestamp format: "$raw"');
    }
    final millis = int.parse(parts[0], radix: 16);
    final counter = int.parse(parts[1], radix: 16);
    final nodeId = parts.sublist(2).join('_');
    return HlcTimestamp(millis: millis, counter: counter, nodeId: nodeId);
  }

  Map<String, dynamic> toJson() => {
        'millis': millis,
        'counter': counter,
        'node_id': nodeId,
      };

  factory HlcTimestamp.fromJson(Map<String, dynamic> json) {
    return HlcTimestamp(
      millis: (json['millis'] as num).toInt(),
      counter: (json['counter'] as num).toInt(),
      nodeId: json['node_id'] as String,
    );
  }

  /// Strict total ordering comparison.
  ///
  /// Orders first by physical millis, then by logical counter, and breaks ties
  /// deterministically using the node ID.
  @override
  int compareTo(HlcTimestamp other) {
    if (millis != other.millis) {
      return millis.compareTo(other.millis);
    }
    if (counter != other.counter) {
      return counter.compareTo(other.counter);
    }
    return nodeId.compareTo(other.nodeId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HlcTimestamp &&
          runtimeType == other.runtimeType &&
          millis == other.millis &&
          counter == other.counter &&
          nodeId == other.nodeId;

  @override
  int get hashCode => Object.hash(millis, counter, nodeId);

  bool operator <(HlcTimestamp other) => compareTo(other) < 0;
  bool operator <=(HlcTimestamp other) => compareTo(other) <= 0;
  bool operator >(HlcTimestamp other) => compareTo(other) > 0;
  bool operator >=(HlcTimestamp other) => compareTo(other) >= 0;
}

/// Hybrid Logical Clock generator maintaining monotonic local state.
class HlcClock {
  HlcClock({
    required this.nodeId,
    int? initialMillis,
    int initialCounter = 0,
  })  : _latestMillis = initialMillis ?? 0,
        _counter = initialCounter;

  final String nodeId;
  int _latestMillis;
  int _counter;

  /// Current logical time state without advancing.
  HlcTimestamp get current => HlcTimestamp(
        millis: _latestMillis,
        counter: _counter,
        nodeId: nodeId,
      );

  /// Generates the next monotonic timestamp for a local event.
  HlcTimestamp send({int? physicalTimeMillis}) {
    final physicalNow = physicalTimeMillis ?? DateTime.now().toUtc().millisecondsSinceEpoch;

    if (physicalNow > _latestMillis) {
      _latestMillis = physicalNow;
      _counter = 0;
    } else {
      _counter += 1;
    }

    return HlcTimestamp(
      millis: _latestMillis,
      counter: _counter,
      nodeId: nodeId,
    );
  }

  /// Updates the local clock state upon receiving a remote timestamp.
  ///
  /// Ensures the clock advances beyond both the local time and the remote time.
  HlcTimestamp receive(HlcTimestamp remote, {int? physicalTimeMillis}) {
    final physicalNow = physicalTimeMillis ?? DateTime.now().toUtc().millisecondsSinceEpoch;

    final nextMillis = _max3(_latestMillis, physicalNow, remote.millis);

    if (nextMillis == _latestMillis && nextMillis == remote.millis) {
      _counter = (remote.counter > _counter ? remote.counter : _counter) + 1;
    } else if (nextMillis == _latestMillis) {
      _counter += 1;
    } else if (nextMillis == remote.millis) {
      _counter = remote.counter + 1;
    } else {
      _counter = 0;
    }

    _latestMillis = nextMillis;

    return HlcTimestamp(
      millis: _latestMillis,
      counter: _counter,
      nodeId: nodeId,
    );
  }

  static int _max3(int a, int b, int c) {
    var max = a;
    if (b > max) max = b;
    if (c > max) max = c;
    return max;
  }
}
