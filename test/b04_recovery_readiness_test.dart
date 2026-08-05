import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_v9.dart';
import 'package:indifit/core/fixtures/b04_adaptive_coaching_fixture_matrix.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_recovery_models.dart';
import 'package:indifit/data/repositories/readiness_snapshot_repository.dart';
import 'package:indifit/data/repositories/recovery_observation_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecoveryObservationRepository observations;
  late ReadinessSnapshotRepository snapshots;

  final createdAt = DateTime.utc(2026, 1, 1, 12);

  setUp(() {
    db = AppDatabase.memory();
    observations = RecoveryObservationRepository(
      database: db,
      nowUtc: () => createdAt,
    );
    snapshots = ReadinessSnapshotRepository(
      database: db,
      observations: observations,
      nowUtc: () => createdAt,
    );
  });

  tearDown(() => db.close());

  RecoveryObservationInput input({
    String? id,
    String userId = 'user-a',
    String kind = 'sleep_duration',
    DateTime? observedAtUtc,
    String timezoneId = 'Asia/Kolkata',
    RecoveryObservationStatus status = RecoveryObservationStatus.known,
    String unit = 'hours',
    double? value = 7.5,
    double? lower,
    double? upper,
    String source = 'health_connect',
    String provenance = 'health-fixture-v1',
    RecoveryPermissionState permission = RecoveryPermissionState.granted,
    RecoveryFreshness freshness = RecoveryFreshness.fresh,
    String? providerExternalId,
    String? sourceVersion = 'provider-contract-v1',
    String? correctionOfObservationId,
  }) => RecoveryObservationInput(
    id: id,
    userId: userId,
    kind: kind,
    observedAtUtc: observedAtUtc ?? DateTime.utc(2026, 1, 1, 18),
    timezoneId: timezoneId,
    status: status,
    unit: unit,
    value: value,
    lower: lower,
    upper: upper,
    source: source,
    provenance: provenance,
    permission: permission,
    freshness: freshness,
    providerExternalId: providerExternalId,
    sourceVersion: sourceVersion,
    correctionOfObservationId: correctionOfObservationId,
  );

  void expectHold(ReadinessEvaluationResult result) {
    expect(result.numericalEffect.calorieDeltaKcal, 0);
    expect(result.numericalEffect.trainingLoadDeltaPercent, 0);
    expect(result.numericalEffect.trainingIntensityDeltaPercent, 0);
    expect(result.numericalEffect.scheduleDurationDelta, 0);
    expect(result.numericalEffect.numericalProposalAllowed, isFalse);
    expect(result.numericalEffect.descriptiveCoachingAllowed, isTrue);
    expect(result.snapshot.policyVersion, kB04ReadinessHoldPolicyVersion);
  }

  Future<ReadinessEvaluationResult> evaluate({
    required List<RecoveryObservationInput> inputs,
    required String date,
    required List<String> requiredKinds,
  }) async {
    for (final item in inputs) {
      await observations.importObservation(item);
    }
    final result = await snapshots.evaluateAndStoreForLocalDate(
      userId: 'user-a',
      localDate: date,
      timezoneId: 'Asia/Kolkata',
      requiredKinds: requiredKinds,
    );
    expect(result, isNotNull);
    return result!;
  }

  group('B04-06 recovery normalization and completeness', () {
    test(
      'complete health evidence is descriptive and has exact zero effects',
      () async {
        final result = await evaluate(
          date: '2026-01-01',
          requiredKinds: const ['sleep_duration', 'heart_rate_variability'],
          inputs: [
            input(id: 'sleep-complete', providerExternalId: 'sleep-complete'),
            input(
              id: 'hrv-complete',
              kind: 'heart_rate_variability',
              unit: 'ms',
              value: 52,
              providerExternalId: 'hrv-complete',
            ),
          ],
        );

        expect(result.snapshot.completeness, ReadinessCompleteness.complete);
        expect(result.snapshot.status, ReadinessStatus.available);
        expect(result.snapshot.band, ReadinessBand.ready);
        expect(result.snapshot.confidence, 1.0);
        expect(result.snapshot.evidenceObservationIds, hasLength(2));
        expectHold(result);
      },
    );

    test(
      'estimated range remains visible and only becomes cautious descriptive state',
      () async {
        final result = await evaluate(
          date: '2026-01-01',
          requiredKinds: const ['sleep_duration'],
          inputs: [
            input(
              id: 'sleep-range',
              status: RecoveryObservationStatus.estimated,
              value: null,
              lower: 6.5,
              upper: 7.5,
              providerExternalId: 'sleep-range',
            ),
          ],
        );

        expect(result.snapshot.completeness, ReadinessCompleteness.complete);
        expect(result.snapshot.status, ReadinessStatus.cautious);
        expect(result.snapshot.band, ReadinessBand.cautious);
        expect(result.snapshot.evidence.single.value, isNull);
        expect(result.snapshot.evidence.single.lower, 6.5);
        expect(result.snapshot.evidence.single.upper, 7.5);
        expectHold(result);
      },
    );

    test(
      'missing evidence is unavailable and does not backfill a snapshot',
      () async {
        final result = await snapshots.evaluateAndStoreForLocalDate(
          userId: 'user-a',
          localDate: '2026-01-04',
          timezoneId: 'Asia/Kolkata',
          requiredKinds: const ['sleep_duration'],
        );

        expect(result, isNull);
        expect(await db.select(db.readinessSnapshots).get(), isEmpty);
      },
    );

    test(
      'partial evidence exposes missing required input and remains zero effect',
      () async {
        final result = await evaluate(
          date: '2026-01-01',
          requiredKinds: const ['sleep_duration', 'heart_rate_variability'],
          inputs: [
            input(id: 'sleep-partial', providerExternalId: 'sleep-partial'),
          ],
        );

        expect(result.snapshot.completeness, ReadinessCompleteness.incomplete);
        expect(result.snapshot.status, ReadinessStatus.unavailable);
        expect(result.snapshot.unavailableReason, contains('missing_required'));
        expectHold(result);
      },
    );

    test(
      'denied permission is visible and is never treated as a measurement',
      () async {
        final result = await evaluate(
          date: '2026-01-01',
          requiredKinds: const ['sleep_duration'],
          inputs: [
            input(
              id: 'sleep-denied',
              status: RecoveryObservationStatus.unknown,
              value: null,
              permission: RecoveryPermissionState.denied,
              freshness: RecoveryFreshness.unknown,
              providerExternalId: 'sleep-denied',
            ),
          ],
        );

        expect(result.snapshot.completeness, ReadinessCompleteness.unknown);
        expect(result.snapshot.status, ReadinessStatus.unavailable);
        expect(result.snapshot.unavailableReason, 'permission_denied');
        expectHold(result);
        final stored = (await observations.listForUser(
          userId: 'user-a',
        )).single;
        expect(stored.permission, RecoveryPermissionState.denied);
        expect(stored.value, isNull);
      },
    );

    test(
      'provider-unavailable permission is unknown and suppresses readiness',
      () async {
        final result = await evaluate(
          date: '2026-01-01',
          requiredKinds: const ['sleep_duration'],
          inputs: [
            input(
              id: 'sleep-provider-unavailable',
              status: RecoveryObservationStatus.unknown,
              value: null,
              permission: RecoveryPermissionState.unavailable,
              freshness: RecoveryFreshness.unknown,
              providerExternalId: 'sleep-provider-unavailable',
            ),
          ],
        );

        expect(result.snapshot.completeness, ReadinessCompleteness.unknown);
        expect(result.snapshot.status, ReadinessStatus.unavailable);
        expect(result.snapshot.unavailableReason, 'provider_unavailable');
        expectHold(result);
      },
    );

    test(
      'stale evidence suppresses readiness and preserves the stale state',
      () async {
        final result = await evaluate(
          date: '2026-01-01',
          requiredKinds: const ['sleep_duration'],
          inputs: [
            input(
              id: 'sleep-stale',
              freshness: RecoveryFreshness.stale,
              providerExternalId: 'sleep-stale',
            ),
          ],
        );

        expect(result.snapshot.completeness, ReadinessCompleteness.incomplete);
        expect(result.snapshot.status, ReadinessStatus.unavailable);
        expect(result.snapshot.unavailableReason, 'stale_evidence');
        expectHold(result);
      },
    );

    test(
      'conflicting same-kind health inputs are unavailable and freeze both evidence IDs',
      () async {
        final result = await evaluate(
          date: '2026-01-01',
          requiredKinds: const ['sleep_duration'],
          inputs: [
            input(
              id: 'sleep-conflict-a',
              value: 6.0,
              providerExternalId: 'sleep-conflict-a',
            ),
            input(
              id: 'sleep-conflict-b',
              value: 8.0,
              providerExternalId: 'sleep-conflict-b',
            ),
          ],
        );

        expect(result.snapshot.completeness, ReadinessCompleteness.unknown);
        expect(result.snapshot.status, ReadinessStatus.unavailable);
        expect(result.snapshot.unavailableReason, contains('conflicting'));
        expect(
          result.snapshot.evidenceObservationIds,
          containsAll(['sleep-conflict-a', 'sleep-conflict-b']),
        );
        expectHold(result);
      },
    );
  });

  group('B04-06 provenance, boundaries and history', () {
    test(
      'normalizes the recorded IANA local date across a UTC boundary and preserves permission provenance',
      () async {
        final imported = await observations.importObservation(
          input(
            id: 'boundary-observation',
            observedAtUtc: DateTime.utc(2026, 1, 1, 18, 30),
            permission: RecoveryPermissionState.granted,
            providerExternalId: 'boundary-provider-id',
          ),
        );

        expect(imported.localDate, '2026-01-02');
        expect(imported.timezoneId, 'Asia/Kolkata');
        expect(imported.permission, RecoveryPermissionState.granted);
        expect(imported.provenance, 'health-fixture-v1');
        expect(imported.provenanceEnvelope.reference, 'health-fixture-v1');
        expect(
          imported.provenanceEnvelope.providerExternalId,
          'boundary-provider-id',
        );

        final raw = await observations.rawById(imported.id);
        final storedProvenance =
            jsonDecode(raw!.provenance) as Map<String, dynamic>;
        expect(storedProvenance['permission'], 'granted');
        expect(storedProvenance['reference'], 'health-fixture-v1');
        expect(storedProvenance.containsKey('raw_payload'), isFalse);
      },
    );

    test(
      'preserves the stored local date across a daylight-saving transition',
      () async {
        final imported = await observations.importObservation(
          input(
            id: 'dst-observation',
            timezoneId: 'America/New_York',
            observedAtUtc: DateTime.utc(2026, 3, 8, 7, 30),
            providerExternalId: 'dst-provider-id',
          ),
        );

        expect(imported.localDate, '2026-03-08');
        final result = await snapshots.evaluateAndStoreForLocalDate(
          userId: 'user-a',
          localDate: '2026-03-08',
          timezoneId: 'America/New_York',
          requiredKinds: const ['sleep_duration'],
        );
        expect(result, isNotNull);
        expect(result!.snapshot.localDate, '2026-03-08');
        expect(result.snapshot.timezoneId, 'America/New_York');
        expectHold(result);
      },
    );

    test(
      'provider retry is idempotent while a changed payload cannot rewrite history',
      () async {
        final first = await observations.importObservation(
          input(id: 'retry-first', providerExternalId: 'provider-retry-1'),
        );
        final retry = await observations.importObservation(
          input(
            id: 'retry-transport-id',
            providerExternalId: 'provider-retry-1',
          ),
        );

        expect(retry.id, first.id);
        expect(await observations.listForUser(userId: 'user-a'), hasLength(1));

        await expectLater(
          observations.importObservation(
            input(
              id: 'retry-conflict',
              value: 5.0,
              providerExternalId: 'provider-retry-1',
            ),
          ),
          throwsA(
            isA<B04RecoveryConflictError>().having(
              (error) => error.code,
              'code',
              'observation_provider_id_conflict',
            ),
          ),
        );
        expect((await observations.rawById(first.id))!.value, 7.5);
      },
    );

    test(
      'corrections append a new observation and snapshot without rewriting prior lineage',
      () async {
        final original = await observations.importObservation(
          input(
            id: 'sleep-original',
            providerExternalId: 'sleep-original-provider',
            observedAtUtc: DateTime.utc(2026, 1, 9, 20),
          ),
        );
        await observations.importObservation(
          input(
            id: 'hrv-original',
            kind: 'heart_rate_variability',
            unit: 'ms',
            value: 50,
            providerExternalId: 'hrv-original-provider',
            observedAtUtc: DateTime.utc(2026, 1, 9, 20),
          ),
        );
        final firstSnapshot = await snapshots.evaluateAndStoreForLocalDate(
          userId: 'user-a',
          localDate: '2026-01-10',
          timezoneId: 'Asia/Kolkata',
          requiredKinds: const ['sleep_duration', 'heart_rate_variability'],
          createdAtUtc: DateTime.utc(2026, 1, 10, 1),
        );
        expect(firstSnapshot, isNotNull);

        final correction = await observations.importObservation(
          input(
            id: 'sleep-correction',
            value: 7.0,
            providerExternalId: 'sleep-correction-provider',
            correctionOfObservationId: original.id,
            observedAtUtc: DateTime.utc(2026, 1, 9, 20),
          ),
        );
        final current = await observations.listForLocalDate(
          userId: 'user-a',
          localDate: '2026-01-10',
          timezoneId: 'Asia/Kolkata',
        );
        expect(current.map((item) => item.id), contains(correction.id));
        expect(current.map((item) => item.id), isNot(contains(original.id)));
        expect((await observations.rawById(original.id))!.value, 7.5);

        final secondSnapshot = await snapshots.evaluateAndStoreForLocalDate(
          userId: 'user-a',
          localDate: '2026-01-10',
          timezoneId: 'Asia/Kolkata',
          requiredKinds: const ['sleep_duration', 'heart_rate_variability'],
          createdAtUtc: DateTime.utc(2026, 1, 10, 2),
        );
        expect(secondSnapshot, isNotNull);
        expect(
          secondSnapshot!.snapshot.supersedesSnapshotId,
          firstSnapshot!.snapshot.id,
        );
        expect(
          secondSnapshot.snapshot.evidenceObservationIds,
          contains(correction.id),
        );
        expect(
          firstSnapshot.snapshot.evidenceObservationIds,
          contains(original.id),
        );
        expect((await snapshots.listForUser(userId: 'user-a')), hasLength(2));
        final oldRow = await snapshots.byId(firstSnapshot.snapshot.id);
        expect(oldRow!.evidenceObservationIds, contains(original.id));
        expect(oldRow.supersededAtUtc, isNull);
        final latest = await snapshots.latestForLocalDate(
          userId: 'user-a',
          localDate: '2026-01-10',
          timezoneId: 'Asia/Kolkata',
        );
        expect(latest!.id, secondSnapshot.snapshot.id);
        expectHold(secondSnapshot);
      },
    );

    test(
      'invalid ranges and permission-as-measurement inputs fail closed',
      () async {
        await expectLater(
          observations.importObservation(
            input(
              id: 'invalid-range',
              lower: 8,
              upper: 7,
              status: RecoveryObservationStatus.estimated,
              value: null,
              providerExternalId: 'invalid-range',
            ),
          ),
          throwsA(
            isA<B04RecoveryValidationError>().having(
              (error) => error.code,
              'code',
              'invalid_observation_range',
            ),
          ),
        );
        await expectLater(
          observations.importObservation(
            input(
              id: 'denied-with-value',
              permission: RecoveryPermissionState.denied,
              providerExternalId: 'denied-with-value',
            ),
          ),
          throwsA(
            isA<B04RecoveryValidationError>().having(
              (error) => error.code,
              'code',
              'permission_state_not_measurement',
            ),
          ),
        );
        expect(await observations.listForUser(userId: 'user-a'), isEmpty);
      },
    );

    test(
      'Backup v9 captures typed recovery provenance and frozen readiness evidence',
      () async {
        await evaluate(
          date: '2026-01-11',
          requiredKinds: const ['sleep_duration'],
          inputs: [
            input(
              id: 'backup-sleep',
              providerExternalId: 'backup-sleep-provider',
              observedAtUtc: DateTime.utc(2026, 1, 11, 18),
            ),
          ],
        );

        final graph = await B04BackupGraph.capture(db);
        graph.validateStructure();
        final recoveryRows = graph.tables['recovery_observations']!;
        final readinessRows = graph.tables['readiness_snapshots']!;
        final evidenceRows = graph.tables['readiness_snapshot_evidence']!;
        expect(recoveryRows, hasLength(1));
        expect(readinessRows, hasLength(1));
        expect(evidenceRows, hasLength(1));
        final provenance =
            jsonDecode(recoveryRows.single['provenance'] as String)
                as Map<String, dynamic>;
        expect(provenance['permission'], 'granted');
        expect(
          recoveryRows.single['provider_external_id'],
          'backup-sleep-provider',
        );
        expect(
          readinessRows.single['policy_version'],
          kB04ReadinessHoldPolicyVersion,
        );
        expect(evidenceRows.single['observation_id'], 'backup-sleep');
      },
    );
  });
}
