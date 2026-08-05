import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/backup/backup_file_adapter.dart';
import 'package:indifit/core/backup/backup_schema.dart';
import 'package:indifit/core/backup/backup_v8.dart';
import 'package:indifit/core/backup/backup_v9.dart';
import 'package:indifit/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'v9 graph round-trips durable B04 lineage and envelope inspection',
    () async {
      final source = AppDatabase.memory();
      final target = AppDatabase.memory();
      addTearDown(source.close);
      addTearDown(target.close);
      await _populateB04Graph(source);

      final backup = await BackupV9Data.createFromDatabase(source);
      final firstJson = jsonEncode(backup.toJson());
      final secondJson = jsonEncode(backup.toJson());

      expect(backup.version, 9);
      expect(backup.schemaVersion, 18);
      expect(firstJson, secondJson);
      expect(backup.adaptiveCoaching.tables.keys, containsAll(_b04Tables));
      expect(firstJson, isNot(contains('prompt')));
      expect(firstJson, isNot(contains('raw_response')));
      expect(firstJson, isNot(contains('image_bytes')));

      final decoded = BackupV9Data.fromJson(
        jsonDecode(firstJson) as Map<String, dynamic>,
      );
      await decoded.restoreToDatabase(target);

      expect(
        await target.select(target.coachingConsentEvents).get(),
        hasLength(4),
      );
      expect(
        (await target.select(target.coachingConsentEvents).get()).map(
          (row) => row.consentCategory,
        ),
        containsAll(['adaptive_coaching', 'optional_ai']),
      );
      expect(
        await target.select(target.coachingEligibilityEvaluations).get(),
        hasLength(3),
      );
      expect(
        await target.select(target.nutritionGoalVersions).get(),
        hasLength(2),
      );
      expect(await target.select(target.recommendations).get(), hasLength(1));
      expect(
        await target.select(target.recommendationFeedback).get(),
        hasLength(2),
      );
      expect(
        (await target.select(target.nutritionGoalVersions).get())
            .singleWhere((row) => row.id == 'goal-v2')
            .supersedesGoalVersionId,
        'goal-v1',
      );
      expect(
        (await target.select(target.recommendations).get())
            .single
            .exactResultNumerator,
        '1810',
      );
      expect(
        await target.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      await expectLater(
        target.customStatement(
          "UPDATE recommendations SET explanation = 'changed' WHERE id = 'recommendation-a'",
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        target.customStatement(
          "DELETE FROM coaching_consent_events WHERE id = 'consent-adaptive-enable'",
        ),
        throwsA(isA<Exception>()),
      );

      final envelope = BackupFileAdapter.exportV9ToEnvelopeJson(data: backup);
      final inspection = await BackupFileAdapter.inspectBackupContent(envelope);
      expect(inspection.envelope.version, 9);
      expect(inspection.backupV9Data, isNotNull);
      expect(
        inspection
            .backupV9Data!
            .adaptiveCoaching
            .tables['coaching_consent_events'],
        hasLength(4),
      );
      final encrypted = BackupFileAdapter.exportV9ToEnvelopeJson(
        data: backup,
        password: 'b04-v9-test-password',
      );
      await expectLater(
        BackupFileAdapter.inspectBackupContent(encrypted),
        throwsA(isA<FormatException>()),
      );
      final decrypted = await BackupFileAdapter.inspectBackupContent(
        encrypted,
        password: 'b04-v9-test-password',
      );
      expect(decrypted.backupV9Data, isNotNull);
    },
  );

  test(
    'v5-v8 imports restore an empty B04 graph without fabrication',
    () async {
      final source = AppDatabase.memory();
      final target = AppDatabase.memory();
      addTearDown(source.close);
      addTearDown(target.close);
      await _populateB04Graph(source);
      await _insertSentinelConsent(target, 'pre-existing');

      final v8 = await BackupV8Data.createFromDatabase(source);
      final decoded = BackupV9Data.fromJson(
        jsonDecode(jsonEncode(v8.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.version, 8);
      expect(decoded.adaptiveCoaching.tables, isEmpty);

      await decoded.restoreToDatabase(target);
      expect(await target.select(target.coachingConsentEvents).get(), isEmpty);
      expect(
        await target.select(target.coachingEligibilityEvaluations).get(),
        isEmpty,
      );
    },
  );

  test(
    'v9 rejects duplicate, cross-user, ordered and policy-invalid graphs',
    () async {
      final source = AppDatabase.memory();
      addTearDown(source.close);
      await _populateB04Graph(source);
      final valid =
          jsonDecode(
                jsonEncode(
                  (await BackupV9Data.createFromDatabase(source)).toJson(),
                ),
              )
              as Map<String, dynamic>;

      final duplicate = _copy(valid);
      final duplicateRows = _table(duplicate, 'coaching_consent_events');
      duplicateRows.add(Map<String, dynamic>.from(duplicateRows.first));
      expect(
        () => BackupV9Data.fromJson(duplicate),
        throwsA(
          isA<BackupV9ValidationException>().having(
            (error) => error.code,
            'code',
            'duplicate_id',
          ),
        ),
      );

      final crossUser = _copy(valid);
      final crossUserGoal = _table(
        crossUser,
        'nutrition_goal_versions',
      ).singleWhere((row) => row['id'] == 'goal-v1');
      crossUserGoal['user_id'] = 'user-b';
      expect(
        () => BackupV9Data.fromJson(crossUser),
        throwsA(
          isA<BackupV9ValidationException>().having(
            (error) => error.code,
            'code',
            'cross_user_reference',
          ),
        ),
      );

      final invalidOrder = _copy(valid);
      final consent = _table(
        invalidOrder,
        'coaching_consent_events',
      ).singleWhere((row) => row['id'] == 'consent-adaptive-disable');
      consent['timestamp_utc'] = '2025-12-31T23:00:00.000Z';
      expect(
        () => BackupV9Data.fromJson(invalidOrder),
        throwsA(
          isA<BackupV9ValidationException>().having(
            (error) => error.code,
            'code',
            'invalid_event_order',
          ),
        ),
      );

      final unsupportedPolicy = _copy(valid);
      _table(unsupportedPolicy, 'recommendations').single['policy_version'] =
          'future-policy';
      expect(
        () => BackupV9Data.fromJson(unsupportedPolicy),
        throwsA(
          isA<BackupV9ValidationException>().having(
            (error) => error.code,
            'code',
            'unsupported_policy_version',
          ),
        ),
      );

      final missingReference = _copy(valid);
      _table(missingReference, 'recommendations').single['goal_version_id'] =
          'missing-goal';
      expect(
        () => BackupV9Data.fromJson(missingReference),
        throwsA(
          isA<BackupV9ValidationException>().having(
            (error) => error.code,
            'code',
            'missing_reference',
          ),
        ),
      );

      final cyclicLineage = _copy(valid);
      _table(
        cyclicLineage,
        'recommendations',
      ).single['supersedes_recommendation_id'] = 'recommendation-a';
      expect(
        () => BackupV9Data.fromJson(cyclicLineage),
        throwsA(
          isA<BackupV9ValidationException>().having(
            (error) => error.code,
            'code',
            'cyclic_relationship',
          ),
        ),
      );

      final partialExactResult = _copy(valid);
      _table(
        partialExactResult,
        'recommendations',
      ).single['exact_result_denominator'] = null;
      expect(
        () => BackupV9Data.fromJson(partialExactResult),
        throwsA(
          isA<BackupV9ValidationException>().having(
            (error) => error.code,
            'code',
            'invalid_exact_result',
          ),
        ),
      );

      final malformedTypedValue = _copy(valid);
      _table(malformedTypedValue, 'recommendations').single['explanation'] = {
        'prompt': 'raw provider prompt',
      };
      expect(
        () => BackupV9Data.fromJson(malformedTypedValue),
        throwsA(
          isA<BackupV9ValidationException>().having(
            (error) => error.code,
            'code',
            'invalid_typed_column',
          ),
        ),
      );

      final future = _copy(valid)..['version'] = 10;
      expect(
        () => BackupV9Data.fromJson(future),
        throwsA(
          isA<BackupV9ValidationException>().having(
            (error) => error.code,
            'code',
            'unsupported_newer_version',
          ),
        ),
      );
    },
  );

  test('offset-less v9 timestamps are interpreted as UTC', () async {
    final source = AppDatabase.memory();
    final target = AppDatabase.memory();
    addTearDown(source.close);
    addTearDown(target.close);
    await _populateB04Graph(source);

    final payload =
        jsonDecode(
              jsonEncode(
                (await BackupV9Data.createFromDatabase(source)).toJson(),
              ),
            )
            as Map<String, dynamic>;
    _table(payload, 'nutrition_goal_versions').first['created_at_utc'] =
        '2026-01-01T00:00:00';

    await BackupV9Data.fromJson(payload).restoreToDatabase(target);
    final restored = (await target.select(target.nutritionGoalVersions).get())
        .singleWhere((row) => row.id == 'goal-v1');
    expect(
      restored.createdAtUtc.toUtc(),
      DateTime.parse('2026-01-01T00:00:00.000Z'),
    );
  });

  test('invalid v9 restore rolls back and a retry succeeds', () async {
    final source = AppDatabase.memory();
    final target = AppDatabase.memory();
    addTearDown(source.close);
    addTearDown(target.close);
    await _populateB04Graph(source);
    await _insertSentinelConsent(target, 'restore-sentinel');
    final backup = await BackupV9Data.createFromDatabase(source);

    expect(
      () => backup.restoreToDatabaseWithFailureInjector(
        target,
        failureInjector: (stage) async {
          if (stage == BackupRestoreFailureStage.databaseMutation) {
            throw StateError('injected restore failure');
          }
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      (await target.select(target.coachingConsentEvents).get()).single.id,
      'restore-sentinel',
    );

    await backup.restoreToDatabase(target);
    expect(
      await target.select(target.coachingConsentEvents).get(),
      hasLength(4),
    );
  });
}

const _b04Tables = {
  'nutrition_goal_versions',
  'coaching_consent_events',
  'nutrition_coaching_preferences',
  'recovery_observations',
  'readiness_snapshots',
  'readiness_snapshot_evidence',
  'recommendations',
  'recommendation_evidence',
  'coaching_eligibility_evaluations',
  'recommendation_feedback',
};

Future<void> _populateB04Graph(AppDatabase db) async {
  final t0 =
      DateTime.parse('2026-01-01T08:00:00.000Z').millisecondsSinceEpoch ~/
      Duration.millisecondsPerSecond;
  await _insert(
    db,
    'nutrition_goal_versions',
    [
      'id',
      'user_id',
      'version_number',
      'goal_type',
      'target_source',
      'calorie_target_kcal',
      'policy_version',
      'calculation_version',
      'algorithm_version',
      'effective_from_local_date',
      'timezone_id',
      'evidence_fingerprint',
      'exact_result_numerator',
      'exact_result_denominator',
      'normalized_maintenance_kcal',
      'created_at_utc',
    ],
    [
      'goal-v1',
      'user-a',
      1,
      'maintenance',
      'user_set',
      1800,
      'B04-D04-HOLD-1',
      'calc-1',
      'algo-1',
      '2026-01-01',
      'Asia/Kolkata',
      'goal-fp-1',
      '1800',
      '1',
      1800,
      t0,
    ],
  );
  await _insert(
    db,
    'nutrition_goal_versions',
    [
      'id',
      'user_id',
      'version_number',
      'goal_type',
      'target_source',
      'calorie_target_kcal',
      'policy_version',
      'calculation_version',
      'algorithm_version',
      'effective_from_local_date',
      'timezone_id',
      'supersedes_goal_version_id',
      'exact_result_numerator',
      'exact_result_denominator',
      'normalized_maintenance_kcal',
      'created_at_utc',
    ],
    [
      'goal-v2',
      'user-a',
      2,
      'maintenance',
      'adaptive',
      1810,
      'B04-D04-ENABLED-1',
      'calc-2',
      'algo-2',
      '2026-01-02',
      'Asia/Kolkata',
      'goal-v1',
      '1810',
      '1',
      1810,
      t0 + 1000,
    ],
  );
  await _insert(
    db,
    'coaching_consent_events',
    [
      'id',
      'user_id',
      'consent_category',
      'action',
      'consent_policy_version',
      'copy_version',
      'timestamp_utc',
      'local_date',
      'timezone_id',
      'actor_source',
      'created_at_utc',
    ],
    [
      'consent-adaptive-enable',
      'user-a',
      'adaptive_coaching',
      'enable',
      'consent-1',
      'copy-1',
      t0 + 2000,
      '2026-01-01',
      'Asia/Kolkata',
      'user',
      t0 + 2000,
    ],
  );
  await _insert(
    db,
    'coaching_consent_events',
    [
      'id',
      'user_id',
      'consent_category',
      'action',
      'consent_policy_version',
      'copy_version',
      'timestamp_utc',
      'local_date',
      'timezone_id',
      'actor_source',
      'related_or_superseded_event_id',
      'created_at_utc',
    ],
    [
      'consent-adaptive-disable',
      'user-a',
      'adaptive_coaching',
      'disable',
      'consent-1',
      'copy-1',
      t0 + 3000,
      '2026-01-01',
      'Asia/Kolkata',
      'user',
      'consent-adaptive-enable',
      t0 + 3000,
    ],
  );
  await _insert(
    db,
    'coaching_consent_events',
    [
      'id',
      'user_id',
      'consent_category',
      'action',
      'consent_policy_version',
      'copy_version',
      'timestamp_utc',
      'local_date',
      'timezone_id',
      'actor_source',
      'related_or_superseded_event_id',
      'created_at_utc',
    ],
    [
      'consent-adaptive-withdraw',
      'user-a',
      'adaptive_coaching',
      'withdraw',
      'consent-1',
      'copy-1',
      t0 + 4000,
      '2026-01-01',
      'Asia/Kolkata',
      'user',
      'consent-adaptive-disable',
      t0 + 4000,
    ],
  );
  await _insert(
    db,
    'coaching_consent_events',
    [
      'id',
      'user_id',
      'consent_category',
      'action',
      'consent_policy_version',
      'copy_version',
      'timestamp_utc',
      'local_date',
      'timezone_id',
      'actor_source',
      'created_at_utc',
    ],
    [
      'consent-ai-enable',
      'user-a',
      'optional_ai',
      'enable',
      'consent-1',
      'copy-1',
      t0 + 2500,
      '2026-01-01',
      'Asia/Kolkata',
      'user',
      t0 + 2500,
    ],
  );
  await _insert(
    db,
    'nutrition_coaching_preferences',
    [
      'id',
      'user_id',
      'adaptive_coaching_enabled',
      'optional_ai_enabled',
      'projection_version',
      'is_archived',
      'created_at_utc',
      'updated_at_utc',
    ],
    ['prefs-a', 'user-a', 0, 1, 1, 0, t0, t0],
  );
  await _insert(
    db,
    'recovery_observations',
    [
      'id',
      'user_id',
      'kind',
      'observed_at_utc',
      'local_date',
      'timezone_id',
      'status',
      'unit',
      'value',
      'source',
      'provenance',
      'freshness',
      'created_at_utc',
    ],
    [
      'recovery-a',
      'user-a',
      'sleep',
      t0,
      '2026-01-01',
      'Asia/Kolkata',
      'known',
      'hours',
      7.5,
      'user',
      'user_reported',
      'fresh',
      t0,
    ],
  );
  await _insert(
    db,
    'readiness_snapshots',
    [
      'id',
      'user_id',
      'local_date',
      'timezone_id',
      'completeness',
      'status',
      'band',
      'confidence',
      'calculation_version',
      'policy_version',
      'evidence_fingerprint',
      'created_at_utc',
    ],
    [
      'readiness-a',
      'user-a',
      '2026-01-01',
      'Asia/Kolkata',
      'complete',
      'available',
      'ready',
      .9,
      'readiness-1',
      'B04-D04-READINESS-HOLD-1',
      'readiness-fp',
      t0 + 5000,
    ],
  );
  await _insert(
    db,
    'readiness_snapshot_evidence',
    [
      'id',
      'readiness_snapshot_id',
      'observation_id',
      'evidence_kind',
      'status',
      'value',
      'unit',
      'created_at_utc',
    ],
    [
      'readiness-evidence-a',
      'readiness-a',
      'recovery-a',
      'sleep',
      'known',
      7.5,
      'hours',
      t0 + 5000,
    ],
  );
  await _insert(
    db,
    'recommendations',
    [
      'id',
      'user_id',
      'scope',
      'local_period_start',
      'local_period_end',
      'timezone_id',
      'status',
      'priority',
      'confidence',
      'action',
      'explanation',
      'rule_version',
      'calculation_version',
      'algorithm_version',
      'policy_version',
      'goal_version_id',
      'readiness_snapshot_id',
      'context_fingerprint',
      'evidence_fingerprint',
      'exact_result_numerator',
      'exact_result_denominator',
      'normalized_maintenance_kcal',
      'proposed_delta_kcal',
      'created_at_utc',
    ],
    [
      'recommendation-a',
      'user-a',
      'daily',
      '2026-01-02',
      '2026-01-02',
      'Asia/Kolkata',
      'available',
      1,
      .8,
      'review target',
      'Evidence-backed target history',
      'rule-1',
      'calc-2',
      'algo-2',
      'B04-D04-ENABLED-1',
      'goal-v2',
      'readiness-a',
      'context-fp',
      'recommendation-fp',
      '1810',
      '1',
      1810,
      0,
      t0 + 6000,
    ],
  );
  await _insert(
    db,
    'recommendation_evidence',
    [
      'id',
      'recommendation_id',
      'user_id',
      'evidence_kind',
      'source_type',
      'source_id',
      'source_version',
      'status',
      'value',
      'unit',
      'local_date',
      'timezone_id',
      'created_at_utc',
    ],
    [
      'recommendation-evidence-a',
      'recommendation-a',
      'user-a',
      'goal',
      'goal_version',
      'goal-v2',
      'calc-2',
      'confirmed',
      1810,
      'kcal',
      '2026-01-02',
      'Asia/Kolkata',
      t0 + 6000,
    ],
  );
  for (final entry in const [
    ('eligibility-unknown', 'unknown_age', 'unknown'),
    ('eligibility-conflicting', 'conflicting_age', 'conflicting'),
    ('eligibility-withheld', 'withheld_age', 'withheld'),
  ]) {
    await _insert(
      db,
      'coaching_eligibility_evaluations',
      [
        'id',
        'user_id',
        'result',
        'reason_code',
        'age_input_source',
        'evidence_timestamp_utc',
        'evaluation_utc',
        'evaluation_local_date',
        'timezone_id',
        'policy_version',
        'minimum_age_rule_version',
        'recommendation_id',
        'created_at_utc',
      ],
      [
        entry.$1,
        'user-a',
        entry.$2,
        entry.$2,
        entry.$3,
        t0 + 7000,
        t0 + 7000 + entry.$1.hashCode.abs() % 1000,
        '2026-01-02',
        'Asia/Kolkata',
        'B04-D04-HOLD-1',
        'age-rule-18',
        'recommendation-a',
        t0 + 7000,
      ],
    );
  }
  await _insert(
    db,
    'recommendation_feedback',
    [
      'id',
      'user_id',
      'recommendation_id',
      'action',
      'source',
      'local_date',
      'timezone_id',
      'created_at_utc',
    ],
    [
      'feedback-a',
      'user-a',
      'recommendation-a',
      'accept',
      'user',
      '2026-01-02',
      'Asia/Kolkata',
      t0 + 8000,
    ],
  );
  await _insert(
    db,
    'recommendation_feedback',
    [
      'id',
      'user_id',
      'recommendation_id',
      'action',
      'reason',
      'source',
      'local_date',
      'timezone_id',
      'created_at_utc',
      'related_feedback_id',
    ],
    [
      'feedback-b',
      'user-a',
      'recommendation-a',
      'override',
      'user requested review',
      'user',
      '2026-01-02',
      'Asia/Kolkata',
      t0 + 9000,
      'feedback-a',
    ],
  );
}

Future<void> _insertSentinelConsent(AppDatabase db, String id) => _insert(
  db,
  'coaching_consent_events',
  [
    'id',
    'user_id',
    'consent_category',
    'action',
    'consent_policy_version',
    'copy_version',
    'timestamp_utc',
    'local_date',
    'timezone_id',
    'actor_source',
  ],
  [
    id,
    'user-a',
    'adaptive_coaching',
    'enable',
    'consent-1',
    'copy-1',
    1,
    '1970-01-01',
    'UTC',
    'test',
  ],
);

Future<void> _insert(
  AppDatabase db,
  String table,
  List<String> columns,
  List<Object?> values,
) => db.customStatement(
  'INSERT INTO $table (${columns.join(', ')}) VALUES '
  '(${List.filled(columns.length, '?').join(', ')})',
  values,
);

Map<String, dynamic> _copy(Map<String, dynamic> source) =>
    jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

List<Map<String, dynamic>> _table(Map<String, dynamic> json, String name) =>
    (((json['b04_graph'] as Map<String, dynamic>)['tables']
                as Map<String, dynamic>)[name]
            as List)
        .cast<Map<String, dynamic>>();
