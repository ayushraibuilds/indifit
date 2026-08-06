import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/data/database/app_database.dart';

import 'fixtures/b03_migration_backup_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('indifit-b04-v18-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('fresh v18 creation exposes B04 tables, indexes and empty state', () async {
    final db = AppDatabase.memory();
    try {
      expect(db.schemaVersion, 19);
      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .get();
      final names = tables.map((row) => row.data['name'] as String).toSet();
      expect(
        names,
        containsAll([
          'nutrition_goal_versions',
          'coaching_consent_events',
          'nutrition_coaching_preferences',
          'recovery_observations',
          'readiness_snapshots',
          'readiness_snapshot_evidence',
          'coaching_eligibility_evaluations',
          'recommendations',
          'recommendation_evidence',
          'recommendation_feedback',
        ]),
      );
      expect(
        await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE '%cache%'",
            )
            .get(),
        isEmpty,
      );
      final indexes = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final indexNames = indexes
          .map((row) => row.data['name'] as String)
          .toSet();
      expect(
        indexNames,
        containsAll(const [
          'nutrition_goal_versions_user_effective_idx',
          'coaching_consent_events_user_date_idx',
          'nutrition_coaching_preferences_user_idx',
          'recovery_observations_user_time_kind_idx',
          'recovery_observations_user_date_idx',
          'readiness_snapshots_user_date_version_idx',
          'readiness_snapshot_evidence_snapshot_idx',
          'recommendations_user_scope_period_status_idx',
          'recommendations_goal_readiness_idx',
          'recommendation_evidence_recommendation_source_idx',
          'coaching_eligibility_evaluations_user_date_result_idx',
          'coaching_eligibility_evaluations_goal_recommendation_idx',
          'recommendation_feedback_recommendation_time_idx',
          'recommendation_feedback_user_time_idx',
        ]),
      );
      expect(await db.select(db.coachingConsentEvents).get(), isEmpty);
      expect(await db.select(db.coachingEligibilityEvaluations).get(), isEmpty);
      await db.customStatement('''
        INSERT INTO nutrition_coaching_preferences (id, user_id)
        VALUES ('user-a', 'user-a')
      ''');
      final defaultPreferences = await db
          .select(db.nutritionCoachingPreferences)
          .getSingle();
      expect(defaultPreferences.adaptiveCoachingEnabled, isFalse);
      expect(defaultPreferences.optionalAiEnabled, isFalse);
      for (final table in const [
        'nutrition_goal_versions',
        'coaching_consent_events',
        'readiness_snapshots',
        'readiness_snapshot_evidence',
        'recommendations',
        'recommendation_evidence',
        'coaching_eligibility_evaluations',
        'recommendation_feedback',
      ]) {
        expect(
          await db.customSelect('PRAGMA foreign_key_list($table)').get(),
          isNotEmpty,
          reason: '$table must expose its declared foreign-key relationships',
        );
      }
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    } finally {
      await db.close();
    }
  });

  test(
    'v17 to v18 migration preserves B03 rows and starts B04 empty',
    () async {
      final file = await B03V16Fixture.copyCompleteTo(
        tempDir,
        filename: 'v17.db',
      );
      final v17 = AppDatabase.executor(
        NativeDatabase(file),
        schemaVersionOverride: 17,
      );
      try {
        await v17.customSelect('SELECT 1').get();
        expect(B03V16Fixture.readUserVersion(file), 17);
        await v17
            .into(v17.nutritionPersonalVessels)
            .insert(
              NutritionPersonalVesselsCompanion.insert(
                id: 'v17-vessel',
                userId: 'user-a',
                displayName: 'V17 Vessel',
              ),
            );
      } finally {
        await v17.close();
      }

      final migrated = AppDatabase.executor(NativeDatabase(file));
      try {
        await migrated.customSelect('SELECT 1').get();
        expect(B03V16Fixture.readUserVersion(file), 19);
        expect(migrated.schemaVersion, 19);
        expect(
          await migrated.select(migrated.nutritionPersonalVessels).get(),
          hasLength(1),
        );
        expect(
          await migrated.select(migrated.nutritionGoalVersions).get(),
          isEmpty,
        );
        expect(await migrated.select(migrated.recommendations).get(), isEmpty);
        expect(
          await migrated.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await migrated.close();
      }

      final reopened = AppDatabase.executor(NativeDatabase(file));
      try {
        await reopened.customSelect('SELECT 1').get();
        expect(B03V16Fixture.readUserVersion(file), 19);
        expect(
          await reopened.select(reopened.nutritionGoalVersions).get(),
          isEmpty,
        );
      } finally {
        await reopened.close();
      }
    },
  );

  test(
    'v16 to v18 chained migration preserves the accepted B03 graph',
    () async {
      final file = await B03V16Fixture.copyCompleteTo(
        tempDir,
        filename: 'v16-chain.db',
      );
      final db = AppDatabase.executor(NativeDatabase(file));
      try {
        await db.customSelect('SELECT 1').get();
        expect(B03V16Fixture.readUserVersion(file), 19);
        expect(await db.select(db.foodLogs).get(), hasLength(3));
        expect(await db.select(db.nutritionGoalVersions).get(), isEmpty);
        expect(await db.select(db.recommendations).get(), isEmpty);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'each v17 to v18 migration failure rolls back and retry succeeds',
    () async {
      for (final stage in V18MigrationFailureStage.values) {
        final file = await B03V16Fixture.copyCompleteTo(
          tempDir,
          filename: 'failure-${stage.name}.db',
        );
        final source = AppDatabase.executor(
          NativeDatabase(file),
          schemaVersionOverride: 17,
        );
        await source.customSelect('SELECT 1').get();
        await source.close();

        final failing = AppDatabase.executor(
          NativeDatabase(file),
          v18MigrationFailureStageInjector: (actual) async {
            if (actual == stage) {
              throw StateError('B04 injected failure at ${stage.name}');
            }
          },
        );
        await expectLater(
          failing.customSelect('SELECT 1').get(),
          throwsA(isA<StateError>()),
        );
        await failing.close();
        expect(B03V16Fixture.readUserVersion(file), 17);

        final retry = AppDatabase.executor(NativeDatabase(file));
        try {
          await retry.customSelect('SELECT 1').get();
          expect(B03V16Fixture.readUserVersion(file), 19);
          expect(
            await retry.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await retry.close();
        }
      }
    },
  );

  test(
    'consent and lineage authorities are append-only and owner-scoped',
    () async {
      final db = AppDatabase.memory();
      try {
        await db.customStatement('''
        INSERT INTO coaching_consent_events
          (id, user_id, consent_category, action, consent_policy_version,
           copy_version, timestamp_utc, local_date, timezone_id, actor_source)
        VALUES ('consent-1', 'user-a', 'adaptive_coaching', 'enable',
                'policy-1', 'copy-1', 1000, '2026-01-01', 'Asia/Kolkata', 'user')
      ''');
        await expectLater(
          db.customStatement(
            "UPDATE coaching_consent_events SET action = 'disable' WHERE id = 'consent-1'",
          ),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          db.customStatement(
            "DELETE FROM coaching_consent_events WHERE id = 'consent-1'",
          ),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          db.customStatement('''
          INSERT INTO coaching_consent_events
            (id, user_id, consent_category, action, consent_policy_version,
             copy_version, timestamp_utc, local_date, timezone_id, actor_source)
          VALUES ('consent-invalid', 'user-a', 'adaptive_coaching', 'invalid',
                  'policy-1', 'copy-1', 1001, '2026-01-01', 'Asia/Kolkata', 'user')
        '''),
          throwsA(isA<Exception>()),
        );

        await db.customStatement('''
        INSERT INTO nutrition_goal_versions
          (id, user_id, version_number, goal_type, target_source,
           effective_from_local_date, timezone_id)
        VALUES ('goal-a', 'user-a', 1, 'maintenance', 'user_set',
                '2026-01-01', 'Asia/Kolkata')
      ''');
        await expectLater(
          db.customStatement('''
          INSERT INTO nutrition_goal_versions
            (id, user_id, version_number, goal_type, target_source,
             effective_from_local_date, timezone_id, supersedes_goal_version_id)
          VALUES ('goal-a-invalid-version', 'user-a', 1, 'maintenance',
                  'user_set', '2026-01-02', 'Asia/Kolkata', 'goal-a')
        '''),
          throwsA(isA<Exception>()),
        );
        await db.customStatement('''
          INSERT INTO nutrition_goal_versions
            (id, user_id, version_number, goal_type, target_source,
             effective_from_local_date, timezone_id, supersedes_goal_version_id)
          VALUES ('goal-a-v2', 'user-a', 2, 'maintenance', 'user_set',
                  '2026-01-02', 'Asia/Kolkata', 'goal-a')
        ''');
        await expectLater(
          db.customStatement('''
          INSERT INTO recommendations
            (id, user_id, scope, local_period_start, local_period_end,
             timezone_id, status, priority, action, explanation, rule_version,
             context_fingerprint, goal_version_id)
          VALUES ('recommendation-b', 'user-b', 'daily', '2026-01-01',
                  '2026-01-01', 'Asia/Kolkata', 'available', 1, 'review',
                  'Review evidence', 'rule-1', 'context-1', 'goal-a')
        '''),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          db.customStatement('''
          INSERT INTO coaching_eligibility_evaluations
            (id, user_id, result, reason_code, age_input_source,
             evidence_timestamp_utc, evaluation_utc, evaluation_local_date,
             timezone_id, policy_version, minimum_age_rule_version)
          VALUES ('eligibility-invalid', 'user-a', 'eligible', 'verified',
                  'unknown', 1000, 1000, '2026-01-01', 'Asia/Kolkata',
                  'policy-1', 'age-18')
        '''),
          throwsA(isA<Exception>()),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'consent history separates categories and recovery deduplication is user-scoped',
    () async {
      final db = AppDatabase.memory();
      try {
        for (final event in const [
          ('consent-adaptive-enable', 'adaptive_coaching', 'enable', 1000),
          ('consent-ai-enable', 'optional_ai', 'enable', 1001),
          ('consent-adaptive-disable', 'adaptive_coaching', 'disable', 1002),
        ]) {
          await db.customStatement('''
            INSERT INTO coaching_consent_events
              (id, user_id, consent_category, action, consent_policy_version,
               copy_version, timestamp_utc, local_date, timezone_id, actor_source)
            VALUES ('${event.$1}', 'user-a', '${event.$2}', '${event.$3}',
                    'policy-1', 'copy-1', ${event.$4}, '2026-01-01',
                    'Asia/Kolkata', 'user')
          ''');
        }
        final events = await db.select(db.coachingConsentEvents).get();
        expect(
          events.map((event) => event.consentCategory),
          containsAll(['adaptive_coaching', 'optional_ai']),
        );
        expect(
          events.where((event) => event.consentCategory == 'adaptive_coaching'),
          hasLength(2),
        );

        Future<void> insertRecovery(String id, String userId, int timestamp) =>
            db.customStatement('''
              INSERT INTO recovery_observations
                (id, user_id, kind, observed_at_utc, local_date, timezone_id,
                 status, unit, value, source, provenance, freshness,
                 provider_external_id)
              VALUES ('$id', '$userId', 'sleep', $timestamp, '2026-01-01',
                      'Asia/Kolkata', 'known', 'hours', 7.5, 'provider',
                      'fixture-v1', 'fresh', 'external-1')
            ''');
        await insertRecovery('recovery-a', 'user-a', 2000);
        await expectLater(
          insertRecovery('recovery-a-duplicate', 'user-a', 2001),
          throwsA(isA<Exception>()),
        );
        await insertRecovery('recovery-b', 'user-b', 2000);
        expect(await db.select(db.recoveryObservations).get(), hasLength(2));
      } finally {
        await db.close();
      }
    },
  );

  test(
    'readiness and recommendation supersession cannot cross users',
    () async {
      final db = AppDatabase.memory();
      try {
        await db.customStatement('''
          INSERT INTO readiness_snapshots
            (id, user_id, local_date, timezone_id, completeness, status,
             calculation_version)
          VALUES ('readiness-b', 'user-b', '2026-01-01', 'Asia/Kolkata',
                  'complete', 'available', 'readiness-1')
        ''');
        await expectLater(
          db.customStatement('''
            INSERT INTO readiness_snapshots
              (id, user_id, local_date, timezone_id, completeness, status,
               calculation_version, supersedes_snapshot_id)
            VALUES ('readiness-a', 'user-a', '2026-01-02', 'Asia/Kolkata',
                    'complete', 'available', 'readiness-2', 'readiness-b')
          '''),
          throwsA(isA<Exception>()),
        );

        await db.customStatement('''
          INSERT INTO recommendations
            (id, user_id, scope, local_period_start, local_period_end,
             timezone_id, status, priority, action, explanation, rule_version,
             context_fingerprint)
          VALUES ('recommendation-b', 'user-b', 'daily', '2026-01-01',
                  '2026-01-01', 'Asia/Kolkata', 'available', 1, 'review',
                  'Review evidence', 'rule-1', 'context-b')
        ''');
        await expectLater(
          db.customStatement('''
            INSERT INTO recommendations
              (id, user_id, scope, local_period_start, local_period_end,
               timezone_id, status, priority, action, explanation, rule_version,
               context_fingerprint, supersedes_recommendation_id)
            VALUES ('recommendation-a', 'user-a', 'daily', '2026-01-02',
                    '2026-01-02', 'Asia/Kolkata', 'available', 1, 'review',
                    'Review evidence', 'rule-1', 'context-a',
                    'recommendation-b')
          '''),
          throwsA(isA<Exception>()),
        );

        await db.customStatement('''
          INSERT INTO recommendations
            (id, user_id, scope, local_period_start, local_period_end,
             timezone_id, status, priority, action, explanation, rule_version,
             context_fingerprint, supersedes_recommendation_id)
          VALUES ('recommendation-b-v2', 'user-b', 'daily', '2026-01-02',
                  '2026-01-02', 'Asia/Kolkata', 'available', 1, 'review',
                  'Review evidence', 'rule-1', 'context-b-v2',
                  'recommendation-b')
        ''');
        expect(await db.select(db.recommendations).get(), hasLength(2));
      } finally {
        await db.close();
      }
    },
  );

  test(
    'versioned policy, exact-result and eligibility history round trips',
    () async {
      final db = AppDatabase.memory();
      try {
        await db.customStatement('''
        INSERT INTO nutrition_goal_versions
          (id, user_id, version_number, goal_type, target_source,
           policy_version, calculation_version, algorithm_version,
           effective_from_local_date, timezone_id, exact_result_numerator,
           exact_result_denominator, normalized_maintenance_kcal)
        VALUES ('goal-lineage', 'user-a', 1, 'loss', 'adaptive',
                'B04-D04-HOLD-1', 'calc-1', 'algo-1', '2026-01-01',
                'Asia/Kolkata', '7', '2', 2001)
      ''');
        await db.customStatement('''
        INSERT INTO recovery_observations
          (id, user_id, kind, observed_at_utc, local_date, timezone_id,
           status, unit, value, source, provenance, freshness)
        VALUES ('recovery-lineage', 'user-a', 'sleep', 1000, '2026-01-01',
                'Asia/Kolkata', 'known', 'hours', 7.5, 'fixture',
                'fixture-v1', 'fresh')
      ''');
        await db.customStatement('''
        INSERT INTO readiness_snapshots
          (id, user_id, local_date, timezone_id, completeness, status,
           band, confidence, calculation_version, policy_version)
        VALUES ('readiness-lineage', 'user-a', '2026-01-01', 'Asia/Kolkata',
                'complete', 'available', 'ready', 0.8, 'readiness-1',
                'B04-D04-READINESS-HOLD-1')
      ''');
        await db.customStatement('''
        INSERT INTO readiness_snapshot_evidence
          (id, readiness_snapshot_id, observation_id, evidence_kind, status,
           value, unit, source_version)
        VALUES ('readiness-evidence', 'readiness-lineage', 'recovery-lineage',
                'sleep', 'known', 7.5, 'hours', 'fixture-v1')
      ''');
        await db.customStatement('''
        INSERT INTO recommendations
          (id, user_id, scope, local_period_start, local_period_end,
           timezone_id, status, priority, action, explanation, rule_version,
           calculation_version, algorithm_version, policy_version,
           goal_version_id, readiness_snapshot_id, context_fingerprint,
           exact_result_numerator, exact_result_denominator,
           normalized_maintenance_kcal, proposed_delta_kcal, replay_hash)
        VALUES ('recommendation-lineage', 'user-a', 'daily', '2026-01-01',
                '2026-01-01', 'Asia/Kolkata', 'unavailable', 0, 'hold',
                'Adaptive coaching is unavailable.', 'rule-1', 'calc-1',
                'algo-1', 'B04-D04-HOLD-1', 'goal-lineage',
                'readiness-lineage', 'context-1', '7', '2', 2001, 0,
                'replay-1')
      ''');
        await db.customStatement('''
        INSERT INTO recommendation_evidence
          (id, recommendation_id, user_id, evidence_kind, source_type,
           source_id, source_version, status, value, unit,
           exact_result_numerator, exact_result_denominator,
           normalized_maintenance_kcal, local_date, timezone_id)
        VALUES ('recommendation-evidence', 'recommendation-lineage', 'user-a',
                'policy', 'fixture', 'goal-lineage', 'policy-1', 'known',
                2001, 'energy_kilocalorie', '7', '2', 2001, '2026-01-01',
                'Asia/Kolkata')
      ''');

        const eligibilityCases = [
          ('eligible', 'verified_dob'),
          ('underage', 'user_entered_dob'),
          ('unknown_age', 'unknown'),
          ('conflicting_age', 'conflicting'),
          ('withheld_age', 'withheld'),
          ('invalid_evidence', 'invalid'),
          ('policy_unavailable', 'policy'),
        ];
        for (var index = 0; index < eligibilityCases.length; index++) {
          final (result, source) = eligibilityCases[index];
          await db.customStatement('''
          INSERT INTO coaching_eligibility_evaluations
            (id, user_id, result, reason_code, age_input_source,
             evidence_timestamp_utc, evaluation_utc, evaluation_local_date,
             timezone_id, policy_version, minimum_age_rule_version,
             goal_version_id, recommendation_id, attempted_proposal_id,
             evidence_fingerprint)
          VALUES ('eligibility-$index', 'user-a', '$result', 'fixture-$index',
                  '$source', ${2000 + index}, ${2000 + index}, '2026-01-01',
                  'Asia/Kolkata', 'policy-$index', 'age-18', 'goal-lineage',
                  'recommendation-lineage', 'attempt-$index', 'fingerprint-$index')
        ''');
        }

        final goal = await db.select(db.nutritionGoalVersions).getSingle();
        expect(goal.policyVersion, 'B04-D04-HOLD-1');
        expect(goal.exactResultNumerator, '7');
        expect(goal.exactResultDenominator, '2');
        expect(goal.normalizedMaintenanceKcal, 2001);
        expect(
          await db.select(db.coachingEligibilityEvaluations).get(),
          hasLength(eligibilityCases.length),
        );
        expect(
          (await db.select(db.recommendationEvidence).getSingle())
              .exactResultDenominator,
          '2',
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'child evidence and feedback require same-user parent ownership',
    () async {
      final db = AppDatabase.memory();
      try {
        await db.customStatement('''
        INSERT INTO recommendations
          (id, user_id, scope, local_period_start, local_period_end,
           timezone_id, status, priority, action, explanation, rule_version,
           context_fingerprint)
        VALUES ('recommendation-a', 'user-a', 'daily', '2026-01-01',
                '2026-01-01', 'Asia/Kolkata', 'available', 1, 'review',
                'Review evidence', 'rule-1', 'context-1')
      ''');
        await expectLater(
          db.customStatement('''
          INSERT INTO recommendation_evidence
            (id, recommendation_id, user_id, evidence_kind, source_type,
             status)
          VALUES ('evidence-b', 'recommendation-a', 'user-b', 'goal',
                  'fixture', 'known')
        '''),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          db.customStatement('''
          INSERT INTO recommendation_feedback
            (id, user_id, recommendation_id, action, source, local_date,
             timezone_id)
          VALUES ('feedback-b', 'user-b', 'recommendation-a', 'dismiss',
                  'user', '2026-01-01', 'Asia/Kolkata')
        '''),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          db.customStatement('''
          INSERT INTO readiness_snapshot_evidence
            (id, readiness_snapshot_id, observation_id, evidence_kind, status)
          VALUES ('readiness-evidence-orphan', 'missing-snapshot',
                  'missing-observation', 'sleep', 'unknown')
        '''),
          throwsA(isA<Exception>()),
        );
      } finally {
        await db.close();
      }
    },
  );
}
