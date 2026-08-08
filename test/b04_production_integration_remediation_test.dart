import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/services/local_schedule_date_service.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:indifit/data/models/b04_goal_models.dart';
import 'package:indifit/data/models/b04_recovery_models.dart';
import 'package:indifit/data/repositories/coaching_preference_repository.dart';
import 'package:indifit/data/repositories/readiness_snapshot_repository.dart';
import 'package:indifit/data/repositories/recovery_observation_repository.dart';
import 'package:indifit/data/services/b04_recovery_production_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late LocalScheduleDateService dates;
  final nowUtc = DateTime.utc(2026, 8, 8, 12);

  setUp(() {
    db = AppDatabase.memory();
    dates = LocalScheduleDateService(nowUtc: () => nowUtc);
  });

  tearDown(() => db.close());

  test(
    'eligibility records missing evidence and exact birthday boundary',
    () async {
      final repository = CoachingPreferenceRepository(
        database: db,
        dates: dates,
        nowUtc: () => nowUtc,
      );

      final missing = await repository.recordEligibility(
        CoachingEligibilityCommand(
          userId: 'user-1',
          dateOfBirthLocalDate: null,
          source: CoachingAgeEvidenceSource.missing,
          localDate: '2026-08-08',
          timezoneId: 'UTC',
          evidenceTimestampUtc: nowUtc,
          evaluationUtc: nowUtc,
        ),
      );
      expect(missing.result, CoachingEligibilityResult.unknownAge);

      final birthday = await repository.recordEligibility(
        CoachingEligibilityCommand(
          userId: 'user-1',
          dateOfBirthLocalDate: '2008-08-08',
          localDate: '2026-08-08',
          timezoneId: 'UTC',
          evidenceTimestampUtc: nowUtc,
          evaluationUtc: nowUtc,
        ),
      );
      expect(birthday.result, CoachingEligibilityResult.eligible);

      final dayBefore = await repository.recordEligibility(
        CoachingEligibilityCommand(
          userId: 'user-2',
          dateOfBirthLocalDate: '2008-08-09',
          localDate: '2026-08-08',
          timezoneId: 'UTC',
          evidenceTimestampUtc: nowUtc,
          evaluationUtc: nowUtc,
        ),
      );
      expect(dayBefore.result, CoachingEligibilityResult.underage);
    },
  );

  test(
    'eligibility restart, correction and consent separation preserve history',
    () async {
      final repository = CoachingPreferenceRepository(
        database: db,
        dates: dates,
        nowUtc: () => nowUtc,
      );
      final first = await repository.recordEligibility(
        CoachingEligibilityCommand(
          userId: 'user-1',
          dateOfBirthLocalDate: '1990-01-01',
          localDate: '2026-08-08',
          timezoneId: 'UTC',
          evidenceTimestampUtc: nowUtc,
          evaluationUtc: nowUtc,
        ),
      );
      final retry = await repository.recordEligibility(
        CoachingEligibilityCommand(
          userId: 'user-1',
          dateOfBirthLocalDate: '1990-01-01',
          localDate: '2026-08-08',
          timezoneId: 'UTC',
          evidenceTimestampUtc: nowUtc,
          evaluationUtc: nowUtc.add(const Duration(minutes: 1)),
        ),
      );
      expect(retry.id, first.id);

      final restarted = CoachingPreferenceRepository(
        database: db,
        dates: dates,
        nowUtc: () => nowUtc,
      );
      expect(
        (await restarted.currentEligibility(userId: 'user-1'))!.id,
        first.id,
      );

      final corrected = await restarted.recordEligibility(
        CoachingEligibilityCommand(
          userId: 'user-1',
          dateOfBirthLocalDate: '2015-01-01',
          localDate: '2026-08-08',
          timezoneId: 'UTC',
          evidenceTimestampUtc: nowUtc,
          evaluationUtc: nowUtc,
        ),
      );
      expect(corrected.id, isNot(first.id));
      expect(corrected.result, CoachingEligibilityResult.underage);
      expect(
        (await db.select(db.coachingEligibilityEvaluations).get()),
        hasLength(2),
      );

      await restarted.recordConsent(
        CoachingConsentCommand(
          userId: 'user-1',
          category: CoachingConsentCategory.adaptiveCoaching,
          action: CoachingConsentAction.enable,
          consentPolicyVersion: 'B04-D04-04-CONSENT-V1',
          copyVersion: 'B04-D04-04-COACHING-COPY-V1',
          timestampUtc: nowUtc,
          localDate: '2026-08-08',
          timezoneId: 'UTC',
          actorSource: 'test',
        ),
      );
      expect(
        (await restarted.currentEligibility(
          userId: 'user-1',
          atUtc: corrected.evaluationUtc,
        ))!.result,
        CoachingEligibilityResult.underage,
      );
    },
  );

  test(
    'production readiness adapter preserves typed states and is idempotent',
    () async {
      final observations = RecoveryObservationRepository(
        database: db,
        dates: dates,
      );
      final snapshots = ReadinessSnapshotRepository(
        database: db,
        observations: observations,
        dates: dates,
      );
      final source = _FakeRecoverySource(
        inputs: [
          _input(
            userId: 'user-1',
            kind: 'sleep_duration',
            value: 7,
            source: 'health:sleep',
            providerExternalId: 'sleep-1',
          ),
          _input(
            userId: 'user-1',
            kind: 'workload',
            value: 120,
            source: 'b02_progress',
            providerExternalId: 'workload-1',
          ),
          _input(
            userId: 'user-1',
            kind: 'soreness',
            value: 2,
            source: 'manual:soreness',
            providerExternalId: 'soreness-1',
          ),
          _input(
            userId: 'user-1',
            kind: 'resting_heart_rate',
            value: 58,
            source: 'health:rhr',
            providerExternalId: 'rhr-1',
          ),
        ],
      );
      final adapter = B04RecoveryProductionAdapter(
        observations: observations,
        snapshots: snapshots,
        source: source,
        dates: dates,
        nowUtc: () => nowUtc,
      );

      final first = await adapter.syncAndEvaluate(
        userId: 'user-1',
        localDate: '2026-08-08',
        timezoneId: 'UTC',
      );
      expect(first, isNotNull);
      expect(first!.snapshot.localDate, '2026-08-08');
      expect(first.snapshot.completeness, ReadinessCompleteness.complete);
      expect(first.numericalEffect.calorieDeltaKcal, 0);
      expect(first.numericalEffect.trainingLoadDeltaPercent, 0);

      final second = await adapter.syncAndEvaluate(
        userId: 'user-1',
        localDate: '2026-08-08',
        timezoneId: 'UTC',
      );
      expect(second!.snapshot.id, first.snapshot.id);
      expect(await observations.listForUser(userId: 'user-1'), hasLength(4));

      source.inputs[0] = _input(
        userId: 'user-1',
        kind: 'sleep_duration',
        value: 8,
        source: 'health:sleep',
        providerExternalId: 'sleep-1',
      );
      final corrected = await adapter.syncAndEvaluate(
        userId: 'user-1',
        localDate: '2026-08-08',
        timezoneId: 'UTC',
      );
      expect(corrected!.snapshot.id, isNot(first.snapshot.id));
      expect(await observations.listForUser(userId: 'user-1'), hasLength(5));

      final correctedRetry = await adapter.syncAndEvaluate(
        userId: 'user-1',
        localDate: '2026-08-08',
        timezoneId: 'UTC',
      );
      expect(correctedRetry!.snapshot.id, corrected.snapshot.id);
      expect(await observations.listForUser(userId: 'user-1'), hasLength(5));
    },
  );

  test('partial, denied and stale evidence remains unavailable', () async {
    final observations = RecoveryObservationRepository(
      database: db,
      dates: dates,
    );
    final snapshots = ReadinessSnapshotRepository(
      database: db,
      observations: observations,
      dates: dates,
    );
    final source = _FakeRecoverySource(
      inputs: [
        _input(
          userId: 'user-1',
          kind: 'sleep_duration',
          value: null,
          status: RecoveryObservationStatus.missing,
          permission: RecoveryPermissionState.denied,
          freshness: RecoveryFreshness.unknown,
          source: 'health:sleep',
          providerExternalId: 'sleep-denied',
        ),
        _input(
          userId: 'user-1',
          kind: 'workload',
          value: 100,
          source: 'b02_progress',
          providerExternalId: 'workload-stale',
          freshness: RecoveryFreshness.stale,
        ),
      ],
    );
    final adapter = B04RecoveryProductionAdapter(
      observations: observations,
      snapshots: snapshots,
      source: source,
      dates: dates,
      nowUtc: () => nowUtc,
    );
    final result = await adapter.syncAndEvaluate(
      userId: 'user-1',
      localDate: '2026-08-08',
      timezoneId: 'UTC',
    );
    expect(result!.snapshot.status, ReadinessStatus.unavailable);
    expect(result.snapshot.completeness, isNot(ReadinessCompleteness.complete));
    expect(result.numericalEffect.scheduleDurationDelta, 0);
    expect(result.snapshot.evidence, hasLength(4));
  });
}

class _FakeRecoverySource implements B04RecoveryEvidenceSource {
  final List<B04RecoveryInput> inputs;

  const _FakeRecoverySource({required this.inputs});

  @override
  Future<List<B04RecoveryInput>> read({
    required String userId,
    required String localDate,
    required String timezoneId,
    required DateTime nowUtc,
    required List<String> requiredKinds,
  }) async => inputs;
}

B04RecoveryInput _input({
  required String userId,
  required String kind,
  required double? value,
  required String source,
  required String providerExternalId,
  RecoveryObservationStatus status = RecoveryObservationStatus.known,
  RecoveryPermissionState permission = RecoveryPermissionState.granted,
  RecoveryFreshness freshness = RecoveryFreshness.fresh,
}) => B04RecoveryInput(
  id: '$kind:$providerExternalId',
  userId: userId,
  kind: kind,
  observedAtUtc: DateTime.utc(2026, 8, 8, 12),
  timezoneId: 'UTC',
  status: status,
  unit: kind == 'workload' ? 'minutes' : 'unit',
  value: value,
  lower: null,
  upper: null,
  source: source,
  provenance: 'test:$providerExternalId',
  permission: permission,
  freshness: freshness,
  providerExternalId: providerExternalId,
  sourceVersion: 'test-v1',
  correctionOfObservationId: null,
  evidenceTimestampUtc: DateTime.utc(2026, 8, 8, 12),
);
