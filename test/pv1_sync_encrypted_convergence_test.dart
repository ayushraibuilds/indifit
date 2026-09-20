import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/cloud_backup_envelope_manager.dart';
import 'package:indifit/core/capabilities/account_capability.dart';
import 'package:indifit/core/capabilities/network_capability.dart';
import 'package:indifit/core/capabilities/sync_capability.dart';
import 'package:indifit/core/outbox/outbox.dart';
import 'package:indifit/core/sync/hlc_timestamp.dart';
import 'package:indifit/core/sync/sync_api_client.dart';
import 'package:indifit/core/sync/sync_mutation.dart';
import 'package:indifit/core/sync/sync_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/indifit_test_harness.dart';

class _FakeAccount implements AccountCapability {
  _FakeAccount({required this.nodeId});

  final String nodeId;

  @override
  Future<bool> get isAuthenticated async => true;

  @override
  Future<String?> get currentUserId async => 'sync-user-42';

  @override
  Future<String> get deviceId async => nodeId;

  @override
  Stream<AccountSession?> get onSessionChanged => Stream.value(
        AccountSession(
          userId: 'sync-user-42',
          deviceId: nodeId,
          displayName: 'Sync User',
        ),
      );

  @override
  Future<void> signOut() async {}

  @override
  Future<void> requestAccountDeletion() async {}
}

SyncService _makeService({
  required AppDatabase db,
  required SharedPreferences prefs,
  required String nodeId,
  required SyncApiClient relay,
  required OutboxRepository outbox,
  String? secret,
}) {
  return SyncService(
    db: db,
    prefs: prefs,
    account: _FakeAccount(nodeId: nodeId),
    network: TestableNetworkCapability(initialConnected: true),
    outbox: outbox,
    apiClient: relay,
    deviceId: nodeId,
    envelopeManager: secret == null ? null : CloudBackupEnvelopeManager(),
    syncEncryptionSecret: secret,
  );
}

String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

const _zeroHlc = HlcTimestamp(millis: 0, counter: 0, nodeId: 'initial');

void main() {
  initializeIndiFitTestHarness();

  group('PV1-SYNC encrypted envelope convergence (Stream B)', () {
    late SharedPreferences prefs;

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      setIndiFitTestPreferences({});
      prefs = await SharedPreferences.getInstance();
    });

    test('(a) A→B encrypted convergence; relay carries no plaintext', () async {
      const secret = 'test-sync-secret-alpha-001';
      final relay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final dbA = scopeA.create();
      final serviceA = _makeService(
        db: dbA,
        prefs: prefs,
        nodeId: 'enc-dev-A',
        relay: relay,
        outbox: InMemoryOutboxRepository(),
        secret: secret,
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = _makeService(
        db: dbB,
        prefs: prefs,
        nodeId: 'enc-dev-B',
        relay: relay,
        outbox: InMemoryOutboxRepository(),
        secret: secret,
      );

      const hlc = HlcTimestamp(millis: 10000, counter: 0, nodeId: 'enc-dev-A');
      final payload = <String, dynamic>{
        'weight_kg': 72.5,
        'recorded_at': '2026-09-03T07:00:00Z',
      };
      await serviceA.recordLocalMutation(SyncMutation(
        entityId: 'uuid-weight-enc-a1',
        domain: SyncDomain.weights,
        type: SyncMutationType.insert,
        hlc: hlc,
        payload: payload,
      ));

      final resultsA = await serviceA.triggerSync();
      expect(resultsA.every((r) => r.success), isTrue);
      expect(relay.totalStoredCount, 1);

      // Inspect the relay bytes: sealed envelope, no plaintext payload.
      final stored =
          (await relay.pullDeltas(sinceHlc: _zeroHlc)).mutations.single;
      expect(stored.payload, isNull);
      expect(stored.encryptedEnvelope, isNotNull);
      expect(
        stored.encryptedEnvelope!.keys,
        containsAll(
          ['mutation_id', 'ciphertext_base64', 'wrapped_key_base64', 'sha256_checksum'],
        ),
      );
      final relayJson = jsonEncode(stored.toJson());
      expect(relayJson.contains(jsonEncode(payload)), isFalse);

      // Wire round-trip preserves the envelope exactly.
      final roundTripped = SyncMutation.fromJson(
        jsonDecode(relayJson) as Map<String, dynamic>,
      );
      expect(roundTripped.encryptedEnvelope, equals(stored.encryptedEnvelope));
      expect(roundTripped.payload, isNull);

      // Peer B converges to the same row.
      final resultsB = await serviceB.triggerSync();
      expect(resultsB.every((r) => r.success), isTrue);
      final rowsB = await dbB.select(dbB.bodyMeasurements).get();
      expect(rowsB, hasLength(1));
      expect(rowsB.first.weight, 72.5);
    });

    test('(b) wrong-key peer skips the mutation (no row, no throw)', () async {
      final relay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final serviceA = _makeService(
        db: scopeA.create(),
        prefs: prefs,
        nodeId: 'enc-dev-A',
        relay: relay,
        outbox: InMemoryOutboxRepository(),
        secret: 'test-sync-secret-correct-002',
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = _makeService(
        db: dbB,
        prefs: prefs,
        nodeId: 'enc-dev-B',
        relay: relay,
        outbox: InMemoryOutboxRepository(),
        secret: 'test-sync-secret-WRONG-002',
      );

      await serviceA.recordLocalMutation(const SyncMutation(
        entityId: 'uuid-weight-enc-b1',
        domain: SyncDomain.weights,
        type: SyncMutationType.insert,
        hlc: HlcTimestamp(millis: 11000, counter: 0, nodeId: 'enc-dev-A'),
        payload: {'weight_kg': 68.0},
      ));
      await serviceA.triggerSync();
      expect(relay.totalStoredCount, 1);

      // Must not throw; sync still reports success (skip is fail-closed).
      final resultsB = await serviceB.triggerSync();
      expect(resultsB.every((r) => r.success), isTrue);
      expect(await dbB.select(dbB.bodyMeasurements).get(), isEmpty);
    });

    test('(c) tampered ciphertext is skipped (stale and recomputed checksums)',
        () async {
      const secret = 'test-sync-secret-tamper-003';
      final relay = InMemorySyncApiClient();
      final manager = CloudBackupEnvelopeManager();

      SyncMutation craftTampered({
        required String entityId,
        required int millis,
        required bool recomputeChecksum,
      }) {
        final hlc = HlcTimestamp(millis: millis, counter: 0, nodeId: 'tamper-A');
        final mutationId = '$entityId:$hlc';
        final envelope = manager.encryptMutation(
          mutationId: mutationId,
          plaintextJson: jsonEncode({'weight_kg': 70.0}),
          kmsKeyWrappingSecret: secret,
        );
        final tampered = Uint8List.fromList(envelope.ciphertextBytes);
        tampered[tampered.length ~/ 2] ^= 0xFF;
        final checksum = recomputeChecksum
            ? sha256Hex(tampered)
            : envelope.sha256Checksum;
        return SyncMutation(
          entityId: entityId,
          domain: SyncDomain.weights,
          type: SyncMutationType.insert,
          hlc: hlc,
          encryptedEnvelope: <String, dynamic>{
            'mutation_id': mutationId,
            'ciphertext_base64': base64Encode(tampered),
            'wrapped_key_base64': base64Encode(envelope.wrappedKeyBytes),
            'sha256_checksum': checksum,
          },
        );
      }

      await relay.pushMutations([
        craftTampered(
          entityId: 'uuid-weight-enc-c1',
          millis: 20000,
          recomputeChecksum: false,
        ),
        craftTampered(
          entityId: 'uuid-weight-enc-c2',
          millis: 20001,
          recomputeChecksum: true,
        ),
      ]);

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = _makeService(
        db: dbB,
        prefs: prefs,
        nodeId: 'enc-dev-B',
        relay: relay,
        outbox: InMemoryOutboxRepository(),
        secret: secret,
      );

      final resultsB = await serviceB.triggerSync();
      expect(resultsB.every((r) => r.success), isTrue);
      expect(await dbB.select(dbB.bodyMeasurements).get(), isEmpty);
    });

    test('(d) plaintext path unchanged when secret is null', () async {
      final relay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final serviceA = _makeService(
        db: scopeA.create(),
        prefs: prefs,
        nodeId: 'plain-dev-A',
        relay: relay,
        outbox: InMemoryOutboxRepository(),
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = _makeService(
        db: dbB,
        prefs: prefs,
        nodeId: 'plain-dev-B',
        relay: relay,
        outbox: InMemoryOutboxRepository(),
      );

      await serviceA.recordLocalMutation(const SyncMutation(
        entityId: 'uuid-weight-plain-d1',
        domain: SyncDomain.weights,
        type: SyncMutationType.insert,
        hlc: HlcTimestamp(millis: 30000, counter: 0, nodeId: 'plain-dev-A'),
        payload: {'weight_kg': 80.0},
      ));
      await serviceA.triggerSync();

      // Relay still carries today's exact plaintext shape.
      final stored =
          (await relay.pullDeltas(sinceHlc: _zeroHlc)).mutations.single;
      expect(stored.encryptedEnvelope, isNull);
      expect(stored.payload?['weight_kg'], 80.0);

      await serviceB.triggerSync();
      final rowsB = await dbB.select(dbB.bodyMeasurements).get();
      expect(rowsB, hasLength(1));
      expect(rowsB.first.weight, 80.0);
    });

    test('(e) weight uuid update-no-duplicate + delete-by-uuid', () async {
      final relay = InMemorySyncApiClient();

      final scopeA = registerTestDatabaseScope();
      final serviceA = _makeService(
        db: scopeA.create(),
        prefs: prefs,
        nodeId: 'uuid-dev-A',
        relay: relay,
        outbox: InMemoryOutboxRepository(),
      );

      final scopeB = registerTestDatabaseScope();
      final dbB = scopeB.create();
      final serviceB = _makeService(
        db: dbB,
        prefs: prefs,
        nodeId: 'uuid-dev-B',
        relay: relay,
        outbox: InMemoryOutboxRepository(),
      );

      // Insert under an opaque (non-numeric) UUID entity id.
      await serviceA.recordLocalMutation(const SyncMutation(
        entityId: 'uuid-weight-e1',
        domain: SyncDomain.weights,
        type: SyncMutationType.insert,
        hlc: HlcTimestamp(millis: 40000, counter: 0, nodeId: 'uuid-dev-A'),
        payload: {'weight_kg': 70.0},
      ));
      await serviceA.triggerSync();
      await serviceB.triggerSync();
      var rowsB = await dbB.select(dbB.bodyMeasurements).get();
      expect(rowsB, hasLength(1));
      expect(rowsB.first.weight, 70.0);

      // Same entity id, newer HLC: must update in place, not duplicate.
      await serviceA.recordLocalMutation(const SyncMutation(
        entityId: 'uuid-weight-e1',
        domain: SyncDomain.weights,
        type: SyncMutationType.update,
        hlc: HlcTimestamp(millis: 41000, counter: 0, nodeId: 'uuid-dev-A'),
        payload: {'weight_kg': 71.0},
      ));
      await serviceA.triggerSync();
      await serviceB.triggerSync();
      rowsB = await dbB.select(dbB.bodyMeasurements).get();
      expect(rowsB, hasLength(1));
      expect(rowsB.first.weight, 71.0);

      // Delete by uuid extinguishes the row.
      await serviceA.recordLocalMutation(const SyncMutation(
        entityId: 'uuid-weight-e1',
        domain: SyncDomain.weights,
        type: SyncMutationType.delete,
        hlc: HlcTimestamp(millis: 42000, counter: 0, nodeId: 'uuid-dev-A'),
      ));
      await serviceA.triggerSync();
      await serviceB.triggerSync();
      rowsB = await dbB.select(dbB.bodyMeasurements).get();
      expect(rowsB, isEmpty);
    });
  });
}
