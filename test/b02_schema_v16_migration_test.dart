import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:indifit/core/fixtures/workout_draft_codec.dart';
import 'package:indifit/data/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'fixtures/v15_db_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('indifit-b02-v16-test-');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('B02-02 v15 to v16 activity schema migration', () {
    test(
      'upgrades a real v15 file without reclassifying history or fabricating B02 execution rows',
      () async {
        final file = await V15DbFixtures.createSourceDatabase(
          tempDir,
          'representative-v15.db',
        );
        expect(V15DbFixtures.readUserVersion(file), 15);

        final db = V15DbFixtures.openCurrentDatabase(file);
        try {
          await db.customSelect('SELECT 1').get();

          expect(V15DbFixtures.readUserVersion(file), 16);
          final session = await (db.select(
            db.workoutSessions,
          )..where((table) => table.id.equals(41))).getSingle();
          expect(session.id, 41);
          expect(session.name, 'Legacy Treadmill Label Must Not Classify');
          expect(session.scheduledOccurrenceId, 'occurrence-v15');
          expect(session.executionTimezoneId, 'Asia/Kolkata');
          expect(session.activityType, 'legacy');
          expect(session.activitySchemaVersion, 1);

          final set = await (db.select(
            db.workoutSets,
          )..where((table) => table.id.equals(51))).getSingle();
          expect(set.sessionId, 41);
          expect(set.exerciseName, 'Unresolved Treadmill Named Exercise');
          expect(set.exerciseId, isNull);
          expect(set.distanceKm, 3.2);

          final occurrence = await (db.select(
            db.scheduledSessionOccurrences,
          )..where((table) => table.id.equals('occurrence-v15'))).getSingle();
          expect(occurrence.status, 'inProgress');
          expect(occurrence.sessionTemplateId, 'template-v15');

          final draft = await (db.select(
            db.workoutDrafts,
          )..where((table) => table.id.equals(61))).getSingle();
          expect(draft.scheduledOccurrenceId, 'occurrence-v15');
          expect(draft.draftSchemaVersion, 1);
          expect(draft.activityType, 'legacy');
          expect(draft.executionStateJson, isNull);
          expect(
            WorkoutDraftCodec.decodeLoggedSets(draft.loggedSetsJson),
            hasLength(1),
          );

          final customExercise =
              await (db.select(db.exercises)..where(
                    (table) =>
                        table.stableId.equals('legacy-custom-v15-identity'),
                  ))
                  .getSingle();
          expect(customExercise.isCustom, isTrue);
          final unresolvedPrescription = await (db.select(
            db.exercisePrescriptions,
          )..where((table) => table.id.equals('prescription-v15'))).getSingle();
          expect(unresolvedPrescription.exerciseId, isNull);
          expect(
            unresolvedPrescription.exerciseNameSnapshot,
            'Unresolved Fixture Movement',
          );

          final provenance = await (db.select(
            db.healthProvenances,
          )..where((table) => table.id.equals(71))).getSingle();
          expect(provenance.provider, 'health_connect');
          expect(provenance.externalId, 'provider-v15-id');
          expect(provenance.fingerprint, 'provider-v15-fingerprint');
          expect(provenance.localSessionId, 41);

          expect(await db.select(db.exerciseGroups).get(), isEmpty);
          expect(await db.select(db.exerciseGroupMembers).get(), isEmpty);
          expect(await db.select(db.strengthSetPrescriptions).get(), isEmpty);
          expect(await db.select(db.cardioSessionDetails).get(), isEmpty);
          expect(await db.select(db.cardioIntervals).get(), isEmpty);
          expect(await db.select(db.mobilitySessionDetails).get(), isEmpty);
          expect(await db.select(db.performedExerciseGroups).get(), isEmpty);
          expect(await db.select(db.performedExercises).get(), isEmpty);
          expect(
            await db.select(db.exerciseTargetRecommendations).get(),
            isEmpty,
          );
          expect(await db.select(db.performedSets).get(), isEmpty);
          expect(await db.select(db.performedSetSegments).get(), isEmpty);
          expect(await db.select(db.performedRestPeriods).get(), isEmpty);
          expect(await db.select(db.muscles).get(), hasLength(4));
          expect(
            await db.select(db.exerciseMuscleMappings).get(),
            hasLength(4),
          );

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
      'creates all approved v16 tables, indexes, FKs, and typed defaults',
      () async {
        final db = AppDatabase.memory(schemaVersionOverride: 16);
        addTearDown(db.close);

        expect(db.schemaVersion, 16);
        final tables = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type = 'table' AND name IN (
          'exercise_groups', 'exercise_group_members',
          'strength_set_prescriptions', 'cardio_session_details',
          'cardio_intervals', 'mobility_session_details',
          'performed_exercise_groups', 'performed_exercises',
          'exercise_target_recommendations', 'performed_sets',
          'performed_set_segments', 'performed_rest_periods', 'muscles',
          'exercise_muscle_mappings'
        )
      ''').get();
        expect(tables, hasLength(14));

        const expectedParents = <String, Set<String>>{
          'exercise_groups': {'session_templates'},
          'exercise_group_members': {
            'exercise_groups',
            'exercise_prescriptions',
          },
          'strength_set_prescriptions': {'exercise_prescriptions'},
          'cardio_session_details': {'workout_sessions'},
          'cardio_intervals': {'cardio_session_details'},
          'mobility_session_details': {'workout_sessions'},
          'performed_exercise_groups': {'workout_sessions', 'exercise_groups'},
          'performed_exercises': {
            'workout_sessions',
            'performed_exercise_groups',
            'exercise_prescriptions',
            'exercises',
          },
          'exercise_target_recommendations': {'performed_exercises'},
          'performed_sets': {'performed_exercises'},
          'performed_set_segments': {'performed_sets'},
          'performed_rest_periods': {
            'workout_sessions',
            'performed_sets',
            'performed_exercise_groups',
          },
          'exercise_muscle_mappings': {'exercises', 'muscles'},
        };
        for (final entry in expectedParents.entries) {
          final foreignKeys = await db
              .customSelect('PRAGMA foreign_key_list(${entry.key})')
              .get();
          final parents = foreignKeys
              .map((row) => row.data['table'] as String)
              .toSet();
          expect(parents, containsAll(entry.value), reason: entry.key);
        }

        final sessionId = await db
            .into(db.workoutSessions)
            .insert(
              WorkoutSessionsCompanion.insert(
                name: 'Fresh activity header',
                totalVolume: 0,
                durationSeconds: 600,
                estimatedCalories: 0,
              ),
            );
        final session = await (db.select(
          db.workoutSessions,
        )..where((table) => table.id.equals(sessionId))).getSingle();
        expect(session.activityType, 'legacy');
        expect(session.activitySchemaVersion, 1);

        await db
            .into(db.cardioSessionDetails)
            .insert(
              CardioSessionDetailsCompanion.insert(sessionId: Value(sessionId)),
            );
        await expectLater(
          db.customStatement('''
          INSERT INTO cardio_intervals
            (id, cardio_session_id, ordinal, segment_type)
          VALUES ('invalid-cardio-parent', 999999, 0, 'work')
        '''),
          throwsA(isA<Object>()),
        );
        await expectLater(
          db
              .into(db.workoutSessions)
              .insert(
                WorkoutSessionsCompanion.insert(
                  name: 'Invalid typed value',
                  totalVolume: 0,
                  durationSeconds: 1,
                  estimatedCalories: 0,
                  activityType: const Value('name-inferred-cardio'),
                ),
              ),
          throwsA(isA<Object>()),
        );

        final indexes = await db.customSelect('''
        SELECT name FROM sqlite_master WHERE type = 'index' AND name IN (
          'idx_workout_sessions_activity_completed',
          'idx_exercise_groups_template',
          'idx_cardio_intervals_session_ordinal',
          'idx_performed_exercises_actual_session',
          'idx_performed_rest_periods_session_started',
          'idx_exercise_muscle_mappings_muscle_status'
        )
      ''').get();
        expect(indexes.map((row) => row.data['name']).toSet(), hasLength(6));
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );

    test(
      'reopening an upgraded file does not duplicate B02 or B01 rows',
      () async {
        final file = await V15DbFixtures.createSourceDatabase(
          tempDir,
          'idempotent-v15.db',
        );
        final first = V15DbFixtures.openCurrentDatabase(file);
        try {
          await first.customSelect('SELECT 1').get();
        } finally {
          await first.close();
        }
        final second = V15DbFixtures.openCurrentDatabase(file);
        try {
          await second.customSelect('SELECT 1').get();
          expect(
            await second.select(second.workoutSessions).get(),
            hasLength(1),
          );
          expect(await second.select(second.workoutSets).get(), hasLength(1));
          expect(await second.select(second.exerciseGroups).get(), isEmpty);
          expect(await second.select(second.muscles).get(), hasLength(4));
        } finally {
          await second.close();
        }
      },
    );

    test(
      'forced v16 migration failure rolls back every DDL and legacy write',
      () async {
        final file = await V15DbFixtures.createSourceDatabase(
          tempDir,
          'rollback-v16.db',
        );
        final db = V15DbFixtures.openCurrentDatabase(
          file,
          v16MigrationFailureInjector: () async {
            throw StateError('injected B02-v16 migration failure');
          },
        );
        try {
          await expectLater(
            db.customSelect('SELECT 1').get(),
            throwsA(isA<StateError>()),
          );
        } finally {
          await db.close();
        }

        expect(V15DbFixtures.readUserVersion(file), 15);
        final source = sqlite.sqlite3.open(
          file.path,
          mode: sqlite.OpenMode.readOnly,
        );
        try {
          final v16Table = source.select('''
          SELECT name FROM sqlite_master
          WHERE type = 'table' AND name = 'performed_exercises'
        ''');
          final activityColumn = source.select(
            'PRAGMA table_info(workout_sessions)',
          );
          final legacySession = source.select('''
          SELECT id, name FROM workout_sessions WHERE id = 41
        ''');
          expect(v16Table, isEmpty);
          expect(
            activityColumn.any((row) => row['name'] == 'activity_type'),
            isFalse,
          );
          expect(
            legacySession.single['name'],
            'Legacy Treadmill Label Must Not Classify',
          );
        } finally {
          source.dispose();
        }
      },
    );
  });
}
