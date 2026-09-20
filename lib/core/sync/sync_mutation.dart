/// Mutation and tombstone models for multi-device record synchronization.
library;

import 'package:flutter/foundation.dart';

import '../capabilities/sync_capability.dart';
import 'hlc_timestamp.dart';

/// Type of record mutation.
enum SyncMutationType {
  insert,
  update,
  delete,
}

/// An immutable atomic change record to a synchronized entity.
@immutable
class SyncMutation {
  const SyncMutation({
    required this.entityId,
    required this.domain,
    required this.type,
    required this.hlc,
    this.payload,
    this.encryptedEnvelope,
  })  : assert(
          type != SyncMutationType.delete || payload == null,
          'Delete mutations cannot carry a payload.',
        ),
        assert(
          type != SyncMutationType.delete || encryptedEnvelope == null,
          'Delete mutations cannot carry an encrypted envelope.',
        );

  /// Globally unique identifier of the entity (UUID v4).
  final String entityId;

  /// The synchronized domain this mutation belongs to.
  final SyncDomain domain;

  /// The type of mutation (insert, update, delete).
  final SyncMutationType type;

  /// Monotonic Hybrid Logical Clock timestamp of this mutation.
  final HlcTimestamp hlc;

  /// Key-value payload attributes (null if deleted, or if this mutation
  /// travels as a client-side encrypted envelope — see [encryptedEnvelope]).
  final Map<String, dynamic>? payload;

  /// Client-side encrypted envelope for the blind-relay path (SYNC-01A §5.1).
  ///
  /// When non-null, [payload] is null and the relay carries only this wire
  /// map with keys `mutation_id`, `ciphertext_base64`, `wrapped_key_base64`,
  /// and `sha256_checksum`. Identity (entity/domain/type/hlc) is unchanged
  /// so relay dedup semantics are preserved.
  final Map<String, dynamic>? encryptedEnvelope;

  /// Whether this mutation represents an explicit deletion (tombstone).
  bool get isDeleted => type == SyncMutationType.delete;

  Map<String, dynamic> toJson() => {
        'entity_id': entityId,
        'domain': domain.name,
        'type': type.name,
        'hlc': hlc.toJson(),
        if (payload != null) 'payload': payload,
        if (encryptedEnvelope != null) 'encrypted_envelope': encryptedEnvelope,
      };

  factory SyncMutation.fromJson(Map<String, dynamic> json) {
    final envelopeRaw = json['encrypted_envelope'];
    late final Map<String, dynamic>? envelope;
    if (envelopeRaw == null) {
      envelope = null;
    } else if (envelopeRaw is Map<String, dynamic>) {
      envelope = envelopeRaw;
    } else if (envelopeRaw is Map) {
      envelope = Map<String, dynamic>.from(envelopeRaw);
    } else {
      throw FormatException(
        'Invalid encrypted_envelope for mutation ${json['entity_id']}: must be a Map when present.',
      );
    }
    return SyncMutation(
      entityId: json['entity_id'] as String,
      domain: SyncDomain.values.firstWhere(
        (d) => d.name == json['domain'],
        orElse: () => throw FormatException('Unknown SyncDomain: ${json['domain']}'),
      ),
      type: SyncMutationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => throw FormatException('Unknown SyncMutationType: ${json['type']}'),
      ),
      hlc: HlcTimestamp.fromJson(json['hlc'] as Map<String, dynamic>),
      payload: json['payload'] as Map<String, dynamic>?,
      encryptedEnvelope: envelope,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncMutation &&
          runtimeType == other.runtimeType &&
          entityId == other.entityId &&
          domain == other.domain &&
          type == other.type &&
          hlc == other.hlc;

  @override
  int get hashCode => Object.hash(entityId, domain, type, hlc);

  @override
  String toString() =>
      'SyncMutation(entity: $entityId, domain: ${domain.name}, type: ${type.name}, hlc: $hlc)';
}

/// A tombstone representing an explicit deletion retained for offline convergence.
@immutable
class SyncTombstone {
  const SyncTombstone({
    required this.entityId,
    required this.domain,
    required this.deletedAtHlc,
    required this.createdAtUtc,
  });

  final String entityId;
  final SyncDomain domain;
  final HlcTimestamp deletedAtHlc;
  final DateTime createdAtUtc;

  /// Default tombstone retention duration before compaction (30 days).
  static const Duration defaultRetention = Duration(days: 30);

  /// Whether this tombstone is eligible for garbage collection.
  bool isExpired({DateTime? now, Duration retention = defaultRetention}) {
    final referenceTime = now ?? DateTime.now().toUtc();
    return referenceTime.difference(createdAtUtc) > retention;
  }

  Map<String, dynamic> toJson() => {
        'entity_id': entityId,
        'domain': domain.name,
        'deleted_at_hlc': deletedAtHlc.toJson(),
        'created_at_utc': createdAtUtc.toIso8601String(),
      };

  factory SyncTombstone.fromJson(Map<String, dynamic> json) {
    return SyncTombstone(
      entityId: json['entity_id'] as String,
      domain: SyncDomain.values.firstWhere((d) => d.name == json['domain']),
      deletedAtHlc: HlcTimestamp.fromJson(json['deleted_at_hlc'] as Map<String, dynamic>),
      createdAtUtc: DateTime.parse(json['created_at_utc'] as String),
    );
  }
}
